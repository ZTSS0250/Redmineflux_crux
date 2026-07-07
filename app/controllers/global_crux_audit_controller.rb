class GlobalCruxAuditController < ApplicationController
  before_action :require_admin

  def index
    @runs = [
      { id: '10482', agent: 'Documentation Agent', project: 'CRM Platform', user: 'J. Mehta', action: 'Generate Wiki', model: 'gpt-4o', tokens: '3,210', cost: '$0.08', status: 'completed', at: '2026-07-06 14:12' },
      { id: '10481', agent: 'Planner', project: 'Hospital Mgmt System', user: 'A. Rao', action: 'Create 84 Issues', model: 'gpt-4o', tokens: '18,940', cost: '$0.42', status: 'completed', at: '2026-07-06 11:45' },
      { id: '10480', agent: 'QA Agent', project: 'Internal Ops', user: 'S. Iyer', action: 'Generate Test Cases', model: 'claude-sonnet', tokens: '5,120', cost: '$0.11', status: 'completed', at: '2026-07-05 17:03' },
      { id: '10479', agent: 'DevOps Agent', project: 'CRM Platform', user: 'J. Mehta', action: 'Deploy', model: 'claude-sonnet', tokens: '1,880', cost: '$0.05', status: 'failed', at: '2026-07-05 09:22' },
      { id: '10478', agent: 'Reporter', project: 'Internal Ops', user: 'S. Iyer', action: 'Weekly Summary', model: 'gpt-4o-mini', tokens: '2,430', cost: '$0.02', status: 'completed', at: '2026-07-04 08:00' }
    ]
  end
end
