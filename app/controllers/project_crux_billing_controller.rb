class ProjectCruxBillingController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    @plan_tier = 'Team (inherited from organization)'

    @stats = [
      { label: 'Outcomes This Period', value: '6' },
      { label: 'Shared Outcomes Cap', value: '500' },
      { label: 'Cost This Period', value: '$151' }
    ]

    @cost_per_agent = [
      { name: 'Planner', cost: '$62' },
      { name: 'QA Agent', cost: '$41' },
      { name: 'Documentation Agent', cost: '$30' },
      { name: 'Reporter', cost: '$18' }
    ]
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
