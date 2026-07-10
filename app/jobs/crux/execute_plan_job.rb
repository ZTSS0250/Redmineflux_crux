module Crux
  # Runs an approved plan's steps off the request thread, consistent with
  # crx-002's established async convention. Steps execute in their declared
  # order (workflow_engine.md) via RetryManager's simulated executor; the
  # first exhausted-retries failure returns the whole plan to `planned` and
  # stops — remaining steps are never left executing in limbo.
  class ExecutePlanJob < ActiveJob::Base
    queue_as :default

    def perform(plan_id)
      plan = Crux::ExecutionPlan.find(plan_id)
      return unless plan.executing?

      plan.plan_steps.where(status: 'approved').order(:id).each do |step|
        break unless plan.reload.executing?

        next if Crux::RetryManager.attempt(step)

        Crux::WorkflowEngine.fail_plan!(plan)
        return
      end

      Crux::WorkflowEngine.complete!(plan) if plan.reload.executing?
    end
  end
end
