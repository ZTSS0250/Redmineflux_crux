module Crux
  class PlanStep < ActiveRecord::Base
    self.table_name = 'crux_plan_steps'

    # Centralized, single source of truth for which action types require
    # crux:approve_destructive in addition to ordinary crux:approve
    # (architecture.md Design Decisions — never scattered per-agent logic).
    DESTRUCTIVE_ACTIONS = %w[delete_project delete_milestone deploy].freeze

    # Which agent role is responsible for executing a given action_type.
    # crux_plan_steps has no agent_id column (database_design.md's Components
    # list has none — only crux_runs.agent_id records who actually executed
    # a step); this is a centralized, action_type-keyed mapping in the same
    # spirit as DESTRUCTIVE_ACTIONS above. Only the two content-generation
    # action types Documentation Agent is documented to own (agent_catalog.md
    # primary output: "wiki pages, technical docs") are mapped explicitly;
    # every other canonical stub action type (create_project, create_versions,
    # generate_milestones, create_issues, assign_users, delete_milestone) is a
    # mechanical Core-Platform-object action from the Planner's own drafted
    # plan, so it defaults to Planner as executing agent for Phase 1 — none of
    # Developer/QA Agent/Reporter/DevOps Agent have a concrete action_type of
    # their own wired yet (crx-004 Out of Scope). Revisit per-action-type once
    # a later task gives those agents real execution triggers.
    AGENT_ROLE_FOR_ACTION_TYPE = {
      'generate_wiki' => 'documentation_agent',
      'generate_documentation' => 'documentation_agent'
    }.freeze
    DEFAULT_AGENT_ROLE = 'planner'.freeze

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

    def responsible_agent_role
      AGENT_ROLE_FOR_ACTION_TYPE.fetch(action_type, DEFAULT_AGENT_ROLE)
    end

    def responsible_agent
      Crux::Agent.effective(role: responsible_agent_role, project: execution_plan.conversation.project)
    end
  end
end
