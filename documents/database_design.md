# Crux Database Design

| | |
|---|---|
| **Document** | Schema Reference |
| **Status** | Canonical |
| **Audience** | Engineering, DBAs, Technical Reviewers |

## Purpose

This document is the authoritative field-level schema reference for the 11 canonical Crux tables. It defines every column, the relationships between tables, retention guidance, and indexing guidance. [architecture.md](architecture.md) names Run Ledger, Workflow Engine, and the others as modules; this document is where those modules' data actually lives. Every other document — [workflow_engine.md](workflow_engine.md), [agent_catalog.md](agent_catalog.md), [billing.md](billing.md), [analytics.md](analytics.md) — should treat table and column names here as fixed and link back rather than restate them.

## Scope

Covers: the 11 `crux_*` tables, their relationships, retention policy, and indexing guidance. Does not cover: Redmine's own Core Platform tables (Projects, Issues, Users, Roles, Wiki, Repository, Versions, Time Entries) — those are unmodified and owned by Redmine itself, referenced here only as foreign targets (e.g., `target_id` on a plan step). Does not cover query-level API contracts (see each module's detail doc).

## Responsibilities

The schema is responsible for making three governance guarantees structurally true, not just procedurally true:

- **Single source of truth for audit, billing, and analytics** — `crux_runs` and `crux_outcomes` are the only place a run or a billable event is recorded; no other table is allowed to duplicate that fact.
- **No dedicated "Pending Actions" table** — pending approvals are a status filter over `crux_plan_steps`, never a separately maintained copy that could drift from the plan steps themselves.
- **Traceability** — every row that represents an AI action can be traced back to the user who requested it, the agent that performed it, the plan step (if any) that authorized it, and the conversation it originated from.

## User Flow

Data flows through the schema in the same order a conversation progresses: a `crux_conversations` row is created when a user starts talking to an agent → each turn appends to `crux_messages` → once enough information exists, a `crux_execution_plans` row is created holding one or more `crux_plan_steps` → each approved step is executed by an agent, producing one `crux_runs` row → a completed, approved run may materialize a `crux_outcomes` row for billing. Configuration tables (`crux_agents`, `crux_knowledge_sources`, `crux_integrations`, `crux_settings`) are read at multiple points along this path rather than written by it. `crux_notifications` is written as a side effect of state changes anywhere in the path.

## UI Description

Each Project Workspace and Administration tab reads a specific slice of this schema:

| UI surface | Tables read |
|---|---|
| Chat tab | `crux_conversations`, `crux_messages` |
| Agents tab (project + admin) | `crux_agents` |
| Runs tab | `crux_runs`, `crux_outcomes` |
| Knowledge tab | `crux_knowledge_sources` |
| Automations tab | `crux_settings` (scope = project), `crux_integrations` |
| **Pending Actions** tab | `crux_plan_steps` filtered to `status = awaiting_approval` — no dedicated table (see Design Decisions) |
| Analytics tab (project + admin) | `crux_runs`, `crux_outcomes` (aggregated) |
| Billing (admin) | `crux_outcomes` |
| Audit Logs (admin) | `crux_runs` |
| Notifications (bell icon, all surfaces) | `crux_notifications` |

## Architecture

```
crux_agents                         crux_knowledge_sources        crux_integrations
   id (PK)                             id (PK)                       id (PK)
   project_id (FK, nullable)──┐        project_id (FK)                project_id (FK)
   name, role                 │        source_type, enabled           provider, config, enabled
   prompt_template            │
   model, fallback_model      │
   temperature, enabled       │
        │                     │
        │ 1                   │
        │                     │
        ▼ N                   │
crux_conversations             │              crux_settings
   id (PK)                     │                 key, value (PK-ish composite)
   project_id (FK) ────────────┘                 scope (global/project)
   user_id (FK → Redmine User)                    project_id (FK, nullable)
   agent_id (FK → crux_agents)
   state
   created_at
        │ 1
        │
        ▼ N
crux_messages                        crux_execution_plans
   id (PK)                              id (PK)
   conversation_id (FK) ───────────────►conversation_id (FK)  [1:1 or 1:N per conversation]
   role (user/agent/system)             status
   content                              estimated_time, estimated_cost
   created_at                           approved_by (FK → User), approved_at
                                              │ 1
                                              │
                                              ▼ N
                                        crux_plan_steps
                                           id (PK)
                                           plan_id (FK)
                                           action_type, target_type, target_id
                                           status   ◄── "Pending Actions" = filter on this column
                                           payload
                                              │ 0..1
                                              │
                                              ▼ N
crux_agents ──────────────────────────► crux_runs
   (agent_id FK)                           id (PK)
                                           agent_id (FK)
                                           plan_step_id (FK, nullable)
                                           user_id (FK → Redmine User)
                                           model, provider
                                           prompt_ref, context_refs
                                           tokens_in, tokens_out, cost
                                           output_ref
                                           created_at
                                              │ 1
                                              │
                                              ▼ 0..1
                                        crux_outcomes
                                           id (PK)
                                           run_id (FK)
                                           outcome_type
                                           project_id (FK)
                                           billed_at

crux_notifications
   id (PK)
   user_id (FK → Redmine User)
   event_type
   ref_type, ref_id   ◄── polymorphic pointer to conversation/run/plan_step/etc.
   read_at, created_at
```

