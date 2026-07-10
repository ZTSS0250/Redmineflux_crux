## Metadata
- **Task ID**: crx-013-feature-workflow-automation-triggers
- **Title**: Workflow Engine Automation Triggers — Scheduler + Automation Policies (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `workflow_engine.md`, `agent_catalog.md`, `database_design.md`, `vision.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Gives the Workflow Engine its first non-chat entry point into `draft`/`planned` — the concrete mechanism behind `roadmap.md`'s Phase 3 line "Workflow Engine supports automated (not solely user-triggered) workflows." **This is the single most under-specified capability in the entire roadmap**: `workflow_engine.md` has no section describing this at all — its whole state machine assumes a user prompt starts every conversation. The only concrete hints anywhere in the doc set are scattered `agent_catalog.md` Execution Flow lines: Reporter ("or a schedule"), Scrum Master Agent ("or a scheduled ceremony trigger"), Release Manager Agent ("or a version-close trigger"), Security Agent ("or a scheduled scan"). This task invents the concrete mechanism, deliberately narrow: exactly two trigger shapes, both converging on the unmodified Workflow Engine/Approval Gate crx-003 already built. It fills crx-001's Automations tab placeholder with real per-project policy rows — a seam `database_design.md` already named (`Automations tab → crux_settings (scope=project), crux_integrations`) but crx-001 never built.

**Goal**:

A project can configure an automation policy — either a recurring cadence or a reaction to one Core Platform event (`Version` closing) — that causes a plan to enter `draft`/`planned` on its own, without a user typing a prompt. Every automation-spawned plan goes through the *exact same* Approval Gate a chat-originated one does; nothing about automation changes how a plan is approved, only what causes it to exist.

**Objectives**:
- [ ] Add `crux_automation_policies` table: project-scoped, one row per configured automation, supporting two `trigger_type` values (`scheduled_cadence`, `core_event`).
- [ ] Implement `Crux::Automations::Scheduler` — cron-like cadence firing.
- [ ] Implement `Crux::Automations::EventDispatcher` — hooks exactly one Core Platform event this phase names: `Version` transitioning to closed.
- [ ] Both dispatch into `Crux::Agents::Runner` (crx-004) unmodified — automation changes only what causes a plan to start, never how it reaches `executing`.
- [ ] Add `crux_execution_plans.origin` (`chat`/`automation`) and `.automation_policy_id` — so Pending Actions/Runs/Audit can distinguish an automation-spawned plan from a chat-spawned one, directly serving the roadmap's own named "approval fatigue" risk (a reviewer needs to know a plan wasn't triggered by a colleague's explicit request).
- [ ] Implement an idempotency guard: if a policy's last-produced plan is still non-terminal, skip this firing rather than spawning a duplicate.
- [ ] Fill crx-001's Automations tab placeholder with real per-project policy configuration, gated `crux:manage_integrations` (the permission crx-001 already assigned to that tab).

**Deliverables**:
- [ ] Migration: `crux_automation_policies`; `crux_execution_plans.origin`, `.automation_policy_id`.
- [ ] `Crux::Automations::Scheduler`, `::EventDispatcher`.
- [ ] `Version` model callback (Core Platform) hooking `EventDispatcher` on close.
- [ ] `ProjectCruxAutomationsController` (crx-001/crx-009) — real policy CRUD.
- [ ] Pending Actions/Runs views (crx-003/crx-004) updated to show an "Automated" badge on automation-originated plans.

**Out of Scope**: A generic Core-Platform event bus beyond `version_closed` (this task hardcodes exactly one event); auto-approval of automation-generated plans (never in scope — Principle 2 is non-negotiable, no automation bypasses `crux:approve`); webhook-sourced (Integration Engine) triggers (crx-017 extends this table's `event_name` domain, this task doesn't invent that generically); a global, cross-project Administration → Policies UI (that tab doesn't exist at all — pre-dates Phase 3, not this task's gap to close); retroactively wiring Reporter's/Security Agent's Phase 1/2 trigger mentions (technically enabled by this mechanism but not a named Phase 3 capability — left for separate backlog grooming).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration; this is the task `roadmap.md`'s own named risk ("Automation before trust") points directly at; a mis-fired or duplicate-fired automation is a governance-adjacent correctness bug, not a cosmetic one. Matches the security/governance-sensitivity criterion crx-003 used for its own HIGH rating.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_automation_policies.rb` | create | `crux_automation_policies(id, project_id, capability, trigger_type [scheduled_cadence|core_event], schedule_cron, event_name, agent_role, enabled, created_by, created_at, updated_at, last_triggered_at)`. |
| `db/migrate/XXXX_add_origin_to_crux_execution_plans.rb` | create | `crux_execution_plans.origin` (`chat`/`automation`, default `chat`), `.automation_policy_id` (nullable FK). |
| `app/models/crux/automation_policy.rb` | create | `belongs_to :project`; validates `trigger_type`/`event_name` against known values. |
| `app/services/crux/automations/scheduler.rb` | create | Periodic check (e.g. via Redmine's existing background job scheduling mechanism) against `schedule_cron`; on due, checks the idempotency guard, then dispatches to `Crux::Agents::Runner`. |
| `app/services/crux/automations/event_dispatcher.rb` | create | Subscribes to the `Version` model's status-change callback; on transition to closed, checks `event_name: 'version_closed'` policies for that project, idempotency-guards, dispatches. |
| `app/models/version.rb` (Core Platform hook, via a Redmine hook listener, not a direct core-file edit) | create (hook) | A `Redmine::Hook::Listener` on the Version status-change event, calling `EventDispatcher` — does not modify Redmine's own `Version` model source, consistent with `architecture.md`'s "Core Platform is never modified by Crux" assumption. |
| `app/controllers/project_crux_automations_controller.rb` (crx-001/009) | modify | Real CRUD for `crux_automation_policies`, gated `crux:manage_integrations`. |
| `app/views/shared/_crux_approval_card.html.erb` (crx-003), Pending Actions/Runs views | modify | "Automated" badge shown when `crux_execution_plans.origin == 'automation'`, distinguishing it from a chat-originated plan per the approval-fatigue concern. |

### Implementation Notes

- **Two named trigger shapes only, not a generic event bus.** `Crux::Automations::Scheduler` (cadence, matching Scrum Master's "a scheduled ceremony trigger") and `Crux::Automations::EventDispatcher` (hooked to exactly one event, `Version` closing, matching Release Manager's "a version-close trigger") are the only two mechanisms this task builds. **Why sufficient now**: these are the only two trigger phrases named anywhere in the doc set for Phase 3's agents; a generic arbitrary-event bus is speculative infrastructure nothing currently cites. **When to revisit**: `workflow_engine.md`'s own Future Enhancements already names "Marketplace-contributed custom step types once the Future Marketplace module ships" (Phase 4) — that's the natural point to generalize `EventDispatcher` into a real pub/sub bus instead of two hardcoded event names.
- **Automation changes only what starts a plan, never how it's approved.** Both trigger paths converge on the *same, unmodified* `Crux::Agents::Runner` (crx-004) and Approval Gate (crx-003) — no new execution path bypasses `crux:approve`/`crux:approve_destructive`. This is the direct, load-bearing answer to `roadmap.md`'s own "automation before trust" risk: automation cannot silently increase what executes without a human decision, only what prompts the human to be asked.
- **Idempotency guard**: if a policy's last-produced plan is still non-terminal (`planned`/`awaiting_approval`/`executing`), skip this firing rather than spawning a duplicate. **Why sufficient now**: Phase 3's assumption is a single-cadence-per-project trigger, not concurrent independent automation streams. **When to revisit**: if a project needs multiple simultaneous automation-spawned plans in flight, this guard becomes a per-policy (not per-project) check — not needed yet.
- **Core Platform is never modified directly** — the `Version`-close hook uses Redmine's own `Redmine::Hook::Listener` mechanism (the same pattern crx-001's `crux_admin_hooks.rb` already established for injecting a stylesheet), not a source edit to Redmine's `Version` model.
- **This does not resolve `vision.md`'s approval-fatigue open question** — the `origin`/`automation_policy_id` columns make automation-originated plans *visible* as such, which is a transparency improvement, not a solution (no batched approvals, risk-tiered gates, or periodic re-confirmation are built here). Flagged explicitly as an accepted residual risk carried forward, per `roadmap.md`'s own "automation before trust" framing.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Scheduled cadence firing | A policy with `schedule_cron` due now | A new plan is drafted, `origin: 'automation'`, `automation_policy_id` set | pending |
| 2 | Version-close event firing | A `Version` transitions to closed, a matching policy exists | A new plan is drafted with `event_name: 'version_closed'` context | pending |
| 3 | Idempotency guard — cadence | Policy's last plan still `awaiting_approval` when the next cadence fires | Firing is skipped, no duplicate plan | pending |
| 4 | Idempotency guard — event | A `Version` closed twice in quick succession (e.g. reopened and reclosed) | No duplicate plan for the same close event | pending |
| 5 | Approval gate unchanged for automation plans | An automation-spawned plan reaches `awaiting_approval` | Requires the identical `crux:approve`/`crux:approve_destructive` as a chat-originated plan | pending |
| 6 | Core Platform unmodified | Inspect the `Version` model source | No Crux-added code inside Redmine's own model file — hook-based only | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Configure a cadence policy | Project → Automations, create a weekly cadence policy | Fires on schedule, produces a real plan visible in Pending Actions with an "Automated" badge | pending |
| 2 | Configure a version-close policy | Create a policy for `version_closed`; close a Version | A plan is drafted immediately, badge visible | pending |
| 3 | Automated plan approval | Approve an automation-spawned plan | Executes identically to a chat-originated one | pending |
| 4 | Disable a policy | Toggle a policy off | No further firings occur | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Policy references a disabled agent | An automation policy's `agent_role` is currently disabled on the project | Firing is skipped/fails cleanly with a clear notification, not a crash | pending |
| 2 | Version closed with no matching policy | A `Version` closes on a project with no `version_closed` policy configured | No plan is drafted — the hook fires but finds no matching policy, a no-op | pending |
| 3 | Project's Crux AI module disabled after policy creation | A policy exists but the project later disables Crux AI | No firing occurs (the module gate, crx-001, still applies) | pending |
| 4 | Rapid repeated cadence misconfiguration | A cadence policy misconfigured to fire every minute | The idempotency guard prevents plan pile-up; no more than one non-terminal automation plan exists per policy at a time | pending |

### QA Test Plan

**Scope**: Automation policy configuration, both trigger mechanisms, idempotency, and confirmation that the approval gate is completely unmodified for automation-originated plans.

**Pre-conditions**: crx-001 through crx-012 in place.

**QA Steps**:
1. Configure a cadence policy; confirm it fires on schedule and produces a Pending Actions item with an "Automated" badge.
2. Configure a version-close policy; close a test Version; confirm immediate plan creation.
3. Approve an automation-spawned plan; confirm identical execution behavior to a chat-originated one.
4. Leave a plan `awaiting_approval` past the next cadence firing; confirm no duplicate plan is created.
5. Disable the Crux AI module on a project with an active policy; confirm no further firings.

**Expected Outcomes**: Automation never bypasses the approval gate; no duplicate plans from repeated/overlapping triggers; every automation-originated plan is visibly distinguishable from a chat-originated one.

**Out of Scope**: Webhook-sourced triggers (crx-017); resolving approval fatigue itself.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This capability has zero mechanism defined anywhere in `workflow_engine.md` — an early draft risked either inventing an over-broad generic event bus, or leaving the mechanism as vague as the source docs, both of which would make this task unimplementable or unreviewable. | Implementation Notes | Narrowed to exactly two named trigger shapes, each traced to a specific `agent_catalog.md` phrase. |
| 2 | HIGH | Core Platform must never be modified directly (`architecture.md`'s Assumption) — an early approach risked hooking `Version`'s close event via a direct source edit. | Code Changes, `Version` hook row | Specified as a `Redmine::Hook::Listener`, matching crx-001's existing hook pattern. |
| 3 | MEDIUM | Without an idempotency guard, a slow-to-approve automation-spawned plan could accumulate duplicates on every subsequent cadence firing. | Implementation Notes; Test Case Unit #3/#4 | Explicit guard specified and tested. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is `roadmap.md`'s own named risk area ("automation before trust") — any code path that let an automation-spawned plan skip or weaken the approval gate would be a direct governance violation, the single worst possible outcome for this task. | Test Case Unit #5 | Explicitly tested that automation plans require the identical gate. |
| 2 | MEDIUM | The module gate (crx-001) must still apply to automation firings — a policy shouldn't fire for a project that has since disabled Crux AI. | Test Case Edge #3 | Explicitly tested. |
| 3 | LOW | No new indexing concern beyond standard FK indexing on the new table (`project_id`, `automation_policy_id`) — confirmed straightforward. | — | Standard indexing applied per `database_design.md`'s existing conventions. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the two-trigger-shape narrowing, hook-based (not source-edit) Version integration, idempotency guard, and module-gate/approval-gate parity are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `dependent:` decision on association | `crux_automation_policies belongs_to :project` cleanup on project deletion not deliberately chosen | Not directly test-covered; flagged for implementation attention — set `dependent:` deliberately, matching crx-003's identical earlier finding |
| 2 | Race condition — two near-simultaneous Version closes | Two rapid Version-close events for the same project both attempt to fire the same policy | Yes — Edge Case #4 (rapid-misfiring pattern, same guard applies) |
| 3 | Policy referencing a disabled agent | Firing attempted against an agent no longer enabled | Yes — Edge Case #1 |
| 4 | Silent failure with no visible signal | A failed automation firing (e.g. disabled agent) produces no notification, leaving the gap invisible to the project admin | Yes — Edge Case #1 explicitly requires "a clear notification, not a crash" |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
