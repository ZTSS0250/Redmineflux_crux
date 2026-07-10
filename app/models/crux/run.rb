module Crux
  class Run < ActiveRecord::Base
    self.table_name = 'crux_runs'

    # Marker prefix for output_ref on a failed invocation (both primary and
    # fallback model failed, or the agent was disabled at execution time).
    # crux_runs has no dedicated status column (database_design.md's
    # Components list for this table has none) — output_ref already exists
    # to reference "the run's output", and a failure explanation is exactly
    # that, so failure is encoded there rather than adding an undocumented
    # column.
    FAILURE_PREFIX = 'failure:'.freeze

    belongs_to :agent, class_name: 'Crux::Agent'
    belongs_to :plan_step, class_name: 'Crux::PlanStep', optional: true
    belongs_to :user

    validates :agent_id, presence: true
    validates :user_id, presence: true

    # Genuinely append-only at the model layer, not just team convention
    # (database_design.md Design Decision; crx-004 Gate 1 finding #2) — a
    # retried or fallback-model run must produce a new row, never mutate an
    # existing one. Raising here (rather than returning false, which merely
    # halts pre-Rails-5 style) makes an accidental future `.update` call fail
    # loudly instead of silently corrupting the audit trail.
    before_update { raise ActiveRecord::ReadOnlyRecord, 'Crux::Run is append-only and cannot be updated.' }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, 'Crux::Run is append-only and cannot be destroyed.' }

    def failed?
      output_ref.to_s.start_with?(FAILURE_PREFIX)
    end
  end
end
