## Metadata
- **Task ID**: crx-024-feature-tool-registry-permissions
- **Title**: Tool Registry & Per-Agent Allowed Tools (Phase 4 — foundation)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `architecture.md`, `security.md`, `database_design.md`, `billing.md`, and existing `crx-004`/`crx-005`/`crx-009`/`crx-021`/`crx-022` specs — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set and existing specs — flagged per the note above)*

**Description**:

Introduces the Tool Registry — an extensible, admin-visible catalog of write-capable and native read-capable actions an agent may invoke mid-run, and a per-agent allow-list restricting which tools a specific `crux_agents` row (catalog or custom) may call. This directly closes the gap between the SEO-Agent-style authoring form (name, description, model, instructions, **allowed tools**, knowledge sources) and what crx-022 currently builds (which has no tool-scoping concept at all). This task ships **zero concrete tools** — `crux_tools` is empty at ship time. It is infrastructure crx-026 (Developer Agent Git Workflow) becomes the first real tenant of, the same relationship crx-004's `Providers::Base` interface has to crx-006's real provider adapters.

This task wraps crx-021's existing MCP outbound tool-calling loop rather than reopening it: `Crux::Mcp::Client` (crx-021) is untouched; a new `Crux::Tools::Dispatcher` becomes the single front door `Crux::Agents::Runner`'s tool-calling loop calls, routing to either a newly-registered native tool or, unchanged, to `Crux::Mcp::Client` for MCP-server-declared tools — closing a real gap crx-021 left open (today every configured MCP server's every tool is available to every run with no per-agent restriction at all).

Knowledge retrieval (crx-005) is explicitly **not** folded into this registry — that is the deliberate, load-bearing boundary with the parallel crx-025 task (Agent Knowledge Scope). Knowledge assembly is structurally mandatory pre-model-call (every run's 4th context layer); a tool call is model-initiated and optional mid-run. Collapsing the two would demote Knowledge Engine's "the model never sees anything the user can't" guarantee from structural to probabilistic — a regression against Principle 6 this task will not introduce.

**Goal**:

An administrator sees a global Tool catalog (initially empty); a user with `crux:author_agents`/`crux:manage_agents` on a Team/Enterprise org can grant a specific agent access to specific registered tools via an "Allowed Tools" checklist on the agent authoring/edit form; an agent's tool-calling loop (crx-021) can only reach tools it's been explicitly granted (default-deny); read-only tools execute inline; write-capable tools always produce an ordinary `crux_plan_steps` row for approval, with no code path that lets a write-capable tool execute without one.

**Objectives**:
- [ ] Add `crux_tools` (global catalog: key, name, description, category, source, requires_approval, integration_provider, enabled) and `crux_agent_tools` (per-agent allow-list, default-deny join table).
- [ ] Define `Crux::Tools::Base` — a class-level `requires_approval?` contract deciding read-only (`#call`) vs. write-capable (`#propose`/`#execute`) structurally, not per-call or per-invocation.
- [ ] Define `Crux::Tools::Registry` (register/find/all/sync catalog rows) and `Crux::Tools::Dispatcher` (the single enforcement point: catalog-enabled → per-agent-allowed → integration-configured → dispatch).
- [ ] Modify `Crux::Agents::Runner`'s tool-calling loop (crx-021) to call `Dispatcher#dispatch` instead of `Crux::Mcp::Client` directly; `Dispatcher` delegates to `Crux::Mcp::Client` unchanged for `source: mcp_server` tools, now gated by the same allow-list.
- [ ] Wire `WorkflowEngine` (crx-003) to accept a tool's `#propose` output as an ordinary plan-step source, and to call `Dispatcher#execute_approved!` on a tool-authored step's `executing` transition — no new state, no new transition type.
- [ ] Add an "Allowed Tools" checklist to crx-022's agent authoring form and the existing catalog-agent edit view, gated `crux:author_agents`/`crux:manage_agents` + a Team/Enterprise tier check (crx-011's `TierPolicy`).
- [ ] Confirm zero touch points to `crux_knowledge_sources`, `Crux::Agents::ContextAssembler`, or `Crux::Knowledge::Retriever`/`Ranker` — that surface belongs entirely to the parallel crx-025 task.

**Deliverables**:
- [ ] Migrations: `crux_tools`, `crux_agent_tools`.
- [ ] Models: `Crux::Tool`, `Crux::AgentTool`.
- [ ] `Crux::Tools::Base` (interface), `Crux::Tools::Registry`, `Crux::Tools::Dispatcher`.
- [ ] `Crux::Agents::Runner` (crx-021) modified: dispatch target changed from `Crux::Mcp::Client` to `Crux::Tools::Dispatcher`.
- [ ] `Crux::Agents::Author` (crx-022) modified: accepts and persists an Allowed Tools selection at custom-agent creation, validated against already-enabled/already-configured tools only.
- [ ] `Crux::Billing::TierPolicy` (crx-011) modified: Allowed Tools assignment gated Team/Enterprise, for catalog and custom agents alike.
- [ ] Shared "Allowed Tools" view partial, reused by both the custom-agent authoring form and the catalog-agent edit view.
- [ ] A global Tool catalog Administration page (list, global enable/disable toggle), gated `crux:administer`.

**Out of Scope**: Any concrete tool implementation (GitHub/git operations are crx-026's job; this task's catalog ships empty); per-agent knowledge-source scoping (crx-025, entirely separate table and UI section); third-party/marketplace tool listings (`future_scope.md`'s connector-vetting question, unresolved, same reasoning crx-023 already applied to connector distribution); per-tool-call analytics beyond the existing `crux_runs.tool_calls_ref` reference log (crx-021's established pattern, not re-opened here); a new Redmine permission (deliberately reuses `crux:author_agents`/`crux:manage_agents`, argued below).

---

## Specification

**Complexity**: HIGH

**Reason**: Introduces the codebase's second architecture-defining interface (`Crux::Tools::Base`, alongside `Crux::Providers::Base`) with two new migrations; extends crx-021's already-HIGH-rated tool-calling loop with a mandatory permission-enforcement layer; is the structural foundation a later HIGH task (crx-026) builds directly on top of; and must guarantee — structurally, not by convention — that a write-capable tool can never execute inline, the same class of "non-negotiable ordering" risk `architecture.md` names for Knowledge Engine's filter-before-rank. Matches the new-migrations + security-changes + architecture-defining-interface criteria this project's other HIGH tasks were rated on.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_tools.rb` | create | `crux_tools(id, tool_key, name, description, category, source [native\|mcp_server], requires_approval, integration_provider, enabled, created_at, updated_at)`; unique index on `tool_key`. |
| `db/migrate/XXXX_create_crux_agent_tools.rb` | create | `crux_agent_tools(id, agent_id, tool_id, created_at)`; unique index `(agent_id, tool_id)`; FK indexes on both columns. |
| `app/models/crux/tool.rb` | create | `has_many :agent_tools`; validates `tool_key` uniqueness; consistency-checked against `Crux::Tools::Registry` at sync time. |
| `app/models/crux/agent_tool.rb` | create | Join model; `belongs_to :agent`, `belongs_to :tool`; enforces the unique-pair constraint at the model layer too, not just the DB index. |
| `app/models/crux/agent.rb` (crx-004/crx-022) | modify | `has_many :agent_tools`, `has_many :tools, through: :agent_tools`. |
| `app/lib/crux/tools/base.rb` | create | Abstract interface: `.tool_key`, `.category`, `.requires_approval?`, `#input_schema`, `#call(input:, user:, project:, agent:, run:)` (read-only path), `#propose(input:, user:, project:, agent:, run:)` → plan-step-shaped hash (write-capable path), `#execute(plan_step:, user:)` (the only place a write-capable tool's real side effect happens, called exclusively post-approval). |
| `app/lib/crux/tools/registry.rb` | create | `.register(tool_class)`, `.all`, `.find(tool_key)`, `.sync_to_db!` (idempotent upsert into `crux_tools`, consistency-checks every registered `tool_key` has a matching row), `.schemas_for(agent:)` (native-tool schemas to surface to the model, alongside whatever crx-021 already surfaces for MCP-declared tools). |
| `app/services/crux/tools/dispatcher.rb` | create | `#dispatch(tool_name:, arguments:, agent:, user:, project:, run:)` — resolves via `Registry` (native) or falls through to `Crux::Mcp::Client` (crx-021, unmodified) for `source: mcp_server`; enforces `crux_tools.enabled` → `crux_agent_tools` membership (default-deny) → integration-configured (if `integration_provider` set) → routes to `#call` or `#propose` per `requires_approval?`. `#execute_approved!(plan_step:)` — called by `WorkflowEngine` on a tool-authored step's `executing` transition; resolves the tool from the step's payload and calls `#execute`. |
| `app/services/crux/agents/runner.rb` (crx-021) | modify | Tool-calling loop's dispatch target changes from `Crux::Mcp::Client` directly to `Crux::Tools::Dispatcher#dispatch`; the max-tool-calls bound (crx-021) applies uniformly regardless of tool source. |
| `app/services/crux/workflow_engine.rb` (crx-003) | modify | Accepts a tool's `#propose` payload as an ordinary plan-step source (no new state, no new transition); on a tool-authored step's `approved → executing` transition, calls `Crux::Tools::Dispatcher#execute_approved!` instead of (or alongside) an agent-authored step's existing dispatch. |
| `app/services/crux/agents/author.rb` (crx-022) | modify | Accepts and persists an Allowed Tools selection at custom-agent creation, validated against catalog-enabled + already-configured integrations only (no self-provisioning). |
| `app/services/crux/billing/tier_policy.rb` (crx-011) | modify | Add a check: assigning/editing an agent's Allowed Tools requires Team/Enterprise, for catalog and custom agents alike. |
| `app/controllers/project_crux_agents_controller.rb` / `global_crux_agents_controller.rb` (crx-004) | modify | Add an Allowed Tools assignment action, gated `crux:manage_agents` + tier check. |
| `app/controllers/global_crux_tools_controller.rb` | create | Admin catalog list + global enable/disable toggle, gated `crux:administer`. |
| `app/views/shared/_crux_allowed_tools.html.erb` | create | Checklist grouped by category; Read-only/Requires-approval badges; disabled-with-inline-explanation rows for tools whose `integration_provider` isn't yet configured for the project — reusing the established "disabled with explanation, not hidden" convention (crx-003's destructive-row pattern, crx-006/crx-011's tier-gated actions). |
| `app/views/global_crux_tools/index.html.erb` | create | Global tool catalog admin page. |

### Implementation Notes

- **Knowledge Engine is not folded into the Tool Registry; it stays crx-004/crx-005's separate, always-on 4th context layer.** Knowledge assembly is structurally mandatory pre-model-call; tool calls are model-initiated and optional mid-run. Converting knowledge access into a tool would demote a structural guarantee ("the model never sees anything the user can't") into a probabilistic one ("the model happened to call the knowledge tool this turn"). **Why sufficient now**: this task's actual need (native, write-capable, per-agent-restrictable actions) is fully met without touching Knowledge Engine at all. **When to revisit**: only if a future requirement needs the model to *actively choose* whether to retrieve knowledge — a materially different product decision, not an implementation detail, and not indicated anywhere in the current doc set.
- **`Crux::Tools::Dispatcher` wraps crx-021's MCP loop via a new front door rather than modifying `Crux::Mcp::Client`.** `Crux::Mcp::Client`'s own approved spec (crx-021) is preserved unchanged; `Dispatcher` adds the allow-list crx-021 never needed until native tools existed. **Why sufficient now**: crx-021's own governance ("outbound tool calls are not individually approval-gated... they don't write to Redmine") still holds for MCP-declared read tools; this task doesn't reopen that decision, it adds a permission gate in front of it. **When to revisit**: never expected — this is a permanent architectural layering, not an interim one.
- **Per-agent allow-listing is a join table (`crux_agent_tools`), default-deny, not a JSON column on `crux_agents`.** Matches the codebase's existing preference for relational toggle tables (`crux_knowledge_sources`) over blob columns, and joins cleanly against `crux_tools.enabled`. **Why sufficient now**: no agent, catalog or custom, gets any tool by default — crx-024 ships the mechanism and an empty catalog, not any grants; a future task (crx-026) is responsible for its own grants. **When to revisit**: only if a future grant needs its own per-agent-per-tool configuration (e.g., scoping a git tool to specific repos) — the join table gains columns then, rather than being retrofitted from a JSON blob.
- **No new permission is introduced; `crux:author_agents` (creation) and `crux:manage_agents` (post-creation edits) absorb tool-assignment, plus the existing Team/Enterprise tier gate.** Tool assignment doesn't cross the "materially higher trust" bar crx-022 used to justify its own new permission — a tool always executes under the invoking human's own authority, never elevated (crx-004's `user_id`-is-always-human rule, unmodified and directly inherited; crx-007's ruling that agents get no Core Platform identity row applies here too — a tool has no standing authority of its own either). **Why sufficient now**: assigning a tool is the same class of action as reassigning a model/temperature, which `crux:manage_agents` already governs. **When to revisit**: only if a future tool category is powerful enough that even *reassigning* it needs independent sign-off distinct from ordinary agent management — not indicated by anything built so far.
- **Write-capable tools use a two-phase `#propose`/`#execute` contract with no `#call` implementation at all**, so a write-capable tool physically cannot execute inline — a coding mistake raises `NotImplementedError` in development rather than silently performing an unapproved write. **Why sufficient now**: reuses crx-003's approval gate completely unmodified, no special-casing for tool-authored vs. agent-authored steps. **When to revisit**: only if a future tool needs to propose multiple steps atomically as one unit — that would reopen `architecture.md`'s Open Question #3 (plan-step granularity), not something this task decides unilaterally.
- **`tool_key` is deliberately open-ended (not a fixed enum)**, unlike `crux_agents.role` (12 fixed values), `crux_knowledge_sources.source_type` (11 fixed values), or `crux_integrations.provider` (12 fixed values) — this is the codebase's first genuinely extensible catalog, matching this task's role as a foundation future tasks add to. A naming convention (`provider.action`, e.g. `github.create_pull_request`) is recommended to prevent future `tool_key` collisions across independently-developed tasks, though not itself enforced at the schema level beyond uniqueness.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Default-deny enforcement | An agent with no `crux_agent_tools` row for a given tool attempts to call it | `Dispatcher` refuses; denial folded into context as a normal untrusted-input response, not a crash | pending |
| 2 | Read-only tool executes inline | An agent calls a `requires_approval: false` tool it's allowed to use | `#call` executes immediately; response folded into context; `crux_runs.tool_calls_ref` records the call | pending |
| 3 | Write-capable tool never executes inline | An agent calls a `requires_approval: true` tool it's allowed to use | `#propose` is invoked, producing an `awaiting_approval` `crux_plan_steps` row; `#call`/`#execute` are never reached during this turn | pending |
| 4 | Structural guard against a mis-implemented tool | A test tool overrides `#call` on a class where `requires_approval? == true` | Calling it via the write path still routes through `#propose`; if code mistakenly invokes `#call` directly, `Base`'s default raises `NotImplementedError` | pending |
| 5 | Integration-not-configured disables a tool | An agent is granted a tool whose `integration_provider` has no enabled `crux_integrations` row for the project | Dispatch refuses with a clear reason; the UI shows the checkbox disabled with inline explanation | pending |
| 6 | MCP fallback unaffected by allow-list absence for native tools | An agent calls an MCP-server-declared tool it's allowed to use, no native tools involved | Routes to `Crux::Mcp::Client` (crx-021) unchanged, now additionally gated by the same allow-list check | pending |
| 7 | Tier gate on tool assignment | A Starter-tier org attempts to grant an agent a tool | Refused with a "requires Team" message, reusing crx-011's `TierPolicy` | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Allowed Tools checklist on agent authoring form | Author a custom agent (crx-022), select tools from the (initially empty, then test-seeded) catalog | Selections persist to `crux_agent_tools` | pending |
| 2 | Global tool catalog admin page | Administration → Tools | Lists all `crux_tools` rows, global enable/disable toggle works | pending |
| 3 | End-to-end write-capable tool approval | A test write-capable tool proposes a step; a user approves it | `Dispatcher#execute_approved!` calls `#execute`; the real side effect occurs only after approval | pending |
| 4 | Catalog vs. custom agent parity | Grant the same tool to a catalog agent and a custom agent | Both behave identically — no special-casing based on `origin` | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Unknown `tool_key` requested by the model | The model hallucinates a tool name not in the registry | `Dispatcher` returns a clear "unknown tool" denial folded into context; loop continues (bounded by crx-021's max-tool-calls limit), never a crash | pending |
| 2 | Tool globally disabled mid-run | `crux_tools.enabled` flipped false between enqueue and dispatch | Dispatch checks `enabled` at dispatch time, not only at agent-authoring time — mirrors crx-004's "enabled checked at execution time, not enqueue time" precedent | pending |
| 3 | Agent's tool grant revoked mid-conversation | A `crux_agent_tools` row is deleted between two turns of the same conversation | The next tool-call attempt in that conversation is refused, consistent with default-deny being re-checked every dispatch, not cached | pending |
| 4 | Two agents, same tool, different projects | Agent A (Project X) and Agent B (Project Y) both hold the same tool grant | Each dispatch is independently scoped — no cross-project bleed via a shared `crux_tools` catalog row | pending |

### QA Test Plan

**Scope**: Tool Registry mechanics (registration, catalog, allow-list, dispatch), the structural read/write split, and the Allowed Tools UI — using test/stub tool classes since no concrete tool ships in this task.

**Pre-conditions**: crx-001 through crx-023 in place; at least one test tool registered (read-only) and one test tool registered (write-capable) for QA purposes only, not shipped to production.

**QA Steps**:
1. Grant a test read-only tool to an agent; invoke it; confirm inline execution and context folding.
2. Grant a test write-capable tool to an agent; invoke it; confirm a plan step is created, never an inline execution.
3. Approve that plan step; confirm `#execute` runs only now.
4. Revoke the grant; confirm the next call attempt is refused.
5. Disable the tool globally; confirm dispatch is refused even for an agent still holding a grant.
6. Confirm the Allowed Tools checklist correctly disables (with explanation) a tool whose integration isn't configured.

**Expected Outcomes**: No write-capable tool ever executes without an approved plan step; default-deny holds at every dispatch, not just at grant time.

**Out of Scope**: Any concrete tool's actual external-system behavior (crx-026 and later tasks).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked `Dispatcher` duplicating MCP-calling logic instead of genuinely wrapping `Crux::Mcp::Client` — this would create two parallel tool-invocation code paths to keep in sync. | Code Changes, `dispatcher.rb` row; Implementation Notes | `Dispatcher` explicitly delegates to `Crux::Mcp::Client` unchanged for `source: mcp_server` tools; no duplicated calling logic. |
| 2 | HIGH | Knowledge Engine risked being folded into the Tool Registry for "consistency," which would demote its structural permission guarantee to a probabilistic, model-initiated one. | Implementation Notes | Explicitly kept separate; crx-025 owns knowledge scoping entirely, with zero schema/code overlap confirmed. |
| 3 | MEDIUM | Without a naming convention, two independently-developed future tasks could collide on the same `tool_key`. | Implementation Notes | `tool_key` uniqueness enforced at the DB/model layer; a `provider.action` naming convention recommended (not enforced) to reduce collision risk. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The single highest-stakes risk in this task: a write-capable tool executing inline (bypassing the approval gate) due to a coding mistake or a missing check. | Code Changes, `base.rb`/`dispatcher.rb` rows; Test Case Unit #3/#4 | Structural prevention: write-capable tools never implement `#call`; `Dispatcher` routes strictly by `requires_approval?`; directly tested. |
| 2 | HIGH | `#execute` must be reachable only after `WorkflowEngine`'s approval transition — no direct call path from `Dispatcher`/`Runner` mid-run. | Code Changes, `workflow_engine.rb` row; Test Case Unit #3 | `#execute` is called exclusively from `execute_approved!`, itself called only by `WorkflowEngine` on the `executing` transition. |
| 3 | HIGH | A tool's `enabled` and per-agent grant state must be checked fresh at dispatch time, not cached from an earlier point (grant time or enqueue time) — a stale check could let a revoked/disabled tool still run. | Test Case Edge #2/#3 | Explicitly checked at dispatch time; directly tested for both the global-disable and per-agent-revocation cases. |
| 4 | MEDIUM | Integration-backed tools must not allow self-provisioning of a new connector — only already-`crux:manage_integrations`-configured integrations are selectable. | Test Case Unit #5 | Explicitly restricted, reusing crx-022's established self-provisioning restriction for providers/MCP servers. |
| 5 | LOW | Required indexes (`tool_key` uniqueness, `(agent_id, tool_id)` uniqueness) must exist given this is a permission-check path hit on every tool call. | Code Changes, migration rows | Explicitly specified. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — `Dispatcher`'s genuine wrapping (not duplication) of `Crux::Mcp::Client`, Knowledge Engine's untouched separation, the structural `#propose`/`#execute` write-path guard, dispatch-time (not cached) enablement/grant checks, and no-self-provisioning are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Silent fallback masking a real error | `Dispatcher` silently falls through to the MCP path on a native `tool_key` typo instead of raising/denying clearly | Yes — Edge Case #1 |
| 2 | Missing `.includes` for associations iterated in a view | The Allowed Tools checklist or global catalog page N+1 queries `crux_agent_tools`/`crux_tools` per row across many agents | Not directly test-covered (low catalog size at ship time — zero concrete tools); flagged for implementation attention as the catalog grows |
| 3 | A future tool author overrides `#call` on a write-capable tool | A well-intentioned but incorrect tool implementation adds `#call` alongside `#propose`/`#execute`, creating an accidental inline-execution path for a write-capable tool | Yes — Unit Test #4 (structural guard) |
| 4 | Enabled-check performed only at grant time | Per-agent grant or global enablement treated as "checked once, cached" rather than re-verified every dispatch | Yes — Edge Case #2/#3 |

Verdict: Approved. Item #2 is an implementation-time attention item rather than a dedicated test, since the catalog ships empty and realistic scale isn't reachable until crx-026 and later tasks populate it.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
