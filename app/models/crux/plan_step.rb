module Crux
  class PlanStep < ActiveRecord::Base
    self.table_name = 'crux_plan_steps'

    # Centralized, single source of truth for which action types require
    # crux:approve_destructive in addition to ordinary crux:approve
    # (architecture.md Design Decisions — never scattered per-agent logic).
    DESTRUCTIVE_ACTIONS = %w[delete_project delete_milestone deploy].freeze

    belongs_to :execution_plan, class_name: 'Crux::ExecutionPlan', foreign_key: 'plan_id'

    enum status: {
      awaiting_approval: 'awaiting_approval',
      approved: 'approved',
      rejected: 'rejected',
      executing: 'executing',
      completed: 'completed',
      failed: 'failed'
    }

    validates :action_type, presence: true

    # Plain JSON.parse/generate rather than ActiveRecord's `serialize`
    # macro (which for a JSON coder would otherwise route through
    # JSON.load) — stored as portable text so this works the same across
    # whichever database Redmine is deployed on.
    def payload
      raw = read_attribute(:payload)
      raw.present? ? JSON.parse(raw) : {}
    rescue JSON::ParserError
      {}
    end

    def payload=(value)
      write_attribute(:payload, value.present? ? JSON.generate(value) : nil)
    end

    def destructive?
      DESTRUCTIVE_ACTIONS.include?(action_type)
    end
  end
end
