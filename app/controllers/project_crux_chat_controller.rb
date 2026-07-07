class ProjectCruxChatController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    @messages = [
      { role: 'agent', name: 'Requirement Analyst', text: "Hi! Tell me what you'd like to build or change in this project, and I'll help turn it into a plan.", at: '10:01 AM' },
      { role: 'user', name: 'You', text: 'Create a CRM System with Customer, Leads, and Invoice modules.', at: '10:02 AM' },
      { role: 'agent', name: 'Requirement Analyst', text: 'A few questions before I proceed: Which technology stack? Expected delivery timeline? Authentication method? Database?', at: '10:02 AM' }
    ]
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
