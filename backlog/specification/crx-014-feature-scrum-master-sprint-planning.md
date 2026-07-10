## Metadata
- **Task ID**: crx-014-feature-scrum-master-sprint-planning
- **Title**: Scrum Master Agent — Automated Sprint Planning (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `agent_catalog.md`, `vision.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Enables the seeded-but-disabled Scrum Master `crux_agents` row (crx-004 seeded it `enabled: false`), writes its real prompt template, and wires it as the first consumer of crx-013's `scheduled_cadence` trigger — the concrete delivery of `roadmap.md`'s "Automated Sprint Planning" Phase 3 capability. Output (sprint plan + risk/dependency log) is delivered as agent output attached to a run, not a new persisted entity.

**Goal**:

A project can configure a recurring "sprint ceremony" cadence policy (crx-013); on schedule, Scrum Master drafts a sprint plan and risk/dependency log, surfaced as a plan preview (for any steps that change dates/assignments) and/or a chat-style report (for the narrative parts), going through the identical approval gate any other plan does.

**Objectives**:
- [ ] Write Scrum Master's real `prompt_template` (role: scrum master; context: sprint/version + issue graph; constraint: risk taxonomy; output: sprint plan + risk/dependency log).
- [ ] Configure Scrum Master as the `agent_role` for a `scheduled_cadence` automation policy (crx-013).
- [ ] Cross-reference issues, versions, and Analytics Engine (crx-012) velocity data to flag risk, per `agent_catalog.md`.
- [ ] Any date/assignment change Scrum Master proposes goes through an ordinary `crux:approve` plan step (facilitation only — "cannot reassign work or change dates without a plan step passing `crux:approve`," per `agent_catalog.md`'s explicit limitation).
- [ ] Confirm crx-013's idempotency guard holds under this agent's real cadence — a ceremony firing while a prior auto-generated sprint plan is still `awaiting_approval` must skip, not double up Pending Actions.

**Deliverables**:
- [ ] Real `prompt_template` for Scrum Master (crx-004's `crux_agents` schema, no new fields).
- [ ] New `crux_plan_steps.action_type` values: `create_sprint_plan`, `update_issue_schedule` (free-form column, no migration needed).
- [ ] A `crux_automation_policies` seed/example row (`capability: sprint_planning`, `agent_role: scrum_master`) as a reference configuration.

**Out of Scope**: Any change to the Approval Gate itself for automation-sourced plans (identical `crux:approve` path as chat-sourced ones, per crx-013); resolving `vision.md`'s open "how is approval fatigue measured/mitigated" question — stays genuinely open, an accepted residual risk, not solved by this task; predictive risk scoring, automated ceremony scheduling beyond the basic cadence (`agent_catalog.md`'s own Future Roadmap line for this agent).

---

## Specification

**Complexity**: HIGH

**Reason**: Not because the agent itself is architecturally complex (it's mostly configuration, like Phase 1's agents) — because this is literally the task `roadmap.md`'s own risk section names ("Phase 3's Automated Sprint Planning removes a user prompt from the loop... if approval-fatigue hasn't been addressed, automating further could compound rather than relieve it"), and crx-013's cross-firing idempotency guard has to actually hold under this agent's real cadence. Matches the security/governance-sensitivity criterion.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/models/crux/agent.rb` (crx-004) | modify | Add Scrum Master's real `prompt_template` content — structural sections only, per `agent_catalog.md`'s Assumption. |
| `db/seeds/crux_agents_seed.rb` (crx-004) | modify | Flip `Scrum Master Agent.enabled` to `true` (global default), per `roadmap.md`'s Phase 3 "new GA" listing. |
| `app/services/crux/agents/runner.rb` (crx-004) | reuse | No changes — Scrum Master dispatches through the exact same invocation path every prior agent uses. |
| `db/seeds/crux_automation_policies_example.rb` | create | A reference/example automation policy row demonstrating the `capability: sprint_planning` configuration, not auto-applied to any real project. |

### Implementation Notes

- **The risk/dependency log is rendered as structured run output, not a new `crux_*` table.** **Why sufficient now**: no Phase 3 consumer needs to query it programmatically. **When to revisit**: if a future trend-across-sprints dashboard needs it queryable, a dedicated table becomes worth adding then — not needed for GA.
- **crx-013's idempotency guard is exercised concretely here first**: a ceremony cadence firing while a prior auto-generated sprint plan is still `awaiting_approval` must skip, not double up Pending Actions. This task doesn't add new guard logic — it's the first real-world test of crx-013's guard under an actual agent's recurring cadence.
- **Scrum Master never itself executes a date/assignment change** — it only ever drafts a plan step; execution still requires `crux:approve`, per `agent_catalog.md`'s explicit limitation, unchanged from how every other Phase 1 agent's plan steps already work.
- **Analytics Engine (crx-012) velocity data informs Scrum Master's risk flagging** — this is a read dependency, not a new integration; `Crux::Analytics::AgentDashboard`/`PerformanceDashboard` query definitions (crx-012) are called directly, no new analytics surface is built here.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Scrum Master enabled by default | New project after this task ships | Scrum Master shows `enabled: true`, per `roadmap.md`'s Phase 3 GA listing | pending |
| 2 | Sprint plan produced on cadence | A `scheduled_cadence` policy configured with `agent_role: scrum_master` fires | A `create_sprint_plan` plan step is drafted | pending |
| 3 | Risk log references Analytics velocity data | Scrum Master's output | Cites/derives from `Crux::Analytics::PerformanceDashboard` data, not fabricated figures | pending |
| 4 | Idempotency under real cadence | A sprint plan still `awaiting_approval` when the next ceremony cadence fires | Firing skipped, no duplicate | pending |
| 5 | No unapproved date change | Scrum Master's output proposing an issue date change | Reaches Redmine only after `crux:approve`, never applied directly | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end automated sprint planning | Configure a sprint-ceremony cadence policy; wait for/force a firing | A sprint plan + risk log appears in Pending Actions with an "Automated" badge (crx-013) | pending |
| 2 | Approve a sprint plan | Approve the drafted plan | Issue schedule/assignment updates apply correctly | pending |
| 3 | Reject a sprint plan | Reject it | Plan returns to `planned` for revision, consistent with crx-003's Reject semantics | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | No sprint/version data available | Scrum Master fires on a project with no versions configured | Produces a clear "insufficient data" output rather than a fabricated plan | pending |
| 2 | Scrum Master disabled mid-cadence | Cadence fires after the project disables the agent | Firing is skipped/fails cleanly (per crx-013's Edge Case #1 pattern) | pending |

### QA Test Plan

**Scope**: Scrum Master's real behavior, the sprint-planning cadence configuration, and confirmation that automated sprint plans never bypass approval.

**Pre-conditions**: crx-001 through crx-013 in place; a project with version/issue data and Analytics Engine (crx-012) producing real velocity figures.

**QA Steps**:
1. Enable Scrum Master; configure a sprint-ceremony cadence policy.
2. Force/wait for a firing; confirm a sprint plan + risk log appears in Pending Actions, badged "Automated."
3. Approve it; confirm issue schedule/assignment changes apply only after approval.
4. Leave a plan `awaiting_approval` past the next cadence; confirm no duplicate.

**Expected Outcomes**: Automated Sprint Planning never applies a change without `crux:approve`; the idempotency guard holds under real repeated firing.

**Out of Scope**: Approval-fatigue mitigation itself; predictive risk scoring.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is the exact task `roadmap.md`'s own risk section names — treating it as "just another agent enablement" without extra scrutiny would understate its governance stakes. | Test Case Functional #2, Unit #5 | Explicit tests confirm no change ever applies without approval. |
| 2 | MEDIUM | The risk/dependency log risked being invented as a new persisted table when structured run output already suffices. | Implementation Notes | Explicitly resolved as run output, not new schema. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Any code path letting Scrum Master's automated output apply a date/assignment change without `crux:approve` would be a direct Principle 2 violation, in the one capability the roadmap itself flags as risky. | Test Case Unit #5 | Explicitly tested. |
| 2 | MEDIUM | crx-013's idempotency guard needed real-world verification under an actual recurring agent cadence, not just crx-013's own synthetic test. | Test Case Unit #4 | Explicitly retested here in a concrete scenario. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — no-unapproved-change guarantee and idempotency-under-real-cadence are both concrete tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing data producing a fabricated plan | Scrum Master invents sprint data for a project with no real versions/issues, producing misleading output | Yes — Edge Case #1 |
| 2 | Agent disabled mid-cadence | A firing dispatches to a since-disabled agent | Yes — Edge Case #2 |
| 3 | `permit` key missing on nested date-change payload | The sprint plan's date-change plan step accepts a malformed payload that silently fails to apply on approval | Not directly test-covered by a UI edge case; flagged for implementation attention — payload validation on `update_issue_schedule` steps at approval time |

Verdict: Approved. Item #3 is an implementation-time attention item since it concerns payload validation robustness rather than a distinct behavior already covered by Functional Test #2's approval flow.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
