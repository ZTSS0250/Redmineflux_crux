## Metadata
- **Task ID**: crx-003-feature-workflow-approval-engine
- **Title**: Workflow Engine, Approval Engine & baseline Notification Engine (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `workflow_engine.md`, `approval_engine.md`, `database_design.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Give a `planned` conversation (crx-002's terminal state) an actual execution plan, an approval gate, and an execute/complete path — the mechanism vision.md's Principle 2 ("no create, delete, close, deploy, or bulk-update path exists that bypasses the approval gate") depends on structurally. This task implements the Workflow Engine's full state machine (`draft → clarifying → planned → awaiting_approval → executing → completed`, with `rejected`/`edited` looping to `planned`), the Approval Engine as a specialization inside it (not a separate module, per `architecture.md`), the destructive-action gate (`crux:approve_destructive`), and a baseline Notification Engine that writes `crux_notifications` on plan-state transitions. It does **not** implement what actually executes a step against Core Platform — that is crx-004's Agent Engine. This task can therefore ship and be QA'd end-to-end using a manually-seeded or stub plan, with real agent-authored plans arriving once crx-004 lands.

**Goal**:

The Pending Actions tab (a placeholder since crx-001) becomes a real, live filtered view over `crux_plan_steps` where `status = awaiting_approval`. A plan with ordinary and destructive steps can be approved, rejected, or modified by a user holding the right permission; destructive steps are visually distinguished and blocked for users without `crux:approve_destructive`; every transition is notified via `crux_notifications`.

**Objectives**:
- [ ] Add `crux_execution_plans` and `crux_plan_steps` tables (`database_design.md`).
- [ ] Add `crux_notifications` table (`database_design.md`) — this task is its first writer.
- [ ] Implement the full `crux_conversations.state` transition logic from `planned` onward: `planned → awaiting_approval → executing → completed`, with `rejected`/`edited` → `planned`.
- [ ] Implement the Approval Gate: `crux:approve` for ordinary `crux_plan_steps`, `crux:approve_destructive` additionally for destructive `action_type`/`target_type` combinations (Delete Project, Delete Milestone, Deploy).
- [ ] Implement atomic, compare-and-swap status transitions on `crux_execution_plans.status` so two simultaneous Approve clicks cannot both succeed (`workflow_engine.md` Assumptions/Risks).
- [ ] Wire the real Pending Actions tab (crx-001 placeholder) to `crux_plan_steps` filtered to `awaiting_approval`, per user's visible plans.
- [ ] Wire the real Approval card (plan preview with steps, estimated time/cost, Approve/Reject/Modify) replacing crx-001's static placeholder.
- [ ] Implement a Retry Manager: a step that errors during `executing` retries per a configurable count, and returns the whole plan to `planned` with the error visible once retries are exhausted.
- [ ] Emit `crux_notifications` rows on: plan reaches `awaiting_approval`, plan approved/rejected, run completed, run failed.

**Deliverables**:
- [ ] Migrations: `crux_execution_plans`, `crux_plan_steps`, `crux_notifications`.
- [ ] Models: `Crux::ExecutionPlan`, `Crux::PlanStep`, `Crux::Notification`.
- [ ] `Crux::WorkflowEngine` service object owning the state machine and the atomic transition guarantee.
- [ ] `Crux::ApprovalGate` — the permission-check specialization inside `WorkflowEngine` (per `architecture.md`: "not a separate module").
- [ ] `Crux::RetryManager`.
- [ ] `Crux::NotificationEmitter` (or equivalent) triggered by `WorkflowEngine` transitions.
- [ ] `ProjectCruxPendingActionsController` rewritten from crx-001's placeholder to a real filtered query.
- [ ] Real Approval card view/partial (Approve/Reject/Modify), reused by both the Chat tab's inline plan preview and the Pending Actions tab.
- [ ] A seedable/stub plan-step generator for QA purposes only, since crx-004 (the real plan author) doesn't exist yet — see Implementation Notes.

**Out of Scope**: Anything that actually mutates Core Platform (creating the real Issue/Version/WikiPage a step describes) — that dispatch belongs to crx-004's Agent Engine and, for external-system steps, the not-yet-scoped Integration Engine. This task executes the *state machine*, not the *underlying Redmine writes*.

---

## Specification

**Complexity**: HIGH

**Reason**: New migrations for 3 tables; implements the single most safety-critical mechanism in the product (the human-approval gate that Principle 2 depends on structurally); introduces the first destructive-action permission distinction; the atomic-transition and retry logic have real concurrency-correctness requirements. Squarely HIGH per the security-changes criterion in the global complexity rubric.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_execution_plans.rb` | create | `crux_execution_plans(id, conversation_id, status, estimated_time, estimated_cost, approved_by, approved_at)` per `database_design.md`. |
| `db/migrate/XXXX_create_crux_plan_steps.rb` | create | `crux_plan_steps(id, plan_id, action_type, target_type, target_id, status, payload)`; `target_id` nullable (create-type steps have no target yet). |
| `db/migrate/XXXX_create_crux_notifications.rb` | create | `crux_notifications(id, user_id, event_type, ref_type, ref_id, read_at, created_at)`. |
| `app/models/crux/execution_plan.rb` | create | `belongs_to :conversation`, `has_many :plan_steps`; `status` enum matching `crux_conversations.state` from `planned` onward. |
| `app/models/crux/plan_step.rb` | create | `belongs_to :execution_plan`; `status` enum `awaiting_approval/approved/rejected/executing/completed/failed`; a class-level `DESTRUCTIVE_ACTIONS` constant (`delete_project`, `delete_milestone`, `deploy`) as the single source of truth for what needs `crux:approve_destructive` (per `architecture.md` Design Decisions: "identified centrally... so the extra check is a single source of truth"). |
| `app/models/crux/notification.rb` | create | `belongs_to :user`; polymorphic `ref_type`/`ref_id` (no DB-level FK, per `database_design.md`'s accepted risk — prefer soft-delete over hard-delete on `crux_plan_steps`/`crux_runs` to avoid orphaning these). |
| `app/services/crux/workflow_engine.rb` | create | Owns `crux_execution_plans.status`/`crux_conversations.state` transitions; every transition wrapped in a DB-level compare-and-swap (optimistic locking via a `lock_version` column or an equivalent atomic `UPDATE ... WHERE status = ?` guard) so concurrent Approve clicks cannot double-execute. |
| `app/services/crux/approval_gate.rb` | create | `can_approve?(user, plan_step)` — checks `crux:approve`, and additionally `crux:approve_destructive` when `plan_step.action_type` is in `PlanStep::DESTRUCTIVE_ACTIONS`. Called by `WorkflowEngine` before any `planned → executing` transition; not a separate controller-level permission check duplicated elsewhere. |
| `app/services/crux/retry_manager.rb` | create | Tracks attempt count per `crux_plan_steps` row (a `attempts`/`max_attempts` pair, count configurable — see Implementation Notes); on exhaustion, marks the step `failed` and the parent plan `planned`, surfacing the error. |
| `app/services/crux/notification_emitter.rb` | create | Subscribed to `WorkflowEngine` transitions; writes `crux_notifications` for `approval_pending`, `run_completed`, `run_failed` event types. |
| `app/controllers/project_crux_pending_actions_controller.rb` | modify | Query `Crux::PlanStep.where(status: :awaiting_approval)` scoped to plans the current user can see in this project (via `crux_execution_plans → crux_conversations → project_id`); add `approve`/`reject`/`modify` POST actions delegating to `WorkflowEngine`/`ApprovalGate`. |
| `app/views/project_crux_pending_actions/index.html.erb` | modify | Replace crx-001's static empty-state-only placeholder with the real queue (per `ui_design.md`'s Pending Actions wireframe): destructive rows visually distinguished, Approve disabled with inline explanation (not hidden) for users lacking `crux:approve_destructive`. |
| `app/views/shared/_crux_approval_card.html.erb` | create | Shared partial: step table, Estimated Time/Cost, Approve/Reject/Modify action bar — reused by the Chat tab's inline plan preview (crx-002's conversation reaching `planned`) and the Pending Actions tab, per `ui_design.md` Components ("Approval action bar — always shown together"). |
| `config/routes.rb` | modify | Add `POST` routes for `approve`/`reject`/`modify` on plan steps and on whole plans. |
| `lib/redmineflux_crux/seed/stub_plan_generator.rb` | create, dev/QA-only | Generates a `crux_execution_plans` + `crux_plan_steps` set matching the canonical worked example (Create Project · Generate Wiki · Create Versions · Generate Milestones · Create 84 Issues · Assign Users · Generate Documentation, including one destructive step) for QA to exercise this task without crx-004 existing yet. Not loaded in production; gated behind a Rake task or console helper only. |

