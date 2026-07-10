## Metadata
- **Task ID**: crx-007-feature-agent-collaboration-engine
- **Title**: Agent Collaboration Engine + Security Agent + Code Reviewer (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `agent_catalog.md`, `architecture.md`, `database_design.md`, `future_scope.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Deliver Phase 2's flagship capability: more than one agent contributing to a single conversation. This task also gives the two Phase 2 GA agents — Security Agent and Code Reviewer — real, working configuration and output-routing behavior (crx-004 seeded both as `crux_agents` rows with `enabled: false`; this task is their first real activation). Critically, this task resolves the two open questions crx-004 explicitly deferred: whether an agent hand-off is one Run Ledger row or a chain (`architecture.md`/`agent_catalog.md`/`roadmap.md` Open Questions), and whether agent identity is a Redmine `User` subtype or a lighter `Member` record (`architecture.md`/`roadmap.md` Open Questions — `security.md` treats this as already-settled, a doc-set inconsistency this task's Implementation Notes calls out rather than silently picks a side on).

This task wires Security Agent and Code Reviewer through the Chat-Engine-invoked path only — a user references a diff/commit/dependency manifest already reachable via crx-005's Repository/Documents knowledge sources. It does **not** wire Code Reviewer's Integration-Engine-webhook invocation path or posting a review back to a real external GitHub PR — that extension belongs to crx-009 (Integration Engine + GitHub), which depends on this task for the agent itself already existing and working.

**Goal**:

Within one conversation, Planner can hand a drafted plan step to Code Reviewer for a second look before the user approves it; Security Agent can be opted into a project (disabled by default, per `agent_catalog.md`) and produce a risk finding routed to a remediation plan step. Every hand-off is fully traceable: given any run, its conversation and every other run in that same conversation (including direct chat-only replies) can be found in one query — closing a Run Ledger traceability gap that existed silently since crx-004.

**Objectives**:
- [ ] Add `crux_runs.conversation_id` (nullable FK) — every future run, including direct chat replies with no plan step, is now traceable to its conversation and project. Backfill existing rows where derivable via `plan_step_id → plan → conversation`.
- [ ] Add `crux_runs.parent_run_id` (nullable, self-referential FK) — the hand-off-chain column `database_design.md`'s own Future Enhancements section anticipated.
- [ ] Retroactively wire the Requirement Analyst → Planner sequence (crx-004) to set `parent_run_id`, without changing crx-004's approved two-independent-rows cardinality decision — only adding the missing edge between them.
- [ ] Enable Security Agent (opt-in, disabled by default) and Code Reviewer (enabled by default, per `agent_catalog.md` — no opt-in language for this agent) with real prompt templates, invoked from Chat Engine.
- [ ] Security Agent: scan Repository/Documents context for known risk patterns → findings with severity → a remediation `crux_plan_steps` row for approval.
- [ ] Code Reviewer: review a referenced diff/change → structured comments by severity → posted as an issue comment via a `crux_plan_steps` row (ordinary `crux:approve`, not destructive).
- [ ] Resolve agent-identity representation: no Core Platform identity row for agents at all (neither `User` nor `Member`) — attribution stays entirely within `crux_agents`/`crux_runs.agent_id`.
- [ ] Resolve hand-off cardinality: a hand-off is two (or more) independent, append-only `crux_runs` rows linked by `parent_run_id`, sharing `conversation_id` — never a merged/collapsed single row.

**Deliverables**:
- [ ] Migration: `crux_runs.conversation_id`, `crux_runs.parent_run_id` (+ indexes).
- [ ] Backfill migration/rake task for existing `crux_runs` rows' `conversation_id`.
- [ ] `Crux::Agents::Runner` (crx-004) modified: sets `conversation_id` on every run unconditionally; accepts an optional `parent_run:` to set `parent_run_id`.
- [ ] Real `prompt_template` + Code Changes for Security Agent and Code Reviewer, following the same `Crux::Agents::Runner`/`Providers::Base` invocation path every Phase 1 agent already uses — no new invocation mechanism.
- [ ] A "hand off to..." affordance in the Chat tab (crx-002) letting a user (or, for this task, the Planner's own output) address a specific next agent within the same conversation.
- [ ] Attribution badges (crx-004) extended to show a visual "chain" indicator when a message/plan step is a hand-off continuation of a prior run.
- [ ] `GlobalCruxAgentsController`/`ProjectCruxAgentsController` (crx-004): Security Agent shown disabled by default; Code Reviewer shown enabled by default.

**Out of Scope**: Code Reviewer's Integration-Engine-webhook invocation and posting to a real external GitHub PR (crx-009); true parallel/simultaneous multi-agent execution (fan-out/fan-in — Phase 4 Multi-Agent Workflows, crx-019); Security Agent continuous background scanning/CVE feed integration (`agent_catalog.md` Future Roadmap, unscheduled); Product Owner/Scrum Master/Release Manager agents (Phase 3); cross-project agent memory, agent-to-agent negotiation prior to plan submission (`agent_catalog.md` Future Enhancements, Phase 4-adjacent).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration on the append-only `crux_runs` table that every future Run Ledger consumer (crx-011 Billing, crx-012 Analytics, crx-019 Multi-Agent Workflows) inherits; resolves two architecture-defining open questions rather than deferring them again; introduces genuine cross-run concurrency-correctness surface. Matches the "new migrations + architecture-defining interfaces" criterion crx-004 used for its own HIGH rating.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_add_conversation_and_parent_to_crux_runs.rb` | create | Adds `conversation_id` (nullable FK → `crux_conversations`) and `parent_run_id` (nullable, self-referential FK → `crux_runs.id`) to `crux_runs`; indexes both. |
| `db/migrate/XXXX_backfill_crux_runs_conversation_id.rb` (or a rake task run once) | create | For every existing `crux_runs` row with a `plan_step_id`, derive and backfill `conversation_id` via `plan_step → plan → conversation`. Rows with no `plan_step_id` (direct chat replies) are left null — there is no way to derive their conversation retroactively if it wasn't recorded at write time; going forward, `Runner` always sets it. |
| `app/services/crux/agents/runner.rb` (crx-004) | modify | `#invoke(agent:, conversation:, user:, parent_run: nil, ...)` now always sets `crux_runs.conversation_id = conversation.id`; sets `parent_run_id = parent_run.id` when a hand-off caller supplies one. No other behavior changes — Mock/OpenAI provider calls, fallback/retry, and Outcome materialization (crx-004) are unmodified. |
| `app/services/crux/chat_engine.rb` (crx-002) | modify | Requirement Analyst → Planner sequence now passes the Requirement Analyst's completed run as `parent_run:` into the Planner's `Runner#invoke` call — the only change needed to retroactively wire this existing sequence into the new chain column. |
| `db/seeds/crux_agents_seed.rb` (crx-004) | modify | Flip `Code Reviewer.enabled` to `true` (global default); Security Agent stays `enabled: false` globally, with the per-project opt-in toggle (`crux:manage_agents`) now functional rather than inert. |
| `app/models/crux/agent.rb` (crx-004) | modify | Add `prompt_template` content for Security Agent (role: security reviewer; context: repository/dependency excerpts; constraint: severity taxonomy; output: finding + remediation plan step) and Code Reviewer (role: peer reviewer; context: diff/change + related issue; constraint: review checklist; output: comment list by severity) — structural sections only, per `agent_catalog.md`'s own Assumption that "Prompt Template means structural sections, not a stored literal string." |
| `app/views/project_crux_chat/index.html.erb` (crx-002) | modify | Add a "hand off to [agent]" affordance on an agent's message bubble, visible only for agents enabled on the project; selecting it enqueues a new `RunAgentJob` (crx-004) with `parent_run:` set to the current message's run. |
| `app/views/project_crux_chat/_message.html.erb`, `app/views/shared/_crux_approval_card.html.erb` (crx-004) | modify | Attribution badge grows a small chain indicator (e.g. "↳ continuing Requirement Analyst's run") when `parent_run_id` is present. |

### Implementation Notes

- **Hand-off chain resolution**: `parent_run_id` is set **only** when Agent B's invocation is directly caused by Agent A's prior output within the same conversation — Requirement Analyst → Planner is retroactively wired this way; Planner's plan step → Code Reviewer's review; Security Agent's finding → a remediation-authoring agent. Two agents independently replying to two unrelated user turns in the same conversation are **not** chained — they're linked only via the shared `conversation_id`. **Why sufficient now**: preserves crx-004's already-approved per-run billing independence (each run keeps its own tokens/cost/Outcome eligibility) while finally giving the ledger the parent-child edge the schema docs anticipated. **When to revisit**: a single `parent_run_id` models a tree (one parent per run), not a general DAG. Phase 4's Multi-Agent Workflows (crx-019) needs true N-hop chain reconstruction and adds `chain_root_run_id`/`chain_position` on top of this column rather than replacing it — flagged explicitly here so crx-019 isn't a surprise migration.
- **Agent identity — no Core Platform identity row.** Agents get neither a Redmine `User` row nor a `Member` row; they remain purely `crux_agents` configuration, with `crux_runs.agent_id` carrying all attribution. **Why**: crx-004's Gate 2 already established that `crux_runs.user_id` always records the human on whose authority a run executed, never a synthetic agent actor with standing permissions (Principle 6, Secure by Construction). A Redmine `User` row would necessarily carry its own role/permission set, directly undermining that precedent; a `Member` row still requires a backing `User` row underneath in Redmine's own data model, so it doesn't actually offer a lighter alternative — it relocates the same problem rather than avoiding it. Attribution badges (the actual UI requirement motivating this question) already work today via the `crux_agents` ↔ `crux_runs.agent_id` join, no Core Platform row needed. **Doc-set note**: `security.md` states "Agents are Users, not a special actor type" as a settled Design Decision, while `architecture.md`/`roadmap.md` still list this as an unresolved Open Question — this spec follows the reasoning above rather than either document's framing, and flags the inconsistency for a documentation fix outside this task. **When to revisit**: only if a future capability needs an agent to hold Redmine-recognized standing authority itself (e.g., direct `assigned_to` assignability, or its own MCP-server-side login for crx-022's Custom Agents) — not needed for Phase 2's actual use cases.
- **Sequential hand-off only, not true concurrency.** Agent Collaboration here means one agent's invocation completing before the next (in the same conversation) begins — not two agents computing at the same instant against the same conversation/plan. **Why sufficient now**: `roadmap.md`'s own worked example ("Planner and Code Reviewer collaborate... to review a pull request before an issue is closed") is inherently ordered; true parallel execution would require solving concurrent-write correctness on `crux_conversations`/`crux_execution_plans` state beyond what crx-003's atomic-transition guarantee covers for this case. **When to revisit**: Phase 4's "agents chaining work to one another" (crx-019) is the roadmap-named home for genuine fan-out/fan-in.
- **Security Agent and Code Reviewer reuse the existing invocation path with zero special-casing** — no new job type, no new controller action beyond the "hand off to" affordance. This matches `architecture.md`'s "no agent-side branching" spirit extended to agent *type*, not just provider.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | conversation_id set on every run | Any new agent invocation, with or without a plan step | `crux_runs.conversation_id` is always populated | pending |
| 2 | parent_run_id set on explicit hand-off | Planner hands off to Code Reviewer | New run's `parent_run_id` equals Planner's run id | pending |
| 3 | parent_run_id absent on independent turns | Two unrelated user turns in one conversation, each answered by a different agent | Neither run's `parent_run_id` is set; both share `conversation_id` | pending |
| 4 | Backfill migration correctness | Pre-existing `crux_runs` rows with a `plan_step_id` | `conversation_id` correctly derived and populated | pending |
| 5 | Security Agent disabled by default | New project enables Crux AI module | Security Agent shows `enabled: false`; Code Reviewer shows `enabled: true` | pending |
| 6 | Chain query performance | A conversation with 5 hand-off hops | All 5 runs retrievable via `conversation_id` in one query, no N+1 | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end hand-off | Planner drafts a plan; user clicks "hand off to Code Reviewer" on a plan step | Code Reviewer's review appears in-thread, attributed correctly, chain indicator shown | pending |
| 2 | Security Agent opt-in | Project admin enables Security Agent via `crux:manage_agents` | Agent becomes invokable from Chat; a repository-context question produces a findings + remediation plan step | pending |
| 3 | Runs tab shows full conversation history | Open Runs tab (crx-004 placeholder-turned-real by crx-004; this task adds conversation-scoped runs) for a conversation with hand-offs | All runs for that conversation are visible, including the direct-chat ones previously untraceable | pending |
| 4 | Requirement Analyst → Planner retroactive wiring | Send the canonical CRM prompt | Planner's run now shows `parent_run_id` = Requirement Analyst's run, without changing the plan's content/shape | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Hand-off to a disabled agent | User attempts to hand off to Security Agent on a project where it's disabled | Affordance is not shown (per `ui_design.md`'s "removed, not disabled" pattern already established) | pending |
| 2 | Hand-off across two conversations | Attempt (via a crafted request) to set `parent_run_id` to a run from a different conversation | Rejected at the model/service layer — a chain never spans conversations | pending |
| 3 | Deep or cyclic chain | Attempt to set `parent_run_id` to a run that is itself a descendant of the new run (cycle) | Rejected — `parent_run_id` must reference a run created strictly earlier | pending |
| 4 | Backfill on a run with no derivable conversation | A direct-chat run predating this task's `Runner` change | `conversation_id` stays null after backfill, not defaulted to a guess | pending |

### QA Test Plan

**Scope**: Multi-agent hand-off within one conversation, Run Ledger traceability (`conversation_id`/`parent_run_id`), Security Agent and Code Reviewer's first real invocation.

**Pre-conditions**: crx-001 through crx-006 in place; at least one project with Repository/Documents knowledge sources enabled (crx-005).

**QA Steps**:
1. Send the canonical CRM prompt; confirm Planner's run now carries `parent_run_id` pointing to Requirement Analyst's run.
2. On an approved plan step, click "hand off to Code Reviewer"; confirm a review appears, correctly attributed and chain-linked.
3. Enable Security Agent on a project; ask it about a dependency manifest; confirm a findings-based remediation plan step is created.
4. Query all runs for one conversation directly (via console/test harness); confirm every run — chat-only and plan-step-tied — is returned.

**Expected Outcomes**: No run is ever untraceable to its conversation going forward; hand-off chains are accurate and never cross conversations or cycle.

**Out of Scope**: Webhook-triggered Code Reviewer invocation (crx-009); true concurrent multi-agent execution (crx-019).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Without this task, `crux_runs` has no path from a direct-chat-reply run (no `plan_step_id`) back to its conversation/project at all — latent since crx-004, now load-bearing the moment Agent Collaboration needs "every agent that touched this conversation." | Code Changes, migration row | `conversation_id` added, always set going forward by `Runner`. |
| 2 | HIGH | The hand-off-cardinality open question (`architecture.md`/`agent_catalog.md`/`roadmap.md`) was left unresolved by crx-004 on purpose, explicitly flagged for this task — leaving it unresolved again would block every downstream task that needs to reason about multi-agent runs (crx-011 billing attribution, crx-012 analytics, crx-019 chaining). | Implementation Notes | Resolved: `parent_run_id`, narrow definition (direct causation only), explicitly flagged for crx-019's N-hop extension. |
| 3 | MEDIUM | The agent-identity question needed a real answer before Code Reviewer/Security Agent (and later, Custom Agents in crx-022) could be built confidently — leaving both documents' disagreement (`security.md` vs. `architecture.md`/`roadmap.md`) unaddressed risks two future tasks making incompatible assumptions. | Implementation Notes | Resolved: no Core Platform identity row; doc-set inconsistency flagged explicitly for a separate documentation fix. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | A hand-off chain must never span two different conversations or projects — a naive `parent_run_id` FK with no validation would let a crafted request link runs across projects, potentially exposing one project's agent activity chain to another. | Test Case Edge #2 | Explicit validation: `parent_run_id` must belong to a run in the same `conversation_id`. |
| 2 | MEDIUM | A cyclic or self-referential `parent_run_id` chain could cause infinite loops in any future chain-reconstruction UI (crx-019). | Test Case Edge #3 | Validated at the model layer: parent must be strictly earlier (by `created_at`/id ordering). |
| 3 | MEDIUM | `crux_runs.conversation_id`/`parent_run_id` need indexes given they're immediately queried for chain reconstruction and Runs-tab display — an unindexed FK here repeats the exact risk `database_design.md` already flags generally. | Code Changes, migration row | Both columns indexed explicitly. |
| 4 | LOW | Enabling Code Reviewer by default (unlike Security Agent) needs to be a deliberate, documented choice, not an accidental asymmetry a future reviewer might "fix" by disabling it. | Implementation Notes / seed row | `agent_catalog.md`'s own text ("disabled by default until a project opts in" — for Security Agent only) is cited as the basis for the asymmetry. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — `conversation_id`, `parent_run_id` with cross-conversation/cycle validation, required indexes, and the Code-Reviewer-vs-Security-Agent enablement asymmetry are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `permit` key on nested params | The "hand off to" affordance's POST accepts an arbitrary `parent_run_id` from the client instead of deriving it server-side from the current message context | Yes — Edge Case #2 (cross-conversation validation catches the class of bug, not just the specific attack) |
| 2 | Backfill migration silently guesses | The backfill migration defaults `conversation_id` to some "best guess" for undeliverable rows instead of leaving them null | Yes — Edge Case #4 |
| 3 | N+1 query reconstructing a chain | A conversation with many hand-offs queries each run's parent individually instead of loading the whole chain in one indexed query | Yes — Unit Test #6 |
| 4 | Agent enablement asymmetry mistaken for a bug | A future contributor "fixes" Code Reviewer's default-enabled state to match Security Agent's default-disabled state, not realizing they're deliberately different per `agent_catalog.md` | Not directly test-covered (a code-review-time attention item); flagged in Implementation Notes with an explicit doc citation so it isn't silently "corrected" |

Verdict: Approved. Item #4 is a code-review-time attention item rather than an automated test, since it's about developer intent, not observable runtime behavior — the explicit doc citation in Implementation Notes is the safeguard.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
