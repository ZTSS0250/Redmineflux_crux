module Crux
  # Tracks attempt count per crux_plan_steps row and retries on failure up to
  # a configurable limit (crux_settings, not a hardcoded constant, per
  # workflow_engine.md's Assumption that this is Administration-configurable).
  #
  # `execute` dispatches to the step's responsible agent via
  # Crux::RunAgentJob (crx-004's Agent Engine) -- called directly
  # (`.new.perform`, not `.perform_later`) since RetryManager already runs
  # inside crx-003's async Crux::ExecutePlanJob and needs execute's
  # true/false result immediately to decide whether to retry or give up,
  # which a second queued hop couldn't provide synchronously.
  class RetryManager
    DEFAULT_MAX_ATTEMPTS = 3

    def self.attempt(step)
      max_attempts = max_attempts_for(step)

      loop do
        step.update!(status: 'executing')

        if execute(step)
          step.update!(status: 'completed', error_message: nil)
          return true
        end

        step.increment!(:attempts)

        if step.attempts >= max_attempts
          step.update!(status: 'failed', error_message: "Step failed after #{step.attempts} attempt(s).")
          return false
        end
      end
    end

    def self.execute(step)
      Crux::RunAgentJob.new.perform(plan_step_id: step.id)
    end

    def self.max_attempts_for(_step)
      Crux::Setting.get('workflow.max_step_attempts', scope: 'global', default: DEFAULT_MAX_ATTEMPTS).to_i
    end
    private_class_method :execute, :max_attempts_for
  end
end
