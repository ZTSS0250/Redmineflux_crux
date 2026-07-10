class AddAgentIdToCruxMessages < ActiveRecord::Migration[6.1]
  # Not in crx-004's literal Code Changes table, but required to satisfy its
  # own Objective ("attribution badges on chat messages... showing which
  # agent authored them") — crux_messages (crx-002) had no column recording
  # who authored a reply. Narrow, additive, nullable column; the same kind
  # of justified extension crx-003 made for crux_settings/attempts/
  # error_message when the literal doc schema fell short of a stated
  # Objective.
  def change
    add_column :crux_messages, :agent_id, :integer
    add_index :crux_messages, :agent_id
  end
end
