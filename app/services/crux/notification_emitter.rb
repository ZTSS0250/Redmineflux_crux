module Crux
  # Baseline Notification Engine: writes crux_notifications on WorkflowEngine
  # transitions. event_type values here go beyond the 3 literally named in
  # architecture.md ("e.g. approval_pending, run_completed, run_failed") since
  # that list is illustrative, not exhaustive, and this task's Objectives ask
  # for plan-approved/rejected/modified notifications too.
  class NotificationEmitter
    def self.plan_awaiting_approval(plan)
      notify_approvers(plan, 'approval_pending')
    end

    def self.plan_approved(plan)
      notify_owner(plan, 'plan_approved')
    end

    def self.plan_rejected(plan)
      notify_owner(plan, 'plan_rejected')
    end

    def self.plan_modified(plan)
      notify_owner(plan, 'plan_modified')
    end

    def self.run_completed(plan)
      notify_owner(plan, 'run_completed')
    end

    def self.run_failed(plan)
      notify_owner(plan, 'run_failed')
    end

    # crx-004 Edge Case #1: both the primary and fallback model failed for a
    # single agent invocation. Unlike the plan-centric methods above, a
    # failed Requirement Analyst/Planner hand-off run has no plan yet, so
    # this notifies against the run itself rather than requiring one.
    def self.agent_run_failed(run)
      Crux::Notification.create!(
        user_id: run.user_id,
        event_type: 'agent_run_failed',
        ref_type: 'Crux::Run',
        ref_id: run.id
      )
    end

    def self.notify_owner(plan, event_type)
      write!(plan, plan.conversation.user_id, event_type)
    end

    def self.notify_approvers(plan, event_type)
      project = plan.conversation.project
      project.users.select { |member| member.allowed_to?(:crux_approve, project) }.each do |member|
        write!(plan, member.id, event_type)
      end
    end

    def self.write!(plan, user_id, event_type)
      Crux::Notification.create!(
        user_id: user_id,
        event_type: event_type,
        ref_type: 'Crux::ExecutionPlan',
        ref_id: plan.id
      )
    end
    private_class_method :notify_owner, :notify_approvers, :write!
  end
end
