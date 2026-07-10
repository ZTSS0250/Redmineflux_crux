class ProjectCruxPendingActionsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize
  before_action :find_plan, only: [:approve_plan, :reject_plan]
  before_action :find_step, only: [:approve_step, :reject_step, :modify_step]

  def index
    @plans = Crux::ExecutionPlan
             .joins(:conversation)
             .where(crux_conversations: { project_id: @project.id }, status: 'awaiting_approval')
             .distinct
  end

  def approve_plan
    Crux::WorkflowEngine.approve!(plan: @plan, user: User.current)
    render json: plan_json(@plan.reload)
  rescue Crux::WorkflowEngine::TransitionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reject_plan
    Crux::WorkflowEngine.reject!(plan: @plan, user: User.current)
    render json: plan_json(@plan.reload)
  end

  def approve_step
    Crux::WorkflowEngine.approve!(plan: @step.execution_plan, user: User.current, step: @step)
    render json: plan_json(@step.execution_plan.reload)
  rescue Crux::WorkflowEngine::TransitionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def reject_step
    Crux::WorkflowEngine.reject!(plan: @step.execution_plan, user: User.current, step: @step)
    render json: plan_json(@step.execution_plan.reload)
  end

  def modify_step
    payload = @step.payload.merge(modify_params)
    Crux::WorkflowEngine.modify!(plan: @step.execution_plan, user: User.current, step: @step, payload: payload)
    render json: plan_json(@step.execution_plan.reload)
  rescue Crux::WorkflowEngine::TransitionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def find_plan
    @plan = Crux::ExecutionPlan
            .joins(:conversation)
            .where(crux_conversations: { project_id: @project.id })
            .find(params[:plan_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_step
    @step = Crux::PlanStep
            .joins(execution_plan: :conversation)
            .where(crux_conversations: { project_id: @project.id })
            .find(params[:step_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def modify_params
    params.require(:plan_step).permit(:assignee_id).to_h
  end

  def plan_json(plan)
    {
      status: plan.status,
      steps: plan.plan_steps.map { |step| { id: step.id, status: step.status } }
    }
  end
end
