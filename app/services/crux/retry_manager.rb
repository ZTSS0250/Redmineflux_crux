module Crux
  # Tracks attempt count per crux_plan_steps row and retries on failure up to
  # a configurable limit (crux_settings, not a hardcoded constant, per
  # workflow_engine.md's Assumption that this is Administration-configurable).
  #
  # `execute` is a simulated stub — crx-004's Agent Engine doesn't exist yet,
  # so there is nothing real to dispatch to. It succeeds unless the step's
  # payload carries `"simulate_failure" => true`, which only the QA-only
  # stub_plan_generator ever sets. A future task replaces this method's body
  # with a real Core Platform/Agent Engine call behind the same call site.
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
      !step.payload['simulate_failure']
    end

    def self.max_attempts_for(_step)
      Crux::Setting.get('workflow.max_step_attempts', scope: 'global', default: DEFAULT_MAX_ATTEMPTS).to_i
    end
    private_class_method :execute, :max_attempts_for
  end
end
