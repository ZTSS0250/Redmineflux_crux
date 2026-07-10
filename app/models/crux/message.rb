module Crux
  class Message < ActiveRecord::Base
    self.table_name = 'crux_messages'

    ROLES = %w[user agent system].freeze

    belongs_to :conversation, class_name: 'Crux::Conversation', foreign_key: 'conversation_id'
    # Nullable: only agent-authored replies are attributed (agent_catalog.md
    # "Attribution badges"); user/system messages never set this.
    belongs_to :agent, class_name: 'Crux::Agent', optional: true

    validates :role, presence: true, inclusion: { in: ROLES }
    validates :content, presence: true
  end
end
