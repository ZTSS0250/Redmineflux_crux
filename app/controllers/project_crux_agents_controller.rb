class ProjectCruxAgentsController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    @agents = [
      { name: 'Requirement Analyst', status: 'enabled', model: 'gpt-4o' },
      { name: 'Planner', status: 'enabled', model: 'gpt-4o' },
      { name: 'Developer', status: 'enabled', model: 'claude-sonnet' },
      { name: 'QA Agent', status: 'enabled', model: 'claude-sonnet' },
      { name: 'Documentation Agent', status: 'enabled', model: 'gpt-4o-mini' },
      { name: 'Reporter', status: 'enabled', model: 'gpt-4o-mini' },
      { name: 'DevOps Agent', status: 'disabled', model: '—' }
    ]
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
