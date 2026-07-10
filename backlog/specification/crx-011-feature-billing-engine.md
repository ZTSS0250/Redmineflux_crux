## Metadata
- **Task ID**: crx-011-feature-billing-engine
- **Title**: Billing Engine — real outcome metering, quota enforcement, 3 plan tiers (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: MEDIUM
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `billing.md`, `database_design.md`, `roadmap.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Build the real Billing Engine per `billing.md`: quota enforcement at the Workflow Engine boundary (active projects, outcomes/month) and Knowledge Engine boundary (indexed objects), the three plan tiers (Starter/Team/Enterprise) as actual gating logic, and the Project Workspace → Settings → Usage panel + Administration → Billing rollup, replacing crx-001's placeholders. This is a recommended addition beyond `roadmap.md`'s literal Phase 2 capability list (which names only Agent Collaboration, Multiple AI Providers, GitHub, Slack) — included here because Phase 1 (crx-004) deliberately deferred it, `billing.md`'s Integrations tier row is only meaningful once Integration Engine ships connectors (crx-009/010, this phase), and `crux_runs`/`crux_outcomes` already exist with no new schema required.

**Goal**:

An org has a configured plan tier (Starter/Team/Enterprise); a Starter-tier project attempting a tier-restricted action (e.g. full prompt-template editing) is refused with a clear "requires Team" message; outcomes/month, active-project, and indexed-object quotas are checked and enforced at the point of use, not only at invoice time; a stakeholder can see real (not placeholder) usage data in Project → Settings → Usage.

**Objectives**:
- [ ] Implement quota checks at three boundaries: Workflow Engine (active projects, outcomes/month — checked before a project can enable Crux, and before a plan step executes), Knowledge Engine (indexed objects — checked before an indexing job runs).
- [ ] Implement the 3-tier capability gate table from `billing.md`: Agent editing, Knowledge indexing, Integrations, Usage visibility, Outcomes/month.
- [ ] Replace crx-001's placeholder Billing/Usage data with real queries over `crux_runs`/`crux_outcomes`.
- [ ] Resolve `billing.md`'s own Open Question on outcomes/month reset: calendar-month reset (not a rolling window) — a simpler engineering default, explicitly not a pricing decision.
- [ ] Resolve `billing.md`'s Open Question on in-flight runs at a plan downgrade: a run already executing keeps its original tier's rules; the next new run immediately sees the downgraded tier.
- [ ] Resolve `billing.md`'s Open Question on Outcome attribution across a hand-off chain (now genuinely relevant because of crx-007's `parent_run_id`): one Outcome per run that independently passes the 3 tests, never one Outcome per chain.

**Deliverables**:
- [ ] `Crux::Billing::QuotaGate` — checked at the Workflow Engine and Knowledge Engine boundaries.
- [ ] `Crux::Billing::TierPolicy` — the 3-tier capability table as queryable gate logic.
- [ ] `crux_settings` row: `key: 'plan_tier'`, `scope: 'global'`.
- [ ] `ProjectCruxSettingsController`'s Usage sub-section (crx-001) — real data.
- [ ] `GlobalCruxBillingController` (crx-001) — real cross-project rollup.

**Out of Scope**: Actual dollar pricing per tier, usage-based pricing below Starter, marketplace revenue share (`billing.md`/`future_scope.md`, a commercial not engineering decision); anomaly detection/alerting before a quota breach (`billing.md`/`analytics.md` Future Enhancements); a second, independent approver for `crux:approve_destructive` (`security.md` Open Question, unscheduled).

---

## Specification

**Complexity**: MEDIUM

**Reason**: `billing.md`'s own Design Decision explicitly forbids a separate counter table ("one ledger, not a ledger plus a billing shadow table"), so this task adds **zero new tables**; all quota checks are live queries over existing `crux_runs`/`crux_outcomes`/`crux_knowledge_sources` plus Redmine's own Project/module-enablement state. Lower schema risk than the HIGH tasks in this batch, though a false-positive quota block would be a real availability bug warranting explicit Gate 2 attention despite the overall MEDIUM rating.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/services/crux/billing/quota_gate.rb` | create | `#check!(project:, dimension:)` for `active_projects`/`outcomes_per_month`/`indexed_objects`; raises a typed, user-facing error if exceeded — called from Workflow Engine (crx-003) before enabling Crux on a new project or executing a plan step, and from Knowledge Engine (crx-005) before an indexing job runs. |
| `app/services/crux/billing/tier_policy.rb` | create | `#allows?(capability:, tier:)` for the 5 tier-gated capabilities in `billing.md`'s table; reads the current `plan_tier` setting live at the moment of the action (per `billing.md`'s "live plan lookup" Design Decision). |
| `app/services/crux/agents/runner.rb` (crx-004, extended crx-007) | modify | Outcome materialization logic unchanged in mechanism — confirmed to already produce one Outcome per independently-qualifying run, correctly handling chained runs (crx-007) without new code. |
| `app/controllers/project_crux_settings_controller.rb` (crx-001) | modify | Add a real Usage sub-section: current-period token spend, outcome count, quota headroom — replacing dummy Billing data folded in here per crx-001's own resolution. |
| `app/controllers/global_crux_billing_controller.rb` (crx-001) | modify | Real cross-project rollup, plan tier, upgrade-path messaging. |
| `app/controllers/global_crux_settings_controller.rb` (crx-006) | modify | Add the `plan_tier` setting as an editable, `crux:administer`-gated field. |

