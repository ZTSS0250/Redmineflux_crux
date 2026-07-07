class GlobalCruxSettingsController < ApplicationController
  before_action :require_admin

  def index
    @settings = [
      { key: 'Default Provider', value: 'OpenAI' },
      { key: 'Default Model', value: 'gpt-4o' },
      { key: 'Fallback Model', value: 'gpt-4o-mini' },
      { key: 'Run Ledger Retention', value: 'Indefinite' },
      { key: 'Rate Limit (per user)', value: '60 requests / hour' },
      { key: 'Rate Limit (per project)', value: '500 requests / hour' },
      { key: 'Require crux:approve_destructive for Deploy', value: 'Yes' }
    ]
  end
end
