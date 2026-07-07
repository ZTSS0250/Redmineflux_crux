# Workflow Engine

The state machine that governs a conversation from first prompt through to a completed — or reopened — execution plan. Owns plan step statuses, the approval gate (including the stricter gate for destructive actions), concurrency across simultaneous conversations, and failure/retry handling during execution.

## Purpose

To define, precisely and in one place, how a conversation's execution plan moves between states, what "approved" actually authorizes, and what happens when a step fails, is rejected, or is sent back for changes. Any other document that mentions plan status, approval, or execution should defer to this one rather than restating the mechanics.

## Scope

Covered: the conversation-level state machine (`draft`, `clarifying`, `planned`, `awaiting_approval`, `executing`, `completed`); the plan step lifecycle and its statuses; the distinct gate for destructive actions; what Modify does to a plan; whether a project can run multiple plans concurrently; and retry semantics for a step that errors during execution.

Not covered: how a plan's steps are generated (Agent Engine, and turn orchestration in [chat_engine.md](chat_engine.md)); how the workspace renders plan state ([ui_design.md](ui_design.md)); the full module map ([architecture.md](architecture.md)); and the exact schema of `crux_execution_plans` and `crux_plan_steps` ([database_design.md](database_design.md)).

## Responsibilities

The Workflow Engine owns the conversation-level state machine, owns the status of every row in `crux_execution_plans` and `crux_plan_steps`, enforces the approval gate before any step executes, enforces the additional `crux:approve_destructive` gate for destructive step types, and coordinates retries when a step fails. It emits every transition to the Run Ledger, Notification Engine, and Analytics Engine.

It does not decide what a plan contains — that is produced by an agent inside the Agent Engine — and it does not perform the underlying Redmine mutation itself, which it delegates to the Agent Engine and Integration Engine for each approved step.

## User Flow

From the user's perspective: a prompt starts a conversation in `draft`; if the agent needs more information the conversation moves to `clarifying` and the user answers questions; once enough information exists it moves to `planned` and a plan is generated; the plan is previewed and the conversation moves to `awaiting_approval`; the user approves, rejects, or modifies it. Approve begins `executing`, which ends in `completed`. Reject and Modify do not end the conversation — both send it back to `planned` so the plan can be revised rather than discarded.

## UI Description

Each state has a direct, single on-screen representation, detailed fully in [ui_design.md](ui_design.md):

| State | What the user sees |
|---|---|
| `draft` | Composer active, no plan shown |
| `clarifying` | Clarification question chips in the thread |
| `planned` | Plan preview rendering, not yet actionable |
| `awaiting_approval` | Approval card with Approve / Reject / Modify enabled |
| `executing` | Approval action bar disabled, status pill "Executing" |
| `completed` | Results appended to the thread, entry visible in Runs |

A step awaiting approval on its own (independent of the rest of the plan) is what populates the Pending Actions tab.

## Architecture

The Workflow Engine sits between the Chat Engine, which produces a draft plan from a conversation turn, and the Agent Engine / Integration Engine, which carry out each approved step. The Approval Engine — the plan-and-gate logic described in [architecture.md](architecture.md) — is not a separate module; it is the authorization check inside the Workflow Engine's transition from `planned` to `executing`. All state is persisted in `crux_execution_plans` and `crux_plan_steps`; every transition is written to the Run Ledger (see [database_design.md](database_design.md)).

### Conversation state machine

```
┌───────┐   needs info    ┌────────────┐   answers complete    ┌─────────┐
│ draft │ ───────────────▶│ clarifying │ ──────────────────────▶│ planned │◀────────────────────────┐
└───────┘                 └─────┬──────┘                        └────┬────┘                          │
                                 │  ▲                                 │                                │
                                 └──┘  more questions needed          │ plan generated,                │
                                       (self-loop)                    │ ready for review                │
                                                                       ▼                                │
                                                        ┌─────────────────────┐                         │
                                                        │  awaiting_approval  │                         │
                                                        └──────────┬──────────┘                         │
                                              approve              │             reject / modify        │
                                     ┌──────────────────────────────┴─────────────────────────────┐    │
                                     ▼                                                              │    │
                               ┌───────────┐    all steps succeed     ┌───────────┐                 │    │
                               │ executing │ ─────────────────────────▶│ completed │                 │    │
                               └─────┬─────┘                          └───────────┘                 │    │
                                     │ a step exhausts its retries                                    │    │
                                     └────────────────────────────────────────────────────────────────┴────┘
```