### Implementation Notes

- **Calendar-month reset, not a rolling window** (`billing.md`'s own Open Question) — recommended as the simpler engineering default; explicitly not a pricing decision (which `billing.md` itself places out of scope). Revisit if commercial requirements later demand a rolling window.
- **In-flight runs at a plan downgrade**: a run already executing keeps its original tier's rules (checked once at start); the *next* new run immediately sees the downgraded tier, consistent with `billing.md`'s "every tier-restricted action checks current plan state at the moment of the action."
- **Outcome attribution across a hand-off chain** (`billing.md`'s Open Question, now genuinely load-bearing because of crx-007's `parent_run_id`): resolved as **one Outcome per run that independently passes the 3 tests**, never one Outcome per chain/deliverable. A chain where only the final run produces a genuine fixed deliverable correctly yields one Outcome; a chain where two runs each independently produce a billable deliverable correctly yields two. **Why sufficient**: `crux_outcomes.run_id` is already a fixed single-run FK — collapsing a chain into one Outcome would require picking an arbitrary "primary" run and would contradict `billing.md`'s existing per-run framing. No schema change or chain-aware special-casing needed — crx-004's existing per-run Outcome test already gives the right answer once `parent_run_id` exists.
- **`QuotaGate` failures are user-facing and specific** ("requires Team," "outcomes/month cap reached"), never a generic permission error — per `billing.md`'s own Risk about tier confusion.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Tier gate blocks correctly | Starter-tier project attempts full prompt-template editing | Refused with a "requires Team" message | pending |
| 2 | Tier gate allows correctly | Team-tier project attempts the same | Allowed | pending |
| 3 | Outcomes/month quota enforced | Project at its outcomes/month cap, a new qualifying run completes | The plan step is blocked *before* execution, with a clear quota message, not after | pending |
| 4 | Calendar-month reset | Quota check at the start of a new calendar month | Count resets to zero | pending |
| 5 | Chained-run Outcome attribution | A crx-007 hand-off chain where both runs independently qualify | Two separate `crux_outcomes` rows, not one | pending |
| 6 | In-flight run unaffected by downgrade | A run starts under Team tier, org downgrades to Starter mid-run | The in-flight run completes under Team's original rules | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Usage panel shows real data | Project → Settings → Usage | Real token spend/outcome count/quota headroom, not crx-001's dummy figures | pending |
| 2 | Admin billing rollup | Administration → Billing | Real cross-project cost/outcome data | pending |
| 3 | Plan tier change takes effect immediately | Admin changes `plan_tier` from Team to Enterprise | A previously-blocked action (e.g. 13th integration) becomes immediately allowed | pending |
| 4 | Quota-approaching notification | Project nears its outcomes/month cap | Notification Engine (crx-003) warns the user before the Workflow Engine actually blocks the action, per `billing.md`'s User Flow | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Quota check race — two simultaneous approvals near the cap | Two plan steps approved at nearly the same instant, both would exceed the cap if both proceed | At most the cap's worth are allowed to proceed; the gate check is atomic against the live count | pending |
| 2 | Indexed-object quota at the Knowledge Engine boundary | A project's indexing job would exceed its indexed-object cap | The job is blocked/truncated at the boundary, not silently over-indexed | pending |
| 3 | Enterprise on-prem indexing still reports usage | An Enterprise project with on-prem indexing (per `billing.md`'s own example) | Usage still syncs to the Billing Engine for quota purposes, even though indexed content stays local | pending |

### QA Test Plan

**Scope**: Tier gating, quota enforcement at both named boundaries, calendar-month reset, chained-run Outcome attribution, and real Usage/Billing dashboard data.

**Pre-conditions**: crx-001 through crx-010 in place (crx-007's `parent_run_id` needed for the chained-attribution test; crx-009/010's integrations needed to exercise the Integrations tier gate meaningfully).

**QA Steps**:
1. Set an org to Starter tier; attempt a Team-gated action; confirm refusal with a clear message.
2. Upgrade to Team; confirm the same action now succeeds immediately (live plan lookup).
3. Drive a project to its outcomes/month cap; confirm the next qualifying action is blocked before execution.
4. Confirm the Usage panel and Administration Billing rollup show real, non-dummy data.
5. Exercise a crx-007 hand-off chain where both runs qualify as Outcomes; confirm two separate `crux_outcomes` rows.

**Expected Outcomes**: No tier-gated action ever succeeds outside its tier; no quota is exceeded silently; Outcome counting is accurate under chained runs.

**Out of Scope**: Actual pricing, anomaly detection/alerting.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | `billing.md`'s own Open Question on chained-run Outcome attribution was left unresolved — without an explicit answer, crx-007's new `parent_run_id` column risks silently double-counting or under-counting Outcomes. | Implementation Notes | Resolved: one Outcome per independently-qualifying run, no special-casing needed. |
| 2 | MEDIUM | Tier confusion risk (`billing.md`'s own Risk) — a generic permission error instead of a specific "requires Team" message would confuse Starter-tier users. | Implementation Notes; Test Case Unit #1 | `QuotaGate`/`TierPolicy` errors are explicitly specific and user-facing. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | A race condition at the quota boundary (two near-simultaneous approvals both under the cap individually, but not together) could let a project exceed its outcomes/month cap. | Test Case Edge #1 | `QuotaGate` check specified as atomic against the live count, not a read-then-write race. |
| 2 | MEDIUM | No new tables means no new indexing concern for storage, but the live quota queries themselves (count of outcomes this period, count of indexed objects) must not be unscoped/unbounded — reuses `database_design.md`'s existing `(project_id, created_at)` composite index guidance rather than introducing a new slow query pattern. | Implementation Notes | Confirmed to reuse existing indexes, no new query shape introduced. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — chained-run Outcome attribution, specific tier-error messaging, and atomic quota checks are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Race condition at a quota boundary | Two concurrent actions both pass a non-atomic quota check | Yes — Edge Case #1 |
| 2 | Missing `.includes` for associations iterated in a view | Usage/Billing dashboards N+1 query outcomes per project row | Not directly test-covered (shared concern with crx-012's Analytics dashboards, addressed there); flagged for implementation attention |
| 3 | Date/time comparison without timezone conversion | Calendar-month reset computed in server time instead of a consistent billing-cycle timezone | Not directly test-covered; flagged for implementation attention — billing period boundaries should use a single consistent timezone (e.g. UTC) regardless of viewer locale |

Verdict: Approved. Items #2 and #3 are implementation-time attention items rather than dedicated tests in this task's scope, since dashboard query optimization is more centrally crx-012's concern and timezone consistency for billing periods is a configuration convention rather than independently testable business logic here.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
