# Crux Architecture

| | |
|---|---|
| **Document** | Architecture Reference |
| **Status** | Canonical |
| **Audience** | Engineering, Solution Architects, Technical Reviewers |

> "Crux transforms Redmine into an AI-Native Project Management Platform. Instead of AI being a chatbot, AI becomes a team member capable of planning, analyzing, documenting, testing, reviewing, coordinating, and assisting users throughout the complete project lifecycle. Crux operates as an AI layer inside Redmine — every action permission-aware, auditable, governed, explainable, and approved by humans. AI assists users; humans always make the final decision."

---

## Purpose

This document is the authoritative reference for all 19 architecture modules that make up Crux. It defines what each module is responsible for, what it reads and writes, and where it sits relative to the others. Every other document in this set — [system_design.md](system_design.md), [database_design.md](database_design.md), [workflow_engine.md](workflow_engine.md), [agent_catalog.md](agent_catalog.md), [knowledge_engine.md](knowledge_engine.md), [billing.md](billing.md), [integrations.md](integrations.md), and the remainder of the module-level docs — treats the module names, boundaries, and read/write ownership defined here as fixed. Where a detail doc appears to conflict with this document, this document wins and the detail doc should be corrected.

## Scope

In scope: the 19 named modules, their layering, their dependencies on each other and on Redmine's Core Platform, and the high-level data each module owns. Out of scope: field-level schema (see [database_design.md](database_design.md)), request/job sequencing internals (see [system_design.md](system_design.md)), the full agent roster and prompt design (see [agent_catalog.md](agent_catalog.md)), and UI copy or screen-by-screen mockups (see [design_documents.md](design_documents.md)). This document describes structure, not behavior over time.

## Responsibilities

The architecture as a whole exists to make the six core principles true by construction rather than by convention:

1. **Conversation First** — the Conversation Engine, Intent Detection, Clarification Engine, and Chat Engine exist specifically so natural language is the primary interface.
2. **Human Approval** — no create, delete, close, deploy, or bulk-update path exists that bypasses the Workflow Engine's approval gate.
3. **AI Agents as Team Members** — the Agent Engine gives every agent a durable, configurable identity rather than a stateless prompt call.
4. **Enterprise Governance** — the Run Ledger is structurally the single place every action is recorded, so audit, billing, and analytics can never drift apart.
5. **Project-Based & Modular** — Project Workspace, Knowledge Engine, and Integration Engine are all scoped by `project_id`, so adoption is opt-in per project.
6. **Secure by Construction** — Knowledge Engine and Core Platform access is filtered through Redmine's own permission checks, not a parallel ACL system.

Each module subsection below states which of these it primarily upholds.

## User Flow

