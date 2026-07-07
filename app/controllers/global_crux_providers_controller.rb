class GlobalCruxProvidersController < ApplicationController
  before_action :require_admin

  def index
    @providers = [
      { name: 'OpenAI', status: 'connected', model: 'gpt-4o' },
      { name: 'Anthropic', status: 'connected', model: 'claude-sonnet' },
      { name: 'Google Gemini', status: 'not_configured', model: '—' },
      { name: 'Azure OpenAI', status: 'not_configured', model: '—' },
      { name: 'Ollama', status: 'not_configured', model: '—' },
      { name: 'Local Models', status: 'not_configured', model: '—' },
      { name: 'Mock Provider', status: 'dev_only', model: 'mock-v1' }
    ]
  end
end
