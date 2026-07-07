# Crux — Roadmap

**Version**: 1.0 · **Status**: Draft

## Purpose

This document sequences Crux's capability delivery across four phases, from the first conversational, human-approved actions in Redmine through a fully collaborative, marketplace-extensible AI layer. It is the authoritative phase breakdown that [release_plan.md](release_plan.md) and [future_scope.md](future_scope.md) build on.

## Scope

Covers the four canonical roadmap phases — what capability each unlocks, which agents and modules ship in it, which integrations go live, and the dependencies between phases. Does not map phases to version numbers or rollout mechanics (see [release_plan.md](release_plan.md)), nor cover work beyond Phase 4 (see [future_scope.md](future_scope.md)).

## Responsibilities

- Define, per phase, which agents from the twelve-agent catalog ([agent_catalog.md](agent_catalog.md)) reach general availability.
- Define, per phase, which of the 19 architecture modules ([architecture.md](architecture.md)) and which of the 12 integrations ([integrations.md](integrations.md)) go live.
- State the dependency chain between phases.

## User Flow

Not applicable — see [workflow_engine.md](workflow_engine.md) for the conversation lifecycle, present in increasingly capable form from Phase 1 onward.

## UI Description

Not applicable — see [ui_design.md](ui_design.md) for how each phase's capability surfaces in the Project Workspace and Administration.

## Architecture

Each phase is additive to the same 19-module architecture ([architecture.md](architecture.md)); no phase replaces a module shipped earlier. Phase 1 establishes the modules; Phases 2–4 mature them — the Provider Layer exists from Phase 1 but supports only one provider until Phase 2, and the Agent Engine hosts 7 agents until Phase 3 completes the roster at 12.

## Components

### Phase 1 — Conversational Foundation
Unlocks describing outcomes in chat and having Crux create and plan real project structure, with every action gated by human approval.
- **Capabilities**: Chat, Project Creation, Issue Creation, Planning, Approval Workflow.
- **Agents (GA)**: Requirement Analyst, Planner, Developer, QA Agent, Documentation Agent, Reporter, DevOps Agent — the full Phase 1 roster of seven.
- **Modules**: Core Platform, Conversation Engine, Intent Detection, Clarification Engine, Chat Engine, Workflow Engine, Agent Engine, Knowledge Engine, Approval Engine, Run Ledger, Administration, Project Workspace; Provider Layer and Model Layer support a single provider end-to-end.
- **Integrations**: none reach GA yet — the Integration Engine module exists architecturally, but no external connector ships until Phase 2.

### Phase 2 — Agent Collaboration & Connected Tools
Unlocks more than one agent contributing to a single conversation, a choice of model provider, and work that reaches outside Redmine into the tools teams already use.
- **Capabilities**: Agent Collaboration, Multiple AI Providers, GitHub Integration, Slack Integration.
- **Agents (new GA)**: Security Agent, Code Reviewer — added to the Phase 1 roster.
- **Modules matured**: Provider Layer and Model Layer now support multiple providers; Integration Engine goes live with its first two connectors.
- **Integrations (GA)**: GitHub, Slack.

### Phase 3 — Automation & Knowledge Depth
Unlocks work that previously required an explicit user prompt each time becoming an automatable workflow, and the Knowledge Engine's search capability maturing into a first-class feature.
- **Capabilities**: Automated Sprint Planning, Code Review, Test Generation, Knowledge Search.
- **Agents (new GA)**: Product Owner Agent, Scrum Master Agent, Release Manager Agent — completing the twelve-agent catalog.
- **Modules matured**: Workflow Engine supports automated (not solely user-triggered) workflows; Knowledge Engine adds search as a primary capability across its eleven knowledge sources.

### Phase 4 — Multi-Agent Ecosystem
Unlocks agents chaining work to one another, Crux acting as both an MCP client and server, organizations authoring their own agents, and a marketplace for distributing all of the above.
- **Capabilities**: Multi-Agent Workflows, MCP Support, Custom Agents, Marketplace.
- **Modules matured**: Agent Engine supports custom, non-catalog agents; Integration Engine adds MCP; Future Marketplace module ships.
- **Integrations (GA)**: MCP, plus the remaining canonical integrations (Bitbucket, Microsoft Teams, Jenkins, Azure DevOps, Webhooks, Email, Calendar) as they reach general availability alongside the marketplace.

