class ProjectCruxRunsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
    @runs = []
  end
end
