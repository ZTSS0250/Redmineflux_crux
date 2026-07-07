plugin_lib = File.expand_path('../lib', __FILE__)

Rails.configuration.to_prepare do
  require_relative 'lib/redmineflux_crux/hooks/crux_admin_hooks'
end

Redmine::Plugin.register :redmineflux_crux do
  name 'Redmineflux Crux plugin'
  author 'Zehntech Technologies Inc.'
  description <<~DESC
  Crux is an AI-native project collaboration plugin for Redmine that enables
  conversational project management, specialized AI agents, approval workflows,
  audit logging, and enterprise integrations to help teams plan, build, test,
  and manage projects more efficiently.
  DESC
  version '1.0.0'
  url 'https://www.redmineflux.com/plugins/crux'
  author_url 'https://www.zehntech.com'

  project_module :crux_ai do
    permission :view_crux_ai,
               :project_crux => [:index],
               :project_crux_chat => [:index],
               :project_crux_agents => [:index],
               :project_crux_billing => [:index],
               :project_crux_settings => [:index]
  end

  menu :project_menu, :crux_ai,
       { :controller => 'project_crux', :action => 'index' },
       :caption => Proc.new { I18n.t(:label_crux_ai_tab, :scope => :crux) },
       :param => :id,
       :if => Proc.new { |project| project.module_enabled?(:crux_ai) }

  menu :admin_menu, :global_crux,
       { :controller => 'global_crux', :action => 'show' },
       :caption => Proc.new { I18n.t(:label_global_crux, :scope => :crux) },
       :html => { :class => 'icon icon-crux-ai' }
end
