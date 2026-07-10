# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# Global Crux (Administration)
get 'crux',              to: 'global_crux#show',              as: 'global_crux'
get 'crux/general',      to: 'global_crux_general#index',      as: 'global_crux_general'
get 'crux/agents',       to: 'global_crux_agents#index',        as: 'global_crux_agents'
patch 'crux/agents/:id', to: 'global_crux_agents#update',        as: 'global_crux_agent'
get 'crux/providers',    to: 'global_crux_providers#index',     as: 'global_crux_providers'
get 'crux/models',       to: 'global_crux_models#index',        as: 'global_crux_models'
get 'crux/billing',      to: 'global_crux_billing#index',       as: 'global_crux_billing'
get 'crux/audit',        to: 'global_crux_audit#index',         as: 'global_crux_audit'
get 'crux/integrations', to: 'global_crux_integrations#index',  as: 'global_crux_integrations'
get 'crux/settings',     to: 'global_crux_settings#index',      as: 'global_crux_settings'
get 'crux/license',      to: 'global_crux_license#index',       as: 'global_crux_license'

# Project Crux
get 'projects/:id/crux',                 to: 'project_crux#index',                 as: 'project_crux'
get 'projects/:id/crux/chat',            to: 'project_crux_chat#index',            as: 'project_crux_chat'
post 'projects/:id/crux/chat/messages',  to: 'project_crux_chat#create_message',   as: 'project_crux_chat_messages'
get 'projects/:id/crux/agents',          to: 'project_crux_agents#index',          as: 'project_crux_agents'
patch 'projects/:id/crux/agents/:agent_id', to: 'project_crux_agents#update',       as: 'project_crux_agent'
get 'projects/:id/crux/runs',            to: 'project_crux_runs#index',            as: 'project_crux_runs'
get 'projects/:id/crux/knowledge',       to: 'project_crux_knowledge#index',       as: 'project_crux_knowledge'
get 'projects/:id/crux/automations',     to: 'project_crux_automations#index',     as: 'project_crux_automations'
get 'projects/:id/crux/pending_actions', to: 'project_crux_pending_actions#index', as: 'project_crux_pending_actions'
post 'projects/:id/crux/pending_actions/plans/:plan_id/approve', to: 'project_crux_pending_actions#approve_plan', as: 'project_crux_pending_action_plan_approve'
post 'projects/:id/crux/pending_actions/plans/:plan_id/reject',  to: 'project_crux_pending_actions#reject_plan',  as: 'project_crux_pending_action_plan_reject'
post 'projects/:id/crux/pending_actions/steps/:step_id/approve', to: 'project_crux_pending_actions#approve_step', as: 'project_crux_pending_action_step_approve'
post 'projects/:id/crux/pending_actions/steps/:step_id/reject',  to: 'project_crux_pending_actions#reject_step',  as: 'project_crux_pending_action_step_reject'
post 'projects/:id/crux/pending_actions/steps/:step_id/modify',  to: 'project_crux_pending_actions#modify_step',  as: 'project_crux_pending_action_step_modify'
get 'projects/:id/crux/analytics',       to: 'project_crux_analytics#index',       as: 'project_crux_analytics'
get 'projects/:id/crux/settings',        to: 'project_crux_settings#index',        as: 'project_crux_settings'
