module Crux
  class Agent < ActiveRecord::Base
    self.table_name = 'crux_agents'

    # Cosmetic catalog metadata (category/phase, agent_catalog.md's Summary
    # table) — not schema columns; every one of the 12 rows shares the exact
    # same crux_agents schema (database_design.md Assumptions), so this is
    # kept as display-only lookup, never persisted.
    CATALOG_META = {
      'requirement_analyst'   => { category: 'Requirements & Planning', phase: 'GA' },
      'planner'               => { category: 'Requirements & Planning', phase: 'GA' },
      'developer'             => { category: 'Engineering', phase: 'GA' },
      'qa_agent'              => { category: 'Quality', phase: 'GA' },
      'documentation_agent'   => { category: 'Documentation', phase: 'GA' },
      'reporter'              => { category: 'Reporting', phase: 'GA' },
      'devops_agent'          => { category: 'Operations', phase: 'GA' },
      'security_agent'        => { category: 'Security', phase: 'Phase 2/3' },
      'code_reviewer'         => { category: 'Quality', phase: 'Phase 2/3' },
      'product_owner_agent'   => { category: 'Requirements & Planning', phase: 'Phase 2/3' },
      'scrum_master_agent'    => { category: 'Governance', phase: 'Phase 2/3' },
      'release_manager_agent' => { category: 'Operations', phase: 'Phase 2/3' }
    }.freeze

    ROLES = CATALOG_META.keys.freeze

    belongs_to :project, optional: true

    validates :name, presence: true
    validates :role, presence: true, inclusion: { in: ROLES }

    # project_id nullable = global default; a non-null row overrides it for
    # that one project only (agent_catalog.md "Per-project override" /
    # database_design.md's project_id nullable pattern — the same shape
    # already used for crux_settings).
    def self.effective(role:, project:)
      where(role: role, project_id: project.id).first || where(role: role, project_id: nil).first
    end

    def category
      CATALOG_META.dig(role, :category)
    end

    def phase
      CATALOG_META.dig(role, :phase)
    end

    def override?
      project_id.present?
    end
  end
end