Relationship summary: `crux_conversations` 1—N `crux_messages`; `crux_conversations` 1—N `crux_execution_plans`; `crux_execution_plans` 1—N `crux_plan_steps`; `crux_plan_steps` 1—N `crux_runs` (a plan step may be executed by exactly one run, or a run may exist outside any plan step for direct chat-only agent replies, hence nullable); `crux_runs` 1—0..1 `crux_outcomes` (only runs that produce a billable, approved deliverable materialize an outcome); `crux_agents` 1—N `crux_conversations` and 1—N `crux_runs`; `crux_knowledge_sources`, `crux_integrations`, and `crux_settings` are project-scoped configuration read by the engines, not written by conversation flow.

## Components

### crux_agents
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| name | Agent display name | e.g. "Planner" |
| role | Catalog role | See [agent_catalog.md](agent_catalog.md) for the 12 canonical roles |
| prompt_template | System prompt template | Tier-gated editability, see [billing.md](billing.md) |
| model | Primary model identifier | Resolved via the Provider Layer / Model Layer, see [architecture.md](architecture.md) |
| fallback_model | Fallback model identifier | Used on primary model failure |
| temperature | Sampling temperature | |
| enabled | Boolean | Per-agent on/off |
| project_id | FK to project, nullable | Null = global/default agent definition; non-null = project-specific override |

### crux_conversations
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| project_id | FK to project | Required; every conversation is project-scoped |
| user_id | FK to Redmine User | The human party |
| agent_id | FK to crux_agents | The agent party for this conversation |
| state | Workflow state | `draft, clarifying, planned, awaiting_approval, executing, completed` (+ `rejected`/`edited` looping to `planned`) — see [workflow_engine.md](workflow_engine.md) |
| created_at | Timestamp | |

### crux_messages
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| conversation_id | FK to crux_conversations | |
| role | Enum | `user`, `agent`, `system` |
| content | Message text | |
| created_at | Timestamp | Ordering key within a conversation |

### crux_execution_plans
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| conversation_id | FK to crux_conversations | |
| status | Plan status | Mirrors/drives the conversation's Workflow Engine state |
| estimated_time | Estimated execution duration | Shown in the approval preview |
| estimated_cost | Estimated cost | Shown in the approval preview; see [billing.md](billing.md) |
| approved_by | FK to Redmine User, nullable | Set only when a user with `crux:approve` (or `crux:approve_destructive`) approves |
| approved_at | Timestamp, nullable | Null until approved |

### crux_plan_steps
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| plan_id | FK to crux_execution_plans | |
| action_type | e.g. `create_issue`, `delete_milestone`, `deploy` | Destructive types require `crux:approve_destructive` |
| target_type | Polymorphic type of the Core Platform object affected | e.g. `Issue`, `Version`, `WikiPage` |
| target_id | Polymorphic id, nullable until the target exists | Null before creation, set after |
| status | Step status | `awaiting_approval, approved, rejected, executing, completed, failed` — **Pending Actions is this column filtered to `awaiting_approval`, not a separate table** |
| payload | Structured content of the proposed action | What the step will do if approved |

### crux_runs
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| agent_id | FK to crux_agents | |
| plan_step_id | FK to crux_plan_steps, nullable | Null for direct chat replies not tied to a plan step |
| user_id | FK to Redmine User | The user on whose behalf/authority the run executed |
| model | Model actually used | May differ from `crux_agents.model` if fallback triggered |
| provider | Provider actually used | See [architecture.md](architecture.md) (Provider Layer) |
| prompt_ref | Reference to the assembled prompt | Not the raw prompt text inline — a reference for size/retention reasons |
| context_refs | Reference(s) to Knowledge Engine retrieval results used | See [knowledge_engine.md](knowledge_engine.md) |
| tokens_in | Input token count | |
| tokens_out | Output token count | |
| cost | Computed cost for this run | Feeds [billing.md](billing.md) |
| output_ref | Reference to the run's output | |
| created_at | Timestamp | Append-only; this table is never updated after insert |

