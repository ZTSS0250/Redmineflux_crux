# Crux — Integrations

**Version**: 1.0 · **Status**: Draft

## Purpose

The Integration Engine connects Crux to the external systems teams already use — source control, chat, CI/CD, trackers, and generic webhooks/MCP servers — so outside events can enter a conversation or plan, and Crux results can flow back out, without opening a side door around governance.

## Scope

Covers the Integration Engine and the 12 canonical integrations: GitHub, GitLab, Bitbucket, Slack, Microsoft Teams, Jenkins, Azure DevOps, Webhooks, MCP, Email, Calendar, and Future Marketplace — their auth models and the events each emits or consumes. Does not cover plan generation ([workflow_engine.md](workflow_engine.md)), approval mechanics ([approval_engine.md](approval_engine.md)), or the crux_integrations schema ([database_design.md](database_design.md)).

## Responsibilities

- Store per-project connector configuration (provider, config, enabled) as a crux_integrations row.
- Authenticate to each provider via the model appropriate to it — OAuth app, API token, or webhook secret.
- Translate inbound provider events into conversation or plan-step triggers for the Workflow Engine.
- Dispatch outbound actions (comments, status updates, file writes) only after they clear the Approval Engine.
- Let a project enable or disable each integration independently, gated by crux:manage_integrations.
- Log every integration-triggered run in the Run Ledger, identical in shape to a chat-triggered run.

## User Flow

1. A user holding crux:manage_integrations opens Project → Crux → Settings → Integrations, selects a provider, and completes its auth model.
2. They choose which events the connector should listen for or emit.
3. A qualifying external event (e.g., a GitHub PR merged) is picked up by the Integration Engine, handed to Intent Detection like a chat message, and — if it implies a Redmine write — routed through the plan → approval → execution path in [workflow_engine.md](workflow_engine.md).

## UI Description

Project-level configuration lives under Project Workspace → Crux → Settings → Integrations, listing each connector with status and last-event time. Global provider registration (OAuth app credentials, default endpoints) lives under Administration → Crux → Integrations, scoped to crux:administer. Both surfaces are detailed in [ui_design.md](ui_design.md).

## Architecture

The Integration Engine sits alongside the Workflow Engine, Notification Engine, and Run Ledger among the 19 modules in [architecture.md](architecture.md). It is the only module holding outbound credentials to third-party systems; it never writes to Redmine directly — it only raises an intent or delivers an already-approved result.

```
External System <--webhook/API--> Integration Engine --> Intent Detection --> Workflow Engine --> Approval Engine --> Redmine
                                                                                          |
                                                                                     Run Ledger
```

## Components

Each integration follows the same shape — Purpose, Auth model, Events — plus the shared governance note that applies to all twelve: **an integration can trigger a plan step, but write-back to Redmine still goes through the normal Workflow Engine approval gate; an external tool never bypasses governance just because it arrived via webhook or MCP instead of the chat UI.**

#### GitHub
Link issues/PRs to Redmine work. Auth: GitHub App (OAuth) or scoped PAT. In: push, PR opened/merged, issue_comment, release. Out: PR/issue comments, status checks — approval-gated.

#### GitLab
Mirror MR and pipeline activity. Auth: OAuth app or project access token. In: merge_request, pipeline, note events. Out: MR comments, label updates — approval-gated.

#### Bitbucket
Source-control parity for Bitbucket teams. Auth: OAuth consumer or app password. In: repo:push, pullrequest events. Out: PR comments — approval-gated.

#### Slack
Converse with Crux and receive notifications in-channel. Auth: OAuth app per workspace. In: slash commands, mentions. Out: run status, approval requests — approval-gated for anything that writes to Redmine.

#### Microsoft Teams
Teams-equivalent of Slack. Auth: OAuth app (Azure AD) per tenant. In: bot mentions, adaptive-card actions. Out: notifications, approval prompts — approval-gated.

#### Jenkins
Ties build/deploy status to plan steps (notably DevOps Agent). Auth: API token plus webhook secret. In: build/deploy results. Out: triggering a Jenkins job as an approved step — gated, especially for crux:approve_destructive deploy steps.

#### Azure DevOps
Parity for Azure DevOps boards/pipelines. Auth: OAuth app or PAT. In: work item updates, pipeline runs. Out: work item sync, pipeline triggers — approval-gated.

