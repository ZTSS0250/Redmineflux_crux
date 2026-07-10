module Crux
  # Orchestration entry point the Chat tab talks to: Intent Detection ->
  # Clarification Engine -> (hand off, not yet executed). Stops at marking
  # the conversation `planned` — generating an actual execution plan begins
  # with crx-003/crx-004.
  class ChatEngine
    def self.call(project:, user:, conversation:, text:)
      new(project: project, user: user, conversation: conversation, text: text).call
    end

    def initialize(project:, user:, conversation:, text:)
      @project = project
      @user = user
      @conversation = conversation
      @text = text
    end

    def call
      result = Crux::IntentClassifier.call(@text)

      if result == :unclassified
        reply_unsupported
      elsif result.is_a?(Array)
        reply_ambiguous(result)
      else
        handle_intent(result)
      end
    end

    private

    def handle_intent(intent)
      questions = Crux::ClarificationEngine.call(intent: intent, conversation: @conversation, text: @text)

      if questions
        ask_clarification(questions)
      else
        @conversation.update!(state: 'planned')
        append_agent_message('Got it — that has enough detail to plan. This conversation is ready for the next phase to pick up.')
      end
    end

    def ask_clarification(questions)
      @conversation.update!(state: 'clarifying') unless @conversation.clarifying?
      content = (['A few questions before I proceed:'] + questions).join("\n")
      append_agent_message(content)
    end

    def reply_unsupported
      suggestions = Crux::IntentClassifier::SUPPORTED_INTENTS.first(5).map { |i| i.to_s.tr('_', ' ') }.join(', ')
      append_agent_message("I can't help with that here. Here are some things I can help with: #{suggestions}.")
    end

    def reply_ambiguous(candidates)
      names = candidates.map { |i| i.to_s.tr('_', ' ') }
      append_agent_message("That could mean a couple of things — did you mean #{names.join(' or ')}? Could you clarify which one?")
    end

    def append_agent_message(content)
      @conversation.messages.create!(role: 'agent', content: content)
    end
  end
end