Architecture modules are invisible to end users, but every user-facing action traverses the same path: a user acts inside **Project Workspace** or **Administration** (top UI layer) → the action is handled by an **Engine** (Conversation, Workflow, Agent, Knowledge, or Integration) → the engine reads or writes through **Core Platform** (Redmine's own models) → the outcome is recorded in the **Run Ledger** → the user sees the result reflected back in the same UI, plus a **Notification** if the action completed asynchronously. No module skips a layer: UI never writes to Core Platform directly, and no engine writes to Core Platform without passing through the Workflow Engine's state machine first. See [system_design.md](system_design.md) for the full sequence.

## UI Description

Two top-level UI surfaces sit above the engine layer:

- **Administration** — 16 tabs: Dashboard, Agents, Providers, Models, Billing, Audit Logs, Usage, Knowledge, Projects, Permissions, Policies, Integrations, Settings, Health Monitoring, License, Future Features. Global scope, admin-only. See [ui_design.md](ui_design.md).
- **Project Workspace** — 9 tabs: Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings. Project scope, visible only when the project has enabled the Crux module. See [ui_design.md](ui_design.md).

Both surfaces are thin: they render state owned by the engine layer and submit user intent (prompts, approvals, configuration changes) back into it. Neither UI surface holds business logic of its own.

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │                  UI LAYER                    │
                    │  Administration Console   Project Workspace  │
                    │     (16 tabs, global)      (9 tabs, project) │
                    └───────────────────┬───────────────────────────┘
                                        │
                    ┌───────────────────▼───────────────────────────┐
                    │                 ENGINE LAYER                   │
                    │                                                │
                    │  Conversation Engine                           │
                    │   ├─ Intent Detection                          │
                    │   ├─ Clarification Engine                      │
                    │   └─ Chat Engine  (orchestrates the above)     │
                    │              │                                 │
                    │              ▼                                 │
                    │  Workflow Engine ──── Approval Engine (gate)   │
                    │              │                                 │
                    │              ▼                                 │
                    │  Agent Engine  ◀───────────────┐               │
                    │        │                        │               │
                    │        ▼                        │               │
                    │  Knowledge Engine          Provider Layer       │
                    │        │                    Model Layer         │
                    │        ▼                                        │
                    │  Run Ledger ──▶ Analytics Engine                │
                    │        │    ──▶ Billing Engine                  │
                    │        │                                        │
                    │  Integration Engine        Notification Engine  │
                    └───────────────────┬───────────────────────────┘
                                        │
                    ┌───────────────────▼───────────────────────────┐
                    │             CORE PLATFORM (Redmine)            │
                    │  Projects · Issues · Users · Roles · Wiki ·    │
                    │  Repository · Versions · Time Entries          │
                    │  Crux reads/writes through it, never around it │
                    └─────────────────────────────────────────────────┘

                    ┌─────────────────────────────────────────────┐
                    │   Future Marketplace  (Phase 4 — not built)  │
                    └─────────────────────────────────────────────┘
```

The layering rule is strict: each layer only calls the layer directly beneath it. The UI layer never touches Core Platform directly; the Engine layer never bypasses the Workflow Engine's approval gate to reach Core Platform; Provider Layer and Model Layer are only ever called by Agent Engine, never by UI or by other engines directly.

## Components

### Core Platform
Redmine itself — Projects, Issues, Users, Roles, Wiki, Repository, Versions, Time Entries. Crux reads and writes this data exclusively through Redmine's own models and permission checks; it is never duplicated into a shadow copy. This is the structural basis of principle 6, Secure by Construction. See [system_design.md](system_design.md).

### Conversation Engine
Owns per-turn dialogue state and message history for a user–agent exchange. Reads and writes `crux_conversations` and `crux_messages`, and hands control to Workflow Engine once enough information exists to build a plan. Upholds principle 1, Conversation First. See [chat_engine.md](chat_engine.md).

### Intent Detection
Classifies each inbound message (create, plan, report, review, question, etc.) so the correct agent and downstream path are chosen. Reads message text and recent conversation history; writes a classification result attached to the turn, not a new table. See [chat_engine.md](chat_engine.md).

### Clarification Engine
Determines whether Crux has enough information to generate an execution plan; if not, produces targeted follow-up questions and holds the conversation at `clarifying` until answered. Reads `crux_messages` and Knowledge Engine context; writes new question messages back into the conversation. See [chat_engine.md](chat_engine.md).

### Chat Engine
The orchestration shell that sequences Intent Detection, Clarification Engine, and Conversation Engine into one user-facing turn, and is the entry point the Project Workspace **Chat** tab talks to. It decides, turn by turn, whether to keep clarifying or move to plan generation. See [chat_engine.md](chat_engine.md).

### Workflow Engine
Owns the conversation-level state machine: `draft → clarifying → planned → awaiting_approval → executing → completed`, with `rejected`/`edited` looping back to `planned`. Reads and writes `crux_conversations.state` and `crux_execution_plans`; every plan step transition is gated here. Upholds principle 2, Human Approval. See [workflow_engine.md](workflow_engine.md).

### Agent Engine
Hosts the 12-agent catalog — definitions, prompts, model assignment, per-project enablement — and runs each invocation as an asynchronous job. Reads `crux_agents`; writes `crux_runs` and populates `crux_plan_steps` or direct chat output. Upholds principle 3, AI Agents as Team Members. See [agent_catalog.md](agent_catalog.md).

### Knowledge Engine (Context Engine)
Provides permission-filtered retrieval across the 11 knowledge sources (Issues, Wiki, Repository, Documents, Files, News, Forums, Time Entries, Helpdesk, CRM, Custom Fields) for a given user and project — filtering the allowed-source set before ranking, not after. Reads Core Platform data and `crux_knowledge_sources`; writes only retrieval references consumed by `crux_runs.context_refs`. Upholds principle 6, Secure by Construction. See [knowledge_engine.md](knowledge_engine.md).

### Approval Engine
The plan-and-gate mechanism embedded inside Workflow Engine: no plan step executes without `approved_by`/`approved_at` set by a user holding `crux:approve` (or `crux:approve_destructive` for destructive steps). Reads and writes `crux_execution_plans` and `crux_plan_steps.status`. It is a specialization of Workflow Engine, not a separate state machine. See [workflow_engine.md](workflow_engine.md).

### Run Ledger
Append-only record of every agent run — the single source of truth feeding Audit Logs, Billing, and dashboards, never denormalized into a shadow copy. Writes `crux_runs` and `crux_outcomes`; read by Analytics Engine, Billing Engine, and Administration. Upholds principle 4, Enterprise Governance. See [database_design.md](database_design.md).

### Analytics Engine
Aggregates Run Ledger and outcome data into project and admin dashboards — success rate, most active agent, token usage, top projects. Strictly read-only against `crux_runs`/`crux_outcomes`; writes nothing. See [analytics.md](analytics.md).

### Billing Engine
Meters `crux_outcomes` against subscription plans and enforces quota at the Workflow Engine and Knowledge Engine boundaries (active projects, indexed sources, outcomes/month). Reads `crux_runs`/`crux_outcomes`; writes billing state only, never ledger rows. See [billing.md](billing.md).

### Integration Engine
Hosts the 12 connectors (GitHub, GitLab, Bitbucket, Slack, Microsoft Teams, Jenkins, Azure DevOps, Webhooks, MCP, Email, Calendar, Future Marketplace). Reads and writes `crux_integrations` config; every external write it initiates still funnels back through the Workflow Engine's approval gate as a normal plan step. See [integrations.md](integrations.md).

### Notification Engine
Delivers in-app and external notifications for pending approvals, run completions, and errors. Reads and writes `crux_notifications`, setting `read_at` on acknowledgment; triggered by state transitions in Workflow Engine and Run Ledger writes. See [workflow_engine.md](workflow_engine.md).

### Administration
The global admin surface spanning all 16 Administration tabs. Reads across nearly every `crux_*` table to build dashboards; writes `crux_settings` (scope = global) and global-scope `crux_agents`. See [ui_design.md](ui_design.md).

### Project Workspace
The per-project surface spanning all 9 workspace tabs. Reads and writes project-scoped rows across most `crux_*` tables, and only renders when the project has enabled the Crux module gate. Upholds principle 5, Project-Based & Modular. See [ui_design.md](ui_design.md).

### Provider Layer
Abstracts the AI vendor connection (OpenAI, Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models, Mock Provider, Future Providers) behind one interface that Agent Engine calls. Reads `crux_settings` for provider credentials and configuration; writes only call telemetry passed on to Run Ledger. See [billing.md](billing.md).

### Model Layer
Sits beneath Provider Layer: per-agent model and fallback-model selection, temperature, and context-window limits. Reads `crux_agents.model`/`fallback_model`; feeds the `model`/`provider`/`tokens_in`/`tokens_out` fields Run Ledger records for every run. See [billing.md](billing.md).

### Future Marketplace
Phase 4, not built. A planned exchange for custom agents, prompt templates, and third-party connectors, layered outside the current engine stack until scoped. See [roadmap.md](roadmap.md).

## Sequence Flow

The conversation lifecycle maps directly onto the module stack:

```
User Prompt
   │
   ▼
Intent Detection ──▶ Knowledge Engine (context search, permission-filtered)
   │
   ▼
Clarification Engine ── needs more info? ──yes──▶ Ask Questions ──▶ Receive Answers ──┐
   │no                                                                                 │
   ◀────────────────────────────────────────────────────────────────────────────────┘
   ▼
Agent Engine generates Execution Plan  (Workflow Engine: state → planned)
   │
   ▼
Preview shown in Project Workspace  (Workflow Engine: state → awaiting_approval)
   │
   ▼
User Approval  (Approval Engine checks crux:approve / crux:approve_destructive)
   │
   ▼
Execute Tasks via Core Platform  (Workflow Engine: state → executing)
   │
   ▼
Run Ledger records run + outcome  (state → completed)
   │
   ├──▶ Analytics Engine (dashboards update)
   ├──▶ Billing Engine (outcome metered)
   └──▶ Notification Engine (user notified)
```

A full walk-through with timing and job boundaries is in [system_design.md](system_design.md).

## Design Decisions

- **Workflow Engine absorbs Approval Engine.** Chat/conversation flow and the approval gate are one state machine, not two, because splitting them previously produced disagreement about which one owns `awaiting_approval`. Approval Engine is documented separately only because it is a large enough concern to deserve its own detail doc.
- **Knowledge Engine filters before it ranks.** Permission filtering happens against the candidate source set first; ranking/retrieval only ever sees data the acting user could already see in Redmine. This ordering is non-negotiable — reversing it would make "secure by construction" a policy statement instead of a structural fact.
- **Run Ledger is the only audit/billing/analytics source.** Analytics Engine and Billing Engine are read-only consumers of Run Ledger; neither is allowed a materialized copy that could drift from it.
- **Provider Layer and Model Layer are separate modules** even though they are adjacent, because provider selection (which vendor) and model selection (which model, temperature, fallback) vary independently — a project might keep its provider but change model tier, or vice versa.
- **Integration Engine cannot bypass Workflow Engine.** Inbound MCP calls and outbound connector actions are both plan steps subject to the same approval gate as chat-originated actions — an external tool does not get a shortcut around governance.

## Assumptions

- A single Crux plugin installation serves one Redmine instance; multi-instance federation is not modeled.
- All 19 modules ship together at Phase 1 architecturally, even though agent count, provider count, and integration count grow across phases (see [roadmap.md](roadmap.md)) — the module boundaries themselves do not change across phases.
- Core Platform is never modified by Crux; Redmine upgrades are assumed to preserve the model/permission APIs Crux depends on.

## Risks

| Risk | Impact | Mitigation direction |
|---|---|---|
| Engine layer sprawl (19 modules) increases coordination cost across 6 parallel authors | Inconsistent terminology or duplicated logic across detail docs | This document is the single source of truth for module boundaries; detail docs defer to it |
| Knowledge Engine permission-filter ordering implemented incorrectly at code time | Silent data leakage across roles | Gate 2 (Security & Performance Review) in the SDD process specifically checks retrieval-before-filter ordering |
| Run Ledger treated as one-of-many audit sources instead of the only one | Billing/audit drift, double counting | Enforce at schema level — no parallel "billing_events" or "audit_log" table is created (see [database_design.md](database_design.md)) |
| Provider/Model Layer abstraction leaks vendor-specific behavior into Agent Engine | Harder to add new providers or models later | Keep provider-specific code isolated behind one interface, no agent-side branching on provider name |

## Open Questions

1. Is agent identity a dedicated `User` subtype or a lighter `Member` record — affects licensing math and which module (Agent Engine vs. Core Platform) owns agent identity rows.
2. Is the first response to a prompt ever synchronous (fast Intent Detection), with only the Agent Engine run itself asynchronous? Affects perceived latency at the Chat Engine boundary.
3. Is "Create 84 Issues" one `crux_plan_steps` row or 84 — affects Approval Engine UX and Run Ledger row count.
4. When one agent hands off to another within a conversation (Agent Engine → Agent Engine), is that one Run Ledger row or a chain?

## Best Practices

- Never let a UI layer component (Administration or Project Workspace) call Core Platform directly — always through an engine.
- Never add a new table or cache that duplicates Run Ledger data for convenience; add a read-optimized view or index instead.
- When adding a new integration or provider, extend Integration Engine / Provider Layer's existing interface rather than special-casing it in Agent Engine or Workflow Engine.
- Keep Knowledge Engine's permission-filter step as the first operation in any retrieval path, not a post-filter.
- Treat module names in this document as fixed identifiers in code, config, and other docs — do not introduce synonyms (e.g., "Context Engine" is acceptable only as the parenthetical alias of Knowledge Engine, nowhere else).

## Example Scenarios

**Scenario 1 — Straightforward creation.** A user types "Create a CRM project with Customer, Leads, and Invoice modules" in Project Workspace's Chat tab. Chat Engine routes through Intent Detection (intent: `create_project`) and Knowledge Engine (no clarification needed — enough detail given). Agent Engine's Planner agent drafts an Execution Plan; Workflow Engine moves to `awaiting_approval`; the user approves; Core Platform creates the project, versions, and issues; Run Ledger records the run; Notification Engine confirms completion.

**Scenario 2 — Under-specified request needing clarification.** A user types "Build an HR system." Clarification Engine determines module count, auth method, and stack are unspecified and asks three questions via Conversation Engine. Workflow Engine holds state at `clarifying` until answered, then proceeds identically to Scenario 1.

**Scenario 3 — Destructive action.** An agent's recommended clean-up step includes deleting a stale milestone. Approval Engine requires `crux:approve_destructive` specifically, distinct from the ordinary `crux:approve` used for the rest of the plan — a project lead without destructive-approval rights can approve everything except that one step.

## Future Enhancements

- Future Marketplace (Phase 4) will require a new module boundary for publishing/consuming custom agents and connectors — likely inserted between Agent Engine and Integration Engine.
- Multi-instance/federated Crux (multiple Redmine instances sharing one Provider Layer account) is not scoped but would affect Provider Layer and Billing Engine most directly.
- As agent count grows past the 12 in the current catalog, Agent Engine may need a sub-categorization layer (e.g., by lifecycle stage) — not required for Phase 1–3.
