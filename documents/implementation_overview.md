# Crux — Implementation Overview

**Status**: Draft · tracks actual shipped code on the `development` branch

> This document is different from the other 19 files in `documents/`: those describe the target product (vision, architecture, roadmap). This one describes what has actually been *built* so far, task by task, as each `backlog/specification/crx-*.md` file is implemented. Update this file's task sections as new tasks ship; do not restate what the canonical docs already own — link to them instead.

## What's implemented so far

| Task | Title | Covers |
|---|---|---|
| [crx-001](../backlog/specification/crx-001-feature-plugin-foundation-ui.md) | Plugin Foundation & Initial UI | Plugin registration, permissions, navigation shell, placeholder tabs |
| [crx-002](../backlog/specification/crx-002-feature-conversation-chat-engine.md) | Conversation/Intent/Clarification/Chat Engine | Real persisted chat, intent classification, clarification loop |

Everything from crx-003 onward (execution plans, real agents, real model providers, knowledge retrieval, and so on) is specified but **not yet implemented**.

---

## crx-001 — Plugin Foundation & Initial UI

### What it does

Registers Crux as a Redmine plugin and builds the navigation/permission "skeleton" every later feature hangs off of. No AI logic exists at this stage — every page is placeholder content.

- **Plugin registration**: `redmineflux_crux`, version 1.0.0, appears under Administration → Plugins.
- **Global Administration → Crux area** (admin-only, gated by Redmine's own Administrator flag via `require_admin`): 10 tabs — General, Dashboard, Agents, Providers, Models, Billing, Audit Logs, Integrations, Settings, License. All render static/dummy data.
- **Per-project opt-in**: Project → Settings → Modules → "Crux AI" checkbox. Enabling it reveals a project-level "Crux" menu item; nothing changes for projects that don't enable it.
- **Project Workspace**: 9 tabs — Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, Settings. All placeholder except Chat (see crx-002 below).
- **Permission model**: 8 project-scoped Redmine permissions (`use_crux`, `crux_approve`, `crux_approve_destructive`, `crux_manage_agents`, `crux_manage_knowledge`, `crux_manage_integrations`, `crux_view_billing`, `crux_view_analytics`), each mapped to the specific tab/action it gates. Global admin surfaces use Redmine's built-in Administrator flag rather than a project permission.

### How it works, step by step (as an admin)

1. Install the plugin into Redmine's `plugins/` directory and run its migrations (see `Best Practices` at the bottom — general steps only, no environment-specific instructions here).
2. Log in as a Redmine administrator. Administration → Plugins → Crux now appears; click through General/Dashboard/Agents/Providers/Models/Billing/Audit Logs/Integrations/Settings/License.
3. Open any project → Settings → Modules → check "Crux AI" → Save.
4. That project's left-hand menu now shows a "Crux" item. Projects that didn't check the box are completely unaffected — no menu item, no route, no data.
5. Inside the project's Crux workspace, click through the 9 tabs. All but Chat show placeholder cards/tables.
6. As a project member holding only `use_crux` (not the other 7), confirm tabs like Pending Actions/Analytics/Knowledge/Automations are *absent* from the tab bar entirely (not just disabled) — this is deliberate, matching the product's "remove, don't gray out" rule.

---

## crx-002 — Conversation Engine, Intent Detection, Clarification Engine & Chat Engine

### What it does

Turns the Chat tab from a fake demo (a hardcoded reply after a `setTimeout`) into a real, persisted, turn-based conversation — without calling any AI model yet. Classification and clarification are both rule/keyword-based placeholders that a later task can swap out without touching anything built here.

- **Real persistence**: every message a user sends, and every reply Crux generates, is saved to the database and survives a page reload.
- **Intent classification**: each message is matched against the 21 canonical intents (Create project, Generate roadmap, Sprint planning, Create issues, Generate test cases, Knowledge search, and so on). A message can come back as one clear intent, `unclassified` (nothing matched), or *ambiguous* (more than one intent matched — e.g. "clean up the backlog" could mean either "Backlog refinement" or "Resolve issue").
- **Clarification loop**: if a request is under-specified, Crux asks follow-up questions instead of guessing. The one worked example currently implemented is "Create an HRMS" → six questions (tech stack, timeline, auth method, database, modules, deployment environment). A well-specified request like "Create a CRM System with Customer, Leads, and Invoice modules" skips clarification entirely.
- **Partial-answer handling**: if a user answers only some of the six questions in one reply, the remaining questions are re-asked — not the same six repeated from scratch.
- **Async processing**: classifying a message never blocks the page. It runs in a background job; the composer shows a "Crux is thinking…" indicator and polls until the reply appears.
- **Graceful failure**: if the background job errors, a message from Crux itself appears in the thread explaining something went wrong, and the composer re-enables — it never spins forever.
- **Out-of-scope fallback**: a request matching none of the 21 intents (e.g. "order me a coffee") gets a plain "I can't help with that here" reply plus a few suggestions, never a guess.

### How it works, step by step (as an end user)

1. Open a project with Crux AI enabled → Chat tab.
2. Type "Create an HRMS." and press Send (or Enter).
3. The composer disables and shows a typing indicator.
4. Within a couple of seconds, Crux's reply appears with six clickable question chips underneath it (clicking a chip drops that question's text into the composer — answering by typing is just as valid).
5. Answer the questions — either one at a time across several messages, or all at once in one free-text reply (e.g. "React, 3 months, OAuth, Postgres, HR/Payroll/Leave, AWS").
6. Once every question has been covered, Crux confirms the request now has enough detail and the conversation is marked ready for the next phase.
7. Reload the page: the entire thread — your messages, Crux's questions, your answers — is still there.
8. Try "Create a CRM System with Customer, Leads, and Invoice modules." in a fresh conversation: no clarification round happens, because the request already names its modules.
9. Try something unrelated, like "order me a coffee": Crux replies that it can't help with that here.

