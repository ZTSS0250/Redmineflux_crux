# frozen_string_literal: true

# ---------------------------------------------------------------------------
# Redmineflux Crux Plugin — ProjectCruxChatController Tests
# ---------------------------------------------------------------------------
# Project:     Redmineflux Crux
# Description: Regression coverage for two separate crux/chat 403 bugs —
#              (1) :create_message was never registered under any
#              permission, so `authorize` rejected every user (including
#              admins), and (2) the chat widget's poll() request used a
#              .json URL suffix, which Redmine's ApplicationController
#              treats as an API request and authenticates via API key
#              instead of the session cookie, silently becoming anonymous.
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

  # Regression: the chat widget's poll() call must ask for JSON via the
  # Accept header — an extensionless URL — NOT a `format: :json` URL
  # suffix. `params[:format] == 'json'` makes Redmine's api_request? return
  # true, which skips session[:user_id] authentication entirely (see
  # ApplicationController#find_current_user/#api_request?) and falls back
  # to API-key auth, which this in-browser poll never sends — silently
  # becoming anonymous and 403ing on :authorize, even though the same
  # session works fine for every other request on the page.
  def test_index_json_via_accept_header_stays_session_authenticated
    @request.headers['Accept'] = 'application/json'
    get :index, params: { id: @project.identifier }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?('messages')
  end

  # Documents the Redmine gotcha directly: a literal .json URL suffix is
  # treated as an API request and 403s even for a fully authenticated
  # session, because Redmine never looks at session[:user_id] for it. This
  # guards against ever reintroducing `format: :json` into the poll URL.
  def test_index_with_json_format_param_is_treated_as_api_request
    get :index, params: { id: @project.identifier, format: 'json' }

    assert_response :forbidden
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
