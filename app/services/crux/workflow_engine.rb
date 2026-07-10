module Crux
  # Owns crux_execution_plans.status / crux_conversations.state transitions.
  # Every transition that matters for correctness goes through a DB-level
  # compare-and-swap (`cas!`) so two concurrent Approve clicks on the same
  # plan cannot both succeed — an application-level read-then-write would be
  # a TOCTOU race (workflow_engine.md Assumptions).
  #
  # Approval model: Approve is additive/partial — it approves every
  # awaiting_approval step the acting user is permitted to approve (all
  # ordinary steps, destructive ones only with crux:approve_destructive),
  # and only transitions the plan to `executing` once nothing remains
  # awaiting_approval. This is what lets a crux:approve-only user approve
  # the ordinary steps in a mixed plan while a destructive step waits for
  # someone else, without a separate "partial approval" concept. Reject and
  # Modify are both disruptive to the whole plan by contrast — either one
  # sends the plan back to `planned`, matching workflow_engine.md's
  # "Reject and Modify both transition awaiting_approval -> planned".
  class WorkflowEngine
    class TransitionError < StandardError; end

    def self.approve!(plan:, user:, step: nil)
      new(plan, user).approve!(step)
    end

    def self.reject!(plan:, user:, step: nil)
      new(plan, user).reject!(step)
    end

    def self.modify!(plan:, user:, step:, payload:)
      new(plan, user).modify!(step, payload)
    end

    def self.submit_for_approval!(plan)
      updated = cas!(plan, from: %w[planned], to: 'awaiting_approval')
      if updated
        plan.conversation.update!(state: 'awaiting_approval')
        Crux::NotificationEmitter.plan_awaiting_approval(plan)
      end
      updated
    end

    def self.complete!(plan)
      updated = cas!(plan, from: %w[executing], to: 'completed')
      if updated
        plan.conversation.update!(state: 'completed')
        Crux::NotificationEmitter.run_completed(plan)
      end
      updated
    end

    def self.fail_plan!(plan)
      updated = cas!(plan, from: %w[executing], to: 'planned')
      if updated
        # Steps that already finished (completed/failed) keep their result
        # visible; anything still approved/executing goes back to
        # awaiting_approval rather than being left in limbo.
        plan.plan_steps.where(status: %w[approved executing]).update_all(status: 'awaiting_approval')
        plan.conversation.update!(state: 'planned')
        Crux::NotificationEmitter.run_failed(plan)
      end
      updated
    end

    # The atomic guard: an UPDATE ... WHERE status = ? whose affected-row
    # count tells the caller whether it actually won the race, never a
    # separate read followed by a separate write.
    def self.cas!(plan, from:, to:, extra: {})
      affected = Crux::ExecutionPlan.where(id: plan.id, status: Array(from)).update_all(extra.merge(status: to))
      plan.reload if affected.positive?
      affected.positive?
    end

    def initialize(plan, user)
      @plan = plan
      @user = user
    end

    def approve!(step)
      ActiveRecord::Base.transaction do
        raise TransitionError, 'Plan is no longer awaiting approval.' unless @plan.reload.awaiting_approval?

        targets = step ? [step] : @plan.plan_steps.awaiting_approval.to_a

        targets.each do |plan_step|
          next unless plan_step.awaiting_approval?

          unless Crux::ApprovalGate.can_approve?(@user, plan_step)
            raise TransitionError, "You don't have permission to approve this step." if step

            next
          end

          plan_step.update!(status: 'approved')
        end

        next unless @plan.plan_steps.awaiting_approval.none?

        updated = self.class.cas!(
          @plan, from: %w[awaiting_approval], to: 'executing',
          extra: { approved_by: @user.id, approved_at: Time.current }
        )
        next unless updated

        @plan.conversation.update!(state: 'executing')
        Crux::NotificationEmitter.plan_approved(@plan)
        Crux::ExecutePlanJob.perform_later(@plan.id)
      end
    end

    def reject!(step)
      ActiveRecord::Base.transaction do
        step&.update!(status: 'rejected')

        updated = self.class.cas!(@plan, from: %w[awaiting_approval], to: 'planned')
        next unless updated

        @plan.plan_steps.awaiting_approval.update_all(status: 'rejected')
        @plan.conversation.update!(state: 'planned')
        Crux::NotificationEmitter.plan_rejected(@plan)
      end
    end

    def modify!(step, payload)
      raise TransitionError, 'That assignee is not a member of this project.' unless valid_payload?(payload)

      ActiveRecord::Base.transaction do
        step.update!(payload: payload)

        updated = self.class.cas!(@plan, from: %w[awaiting_approval], to: 'planned')
        next unless updated

        @plan.conversation.update!(state: 'planned')
        Crux::NotificationEmitter.plan_modified(@plan)
      end
    end

    private

    def valid_payload?(payload)
      assignee_id = payload['assignee_id']
      return true if assignee_id.blank?

      @plan.conversation.project.users.exists?(id: assignee_id)
    end
  end
end
