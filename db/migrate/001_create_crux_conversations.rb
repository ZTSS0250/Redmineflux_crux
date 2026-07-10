class CreateCruxConversations < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_conversations do |t|
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.integer :agent_id
      # Full 6-state enum from workflow_engine.md, even though this task only
      # ever transitions draft -> clarifying -> planned. Defining it now
      # avoids a schema-changing migration in crx-003 just to add values.
      t.string :state, null: false, default: 'draft'
      t.timestamp :created_at, null: false
    end

    add_index :crux_conversations, :project_id
    add_index :crux_conversations, :user_id
    add_index :crux_conversations, :agent_id
    add_index :crux_conversations, [:project_id, :created_at]
    add_index :crux_conversations, [:project_id, :user_id, :state]
  end
end