Reject and Modify both transition `awaiting_approval → planned`; a step that exhausts its retries transitions the whole plan `executing → planned` as well, so the conversation always has a single, well-defined place to resume from.

## Components

- **State Machine Controller** — owns the `status` field on `crux_execution_plans` and validates every transition.
- **Plan Step Executor** — iterates `crux_plan_steps` in order and invokes the Agent Engine or Integration Engine per step.
- **Approval Gate** — checks `crux:approve` for ordinary steps and additionally `crux:approve_destructive` for destructive ones before allowing `executing`.
- **Retry Manager** — tracks attempt count and backoff per step.
- **Concurrency Coordinator** — scopes locking to a single conversation so unrelated conversations in the same project are never blocked by each other.
- **Event Emitter** — publishes every transition to the Run Ledger, Notification Engine, and Analytics Engine.

## Sequence Flow

```
Chat Engine ──(plan drafted)──▶ Workflow Engine ──(status: planned)──▶ user preview
                                        │ user clicks Approve
                                        ▼
                          Approval Gate checks crux:approve
                          (and crux:approve_destructive for destructive steps)
                                        │ gate passes
                                        ▼
                     Workflow Engine (status: executing) ──▶ Agent Engine / Integration Engine
                                        │ step succeeds                │ step errors
                                        ▼                              ▼
                     next step, or status: completed             Retry Manager
                                                                        │ retries remain → re-executes step
                                                                        │ retries exhausted → status: planned
```

## Design Decisions

Reject and Modify both route back to `planned` rather than into a dead "cancelled" state, so a conversation is always resumable and a user is never forced to start over for a small correction. Destructive step types are identified centrally, by `action_type`/`target_type` combination (delete, deploy, and similar), at plan-generation time, so the extra `crux:approve_destructive` check is a single source of truth rather than scattered per-agent logic. A conversation holds at most one active (non-`completed`) plan at a time; a new request after `completed` starts a new plan record rather than mutating history. Multiple conversations — and therefore multiple plans — may be in flight concurrently within the same project; concurrency is scoped per conversation, not per project. A plan step that exhausts its retries marks itself `failed`, surfaces the error, and returns the parent plan to `planned` rather than leaving the remaining steps in limbo. Steps within an approved plan execute in their declared order by default.

## Assumptions

Every transition on `crux_execution_plans.status` is an atomic compare-and-swap, so two simultaneous Approve clicks on the same plan cannot both succeed. The number of retry attempts per step is small and configurable in Administration → Policies rather than unlimited. Conversation-level locking is sufficient and no additional row-level locking is needed beyond the plan's own status field.

## Risks

A race condition between two approvers clicking Approve on the same plan at the same time must be resolved by the atomic status transition described above, not by UI disabling alone. Partial execution on failure can leave Redmine in an inconsistent intermediate state — for example a project created but its issues not yet — which is why a failed step returns the whole plan to `planned` with the error visible rather than presenting a silently partial success. Two concurrent plans in the same project targeting the same resource (for example, two conversations both trying to create a project with the same name) can still conflict at execution time even though the state machine itself has no project-level lock.

## Open Questions

Should there be an explicit terminal state for a plan the user abandons without ever rejecting it, or is indefinite `planned` acceptable? Is the retry count and backoff configurable per agent, or only globally? Should two plans in the same project be prevented from targeting the same resource, or is that left to the underlying Redmine uniqueness constraints to catch at execution time?

## Best Practices

Always transition plan status atomically to prevent double-execution. Log every state transition to the Run Ledger for auditability, not only the terminal ones. Surface partial failure clearly to the user rather than swallowing the error inside a generic "failed" label. Keep destructive-step detection centralized rather than letting individual agents decide for themselves what counts as destructive.

## Example Scenarios

The canonical CRM System plan runs end to end: `draft → clarifying → planned → awaiting_approval → executing → completed`. A user rejects a "Delete Milestone" step; the plan returns to `planned` and the DevOps Agent revises it before the user is asked to approve again. A "Create 84 Issues" step fails transiently, is retried automatically by the Retry Manager, and succeeds on the second attempt without the plan ever leaving `executing`.

## Future Enhancements

Parallel execution for steps with no data dependency on one another. Per-project, and eventually per-agent, configurable retry and backoff policy. Scheduled or recurring plans that an approval policy can auto-approve. Marketplace-contributed custom step types once the Future Marketplace module ships.
