# Crux — Vision

**Version**: 1.0 · **Status**: Draft

> This document formalizes and supersedes earlier internal drafts of Crux's product vision — the previous version of this file and the vision-related sections of `design_documents.md`. It is the canonical vision reference for the documentation set indexed in [README.md](README.md).

## Purpose

> Crux transforms Redmine into an AI-Native Project Management Platform. Instead of AI being a chatbot, AI becomes a team member capable of planning, analyzing, documenting, testing, reviewing, coordinating, and assisting users throughout the complete project lifecycle. Crux operates as an AI layer inside Redmine — every action permission-aware, auditable, governed, explainable, and approved by humans. AI assists users; humans always make the final decision.

### Mission

Make project delivery conversational without making it ungoverned. Delivering software through Redmine today means manually creating projects, breaking requirements into issues, planning sprints, writing documentation, generating test cases, and reporting status. Crux's mission is to let a user describe an outcome in natural language and have Crux do the surrounding work, while every consequential change still passes through a human decision point first.

## Scope

This document defines *why* Crux exists and what "success" looks like. It does not define how Crux is built (see [architecture.md](architecture.md), [system_design.md](system_design.md)) or how it looks (see [ui_design.md](ui_design.md)). It applies to Crux as a whole product across all [roadmap.md](roadmap.md) phases, not to any single agent, engine, or release.

## Responsibilities

### Product Goals

Crux is responsible for making the following outcomes achievable:

- Create a fully-structured project — versions, milestones, issues, wiki — from a single natural-language request.
- Turn a raw idea into requirements, a roadmap, and an estimated backlog without manual data entry.
- Produce documentation, test cases, release notes, and status reports on demand.
- Give every stakeholder a governed way to answer "what changed, who approved it, and why" for any AI-driven action.
- Let each project adopt AI capability at its own pace, choosing its own agents, knowledge sources, and integrations.

### Success Criteria

Crux succeeds when teams complete materially more project work through human–AI collaboration while every AI-driven change remains traceable to an approving human, a specific agent, and a specific model. AI should measurably reduce repetitive work without displacing human judgment over what should be built. Humans define goals; AI accelerates execution; together they deliver better software.

## User Flow

The canonical interaction pattern — prompt, clarification, plan, approval, execution — is specified once in [workflow_engine.md](workflow_engine.md) and [chat_engine.md](chat_engine.md); a condensed version appears under Sequence Flow below. This document only constrains that a human decision point must exist before execution.

## UI Description

Vision does not prescribe screens. The Project Workspace and Administration surfaces that realize it are specified in [ui_design.md](ui_design.md) and summarized in [plugin_overview.md](plugin_overview.md).

## Architecture

The vision is realized through the 19 modules in [architecture.md](architecture.md). This document constrains what those modules must guarantee — approval before execution, an auditable record of every action, permission-aware data access — not how they are implemented.

## Components

Capability is delivered through named, scoped agents, not one generic assistant (Principle 3). The twelve-agent roster and rollout phasing live in [agent_catalog.md](agent_catalog.md); the engines that host and coordinate them are in [architecture.md](architecture.md).

## Sequence Flow

Condensed conversation lifecycle (full detail in [workflow_engine.md](workflow_engine.md)):

```
Prompt → Intent Detection → Knowledge/Context Search → [Clarify if needed]
       → Execution Plan → Preview → Approval → Execute Tasks
       → Generate Results → Audit Log → Notification
```

## Design Decisions

Crux is built on six Core Principles. They are design decisions in the strictest sense: every other document in this set is expected to comply with them rather than re-justify them.

1. **Conversation First** — Natural language is the primary interface. Users describe outcomes, not fill forms.
2. **Human Approval** — No major operation (create, delete, close, deploy, bulk-update) executes without an explicit approval step.
3. **AI Agents as Team Members** — Capability is delivered through named, scoped agents, not one generic assistant.
4. **Enterprise Governance** — Every action is permission-checked, logged, auditable, explainable, and traceable.
5. **Project-Based & Modular** — Crux is opt-in per project; each project chooses its own agents, knowledge sources, integrations, and approval policies.
6. **Secure by Construction** — AI can only read/write what the acting user is already authorized to touch in Redmine.

## Assumptions

- Organizations adopting Crux already run Redmine (or Redmineflux) and intend to extend it, not replace it.
- Users are willing to review and approve AI-proposed plans rather than delegate final authority to AI outright.
- At least one model provider (see the Provider Layer in [architecture.md](architecture.md)) is configured before any agent can run.

## Risks

- **Approval fatigue** — Principle 2 can erode if users start approving large plans without reading them.
- **Permission drift** — Principle 6 depends on the Knowledge Engine always reflecting Redmine's current permission state; drift reintroduces the exact leak the principle prevents.
- **Trust recovery** — early unreliable agent output may suppress adoption even after quality improves.

## Open Questions

- How should "approval fatigue" be measured and mitigated — batched approvals, risk-tiered gates, periodic re-confirmation?
- Where is the line between an agent assisting and an agent being perceived as accountable?
- How does "humans always decide" extend once third-party agents ship through the Future Marketplace?

## Best Practices

- Introduce Crux to a project with a small set of agents and knowledge sources, then expand — Principle 5 applied, not just a rollout tactic.
- Treat every rejected or edited execution plan as product feedback on agent quality, not merely a workflow event.
- Review the Run Ledger and audit trail periodically even when nothing has gone wrong, so governance stays a habit.

## Example Scenarios

**Clarification example** — User: "Create an HRMS." Crux asks: Which technology stack? Expected delivery timeline? Authentication method? Database? Expected modules? Deployment environment?

**Execution plan example** — Crux proposes: Create Project · Generate Wiki · Create Versions · Generate Milestones · Create 84 Issues · Assign Users · Generate Documentation — shown with Estimated Time and Estimated AI Cost, and the actions Approve / Reject / Modify. Nothing in the plan executes until one of those actions is taken.

## Future Enhancements

Crux's long-term direction is to evolve beyond a conversational assistant into an AI Coordination Platform: multiple agents collaborating on a single conversation, organizations authoring and enabling their own custom agents, and a Future Marketplace (Phase 4) through which third-party agents, connectors, and knowledge sources can be added under the same governance model described in Principle 4. This evolution is sequenced in [roadmap.md](roadmap.md) and elaborated further in [future_scope.md](future_scope.md); at every phase, the six Core Principles remain the acceptance test for whether a new capability belongs in Crux.
