module CruxProjectScoped
  extend ActiveSupport::Concern

  included do
    before_action :find_project
  end

  private

  def find_project
    @project = Project.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
