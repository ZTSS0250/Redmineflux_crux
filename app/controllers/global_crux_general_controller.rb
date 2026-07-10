class GlobalCruxGeneralController < ApplicationController
  before_action :require_admin

  def index
    plugin = Redmine::Plugin.find(:redmineflux_crux)
    @plugin_info = {
      name: plugin.name,
      version: plugin.version,
      description: plugin.description,
      author: plugin.author,
      url: plugin.url
    }
  end
end
