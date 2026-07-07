class GlobalCruxAgentsController < ApplicationController
  before_action :require_admin

  def index
    @agents = [
      { name: 'Requirement Analyst', category: 'Requirements & Planning', phase: 'GA', status: 'enabled', model: 'gpt-4o' },
      { name: 'Planner', category: 'Requirements & Planning', phase: 'GA', status: 'enabled', model: 'gpt-4o' },
      { name: 'Developer', category: 'Engineering', phase: 'GA', status: 'enabled', model: 'claude-sonnet' },
      { name: 'QA Agent', category: 'Quality', phase: 'GA', status: 'enabled', model: 'claude-sonnet' },
      { name: 'Documentation Agent', category: 'Documentation', phase: 'GA', status: 'enabled', model: 'gpt-4o-mini' },
      { name: 'Reporter', category: 'Reporting', phase: 'GA', status: 'enabled', model: 'gpt-4o-mini' },
      { name: 'DevOps Agent', category: 'Operations', phase: 'GA', status: 'enabled', model: 'claude-sonnet' },
      { name: 'Security Agent', category: 'Security', phase: 'Phase 2/3', status: 'disabled', model: '—' },
      { name: 'Code Reviewer', category: 'Quality', phase: 'Phase 2/3', status: 'disabled', model: '—' },
      { name: 'Product Owner Agent', category: 'Requirements & Planning', phase: 'Phase 2/3', status: 'disabled', model: '—' },
      { name: 'Scrum Master Agent', category: 'Governance', phase: 'Phase 2/3', status: 'disabled', model: '—' },
      { name: 'Release Manager Agent', category: 'Operations', phase: 'Phase 2/3', status: 'disabled', model: '—' }
    ]
  end
end
