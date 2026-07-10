class ProjectCruxAgentsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @agents = Crux::Agent::ROLES.map { |role| Crux::Agent.effective(role: role, project: @project) }.compact
  end

  # Always writes/updates a project-scoped override row, cloning from the
  # global default the first time a project customizes a given agent
  # (agent_catalog.md "Per-project override" — project_id nullable pattern).
  # Submitting the form on a row that's still showing the global default
  # doesn't touch that global row; it creates the project's own override.
  def update
    base_agent = Crux::Agent.find(params[:agent_id])
    override = Crux::Agent.find_or_initialize_by(role: base_agent.role, project_id: @project.id)

    if override.new_record?
      override.assign_attributes(base_agent.attributes.except('id', 'project_id', 'created_at', 'updated_at'))
    end

    override.assign_attributes(agent_params)
    override.save!

    redirect_to project_crux_agents_path(@project), notice: l(:notice_successful_update)
  end

  private

  def agent_params
    params.require(:agent).permit(:enabled, :model, :fallback_model, :temperature)
  end
end
