module Crux
  # Runs Intent Detection/Clarification classification off the request
  # thread, per system_design.md's uniform-asynchronicity rule — enforced
  # even though this task's classification is cheap, so the pattern is
  # already in place for later tasks that add a real, slower model call
  # behind this same job.
  class ProcessChatTurnJob < ActiveJob::Base
    queue_as :default

    def perform(conversation_id, project_id, user_id, text)
      conversation = Crux::Conversation.find(conversation_id)
      project = Project.find(project_id)
      user = User.find(user_id)

      previous_user = User.current
      User.current = user
      begin
        Crux::ChatEngine.call(project: project, user: user, conversation: conversation, text: text)
      rescue StandardError => e
        Rails.logger.error("Crux::ProcessChatTurnJob failed for conversation ##{conversation_id}: #{e.class}: #{e.message}")
        conversation.messages.create!(role: 'system', content: 'Something went wrong processing that message. Please try again.')
      ensure
        User.current = previous_user
      end
    end
  end
end
