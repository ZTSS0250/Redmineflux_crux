class GlobalCruxAgentsController < ApplicationController
  before_action :require_admin
  before_action :find_agent, only: :update

  def index
    @agents = Crux::Agent.where(project_id: nil).order(:name)
  end

  def update
    @agent.update!(agent_params)
    redirect_to global_crux_agents_path, notice: l(:notice_successful_update)
  end

  private

  def find_agent
    @agent = Crux::Agent.where(project_id: nil).find(params[:id])
  end

  def agent_params
    params.require(:agent).permit(:enabled, :model, :fallback_model, :temperature)
  end
end
