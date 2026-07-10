class CreateCruxAgents < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_agents do |t|
      t.string :name, null: false
      t.string :role, null: false
      t.text :prompt_template
      t.string :model
      t.string :fallback_model
      t.float :temperature, default: 0.3
      t.boolean :enabled, null: false, default: true
      t.integer :project_id
      t.timestamps
    end

    add_index :crux_agents, :project_id
    add_index :crux_agents, :role
    # project_id nullable pattern (null = global default, non-null = project
    # override) per database_design.md/agent_catalog.md — one row per
    # (role, project_id) pair.
    add_index :crux_agents, [:role, :project_id], unique: true, name: 'index_crux_agents_on_role_and_project'
  end
end
