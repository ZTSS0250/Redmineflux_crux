# UI Design

Reference for the visual and interaction design of every Crux surface — the Project Workspace, the Administration section, and the shared components (chat, approval, pending actions, analytics) that appear across both. This document defines layout and interaction patterns only; visual tokens such as color palette, type scale, and spacing belong to the product's design system and are out of scope here.

## Purpose

To give everyone building or documenting a Crux surface — engineers, other documentation authors, QA — one consistent visual vocabulary: tab order, wireframe layout, component naming, empty-state behavior, and accessibility requirements. Anyone rendering a Crux screen should be able to build it from this document without guessing at layout or interaction details.

## Scope

Covered: the navigation model from module activation to tab content; wireframes for the Project Workspace tab bar, the Chat tab, the Approval card, the Pending Actions queue, the Administration Dashboard, and a Project/Org Analytics dashboard; empty states; accessibility requirements.

Not covered: color palette, typography, and spacing tokens (design system); the logic that produces plan data (see [workflow_engine.md](workflow_engine.md)); intent detection and clarification logic (see [chat_engine.md](chat_engine.md)); the full module map (see [architecture.md](architecture.md)); table and field definitions (see [database_design.md](database_design.md)).

## Responsibilities

This document owns tab order and grouping, wireframe-level layout for every screen listed in Scope, the naming for reusable UI components, and accessibility requirements for those components.

It does not own what data appears in a plan step, who is allowed to approve it, how an agent's output is generated, or backend performance characteristics — those belong to the Workflow Engine, Agent Engine, and Approval Engine (the gate inside Workflow Engine); see [architecture.md](architecture.md) and [workflow_engine.md](workflow_engine.md).

## User Flow

Navigation to any Crux surface starts at the module gate:

```
Project Settings → Modules → ☐ Crux AI
```

If the module is unchecked, no Crux menu item, chatbot, or AI surface appears anywhere in the project — the routing layer removes it entirely rather than hiding it visually. Once checked, "Crux" appears as a project menu item alongside Overview, Activity, Issues, Wiki, and Repository.

Inside a project the flow is: project menu → **Crux** → the nine-tab workspace bar. In Administration the flow is: **Administration → Plugins → Crux**, which opens the sixteen-tab admin area (Dashboard, Agents, Providers, Models, Billing, Audit Logs, Usage, Knowledge, Projects, Permissions, Policies, Integrations, Settings, Health Monitoring, License, Future Features).

Within a conversation the visible flow is: composer → typing indicator → clarification chips (if needed) → plan preview → Approval card → Approve / Reject / Modify → result appended to the thread. Deferred approvals reappear in Pending Actions until acted on.

## UI Description

### Project Workspace tab bar

The nine tabs always render in this fixed order:

```
┌──────────┬──────┬────────┬──────┬───────────┬─────────────┬─────────────────────┬───────────┬──────────┐
│ Overview │ Chat │ Agents │ Runs │ Knowledge │ Automations │ Pending Actions (3) │ Analytics │ Settings │
└──────────┴──────┴────────┴──────┴───────────┴─────────────┴─────────────────────┴───────────┴──────────┘
```

The active tab is underlined; Pending Actions carries a numeric badge showing the count of steps at `awaiting_approval`. A tab is omitted entirely — not just disabled — if the current user lacks the permission behind it (e.g. Analytics is absent without `crux:view_analytics`).

### Chat tab

```
┌───────────────────────────────────────────────────────────────────────┐
│  Crux · Chat                                            [+ New chat]  │
├───────────────────────────────────────────────────────────────────────┤
│  You                                                        10:02 AM  │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ Create a CRM System with Customer, Leads, and Invoice modules.  │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  Requirement Analyst                                        10:01 AM │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │ A few questions before I proceed:                                │ │
│  │                                                                   │ │
│  │  ( Which technology stack? )   ( Expected delivery timeline? )   │ │
│  │  ( Authentication method? )    ( Database? )                     │ │
│  │  ( Expected modules? )         ( Deployment environment? )       │ │
│  └─────────────────────────────────────────────────────────────────┘ │
├───────────────────────────────────────────────────────────────────────┤
│  [ Type a message…                                        ]  [ Send ]│
└───────────────────────────────────────────────────────────────────────┘
```

Clarification chips are clickable shortcuts, never mandatory — a user may answer all of them in one free-text reply instead.

### Approval card

```
┌───────────────────────────────────────────────────────────────────────┐
│  Execution Plan — CRM System                     Status: ⏳ Awaiting  │
│                                                          Approval      │
├───────────────────────────────────────────────────────────────────────┤
│  # │ Action                    │ Type    │ Target                    │
│  ──┼───────────────────────────┼─────────┼─────────────────────────  │
│  1 │ Create Project            │ create  │ Project                   │
│  2 │ Generate Wiki             │ create  │ Wiki page                 │
│  3 │ Create Versions           │ create  │ Version (×3)              │
│  4 │ Generate Milestones       │ create  │ Milestone (×3)            │
│  5 │ Create 84 Issues          │ create  │ Issue (×84)               │
│  6 │ Assign Users              │ update  │ Issue assignee            │
│  7 │ Generate Documentation    │ create  │ Wiki / Document           │
├───────────────────────────────────────────────────────────────────────┤
│  Estimated Time: ~6 min          Estimated AI Cost: $0.42             │
├───────────────────────────────────────────────────────────────────────┤
│           [ Approve ]        [ Reject ]        [ Modify ]             │
└───────────────────────────────────────────────────────────────────────┘
```

