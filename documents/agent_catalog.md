# Agent Catalog

*The authoritative reference for all 12 Crux agents — what each one does, how it is configured, and what it is permitted to touch.*

## Purpose

This document is the single source of truth for the Crux agent roster — behavior, permissions, prompt structure, and invocation flow for all 12 agents. Other documents that mention a specific agent should link here rather than restate it, so a question like "what does the QA Agent do" has exactly one answer across the product.

## Scope

**In scope**: agent roster, per-agent behavior contract, configuration surface (`crux_agents`), permission gating, prompt template structure, agent-level execution flow.

**Out of scope**: Agent Engine internals and the 19-module architecture ([architecture.md](architecture.md)); plan/approval state machine ([approval_engine.md](approval_engine.md), `workflow_engine.md`); retrieval mechanics ([knowledge_engine.md](knowledge_engine.md)); full schema ([database_design.md](database_design.md)).

## Responsibilities

The agent roster, as a system, is responsible for:

- Covering the full project lifecycle (requirements → planning → build guidance → quality → documentation → reporting → operations) at GA, deepening governance and prioritization in Phase 2/3.
- Keeping every agent inside the permission boundary of the invoking user (Principle 6, Secure by Construction).
- Never executing a state-changing action without the Workflow Engine plan/approval gate — a direct chat reply is the only exempt output type.
- Staying configurable data (`crux_agents` rows), not hardcoded behavior, so operators can tune or disable agents without a deployment.

## User Flow

1. User writes a request, either general or addressed to a specific agent via the agent picker.
2. Intent Detection (and, for ambiguous requests, the Clarification Engine) routes it to one or more agents.
3. The agent returns a direct chat reply, or one or more `crux_plan_steps` inside an execution plan.
4. Any plan produced is reviewed through [approval_engine.md](approval_engine.md) before it executes.

## UI Description

- **Agent Settings** (admin, gated by `crux:manage_agents`): all 12 agents with enabled toggle, model, fallback model, temperature, and scope (global vs. project, reflecting `crux_agents.project_id`).
- **Agent picker**: addresses a specific agent from the conversation composer instead of relying on automatic routing.
- **Attribution badges**: chat messages and plan steps show which agent authored them (a wiki page traces to Documentation Agent, a test case to QA Agent).
- **Per-project overrides**: shows whether an agent is using the global default or a project-specific override.

## Architecture

Agents sit inside the Agent Engine, invoked by the Chat Engine after Intent Detection routes a request. The Agent Engine assembles context via the Knowledge Engine, calls a model through the Provider Layer/Model Layer, then returns a direct reply via the Chat Engine or hands structured output to the Workflow Engine as plan steps. See [architecture.md](architecture.md) for the full module map.

## Components

### Summary

| Agent | Category | Phase | Primary Output |
|---|---|---|---|
| Requirement Analyst | Requirements & Planning | GA (Launch) | Structured specification |
| Planner | Requirements & Planning | GA (Launch) | Roadmap, work breakdown, draft execution plan |
| Developer | Engineering | GA (Launch) | Implementation guidance |
| QA Agent | Quality | GA (Launch) | Test cases, bug/scenario review |
| Documentation Agent | Documentation | GA (Launch) | Wiki pages, technical docs, release notes |
| Reporter | Reporting | GA (Launch) | Standups, sprint reports, project summaries |
| DevOps Agent | Operations | GA (Launch) | Deployment guidance, environment validation, CI/CD assistance |
| Security Agent | Security | Phase 2/3 | Risk and vulnerability analysis |
| Code Reviewer | Quality | Phase 2/3 | Review feedback on changes |
| Product Owner Agent | Requirements & Planning | Phase 2/3 | Prioritized backlog |
| Scrum Master Agent | Governance | Phase 2/3 | Sprint plan, dependency/risk log |
| Release Manager Agent | Operations | Phase 2/3 | Release notes, release plan coordination |

All 12 rows share one schema, `crux_agents(id, name, role, prompt_template, model, fallback_model, temperature, enabled, project_id)`, where `project_id` is nullable to mean "global default." Details for each agent follow.

### Requirement Analyst

