## Metadata
- **Task ID**: crx-001-feature-plugin-foundation-ui
- **Title**: Crux Plugin Foundation & Initial UI (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-07
- **Author**: Sheetal Sharma
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Developer-filled — unchanged from planning stage)*

**Description**:

Implement the initial user interface foundation for the Crux plugin — the plugin structure, navigation, project integration, permissions, and placeholder pages that every future phase builds on. Think of this as the "skeleton" of the Crux platform. This phase explicitly does **not** implement any AI functionality (no providers, LLM integration, chat execution, agent execution, billing, workflow engine, knowledge engine, MCP, or external integrations) — every page is a placeholder ("Coming in Future Phase" / "Coming Soon").

**Goal**:

After installing the plugin: it registers successfully as "Crux" v1.0.0; a global Crux menu and Administration → Plugins → Crux page appear; a per-project "Crux AI" module can be enabled, which reveals a project-level Crux menu and workspace; all pages render placeholder content with consistent Redmine-native styling; no AI execution occurs anywhere.

**Objectives**:
- [x] Register the plugin (name, version 1.0.0, description) — done in `init.rb`.
- [x] Add a global top-level "Crux" menu item opening a placeholder Global Crux Dashboard.
- [ ] Add an Administration → Plugins → Crux page with placeholder tabs: General, Dashboard, Agents, Providers, Models, Billing, Audit Logs, Integrations, Settings, License — 6 of 10 built (Dashboard, Agents, Providers, Billing, Audit Logs, Settings); General/Models/Integrations/License remain.
- [x] Add a project module ("Crux AI") toggle under Project → Settings → Modules; project-level "Crux" menu item.
- [ ] Build the project Crux workspace with placeholder tabs: Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings — 4 of 9 built (Overview, Chat, Agents, Settings); Runs/Knowledge/Automations/Pending Actions/Analytics remain.
- [ ] Define new Redmine permissions integrated with Roles — only 1 of the intended set (`view_crux_ai`) exists; remapped onto the canonical 9-permission set from `security.md` in this spec (see Implementation Notes).
- [ ] Add routes for all placeholder pages (global and project-scoped) — partial; remaining tabs need routes.
- [x] Add controllers (render-only, no business logic) for each surface built so far.
- [x] No DB migrations — confirmed none needed; none added.

**Deliverables**: (tracked against actual code in Code Changes below — this list is unchanged from the original ask)
- [ ] Plugin registration (`init.rb`) matching the spec (name, version, description)
- [ ] Global Crux menu + Global Crux Dashboard (placeholder cards)
- [ ] Administration → Crux page with 10 placeholder tabs
- [ ] Project module gate ("Crux AI") wired to Settings → Modules
- [ ] Project-level Crux menu item + workspace with 9 placeholder tabs
- [ ] Sidebar navigation inside the project Crux workspace
- [ ] New permissions wired into Redmine's Roles & Permissions screen
- [ ] Routes for every placeholder page (global + `/project/:id/crux/...`)
- [ ] Controllers (render-only)
- [ ] Views: consistent placeholder layout across all pages
- [ ] Clean, conventional Redmine plugin folder structure

**Out of Scope** (explicitly deferred to later phases):
AI providers, LLM integration, chat execution, prompt processing, agent execution, billing logic, token tracking, workflow engine, knowledge engine, MCP, GitHub integration, Slack integration. This phase ships UI/navigation/permissions scaffolding only.

**Reference layouts** (as provided by developer): *Global Crux Dashboard* — cards for Projects, Projects Enabled, AI Runs, Pending Approvals, Agents, Models, Token Usage, Version, all dummy values. *Project Crux Dashboard* — cards for AI Runs, Outcomes, Agents, Pending, Knowledge, Models, Recent Activity, all dummy values. *UI requirements*: standard Redmine UI components and styling, responsive layout, professional appearance, avoid custom JavaScript unless necessary.

---

## Specification
*(Claude-filled — codebase read directly; a partial implementation already exists)*

**Complexity**: HIGH

