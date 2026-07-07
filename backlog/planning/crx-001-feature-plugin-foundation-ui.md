## Metadata
- **Task ID**: crx-001-feature-plugin-foundation-ui
- **Title**: Crux Plugin Foundation & Initial UI (Phase 1)
- **Type**: feature
- **Status**: planning
- **Complexity**: (filled by Claude at spec stage)
- **Created**: 2026-07-07
- **Author**: Sheetal Sharma
- **Quality Gates**: Gate 1: pending | Gate 2: pending | Gate 3: pending

---

## Planning
*(Developer fills this section)*

**Description**:

Implement the initial user interface foundation for the Crux plugin — the plugin structure, navigation, project integration, permissions, and placeholder pages that every future phase builds on. Think of this as the "skeleton" of the Crux platform. This phase explicitly does **not** implement any AI functionality (no providers, LLM integration, chat execution, agent execution, billing, workflow engine, knowledge engine, MCP, or external integrations) — every page is a placeholder ("Coming in Future Phase" / "Coming Soon").

**Goal**:

After installing the plugin: it registers successfully as "Crux" v1.0.0; a global Crux menu and Administration → Plugins → Crux page appear; a per-project "Crux AI" module can be enabled, which reveals a project-level Crux menu and workspace; all pages render placeholder content with consistent Redmine-native styling; no AI execution occurs anywhere.

**Objectives**:
- [ ] Register the plugin (name, version 1.0.0, description) — already scaffolded in `init.rb`, confirm it matches spec.
- [ ] Add a global top-level "Crux" menu item alongside Home/My Page/Projects/Administration/Help, opening a placeholder Global Crux Dashboard (dummy stat cards: Total Projects, Projects with Crux Enabled, Total AI Runs, Pending Approvals, Active Agents, Token Usage, Plugin Version).
- [ ] Add an Administration → Plugins → Crux page with placeholder tabs: General, Dashboard, Agents, Providers, Models, Billing, Audit Logs, Integrations, Settings, License.
- [ ] Add a project module ("Crux AI") toggle under Project → Settings → Modules; when enabled, add a project-level "Crux" menu item alongside Overview/Activity/Roadmap/Issues/Wiki/Repository.
- [ ] Build the project Crux workspace with placeholder tabs: Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings — each showing title, short description, and "Coming in Future Phase."
- [ ] Define new Redmine permissions integrated with Roles: View Crux, Use Crux Chat, Manage Agents, Approve AI Actions, View Audit Logs, Manage Integrations, Manage Billing, Manage Settings.
- [ ] Add routes for all placeholder pages (global and project-scoped).
- [ ] Add controllers (render-only, no business logic) for each surface.
- [ ] Add minimal DB migrations only if required for plugin registration/future expansion — no AI data models yet.

**Deliverables**:
- [ ] Plugin registration (`init.rb`) matching the spec (name, version, description)
- [ ] Global Crux menu + Global Crux Dashboard (placeholder cards)
- [ ] Administration → Crux page with 10 placeholder tabs
- [ ] Project module gate ("Crux AI") wired to Settings → Modules
- [ ] Project-level Crux menu item + workspace with 9 placeholder tabs
- [ ] Sidebar navigation inside the project Crux workspace
- [ ] New permissions wired into Redmine's Roles & Permissions screen
- [ ] Routes for every placeholder page (global + `/project/:id/crux/...`)
- [ ] Controllers: `CruxController`, `DashboardController`, `AgentsController`, `ProvidersController`, `BillingController`, `SettingsController`, `ProjectCruxController`, `ChatController`, `AnalyticsController` (render-only)
- [ ] Views: consistent placeholder layout (title, breadcrumb, description, placeholder card, "Coming Soon") across all pages
- [ ] Clean, conventional Redmine plugin folder structure

**Out of Scope** (explicitly deferred to later phases):
AI providers, LLM integration, chat execution, prompt processing, agent execution, billing logic, token tracking, workflow engine, knowledge engine, MCP, GitHub integration, Slack integration. This phase ships UI/navigation/permissions scaffolding only.

**Reference layouts** (as provided by developer — informs the Specification/view work, not restated elsewhere):

*Global Crux Dashboard*: cards for Projects, Projects Enabled, AI Runs, Pending Approvals, Agents, Models, Token Usage, Version — all dummy values.

*Project Crux Dashboard*: cards for AI Runs, Outcomes, Agents, Pending, Knowledge, Models, Recent Activity — all dummy values.

*UI requirements*: standard Redmine UI components and styling, responsive layout, professional appearance, avoid custom JavaScript unless necessary.

---

## Specification
*(Claude fills this section after reading the codebase)*

**Complexity**: —

**Reason**: Not yet assessed — pending "move to specification."

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| — | — | To be filled when this task moves to specification |

### Implementation Notes
—

---

## Test Cases
*(Claude writes these; developer executes and marks pass/fail)*

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|

### QA Test Plan
*(Copied verbatim into the PR description)*

**Scope**: —

**Pre-conditions**:
- —

**QA Steps**:
1. —

**Expected Outcomes**:
- —

**Out of Scope**:
- —

---

## Quality Gates
*(Claude fills this section during the three-gate review)*

### Gate 1 — Senior Developer Review
Date: — | Status: pending

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|

Verdict: pending

### Gate 2 — Security & Performance Review
Date: — | Status: pending

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|

Verdict: pending

### Gate 3 — Pre-Development Sweep
Date: — | Status: pending

**Part A — Gate 1 & 2 resolution confirmed**: pending

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|

Verdict: pending

---

## Done
*(Claude fills this section when tests pass and PR is merged)*

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
