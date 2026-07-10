class GlobalCruxIntegrationsController < ApplicationController
  before_action :require_admin

  def index
    @integrations = [
      { name: 'GitHub', status: 'not_configured' },
      { name: 'GitLab', status: 'not_configured' },
      { name: 'Bitbucket', status: 'not_configured' },
      { name: 'Slack', status: 'not_configured' },
      { name: 'Microsoft Teams', status: 'not_configured' },
      { name: 'Jenkins', status: 'not_configured' },
      { name: 'Azure DevOps', status: 'not_configured' },
      { name: 'Webhooks', status: 'not_configured' },
      { name: 'MCP', status: 'not_configured' },
      { name: 'Email', status: 'not_configured' },
      { name: 'Calendar', status: 'not_configured' },
      { name: 'Future Marketplace', status: 'not_configured' }
    ]
  end
end