### crux_outcomes
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| run_id | FK to crux_runs | |
| outcome_type | Billable deliverable type | Materialized only for completed, approved runs |
| project_id | FK to project | Denormalized from the run's conversation for billing query performance |
| billed_at | Timestamp, nullable | Null until a billing cycle processes it |

### crux_knowledge_sources
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| project_id | FK to project | |
| source_type | One of the 11 canonical sources | Issues, Wiki, Repository, Documents, Files, News, Forums, Time Entries, Helpdesk, CRM, Custom Fields — see [knowledge_engine.md](knowledge_engine.md) |
| enabled | Boolean | Per-project toggle |

### crux_integrations
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| project_id | FK to project | |
| provider | One of the 12 canonical integrations | See [integrations.md](integrations.md) |
| config | Connection configuration | Credentials/tokens stored per platform security standards, never logged (see security-rules.md conventions) |
| enabled | Boolean | |

### crux_notifications
| Column | Description | Notes |
|---|---|---|
| id | Primary key | |
| user_id | FK to Redmine User | Recipient |
| event_type | e.g. `approval_pending`, `run_completed`, `run_failed` | |
| ref_type | Polymorphic type of the referenced object | e.g. `crux_plan_steps`, `crux_runs` |
| ref_id | Polymorphic id | |
| read_at | Timestamp, nullable | Null until acknowledged |
| created_at | Timestamp | |

### crux_settings
| Column | Description | Notes |
|---|---|---|
| key | Setting key | Part of composite identity |
| value | Setting value | |
| scope | `global` or `project` | |
| project_id | FK to project, nullable | Null when scope = global |

## Sequence Flow

Writes during one full conversation, in order:

```
1. INSERT crux_conversations           (state = draft)
2. INSERT crux_messages                (role = user, the initial prompt)
3. INSERT crux_messages                (role = agent, clarifying question)   [repeat 2-3 as needed]
4. UPDATE crux_conversations           (state = planned)
5. INSERT crux_execution_plans         (status = draft plan)
6. INSERT crux_plan_steps              (one or more rows, status = awaiting_approval)
7. UPDATE crux_conversations           (state = awaiting_approval)
8. UPDATE crux_execution_plans         (approved_by, approved_at set)
9. UPDATE crux_plan_steps              (status = approved, then executing, then completed/failed)
10. INSERT crux_runs                   (one row per agent invocation that executed a step)
11. INSERT crux_outcomes               (only for completed, approved, billable steps)
12. UPDATE crux_conversations          (state = completed)
13. INSERT crux_notifications          (event_type = run_completed)
```

Steps 9-11 repeat per plan step; a plan with N approved steps produces N (or fewer, if steps are grouped — see [architecture.md](architecture.md) Open Questions item 3) `crux_runs` rows.

## Design Decisions

- **Pending Actions has no dedicated table.** It is a status filter (`status = awaiting_approval`) over `crux_plan_steps`. A separate table would require the two to be kept in sync on every status transition, and any missed transition would show a stale or incorrect approval queue. A filtered view/query is used instead, guaranteeing the Pending Actions tab can never disagree with the plan step it's supposedly summarizing.
- **Run Ledger (`crux_runs` + `crux_outcomes`) is the single source of truth for audit, billing, and dashboards.** No shadow "billing_events" or "audit_log" table exists anywhere in the schema. Analytics Engine and Billing Engine both read directly from these two tables; this is enforced as a schema-level rule, not just a code-review convention (see [architecture.md](architecture.md) Design Decisions).
- **`crux_runs` is append-only.** Rows are never updated after insert; a retried or fallback-model run produces a new row rather than mutating the original, preserving a complete history of what was actually attempted.
- **`crux_outcomes.project_id` is deliberately denormalized** from the run's conversation, purely for billing query performance at scale — this is the one accepted exception to "derive, don't duplicate," justified because outcomes are queried far more often by project than joined through the full conversation chain.
- **`crux_plan_steps.target_id` is nullable** because a step proposing to *create* something has no target yet; it is populated once the Core Platform object exists.

## Assumptions

- Redmine's own `users` and `projects` tables are the FK targets for `user_id`/`project_id` throughout — Crux does not maintain parallel user or project tables.
- `crux_agents.project_id` nullable pattern (null = global default, non-null = project override) is the same pattern used for both agent definitions and settings scope, kept consistent across both tables intentionally.
- Token counts and cost on `crux_runs` are computed at write time from the provider's response, not recomputed later — historical cost figures are not retroactively adjusted if pricing changes.

## Risks

