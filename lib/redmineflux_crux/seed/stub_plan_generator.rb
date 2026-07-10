module RedminefluxCrux
  module Seed
    # QA-only. Generates the canonical worked-example execution plan
    # (Create Project · Generate Wiki · Create Versions · Generate
    # Milestones · Create 84 Issues · Assign Users · Generate Documentation,
    # plus one destructive step) against a real conversation, since crx-004's
    # Planner agent — the real plan author — doesn't exist yet.
    #
    # Must never be invoked from production UI or a controller action; only
    # from the `crux:stub_plan` Rake task or a Rails console session.
    class StubPlanGenerator
      STEPS = [
        { action_type: 'create_project', target_type: 'Project' },
        { action_type: 'generate_wiki', target_type: 'WikiPage' },
        { action_type: 'create_versions', target_type: 'Version', payload: { count: 3 } },
        { action_type: 'generate_milestones', target_type: 'Version', payload: { count: 3 } },
        { action_type: 'create_issues', target_type: 'Issue', payload: { count: 84 } },
        { action_type: 'assign_users', target_type: 'Issue' },
        { action_type: 'generate_documentation', target_type: 'WikiPage' },
        { action_type: 'delete_milestone', target_type: 'Version', payload: { name: 'v0.9' } }
      ].freeze

      def self.call(conversation:, simulate_failure_on: nil)
        new(conversation, simulate_failure_on).call
      end

      def initialize(conversation, simulate_failure_on)
        @conversation = conversation
        @simulate_failure_on = simulate_failure_on
      end

      def call
        plan = Crux::ExecutionPlan.create!(
          conversation_id: @conversation.id,
          status: 'awaiting_approval',
          estimated_time: '~6 min',
          estimated_cost: '$0.42'
        )

        STEPS.each do |step|
          payload = (step[:payload] || {}).dup
          payload['simulate_failure'] = true if step[:action_type] == @simulate_failure_on

          Crux::PlanStep.create!(
            plan_id: plan.id,
            action_type: step[:action_type],
            target_type: step[:target_type],
            status: 'awaiting_approval',
            payload: payload
          )
        end

        @conversation.update!(state: 'awaiting_approval')
        Crux::NotificationEmitter.plan_awaiting_approval(plan)
        plan
      end
    end
  end
end
