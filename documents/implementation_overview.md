# Crux — Implementation Overview

**Status**: Draft · tracks actual shipped code on the `development` branch

> This document is different from the other 19 files in `documents/`: those describe the target product (vision, architecture, roadmap). This one describes what has actually been *built* so far, task by task, as each `backlog/specification/crx-*.md` file is implemented. Update this file's task sections as new tasks ship; do not restate what the canonical docs already own — link to them instead.

## What's implemented so far

| Task | Title | Covers |
|---|---|---|
| [crx-001](../backlog/specification/crx-001-feature-plugin-foundation-ui.md) | Plugin Foundation & Initial UI | Plugin registration, permissions, navigation shell, placeholder tabs |
| [crx-002](../backlog/specification/crx-002-feature-conversation-chat-engine.md) | Conversation/Intent/Clarification/Chat Engine | Real persisted chat, intent classification, clarification loop |
| [crx-003](../backlog/specification/crx-003-feature-workflow-approval-engine.md) | Workflow Engine, Approval Engine & Notification Engine | Real execution plans/steps, approve/reject/modify, destructive-action gate, baseline notifications |
| [crx-004](../backlog/specification/crx-004-feature-agent-engine-run-ledger.md) | Agent Engine, 7 GA Agents & Run Ledger | Real agents, Requirement Analyst → Planner hand-off, Mock Provider, append-only Run Ledger |

Everything from crx-005 onward (permission-filtered knowledge retrieval, real AI model providers, multi-agent collaboration, integrations, billing/analytics, and so on) is specified but **not yet implemented**.

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

## crx-003 — Workflow Engine, Approval Engine & Notification Engine

### What it does

Turns a drafted plan into something a human can approve, reject, or modify — and turns an approved plan into completed (or failed) work, notifying the right people along the way. Before this task, Pending Actions was an empty placeholder tab (crx-001), and no execution plan could exist for real (crx-002 only ever got a conversation to `planned`).

- **Real execution plans and steps**: every plan is a row with one or more steps, each carrying an action type, a target, and its own status.
- **Approval Engine**: Pending Actions now shows real plans awaiting approval, with per-step Approve/Reject/Modify controls and a plan-level "Approve All"/"Reject."
- **Two-tier permission gate**: ordinary steps need `crux:approve`; three destructive action types (Delete Project, Delete Milestone, Deploy) additionally need `crux:approve_destructive`. A user holding only the ordinary permission can approve every ordinary step in a mixed plan, leaving just the destructive one waiting for someone else — approval is additive, not all-or-nothing.
- **Reject/Modify** both send the whole plan back to `planned` for re-drafting, rather than leaving it in a half-approved state.
- **Execution**: once every step in a plan is approved, it executes step by step in order; a configurable retry count (default 3, adjustable per deployment) applies to each step before it's marked failed and the whole plan reverts to `planned`.
- **Notifications**: a plan becoming awaiting-approval, approved, rejected, modified, completed, or failed all write a notification record for the relevant people.
- **QA-only stub plan generator**: a rake task lets a developer manufacture a realistic 7–8 step plan (including one destructive step) against any conversation, for testing the approval/execution flow before a real agent can draft plans — never reachable from the product UI itself.

### How it works, step by step (as an approver)

1. Open a project's Pending Actions tab. If nothing is awaiting approval, an empty state explains that approved/rejected items move to Runs.
2. Each awaiting plan renders as a card: every step listed with its action, target, current status, and Approve/Reject/Modify buttons. Destructive steps (e.g. "Delete Milestone") are visually flagged, and their Approve button is disabled with an explanatory tooltip unless you hold the stricter destructive-approval permission.
3. Click "Approve All" to approve every step you're permitted to approve in one action. If a destructive step is in the mix and you don't hold that permission, it's simply skipped — it stays awaiting approval for someone who does.
4. Once every step in the plan has been approved by someone, the plan itself starts executing, and each step's status pill updates live, in place, with no page reload.
5. If a step exhausts its retries, the whole plan reverts to `planned` and re-enters the approval queue for another pass.
6. Rejecting (at the plan or step level) or Modifying a step (currently: reassigning it to a different project member) both send the plan back to `planned`; a Modify naming someone who isn't a project member is refused with an explanation rather than silently accepted.

### How it works internally, step by step (technical)

