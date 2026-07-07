# Crux — Project Memory

> Auto-loaded by Claude Code on every session opened in this directory. Read this first, before opening any of the 20 documents below — it exists so you don't have to re-derive the plugin's shape from scratch each session.

## What this project is

**Crux** (package/folder: `redmineflux_crux`) is a Redmine plugin, developed by Zehntech, that turns Redmine into an AI-native project management platform: AI agents act as governed team members — planning, analyzing, documenting, testing, reviewing, coordinating — instead of a chatbot bolted onto the side. Every AI action is permission-checked, logged, auditable, explainable, and requires human approval before it touches project data. See `[[project]]` note below for current status.

**Project key** (for the Zehntech SDD process defined in the global `CLAUDE.md`): **`crx`**. Once implementation tasks begin, they are filed as `backlog/planning/crx-{NNN}-{type}-{description}.md` per that process — this repo has no `backlog/` yet because nothing has moved past documentation.

**Current stage: documentation-only.** No Ruby/Rails code exists yet. Do not start implementing against this plugin unless the user explicitly asks to move a specific piece from documentation into the SDD `backlog/planning/` → `specification/` flow. If asked to "build Crux" or similar without more context, treat that as ambiguous and check which document/capability they mean first.

## Canonical kernel — the facts every document in this repo agrees on

These are the load-bearing facts. If you edit any document in this repo, keep it consistent with this kernel rather than the kernel with it — the kernel is the source of truth precisely because 20 documents were authored in parallel against it. If you need to change one of these facts, update it here and treat every document below as needing a matching edit.

**Vision statement** (verbatim, reused across docs):
> Crux transforms Redmine into an AI-Native Project Management Platform. Instead of AI being a chatbot, AI becomes a team member capable of planning, analyzing, documenting, testing, reviewing, coordinating, and assisting users throughout the complete project lifecycle. Crux operates as an AI layer inside Redmine — every action permission-aware, auditable, governed, explainable, and approved by humans. AI assists users; humans always make the final decision.

**Six core principles**: Conversation First · Human Approval · AI Agents as Team Members · Enterprise Governance · Project-Based & Modular · Secure by Construction. Full explanation in [vision.md](vision.md).

**19 architecture modules** (exact names — never invent alternates): Core Platform (Redmine itself) · Conversation Engine · Intent Detection · Clarification Engine · Chat Engine · Workflow Engine · Agent Engine · Knowledge Engine · Approval Engine · Run Ledger · Analytics Engine · Billing Engine · Integration Engine · Notification Engine · Administration · Project Workspace · Provider Layer · Model Layer · Future Marketplace (Phase 4, unbuilt). Full detail in [architecture.md](architecture.md).

**12 agents** — GA at launch: Requirement Analyst, Planner, Developer, QA Agent, Documentation Agent, Reporter, DevOps Agent. Added Phase 2/3: Security Agent, Code Reviewer, Product Owner Agent, Scrum Master Agent, Release Manager Agent. Full detail in [agent_catalog.md](agent_catalog.md).

