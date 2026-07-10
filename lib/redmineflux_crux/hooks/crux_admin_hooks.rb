module RedminefluxCrux
  module Hooks
    class CruxAdminHooks < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context = {})
        controller = context[:controller]
        return '' unless controller && controller.controller_name.to_s.start_with?('global_crux')

        stylesheet_link_tag('administration', plugin: 'redmineflux_crux')
      end
    end
  end
end
