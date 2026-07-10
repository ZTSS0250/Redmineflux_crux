class ProjectCruxPendingActionsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @pending_count = 0
  end
end