### How it works internally, step by step (technical)

1. **Send** — the composer's JS POSTs the typed text to `POST /projects/:id/crux/chat/messages`. Only the message `content` is accepted from the client; the project, the current conversation, and the current user are always resolved server-side, never taken from the request.
2. **Persist the user's turn** — the controller finds the caller's current conversation (the newest one still `draft` or `clarifying`; a brand-new one is created if none exists) and saves the message immediately.
3. **Enqueue, don't block** — a background job (`ProcessChatTurnJob`) is queued with the conversation, project, user, and text; the HTTP response returns right away, before any classification happens.
4. **Classify** — the job calls `ChatEngine`, which calls `IntentClassifier.call(text)`. This checks the text against keyword/phrase patterns for all 21 intents and returns either one intent, `:unclassified`, or an array of intents if more than one pattern matched.
5. **Branch on the result**:
   - No match → the out-of-scope fallback message is saved.
   - Multiple matches → an "did you mean X or Y?" message is saved.
   - One match → `ClarificationEngine.call` decides whether the request is complete enough.
6. **Clarify or proceed** — for the one intent with real clarification logic today (`create_project`), the engine checks for a simple completeness signal (does the text already contain "with" plus enough detail?) on the first turn, or — on later turns — counts how many of the six questions prior replies have already covered. It returns either the remaining questions or `nil`.
7. **Update state** — if questions remain, the conversation's `state` becomes `clarifying` and an agent message is saved containing the question list. If nothing remains, `state` becomes `planned` and a confirmation message is saved. (The database column already supports the full state machine — `draft → clarifying → planned → awaiting_approval → executing → completed` — so later tasks only add new transitions, not new states.)
8. **Poll for the reply** — meanwhile, the browser polls `GET /projects/:id/crux/chat` (JSON format) roughly every 1.5 seconds. As soon as it sees a message newer than the one it already knows about, it appends it to the thread, turns off the typing indicator, and stops polling.
9. **If the job itself fails** — any unexpected error is caught, logged, and turned into a `system`-role message in the thread ("Something went wrong processing that message. Please try again."), so the composer never re-enables silently *without* an explanation, and never re-enables *without* re-enabling at all.

### Data model introduced

| Table | Columns |
|---|---|
| `crux_conversations` | `id`, `project_id`, `user_id`, `agent_id` (unused until agents exist), `state`, `created_at` |
| `crux_messages` | `id`, `conversation_id`, `role` (`user`/`agent`/`system`), `content`, `created_at` |

### What's deliberately not in this task

- No AI model is called anywhere — `IntentClassifier` and `ClarificationEngine` are both plain keyword/rule logic today, built so a future model-backed version is a drop-in replacement.
- No execution plan is generated and no agent actually does anything yet — reaching `planned` just means "ready for the next phase," which hasn't shipped.
- No knowledge-source grounding (project Issues/Wiki/Repository content) is used when classifying or clarifying — that arrives in a later task.

---

## Cumulative feature list (everything usable today)

- Install and register the plugin; per-project opt-in via the Crux AI module.
- Global Administration Crux area (10 tabs, placeholder data) and per-project Crux workspace (9 tabs, mostly placeholder).
- Real, permission-gated navigation — tabs a user can't access are removed from the tab bar entirely.
- A working Chat tab: persisted conversations, 21-intent classification, a clarification loop with the HRMS worked example, async processing with a typing indicator, and a graceful out-of-scope fallback.

## What's next

Every remaining task lives in `backlog/specification/` (crx-003 through crx-026), covering — in order — the approval-gated execution plan (crx-003), the first real agents and Run Ledger (crx-004), permission-filtered knowledge retrieval (crx-005), and the first real AI model provider (crx-006), before Phase 2–4 add multi-agent collaboration, integrations, billing/analytics, automation, and the Developer Agent's git workflow. See [roadmap.md](roadmap.md) for the phase breakdown and `TODO.md` at the repo root for current task status.
