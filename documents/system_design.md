# Crux System Design

| | |
|---|---|
| **Document** | Cross-Cutting Technical Design |
| **Status** | Canonical |
| **Audience** | Engineering, Solution Architects |

## Purpose

This document specifies how Crux is actually wired into Redmine as a plugin, and the cross-cutting technical concerns that no single module in [architecture.md](architecture.md) fully owns: plugin registration, the project-level module gate, the asynchronous execution pattern, multi-tenancy/project isolation, and non-functional requirements. Where [architecture.md](architecture.md) answers "what are the modules," this document answers "how does a request actually move through them, and what does the platform guarantee while it does."

## Scope

Covers: Redmine plugin registration mechanics (conceptually, not as code), the `project_module :crux` gate, background job execution for agent runs, an end-to-end sequence for one full conversation, project isolation, and scalability/latency/availability expectations. Does not cover: individual module internals (see each module's detail doc), schema (see [database_design.md](database_design.md)), or the agent catalog (see [agent_catalog.md](agent_catalog.md)).

## Responsibilities

System design is responsible for guaranteeing three things that cut across every module in [architecture.md](architecture.md):

- **Gating** — a project that has not opted into Crux has zero exposure to it: no menu entry, no route, no data written. This is the technical backbone of principle 5, Project-Based & Modular.
- **Non-blocking execution** — no model call ever runs on the request thread that served a user's HTTP action. This is what keeps Chat Engine responsive regardless of Agent Engine/Provider Layer latency.
- **Isolation** — one project's conversations, runs, and knowledge sources are never visible to, or retrievable by, another project's users, agents, or knowledge search.

## User Flow

From a systems perspective, a user's action takes one of two shapes:

- **Read-mostly / chat turn** — user sends a message, expects to see a reply (possibly a clarifying question) in the same interaction. Handled synchronously up to the point a model call is required; see Open Questions for whether Intent Detection itself is synchronous.
- **Approved execution** — user clicks Approve on an Execution Plan; the actual Core Platform writes (issue creation, wiki generation, etc.) happen as background work, and the user is notified via Notification Engine when done, not held on a spinner for the full duration.

## UI Description

No new UI surface is introduced by this document beyond what [architecture.md](architecture.md) and [ui_design.md](ui_design.md) already define. What changes here is *when* the UI reflects state: the Chat tab shows a "thinking" / "running" indicator keyed off `crux_conversations.state` and `crux_runs` rows still in flight, and Pending Actions (a filtered view over `crux_plan_steps`, see [database_design.md](database_design.md)) refreshes via the same Notification Engine events used for the async job completion signal.

## Architecture

### Plugin registration and the module gate

Crux registers as a Rails engine plugin inside Redmine, the same mechanism every Redmine plugin uses. Three registration points matter most, described conceptually:

- **The project module gate** — Crux declares a project module (`crux`) with its own permission set (see [security.md](security.md)). A project only shows the Crux tab, only accepts Crux routes, and only allows Crux controllers to respond, if that project has explicitly enabled the module in its settings. This is enforced at the routing layer, not just hidden in a view — a user who guesses a Crux URL for a project that hasn't enabled the module gets the same "module not enabled" response Redmine gives for any other disabled module (Wiki, Repository, etc.).
- **Menu registration** — Redmine's menu manager adds a "Crux" entry to the project-level menu (visible only when the gate above is open) and a separate top-level entry under Administration (visible only to users holding the global `crux:administer` permission).
- **Settings partial** — a global admin configuration screen (providers, models, billing, default agents) is registered as the plugin's settings partial, reachable from Administration → Settings regardless of whether any project has yet enabled Crux.

Everything downstream of the gate — Chat Engine, Workflow Engine, Agent Engine, and the rest — is ordinary application logic; the gate is what makes "opt-in per project" (principle 5) a routing-level guarantee rather than a UI convention.

### Asynchronous execution pattern

Agent execution is a background job, never inline on the web request. The rule is unconditional: any code path that calls out to Provider Layer/Model Layer for a model response must run off the request thread. The request/response cycle that submits a chat message or an approval returns immediately with an acknowledgment; the actual model call, context assembly, and Core Platform writes happen in a queued job that:

1. Assembles context via Knowledge Engine (permission-filtered for the acting user, not the job's own identity).
2. Calls Provider Layer/Model Layer.
3. Parses the result into plan steps (Workflow Engine) or a direct chat reply (Conversation Engine).
4. Writes a `crux_runs` row (Run Ledger) regardless of success or failure.
5. Emits a Notification Engine event so the UI updates without polling being the only option.

This pattern applies uniformly to a single-agent chat reply and to a multi-step Execution Plan — the only difference is how many jobs are queued and how their outputs recombine into one plan.

## Components

The components touched by this document are the same 19 named in [architecture.md](architecture.md); this document does not introduce new ones. The concerns specific to this document map onto existing components as follows:

| Concern | Primary component(s) |
|---|---|
| Module gate / routing enforcement | Core Platform, Project Workspace |
| Job queue for agent execution | Agent Engine |
| Context assembly inside a job | Knowledge Engine |
| State transition on job completion | Workflow Engine |
| Failure/success recording | Run Ledger |
| User-facing completion signal | Notification Engine |
| Cross-project isolation | Core Platform, Knowledge Engine, Integration Engine |

## Sequence Flow

End-to-end sequence for one full run, from prompt to notification:

```
User                Chat Engine        Intent/Clarify      Agent Engine (job)     Workflow Engine      Run Ledger      Notification Engine
 │                       │                    │                     │                     │                 │                  │
 ├─ prompt ─────────────▶│                    │                     │                     │                 │                  │
 │                       ├─ classify ────────▶│                     │                     │                 │                  │
 │                       │◀─ intent ──────────┤                     │                     │                 │                  │
 │                       │                    │                     │                     │                 │                  │
 │            [needs clarification? yes]      │                     │                     │                 │                  │
 │◀── question ──────────┤                    │                     │                     │                 │                  │
 ├─ answer ─────────────▶│                    │                     │                     │                 │                  │
 │                       │        (loop until clarification complete)                     │                 │                  │
 │                       │                    │                     │                     │                 │                  │
 │                       ├─ enqueue plan job ─────────────────────▶│                     │                 │                  │
 │◀── "plan generating" ─┤                    │                     ├─ context search ───▶│(Knowledge Eng.) │                  │
 │                       │                    │                     ├─ model call ────────────────────────▶│(Provider/Model)  │
 │                       │                    │                     │◀─ plan steps ────────┤                 │                  │
 │                       │                    │                     ├─ write plan ────────▶│ state: planned  │                  │
 │                       │                    │                     │                     ├─ awaiting_approval▶│               │
 │◀── plan preview ──────┴────────────────────┴─────────────────────┴─────────────────────┤                 │                  │
 ├─ approve ─────────────────────────────────────────────────────────────────────────────▶│                 │                  │
 │                       │                    │                     │                     ├─ state: executing│                 │
 │                       │                    │                     ├─ enqueue exec job ──▶│                 │                  │
 │                       │                    │                     ├─ Core Platform writes│                 │                  │
 │                       │                    │                     ├─ write run + outcome ─────────────────▶│                  │
 │                       │                    │                     │                     ├─ state: completed│                 │
 │                       │                    │                     │                     │                 ├─ notify ────────▶│
 │◀── notification: done ─────────────────────────────────────────────────────────────────────────────────────────────────────┤
```

This is the sequence-form counterpart to the conversation lifecycle diagram in [architecture.md](architecture.md).

## Design Decisions

- **The module gate is enforced at routing, not view rendering.** A hidden menu item is not a security boundary; Crux treats "module not enabled" as equivalent to any other disabled-module response Redmine already gives, so no new class of access-control bug is introduced.
- **All model calls are asynchronous, with no exception carved out for "fast" agents.** Even a cheap classification call goes through the job queue, because consistency of the execution pattern is worth more than shaving latency off a single fast path — see Open Questions for the one place this is still debated (Intent Detection).
- **Notifications, not polling, drive UI refresh for async completion.** Keeps Chat Engine and Project Workspace decoupled from job queue internals.
- **Project isolation is enforced at the query layer, not the network layer.** Crux is a single application instance serving many projects; isolation comes from every query being scoped by `project_id` and by Redmine's own permission checks (see [database_design.md](database_design.md) indexing guidance), not from separate deployments per project.

## Assumptions

- Redmine's existing background job infrastructure (or an equivalent queue Crux adds) is available and durable enough to guarantee a job is not silently dropped between "enqueued" and "run recorded."
- One Crux plugin instance serves multiple projects within a single Redmine installation; cross-installation deployment is out of scope (see [architecture.md](architecture.md) Assumptions).
- Provider Layer calls are the dominant source of latency in any agent run; Knowledge Engine retrieval and Core Platform writes are assumed fast by comparison.

## Risks

| Risk | Impact | Mitigation direction |
|---|---|---|
| Job queue backlog under load | Users perceive Crux as "stuck" between approval and completion | Notification Engine should distinguish "queued" from "failed" states explicitly, not leave the user guessing |
| A model call accidentally added inline on a request thread | Web workers blocked, unrelated Redmine pages slow down | Code review checklist item (Gate 1/Gate 2 in the SDD process) specifically checks for synchronous provider calls |
| Project-scoping filter omitted on a new query | Cross-project data leakage | Every new query against a `crux_*` table must include `project_id` in its `WHERE`/scope by convention; see [database_design.md](database_design.md) indexing guidance |
| Long-running agent jobs starve the queue for other projects | Latency degradation platform-wide from one noisy project | Fair queuing / per-project concurrency limits, tracked as a Billing Engine quota concern (see [billing.md](billing.md)) |

## Open Questions

1. **Sync vs. async chat** — is the first response to a prompt (fast Intent Detection) ever synchronous, with only the actual Agent Engine run going async? This document currently assumes uniform asynchronicity; resolving this affects perceived latency more than any other single decision.
2. Is agent identity a dedicated `User` subtype or a lighter `Member` record? Affects whether an agent's background job runs "as" a real Redmine user for permission-check purposes.
3. Is "Create 84 Issues" one plan step executed as one job, or 84 jobs? Affects job queue shape and partial-failure handling.
4. When one agent hands off to another mid-conversation, is that one job chained internally, or two independently queued jobs? Affects how Run Ledger rows are chained (see [architecture.md](architecture.md) Open Questions item 4).

## Best Practices

- Never call Provider Layer/Model Layer synchronously from a controller action — always through the job queue described above.
- Always scope queries by `project_id` even when a global admin is making the request; use an explicit "all projects" path rather than an unscoped query.
- Treat a job's identity as "acting on behalf of `user_id`" for every permission check inside it — never widen permissions just because code is now running in a background worker instead of a request.
- Emit a Notification Engine event on both success and failure of a job; a silent failure is worse than a visible one.

## Example Scenarios

**Scenario 1 — Normal latency.** A user approves a 5-step plan. The job queue picks it up within seconds, Core Platform writes complete in under a minute, and the user gets a completion notification before they've navigated away from the Pending Actions tab.

**Scenario 2 — Slow provider.** The configured model provider is degraded. The job retries against the agent's configured `fallback_model` (see [database_design.md](database_design.md) `crux_agents.fallback_model`); if that also fails, the run is recorded in Run Ledger with a failure outcome and the user is notified with a clear retry option, rather than the UI hanging indefinitely.

**Scenario 3 — Two projects, same admin.** An administrator with `crux:administer` views the cross-project Administration dashboard, which aggregates data from many projects deliberately (by design, admin-only). A regular project member on Project A never sees Project B's conversations or runs, even though both projects share the same Crux installation and the same Provider Layer credentials.

## Future Enhancements

- Revisit the sync-vs-async question once real latency data exists from Phase 1 usage — a hybrid where Intent Detection is synchronous but everything past it is async may become the resolved answer.
- Per-project concurrency/fair-queuing limits for job execution, once multi-project load patterns are observed in production.
- Federated/multi-instance deployment (multiple Redmine installations sharing billing/provider configuration) is not scoped for Phase 1–4 but would require revisiting the isolation model described here.
