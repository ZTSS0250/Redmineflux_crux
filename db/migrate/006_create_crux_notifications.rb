class CreateCruxNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_notifications do |t|
      t.integer :user_id, null: false
      t.string :event_type, null: false
      # Polymorphic reference with no DB-level FK (database_design.md's
      # accepted risk) — the referenced row may be soft-handled/gone later;
      # rendering must degrade gracefully rather than rely on a constraint.
      t.string :ref_type
      t.integer :ref_id
      t.timestamp :read_at
      t.timestamp :created_at, null: false
    end

    add_index :crux_notifications, :user_id
    add_index :crux_notifications, [:ref_type, :ref_id]
    add_index :crux_notifications, [:user_id, :created_at]
  end
end
