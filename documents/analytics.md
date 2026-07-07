# Crux — Analytics Engine

**Version**: 1.0 · **Status**: Draft

## Purpose

The Analytics Engine turns the Run Ledger into decision-ready dashboards for project members, program leadership, and platform administrators. It answers three recurring questions at every altitude: what is AI doing, how well is it doing it, and what is it costing. It does not decide anything itself — it is a read layer over data other engines already produce.

## Scope

This document defines the eight canonical dashboards the Analytics Engine ships — Project, Organization, Agent, Token, Model, Performance, Outcome, and Cost — the tables each dashboard reads, and the design decision that none of them are backed by a separately maintained aggregate table. It does not define the Run Ledger's schema (see [database_design.md](database_design.md)), the invoicing logic that also reads this data (see [billing.md](billing.md)), or the permission model that gates dashboard access (see [security.md](security.md)).

## Responsibilities

- Aggregate `crux_runs`, `crux_outcomes`, and `crux_conversations` into the eight dashboards below, scoped correctly to project, agent, model, or organization.
- Enforce `crux:view_analytics` ("see project AI dashboards") and `crux:view_billing` ("see project-level usage and billing") on every dashboard and drill-down, as defined in [security.md](security.md), never exposing cross-project data to a user without access to that project.
- Stay read-only: the Analytics Engine never writes to `crux_runs` or `crux_outcomes`, and never maintains its own copy of them.
- Surface trends (token growth, cost trend, approval rate over time) as well as point-in-time snapshots.

## User Flow

A user opens a dashboard — Project Workspace → **Analytics** tab, or Administration → **Usage** / **Dashboard** for org-wide views (tab structure defined in [ui_design.md](ui_design.md)). The Analytics Engine resolves the caller's permission and project scope, runs the relevant query over `crux_runs` / `crux_outcomes` / `crux_conversations`, and renders the result. There is no separate "generate report" step for the near-real-time dashboards; heavier rollups (see Design Decisions) show an "as of" timestamp instead of a live figure.

## UI Description

Each dashboard is a page of stat tiles and time-series charts, consistent with the Project Workspace's **Analytics** tab and Administration's **Usage** and **Dashboard** tabs (see [ui_design.md](ui_design.md)). Every chart supports a date-range filter; every stat tile that aggregates money or tokens is drillable into the underlying runs. Cost-bearing widgets are hidden from users who hold `crux:view_analytics` but not `crux:view_billing`.

## Architecture

The Analytics Engine sits beside the Billing Engine as a second consumer of the Run Ledger (see [architecture.md](architecture.md)); both read `crux_runs` and `crux_outcomes`, neither owns them. Dashboards are query definitions, not stored data:

```
crux_runs ──────────┐
crux_outcomes ───────┼──▶  Analytics Engine (query layer)  ──▶  8 dashboards
crux_conversations ─┘
```

## Components

The eight dashboards, each with representative metrics and source tables.

### Project Dashboard
Scoped to one project, surfaced in the Project Workspace's Analytics tab.
- Runs this period, and trend vs. prior period
- Approval rate (approved plans ÷ proposed plans)
- Outcomes delivered this period, by type
- Pending Actions currently open
- Token/cost spend this period

Derived from: `crux_runs` (joined through `crux_plan_steps` → `crux_execution_plans` → `crux_conversations` to resolve `project_id`), `crux_outcomes` (has `project_id` directly).

### Organization Dashboard
Cross-project rollup for program and platform leadership, surfaced under Administration.
- Total runs across all Crux-enabled projects
- Number of projects with the Crux AI module enabled
- Org-wide approval rate
- Outcomes billed this period vs. prior period
- Top agents and top projects by run volume

Derived from: `crux_runs` and `crux_outcomes` aggregated without a project filter.

### Agent Dashboard
Per-agent performance, viewable at project scope and at organization scope.
- Runs per agent
- Success vs. failure outcome share per agent
- Average tokens and average cost per run, per agent
- Projects each agent is active on

Derived from: `crux_runs` (`agent_id`), `crux_outcomes` (`outcome_type`, joined via `run_id`).

### Token Dashboard
Token consumption, the leading indicator for cost.
- `tokens_in` vs. `tokens_out` trend over time
- Tokens consumed per agent
- Tokens consumed per model/provider
- Tokens per project

Derived from: `crux_runs` (`tokens_in`, `tokens_out`).

### Model Dashboard
Comparison across models and providers to support model-selection decisions in the Model Layer and Provider Layer.
- Runs per model and per provider
- Cost per model
- Outcome success rate per model
- Provider share of total run volume

Derived from: `crux_runs` (`model`, `provider`, `cost`), `crux_outcomes` (`outcome_type`).

### Performance Dashboard
Operational health of the agent execution pipeline.
- Run volume over time, by agent and by project
- Outcome success/failure rate
- Approval-to-execution latency (time between plan approval and run creation)
- Plan step completion rate