Estimated time and cost are always shown before Approve is reachable — a plan is never approved blind. See [workflow_engine.md](workflow_engine.md) for what each button transitions.

### Pending Actions queue

```
┌───────────────────────────────────────────────────────────────────────┐
│  Pending Actions                                    3 awaiting review │
├───────────────────────────────────────────────────────────────────────┤
│  ⏳ Awaiting Approval   Create 84 Issues            Planner   2m ago  │
│                                    [ Approve ] [ Reject ] [ Modify ]  │
│  ───────────────────────────────────────────────────────────────────  │
│  ⛔ Destructive · Awaiting Approval   Delete Milestone "v0.9"  DevOps │
│      Approve requires the "approve destructive actions" permission    │
│                                    [ Approve ] [ Reject ] [ Modify ]  │
│  ───────────────────────────────────────────────────────────────────  │
│  ⏳ Awaiting Approval   Generate Test Suite         QA Agent  14m ago │
│                                    [ Approve ] [ Reject ] [ Modify ]  │
└───────────────────────────────────────────────────────────────────────┘
```

Destructive steps (Delete Project, Delete Milestone, Deploy, and similar) carry a distinct icon and label because they are gated by `crux:approve_destructive` rather than plain `crux:approve`. A user holding only `crux:approve` sees the row but its Approve control is disabled with an inline explanation — never silently hidden.

### Administration Dashboard

```
┌───────────────────────────────────────────────────────────────────────┐
│  Administration ▸ Crux ▸ Dashboard                                    │
├───────────┬────────┬───────────┬────────┬─────────┬───────┬──────────┤
│ Dashboard │ Agents │ Providers │ Models │ Billing │ Audit │ … (16)   │
├───────────┴────────┴───────────┴────────┴─────────┴───────┴──────────┤
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐          │
│  │ Projects   │ │ AI Runs    │ │ Outcomes   │ │ Est. Spend │          │
│  │    14      │ │   1,842    │ │    241     │ │   $482     │          │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘          │
│                                                                       │
│  Top Projects by AI Activity            Top Agents by Usage          │
│  ──────────────────────────             ────────────────────         │
│  CRM Platform          34 runs          Planner            38%       │
│  Hospital Mgmt System  28 runs          QA Agent           24%       │
│  Internal Ops          24 runs          Reporter           19%       │
└───────────────────────────────────────────────────────────────────────┘
```

### Project / Org Analytics dashboard

```
┌───────────────────────────────────────────────────────────────────────┐
│  Analytics                                       Range: Last 30 days ▾│
├───────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐          │
│  │ AI Runs    │ │ Success %  │ │ Token Usage│ │ Pending    │          │
│  │   128      │ │    91%     │ │   842K     │ │    2       │          │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘          │
│                                                                       │
│  Runs over time                                                      │
│  ▁▂▃▅▆▇▆▅▃▂▁▂▃▅▇█▇▅▃▂▁▂▃▅▆▇                                          │
│                                                                       │
│  Most Active Agent: Planner                                          │
│  Outcome Success Rate by Agent                                       │
│  Planner            ██████████████████░░  91%                       │
│  QA Agent           ████████████████░░░░  82%                       │
│  Reporter           ███████████████████░  96%                       │
└───────────────────────────────────────────────────────────────────────┘
```

The same layout serves project-level Analytics (scoped to one project) and the organization-level rollup in Administration → Usage; only the scope selector and the presence of a project column differ.

### Empty states

```
┌───────────────────────────────┐  ┌───────────────────────────────┐  ┌───────────────────────────────┐
│ Agents                        │  │ Runs                          │  │ Pending Actions               │
│                                │  │                                │  │                                │
│  No agents enabled yet.       │  │  No runs yet.                 │  │  Nothing waiting on you.      │
│  Turn one on to start         │  │  Start a conversation in Chat │  │  Approved and rejected items  │
│  automating project work.     │  │  to see agent activity here.  │  │  move to Runs.                │
│                                │  │                                │  │                                │
│     [ Enable an agent ]       │  │       [ Go to Chat ]          │  │                                │
└───────────────────────────────┘  └───────────────────────────────┘  └───────────────────────────────┘
```

Every empty state names the cause plainly and, where an action exists, offers exactly one primary call to action rather than a menu of options.

### Accessibility

