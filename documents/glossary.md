# Crux — Glossary

**Version**: 1.0 · **Status**: Draft

## Purpose

This glossary defines every canonical term used across the Crux documentation set in one place, so all twenty documents can reference a single, consistent definition instead of restating or re-deriving one.

## Scope

Covers terms specific to Crux's product, architecture, and data model. It does not cover general Redmine terminology (project, issue, wiki, role) except where Crux gives an existing term additional meaning.

## Definitions (A–Z)

**Administration** — The global, cross-project configuration and monitoring surface for Crux, organized into 16 tabs: Dashboard, Agents, Providers, Models, Billing, Audit Logs, Usage, Knowledge, Projects, Permissions, Policies, Integrations, Settings, Health Monitoring, License, Future Features. See [ui_design.md](ui_design.md).

**Agent** — A named, scoped AI team member (for example, Planner or QA Agent) that performs a defined kind of work within Crux's governance model, rather than a single general-purpose assistant. The full catalog of twelve is defined in [agent_catalog.md](agent_catalog.md).

**Analytics Engine** — The read-only module that turns the Run Ledger into the eight canonical dashboards: Project, Organization, Agent, Token, Model, Performance, Outcome, and Cost. See [analytics.md](analytics.md).

**Approval Engine** — The module that gates every consequential AI action behind an explicit human decision (approve, reject, or modify) before an execution plan runs. See [approval_engine.md](approval_engine.md).

**Billing Engine** — The module that meters outcomes recorded in `crux_outcomes` against an organization's plan tier and quotas to produce billing. See [billing.md](billing.md).

**Chat Engine** — The module that manages the real-time conversational interface between a user and Crux's agents. See [chat_engine.md](chat_engine.md).

**Clarification Engine** — The module that generates follow-up questions when a user's request lacks enough information to produce a reliable execution plan.

**Conversation Engine** — The module that owns the lifecycle and state of a conversation between a user and Crux, from first prompt through completion.

**Core Platform** — Redmine's own native data and permission model (projects, issues, users, roles) that Crux reads and writes through rather than duplicating.

**Core Principles** — The six product-level rules Crux is built on: Conversation First, Human Approval, AI Agents as Team Members, Enterprise Governance, Project-Based & Modular, and Secure by Construction. See [vision.md](vision.md).

**Coverage Score** — A Knowledge Engine metric: indexed objects ÷ total addressable objects, across a project's enabled knowledge sources. It is a per-source and overall metric, not a global one, and reflects the last completed index pass rather than the current instant. See [knowledge_engine.md](knowledge_engine.md).

**Crux** — The AI-native operating layer plugin for Redmine (also branded Redmineflux) that this documentation set describes.

**Destructive Action Gate** — The stricter approval checkpoint, enforced through the `crux:approve_destructive` permission, applied to plan steps that delete, close, or deploy — distinct from and in addition to the ordinary `crux:approve` gate. See [approval_engine.md](approval_engine.md).

**Execution Plan** — The ordered set of Plan Steps Crux proposes in response to a request, shown to the user with estimated time and estimated cost, and requiring approval before any step runs.

**Future Marketplace** — The Phase 4 module through which third-party agents, connectors, and knowledge sources can be listed and adopted under Crux's existing governance model. See [future_scope.md](future_scope.md).

**Integration Engine** — The module that connects Crux to external systems and tools. See the twelve canonical integrations in [integrations.md](integrations.md).

**Intent Detection** — The module that classifies what a user is asking for from a natural-language prompt, before clarification or planning begins.

**Knowledge Engine** — The module that retrieves permission-filtered project context from Crux's eleven knowledge sources to ground agent output. See [knowledge_engine.md](knowledge_engine.md).

**Knowledge Source** — One of the eleven categories of Redmine data — Issues, Wiki, Repository, Documents, Files, News, Forums, Time Entries, Helpdesk, CRM, Custom Fields — the Knowledge Engine can index and retrieve from.

