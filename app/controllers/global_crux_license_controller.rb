class GlobalCruxLicenseController < ApplicationController
  before_action :require_admin

  def index
    @plan_tier = 'Team'
    @seats = { used: 6, total: 25 }
  end
end
