class ProjectCruxSettingsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @settings = [
      { key: 'Knowledge Sources Enabled', value: 'Issues, Wiki, Repository' },
      { key: 'Coverage Score', value: '77%' },
      { key: 'Default Approval Policy', value: 'crux:approve required for all steps' },
      { key: 'Destructive Actions', value: 'crux:approve_destructive required' },
      { key: 'Notifications', value: 'In-app + Email' }
    ]

    @show_usage = User.current.allowed_to?(:crux_view_billing, @project)
    if @show_usage
      @plan_tier = 'Team (inherited from organization)'
      @usage_stats = [
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
  end
end