| Risk | Impact | Mitigation direction |
|---|---|---|
| `crux_messages` and `crux_runs` grow unbounded on high-traffic projects | Storage cost, slow queries over time | Retention guidance below; archive rather than delete where audit requirements apply |
| Missing index on `crux_plan_steps.status` | Slow Pending Actions queries as plan step volume grows | Explicit index requirement below |
| `crux_outcomes.project_id` denormalization drifts from the true project if a conversation is ever reassigned | Billing misattribution | Reassignment of a conversation's project is out of scope for Phase 1-3; if introduced later, must cascade to `crux_outcomes` |
| Polymorphic `ref_type`/`ref_id` on `crux_notifications` lacks a DB-level foreign key | Orphaned notifications if the referenced row is hard-deleted | Prefer soft-delete/status columns over hard deletes on referenced tables (`crux_plan_steps`, `crux_runs`) |

## Open Questions

1. Is "Create 84 Issues" one `crux_plan_steps` row with a payload describing 84 issues, or 84 individual rows? This directly determines Pending Actions UX (approve as a batch vs. individually) and `crux_runs` row cardinality — see [architecture.md](architecture.md) Open Questions item 3.
2. When one agent hands off to another mid-conversation, is that one `crux_runs` row or a chain of rows linked by a new field (e.g. `parent_run_id`, not yet in the schema above)? See [architecture.md](architecture.md) Open Questions item 4.
3. Does `crux_agents` need a distinct identity table if agent identity becomes a Redmine `User` subtype (see [architecture.md](architecture.md) Open Questions item 1) — would `crux_agents` then hold configuration only, with identity moved to Core Platform's `users` table?
4. Should `crux_runs.prompt_ref`/`context_refs`/`output_ref` point to a dedicated blob/object store, or to rows in a Crux-owned table? Not yet decided; affects retention tooling below.

## Best Practices

- **Foreign keys**: every `project_id`, `user_id`, `agent_id`, `conversation_id`, `plan_id`, `run_id` column should be indexed — these are the join and filter keys on nearly every query in the system.
- **Composite indexes**: index `(project_id, created_at)` on `crux_conversations`, `crux_runs`, and `crux_notifications` — the dominant query shape is "this project's recent activity."
- **Status filters**: index `crux_plan_steps.status` (and ideally `(plan_id, status)`) given Pending Actions depends entirely on this filter being fast.
- **Retention — `crux_runs`**: retain indefinitely by default (it is the audit and billing source of record); if storage policy requires trimming, archive `prompt_ref`/`context_refs`/`output_ref` payloads to cold storage before the summary row (tokens, cost, timestamps) is ever purged, since the summary row is what billing and audit need longest.
- **Retention — `crux_messages`**: retain per project data-retention policy configured in Administration → Policies; conversation transcripts are lower-stakes than the Run Ledger but still subject to the same permission model as the project itself.
- **Never add a new table to shadow `crux_runs`/`crux_outcomes`** for a new dashboard or report — extend the query, not the schema.

## Example Scenarios

**Scenario 1 — Pending Actions in practice.** A plan with 3 steps is awaiting approval. The Pending Actions tab runs one query: `crux_plan_steps` where `plan_id IN (user's visible plans)` and `status = 'awaiting_approval'`. The user approves 2 and rejects 1. No new table is touched beyond `crux_plan_steps.status` updates and the resulting `crux_runs`/`crux_notifications` rows for the approved steps.

**Scenario 2 — Billing reconciliation.** Finance asks "how many outcomes did Project X generate last month." The query joins `crux_outcomes` (filtered by `project_id` and `billed_at` range) back to `crux_runs` only if run-level detail (which agent, which model) is needed — the outcome count itself never requires touching `crux_plan_steps` or `crux_conversations` at all, because `crux_outcomes.project_id` was denormalized precisely for this query.

**Scenario 3 — Audit request.** A security reviewer asks "what did the Documentation Agent write to this project's wiki last quarter, and who approved it." The trace runs `crux_runs` (agent_id = Documentation Agent, project scoped via its conversation) → `crux_plan_steps` (via `plan_step_id`) → `crux_execution_plans.approved_by`/`approved_at`. No table in this chain could have been bypassed, because Workflow Engine never lets a step execute without that approval row being set first.

## Future Enhancements

- If agent handoff chaining (Open Question 2) is resolved in favor of chained rows, `crux_runs` will need a `parent_run_id` column — flagged here so [architecture.md](architecture.md) stays in sync when that decision lands.
- If plan-step granularity (Open Question 1) resolves toward per-item rows for bulk actions, expect `crux_plan_steps` volume to grow substantially for bulk-creation workflows — revisit indexing guidance above at that point.
- A dedicated object/blob store for `prompt_ref`/`context_refs`/`output_ref` (rather than same-database rows) is a likely Phase 2/3 change once payload sizes are measured in production.
