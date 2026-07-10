class GlobalCruxModelsController < ApplicationController
  before_action :require_admin

  def index
    @agent_models = [
      { agent: 'Requirement Analyst', model: 'gpt-4o', fallback: 'gpt-4o-mini', temperature: '0.2' },
      { agent: 'Planner', model: 'gpt-4o', fallback: 'gpt-4o-mini', temperature: '0.2' },
      { agent: 'Developer', model: 'claude-sonnet', fallback: 'gpt-4o-mini', temperature: '0.3' },
      { agent: 'QA Agent', model: 'claude-sonnet', fallback: 'gpt-4o-mini', temperature: '0.3' },
      { agent: 'Documentation Agent', model: 'gpt-4o-mini', fallback: '—', temperature: '0.4' },
      { agent: 'Reporter', model: 'gpt-4o-mini', fallback: '—', temperature: '0.5' },
      { agent: 'DevOps Agent', model: 'claude-sonnet', fallback: 'gpt-4o-mini', temperature: '0.2' }
    ]
  end
end