**MCP (Model Context Protocol)** — The standard protocol Crux uses to act as both a client and a server for external AI tools, shipping as MCP Support in Phase 4.

**Model Layer** — The module that abstracts the specific AI model being called, as distinct from the Provider Layer, which abstracts the vendor hosting it.

**Module Gate** — The per-project opt-in mechanism (Project Settings → Modules → Crux AI), enforced at the routing layer, that determines whether a project has any Crux surface at all. See [release_plan.md](release_plan.md).

**Notification Engine** — The module that delivers alerts about Crux activity — approvals needed, runs completed, outcomes delivered — to users through their configured channels.

**Outcome** — A billable, tracked unit of value delivered by a Run, recorded in `crux_outcomes` with an `outcome_type` and, once invoiced, a `billed_at` timestamp.

**Pending Action** — An execution plan or plan step awaiting human approval, surfaced in the Project Workspace's Pending Actions tab. Implemented as a status filter over `crux_plan_steps`, not a separately maintained table. See [database_design.md](database_design.md).

**Permission** — One of the nine access-control grants Crux defines — `use_crux`, `crux:approve`, `crux:approve_destructive`, `crux:manage_agents`, `crux:manage_knowledge`, `crux:manage_integrations`, `crux:view_billing`, `crux:view_analytics`, `crux:administer` — layered on top of Redmine's existing role system. See [security.md](security.md).

**Plan Step** — One discrete, orderable unit of work inside an Execution Plan. Whether a large action like "Create 84 Issues" is one Plan Step or many is an open question tracked across this documentation set.

**Project Workspace** — The project-scoped Crux surface, organized into nine tabs: Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings. See [ui_design.md](ui_design.md).

**Provider Layer** — The module that abstracts which AI vendor — OpenAI, Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models, Mock Provider, or a future provider — services a given model call.

**Quota** — A plan-tier limit on active projects, indexed objects, or outcomes/month, enforced by the Billing Engine at the point of use. See [billing.md](billing.md).

**Run** — A single recorded invocation of an agent against a model, captured as one row in `crux_runs` with its tokens, cost, and output reference.

**Run Ledger** — The append-only `crux_runs` / `crux_outcomes` record that is the single source of truth for audit, billing, and analytics across Crux — never duplicated into a separately maintained aggregate table. See [database_design.md](database_design.md).

**Workflow Engine** — The module that drives a conversation through its states — draft, clarify, plan, approve, execute — coordinating the Clarification, Approval, and Agent Engines. See [workflow_engine.md](workflow_engine.md).

## Responsibilities

Define every canonical term above once, consistently, for reuse by all other documents in the set.

## User Flow

N/A — see the individual topic documents for how each term's concept is actually used.

## UI Description

N/A — see [ui_design.md](ui_design.md) and [plugin_overview.md](plugin_overview.md).

## Architecture

N/A — see [architecture.md](architecture.md).

## Components

N/A — every named component and concept in the system is defined above under Definitions (A–Z).

## Sequence Flow

N/A — see the individual topic documents.

## Design Decisions

Terms here are defined to match the shared kernel exactly; no document in the set should introduce an alternate name for a term defined here.

## Assumptions

N/A beyond what is noted inline above (Coverage Score's definition is sourced from [knowledge_engine.md](knowledge_engine.md); Destructive Action Gate is this document's name for the mechanism [approval_engine.md](approval_engine.md) and [security.md](security.md) describe via the `crux:approve_destructive` permission).

## Risks

Term drift — if another document renames or redefines a term above without updating this glossary, cross-document consistency breaks.

## Open Questions

N/A — see the individual topic documents for the open questions carried across this set (agent identity representation, synchronous first response, Plan Step granularity, and multi-agent Run Ledger chaining).

## Best Practices

When introducing a new concept in any document, add it here in the same edit rather than letting definitions diverge across files.

## Example Scenarios

N/A — see the individual topic documents.

## Future Enhancements

New terms are added here as Crux's scope grows, particularly from [future_scope.md](future_scope.md).
