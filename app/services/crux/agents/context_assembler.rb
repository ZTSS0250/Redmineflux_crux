module Crux
  module Agents
    # Conversation-history-only context for crx-004. Returns the first 3 of
    # chat_engine.md's 4 context layers (project identity, bounded
    # conversation history, detected intent); the 4th layer
    # (permission-filtered Knowledge Engine retrieval) is an explicit,
    # documented seam — crx-005 extends this same #assemble method rather
    # than every agent's call site having to change.
    class ContextAssembler
      HISTORY_LIMIT = 20

      def self.assemble(conversation:, user:)
        new(conversation: conversation, user: user).assemble
      end

      def initialize(conversation:, user:)
        @conversation = conversation
        @user = user
      end

      def assemble
        {
          project: { id: @conversation.project_id, name: @conversation.project.name },
          user: { id: @user.id, name: @user.name },
          history: recent_messages,
          intent: Crux::IntentClassifier.call(latest_user_message)
          # TODO: crx-005 — add permission-filtered Knowledge Engine
          # retrieval here as a 4th input (chat_engine.md's 4-layer model).
        }
      end

      private

      def recent_messages
        @conversation.messages.order(created_at: :desc).limit(HISTORY_LIMIT).reverse.map do |message|
          { role: message.role, content: message.content }
        end
      end

      def latest_user_message
        @conversation.messages.where(role: 'user').order(created_at: :desc).first&.content.to_s
      end
    end
  end
end
