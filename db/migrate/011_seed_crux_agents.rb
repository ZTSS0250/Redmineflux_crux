class SeedCruxAgents < ActiveRecord::Migration[6.1]
  # Idempotent migration-time insert (the parenthetical alternative to
  # db/seeds/crux_agents_seed.rb named in crx-004's Code Changes table) —
  # runs automatically with the rest of the plugin's migrations rather than
  # depending on a separate, easy-to-forget rake db:seed step.
  class MigrationAgent < ActiveRecord::Base
    self.table_name = 'crux_agents'
  end

  # model/fallback_model are deliberately distinct strings (not both "mock")
  # so a fallback in Crux::Agents::Runner is observable in crux_runs.model
  # (crx-004 Unit Test #2) purely against the Mock Provider, no external
  # provider required until crx-006.
  GA_AGENTS = [
    { name: 'Requirement Analyst', role: 'requirement_analyst', temperature: 0.2 },
    { name: 'Planner', role: 'planner', temperature: 0.2 },
    { name: 'Developer', role: 'developer', temperature: 0.4 },
    { name: 'QA Agent', role: 'qa_agent', temperature: 0.3 },
    { name: 'Documentation Agent', role: 'documentation_agent', temperature: 0.3 },
    { name: 'Reporter', role: 'reporter', temperature: 0.5 },
    { name: 'DevOps Agent', role: 'devops_agent', temperature: 0.3 }
  ].freeze

  PHASE_2_3_AGENTS = [
    { name: 'Security Agent', role: 'security_agent' },
    { name: 'Code Reviewer', role: 'code_reviewer' },
    { name: 'Product Owner Agent', role: 'product_owner_agent' },
    { name: 'Scrum Master Agent', role: 'scrum_master_agent' },
    { name: 'Release Manager Agent', role: 'release_manager_agent' }
  ].freeze

  def up
    now = Time.current

    GA_AGENTS.each do |attrs|
      next if MigrationAgent.where(role: attrs[:role], project_id: nil).exists?

      MigrationAgent.create!(
        attrs.merge(
          model: 'mock-primary',
          fallback_model: 'mock-fallback',
          enabled: true,
          project_id: nil,
          created_at: now,
          updated_at: now
        )
      )
    end

    PHASE_2_3_AGENTS.each do |attrs|
      next if MigrationAgent.where(role: attrs[:role], project_id: nil).exists?

      MigrationAgent.create!(
        attrs.merge(
          temperature: 0.3,
          enabled: false,
          project_id: nil,
          created_at: now,
          updated_at: now
        )
      )
    end
  end

  def down
    MigrationAgent.where(project_id: nil, role: (GA_AGENTS + PHASE_2_3_AGENTS).map { |a| a[:role] }).delete_all
  end
end
