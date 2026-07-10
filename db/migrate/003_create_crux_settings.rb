class CreateCruxSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :crux_settings do |t|
      t.string :key, null: false
      t.text :value
      t.string :scope, null: false, default: 'global'
      t.integer :project_id
      t.timestamps
    end

    add_index :crux_settings, [:key, :scope, :project_id], unique: true, name: 'index_crux_settings_on_key_scope_project'
    add_index :crux_settings, :project_id
  end
end
