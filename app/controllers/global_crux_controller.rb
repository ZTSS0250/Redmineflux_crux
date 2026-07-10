class GlobalCruxController < ApplicationController
  before_action :require_admin

  def show
    @stats = [
      { label: 'Projects', value: '14' },
      { label: 'Projects Enabled', value: '6' },
      { label: 'AI Runs', value: '1,842' },
      { label: 'Pending Approvals', value: '5' },
      { label: 'Active Agents', value: '7' },
      { label: 'Token Usage', value: '842K' },
      { label: 'Version', value: '1.0.0' }
    ]

    @top_projects = [
      { name: 'CRM Platform', runs: 34 },
      { name: 'Hospital Mgmt System', runs: 28 },
      { name: 'Internal Ops', runs: 24 }
    ]

    @top_agents = [
      { name: 'Planner', share: '38%' },
      { name: 'QA Agent', share: '24%' },
      { name: 'Reporter', share: '19%' }
    ]
  end
end
