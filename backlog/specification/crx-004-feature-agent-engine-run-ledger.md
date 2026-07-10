## Metadata
- **Task ID**: crx-004-feature-agent-engine-run-ledger
- **Title**: Agent Engine, 7 GA agents & Run Ledger (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `agent_catalog.md`, `architecture.md`, `database_design.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Give crx-002's conversations and crx-003's execution plans an actual author and executor: the Agent Engine, hosting the 7 GA agents (Requirement Analyst, Planner, Developer, QA Agent, Documentation Agent, Reporter, DevOps Agent), and the Run Ledger (`crux_runs`/`crux_outcomes`) that records every invocation. This task also defines the Provider Layer *interface* and its first concrete implementation, the Mock Provider — one of the 7 canonical providers named in `architecture.md`/`plugin_overview.md`, not an invented shortcut — so agents can be built and QA'd deterministically before crx-006 wires in real OpenAI/Anthropic/etc. adapters. Knowledge Engine context (crx-005) is similarly stubbed to "conversation history only" behind a narrow, swappable interface.

**Goal**:

A conversation that reaches `planned` (crx-002) is picked up by the Requirement Analyst and Planner, producing a real `crux_execution_plans`/`crux_plan_steps` set (replacing crx-003's QA-only stub generator) that flows through the real approval gate. An approved step is "executed" by dispatching to the responsible agent, which — for this task's scope — writes its output as a chat reply or a plan-step outcome using the Mock Provider's deterministic responses, with a full `crux_runs` row recorded regardless of success or failure. Agents can be enabled/disabled and assigned a model via Administration/Project Agents settings (replacing crx-001's dummy `@agents` arrays).

**Objectives**:
- [ ] Add `crux_agents`, `crux_runs`, `crux_outcomes` tables (`database_design.md`).
- [ ] Define the Provider Layer interface (`Crux::Providers::Base`) and implement the Mock Provider against it — deterministic canned responses per agent role, no external network call.
- [ ] Define a narrow `Crux::Agents::ContextAssembler` interface returning conversation-history-based context only; document the seam crx-005 will fill with real Knowledge Engine retrieval.
- [ ] Implement all 7 GA agents as `crux_agents` rows (configuration, not code) plus one shared `Crux::Agents::Runner` that assembles context, calls the Provider Layer, and routes output to either a direct chat reply (Conversation Engine) or new `crux_plan_steps` (Workflow Engine).
- [ ] Wire the Requirement Analyst → Planner hand-off: a `planned` conversation without an existing plan triggers Requirement Analyst (structures the request) then Planner (drafts `crux_execution_plans`/`crux_plan_steps`), replacing crx-003's stub generator for real conversations.
- [ ] Implement step dispatch on `executing`: `WorkflowEngine` (crx-003) invokes the plan step's authoring/executing agent via `Crux::Agents::Runner`, which produces a `crux_runs` row and, where the 3 Outcome tests from `billing.md` pass (fixed deliverable, approved, has a Run Ledger receipt), a `crux_outcomes` row.
- [ ] Async execution: every agent invocation runs as a background job (`Crux::Jobs::RunAgentJob`), consistent with `system_design.md`'s uniform-asynchronicity rule established in crx-002.
- [ ] Replace crx-001's dummy Agents-tab arrays (project and global) with real reads of `crux_agents`.
- [ ] Enforce per-agent Knowledge Engine/Provider Layer access strictly through the acting user's own permissions (Principle 6) — an agent's `crux_runs` row records `user_id` as the human on whose authority it ran, never the agent's own standing authority.

**Deliverables**:
- [ ] Migrations: `crux_agents`, `crux_runs`, `crux_outcomes`.
- [ ] Models: `Crux::Agent`, `Crux::Run`, `Crux::Outcome`.
- [ ] `Crux::Providers::Base` (interface) + `Crux::Providers::Mock` (implementation).
- [ ] `Crux::Agents::ContextAssembler` (conversation-history-only for this task).
- [ ] `Crux::Agents::Runner` (shared invocation path: assemble context → call provider → route output → write Run Ledger).
- [ ] `Crux::Jobs::RunAgentJob`.
- [ ] Seed data / migration-time inserts for the 7 GA `crux_agents` rows (`enabled: true`, `project_id: nil` = global default) plus the 5 Phase 2/3 agents inserted `enabled: false` so the full 12-row catalog exists from Phase 1 (per `agent_catalog.md`'s "agents are configuration, not code" — disabling, not omitting, is the correct Phase-1 posture for not-yet-active agents).
- [ ] `GlobalCruxAgentsController`/`ProjectCruxAgentsController` rewritten to read `crux_agents` instead of hardcoded arrays; enable/disable and model-assignment actions gated by `crux:manage_agents`.
- [ ] Attribution badges on chat messages and plan steps showing which agent authored them (`agent_catalog.md` UI Description).

**Out of Scope**: Real (non-Mock) providers — OpenAI/Anthropic/Gemini/Azure OpenAI/Ollama/Local Models (crx-006); real Knowledge Engine retrieval beyond conversation history (crx-005); the 5 Phase 2/3 agents' actual behavior (rows exist, disabled, no prompt/runtime work); Billing Engine dashboards/quota enforcement (outcomes are recorded, not yet metered against a plan tier); multi-agent hand-off chaining beyond the single fixed Requirement Analyst → Planner sequence.

---

## Specification

**Complexity**: HIGH

**Reason**: New migrations for 3 tables (including the Run Ledger, the single source of truth for audit/billing/analytics per `architecture.md`); introduces the first background-job-driven Core-adjacent execution path; touches both Administration and Project Workspace Agents tabs; establishes the Provider Layer interface every future provider (crx-006) and the Knowledge Engine (crx-005) plug into. HIGH per new migrations + architecture-defining interfaces.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_agents.rb` | create | `crux_agents(id, name, role, prompt_template, model, fallback_model, temperature, enabled, project_id)` per `database_design.md`; `project_id` nullable = global default. |
| `db/migrate/XXXX_create_crux_runs.rb` | create | `crux_runs(id, agent_id, plan_step_id, user_id, model, provider, prompt_ref, context_refs, tokens_in, tokens_out, cost, output_ref, created_at)`; `plan_step_id` nullable (direct chat replies aren't tied to a step); append-only — no update path defined anywhere in this spec. |
| `db/migrate/XXXX_create_crux_outcomes.rb` | create | `crux_outcomes(id, run_id, outcome_type, project_id, billed_at)`; `project_id` denormalized from the run's conversation per `database_design.md`'s accepted exception. |
| `app/models/crux/agent.rb` | create | `belongs_to :project, optional: true`; validates `role` against the 12 canonical roles (`agent_catalog.md`); `fallback_model` used on primary-model failure. |
| `app/models/crux/run.rb` | create | `belongs_to :agent`, `belongs_to :plan_step, optional: true`, `belongs_to :user`; no `update`/`destroy` exposed — enforced at the model layer (`before_update`/`before_destroy` raise), not just by convention, per `database_design.md`'s "append-only" design decision. |
| `app/models/crux/outcome.rb` | create | `belongs_to :run`; `outcome_type` populated only when `Crux::Agents::Runner` confirms all 3 Outcome tests from `billing.md` pass. |
| `app/lib/crux/providers/base.rb` | create | Abstract interface: `#call(prompt:, context:, agent:)` → `{content:, tokens_in:, tokens_out:}`. Every provider (Mock now, real ones in crx-006) implements exactly this. |
| `app/lib/crux/providers/mock.rb` | create | Deterministic canned responses keyed by agent role (e.g. Requirement Analyst returns a fixed structured-requirements shape, Planner returns the canonical 7-step CRM/HRMS plan shape) — enables fully repeatable QA without any external API key. |
| `app/services/crux/agents/context_assembler.rb` | create | `#assemble(conversation:, user:)` → returns project identity + bounded conversation history + detected intent/clarification answers (the first 3 of `chat_engine.md`'s 4 context layers); the 4th layer (permission-filtered knowledge) is an explicit `# TODO: crx-005` seam, documented, not silently omitted. |
| `app/services/crux/agents/runner.rb` | create | Shared invocation path for every agent: assemble context → resolve `agent.model`/`fallback_model` via the Provider Layer interface → call → on success, route output to a direct chat reply or new `crux_plan_steps` rows depending on agent role → write `crux_runs` (always) → write `crux_outcomes` (only if the 3 Outcome tests pass) → on failure, retry against `fallback_model` once, then record a failed `crux_runs` row and notify (reusing crx-003's `NotificationEmitter`). |
| `app/jobs/crux/run_agent_job.rb` | create | Background job wrapping `Runner` invocation, enqueued from `WorkflowEngine` (crx-003) on a step entering `executing`, and from `ChatEngine` (crx-002) once a conversation reaches `planned` with no existing plan (triggers Requirement Analyst → Planner). |
| `db/seeds/crux_agents_seed.rb` (or an idempotent migration-time insert) | create | Inserts the 12-row canonical catalog: 7 GA rows `enabled: true`, 5 Phase 2/3 rows (Security Agent, Code Reviewer, Product Owner Agent, Scrum Master Agent, Release Manager Agent) `enabled: false`, all `project_id: nil`. |
| `app/controllers/global_crux_agents_controller.rb` | modify | Replace the hardcoded `@agents` array with `Crux::Agent.where(project_id: nil)`; add enable/disable + model-assignment actions gated `crux:manage_agents`/`crux:administer`. |
| `app/controllers/project_crux_agents_controller.rb` | modify | Replace the hardcoded `@agents` array with the effective per-project set (project-scoped override row if present, else the global default row) per `crux_agents.project_id` nullable pattern; enable/disable gated `crux:manage_agents`. |
| `app/views/global_crux_agents/index.html.erb`, `app/views/project_crux_agents/index.html.erb` | modify | Render real data; show whether each agent is using the global default or a project-specific override (`agent_catalog.md` UI Description). |
| `app/views/project_crux_chat/_message.html.erb` (or equivalent partial extraction from crx-002's chat view) | modify | Add an attribution badge naming the authoring agent on `role: agent` messages. |
| `app/views/shared/_crux_approval_card.html.erb` (crx-003) | modify | Add an attribution badge naming the authoring agent per plan step. |

### Implementation Notes

- **The Mock Provider is not a testing shortcut invented for this task — it is one of the 7 canonical providers already named in `architecture.md`/`plugin_overview.md`/`glossary.md`.** Building against it first, then adding real adapters in crx-006 behind the same `Crux::Providers::Base` interface, is the intended use of that canonical provider, not a deviation from the doc set.
- **Knowledge Engine's absence is an explicit, documented seam, not a silent gap.** `Crux::Agents::ContextAssembler#assemble` is written now with the exact method signature crx-005 will extend (adding permission-filtered knowledge as a 4th input), so crx-005 modifies this one class rather than every agent's call site.
- **Requirement Analyst → Planner is the only hand-off wired in this task.** `agent_catalog.md`'s open question ("is a hand-off one Run Ledger row or a chain?") is resolved here, narrowly, as: two separate `crux_runs` rows, one per agent, both referencing the same `conversation_id` via their respective `plan_step_id`/direct-chat linkage — not a single merged row. This is flagged as a decision worth revisiting once Phase 2's Agent Collaboration (multiple simultaneous agents) makes the "chain" question load-bearing; for Phase 1's single fixed two-agent sequence, two independent rows are sufficient and simplest.
- **`crux_runs` is genuinely append-only at the model layer**, not just by team convention — `before_update`/`before_destroy` callbacks raise, so a future accidental `.update` call fails loudly in development rather than silently corrupting the audit trail.
- **Outcome materialization reuses `billing.md`'s 3-test definition exactly** (fixed deliverable type, human-approved, has a Run Ledger receipt) — `Runner` checks this after every successful run, but this task does not implement Billing Engine's quota enforcement or dashboards; `crux_outcomes` rows simply exist, unmetered, until a later task builds the Billing Engine proper.
- **Every agent invocation is asynchronous**, consistent with crx-002's established pattern — even Mock Provider calls, which are fast, go through `RunAgentJob` so the code path is identical once real (slower) providers land in crx-006.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Requirement Analyst → Planner hand-off | Conversation reaches `planned` (crx-002) with the canonical CRM prompt | Two `crux_runs` rows created (one per agent), plan steps match the canonical 7-step shape from `approval_engine.md` | pending |
| 2 | Fallback model on primary failure | Mock Provider configured to simulate a primary-model failure for one call | `Runner` retries against `agent.fallback_model`; the resulting `crux_runs.model` reflects the fallback, not the primary | pending |
| 3 | Outcome materialization — passes | A Documentation Agent run: fixed deliverable (wiki page), approved plan step, has a `crux_runs` receipt | `crux_outcomes` row created | pending |
| 4 | Outcome materialization — fails | A Requirement Analyst chat-only reply with no plan step and no approval | No `crux_outcomes` row created, even though `crux_runs` is written | pending |
| 5 | Append-only enforcement | Attempt to `.update` or `.destroy` an existing `crux_runs` row | Raises, does not silently succeed | pending |
| 6 | Disabled agent is not invoked | DevOps Agent set `enabled: false` on a project; a plan step assigned to it | `RunAgentJob` refuses to dispatch, records a failure/skip rather than silently running a disabled agent | pending |
| 7 | Project override vs. global default | A project sets a project-scoped `crux_agents` row overriding `model` for Planner | Project Agents tab shows the override; a different project with no override shows the global default | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end plan authoring | Send the canonical CRM prompt in Chat (crx-002) through to `planned` | Real `crux_execution_plans`/`crux_plan_steps` appear in Pending Actions (crx-003), authored by Requirement Analyst/Planner, not the crx-003 stub generator | pending |
| 2 | Approved step executes via an agent | Approve a "Generate Documentation" step | `RunAgentJob` dispatches Documentation Agent via Mock Provider; step → `completed`; attribution badge shows "Documentation Agent" | pending |
| 3 | Global vs. project Agents tab | Compare Administration → Agents and a project's Agents tab | Both read from `crux_agents`; enable/disable in one doesn't silently affect the other's scope inappropriately (global default vs. project override semantics hold) | pending |
| 4 | Chat attribution | Any agent chat reply | Message bubble shows the named agent, not "Crux" generically | pending |
| 5 | Full 12-row catalog present | Open Administration → Agents after this task ships | All 12 canonical agents listed; 7 enabled (GA), 5 disabled (Phase 2/3) | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Both primary and fallback model fail (simulated via Mock Provider) | `crux_runs` row recorded with a failure outcome; user notified with a clear retry option, per `system_design.md` Scenario 2 — UI does not hang indefinitely | pending |
| 2 | Agent disabled mid-run | An in-flight `RunAgentJob` for an agent that gets disabled after the job was enqueued but before it executes | Job checks `enabled` at execution time, not only at enqueue time; refuses to run if now disabled | pending |
| 3 | Two conversations, same project, same agent | Concurrent Planner invocations in two different conversations | Each produces its own independent `crux_execution_plans`/`crux_runs`; no cross-conversation state leakage | pending |
| 4 | Outcome test #2 (approval) not yet met | A Planner run produces plan steps, but the plan is still `awaiting_approval`, not yet approved | No `crux_outcomes` row is created prematurely — only after actual approval and execution | pending |
| 5 | Agent acting beyond the invoking user's permissions | A user without repository access triggers Developer Agent guidance on an issue referencing repository content | Per Principle 6, the agent's context/output is bounded by what *that user* could see — since Knowledge Engine isn't wired yet (crx-005), this task's `ContextAssembler` returns only conversation history, so this edge case degrades safely (no repository content leaks) rather than needing full enforcement yet; documented, not silently ignored | pending |

### QA Test Plan

**Scope**: Agent invocation, Provider Layer interface + Mock Provider, Requirement Analyst → Planner hand-off, Run Ledger recording (including append-only and Outcome materialization), and the Agents tab (project + admin) reading real data.

**Pre-conditions**:
- crx-001 (permissions/nav), crx-002 (chat), crx-003 (workflow/approval) are in place.
- The 12-row agent catalog is seeded, 7 enabled.

**QA Steps**:
1. Send the canonical CRM prompt; confirm Requirement Analyst then Planner produce a real plan (not the crx-003 stub) matching the canonical 7-step shape.
2. Approve the plan; confirm each step dispatches its responsible agent via Mock Provider and reaches `completed`.
3. Confirm `crux_runs` rows exist for every dispatch, and `crux_outcomes` rows exist only for steps that pass all 3 Outcome tests.
4. Attempt to disable DevOps Agent on a project mid-plan; confirm any not-yet-executed step assigned to it is handled per Edge Case #2.
5. Confirm Administration → Agents and the project Agents tab both show real data, with override semantics correct.
6. Attempt (via console/test harness, not UI) to update or destroy an existing `crux_runs` row; confirm it's refused.

**Expected Outcomes**:
- Every agent action, successful or failed, produces exactly one `crux_runs` row (or the documented fallback-retry pair).
- `crux_outcomes` exists only where `billing.md`'s 3 tests genuinely pass.
- No agent ever executes while `enabled: false`.

**Out of Scope**:
- Real provider responses (OpenAI/Anthropic/etc.) — Mock Provider only, until crx-006.
- Real knowledge-grounded output — until crx-005.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked treating "no real provider yet" as a reason to fabricate an ad hoc stub inside `Runner` itself, rather than using the already-canonical Mock Provider concept — this would create a throwaway code path crx-006 has to delete rather than extend. | Code Changes, `providers/mock.rb` row; Implementation Notes | Mock Provider is specified as a first-class, permanent implementation of `Providers::Base`, matching its documented status in `architecture.md`, not a disposable shim. |
| 2 | HIGH | `crux_runs` "append-only" was stated only as an Implementation Note in `database_design.md`'s own text, with no enforcement mechanism specified — leaving it as a convention risks exactly the drift `architecture.md` Risks calls out ("Run Ledger treated as one-of-many audit sources"). | Code Changes, `run.rb` row | Enforcement moved into the model layer (`before_update`/`before_destroy` raise), not left as a team convention. Test Unit #5 verifies it. |
| 3 | HIGH | Component sync gap: `agent_catalog.md` describes agent attribution badges on both chat messages and plan steps as a UI requirement, but neither crx-002's Chat view nor crx-003's Approval card originally accounted for an agent-authorship field. | Code Changes, message/approval-card view rows | Both views are explicitly modified in this task to add the badge, closing the gap before it becomes a cross-task inconsistency. |
| 4 | MEDIUM | The multi-agent hand-off row-cardinality open question (`agent_catalog.md`/`architecture.md`) needed an explicit answer for this task to be buildable at all, not left open. | Implementation Notes | Resolved narrowly (two independent `crux_runs` rows for the one fixed Requirement Analyst → Planner sequence), with an explicit flag that Phase 2 Agent Collaboration may need to revisit it. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An agent's `crux_runs.user_id` must record the human on whose authority it ran, not a synthetic "agent user" with its own standing permissions — otherwise Principle 6 (Secure by Construction) is violated the moment Knowledge Engine (crx-005) starts filtering by this field. | Code Changes, `run.rb`/`runner.rb` rows | `Runner` is specified to always carry and record the invoking human `user_id`; no agent-as-independent-actor path exists in this task. |
| 2 | HIGH | A disabled agent (`enabled: false`) must not be dispatchable via a queued job that was enqueued before it was disabled — a naive implementation checks `enabled` only at enqueue time. | Code Changes, `run_agent_job.rb` row; Test Case Edge #2 | `RunAgentJob` re-checks `enabled` at execution time, not only enqueue time. |
| 3 | MEDIUM | `crux_runs`/`crux_outcomes` need the composite indexes `database_design.md` Best Practices already specifies (`(project_id, created_at)` via the outcome's denormalized `project_id`, plus FK indexes on `agent_id`, `plan_step_id`, `user_id`, `run_id`) — an early draft's migrations didn't call these out. | Code Changes, migration rows | Indexing requirement added explicitly (see Best Practices carried into Code Changes intent — implementation must include them in the migration). |
| 4 | LOW | No secrets appear in `crux_runs.prompt_ref`/`context_refs` for this task since Mock Provider needs no API key — but the interface (`Providers::Base`) must not leak credentials into `prompt_ref` once crx-006 adds real providers with API keys. | Implementation Notes | `Providers::Base` interface reviewed to confirm it passes credentials only within the provider adapter's own scope, never into the logged `prompt_ref`/`context_refs` — flagged here for crx-006 to inherit. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — Mock Provider's permanence, append-only enforcement, attribution-badge view changes, hand-off row cardinality, human-authority `user_id` recording, execution-time enabled-check, and indexing requirements are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `.includes` for associations iterated in a view | Agents tab or Runs-adjacent views N+1 query `crux_agents`/`crux_runs` per row once real data exists | Not directly test-covered by a functional test in this task (data volume is low pre-crx-005/006); flagged here for implementation attention — `.includes(:agent)` required wherever runs are listed alongside their agent |
| 2 | Silent mass-assignment via a missing `permit` key | Model/fallback-model assignment on the Agents tab accepts an arbitrary `model` string without validating it against the Provider Layer's known model list | Not yet enforceable in full until crx-006 defines the real model list; flagged here so crx-006 adds the validation rather than assuming crx-004 already did |
| 3 | Race between two plan steps assigned to the same agent | Two `RunAgentJob`s for the same agent, same conversation, running concurrently | Yes — Edge Case #3 (two conversations/concurrent Planner invocations) |
| 4 | Outcome created before approval is actually recorded | A timing bug where `Runner` checks `plan.status` before `WorkflowEngine`'s own transition commits, materializing an outcome prematurely | Yes — Edge Case #4 |
| 5 | Fallback model masking a real failure silently | A run "succeeds" on fallback without any visible signal that the primary model failed, eroding trust in output quality per `agent_catalog.md` Risks ("fallback model drift") | Yes — Unit Test #2 confirms the fallback is recorded and observable in `crux_runs.model`, not silently hidden |

Verdict: Approved. Items #1 and #2 are implementation-time attention items rather than dedicated test cases in this task's scope, since realistic query volume and the real model list don't exist until crx-005/crx-006 land — both are carried forward explicitly rather than silently dropped.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