### Implementation Notes

- **This task cannot fully exist without a plan author, so it ships with a QA-only stub generator.** Real plans come from crx-004's Agent Engine (specifically the Planner agent). Rather than blocking crx-003 on crx-004, this spec adds a narrow, clearly-labeled dev/QA seed path (`stub_plan_generator.rb`) so the state machine, approval gate, and notifications can be built and tested in isolation — exactly the same reasoning `roadmap.md` uses to justify sequencing phases by dependency rather than forcing lockstep delivery. The stub generator must never run outside a QA/console context and must not appear in any user-facing UI.
- **"Create 84 Issues" is one `crux_plan_steps` row, not 84**, for this task's implementation — this resolves the open question tracked in `architecture.md`/`database_design.md`/`roadmap.md` in favor of a single-row-per-declared-step model, matching the canonical worked example in `approval_engine.md` ("Create 84 Issues" is listed as one row with one Approve/Reject/Modify). If this is revisited later, it is a schema and UX change to `crux_plan_steps` cardinality, not a small patch — flagged here so a future task doesn't silently assume the other answer.
- **Multi-agent hand-off row cardinality on `crux_runs` is out of scope for this task** — `crux_runs` doesn't exist until crx-004. This task only prepares the *state machine* a run's completion will eventually drive.
- **Atomic transitions are the crux of this task's correctness.** `WorkflowEngine` must use a real DB-level guard (e.g., `UPDATE crux_execution_plans SET status = 'executing' WHERE id = ? AND status = 'awaiting_approval'` checking affected-row count, or Rails optimistic locking) — an application-level `if plan.status == 'awaiting_approval'` check followed by a separate `update` call is a TOCTOU race and does not satisfy `workflow_engine.md`'s Assumption that every transition is atomic.
- **Retry count is configurable, not hardcoded** — per `workflow_engine.md` Assumptions ("configurable in Administration → Policies"). This task stores it as a `crux_settings` row (scope: global, falling back to a sane default) rather than a constant, even though the Administration → Policies tab UI itself isn't built until a later task — the setting must exist and be readable now so it isn't a breaking schema change later.
- **Destructive-action detection is centralized in the model layer** (`PlanStep::DESTRUCTIVE_ACTIONS`), not scattered per-agent — this matters even before crx-004 ships agents, because the stub generator and every future agent must consult the same single source of truth.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | State transition — happy path | Plan at `awaiting_approval`, user with `crux:approve` approves | Plan → `executing`; all non-destructive steps → `approved` then `executing` | pending |
| 2 | Destructive gate — blocked | Plan step is `delete_milestone`, user has `crux:approve` but not `crux:approve_destructive` | Step's Approve action is refused server-side, not just hidden client-side | pending |
| 3 | Destructive gate — allowed | Same step, user has `crux:approve_destructive` | Step approves | pending |
| 4 | Reject loops to `planned` | Plan at `awaiting_approval`, user rejects | Plan → `planned`, not a dead "cancelled" state | pending |
| 5 | Modify changes payload only | User modifies the "Assign Users" step's assignee | `plan_steps.payload` changes; `action_type`/`target_type` unchanged; plan → `planned` for re-preview | pending |
| 6 | Retry exhaustion | A step fails on every attempt up to `max_attempts` | Step → `failed`; parent plan → `planned` with error visible; remaining steps not left in limbo | pending |
| 7 | Concurrent approve race | Two simultaneous Approve requests on the same plan | Exactly one succeeds; the second receives a "no longer awaiting approval" response, not a duplicate execution | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Canonical plan end-to-end | Seed the stub CRM/HRMS-style plan → open Pending Actions → Approve all steps | Plan reaches `completed` (steps simulated as instantly successful in this task's scope); notifications fire | pending |
| 2 | Pending Actions badge count | Seed 3 plans with steps at `awaiting_approval` | Tab badge shows "3", matching `ui_design.md`'s wireframe | pending |
| 3 | Destructive row styling | Seed a plan containing a `deploy` step | Row is visually distinguished with a destructive icon/label, per `ui_design.md` | pending |
| 4 | Approval card parity | Compare the Chat tab's inline plan preview and the Pending Actions queue for the same plan | Both render via the same `_crux_approval_card` partial, identical step data | pending |
| 5 | Notification on approval | Approve a plan | A `crux_notifications` row is created for the approving user's project collaborators per `event_type: run_completed`/`approval_pending` as appropriate | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Mixed ordinary + destructive plan, partial permission | User has `crux:approve` only; plan has 6 ordinary + 1 destructive step | The 6 approve; the destructive row's Approve is disabled with inline text explaining why, Reject remains available (per `ui_design.md`) | pending |
| 2 | Two plans targeting the same resource | Two conversations in the same project both plan "Create Project X" | Both can be approved independently by the state machine; any real conflict surfaces at execution time (crx-004), not blocked here — per `workflow_engine.md` Risks | pending |
| 3 | Modify with an invalid payload | User modifies a step's assignee to a user not on the project | Modify is rejected with a validation error, plan stays `awaiting_approval`, not silently accepted | pending |
| 4 | Plan abandoned indefinitely | A plan sits at `planned` with no user action for an extended period | No automatic timeout/expiry exists (per `workflow_engine.md` Open Questions — this is intentionally undecided); confirm no code path silently auto-rejects or auto-approves it | pending |
| 5 | Notification for a since-deleted plan step | A plan step referenced by a `crux_notifications` row is later hard-deleted (should not normally happen — see Implementation Notes on soft-delete) | Notification does not raise on render; degrades to a generic "no longer available" link rather than a 500 | pending |

### QA Test Plan

**Scope**: State-machine correctness, the approval/destructive gate, retry/failure handling, and notification emission — using the stub plan generator in place of real agent-authored plans.

**Pre-conditions**:
- crx-001 (permissions/navigation) and crx-002 (conversations reaching `planned`) are in place.
- At least one user holding `crux:approve` only, and one holding both `crux:approve` and `crux:approve_destructive`.
- The stub plan generator seeded at least one plan containing both ordinary and destructive steps.

**QA Steps**:
1. As the `crux:approve`-only user, open Pending Actions; confirm the destructive step's Approve control is disabled with an explanation, not hidden.
2. As the `crux:approve_destructive` user, approve the same step; confirm it executes.
3. Reject an ordinary step; confirm the plan returns to `planned`, not a dead state.
4. Modify a step's payload; confirm `action_type` is unchanged and the plan re-enters `awaiting_approval` preview.
5. Force a step to fail on every retry attempt (via the stub generator's failure-simulation flag); confirm the plan returns to `planned` with the error visible.
6. Trigger two near-simultaneous Approve clicks (e.g. two browser tabs) on the same plan; confirm only one succeeds.
7. Confirm `crux_notifications` rows are created at each of the transitions above.

**Expected Outcomes**:
- No plan step ever executes without the correct permission (`crux:approve`, and `crux:approve_destructive` where applicable) having been checked server-side.
- No race condition allows double-execution of the same plan.
- Every transition is reflected in a `crux_notifications` row.

**Out of Scope**:
- Real Core Platform writes (Issue/Wiki/Version creation) — steps in this task's QA scope are simulated success/failure via the stub generator, not real Redmine mutation.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Approval Engine risked being modeled as a separate controller-level permission check duplicated across Chat and Pending Actions views, contradicting `architecture.md`'s explicit "not a separate module — a specialization inside Workflow Engine" design decision. | Code Changes, `approval_gate.rb` row | `ApprovalGate` is a single service called by `WorkflowEngine`, invoked identically from both surfaces via the shared `_crux_approval_card` partial. |
| 2 | HIGH | This task has no plan author until crx-004 ships — an early draft risked either blocking crx-003 entirely on crx-004, or quietly fabricating fake `crux_agents`/`crux_runs` rows to make plans "look real." | Code Changes, `stub_plan_generator.rb` row; Implementation Notes | A clearly-labeled, QA-only stub generator is specified instead, with an explicit rule that it must never reach production UI. |
| 3 | HIGH | Destructive-action detection risked being left to "whatever the plan step's payload says," which `architecture.md` explicitly warns against ("centralized... a single source of truth rather than scattered per-agent logic"). | Code Changes, `PlanStep::DESTRUCTIVE_ACTIONS` | Single model-level constant is the sole source of truth, consulted by `ApprovalGate` and (later) every agent that drafts a destructive step. |
| 4 | MEDIUM | Retry count was initially going to be a hardcoded constant, contradicting `workflow_engine.md`'s Assumption that it's configurable in Administration → Policies. | Implementation Notes | Stored as a `crux_settings` row now, even though the Policies UI itself isn't built until later — avoids a breaking schema change. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The single biggest risk in this task: an Approve/Reject/Modify action that only checks permission in the view (disabling a button) without a matching server-side check would let a `crux:approve`-only user approve a destructive step via a crafted request. | Code Changes, controller row; Test Case Unit #2 | `ApprovalGate.can_approve?` is enforced inside `WorkflowEngine` itself — the controller action cannot transition state without passing it, regardless of what the client sent. |
| 2 | HIGH | A missing DB-level atomic guard on `crux_execution_plans.status` transitions would allow a genuine race condition — two concurrent Approve clicks both executing the same plan (double Core Platform writes once crx-004 exists). | Code Changes, `workflow_engine.rb` row; Test Case Unit #7 | Specified as a real compare-and-swap (`UPDATE ... WHERE status = ?` + affected-row check, or optimistic locking), not an application-level read-then-write. |
| 3 | MEDIUM | `crux_plan_steps.status` needs an index (and ideally `(plan_id, status)`) given Pending Actions depends entirely on this filter being fast, per `database_design.md` Best Practices — an early draft's Code Changes didn't call this out explicitly. | Code Changes, migration row | Added explicitly to the migration's requirements. |
| 4 | MEDIUM | `crux_notifications`' polymorphic `ref_type`/`ref_id` has no DB-level FK (`database_design.md`'s accepted risk) — a hard delete of a referenced `crux_plan_steps` row would orphan notifications and could 500 on render. | Code Changes, `notification.rb` row; Test Case Edge #5 | Spec calls for soft-delete/status columns over hard deletes on referenced tables, and the notification renderer must degrade gracefully rather than raising. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the single `ApprovalGate` service, atomic transition requirement, centralized destructive-action list, indexing requirement, and notification soft-delete handling are all concrete rows/notes above, not narrative-only agreements.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | `redirect_to` missing after `render` in an error branch | A rejected Modify (invalid payload) both renders a validation error and redirects, causing a double-render exception | Yes — Edge Case #3 |
| 2 | Wrong `dependent:` on association | `crux_execution_plans has_many :plan_steps` uses `dependent: :destroy` where the append-only/soft-delete posture actually calls for `dependent: :restrict_with_error` or a soft-delete equivalent, risking silent data loss on plan cleanup | Not directly test-covered by a UI edge case (this is an association-declaration detail); called out here explicitly so implementation sets `dependent:` deliberately rather than accepting the Rails default of `nil` (which would raise on deletion attempts, safer than silent cascade — implementation must not "fix" that by adding `:destroy` for convenience) |
| 3 | `respond_to :js` missing for AJAX approve/reject/modify | Approve/Reject/Modify implemented as full-page redirects instead of the in-place status-pill update `ui_design.md` describes | Yes — Functional Test #4 (approval card parity implicitly requires the same AJAX-capable partial in both surfaces) |
| 4 | DB-level uniqueness index missing enabling a race | Two concurrent approvals both succeed because the transition guard is application-level, not DB-level | Yes — Unit Test #7 |
| 5 | Missing index causing slow Pending Actions at scale | `crux_plan_steps.status` unindexed once volume grows | Yes — covered by the Gate 2 #3 resolution (migration requirement), though no dedicated load-test edge case exists in this task's QA scope since realistic volume isn't reachable pre-crx-004 |

Verdict: Approved. Item #2 (association `dependent:` choice) is an implementation-time decision this spec constrains but does not add a dedicated test case for, since it is not independently observable UI/API behavior — it is called out here so a code reviewer checks it explicitly during Gate-equivalent code review at PR time.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
