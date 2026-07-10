class ProjectCruxAnalyticsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @stats = [
      { label: 'AI Runs', value: '0' },
      { label: 'Success %', value: '—' },
      { label: 'Token Usage', value: '0' },
      { label: 'Pending', value: '0' }
    ]
  end
end