1. A single service (`WorkflowEngine`) owns every plan/step state transition; each transition is a database-level compare-and-swap (`update ... where status = X`), so two concurrent Approve clicks on the same plan can never both "win."
2. Approve is additive: it marks every `awaiting_approval` step the caller is permitted to approve, and only flips the plan to `executing` once nothing is left awaiting approval.
3. A single, centralized permission check (`ApprovalGate`) is the only place destructive-vs-ordinary approval is decided — never duplicated per controller action.
4. Once `executing`, a background job walks the plan's approved steps in order; each step goes through a retry manager that tracks its attempt count against a configurable maximum before giving up.
5. A notification is written on every plan-level transition — approvers are notified when a plan needs review, the conversation's owner on every transition after that.
6. Pending Actions and its approve/reject/modify actions are pure AJAX: a click sends a request that returns JSON, and the browser patches just the affected status pill and disables just the relevant buttons — approving one step never reloads or disturbs the rest of the page.

### Data model introduced

| Table | Columns |
|---|---|
| `crux_settings` | `id`, `key`, `value`, `scope` (global/project), `project_id` |
| `crux_execution_plans` | `id`, `conversation_id`, `status`, `estimated_time`, `estimated_cost`, `approved_by`, `approved_at` |
| `crux_plan_steps` | `id`, `plan_id`, `action_type`, `target_type`, `target_id`, `status`, `payload`, `attempts`, `error_message` |
| `crux_notifications` | `id`, `user_id`, `event_type`, `ref_type`, `ref_id`, `read_at`, `created_at` |

### What's deliberately not in this task

- Nothing actually creates real Redmine objects yet — a step's execution is still simulated; a real agent actually dispatching to one arrives in crx-004 and beyond.
- No real agent drafts these plans yet — before crx-004, the only way a plan exists at all is the QA-only rake task, never the product UI.
- The Notification Engine here is a baseline: notification records are written, but nothing renders a bell-icon notification center yet.

---

## crx-004 — Agent Engine, 7 GA Agents & Run Ledger

### What it does

Gives conversations and execution plans an actual author and executor. Before this task, reaching `planned` (crx-002) just posted a canned "ready for the next phase" message, and the only way a plan ever existed was crx-003's QA-only stub generator.

- **All 12 catalog agents are real, configurable rows** — the 7 GA agents (Requirement Analyst, Planner, Developer, QA Agent, Documentation Agent, Reporter, DevOps Agent) enabled by default; the 5 Phase 2/3 agents (Security Agent, Code Reviewer, Product Owner Agent, Scrum Master Agent, Release Manager Agent) present in the catalog but disabled until their own task builds real behavior for them.
- **Requirement Analyst → Planner hand-off**: once a conversation has enough detail to plan, Requirement Analyst posts a real structured-requirements reply, then Planner drafts and submits a real execution plan for approval — replacing crx-003's stub generator for actual conversations.
- **Mock Provider**: a deterministic, canned-response model — one of the product's own canonical providers, not a placeholder hack — so every agent can be exercised and QA'd without any external API key. Each of the 12 roles has its own canned response; Planner's is the exact canonical 7-step plan (Create Project · Generate Wiki · Create Versions · Generate Milestones · Create 84 Issues · Assign Users · Generate Documentation).
- **Run Ledger**: every agent invocation — successful or failed — writes a permanent, append-only record (who ran it, which agent, which model, token counts, what it produced). A billable outcome record is additionally created only when the run represents a real, already-approved deliverable — never for an ordinary chat reply.
- **Fallback models**: if an agent's primary model fails, it retries once against its configured fallback model, and the run record shows which model actually produced the result, so a silent quality change never goes unnoticed.
- **Agents tabs now show and edit real data** — model, fallback model, temperature, enabled — instead of a static demo table, in both Administration and each project's own Agents tab. A project can override a specific agent just for itself without affecting any other project; everyone else keeps seeing the global default.
- **Attribution badges**: every agent-authored chat message and every plan step now shows which agent produced it (e.g. a wiki-page step traces to "Documentation Agent").

### How it works, step by step (as an end user)

