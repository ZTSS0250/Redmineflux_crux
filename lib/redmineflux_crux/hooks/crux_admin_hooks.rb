module RedminefluxCrux
  module Hooks
    class CruxAdminHooks < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context = {})
        stylesheet_link_tag('administraction', plugin: 'redmineflux_crux')
      end
    end
  end
end