- **Purpose**: Converts a free-form idea into a structured, actionable specification for the rest of the agent chain.
- **Responsibilities**: Extract goals, scope, constraints from conversation; escalate ambiguity to the Clarification Engine instead of guessing; hand structured output to the Planner.
- **Capabilities**: Parses multi-turn context; produces requirement lists, module breakdowns, draft acceptance criteria.
- **Limitations**: Creates no Redmine objects itself; does not estimate time/cost (Planner's role); accuracy bounded by what the user provides.
- **Configuration**: `model`, `fallback_model`, `temperature` (low, for consistency), `enabled` via `crux_agents`; `project_id` nullable for a global default.
- **Prompt Template**: role block (business analyst), context block (conversation), constraint block (Redmine object vocabulary), output-format block (requirement list).
- **Execution Flow**: Chat Engine → Agent Engine assembles context via Knowledge Engine → model call → structured requirements → to Planner, or held pending clarification.
- **Permissions**: `use_crux` to invoke; output later feeds a plan gated by `crux:approve`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Conversation Engine, Clarification Engine, Knowledge Engine.
- **Future Roadmap**: reusable requirement templates by project type.

### Planner

- **Purpose**: Turns a requirement set into a roadmap, work breakdown, and a draft execution plan.
- **Responsibilities**: Sequence milestones and versions, draft `crux_plan_steps` for review, coordinate with Requirement Analyst and (later) Product Owner Agent input.
- **Capabilities**: Generates milestones, issue breakdowns, dependency ordering, draft `estimated_time`/`estimated_cost`.
- **Limitations**: Cannot execute steps itself; estimates are advisory until the [approval_engine.md](approval_engine.md) gate passes; does not resolve ambiguous requirements.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`; temperature kept low for deterministic breakdowns.
- **Prompt Template**: role block (delivery planner), context block (requirements + project settings), constraint block (object limits, naming conventions), output-format block (ordered plan steps).
- **Execution Flow**: invoked after Requirement Analyst → Agent Engine assembles project context via Knowledge Engine → model call → structured plan steps → Workflow Engine creates `crux_execution_plans`/`crux_plan_steps` in `planned` status.
- **Permissions**: `use_crux` to invoke; plan execution still requires `crux:approve` from a human.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine, Workflow Engine, Project Workspace.
- **Future Roadmap**: cross-project roadmap templates, capacity-aware scheduling.

### Developer

- **Purpose**: Produces implementation guidance for issues and tasks — never commits code directly.
- **Responsibilities**: Explain a technical approach, cite repository/wiki context, flag risks, suggest file-level changes as guidance text only.
- **Capabilities**: Reads Repository and Documents sources; drafts approach notes attached to an issue.
- **Limitations**: Does not write, commit, or run code or tests; quality depends on repository indexing.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (engineer advisor), context block (issue + repository excerpts), constraint block ("guidance only"), output-format block (approach + risks + files).
- **Execution Flow**: issue conversation → Agent Engine pulls Repository/Documents context via Knowledge Engine → model call → guidance as chat reply or note, optionally seeding a Documentation Agent step.
- **Permissions**: `use_crux`; read access bounded by the user's existing repository permissions (Principle 6).
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Repository, Documents), Integration Engine.
- **Future Roadmap**: review-ready change proposals pending human commit.

### QA Agent

- **Purpose**: Creates test cases and finds missing scenarios or bug patterns, before and after implementation.
- **Responsibilities**: Draft unit, functional, and edge-case test cases; review existing bug reports for gaps; flag untested paths.
- **Capabilities**: Generates structured test-case tables; cross-references issues and wiki content for acceptance criteria.
- **Limitations**: Cannot execute tests against a live system; relies on Developer/Requirement Analyst output for context accuracy.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (QA engineer), context block (issue/spec text), constraint block (test taxonomy: unit/functional/edge), output-format block (test-case table).
- **Execution Flow**: invoked from Chat Engine, or as a plan step after Developer guidance → Agent Engine assembles context via Knowledge Engine → model call → structured test cases → Workflow Engine plan step or issue comment.
- **Permissions**: `use_crux`; output is attached to issues the user can already access.
- **Supported Models**: any Provider Layer model, including the Mock Provider for offline test-case drafting.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Issues, Wiki), Workflow Engine.
- **Future Roadmap**: automated regression-suite generation, coverage-gap analytics.

### Documentation Agent

- **Purpose**: Produces wiki pages, technical documentation, and release notes from project activity.
- **Responsibilities**: Draft or update wiki content, summarize technical decisions, maintain release-note style entries.
- **Capabilities**: Generates structured wiki pages, technical write-ups, and changelog entries from issue/repository context.
- **Limitations**: A wiki write is still an ordinary, auditable plan step, not an instant publish; output quality depends on source completeness.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (technical writer), context block (issues/wiki/repository excerpts), constraint block (house style, audience), output-format block (wiki markup).
- **Execution Flow**: invoked from Chat Engine or as the "Generate Documentation" plan step → Agent Engine assembles context via Knowledge Engine → model call → draft wiki page → Workflow Engine plan step for approval.
- **Permissions**: `use_crux`; wiki writes are gated by ordinary `crux:approve`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Wiki, Documents, Issues), Project Workspace.
- **Future Roadmap**: multi-language documentation, auto-sync on merge.

### Reporter

- **Purpose**: Produces standups, project summaries, sprint reports, and weekly summaries.
- **Responsibilities**: Aggregate activity across issues, time entries, and versions into a digestible narrative with metrics.
- **Capabilities**: Generates standup digests, sprint narrative, weekly summaries, project health snapshots.
- **Limitations**: Read-only by nature — cannot alter project data; accuracy depends on the Coverage Score of enabled knowledge sources ([knowledge_engine.md](knowledge_engine.md)).
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (project analyst), context block (issues/time entries/analytics), constraint block (report period, audience), output-format block (structured summary).
- **Execution Flow**: invoked from Chat Engine or a schedule → Agent Engine assembles context via Knowledge Engine/Analytics Engine → model call → chat reply or Notification Engine broadcast; typically bypasses the plan/approval gate because it is read-only.
- **Permissions**: `use_crux`; view scope is bounded by the user's existing project access.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Analytics Engine, Knowledge Engine, Notification Engine.
- **Future Roadmap**: scheduled recurring reports, cross-project portfolio summaries.

### DevOps Agent

- **Purpose**: Provides deployment guidance, environment validation, and CI/CD assistance.
- **Responsibilities**: Explain deployment steps, validate environment/config readiness, draft CI/CD pipeline guidance — never deploys unsupervised.
- **Capabilities**: Reads Integration Engine connections (CI/CD, environments); drafts deployment checklists and rollback notes.
- **Limitations**: Cannot trigger a deploy itself; Deploy is a destructive action requiring an explicit human gate.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (DevOps engineer), context block (environment/integration state), constraint block ("guidance only, Deploy requires destructive approval"), output-format block (checklist/plan step).
- **Execution Flow**: invoked from Chat Engine → Agent Engine pulls integration/environment context via Knowledge Engine/Integration Engine → model call → a plan step such as "Deploy" submitted to Workflow Engine.
- **Permissions**: `use_crux` to invoke; a Deploy step it drafts requires `crux:approve_destructive`, not ordinary `crux:approve`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Integration Engine, Notification Engine, Workflow Engine.
- **Future Roadmap**: automated environment drift detection, guided rollback execution.

### Security Agent

*(Phase 2/3)*

- **Purpose**: Performs risk analysis, dependency analysis, and vulnerability review.
- **Responsibilities**: Scan repository/dependency metadata for known risk patterns, summarize findings with severity, recommend remediation as plan steps.
- **Capabilities**: Cross-references Repository/Documents knowledge sources against known risk patterns; drafts risk reports.
- **Limitations**: Advisory only — cannot patch or merge fixes; complements, rather than replaces, a dedicated scanning tool reached via Integration Engine.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`; disabled by default until a project opts in.
- **Prompt Template**: role block (security reviewer), context block (repository/dependency excerpts), constraint block (severity taxonomy), output-format block (finding + remediation plan step).
- **Execution Flow**: invoked from Chat Engine or a scheduled scan → Agent Engine assembles context via Knowledge Engine/Integration Engine → model call → findings → Workflow Engine plan step for remediation approval.
- **Permissions**: `use_crux`; findings are visible only within the requesting user's existing repository access.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Repository, Documents), Integration Engine.
- **Future Roadmap**: continuous background scanning, CVE feed integration.

### Code Reviewer

*(Phase 2/3)*

- **Purpose**: Reviews bugs and pull-adjacent changes, providing quality feedback.
- **Responsibilities**: Review diffs/changes surfaced via Integration Engine, flag style/logic/performance issues, suggest improvements as comments.
- **Capabilities**: Reads repository change context; generates structured review feedback comparable to a peer review.
- **Limitations**: Feedback only — cannot approve or merge changes; effectiveness depends on repository indexing depth.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (peer reviewer), context block (diff/change + related issue), constraint block (review checklist), output-format block (comment list by severity).
- **Execution Flow**: invoked from Chat Engine or an Integration Engine webhook → Agent Engine assembles context via Knowledge Engine → model call → structured review comments posted to the related issue/change.
- **Permissions**: `use_crux`; review scope is bounded by the user's existing repository access.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Repository), Integration Engine.
- **Future Roadmap**: inline diff-level annotations, review-quality trend tracking.

### Product Owner Agent

*(Phase 2/3)*

- **Purpose**: Assists with backlog refinement and requirement prioritization.
- **Responsibilities**: Re-rank backlog items against stated business goals, flag stale or duplicate issues, draft prioritization rationale.
- **Capabilities**: Cross-references Issues and Analytics Engine signals (age, activity) to propose ordering.
- **Limitations**: Prioritization is a recommendation only — reordering the live backlog is a plan step requiring `crux:approve`; it does not set business strategy.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (product owner), context block (backlog + goals), constraint block (prioritization framework), output-format block (ranked list + rationale).
- **Execution Flow**: invoked from Chat Engine → Agent Engine assembles context via Knowledge Engine/Analytics Engine → model call → proposed backlog order → Workflow Engine plan step.
- **Permissions**: `use_crux`; the reordering plan step still requires `crux:approve`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Knowledge Engine (Issues), Analytics Engine, Workflow Engine.
- **Future Roadmap**: goal-weighted auto-prioritization, stakeholder voting integration.

### Scrum Master Agent

*(Phase 2/3)*

- **Purpose**: Facilitates sprint planning and tracks dependencies and risks.
- **Responsibilities**: Draft sprint plans, surface cross-issue dependencies, maintain a running risk log, flag stalled items.
- **Capabilities**: Cross-references issues, versions, and Analytics Engine velocity data to flag risk.
- **Limitations**: Facilitation only — cannot reassign work or change dates without a plan step passing `crux:approve`.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (scrum master), context block (sprint/version + issue graph), constraint block (risk taxonomy), output-format block (sprint plan + risk/dependency log).
- **Execution Flow**: invoked from Chat Engine or a scheduled ceremony trigger → Agent Engine assembles context via Knowledge Engine/Analytics Engine → model call → sprint plan/risk log → chat reply or Workflow Engine plan step.
- **Permissions**: `use_crux`; date or assignment changes require `crux:approve`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Analytics Engine, Workflow Engine, Notification Engine.
- **Future Roadmap**: predictive risk scoring, automated ceremony scheduling.

### Release Manager Agent

*(Phase 2/3)*

- **Purpose**: Coordinates release notes and release plans.
- **Responsibilities**: Compile release notes from completed issues, draft a release plan/timeline, coordinate with the DevOps Agent on deployment sequencing.
- **Capabilities**: Cross-references issues, versions, and Documentation Agent output to assemble a release plan.
- **Limitations**: Cannot cut or deploy a release itself; any Deploy step it coordinates still requires `crux:approve_destructive`.
- **Configuration**: `model`/`fallback_model`/`temperature`/`enabled` via `crux_agents`.
- **Prompt Template**: role block (release manager), context block (version + issue history), constraint block (release-note format), output-format block (release notes + release plan).
- **Execution Flow**: invoked from Chat Engine or a version-close trigger → Agent Engine assembles context via Knowledge Engine → model call → release notes/plan → Workflow Engine plan step (may include a Deploy step).
- **Permissions**: `use_crux`; any Deploy step requires `crux:approve_destructive`.
- **Supported Models**: any Provider Layer model.
- **Memory**: per-conversation only.
- **Tools**: Workflow Engine, Integration Engine, Notification Engine, Knowledge Engine.
- **Future Roadmap**: automated multi-environment release trains.

## Sequence Flow

```
User
  │  message
  ▼
Chat Engine ──(Intent Detection)──▶ routes to agent(s)
  │
  ▼
Agent Engine ──context request──▶ Knowledge Engine
  │◀──────── ranked context ───────────┘
  │  prompt + context
  ▼
Provider Layer / Model Layer
  │  model output
  ▼
Agent Engine
  ├── direct reply ──▶ Chat Engine ──▶ User
  └── plan step(s) ──▶ Workflow Engine ──▶ Approval Engine ──▶ User
```

## Design Decisions

- **GA vs. Phase 2/3 split**: ship a complete lifecycle loop (requirements → plan → build guidance → QA → docs → report → ops) before adding governance and prioritization agents that assume the loop already works.
- **Agents are configuration, not code**: every agent is a `crux_agents` row with a `prompt_template`, editable without a redeploy.
- **`crux:manage_agents` is separate from `use_crux`**: configuring an agent is administrative; invoking it in conversation is routine — deliberately gated by different permissions.
- **Per-project override**: `project_id` is nullable so an organization sets a global default and lets projects override model, temperature, or enablement.

## Assumptions

- Companion documents follow the snake_case naming pattern of [architecture.md](architecture.md) and [database_design.md](database_design.md); this document links to `workflow_engine.md` and `permissions.md` on that assumption — reconcile if filenames differ.
- All 12 agents share the same `crux_agents` schema; none has bespoke database fields.
- "Prompt Template" here means structural sections, not a stored literal string — literal content is operational configuration, not documentation.

## Risks

- **Responsibility overlap**: QA Agent/Code Reviewer, or Planner/Product Owner Agent, could produce conflicting output if Intent Detection routing isn't tuned carefully.
- **Fallback model drift**: a silent fallback to `fallback_model` could change output tone mid-conversation unnoticed.
- **Destructive-adjacent agents**: DevOps Agent and Release Manager Agent both draft steps ending in a `crux:approve_destructive` gate; misconfiguration still raises blast radius even though execution is protected.

## Open Questions

- When Planner hands off to QA Agent within a single conversation, is that one [Run Ledger](database_design.md) row or a chain of rows? Multi-agent run attribution is undecided.
- Should Reporter's read-only output always pass through the Workflow Engine for audit uniformity, or may it bypass the plan/approval gate?
- Does `crux:manage_agents` let a project admin edit a global-scope agent, or only project-scoped ones?

## Best Practices

- Keep temperature low for agents producing structured plan steps (Requirement Analyst, Planner); allow more latitude for narrative agents (Reporter).
- Disable unused Phase 2/3 agents per project rather than leaving them enabled with no owner.
- Review `prompt_template` changes with the same rigor as a code change — they directly shape output and downstream plan steps.

## Example Scenarios

> User: "Create an HRMS." Crux asks: Which technology stack? Expected delivery timeline? Authentication method? Database? Expected modules? Deployment environment?

Requirement Analyst working with the Clarification Engine before anything reaches the Planner.

> "Create a CRM System with Customer, Leads, and Invoice modules" → Requirement Analyst → Planner drafts the plan.

The canonical hand-off: Requirement Analyst structures the request, Planner turns it into a draft execution plan (see [approval_engine.md](approval_engine.md)).

A third case: Developer posts implementation guidance on an issue, then QA Agent generates test cases against that same issue — two agents on one thread, neither executing anything directly.

## Future Enhancements

Cross-project agent memory; custom, user-defined agents via the Future Marketplace; agent-to-agent negotiation before a plan is submitted for approval; per-agent cost budgets tied to the Billing Engine.
