class CreateCruxExecutionPlans < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_execution_plans do |t|
      t.integer :conversation_id, null: false
      # Mirrors crux_conversations.state from `planned` onward; no separate
      # `rejected` value — reject/modify both loop back to `planned`.
      t.string :status, null: false, default: 'planned'
      t.string :estimated_time
      t.string :estimated_cost
      t.integer :approved_by
      t.timestamp :approved_at
      t.timestamps
    end

    add_index :crux_execution_plans, :conversation_id
    add_index :crux_execution_plans, :status
    add_index :crux_execution_plans, [:conversation_id, :status]
  end
end
