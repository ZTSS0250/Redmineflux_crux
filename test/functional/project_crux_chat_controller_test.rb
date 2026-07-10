# frozen_string_literal: true

# ---------------------------------------------------------------------------
# Redmineflux Crux Plugin — ProjectCruxChatController Tests
# ---------------------------------------------------------------------------
# Project:     Redmineflux Crux
# Description: Regression coverage for the crux/chat/messages 403 bug —
#              :create_message was never registered under any permission,
#              so `authorize` rejected every user (including admins).
# Company:     Zehntech Technologies Inc.
# License:     Proprietary — All rights reserved
# ---------------------------------------------------------------------------

require File.expand_path('../../test_helper', __FILE__)

class ProjectCruxChatControllerTest < ActionController::TestCase
  tests ProjectCruxChatController

  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules

  def setup
    @project = Project.find(1)
    @project.enabled_module_names |= ['crux_ai']
    @project.save!
    @request.session[:user_id] = 1 # admin
  end

  def test_index_is_allowed
    get :index, params: { id: @project.identifier }
    assert_response :success
  end

  # Regression: :create_message was missing from the :use_crux permission's
  # action list in init.rb, so `authorize` 403'd everyone — including admin,
  # since Project#allows_to? rejects unregistered controller/action pairs
  # before the admin bypass in User#allowed_to? is ever reached.
  #
  # ProcessChatTurnJob is stubbed because test.rb runs ActiveJob inline —
  # letting it actually call Crux::ChatEngine would couple this
  # authorization-focused test to the chat engine's own (evolving) reply
  # behavior.
  def test_create_message_is_allowed_and_persists
    Crux::ProcessChatTurnJob.expects(:perform_later)

    assert_difference('Crux::Conversation.count', 1) do
      assert_difference('Crux::Message.count', 1) do
        post :create_message, params: { id: @project.identifier, content: 'order me a coffee' }
      end
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 'ok', json['status']
    assert_equal 'order me a coffee', json['message']['content']
  end

  def test_create_message_rejects_blank_content
    post :create_message, params: { id: @project.identifier, content: '  ' }

    assert_response :unprocessable_entity
  end
end
