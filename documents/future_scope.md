# Crux — Future Scope

**Version**: 1.0 · **Status**: Draft

## Purpose

This document explores directions for Crux beyond Phase 4 of [roadmap.md](roadmap.md). Nothing here is a committed specification. Several other documents in this set already point forward to it — [billing.md](billing.md) on future pricing models, [security.md](security.md) on data residency, [knowledge_engine.md](knowledge_engine.md) on organization-wide retrieval, [agent_catalog.md](agent_catalog.md) on cross-project agent memory, and [integrations.md](integrations.md) on the broader connector ecosystem — and this document is where those forward pointers converge.

## Scope

Covers five forward-looking areas: Marketplace growth, multi-agent hand-off chains, on-prem/local-model indexing for Enterprise, MCP ecosystem growth, and organization-wide knowledge retrieval. Explicitly out of scope: committing any of these to a phase, agent, or release number — that only happens once one of these areas is pulled into [roadmap.md](roadmap.md) and [release_plan.md](release_plan.md) with real scope.

## Responsibilities

This document is not implementation-bearing; its only responsibility is to hold speculative direction so it doesn't get lost or reinvented inconsistently across the doc set.

## User Flow

Not applicable — none of the areas below have a defined user flow yet; each would need one specified at the point it enters an actual roadmap phase.

## UI Description

Not applicable, for the same reason. Where an area implies a UI surface (for example, a Marketplace listing page), that surface is named but not designed here.

## Architecture

Each area below extends the existing 19-module architecture ([architecture.md](architecture.md)) rather than proposing new modules, with one exception: the Future Marketplace module is already canonical and ships in Phase 4 — this document only discusses what grows on top of it afterward.

## Components

### Marketplace growth
Phase 4 ships the Future Marketplace as a listing mechanism for third-party agents and connectors ([agent_catalog.md](agent_catalog.md) already names "custom, user-defined agents via the Future Marketplace" as a direction). Beyond that, the marketplace could grow to include rating/review of third-party agents, a certification tier for agents that pass Crux's own governance checks (permission-awareness, auditability), and — as [billing.md](billing.md) flags forward — new pricing models such as usage-based tiers below Starter, agent-specific pricing, and marketplace-connector revenue share. Any such pricing model must still resolve to the same Outcome definition and single-ledger design described in [billing.md](billing.md). A marketplace agent remains an ordinary `crux_agents` row, still produces `crux_runs`, and is still subject to Approval Engine gates — the marketplace changes distribution, not governance.

### Multi-agent hand-off chains
Phase 2 introduces Agent Collaboration and Phase 4 introduces Multi-Agent Workflows, but neither resolves the open question of whether a hand-off (for example, Planner finishing and handing to QA within one conversation) produces one Run Ledger row or a linked chain of them — see [architecture.md](architecture.md) Open Questions. Future scope here is a formal hand-off primitive — an explicit, auditable link between runs — that would let arbitrarily long agent chains (Requirement Analyst → Planner → Developer → QA → Code Reviewer → Release Manager) be reconstructed and audited as a single traceable sequence rather than inferred after the fact. This is adjacent to the "agent-to-agent negotiation before a plan is submitted for approval" direction already named in [agent_catalog.md](agent_catalog.md).

### On-prem / local-model indexing for Enterprise
The Provider Layer already names Local Models and Ollama as canonical providers, and [billing.md](billing.md) already notes that Enterprise on-prem indexing still reports usage to the Billing Engine for quota purposes even though indexed content stays in the customer's environment. Future scope extends this into full indexing-pipeline locality: Enterprise organizations running fully on-prem models could also run the Knowledge Engine's indexing pipeline on-prem, so no knowledge source content leaves the organization's network even transiently. [security.md](security.md) frames this as "expanded data-residency options beyond Enterprise on-prem indexing" — this document treats data residency as the driving requirement, with indexing locality as the mechanism.

### MCP ecosystem growth
Phase 4 ships baseline MCP Support (Crux as both an MCP client and server). Future growth is in breadth, not the mechanism: more inbound tool integrations (external tools calling into Crux's agents) and more outbound ones (Crux's agents calling out to a growing library of MCP-compatible tools), plus the deeper native integrations and broader third-party connector ecosystem [integrations.md](integrations.md) already flags forward to this document — all governed by the same Approval Engine and permission checks as every other integration in [integrations.md](integrations.md).

### Organization-wide knowledge retrieval
The Knowledge Engine's eleven sources ([knowledge_engine.md](knowledge_engine.md)) are project-scoped today; that document already names organization-wide retrieval as a future direction, requiring "a second, organization-level permission-filter pass." This document treats that as one of five forward areas: a cross-project retrieval layer would let an agent answer questions spanning multiple projects an organization runs, while still resolving per-project Redmine permissions for every source at query time — not just at index time — so cross-project search never becomes a way to see data the querying user isn't authorized to see in Redmine itself. This is also the natural home for the "cross-project agent memory" direction named in [agent_catalog.md](agent_catalog.md).

## Sequence Flow

Not applicable at this stage of specification.

## Design Decisions

None of the five areas above have been decided as committed scope; the only decision this document makes is to keep them as named, distinct concepts so future planning discussions start from a shared vocabulary instead of re-deriving it independently in each topic document.

## Assumptions

- Every future area is assumed to inherit Crux's existing governance model (permission checks, Run Ledger, Approval Engine) rather than requiring a parallel one.
- Organization-wide knowledge retrieval and Marketplace growth are assumed to lean toward Enterprise-tier capability, consistent with [billing.md](billing.md)'s quota model, though this is not committed.

## Risks

- **Premature commitment** — if another document in this set treats any of these five areas as scheduled work, it will conflict with [roadmap.md](roadmap.md), which stops at Phase 4.
- **Permission model strain** — organization-wide knowledge retrieval is the area most likely to strain Principle 6, Secure by Construction, if per-project permission resolution isn't kept in the query path.
- **Marketplace trust** — third-party agents at scale reintroduce the "trust recovery" risk named in [vision.md](vision.md), at a level the twelve-agent catalog never had to face.

## Open Questions

- Does a hand-off chain (multi-agent) become a first-class Run Ledger concept, and does that require a schema change beyond what [database_design.md](database_design.md) defines today?
- Does on-prem indexing require a distinct Knowledge Engine deployment mode, or a configuration flag on the existing one?
- Who governs marketplace agent certification, and does it require a new permission beyond the nine already defined in [security.md](security.md)?

## Best Practices

- Treat this document as a parking lot, not a backlog — nothing here should be estimated or assigned until it is promoted into [roadmap.md](roadmap.md).
- Revisit this document at the start of Phase 4 planning to decide what, if anything, graduates into a Phase 5-equivalent scope.

## Example Scenarios

An Enterprise customer running fully on-prem Ollama models asks whether their indexed wiki content ever leaves their network — the answer today is "the model call stays on-prem, but the indexing pipeline is not yet on-prem," which is exactly the gap the On-prem/local-model indexing area above would close.

A third-party vendor wants to list a custom "Compliance Agent" on the Future Marketplace — today that is a Phase 4 mechanism with no certification tier, which is exactly the gap the Marketplace growth area above names without yet specifying.

## Future Enhancements

This document is itself the future-enhancements register for the whole doc set; items graduate out of it into [roadmap.md](roadmap.md) as they are committed.