**Data model** (11 tables, schema owned by [database_design.md](database_design.md) — link there, don't restate column lists): `crux_agents` · `crux_conversations` · `crux_messages` · `crux_execution_plans` · `crux_plan_steps` · `crux_runs` · `crux_outcomes` · `crux_knowledge_sources` · `crux_integrations` · `crux_notifications` · `crux_settings`. Pending Actions is a `status = awaiting_approval` filter on `crux_plan_steps`, never its own table. `crux_runs`/`crux_outcomes` are append-only and are the single source of truth for audit, billing, and analytics — never denormalize a shadow table.

**Permissions** (Redmine ACL pattern, no parallel system): `use_crux` · `crux:approve` · `crux:approve_destructive` · `crux:manage_agents` · `crux:manage_knowledge` · `crux:manage_integrations` · `crux:view_billing` · `crux:view_analytics` · `crux:administer`. Full RBAC table in [security.md](security.md).

**Project Workspace tabs** (9, in order): Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings.
**Administration tabs** (16): Dashboard, Agents, Providers, Models, Billing, Audit Logs, Usage, Knowledge, Projects, Permissions, Policies, Integrations, Settings, Health Monitoring, License, Future Features.
Both fully specified in [ui_design.md](ui_design.md).

**Conversation lifecycle** (state machine: `draft → clarifying → planned → awaiting_approval → executing → completed`, with `rejected`/edited looping back to `planned`): full detail in [workflow_engine.md](workflow_engine.md).

**Roadmap phases**: Phase 1 — Chat, Project Creation, Issue Creation, Planning, Approval Workflow. Phase 2 — Agent Collaboration, Multiple Providers, GitHub/Slack. Phase 3 — Automated Sprint Planning, Code Review, Test Generation, Knowledge Search, remaining agents. Phase 4 — Multi-Agent Workflows, MCP Support, Custom Agents, Marketplace. Full detail in [roadmap.md](roadmap.md).

**Open questions, not yet resolved anywhere** — don't assume an answer when writing new material: (1) is agent identity a dedicated `User` subtype or a lighter `Member` record; (2) is the first chat response ever synchronous, with only the agent run itself async; (3) is a bulk action like "Create 84 Issues" one `crux_plan_steps` row or many; (4) when one agent hands off to another mid-conversation, is that one `crux_runs` row or a chain.

## Document map

20 canonical documents, all at the repo root, each owning exactly one topic — cross-reference by link rather than restating another doc's content:

| Doc | Owns |
|---|---|
| [README.md](README.md) | Index and reading order for the set |
| [vision.md](vision.md) | Vision, mission, six principles, success criteria |
| [plugin_overview.md](plugin_overview.md) | At-a-glance product summary, competitive differentiation |
| [architecture.md](architecture.md) | The 19 modules and how they layer together |
| [system_design.md](system_design.md) | Plugin registration, async job model, NFRs, end-to-end sequence |
| [database_design.md](database_design.md) | Authoritative schema for all 11 `crux_*` tables |
| [ui_design.md](ui_design.md) | Workspace/Admin tab structure, wireframes, navigation, accessibility |
| [workflow_engine.md](workflow_engine.md) | Conversation state machine, plan-step lifecycle, destructive gate |
| [chat_engine.md](chat_engine.md) | Conversation Engine, Intent Detection, Clarification Engine |
| [agent_catalog.md](agent_catalog.md) | All 12 agents in full detail |
| [knowledge_engine.md](knowledge_engine.md) | Permission-filtered retrieval, knowledge sources, Coverage Score |
| [approval_engine.md](approval_engine.md) | Execution plan anatomy, Approve/Reject/Modify semantics |
| [integrations.md](integrations.md) | 12 external connectors + MCP inbound/outbound |
| [billing.md](billing.md) | Outcome-based billing, quotas, plan tiers |
| [security.md](security.md) | RBAC table, isolation, encryption, compliance |
| [analytics.md](analytics.md) | The 8 dashboards and their source tables |
| [roadmap.md](roadmap.md) | Phase 1–4 detail |
| [release_plan.md](release_plan.md) | Phase-to-release mapping, versioning, rollout |
| [future_scope.md](future_scope.md) | Beyond Phase 4 — marketplace, cross-project memory, etc. |
| [glossary.md](glossary.md) | Every canonical term, alphabetically |

Historical / non-canonical files also in this folder — read only if asked about project history, never as a source of current facts (they predate and are superseded by the kernel above):
- `design_documents.md` — earlier vision/UX draft, folded into vision.md/plugin_overview.md/ui_design.md
- `technical_design.md` — earlier engineering draft, folded into architecture.md/system_design.md/database_design.md
- `design_documents.html` — a styled, browsable single-file rendering of the original design_documents.md (superseded content-wise, kept as a demo artifact)
- `New Text Document.md` — an unrelated HTML mockup of a Redmine/Crux admin screen; not part of the documentation set

## Working conventions for this repo

- **One fact, one owning document.** Before adding a new fact (a name, a table, a tab list), check whether it already has an owner above — link to it instead of restating it.
- **Never introduce alternate names** for a canonical term (agent, module, table, permission, tab) — check [glossary.md](glossary.md) first.
- **This is documentation, not implementation.** No Ruby/Rails code, no SQL DDL, no JSON payloads belong in these `.md` files — they describe product and architecture decisions only.
- **All 20 documents share the same 15-section template** (Purpose, Scope, Responsibilities, User Flow, UI Description, Architecture, Components, Sequence Flow, Design Decisions, Assumptions, Risks, Open Questions, Best Practices, Example Scenarios, Future Enhancements) as top-level `##` headings — preserve that structure if you edit an existing doc or add a new one.
- When implementation eventually starts, follow the global Zehntech SDD process (`backlog/planning/` → three quality gates → `backlog/specification/` → code → `backlog/done/`) using the `crx` project key.
