class CreateCruxPlanSteps < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_plan_steps do |t|
      t.integer :plan_id, null: false
      t.string :action_type, null: false
      t.string :target_type
      t.integer :target_id
      t.string :status, null: false, default: 'awaiting_approval'
      t.text :payload
      # Not in database_design.md's abbreviated column list, but genuinely
      # needed for the Retry Manager's persistent attempt tracking and for
      # surfacing why a step failed (workflow_engine.md's "surface the
      # error" requirement) — a narrow, justified addition, not silent
      # schema drift.
      t.integer :attempts, null: false, default: 0
      t.text :error_message
      t.timestamps
    end

    add_index :crux_plan_steps, :plan_id
    add_index :crux_plan_steps, :status
    add_index :crux_plan_steps, [:plan_id, :status]
  end
end
