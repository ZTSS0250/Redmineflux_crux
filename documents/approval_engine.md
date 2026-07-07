# Approval Engine

*The plan-and-gate specialization inside the Workflow Engine that turns an agent-drafted execution plan into a human-approved, auditable action.*

## Purpose

The Approval Engine is where "AI assists, humans decide" becomes an enforced mechanism, not a slogan. It takes Planner's output (or any agent's plan steps), presents it as a reviewable preview with cost and time estimates, and blocks execution of any step until a permission-holding human approves it.

## Scope

**In scope**: execution plan anatomy (`crux_execution_plans`, `crux_plan_steps`), the Approve/Reject/Modify actions and their effect on plan state, and the destructive-action gate.

**Out of scope**: the reasoning that produces a plan ([agent_catalog.md](agent_catalog.md)); the full Workflow Engine state machine and module boundaries ([architecture.md](architecture.md), `workflow_engine.md`); the underlying schema in full ([database_design.md](database_design.md)).

## Responsibilities

- Present a human-readable preview of every proposed action before anything executes.
- Enforce `crux:approve` for ordinary steps and the stricter `crux:approve_destructive` for destructive ones.
- Record who approved a plan and when.
- Drive plan and step status transitions in response to Approve, Reject, and Modify.

## User Flow

This engine implements the approval segment of the conversation lifecycle: Generate Execution Plan → Preview → User Approval → Execute Tasks → Generate Results → Audit Log → Success/Notification. The user chooses Approve, Reject, or Modify per step or for the whole plan; only Approve moves work toward execution.

## UI Description

The plan preview panel lists each step with Estimated Time and Estimated AI Cost, plus per-step Approve / Reject / Modify controls and a plan-level "approve all." Steps gated by `crux:approve_destructive` (Delete Project, Delete Milestone, Deploy) are visually distinguished — typically warning-styled — and need their own explicit confirmation even if the rest of the plan is already approved.

## Architecture

The Approval Engine is a specialization inside the Workflow Engine, not a separate module. Upstream, the Agent Engine (typically Planner) drafts a plan; downstream, an approved step is dispatched for execution, recorded in the Run Ledger, and reported via the Notification Engine. See [architecture.md](architecture.md), [database_design.md](database_design.md), [agent_catalog.md](agent_catalog.md).

## Components

**`crux_execution_plans`**: `id`, `conversation_id`, `status`, `estimated_time`, `estimated_cost`, `approved_by`, `approved_at`.

**`crux_plan_steps`**: `id`, `plan_id`, `action_type`, `target_type`, `target_id`, `status`, `payload`.

"Pending Actions" is not a separate table — it is a filtered view over `crux_plan_steps` where `status = awaiting_approval`, letting a user see every step across every plan that needs attention in one place.

**Canonical worked example** — a plan generated from "Create an HRMS" style requests:

| Step | Estimated Time | Estimated AI Cost | Actions |
|---|---|---|---|
| Create Project | — | — | Approve / Reject / Modify |
| Generate Wiki | — | — | Approve / Reject / Modify |
| Create Versions | — | — | Approve / Reject / Modify |
| Generate Milestones | — | — | Approve / Reject / Modify |
| Create 84 Issues | — | — | Approve / Reject / Modify |
| Assign Users | — | — | Approve / Reject / Modify |
| Generate Documentation | — | — | Approve / Reject / Modify |

Each row is one `crux_plan_steps` record; the plan-level `estimated_time`/`estimated_cost` on `crux_execution_plans` is the sum shown atop the preview.

## Sequence Flow

```
Planner (Agent Engine)
     │  drafts plan
     ▼
Workflow Engine                status: planned
     │  submit for review
     ▼
Approval Engine                status: awaiting_approval   (Pending Actions view)
     │  preview: steps, estimated_time, estimated_cost
     │
     ├─ Approve ─────────▶ status: executing ─▶ Run Ledger ─▶ status: completed
     │                                                          │
     │                                                          ▼
     │                                                 Notification Engine ─▶ User
     ├─ Reject  ─────────▶ status: planned   (revise and resubmit)
     │
     └─ Modify  ─────────▶ edit crux_plan_steps.payload ─▶ status: planned (re-preview)

Destructive steps (Delete Project, Delete Milestone, Deploy)
require crux:approve_destructive at the Approve branch above,
distinct from ordinary crux:approve.
```

This mirrors the Workflow Engine's state machine (`draft → clarifying → planned → awaiting_approval → executing → completed`), where Reject and Modify both loop back to `planned` rather than dead-ending the conversation.

## Design Decisions

- **Two-tier gate**: `crux:approve` covers ordinary steps; `crux:approve_destructive` is required specifically for Delete Project, Delete Milestone, and Deploy — irreversible or high-blast-radius actions warrant a narrower, explicitly granted permission.
- **Reject and Modify both loop to `planned`**, not to a dead end, so a rejected or edited plan can be revised and resubmitted without restarting the conversation.
- **Estimates are stored, not recomputed**: `estimated_time`/`estimated_cost` are captured on `crux_execution_plans` at approval time, giving a stable audit record even if a later run's real cost differs.
- **Modify changes payload, not identity**: editing a step changes `crux_plan_steps.payload` (an assignee or date), not `action_type`/`target_type` — changing the action itself is a new step, not an edit.

## Assumptions

- Approval is per-plan by default, with per-step preview as the mechanism for catching a single bad step inside a larger plan.
- The preview is read-only until an explicit Approve, Reject, or Modify action — no implicit approval from inactivity or timeout.
- A conversation holds one active execution plan at a time; a new request while one is `awaiting_approval` extends or supersedes it rather than creating a second (not schema-confirmed — flag for [database_design.md](database_design.md)).

## Risks

- A large plan (Create 84 Issues, for example) approved as a single unit limits the approver's practical ability to catch one bad step among many, even with per-step preview.
- Modify without re-validation could produce a step whose payload no longer matches what the originating agent intended.
- Estimated cost drifting from actual cost (model pricing changes) could erode trust in the preview over time.

## Open Questions

- `crux_plan_steps` carries its own `status`, but `approved_by`/`approved_at` live only on `crux_execution_plans`. When a plan mixes ordinary and destructive steps, is approval tracked per step, or does plan-level `approved_by`/`approved_at` cover the whole batch? Undecided — reconcile with [database_design.md](database_design.md).
- When a plan spans a multi-agent hand-off (Planner drafting steps a later agent revises), is the execution one Run Ledger row or a chain? Undecided; see [agent_catalog.md](agent_catalog.md).

## Best Practices

- Keep plan steps small and independently reviewable rather than bundling "everything" into one step.
- Grant `crux:approve_destructive` narrowly (project leads only) — never bundle it into a default Member role.
- Surface `estimated_cost` prominently so approvers can weigh AI spend against Billing Engine budgets.

## Example Scenarios

> Create Project · Generate Wiki · Create Versions · Generate Milestones · Create 84 Issues · Assign Users · Generate Documentation — shown with Estimated Time and Estimated AI Cost, actions Approve / Reject / Modify.

A user reviewing this plan might Modify the "Assign Users" step to change a reviewer, Approve the rest individually, and leave any Deploy-adjacent follow-up plan untouched until a `crux:approve_destructive` holder is available.

## Future Enhancements

Per-step approver delegation; approval policies that auto-approve low-cost, non-destructive steps under a configurable threshold; plan diffing on Modify so a re-preview shows exactly what changed before re-approval.
