# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# Global Crux (Administration)
get 'crux',           to: 'global_crux#show',            as: 'global_crux'
get 'crux/agents',    to: 'global_crux_agents#index',    as: 'global_crux_agents'
get 'crux/audit',     to: 'global_crux_audit#index',     as: 'global_crux_audit'
get 'crux/billing',   to: 'global_crux_billing#index',   as: 'global_crux_billing'
get 'crux/providers', to: 'global_crux_providers#index', as: 'global_crux_providers'
get 'crux/settings',  to: 'global_crux_settings#index',  as: 'global_crux_settings'

# Project Crux
get 'projects/:id/crux',          to: 'project_crux#index',          as: 'project_crux'
get 'projects/:id/crux/chat',     to: 'project_crux_chat#index',     as: 'project_crux_chat'
get 'projects/:id/crux/agents',   to: 'project_crux_agents#index',   as: 'project_crux_agents'
get 'projects/:id/crux/billing',  to: 'project_crux_billing#index',  as: 'project_crux_billing'
get 'projects/:id/crux/settings', to: 'project_crux_settings#index', as: 'project_crux_settings'
