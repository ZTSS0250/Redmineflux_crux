class CreateCruxOutcomes < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_outcomes do |t|
      t.integer :run_id, null: false
      t.string :outcome_type, null: false
      # Denormalized from the run's conversation, purely for billing query
      # performance at scale — the one accepted exception to "derive, don't
      # duplicate" (database_design.md Design Decisions).
      t.integer :project_id, null: false
      t.timestamp :billed_at
      t.timestamp :created_at, null: false
    end

    add_index :crux_outcomes, :run_id
    add_index :crux_outcomes, [:project_id, :created_at]
    add_index :crux_outcomes, :billed_at
  end
end
