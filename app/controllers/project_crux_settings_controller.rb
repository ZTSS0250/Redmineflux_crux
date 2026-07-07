class ProjectCruxSettingsController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    @settings = [
      { key: 'Knowledge Sources Enabled', value: 'Issues, Wiki, Repository' },
      { key: 'Coverage Score', value: '77%' },
      { key: 'Default Approval Policy', value: 'crux:approve required for all steps' },
      { key: 'Destructive Actions', value: 'crux:approve_destructive required' },
      { key: 'Notifications', value: 'In-app + Email' }
    ]
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