#### Webhooks
Generic channel for systems without a dedicated connector. Auth: shared, HMAC-signed webhook secret. In: any configured payload mapped to an intent. Out: outbound HTTP calls as an approved step.

#### MCP
Two independent directions — see dedicated subsection below.

#### Email
Raise or update requests via email. Auth: mailbox OAuth (hosted) or SMTP/IMAP credentials (on-prem). In: inbound mail parsed into a conversation. Out: notification/digest emails — approval-gated where it becomes a Redmine change.

#### Calendar
Reflect milestones, deadlines, and runs on a team calendar. Auth: OAuth (Google/Microsoft). In: none by default. Out: event creation/update — approval-gated where it implies a date change in Redmine.

#### Future Marketplace
Not a connector itself — the forward path for third-party connectors. See [future_scope.md](future_scope.md).

### MCP — inbound and outbound

- **Inbound** — Crux exposes Redmine operations as MCP tools so an external agent (e.g., Claude Code, Cursor) can pull its assigned tasks and write results back. Auth: an MCP token scoped to the acting user's own Redmine permissions — the external agent never sees or does more than that user could in the UI.
- **Outbound** — Crux's own agents call configured MCP servers as tool calls during a run (e.g., a Developer Agent invoking a code-search server). Auth: per-server credentials set by crux:manage_integrations. Every outbound call is logged in the Run Ledger like any other agent action.

Both directions terminate at the same approval gate before anything is written to Redmine.

## Sequence Flow

```
Inbound event (webhook/API/MCP) → Integration Engine → Intent Detection
   → Execution Plan (if a Redmine write is implied) → Approval Engine
   → Workflow Engine executes → Run Ledger entry → Notification Engine
   → Outbound event (comment/status/webhook) back to the external system
```

## Design Decisions

- **One governance gate regardless of entry point** — chat, webhook, and MCP all converge on the same Approval Engine path; there is no "trusted integration" shortcut.
- **Per-project connection** — each connector is a crux_integrations row scoped to project_id, matching Core Principle 5; see [database_design.md](database_design.md).
- **MCP is two capabilities, not one** — inbound and outbound carry different trust boundaries and are configured, permissioned, and audited independently.
- **Credentials referenced, never embedded** — plan steps and prompts reference a connector by ID; secrets never appear in prompt text or the Run Ledger (see [security.md](security.md)).

## Assumptions

- Each provider's app registration (GitHub App, Slack app, Azure AD app) is created once per deployment, not per project.
- External systems stay the source of truth for their own objects; Crux keeps a reference, except where the Knowledge Engine indexes content.
- Provider-side rate limits apply in addition to Crux-side limits ([security.md](security.md)).

## Risks

- **Untrusted inbound payloads** — webhook/email bodies can carry adversarial content; Intent Detection must treat them as untrusted input, not pre-authorized instruction.
- **Silent token expiry** — an expired token or revoked secret quietly stops a connector; it needs visible health status, not just failed-run logs.
- **Event storms** — a noisy webhook can flood Intent Detection without its own throttling ahead of the shared rate limiter.

## Open Questions

- Which integrations should support two-way sync versus one-way-in/one-way-out-via-approval?
- How are conflicting updates resolved when the external system and Redmine change the same object between syncs?
- What vetting will Future Marketplace connectors undergo before holding outbound credentials?

## Best Practices

- Scope tokens and OAuth apps to the minimum permission needed (e.g., a GitHub App restricted to specific repos).
- Rotate webhook secrets and tokens on a schedule, not only after a suspected leak.
- Disable connectors a project no longer uses rather than leaving them dormant.

## Example Scenarios

**GitHub → QA Agent**
> A GitHub PR is merged. The webhook reaches the Integration Engine, which raises an intent for the QA Agent to draft a regression test plan. The step is approved by a project lead before any Redmine issue changes.

**Slack slash command**
> A user types `/crux status` in Slack. The Integration Engine treats it like a chat message, runs Intent Detection, and replies in-thread with the Reporter Agent's output — no Redmine write, so no approval needed.

**MCP inbound from Claude Code**
> Claude Code, connected via inbound MCP, pulls its assigned issue and later writes back a completed patch reference — subject to the same crux:approve gate as a human-proposed change in chat.

## Future Enhancements

Deeper native integrations (richer Azure DevOps board sync, calendar two-way sync) and the broader third-party connector ecosystem are tracked in [future_scope.md](future_scope.md) under the Future Marketplace, governed by the same principles as the 12 canonical integrations above.
