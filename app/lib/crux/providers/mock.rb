module Crux
  module Providers
    # One of the 7 canonical providers named in architecture.md/
    # plugin_overview.md/glossary.md — not a testing shortcut invented for
    # crx-004. Returns deterministic, canned content keyed by agent role so
    # every agent can be built and QA'd without any external API key; real
    # adapters (OpenAI, Anthropic, Gemini, Azure OpenAI, Ollama, Local
    # Models) implement this same Crux::Providers::Base interface in crx-006.
    class Mock < Base
      # Planner's canned output is structured (an array of plan-step
      # descriptors), not prose — Crux::Agents::Runner consumes it directly
      # to create real crux_plan_steps rows. This is exactly the canonical
      # 7-step shape documented in approval_engine.md's worked example
      # ("Create Project · Generate Wiki · Create Versions · Generate
      # Milestones · Create 84 Issues · Assign Users · Generate
      # Documentation"). It deliberately excludes the destructive
      # delete_milestone step that crx-003's QA-only stub_plan_generator adds
      # on top of this same canonical shape for destructive-gate testing.
      CANONICAL_PLAN_STEPS = [
        { action_type: 'create_project', target_type: 'Project' },
        { action_type: 'generate_wiki', target_type: 'WikiPage' },
        { action_type: 'create_versions', target_type: 'Version', payload: { count: 3 } },
        { action_type: 'generate_milestones', target_type: 'Version', payload: { count: 3 } },
        { action_type: 'create_issues', target_type: 'Issue', payload: { count: 84 } },
        { action_type: 'assign_users', target_type: 'Issue' },
        { action_type: 'generate_documentation', target_type: 'WikiPage' }
      ].freeze

      def call(prompt:, context:, agent:)
        raise Error, "Simulated failure for #{agent.role}/#{context[:model]}" if context[:simulate_failure]

        content = canned_content_for(agent.role)
        { content: content, tokens_in: prompt.to_s.length, tokens_out: content.to_s.length }
      end

      private

      def canned_content_for(role)
        case role
        when 'requirement_analyst'
          'Structured requirements captured: goals, scope, and constraints extracted from this conversation. Handing off to the Planner.'
        when 'planner'
          CANONICAL_PLAN_STEPS
        when 'developer'
          'Suggested approach: outline the change at the file level, note risks, and flag any repository areas needing attention.'
        when 'qa_agent'
          'Draft test cases: one unit test, one functional test, and one edge case covering the primary flow described in this conversation.'
        when 'documentation_agent'
          "# Project Documentation\n\nAuto-generated overview of the project's purpose, modules, and current status."
        when 'reporter'
          "Summary: recent activity across this project's issues and versions, condensed into a short status update."
        when 'devops_agent'
          'Deployment checklist: verify environment configuration, run pre-deploy checks, and confirm a rollback plan before proceeding.'
        else
          "No canned Mock Provider response configured for role '#{role}'."
        end
      end
    end
  end
end
