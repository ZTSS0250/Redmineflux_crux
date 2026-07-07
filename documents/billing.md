# Crux — Billing

**Version**: 1.0 · **Status**: Draft

## Purpose

The Billing Engine turns governed AI activity into a usage and cost record teams can trust — not via a separate metering system, but by reading the same Run Ledger that already proves what happened, who approved it, and what it produced. Its purpose: "what did AI do, and what did it cost" is answerable from one place, for one deliverable, exactly once.

## Scope

Covers outcome-based billing, token usage tracking, quota enforcement, and the three plan tiers (Starter, Team, Enterprise). Does not cover the Run Ledger's schema ([database_design.md](database_design.md)), plan-step execution ([workflow_engine.md](workflow_engine.md)), or the crux:view_billing permission model ([security.md](security.md)).

## Responsibilities

- Materialize a crux_outcomes row only when a plan step passes all three Outcome tests (below).
- Track token and cost data per run — tokens_in, tokens_out, cost, model, provider — via crux_runs.
- Enforce quota dimensions (active projects, indexed objects, outcomes/month) at the point of use, not only at invoice time.
- Present monthly and historical usage to stakeholders per their permission level.
- Gate tier-restricted capabilities (agent editing, on-prem indexing, integration limits) against the account's plan.

## User Flow

1. A stakeholder with crux:view_billing opens Project → Crux → Settings → Usage for current-period token spend, outcome count, and quota headroom.
2. An administrator with crux:administer opens Administration → Crux → Billing for the cross-project rollup and plan management.
3. As a quota dimension nears its limit, the Notification Engine warns users before the Workflow or Knowledge Engine actually blocks the action.
4. An action the plan doesn't allow (e.g., pipeline editing on Starter) is checked against a live plan lookup and refused with an explanation, not a silent failure.

## UI Description

Project Workspace → Crux → Settings → Usage shows a project's own consumption against its quotas. Administration → Crux → Billing shows the account-wide rollup, plan tier, and upgrade path. The Usage panel is a filtered view of the Billing dashboard, not a separate export.

## Architecture

The Billing Engine keeps no ledger of its own — it is a read/query layer over the Run Ledger and a gate-check layer in front of the Workflow and Knowledge Engines, per [architecture.md](architecture.md).

```
crux_runs (Run Ledger) --query--> Billing Engine --> Usage dashboards
                                        |
                          quota gate ---+---> Workflow Engine (plan-step execution)
                                        +---> Knowledge Engine (indexing)
```

## Components

**Outcome definition** — a crux_outcomes row exists only when a plan step passes three tests: (1) it produced a fixed deliverable type — an issue, document, code change, or report, not an open-ended chat reply; (2) it passed a human-approved gate; (3) it has a Run Ledger receipt — a crux_runs row with prompt, model, tokens, and output references. All three must hold; an unapproved step or a run with no fixed deliverable never becomes billable.

**Token usage tracking** — every crux_runs row records tokens_in, tokens_out, cost, model, and provider, tied to the agent, plan step, and user that produced it. This is the raw data the Billing Engine aggregates, never recomputed separately.

**Quota dimensions** — active projects, indexed objects, and outcomes/month. Active-project and outcome quotas are checked at the Workflow Engine boundary (enablement and plan-step approval); indexed-object quotas at the Knowledge Engine's ingestion boundary. All three block the action itself, not just future invoicing.

**Plan tiers**

| Capability | Starter | Team | Enterprise |
|---|---|---|---|
| Agent editing | Prompt text only | Full pipeline + prompt-template editing | Full pipeline + prompt-template editing |
| Knowledge indexing | Hosted only | Hosted only | Hosted or on-prem/local |
| Integrations | Core set, limited concurrency | Expanded set | Full 12-integration catalog, highest concurrency |
| Usage visibility | Project-level only | Project + account rollup | Project + rollup + data-residency controls |
| Outcomes/month | Lowest cap | Mid cap | Highest cap / negotiated |

## Sequence Flow

```
Plan step executes → crux_runs row written (Run Ledger)
   → passes fixed-deliverable + approval + receipt tests?
      yes → crux_outcomes row materialized → counts toward outcomes/month
      no  → run recorded, no Outcome, not billed
   → Billing Engine aggregates for dashboards and invoicing
```

## Design Decisions

- **One ledger, not a ledger plus a billing shadow table** — Outcomes are a query/materialization over Run Ledger rows, never a separately maintained counter. This is what makes "the billing event and the acceptance event are the same click" true: a separate tally could drift from what was actually approved and executed.
- **Quota enforcement at the boundary, not invoice time** — checking quotas at the Workflow and Knowledge Engines means a team learns it's over quota when it tries to act, not a month later on a bill.
- **Tier gates check a live plan lookup** — every tier-restricted action checks current plan state at the moment of the action, so a downgrade takes effect immediately.

## Assumptions

- Every billable plan step produces exactly one crux_runs row; retries or partial failures do not double-count toward outcomes/month.
- Price per Outcome, token, or seat is a commercial decision outside this document; this document defines what is measured, not its price.
- Enterprise on-prem indexing still reports usage to the Billing Engine for quota purposes, even though indexed content stays in the customer's environment.

## Risks

- **Approval-to-Outcome lag** — a step approved near a period boundary could materialize in the following period; the boundary rule needs to be explicit and consistent.
- **Quota gate false negatives** — a boundary check out of sync with actual Run Ledger state could block, or under-block, a team incorrectly.
- **Tier confusion** — a Starter user attempting a pipeline edit needs a clear "requires Team" message, not a generic permission error.

## Open Questions

- Should outcomes/month reset on a calendar month or a rolling window?
- How are Outcomes attributed when a plan step spans multiple agents — one per step, or one per deliverable?
- What happens to in-flight runs at the moment a plan downgrade takes effect mid-run?

## Best Practices

- Review the Usage panel before, not after, a quota-sensitive push such as a large bulk-issue-generation plan.
- Treat outcomes/month as a capacity signal, not just a cost signal — a team consistently near cap may need a tier change.
- Reconcile Billing Engine dashboards against raw Run Ledger exports periodically to confirm the one-ledger guarantee holds.

## Example Scenarios

**Billable Outcome**
> A Documentation Agent drafts a wiki page, a reviewer approves it, and the run completes with a stored output reference. All three Outcome tests pass, so a crux_outcomes row is created and counted toward outcomes/month.

**Non-billable run**
> A Requirement Analyst Agent answers a clarifying question in chat with no fixed deliverable and no approval step. The run is logged for cost tracking, but no Outcome is created — it was never billable by definition.

**Tier gate in action**
> A Team-tier project attempts a 13th concurrent integration and is blocked at the Integration Engine's configuration step with a message pointing to Enterprise, rather than a silent failure.

## Future Enhancements

Future pricing models — usage-based tiers below Starter, agent-specific pricing, or marketplace-connector revenue share — are tracked in [future_scope.md](future_scope.md); any such model must still resolve to the same Outcome definition and single-ledger design described here.