Approve, Reject, and Modify are native `<button>` elements reachable by Tab and activatable with Enter or Space — never a clickable `<div>`. Status pills (Awaiting Approval, Executing, Completed, Rejected, Failed) always pair an icon and a text label with their color and expose that text to assistive technology, so color-blind and screen-reader users receive the same information as sighted users. Destructive rows are announced as "destructive, requires additional permission" rather than relying on icon color alone.

## Architecture

The UI is a set of server-rendered Redmine views progressively enhanced with client-side scripting, not a separate single-page application. Each tab maps to a module described in [architecture.md](architecture.md): Chat renders the Chat Engine's turn history; Agents and Automations render Agent Engine configuration; Runs renders the Run Ledger; Knowledge renders the Knowledge Engine's source list; Pending Actions is a filtered view over `crux_plan_steps` where `status = awaiting_approval` (see [database_design.md](database_design.md)); Analytics renders the Analytics Engine; Settings renders per-project entries in `crux_settings`. In-flight runs update the UI through polling rather than a persistent connection in the initial release (see Assumptions).

## Components

- **Tab bar** — fixed-order, permission-filtered links with an active-state underline and optional numeric badge.
- **Message bubble** — a single chat turn, labeled with sender (user or named agent) and timestamp.
- **Composer** — the message input and Send control; disables and shows a typing indicator while a run is in progress.
- **Clarification chip** — a clickable shortcut for one clarification question; always paired with a free-text fallback.
- **Plan table** — the step-by-step breakdown inside the Approval card; each row shows action, type, and target.
- **Status pill** — the icon + label + color combination used consistently for plan step and run status everywhere.
- **Stat tile** — a single labeled metric used on Overview, Dashboard, and Analytics.
- **Empty-state panel** — icon, one line of explanation, at most one primary action.
- **Approval action bar** — the Approve / Reject / Modify button group, always shown together.

## Sequence Flow

```
Composer (enabled)
      │ user sends message
      ▼
Composer (disabled) + typing indicator — "Planner is drafting…"
      │ agent run completes (async, background — see chat_engine.md)
      ▼
Message thread updates + Approval card renders (if a plan was produced)
      │ user clicks Approve / Reject / Modify
      ▼
Approval action bar disables; status pill updates in place
      │ execution proceeds, or plan reopens (see workflow_engine.md)
      ▼
Result appended to thread; entry now visible in Runs and Audit Logs
```

## Design Decisions

Status is always communicated through an icon-plus-text pill, never color alone. The Approval card always discloses estimated time and cost before Approve becomes usable. Destructive plan steps are visually distinguished and their Approve control is disabled — with an explanation — for users holding `crux:approve` but not `crux:approve_destructive`, rather than being hidden. Tabs are removed entirely, not grayed out, when the viewing user lacks the underlying permission. Every empty state offers exactly one primary next action.

## Assumptions

The initial release updates Runs and Pending Actions through periodic polling rather than a persistent WebSocket connection; real-time push is treated as a future enhancement, not a baseline requirement. The workspace targets typical laptop and desktop widths; a dedicated mobile layout is out of scope for the initial release. Existing Redmine chrome (top navigation, project menu) is unchanged — Crux surfaces live entirely within the content area Redmine already provides for a plugin page.

## Risks

Nine workspace tabs plus sixteen admin tabs is substantial surface area for a first-time user; without a strong Overview and clear empty states, discoverability suffers. Approval fatigue — clicking Approve without reading the plan table — is a real risk for frequent, low-stakes plans, and the plan table's clarity is the main available mitigation rather than a technical control. Polling-based updates may feel laggy for long-running executions if the interval is too coarse.

## Open Questions

Should the Pending Actions badge count destructive and non-destructive items separately, so an approver with only `crux:approve` isn't shown a count they can only partly act on? Should Chat and Pending Actions merge into one surface for projects with very low plan volume? What polling interval should Runs and Pending Actions use before this needs to become push-based?

## Best Practices

Prefer native HTML form controls over custom widgets so keyboard and screen-reader behavior come for free. Maintain one shared status-pill component rather than re-implementing status styling per tab. Use an ARIA live region for the typing indicator and for messages appended asynchronously, so screen-reader users are notified without re-polling the page. Keep clarification chips optional, never the only way to answer.

## Example Scenarios

A project owner enables the Crux AI module for the first time: the project menu gains a Crux item, and Overview, Agents, Runs, and Pending Actions all render their empty states until an agent is enabled and a conversation is started. A user runs the CRM System example end to end: Chat tab clarification chips, an Approval card matching the canonical plan, then a completed run visible in Runs and Analytics. A user without `crux:approve_destructive` opens Pending Actions and sees a Delete Milestone row with its Approve control disabled and an inline explanation, while Reject remains available.

## Future Enhancements

A responsive/mobile layout for the Project Workspace. Push-based (WebSocket) updates for Runs and Pending Actions in place of polling. Customizable Analytics dashboard widgets. A dedicated marketplace browsing UI once the Future Marketplace module ships (see [architecture.md](architecture.md)).
