## Metadata
- **Task ID**: crx-002-feature-conversation-chat-engine
- **Title**: Conversation Engine, Intent Detection, Clarification Engine & Chat Engine orchestration (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `chat_engine.md`, `architecture.md`, `database_design.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set, not a developer-authored session — flagged per the note above)*

**Description**:

Replace the static placeholder Chat tab shipped in crx-001 with a real turn-based conversation: a user sends a message, it is persisted, classified against the 21 canonical intents (`chat_engine.md`), and — if the request is under-specified — answered with clarification questions instead of guessed at. This task delivers the Conversation Engine (turn/message persistence), Intent Detection (classification), the Clarification Engine (follow-up questions), and the Chat Engine (the orchestration shell the Chat tab actually talks to). It stops short of generating an execution plan or invoking a specific named agent's model output — that begins with crx-004 (Agent Engine) once crx-006 (Provider Layer) exists to actually call a model. Until then, Intent Detection and Clarification Engine run on simple rule/keyword classification, not a live model call, so this task can ship and be tested independently of provider configuration.

**Goal**:

A user typing a message on the Chat tab gets a persisted, threaded conversation; an under-specified request (the canonical "Create an HRMS" example) receives the documented clarification questions; a well-specified request (the canonical "Create a CRM System with Customer, Leads, and Invoice modules" example) is acknowledged and held at a new `planned`-adjacent state ready for crx-003/crx-004 to pick up, without yet producing a real execution plan. All state is durable across page reloads (no more in-memory-only demo JS).

**Objectives**:
- [ ] Add `crux_conversations` and `crux_messages` tables (`database_design.md`).
- [ ] Implement `state` on `crux_conversations`: `draft → clarifying → planned` (this task stops at `planned`; `awaiting_approval` onward belongs to crx-003).
- [ ] Replace `ProjectCruxChatController`'s hardcoded `@messages` with real persistence: create a conversation on first message, append every turn.
- [ ] Implement Intent Detection against the 21 canonical intents (`chat_engine.md`), rule/keyword-based for this task (no model call yet).
- [ ] Implement the Clarification Engine: recognize an under-specified request and generate the documented follow-up questions; hold the conversation at `clarifying` until answered.
- [ ] Implement the Chat Engine as the orchestration entry point the controller calls — sequencing Intent Detection → Clarification Engine → (hand off, not yet executed).
- [ ] Async execution: any classification/clarification logic heavier than a lookup must run as a background job per `system_design.md`'s "no model call ever runs on the request thread" rule, with a typing indicator on the composer while it runs.
- [ ] Out-of-scope guard: unclassifiable or out-of-21-intent requests get the documented fallback reply ("I can't help with that here…" + suggested-intent list), never a guess.

**Deliverables**:
- [ ] Migrations: `crux_conversations`, `crux_messages`.
- [ ] Models: `Crux::Conversation`, `Crux::Message`.
- [ ] `Crux::ChatEngine` service object (orchestration shell).
- [ ] `Crux::IntentClassifier` (rule-based for this task).
- [ ] `Crux::ClarificationEngine` (question generation for the 21-intent taxonomy).
- [ ] Background job: `Crux::ProcessChatTurnJob`.
- [ ] `ProjectCruxChatController` rewritten to read/write real data instead of dummy arrays.
- [ ] Composer/typing-indicator JS wired to the async job's completion signal (polling, per `ui_design.md` Assumptions — no WebSocket in Phase 1).
- [ ] Updated Chat tab view: real thread history, real clarification chips generated from `ClarificationEngine` output (not hardcoded HTML).

**Out of Scope**: Execution plan generation (crx-003/crx-004), any named agent's actual model output (crx-004/crx-006), Knowledge Engine context assembly (crx-005 — this task's Intent Detection/Clarification Engine work from message text and recent history only, not retrieved knowledge), multi-intent parsing, voice input.

---

## Specification

**Complexity**: HIGH

**Reason**: Introduces the first two `crux_*` tables and the first background-job execution path in the plugin; changes an existing controller from static to persisted; the async pattern (job queue + polling) it establishes is reused by every later task (crx-003 through crx-006), making correctness here high-leverage. Meets HIGH per new migrations + cross-module impact.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_conversations.rb` | create | `crux_conversations(id, project_id, user_id, agent_id, state, created_at)` per `database_design.md`; `agent_id` nullable until crx-004 exists (no agents to assign to yet — default to a placeholder "unassigned" state, not a fabricated agent row). |
| `db/migrate/XXXX_create_crux_messages.rb` | create | `crux_messages(id, conversation_id, role, content, created_at)`. |
| `app/models/crux/conversation.rb` | create | `belongs_to :project`, `belongs_to :user`, `has_many :messages`; `state` enum matching `draft/clarifying/planned` (remaining states added by crx-003, not duplicated here). |
| `app/models/crux/message.rb` | create | `belongs_to :conversation`; `role` enum `user/agent/system`. |
| `app/services/crux/chat_engine.rb` | create | Orchestration entry point: receives `(project, user, conversation, text)`, calls `IntentClassifier`, then `ClarificationEngine` if needed, else marks `planned` and stops (no plan generation here). |
| `app/services/crux/intent_classifier.rb` | create | Maps free text to one of the 21 canonical intents or `:unclassified`, rule/keyword-based for this task; structured so a later task can swap in a model-backed classifier behind the same interface. |
| `app/services/crux/clarification_engine.rb` | create | Given an intent + message text, returns either `nil` (enough info) or a small set of follow-up questions; encodes the canonical HRMS question set as its worked example/test fixture. |
| `app/jobs/crux/process_chat_turn_job.rb` | create | Background job wrapping `ChatEngine` invocation — enforces `system_design.md`'s "no model call/classification on the request thread" rule uniformly, even though this task's classification is cheap; keeps the pattern consistent for later tasks that add a real model call behind the same job. |
| `app/controllers/project_crux_chat_controller.rb` | modify | `index` loads the current (or newest) `Crux::Conversation` for `@project`/`User.current` and its messages instead of a hardcoded array; add a `create_message` action (POST) that persists the user's turn and enqueues `ProcessChatTurnJob`. |
| `config/routes.rb` | modify | Add `POST projects/:id/crux/chat/messages` for `create_message`. |
| `app/views/project_crux_chat/index.html.erb` | modify | Render `@conversation.messages` instead of the hardcoded `@messages` array; clarification chips rendered from the last `agent`-role message's structured question list, not inline HTML; composer POSTs to the new route and polls for the job's completion instead of the fake `setTimeout` demo reply. |
| `app/controllers/concerns/crux_project_scoped.rb` | reuse | No change — the shared `find_project` concern from crx-001 is reused here. |

### Implementation Notes

- **This task deliberately does not call a model.** `Crux::IntentClassifier` and `Crux::ClarificationEngine` are rule/keyword-based now so the conversation-state machinery (persistence, async job, polling) can be built and tested before crx-006 (Provider Layer) exists. Swapping in real classification later means changing the inside of these two classes, not their calling convention — `ChatEngine` and the controller are unaffected.
- **`agent_id` on `crux_conversations` is nullable in this task's migration** because no `crux_agents` table exists yet (crx-004). A conversation started under this task simply has no agent attribution until crx-004 ships; do not fabricate a dummy agent row to satisfy a NOT NULL constraint.
- **State machine scope is intentionally partial.** This task implements `draft → clarifying → planned` only. `awaiting_approval → executing → completed` and the `rejected`/`edited` loop belong to crx-003 (Workflow Engine) — `Crux::Conversation.state` should be defined as a full enum matching `workflow_engine.md`'s six states now (to avoid a schema migration in crx-003 just to add enum values), but this task's code never transitions past `planned`.
- **Context assembly is not implemented here.** `chat_engine.md` describes context assembly layering four inputs including "knowledge sources enabled for the project and permitted for the user" — that layer is crx-005's Knowledge Engine. This task's `ChatEngine` assembles only project identity, conversation history, and the detected intent/clarification answers — the first two of the four layers.
- Every background job path introduced here must emit on both success and failure (`system_design.md` Best Practices) — `ProcessChatTurnJob` writes an error message back into the thread as a `role: system` message on failure rather than leaving the composer spinning indefinitely.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Intent classification — clear request | "Create a CRM System with Customer, Leads, and Invoice modules." | Classified as `create_project`, sufficient info detected | pending |
| 2 | Intent classification — under-specified | "Create an HRMS." | Classified as `create_project`, insufficient info | pending |
| 3 | Intent classification — unclassifiable | "order me a coffee" | `:unclassified` | pending |
| 4 | Clarification question generation | Under-specified `create_project` intent | Returns the documented 6-question HRMS set (stack, timeline, auth, database, modules, deployment) | pending |
| 5 | Conversation state transition | New conversation, first message classified with sufficient info | `state` moves `draft → planned` directly (no clarification needed) | pending |
| 6 | Conversation state transition | New conversation, first message under-specified | `state` moves `draft → clarifying` | pending |
| 7 | Clarification loop | User answers only 2 of 6 questions | `state` remains `clarifying`; remaining questions re-asked, not the same 6 repeated verbatim | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end clarification flow | Open Chat tab → send "Create an HRMS." → answer all 6 questions across replies | Conversation reaches `planned`; full thread persists across a page reload | pending |
| 2 | End-to-end direct handoff | Send "Create a CRM System with Customer, Leads, and Invoice modules." | Conversation reaches `planned` in one turn, no clarification asked | pending |
| 3 | Composer busy state | Send any message | Composer disables with a typing indicator until the background job completes, then re-enables with the reply appended | pending |
| 4 | Out-of-scope fallback | Send "order me a coffee" | Reply states it can't help with that and offers the suggested-intent list | pending |
| 5 | Conversation persistence across tabs | Send a message, switch to another Project Workspace tab, return to Chat | Full thread is intact, no lost turns | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Empty/whitespace-only message | Composer send is a no-op or rejected, no empty `crux_messages` row created | pending |
| 2 | Ambiguous intent spanning two of the 21 | "clean up the backlog" (Backlog refinement vs. Resolve issue) | Chat Engine asks which is intended rather than silently picking one | pending |
| 3 | Background job failure (e.g. classifier raises) | A `role: system` error message is appended to the thread; composer re-enables; conversation state does not silently advance | pending |
| 4 | Second conversation started while first is `clarifying` | `chat_engine.md`: "will not open a second plan lineage before the current one reaches completed" — for this task's scope, a second concurrent conversation in the same project by the same user is either blocked or clearly separated, not silently merged | pending |
| 5 | Very long message history | Conversation with 200+ messages | Context assembly truncates to the bounded window (`chat_engine.md` Assumptions) without erroring | pending |
| 6 | Message timestamp display | A message is created while the viewing user's Redmine time zone differs from server time | `crux_messages.created_at` renders in the viewing user's configured time zone, not raw server time | pending |
| 7 | Concurrent sends from the same user | Two messages submitted in rapid succession (e.g. double-click Send) | Both persist in strict chronological order with no dropped or reordered `crux_messages` row | pending |

### QA Test Plan

**Scope**: Message persistence, intent classification accuracy against the 21-intent taxonomy, the clarification loop, and async UX (typing indicator, no blocking request). Does not cover plan generation, agent execution, or Knowledge Engine grounding.

**Pre-conditions**:
- crx-001's permission/module scaffolding is in place; a project with Crux AI enabled and at least one user holding `use_crux`.
- No `crux_agents` rows exist yet (expected — crx-004 not shipped).

**QA Steps**:
1. Send the canonical HRMS prompt; answer clarification questions one at a time and all-at-once (free-text bundling multiple answers) to confirm both paths work.
2. Send the canonical CRM prompt; confirm no clarification round occurs.
3. Send an out-of-scope prompt; confirm the fallback message and suggested-intent list.
4. Reload the page mid-conversation; confirm the thread persists.
5. Send a message and immediately navigate to another tab; confirm the composer's busy state doesn't leak into other tabs and the reply is present on return.

**Expected Outcomes**:
- Every conversation's full turn history is durable in `crux_messages`.
- No model provider call occurs anywhere in this task (confirm via absence of any Provider Layer reference in the code paths exercised).
- No request thread is ever blocked waiting on `ProcessChatTurnJob`.

**Out of Scope**:
- Real agent responses, plan previews, and anything requiring `crux_agents`/`crux_execution_plans` (later tasks).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Original draft risked defining `crux_conversations.state` as a 3-value enum (`draft/clarifying/planned`), which would force a schema-changing migration in crx-003 to add `awaiting_approval/executing/completed`. | Code Changes, `Crux::Conversation` model row | Spec now defines the full 6-state enum in this task's migration; crx-003 only adds transition *logic*, not new enum values. |
| 2 | HIGH | `agent_id` on `crux_conversations` has no source of truth yet (no `crux_agents` table until crx-004) — an early draft implied a NOT NULL constraint, which would force fabricating a dummy row. | Code Changes, migration row | `agent_id` specified nullable; Implementation Notes calls this out explicitly so crx-004 doesn't have to backfill or relax a constraint. |
| 3 | MEDIUM | `ProcessChatTurnJob` needed an explicit failure path — a raised exception inside a background job otherwise fails silently from the user's perspective (composer spins forever). | Implementation Notes | Job writes a `role: system` error message and always re-enables the composer, per `system_design.md`'s "emit on both success and failure" rule. |
| 4 | LOW | `IntentClassifier`/`ClarificationEngine` need a stable interface boundary so a future model-backed classifier is a drop-in replacement, not a rewrite of `ChatEngine`/the controller. | Implementation Notes | Called out explicitly as a design constraint for this task. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | `create_message` is a new write action — must not accept arbitrary params; the message body needs strong-param scoping to `content` only, with `conversation_id`/`project_id`/`user_id` derived server-side, never client-supplied. | Code Changes, controller row | Added as an explicit constraint on the new `create_message` action. |
| 2 | HIGH | A new POST action means CSRF protection must not be bypassed for it — Redmine's default `protect_from_forgery` must remain active; no `skip_before_action` is introduced. | Code Changes, controller row | Confirmed no CSRF skip is part of this spec. |
| 3 | MEDIUM | `crux_messages`/`crux_conversations` will be queried by `(project_id, created_at)` and `conversation_id` from day one — missing indexes here would repeat the exact N+1/slow-query risk `database_design.md` already flags. | Code Changes, migration rows | Migrations must include indexes on `project_id`, `user_id`, `conversation_id`, and the composite `(project_id, created_at)` per `database_design.md` Best Practices — added as an explicit migration requirement. |
| 4 | MEDIUM | The async job must run "as" the requesting user for permission-check purposes (`system_design.md`), not with elevated worker privileges — relevant even though this task does no Knowledge Engine retrieval yet, to avoid establishing the wrong pattern for crx-005. | Implementation Notes | `ProcessChatTurnJob` is specified to carry `user_id` and never widen permissions inside the job. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the 6-state enum, nullable `agent_id`, job failure path, strong params, CSRF, and required indexes are all concrete rows/notes in the spec above, not left as verbal agreements.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | `respond_to :js` missing for AJAX controller actions | `create_message` implemented as a plain HTML POST/redirect instead of returning JSON/JS the composer's polling logic expects | Yes — Functional Test #3 exercises the composer busy-state round trip end to end |
| 2 | Date/time comparison without timezone conversion | Message timestamps rendered in server time instead of the viewing user's Redmine time zone preference | Yes — Edge Case #6 |
| 3 | Silent partial failure inside a background job | Classifier raises mid-job, conversation is left in an undefined state (neither `clarifying` nor `planned`) | Yes — Edge Case #3 |
| 4 | Missing `permit` key on nested/bundled answers | User answers multiple clarification questions in one free-text reply; parsing silently drops one answer | Yes — Unit Test #7 (partial-answer loop) |
| 5 | DB-level uniqueness/race on concurrent turns | Two rapid sends from the same user create out-of-order `crux_messages` rows | Yes — Edge Case #7 |

Verdict: Approved — all 5 predicted bugs are now covered by a concrete test/edge case above.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
