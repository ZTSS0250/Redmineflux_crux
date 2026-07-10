module Crux
  # Rule/keyword-based classifier against the 21 canonical intents
  # (chat_engine.md). Deliberately makes no model call — see
  # crx-002-feature-conversation-chat-engine.md's Implementation Notes.
  # A future model-backed classifier is a drop-in replacement behind this
  # same `.call(text)` interface.
  class IntentClassifier
    INTENT_TRIGGERS = {
      # Project Setup
      create_project: [/\bcreate\s+(a|an)\b.*\b(project|system|app|application|crm|hrms|erp|platform)\b/i],
      generate_roadmap: [/\broadmap\b/i],

      # Planning
      generate_milestones: [/\bmilestones?\b/i],
      sprint_planning: [/\bsprint\s+plan/i],
      # "clean up the backlog" is intentionally listed under both
      # backlog_refinement and resolve_issue below — chat_engine.md's own
      # worked ambiguous example — so the classifier surfaces it as
      # ambiguous rather than silently picking one.
      backlog_refinement: [/\bbacklog\s+refin/i, /\bclean\s+up\s+the\s+backlog\b/i, /\bgroom\s+the\s+backlog\b/i],
      estimate_story_points: [/\bstory\s+points?\b/i],
      dependency_analysis: [/\bdependenc(y|ies)\b/i],

      # Development
      create_epics: [/\bcreate\s+.*\bepics?\b/i],
      create_issues: [/\bcreate\s+.*\bissues?\b/i],
      resolve_issue: [/\bresolve\s+.*\bissue\b/i, /\bfix\s+.*\bissue\b/i, /\bclose\s+.*\bissue\b/i, /\bclean\s+up\s+the\s+backlog\b/i],
      repository_analysis: [/\brepository\s+analysis\b/i, /\banalyz\w*\s+.*\brepository\b/i],

      # Documentation & Reporting
      generate_documentation: [/\bdocumentation\b/i],
      generate_release_notes: [/\brelease\s+notes?\b/i],
      daily_standup: [/\bdaily\s+standup\b/i, /\bstandup\b/i],
      weekly_summary: [/\bweekly\s+summary\b/i],
      project_health_report: [/\bhealth\s+report\b/i, /\bproject\s+health\b/i],

      # Analysis
      review_bugs: [/\breview\s+.*\bbugs?\b/i, /\bbug\s+review\b/i],
      generate_test_cases: [/\btest\s+cases?\b/i],
      knowledge_search: [/\bsearch\s+(the\s+)?(wiki|knowledge|docs)\b/i],
      requirement_generation: [/\brequirements?\s+generation\b/i, /\bgenerate\s+requirements?\b/i],
      risk_analysis: [/\brisk\s+(analysis|assessment)\b/i]
    }.freeze

    SUPPORTED_INTENTS = INTENT_TRIGGERS.keys.freeze

    # Returns a single Symbol for a clear match, :unclassified for no match,
    # or an Array of 2+ Symbols when the text matches more than one intent.
    def self.call(text)
      matches = INTENT_TRIGGERS.select { |_intent, patterns| patterns.any? { |pattern| text.to_s =~ pattern } }.keys

      case matches.size
      when 0 then :unclassified
      when 1 then matches.first
      else matches
      end
    end
  end
end