## Sequence Flow

```
Phase 1                 Phase 2                  Phase 3                   Phase 4
Conversational   ──▶    Agent Collaboration ──▶  Automation &        ──▶   Multi-Agent
Foundation               + Multi-Provider          Knowledge Depth          Ecosystem
(7 agents,                + GitHub/Slack           (12-agent roster         (+ MCP, Custom
 1 provider,                                        complete, search)        Agents, Marketplace)
 0 integrations)
```

## Design Decisions

- Each phase is scoped so no agent or integration is promised before the modules it depends on are stable — Agent Collaboration (Phase 2) is not attempted before the Phase 1 Approval Engine and Run Ledger are proven, since collaboration multiplies the number of governed actions in flight.
- Phase 4's Marketplace is deliberately last: it depends on Phase 2's multi-provider support (a marketplace agent must be able to declare a provider without Crux hard-coding it) and on Phase 3's twelve-agent roster being stable (third-party agents need a settled catalog contract to extend rather than a moving target).
- The Phase 2 / Phase 3 agent split is precise, not approximate: Security Agent and Code Reviewer are Phase 2; Product Owner Agent, Scrum Master Agent, and Release Manager Agent are Phase 3. Where [agent_catalog.md](agent_catalog.md) labels all five collectively as "Phase 2/3," this document is the authoritative source for the exact split and should be treated as such for reconciliation.

## Assumptions

- Each phase reaches "complete" before the next phase's agents/integrations start shipping to GA, though early features of a phase may ship ahead of that phase's full completion (see the incremental-release pattern in [release_plan.md](release_plan.md)).
- Integrations not explicitly named against a phase (Bitbucket, Microsoft Teams, Jenkins, Azure DevOps, Webhooks, Email, Calendar) are assumed to land across Phase 3–4 rather than Phase 1–2, since only GitHub and Slack are named against Phase 2.

## Risks

- **Sequencing risk** — if Phase 2's multi-provider work slips, Phase 4's Marketplace timeline slips with it, since Marketplace depends on it.
- **Roster fragmentation** — shipping only 2 of 5 post-GA agents in Phase 2 risks users expecting the full catalog from [agent_catalog.md](agent_catalog.md) before Phase 3 delivers it.
- **Automation before trust** — Phase 3's Automated Sprint Planning removes a user prompt from the loop; if the approval-fatigue risk named in [vision.md](vision.md) hasn't been addressed by then, automating further could compound rather than relieve it.

## Open Questions

Carried forward from earlier engineering discussion (also tracked in [architecture.md](architecture.md)), unresolved at the roadmap level but relevant to phase sequencing:
- Is agent identity a dedicated `User` subtype or a lighter `Member` record — affects how Phase 2's multiple simultaneous agents are represented.
- Is the first response to a prompt ever synchronous, with only the agent run itself asynchronous — relevant to how responsive Phase 1's Chat Engine feels.
- Is a bulk action like "Create 84 Issues" one Plan Step or many — affects how Phase 1's Approval Engine and Run Ledger scale before Phase 3 automation increases plan size further.
- When Planner hands off to QA within one conversation (Phase 2 Agent Collaboration), is that one Run Ledger row or a chain — directly determines how Phase 4's Multi-Agent Workflows are audited.

## Best Practices

- Read this document alongside [agent_catalog.md](agent_catalog.md) and [architecture.md](architecture.md) before committing a feature to a phase — a capability only belongs in a phase if its agent and module dependencies are already GA in an earlier phase.
- Re-validate the Phase 4 Marketplace dependency chain (Phase 2 multi-provider, Phase 3 full roster) whenever either prerequisite's timeline changes.

## Example Scenarios

A team adopts Crux at Phase 1: they chat "Create a CRM project," approve the proposed plan, and the Developer and QA agents execute it — on a single model provider, with no external integrations yet configured.

The same team, now on Phase 2, connects GitHub; their Planner and the new Code Reviewer agent collaborate within one conversation to review a pull request before an issue is closed — the first time two agents contribute to a single Crux conversation.

## Future Enhancements

Work beyond Phase 4 — deeper marketplace mechanics, org-wide knowledge retrieval, expanded MCP ecosystem growth, and on-prem model indexing for Enterprise — is intentionally out of roadmap scope and tracked as forward-looking exploration in [future_scope.md](future_scope.md).
