class GlobalCruxBillingController < ApplicationController
  before_action :require_admin

  def index
    @plan_tier = 'Team'

    @stats = [
      { label: 'Total Cost This Period', value: '$482' },
      { label: 'Outcomes Billed', value: '241' },
      { label: 'Outcomes / Month Cap', value: '500' },
      { label: 'Projected Period-End Cost', value: '$610' }
    ]

    @cost_per_project = [
      { name: 'CRM Platform', cost: '$184' },
      { name: 'Hospital Mgmt System', cost: '$151' },
      { name: 'Internal Ops', cost: '$147' }
    ]

    @tiers = [
      { capability: 'Agent editing', starter: 'Prompt text only', team: 'Full pipeline + prompt-template editing', enterprise: 'Full pipeline + prompt-template editing' },
      { capability: 'Knowledge indexing', starter: 'Hosted only', team: 'Hosted only', enterprise: 'Hosted or on-prem/local' },
      { capability: 'Integrations', starter: 'Core set, limited concurrency', team: 'Expanded set', enterprise: 'Full 12-integration catalog' },
      { capability: 'Outcomes/month', starter: 'Lowest cap', team: 'Mid cap', enterprise: 'Highest cap / negotiated' }
    ]
  end
end
