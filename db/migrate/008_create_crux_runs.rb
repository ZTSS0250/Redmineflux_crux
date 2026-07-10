class CreateCruxRuns < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_runs do |t|
      t.integer :agent_id, null: false
      t.integer :plan_step_id
      t.integer :user_id, null: false
      t.string :model
      t.string :provider
      t.string :prompt_ref
      t.text :context_refs
      t.integer :tokens_in
      t.integer :tokens_out
      t.decimal :cost, precision: 10, scale: 4
      t.string :output_ref
      t.timestamp :created_at, null: false
    end

    add_index :crux_runs, :agent_id
    add_index :crux_runs, :plan_step_id
    add_index :crux_runs, :user_id
    add_index :crux_runs, :created_at

    # No project_id column here: database_design.md's Components section for
    # crux_runs lists no such column (only crux_outcomes denormalizes
    # project_id, per its own explicit Design Decision) — the Best Practices
    # section's "(project_id, created_at) on ... crux_runs" line appears to
    # be a documentation inconsistency rather than a real column, so it is
    # not added here. Flagged for reconciliation rather than silently
    # guessed either way.
  end
end
