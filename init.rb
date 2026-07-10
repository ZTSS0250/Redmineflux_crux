plugin_lib = File.expand_path('../lib', __FILE__)

Rails.configuration.to_prepare do
  require_relative 'lib/redmineflux_crux/hooks/crux_admin_hooks'
  require_relative 'lib/redmineflux_crux/seed/stub_plan_generator'
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

  # Canonical project-scoped permission set (security.md / glossary.md).
  # Global crux:administer is intentionally NOT declared here — Administration
  # → Crux controllers gate on Redmine's own `require_admin` (User#admin?),
  # matching the site-wide "Administrator" concept rather than a project role.
  project_module :crux_ai do
    permission :use_crux,
               :project_crux => [:index],
               :project_crux_chat => [:index, :create_message],
               :project_crux_agents => [:index],
               :project_crux_runs => [:index],
               :project_crux_settings => [:index]

    permission :crux_approve,
               :project_crux_pending_actions => [
                 :index, :approve_plan, :reject_plan, :approve_step, :reject_step, :modify_step
               ]

    permission :crux_approve_destructive, {}

    permission :crux_manage_agents, {}

    permission :crux_manage_knowledge,
               :project_crux_knowledge => [:index]

    permission :crux_manage_integrations,
               :project_crux_automations => [:index]

    permission :crux_view_billing, {}

    permission :crux_view_analytics,
               :project_crux_analytics => [:index]
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