Derived from: `crux_runs`, `crux_outcomes`, and `crux_execution_plans` / `crux_plan_steps` status. See Assumptions — the exact timestamp/status columns needed for latency metrics are defined authoritatively in [database_design.md](database_design.md).

### Outcome Dashboard
The business value delivered by AI work, independent of cost.
- Outcomes by `outcome_type` (e.g., issues created, documents generated, tests generated)
- Outcomes billed (`billed_at` populated) vs. unbilled
- Outcome volume trend
- Outcomes per project and per agent

Derived from: `crux_outcomes` primarily, joined to `crux_runs` for agent/model attribution.

### Cost Dashboard
Spend tracking, gated by `crux:view_billing`.
- Total cost this period, and trend
- Cost per project, per agent, per model
- Projected period-end cost vs. plan quota (see [billing.md](billing.md))
- Cost per outcome (efficiency metric)

Derived from: `crux_runs` (`cost`), `crux_outcomes` (for outcome-based cost attribution). Feeds the same numbers the Billing Engine invoices from, but never invoices itself.

## Sequence Flow

```
User opens dashboard
        │
        ▼
Analytics Engine checks crux:view_analytics / crux:view_billing
        │
        ▼
Resolve scope (project / agent / model / organization)
        │
        ▼
Query crux_runs + crux_outcomes (+ crux_conversations)
        │
        ▼
Render stat tiles + charts
```

## Design Decisions

- **All eight dashboards are derived queries, never separately maintained aggregate tables.** Crux keeps exactly one ledger — `crux_runs` and `crux_outcomes` — and every dashboard, invoice, and audit view is a query over it (consistent with the "single source of truth" guarantee in [database_design.md](database_design.md)). No dashboard can drift from the Run Ledger because no dashboard stores its own numbers.
- Cost and Outcome dashboards intentionally read the same source tables the Billing Engine invoices from, so a user auditing "why was I billed this" always sees numbers that reconcile with Analytics.
- Dashboard scope (project vs. organization) is a query parameter, not a schema distinction — the same query engine serves the Project Dashboard and the Organization Dashboard with different filters.

## Assumptions

- **Refresh cadence**: run/outcome counts, Pending Actions, and other Project Dashboard widgets are near-real-time (queried live or cached with a sub-minute TTL). Heavier aggregates — Organization Dashboard, Cost Dashboard trend charts, cross-project Model/Token comparisons — are refreshed on an hourly rollup cadence to bound query cost as `crux_runs` grows. This cadence is an assumption pending confirmation against production load characteristics.
- The `crux_runs` columns enumerated in the shared data model are the fields relevant to analytics, not necessarily exhaustive; Performance Dashboard latency metrics assume additional timestamp/status detail exists and defer the exact column names to [database_design.md](database_design.md).
- Dashboard queries run against the same operational database as the Run Ledger for GA; a dedicated analytics replica is not assumed for Phase 1.

## Risks

- **Query cost at scale** — without the hourly-rollup cadence, Organization and Cost dashboards could degrade as `crux_runs` grows across many projects; the rollup boundary needs load testing ahead of Phase 2's multi-provider volume increase.
- **Cross-project leakage** — a scoping bug in the Organization Dashboard's aggregation could expose project-level detail to a user who only holds `crux:view_analytics` on one project; scope filters must be enforced at the query layer, not the UI layer.
- **Metric drift between documents** — because Analytics and Billing read the same tables but present different labels, a metric renamed in one document without updating the other could confuse operators.

## Open Questions

- What is the authoritative refresh cadence and caching strategy — uniform per dashboard, or configurable per organization/plan tier?
- Does the Performance Dashboard require new fields on `crux_runs` / `crux_execution_plans` (e.g., an explicit status or completion timestamp) beyond those enumerated in the shared data model, and who owns adding them?
- Should Cost Dashboard figures be shown to project members without `crux:view_billing` in an anonymized or capped form, or fully hidden?

## Best Practices

- Treat every new dashboard metric as a query against `crux_runs` / `crux_outcomes` first; only propose a new column on the ledger if no existing field can answer the question.
- Keep Cost and Outcome dashboard definitions in lockstep with the Billing Engine's invoicing queries so the two never silently diverge.
- Default every cross-project view to the caller's permitted project set — never require the caller to manually exclude projects they cannot see.

## Example Scenarios

A project lead opens the **Project Dashboard** before a sprint review and sees 42 runs this week, an 88% approval rate, and 6 outcomes delivered (4 issues created, 2 wiki pages generated) — all read live from `crux_runs` and `crux_outcomes` filtered to that project.

A platform administrator opens the **Organization Dashboard** and notices the Developer agent's cost per run rose 30% month over month. They drill into the **Model Dashboard**, see the increase concentrated in one provider, and take it to that provider's configuration in the Model Layer.

## Future Enhancements

Anomaly detection on cost and token trends (alerting before a quota is breached), configurable custom dashboards beyond the eight canonical ones, and per-organization refresh-cadence controls are natural extensions once the eight canonical dashboards are stable. Cross-project analytics for Enterprise organizations are explored further in [future_scope.md](future_scope.md).
