class ProjectCruxAutomationsController < ApplicationController
  include CruxProjectScoped
  before_action :authorize

  def index
  end
end
