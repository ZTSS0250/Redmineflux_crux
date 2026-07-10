module Crux
  class Message < ActiveRecord::Base
    self.table_name = 'crux_messages'

    ROLES = %w[user agent system].freeze

    belongs_to :conversation, class_name: 'Crux::Conversation', foreign_key: 'conversation_id'

    validates :role, presence: true, inclusion: { in: ROLES }
    validates :content, presence: true
  end
end
