## Metadata
- **Task ID**: crx-012-feature-analytics-engine
- **Title**: Analytics Engine — 8 canonical dashboards (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: MEDIUM
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `analytics.md`, `database_design.md`, `roadmap.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Build the real Analytics Engine — the eight canonical dashboards (Project, Organization, Agent, Token, Model, Performance, Outcome, Cost) as live queries over `crux_runs`/`crux_outcomes`/`crux_conversations`, replacing crx-001's placeholder Project Analytics tab and Administration Dashboard/Usage tabs, with `crux:view_analytics`/`crux:view_billing` enforced per widget. A recommended addition alongside crx-011, beyond `roadmap.md`'s literal Phase 2 list — justified because `analytics.md`'s own Risks section names Phase 2's multi-provider volume increase as the trigger point for needing this load-tested, and crx-007's new `conversation_id` column is what finally makes every run (including direct chat replies) correctly attributable to a project.

**Goal**:

A project lead can open the Project Dashboard and see real run counts, approval rate, outcomes delivered, and token/cost spend. A platform administrator can open the Organization Dashboard and see a real cross-project rollup. Every dashboard is a query, never a separately maintained number that could drift from the Run Ledger.

**Objectives**:
- [ ] Implement all 8 dashboards as query definitions over `crux_runs`/`crux_outcomes`/`crux_conversations`, per `analytics.md`'s exact per-dashboard metric list.
- [ ] Enforce `crux:view_analytics` for all 8; additionally `crux:view_billing` for Cost-Dashboard-derived widgets.
- [ ] Resolve `analytics.md`'s own Open Question on Performance Dashboard latency: no new column needed — approval-to-execution latency is computable today from `crux_execution_plans.approved_at` and `crux_runs.created_at` via the existing `plan_step_id → plan_id` path.
- [ ] Resolve `analytics.md`'s own pending Assumption on refresh cadence: Project/Agent-scoped dashboards as live queries; Organization/Cost dashboards get a short TTL cache (5-15 min), not a full background rollup pipeline, since Phase 2's volume doesn't yet justify one.
- [ ] Scope every cross-project view (Organization Dashboard) to the caller's permitted project set by default — never require manually excluding inaccessible projects.

**Deliverables**:
- [ ] `Crux::Analytics::ProjectDashboard`, `::OrganizationDashboard`, `::AgentDashboard`, `::TokenDashboard`, `::ModelDashboard`, `::PerformanceDashboard`, `::OutcomeDashboard`, `::CostDashboard` — 8 query-definition classes, no new tables.
- [ ] `ProjectCruxAnalyticsController` (crx-001 placeholder) — real Project/Agent/Token/Performance/Outcome dashboard rendering.
- [ ] `GlobalCruxController`/Administration Usage tab (crx-001 placeholder) — real Organization/Model/Cost dashboard rendering.
- [ ] Short TTL cache layer for the Organization/Cost dashboards only.

**Out of Scope**: Custom/configurable dashboards beyond the 8 canonical (`analytics.md` Future Enhancements, unscheduled); a real background rollup/materialization pipeline at true production scale (deferred until load evidence justifies it); cross-project analytics beyond the Organization Dashboard's already-scoped rollup (`future_scope.md`).

---

## Specification

**Complexity**: MEDIUM

**Reason**: `analytics.md`'s own Design Decision explicitly forbids a separately maintained aggregate table ("none of them are backed by a separately maintained aggregate table"), so this is read-only, schema-free work — lower risk than the HIGH tasks in this batch. The one item warranting HIGH-caliber scrutiny despite the overall MEDIUM rating is the Organization Dashboard's cross-project query-scoping, which `analytics.md` itself names as a leakage risk structurally parallel to crx-005's permission-filter-before-rank concern.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/services/crux/analytics/project_dashboard.rb` | create | Runs this period + trend, approval rate, outcomes delivered by type, pending actions count, token/cost spend — scoped to one `project_id`. |
| `app/services/crux/analytics/organization_dashboard.rb` | create | Total runs across all Crux-enabled projects, module-enabled project count, org-wide approval rate, outcomes billed this vs. prior period, top agents/projects — **scoped to the caller's permitted project set by default**, never requiring manual exclusion. |
| `app/services/crux/analytics/agent_dashboard.rb` | create | Runs per agent, success/failure share, average tokens/cost per run, projects each agent is active on — viewable at project and org scope. |
| `app/services/crux/analytics/token_dashboard.rb` | create | `tokens_in`/`tokens_out` trend, per agent, per model/provider, per project. |
| `app/services/crux/analytics/model_dashboard.rb` | create | Runs/cost/outcome-success-rate per model, provider share of run volume — reads `crux_agents.provider` (crx-008). |
| `app/services/crux/analytics/performance_dashboard.rb` | create | Run volume over time, outcome success/failure rate, approval-to-execution latency (computed from existing `approved_at`/`created_at`, no new column), plan step completion rate. |
| `app/services/crux/analytics/outcome_dashboard.rb` | create | Outcomes by type, billed vs. unbilled, volume trend, per project/agent. |
| `app/services/crux/analytics/cost_dashboard.rb` | create | Total cost + trend, cost per project/agent/model, projected period-end cost vs. quota (crx-011), cost per outcome — gated additionally by `crux:view_billing`. |
| `app/controllers/project_crux_analytics_controller.rb` (crx-001) | modify | Renders Project/Agent/Token/Performance/Outcome dashboards for the current project. |
| `app/controllers/global_crux_controller.rb`/Administration Usage tab (crx-001) | modify | Renders Organization/Model/Cost dashboards; Cost widgets hidden from users without `crux:view_billing`. |
| `app/lib/crux/analytics/short_ttl_cache.rb` | create | A thin, generic 5-15 min cache wrapper applied only to Organization/Cost dashboard queries — not a background rollup job. |

### Implementation Notes

- **Performance Dashboard's approval-to-execution latency needs no new column.** `analytics.md`'s own Open Question asked whether new timestamp/status fields were needed — resolved here as **no**: latency is computable today from `crux_execution_plans.approved_at` and `crux_runs.created_at` via `plan_step_id → plan_id`, for any run that went through a plan step. Direct-chat-reply runs (no plan step) simply have no approval-latency metric — correctly excluded, not an error condition.
- **Refresh cadence**: Project/Agent-scoped dashboards as genuinely live queries (Phase 2's volume doesn't yet justify a caching layer); Organization/Cost dashboards get a simple short TTL cache, **not** a full background rollup pipeline. **Why sufficient now**: the simplest thing that satisfies "near-real-time," without over-building a rollup job before load evidence shows it's needed. **When to revisit**: once the load testing `analytics.md` itself calls for "ahead of Phase 2's multi-provider volume increase" actually shows query cost degrading — likely an early Phase 3 follow-up, not invented preemptively here.
- **Organization Dashboard's cross-project scoping is the one genuinely security-sensitive piece of this otherwise read-only task** — every cross-project aggregate query must filter to the caller's permitted project set *at the query layer*, never rely on the UI to hide inaccessible rows after the fact, mirroring crx-005's filter-before-rank precedent.
- **Cost and Outcome dashboards intentionally read the same source tables the Billing Engine (crx-011) invoices from**, so a user auditing "why was I billed this" always sees numbers that reconcile — no separate query definition drifts from crx-011's.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Project Dashboard scoping | Query for Project A | Returns only Project A's runs/outcomes | pending |
| 2 | Organization Dashboard scoping | User with `crux:view_analytics` on Projects A and B only, not C | Organization rollup includes only A and B, never C | pending |
| 3 | Approval-to-execution latency | A run tied to a plan step approved at T0, run created at T1 | Latency = T1 - T0, computed without any new column | pending |
| 4 | Direct-chat run excluded from latency metric | A run with no `plan_step_id` | Correctly excluded from the Performance Dashboard's latency metric, not an error | pending |
| 5 | Cost widget gating | User with `crux:view_analytics` but not `crux:view_billing` | Cost Dashboard widgets are hidden entirely | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Project Dashboard real data | Open Project → Analytics tab | Real run counts/approval rate/outcomes, replacing crx-001's dummy figures | pending |
| 2 | Organization Dashboard real data | Administration → Usage (or Dashboard) | Real cross-project rollup | pending |
| 3 | Model Dashboard reflects crx-008 providers | After crx-008 ships multiple providers, invoke agents on 2+ providers | Model Dashboard shows per-provider run/cost breakdown correctly | pending |
| 4 | Cache behavior on Organization Dashboard | Two requests within the TTL window | Second request served from cache, not a fresh query (verify via timing/logging, not user-visible difference) | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | User with `crux:view_analytics` on zero projects | Opens Organization Dashboard | Renders an empty/zero state, not an error or another org's data | pending |
| 2 | Stale cache after a plan tier change | Cost Dashboard cached just before a tier change affecting quota display | Cache respects its short TTL — stale window is bounded, not indefinite | pending |
| 3 | Agent with runs across multiple providers (crx-008) | Agent Dashboard for that agent | Correctly aggregates across providers, not silently dropping non-primary-provider runs | pending |

### QA Test Plan

**Scope**: All 8 dashboards' data accuracy, permission gating (`crux:view_analytics`/`crux:view_billing`), and cross-project scoping correctness.

**Pre-conditions**: crx-001 through crx-011 in place, ideally with crx-007/008/009 exercised for chained runs/multi-provider/integration data.

**QA Steps**:
1. As a project lead, confirm Project Dashboard figures match a manual count from `crux_runs`/`crux_outcomes`.
2. As an admin, confirm the Organization Dashboard rollup matches the sum of all Crux-enabled projects' data.
3. As a user with analytics-but-not-billing access on one project, confirm Cost widgets are absent, not just visually hidden.
4. As a user with analytics access on only 2 of 3 projects, confirm the Organization Dashboard never surfaces the third.

**Expected Outcomes**: Every number reconciles with a direct Run Ledger query; no cross-project leakage under any permission combination.

**Out of Scope**: Custom dashboards, background rollup pipeline.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | `analytics.md`'s own Open Question on Performance Dashboard latency risked being answered by adding new columns that duplicate data already derivable from existing timestamps. | Implementation Notes | Resolved with no new column, computed from existing `approved_at`/`created_at`. |
| 2 | MEDIUM | An early draft risked building a full background rollup job pre-emptively, over-engineering ahead of any load evidence. | Implementation Notes | Explicitly deferred; short TTL cache only, for now. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The Organization Dashboard's cross-project aggregation is a real cross-project data-leakage risk if scoping happens at the UI layer instead of the query layer — structurally the same class of risk crx-005's Gate 2 called out for Knowledge Engine retrieval. | Code Changes, `organization_dashboard.rb` row; Test Case Unit #2 | Scoping enforced at the query layer, explicitly tested. |
| 2 | MEDIUM | Without the caching layer, Organization/Cost dashboard queries could degrade as `crux_runs` grows — `analytics.md`'s own Risk names this explicitly. | Code Changes, `short_ttl_cache.rb` row | Short TTL cache added specifically for these two dashboards. |
| 3 | LOW | Cost widgets must be fully absent (not just visually hidden) for users without `crux:view_billing`, consistent with `ui_design.md`'s "removed, not disabled" pattern. | Test Case Unit #5 | Explicitly tested. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — no-new-column latency resolution, deferred rollup pipeline, query-layer cross-project scoping, the caching layer, and full-absence Cost-widget gating are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `.includes` for associations iterated in a view | Agent/Model dashboards N+1 query `crux_agents`/`crux_runs` per row | Not directly test-covered (this is a straightforward implementation-time requirement, same pattern crx-004's Part B item #1 flagged); required at implementation time — `.includes(:agent)` wherever runs are listed alongside agent data |
| 2 | Stale cache masking a real-time-sensitive change | A tier change or quota breach not reflected until the TTL expires | Yes — Edge Case #2 |
| 3 | Cross-project leakage via a scoping bug in aggregation, not the UI | The exact risk named in Gate 2 #1 | Yes — Test Case Unit #2 |

Verdict: Approved. Item #1 is an implementation-time attention item rather than a dedicated test, consistent with how crx-004 handled the identical pattern for its own dashboards.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