**Reason**: Touches every layer of the plugin (registration, permissions, routing, ~20 controllers, ~20 views, i18n, stylesheets, two navigation surfaces) and establishes the permission model, module gate, and tab structure every later phase (crx-002 through crx-006) depends on. No DB migrations are required, but the cross-cutting surface area (Administration + Project Workspace + Core Platform's Roles & Permissions screen) places it at HIGH rather than MEDIUM, per the global complexity rubric (6+ files, architecture impact).

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `init.rb` | modify | Replace the single `:view_crux_ai` permission with the canonical set from `security.md`/`glossary.md`: `use_crux`, `crux:approve`, `crux:approve_destructive`, `crux:manage_agents`, `crux:manage_knowledge`, `crux:manage_integrations`, `crux:view_billing`, `crux:view_analytics` inside `project_module :crux_ai`, plus global `crux:administer` guarding every Administration → Crux controller. Map each controller/action to the permission that actually gates it (see Implementation Notes). |
| `app/controllers/global_crux_controller.rb` | modify | Add `before_action :require_admin` — currently the only global Crux controller without it; its five siblings (Agents/Providers/Billing/Settings/Audit) already have it. |
| `lib/redmineflux_crux/hooks/crux_admin_hooks.rb` | modify | Scope the injected stylesheet to Crux admin pages only (check for a `global_crux*` controller prefix) instead of injecting on every page in the Redmine instance; update the reference once the asset below is renamed. |
| `assets/stylesheets/administraction.css` | rename → `administration.css` | Fixes the existing filename typo, referenced from the hook above. |
| `config/routes.rb` | modify | Add routes for the 4 missing Administration tabs (General, Models, Integrations, License) and the 5 missing Project Workspace tabs (Runs, Knowledge, Automations, Pending Actions, Analytics). Remove the non-canonical `projects/:id/crux/billing` route (see Implementation Notes). |
| `config/locales/en.yml` | modify | Add `label_general`, `label_models`, `label_integrations`, `label_license`, `label_runs`, `label_knowledge`, `label_automations`, `label_pending_actions`, `label_analytics`. |
| `app/controllers/concerns/crux_project_scoped.rb` | create | Shared `before_action :find_project`, currently duplicated verbatim across `ProjectCruxController`, `ProjectCruxChatController`, `ProjectCruxAgentsController`, `ProjectCruxBillingController`, `ProjectCruxSettingsController` — included by all project-scoped controllers, old and new. |
| `app/controllers/global_crux_general_controller.rb` + `app/views/global_crux_general/index.html.erb` | create | Administration → Crux → General tab: plugin name, version, description, author, sourced from `init.rb`'s registered metadata — `before_action :require_admin`. |
| `app/controllers/global_crux_models_controller.rb` + view | create | Administration → Crux → Models tab: placeholder rows matching the Model Layer's per-agent model/fallback/temperature concept — `before_action :require_admin`. |
| `app/controllers/global_crux_integrations_controller.rb` + view | create | Administration → Crux → Integrations tab: placeholder list of the 12 canonical integrations (`integrations.md`), all shown "not configured" — `before_action :require_admin`. |
| `app/controllers/global_crux_license_controller.rb` + view | create | Administration → Crux → License tab: placeholder plan tier / seat count — `before_action :require_admin`. |
| `app/controllers/project_crux_runs_controller.rb` + view | create | Project Workspace → Runs tab placeholder — gated `use_crux`. |
| `app/controllers/project_crux_knowledge_controller.rb` + view | create | Project Workspace → Knowledge tab placeholder listing the 11 canonical sources, all "disabled" — gated `crux:manage_knowledge`. |
| `app/controllers/project_crux_automations_controller.rb` + view | create | Project Workspace → Automations tab placeholder — gated `crux:manage_integrations`. |
| `app/controllers/project_crux_pending_actions_controller.rb` + view | create | Project Workspace → Pending Actions tab placeholder (static "Nothing waiting on you" empty state per `ui_design.md`) — gated `crux:approve`. |
| `app/controllers/project_crux_analytics_controller.rb` + view | create | Project Workspace → Analytics tab placeholder — gated `crux:view_analytics`. |
| `app/controllers/project_crux_settings_controller.rb` + view | modify | Fold the existing project-level Billing placeholder content in as a "Usage" sub-section (per `billing.md`'s own User Flow: "Project → Crux → Settings → Usage"), rather than a stand-alone tab. |
| `app/controllers/project_crux_billing_controller.rb`, `app/views/project_crux_billing/index.html.erb` | delete | Not one of the canonical 9 Project Workspace tabs (`ui_design.md`); content absorbed into Settings → Usage above. |
| `app/views/crux_global_sidebar/_global_crux_sidebar.html.erb` | modify | Add icons/links for General, Models, Integrations, License. |
| `app/views/crux_project_sidebar/_project_crux_sidebar.html.erb` | modify | Add icons/links for Runs, Knowledge, Automations, Pending Actions, Analytics; remove the Billing icon/link. |

### Implementation Notes

- **Permission remapping is the load-bearing change in this spec.** Planning's ad hoc list ("View Crux, Use Crux Chat, Manage Agents, Approve AI Actions, View Audit Logs, Manage Integrations, Manage Billing, Manage Settings") predates `security.md` and doesn't reuse its canonical 9 permissions. This spec reconciles the two: `use_crux` covers both "view the tab" and "use chat" (there is no separate canonical "use chat" permission); `crux:administer` (global) covers Audit Logs, since Audit Logs has no project-level counterpart in `ui_design.md`; `crux:approve`/`crux:approve_destructive` are wired in now, gating the Pending Actions placeholder, even though no plan step exists yet to approve — so the permission scaffold is ready the moment crx-003 lands real plan steps.
- **The project-level Billing tab is a deviation, not a feature.** `ui_design.md`'s nine Project Workspace tabs do not include Billing; `billing.md` explicitly places project usage/cost under Settings → Usage instead. Carrying a stand-alone Billing tab forward would fork the shipped UI from its own canonical spec.
- All new/modified controllers follow the existing pattern exactly: `find_project` (via the new concern) + `authorize` for project-scoped ones, `require_admin` for global ones, dummy instance variables, no database reads, no business logic — consistent with this task's Out of Scope.
- No new database migrations are introduced by this spec, consistent with Planning's "no AI data models yet."
- This task's deliverables are the dependency baseline for crx-002 through crx-006: those tasks fill the placeholder tabs shipped here (Chat → crx-002, Pending Actions/approval UI → crx-003, Agents/Runs → crx-004, Knowledge → crx-005, Providers/Models → crx-006) rather than re-defining navigation or permissions.

---

## Test Cases
*(Claude-written; developer executes and marks pass/fail)*

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Global Crux permission gate | Non-admin user requests `GET /crux` directly by URL | 403 / access denied, same as any other admin-only Redmine page | pending |
| 2 | Project Crux permission gate | User without `use_crux` on the project requests `GET /projects/:id/crux` | 403 / access denied | pending |
| 3 | Pending Actions permission gate | User with `use_crux` but without `crux:approve` requests `GET /projects/:id/crux/pending_actions` | 403 / access denied | pending |
| 4 | Module gate off | Project without the `crux_ai` module enabled requests any `/projects/:id/crux/*` route | Redmine's standard "module not enabled" response, no Crux controller invoked | pending |
| 5 | Shared `find_project` concern | Any project-scoped controller, invalid `:id` | `render_404`, identical behavior across all 9 project-scoped controllers | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Full Administration tab set renders | Log in as admin → Administration → Plugins → Crux → click each of the 10 tabs | Each of General/Dashboard/Agents/Providers/Models/Billing/Audit Logs/Integrations/Settings/License renders without error | pending |
| 2 | Full Project Workspace tab set renders | Enable Crux AI module on a project → open project → click each of the 9 tabs | Each of Overview/Chat/Agents/Runs/Knowledge/Automations/Pending Actions/Analytics/Settings renders without error; no Billing tab present | pending |
| 3 | Module opt-in is per-project | Enable Crux AI on Project A only | Project B's menu has no Crux item; Project A's does | pending |
| 4 | Roles & Permissions screen | Administration → Roles & Permissions → a role | All 8 project-scoped + 1 global Crux permission appear under a "Crux" group, matching `security.md`'s canonical set | pending |
| 5 | Sidebar reflects new tabs | Open any Project Workspace tab | Sidebar shows all 9 icons in the fixed order from `ui_design.md`, active tab highlighted | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | User holds `crux:view_analytics` but not `use_crux` | Analytics tab is omitted entirely (not shown disabled), per `ui_design.md`'s "tabs removed, not grayed out" rule | pending |
| 2 | Direct URL to the deleted Billing route | `GET /projects/:id/crux/billing` after this spec ships | 404 (route removed), not a silent redirect | pending |
| 3 | Admin stylesheet scoping | Visit a non-Crux Redmine page (e.g. an Issue) after the hook fix | `administration.css` is not loaded | pending |
| 4 | Global Crux Dashboard direct URL as non-admin | `GET /crux` while logged in as a regular project member | 403, not the dashboard content | pending |

### QA Test Plan
*(Copied verbatim into the PR description)*

**Scope**: Navigation, permission gating, and placeholder rendering for every Administration and Project Workspace tab named in this spec. No AI behavior is exercised — there is none yet.

**Pre-conditions**:
- A Redmine instance with the `redmineflux_crux` plugin installed.
- At least two projects: one with the Crux AI module enabled, one without.
- At least one user per permission tier: admin, project member with full Crux permissions, project member with only `use_crux`.

**QA Steps**:
1. As admin, open Administration → Plugins → Crux and click through all 10 tabs.
2. As a non-admin, attempt `GET /crux` directly; confirm access denied.
3. Enable the Crux AI module on Project A; confirm Project B is unaffected.
4. As the full-permission project member, click through all 9 Project Workspace tabs on Project A.
5. As the `use_crux`-only member, open Pending Actions and Analytics; confirm both are absent from the tab bar.
6. Confirm the Roles & Permissions screen lists all 9 Crux permissions (8 project + 1 global) under one "Crux" group.

**Expected Outcomes**:
- Every tab renders its placeholder content with no error and no live data.
- Permission gating matches the mapping in Implementation Notes — no tab is reachable by URL guessing without its permission.
- No stand-alone Billing tab exists at the project level.

**Out of Scope**:
- Anything requiring a real model call, a real plan step, or real Redmine object mutation — none exists in this task.

---

## Quality Gates
*(Claude-filled during the three-gate review)*

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | `GlobalCruxController#show` has no `before_action :require_admin`, unlike its five sibling global controllers — reachable by any authenticated user via direct URL despite being an admin-only surface. | Code Changes, row 2 | `before_action :require_admin` added to the spec. |
| 2 | HIGH | Planning's permission list ("View Crux", "Use Crux Chat", "View Audit Logs", "Manage Settings") doesn't reuse the canonical 9 permissions already defined in `security.md`/`glossary.md`, and only 1 (`view_crux_ai`) exists in code today. | Code Changes row 1, Implementation Notes | Specification remaps every planned permission onto the canonical set and defines which controller/action each one gates. |
| 3 | HIGH | Project-level `project_crux_billing_controller`/route/sidebar icon is not one of the 9 canonical Project Workspace tabs in `ui_design.md`; `billing.md` places this content under Settings → Usage instead. | Code Changes (delete row) | Controller/view/route deleted; content folded into `ProjectCruxSettingsController` as a Usage sub-section. |
| 4 | MEDIUM | `find_project` duplicated verbatim across 5 controllers (soon 9+). | Code Changes (concern row) | Extracted to `app/controllers/concerns/crux_project_scoped.rb`. |
| 5 | LOW | Stylesheet asset misspelled `administraction.css`, referenced identically in the view hook. | Code Changes (rename row) | Renamed to `administration.css`; hook reference updated. |

Verdict: Approved — all HIGH findings resolved in spec text; MEDIUM/LOW resolved as well.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Same gap as Gate 1 #1 — a genuine unauthorized-access path, not a style issue: Redmine's admin-menu hiding is UI-only (`system_design.md`: "a hidden menu item is not a security boundary"). | Code Changes row 2 | Same resolution as Gate 1 #1. |
| 2 | MEDIUM | The admin stylesheet hook (`view_layouts_base_html_head`) injects `administraction.css` on every Redmine page instance-wide, not just Crux pages. | Code Changes (hook row) | Hook scoped to `global_crux*` controllers only. |
| 3 | LOW | No CSRF, mass-assignment, or SQL-injection surface exists in this task (no write forms, no params used in queries beyond `params[:id]` via `Project.find`) — confirmed clean. | — | No action needed. |
| 4 | LOW | No N+1 or pagination concerns — all data is hardcoded; no `crux_*` table reads exist yet. | — | No action needed; becomes relevant starting with crx-004/crx-005. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — all 3 HIGH findings (permission gap on `GlobalCruxController`, permission-set remapping, non-canonical Billing tab) and the MEDIUM/LOW findings are reflected as concrete rows in the Code Changes table above, not only discussed narratively.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `authorize` on a non-obvious action | A future new admin tab (Models/Integrations/License) ships without `require_admin` copy-pasted correctly from an existing controller | Yes — Functional Test #1 exercises every Administration tab |
| 2 | Tabs hidden vs. tabs disabled | Permission gating implemented by disabling a tab's contents instead of omitting it, contradicting `ui_design.md`'s "removed entirely, not grayed out" rule | Yes — Edge Case #1 |
| 3 | Route left behind after controller deletion | The `projects/:id/crux/billing` route forgotten in `config/routes.rb` after the controller/view are deleted, leaving a dangling route | Yes — Edge Case #2 |
| 4 | Global asset hook applied too broadly | The stylesheet-scoping fix checks the wrong condition (e.g. `params[:action]` instead of controller name) and still loads on non-Crux pages | Yes — Edge Case #3 |
| 5 | Permission group naming drift | The 9 permissions are registered in `init.rb` but not visibly grouped under "Crux" on the Roles & Permissions screen | Yes — Functional Test #4 |

Verdict: Approved.

---

## Done
*(filled when tests pass and PR is merged)*

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
