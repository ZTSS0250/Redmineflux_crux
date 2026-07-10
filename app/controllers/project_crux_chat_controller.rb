class ProjectCruxChatController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @conversation = current_conversation

    respond_to do |format|
      format.html
      format.json { render json: conversation_json(@conversation) }
    end
  end

  def create_message
    text = params[:content].to_s.strip

    if text.blank?
      render json: { error: 'empty' }, status: :unprocessable_entity
      return
    end

    conversation = current_conversation
    message = conversation.messages.create!(role: 'user', content: text)

    Crux::ProcessChatTurnJob.perform_later(conversation.id, @project.id, User.current.id, text)

    render json: { status: 'ok', conversation_id: conversation.id, message: message_json(message) }
  end

  private

  # Reuses the existing draft/clarifying conversation for this project+user
  # if one exists, rather than starting a second one — this is what keeps a
  # reply sent while the first conversation is still `clarifying` from
  # silently becoming an unrelated second conversation (chat_engine.md).
  # Once a conversation reaches `planned` it's no longer "current" for this
  # task's purposes, so the next message starts a fresh one.
  def current_conversation
    Crux::Conversation
      .where(project_id: @project.id, user_id: User.current.id, state: %w[draft clarifying])
      .order(created_at: :desc)
      .first || Crux::Conversation.create!(project_id: @project.id, user_id: User.current.id, state: 'draft')
  end

  def conversation_json(conversation)
    {
      state: conversation.state,
      messages: conversation.messages.includes(:agent).map { |message| message_json(message) }
    }
  end

  def message_json(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      agent_name: message.agent&.name,
      at: view_context.format_time(message.created_at)
    }
  end
end
