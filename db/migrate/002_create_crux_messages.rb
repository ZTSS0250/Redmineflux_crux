class CreateCruxMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_messages do |t|
      t.integer :conversation_id, null: false
      t.string :role, null: false
      t.text :content, null: false
      t.timestamp :created_at, null: false
    end

    add_index :crux_messages, :conversation_id
    add_index :crux_messages, [:conversation_id, :created_at]
  end
end
