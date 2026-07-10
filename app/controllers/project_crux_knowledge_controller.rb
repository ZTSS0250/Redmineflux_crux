class ProjectCruxKnowledgeController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @sources = [
      { name: 'Issues', enabled: false },
      { name: 'Wiki', enabled: false },
      { name: 'Repository', enabled: false },
      { name: 'Documents', enabled: false },
      { name: 'Files', enabled: false },
      { name: 'News', enabled: false },
      { name: 'Forums', enabled: false },
      { name: 'Time Entries', enabled: false },
      { name: 'Helpdesk', enabled: false },
      { name: 'CRM', enabled: false },
      { name: 'Custom Fields', enabled: false }
    ]
  end
end