1. Open the Chat tab and send a well-specified request, e.g. "Create a CRM System with Customer, Leads, and Invoice modules." (one that doesn't need clarification).
2. Within a few seconds, a reply from "Requirement Analyst" appears, carrying its own attribution badge, summarizing the captured requirements.
3. Shortly after, a reply from "Planner" confirms a plan was drafted, and the Pending Actions tab shows a real 7-step plan awaiting your approval — each step tagged with the agent responsible for it (Planner for most steps, Documentation Agent for the wiki-generation step).
4. Approve the plan as usual (crx-003's flow, unchanged). As each step executes, it dispatches to its responsible agent and completes.
5. Open Administration → Agents (as a site admin), or a project's own Agents tab: all 12 canonical agents are listed with real enabled/model/fallback/temperature settings; a project admin can override any agent just for their project without touching the global default.

### How it works internally, step by step (technical)

1. Once a conversation reaches `planned` with no existing plan, a background job is enqueued in place of the old placeholder message.
2. That job resolves the effective Requirement Analyst (a project override if one exists, otherwise the global default) and invokes it through a single shared invocation path; on success, it does the same for Planner.
3. That shared path is used by every agent, of every kind: it assembles context (project identity, bounded conversation history, detected intent — permission-filtered knowledge retrieval is an explicit seam left for a later task), calls the Mock Provider with the agent's primary model, falls back once to the agent's fallback model on failure, then routes the output — a chat reply for most roles, a real execution plan for Planner — and always writes a Run Ledger record.
4. A billable outcome record is written only when a run is tied to an already-approved plan step — never for a bare chat reply or the plan-authoring run itself — mirroring the product's "fixed deliverable, approved, has a Run Ledger receipt" billing definition exactly.
5. When an approved step executes (crx-003's execution job), it now dispatches through this same path to the step's responsible agent, re-checking whether that agent is still enabled at the moment it actually runs — not just when the job was first queued — so disabling an agent takes effect immediately, even for work already sitting in the retry loop.
6. Run Ledger records can never be edited or deleted after the fact — a retried or fallback attempt always produces a brand-new record, preserving a complete history of every attempt.

### Data model introduced

| Table | Columns |
|---|---|
| `crux_agents` | `id`, `name`, `role`, `prompt_template`, `model`, `fallback_model`, `temperature`, `enabled`, `project_id` |
| `crux_runs` | `id`, `agent_id`, `plan_step_id`, `user_id`, `model`, `provider`, `prompt_ref`, `context_refs`, `tokens_in`, `tokens_out`, `cost`, `output_ref`, `created_at` |
| `crux_outcomes` | `id`, `run_id`, `outcome_type`, `project_id`, `billed_at` |
| `crux_messages` (extended) | `+ agent_id` — which agent, if any, authored a given reply |

### What's deliberately not in this task

- No real AI model provider exists yet — every agent runs on the deterministic Mock Provider; the real providers (OpenAI, Anthropic, Gemini, Azure OpenAI, Ollama, Local Models) arrive in a later task behind the exact same provider interface, so nothing built here needs to change when they land.
- No permission-filtered knowledge retrieval (project Issues/Wiki/Repository content) feeds an agent's context yet — only conversation history does; the seam for a later task to add it already exists.
- The 5 Phase 2/3 agents exist only as disabled configuration rows — none of them have real behavior wired up yet.
- Billing/quota enforcement isn't built — outcome records are captured but nothing yet meters them against a plan tier.

---

## Cumulative feature list (everything usable today)

- Install and register the plugin; per-project opt-in via the Crux AI module.
- Global Administration Crux area (10 tabs) and per-project Crux workspace (9 tabs) — Agents (both) now show and edit real data; the rest remain placeholder pending later tasks.
- Real, permission-gated navigation — tabs a user can't access are removed from the tab bar entirely.
- A working Chat tab: persisted conversations, 21-intent classification, a clarification loop with the HRMS worked example, async processing with a typing indicator, and a graceful out-of-scope fallback.
- A real Requirement Analyst → Planner hand-off that drafts an actual execution plan from a well-specified chat request, running on a deterministic Mock Provider.
- A full approval workflow: per-step and plan-level Approve/Reject/Modify, a two-tier destructive-action gate, live in-place status updates, retry-then-fail execution, and notifications on every transition.
- An append-only Run Ledger recording every agent invocation, with billable-outcome tracking that only fires for real, approved deliverables.
- Agent attribution badges on chat messages and plan steps, and editable Agents tabs (Administration + per-project, with global-default/project-override semantics) for all 12 catalog agents.

## What's next

Every remaining task lives in `backlog/specification/` (crx-005 through crx-026), covering — in order — permission-filtered knowledge retrieval (crx-005) and the first real AI model provider (crx-006), before Phase 2–4 add multi-agent collaboration, integrations, billing/analytics, automation, and the Developer Agent's git workflow. See [roadmap.md](roadmap.md) for the phase breakdown and `TODO.md` at the repo root for current task status.
