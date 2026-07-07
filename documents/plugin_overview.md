# Crux — Plugin Overview

**Version**: 1.0 · **Status**: Draft

> This document replaces the earlier `plugin_overview.md` draft and folds in the still-relevant parts of `design_documents.md`'s product overview; see [README.md](README.md) for how the full 20-document set relates to those earlier drafts.

## Purpose

Crux is an AI-native operating layer for Redmine: a plugin that lets project managers, developers, QA, and executives run project work through conversation, while every consequential change still passes through a human approval gate before it touches the project. This document answers "what is Crux, at a glance" for a reader new to [vision.md](vision.md) and [architecture.md](architecture.md).

**Elevator pitch**: Describe what you want — "create an HRMS with employee, payroll, and leave modules" — and Crux asks the clarifying questions a competent PM would ask, drafts a full execution plan with estimated time and cost, and only touches the project after you approve it. Every step is logged against a real user, agent, and model, so the audit trail is as complete as the automation.

## Scope

Crux is intended for four audiences inside a Redmine-run organization:

| Persona | What Crux gives them |
|---|---|
| Project Managers | Conversational project setup, roadmap and milestone generation, sprint planning, status reporting |
| Developers | Issue and requirement generation, code review assistance, documentation drafting, DevOps guidance |
| QA | Automated test case generation, bug review assistance, coverage gaps surfaced from existing issues |
| Executives / Stakeholders | Project health reports, weekly summaries, and an auditable record of every AI-driven change |

This document covers positioning and feature summary only. Detailed UI is in [ui_design.md](ui_design.md); detailed engineering is in [architecture.md](architecture.md) and [system_design.md](system_design.md).

## Responsibilities

| Feature Area | What It Does |
|---|---|
| Conversational project creation | Turns a natural-language request into a structured project — versions, milestones, issues, wiki |
| Execution plans with approval gate | Previews every proposed action with estimated time/cost before anything executes |
| Named AI agents | Twelve scoped agents (see [agent_catalog.md](agent_catalog.md)) instead of one generic assistant |
| Knowledge-aware responses | Answers and plans are grounded in the project's own issues, wiki, repository, and documents |
| Run Ledger & audit trail | Every agent action recorded — who, which agent, which model, what data, what output |
| Multi-provider model layer | OpenAI, Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models, Mock Provider |
| Integrations | GitHub, GitLab, Bitbucket, Slack, Microsoft Teams, Jenkins, Azure DevOps, Webhooks, MCP, Email, Calendar |
| Analytics & billing | Usage, cost, and outcome dashboards at both project and organization level |

## User Flow

Every capability above runs through the same conversation lifecycle — prompt, clarification, plan, approval, execution — detailed in [workflow_engine.md](workflow_engine.md) and [chat_engine.md](chat_engine.md).

## UI Description

Crux surfaces in two places. Inside an opted-in project, the **Project Workspace** exposes nine tabs: Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings. At the organization level, **Administration** exposes sixteen tabs: Dashboard, Agents, Providers, Models, Billing, Audit Logs, Usage, Knowledge, Projects, Permissions, Policies, Integrations, Settings, Health Monitoring, License, Future Features. Tab behavior is in [ui_design.md](ui_design.md); the engines behind each tab are in [architecture.md](architecture.md).

## Architecture

Crux is composed of 19 modules spanning conversation handling, agent execution, knowledge retrieval, approval, audit, billing, and integrations, with Redmine's own Core Platform (Projects, Issues, Users, Roles, Wiki, Repository, Versions, Time Entries) as the system of record. Full detail in [architecture.md](architecture.md) and [system_design.md](system_design.md).

## Components

Capability is delivered by twelve named agents — Requirement Analyst, Planner, Developer, QA Agent, Documentation Agent, Reporter, and DevOps Agent at GA, joined later by Security Agent, Code Reviewer, Product Owner Agent, Scrum Master Agent, and Release Manager Agent. See [agent_catalog.md](agent_catalog.md).

## Sequence Flow

A representative request flows: prompt → intent detection → knowledge search → clarification if needed → execution plan → approval → execution against Core Platform → Run Ledger entry → notification. Full state machine in [workflow_engine.md](workflow_engine.md).

## Design Decisions

The distinction that matters: most competing tools bolt AI onto an existing view as a suggestion engine that a human still has to act on manually. Crux makes AI a governed actor that can actually execute the change itself, gated by an explicit approval step.

| Tool | Typical AI role | Crux's difference |
|---|---|---|
| Jira | Suggests fields, summarizes issues | Crux drafts and, on approval, creates the actual project/issue structure |
| Linear | AI-assisted issue writing | Crux plans and executes multi-step work (roadmap, issues, docs) as one governed action |
| Notion AI | Generates or edits page content on request | Crux acts across Redmine's structured data — projects, issues, versions — not just documents |
| GitHub Copilot | In-editor code suggestions | Crux operates at the project-management layer: planning, QA, reporting, documentation, not just code |
| Azure DevOps Boards | Boards with limited AI-assisted insights | Crux adds a conversational, approval-gated execution layer on top of the same kind of board data |

Every named agent (Principle 3) and every approval gate (Principle 2) exists to make this distinction real rather than a slogan — see [vision.md](vision.md) for the full principle set.

## Assumptions

- Readers evaluating Crux are already familiar with Redmine's project/issue model.
- "Executive/stakeholder" usage is read-mostly (reports, dashboards) rather than plan authorship.
- Feature availability at GA is limited to the seven launch agents; the remaining five ship later per [roadmap.md](roadmap.md).

## Risks

- Prospective buyers may mistake Crux for "another AI chatbot" unless the execute-under-approval distinction is concrete in the first demo.
- Comparisons to Jira/Linear/Notion AI/Copilot/Azure DevOps Boards will age as those products add agentic features; revisit each roadmap phase.

## Open Questions

- Which persona should the default demo script lead with for prospective customers?
- Does Crux need persona-specific onboarding inside the Project Workspace, or one flow for all four?

## Best Practices

- Lead a stakeholder demo with the Example Scenario below — the fastest way to show "governed actor" versus "suggestion engine."
- When positioning against a named competitor, cite the specific approval-gate behavior, not general AI capability claims.
- Point technical evaluators to [architecture.md](architecture.md) and non-technical evaluators to this document and [ui_design.md](ui_design.md).

## Example Scenarios

**Stakeholder demo** — User: "Create an HRMS." Crux asks: Which technology stack? Expected delivery timeline? Authentication method? Database? Expected modules? Deployment environment? After answers are given, Crux presents an execution plan — Create Project · Generate Wiki · Create Versions · Generate Milestones · Create 84 Issues · Assign Users · Generate Documentation — with Estimated Time and Estimated AI Cost, and Approve / Reject / Modify actions. The demo's key beat is that nothing above the line executes until the stakeholder clicks Approve.

## Future Enhancements

Later roadmap phases (see [roadmap.md](roadmap.md)) add agent collaboration, additional providers, and deeper integrations; longer-term direction, including the Future Marketplace, is covered in [future_scope.md](future_scope.md).
