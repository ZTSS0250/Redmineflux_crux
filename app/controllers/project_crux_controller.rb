class ProjectCruxController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @stats = [
      { label: 'AI Runs', value: '42' },
      { label: 'Outcomes', value: '6' },
      { label: 'Agents Enabled', value: '5' },
      { label: 'Pending Actions', value: '2' },
      { label: 'Token Usage', value: '128K' },
      { label: 'Coverage Score', value: '77%' }
    ]

    @recent_activity = [
      { text: 'Planner drafted "Create 84 Issues" plan', at: '2h ago' },
      { text: 'Documentation Agent generated Wiki page "API Overview"', at: '5h ago' },
      { text: 'QA Agent generated 12 test cases for #2031', at: '1d ago' },
      { text: 'DevOps Agent flagged environment drift', at: '2d ago' }
    ]
  end
end
