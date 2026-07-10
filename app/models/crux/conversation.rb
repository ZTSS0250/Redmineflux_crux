module Crux
  class Conversation < ActiveRecord::Base
    self.table_name = 'crux_conversations'

    belongs_to :project
    belongs_to :user
    has_many :messages, -> { order(:created_at) },
             class_name: 'Crux::Message',
             foreign_key: 'conversation_id',
             dependent: :destroy

    # Full state machine per workflow_engine.md. This task only ever drives
    # a conversation through draft -> clarifying -> planned; the remaining
    # states are reserved for crx-003 (Workflow Engine).
    enum state: {
      draft: 'draft',
      clarifying: 'clarifying',
      planned: 'planned',
      awaiting_approval: 'awaiting_approval',
      executing: 'executing',
      completed: 'completed'
    }

    validates :project_id, presence: true
    validates :user_id, presence: true
  end
end
