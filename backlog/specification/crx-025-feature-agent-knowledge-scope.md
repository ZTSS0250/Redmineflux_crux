## Metadata
- **Task ID**: crx-025-feature-agent-knowledge-scope
- **Title**: Agent Knowledge Scope — per-agent knowledge-source restriction (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `knowledge_engine.md`, `security.md`, `chat_engine.md`, `database_design.md`, and existing `crx-004`/`crx-005`/`crx-022` specs — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set and existing specs — flagged per the note above)*

**Description**:

Extends crx-005's Knowledge Engine from project-level-only source enablement to a second, per-agent scoping dimension. Today `crux_knowledge_sources` enables Wiki/Issues/Repository/etc. for an entire project, shared uniformly by every agent active in it — there is no way to say "SEO Agent may see Wiki and Documents, but never Issues, even though Issues is enabled project-wide and every other agent in this project can see it." This task adds that missing per-agent dimension without touching `Crux::Knowledge::PermissionFilter` or `Ranker` — the two components crx-005's own Gate 2 review named as the single most security-critical code in the product.

This task explicitly does **not** cover tool/write-action permissions — that is the parallel crx-024 task's domain. The dividing line: Knowledge Engine governs Redmine-native *reads* feeding an agent's context (crx-025's domain); Workflow Engine already governs Redmine-native *writes* (unrelated to either task); the Tool Registry governs external-system actions (crx-024's domain). "Search the wiki" is always a knowledge-source read under this task, never a tool under crx-024's, even when an agent's own prompt phrasing suggests otherwise — treating it as a tool would create a second, weaker-permissioned access path to content crx-005 already governs correctly.

**Goal**:

An agent's *effective* knowledge set for any given run is the three-way intersection of what the acting user is permitted to see (Redmine ACL, unchanged), what the project has enabled (crx-005, unchanged), and what that specific agent has been granted (new, this task) — never wider than any one of the three. A newly authored custom agent defaults to zero enabled sources; catalog agents are seeded from `agent_catalog.md`'s already-documented per-agent source affinities where stated.

**Objectives**:
- [ ] Add `crux_agent_knowledge_sources(id, agent_id, source_type, enabled)` — the same `(scope_id, source_type, enabled)` shape crx-005 already established for the project dimension, reusing the identical 11-value canonical source-type list.
- [ ] Extract the 11-value canonical source-type validation into one shared constant referenced by both `Crux::KnowledgeSource` (crx-005) and the new `Crux::AgentKnowledgeSource`, preventing the two tables' notion of "valid source type" from drifting apart.
- [ ] Extend `Crux::Knowledge::Retriever#candidates` with a config-only `agent_allowed_types` read, ANDed into the existing `project_enabled_types` computation **before** `PermissionFilter` is called — never after, never in place of it.
- [ ] Make `Crux::Agents::ContextAssembler#assemble`'s `agent:` parameter **explicit and required** (currently implicitly inferable from `conversation.agent_id`, which breaks the moment one conversation involves more than one agent — already true today via the Requirement Analyst → Planner hand-off, crx-004).
- [ ] Seed the 12 catalog agents' knowledge scope from `agent_catalog.md`'s documented Tools-column affinities where stated; default all-disabled where the catalog doesn't commit to a specific source list.
- [ ] Default new custom agents (crx-022) to zero sources enabled; require explicit per-agent opt-in.
- [ ] Add a "Knowledge Sources" checkbox section to crx-022's agent authoring form and the existing catalog-agent edit view (crx-004), visually and functionally separate from crx-024's "Allowed Tools" section on the same form.

**Deliverables**:
- [ ] Migration: `crux_agent_knowledge_sources` (with a backfill step inserting all 11 rows for every existing `crux_agents` row per the default rules above).
- [ ] Model: `Crux::AgentKnowledgeSource`.
- [ ] Shared canonical source-type constant, referenced by `Crux::KnowledgeSource` (crx-005) and `Crux::AgentKnowledgeSource`.
- [ ] `Crux::Knowledge::Retriever` (crx-005) modified: `#candidates(user:, project:, query:, agent:)`.
- [ ] `Crux::Agents::ContextAssembler` (crx-004) modified: `#assemble(conversation:, user:, agent:)`.
- [ ] `Crux::Agents::Runner` (crx-004) modified: passes the specific agent about to be invoked explicitly into `ContextAssembler#assemble`.
- [ ] `Crux::Agents::Author` (crx-022) modified: creates the new agent's 11 `crux_agent_knowledge_sources` rows at authoring time from the submitted checkboxes (default unchecked).
- [ ] `db/seeds/crux_agents_seed.rb` (crx-004) modified: seeds the 12 catalog agents' rows per `agent_catalog.md`'s documented affinities.
- [ ] Updated agent authoring/edit views: "Knowledge Sources" checkbox section, 11 sources, same order as crx-005's Knowledge tab.

**Out of Scope**: Any tool/write-action permission concept (crx-024, entirely separate table and code path); RAG/vector-store semantic retrieval (`knowledge_engine.md` Future Enhancements, unchanged — crx-018 already deferred this for Phase 3, this task doesn't reopen it); organization-wide (cross-project) knowledge scoping (`future_scope.md`); any change to `PermissionFilter` or `Ranker`'s own internal logic (zero lines changed in either).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration; touches the single most security-critical data-access path in the product (any bug threading the new `agent:` parameter through `Retriever`/`ContextAssembler` risks the exact silent-data-leak class crx-005's Gate 2 called non-negotiable, even though the net-new logic is "just" one more AND-intersection — crx-018 used identical reasoning to justify its own HIGH rating despite smaller net-new code than crx-005's original build); spans two existing UI surfaces (crx-022's authoring form, crx-004's Agent Settings edit view) that must stay in sync; requires explicit schema/vocabulary coordination with the parallel crx-024 task to avoid duplicate registries. Matches the security-sensitivity + cross-module-impact criteria.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_agent_knowledge_sources.rb` | create | `crux_agent_knowledge_sources(id, agent_id, source_type, enabled)`; unique index `(agent_id, source_type)`; index on `agent_id`; backfills all 11 rows for every existing `crux_agents` row per the default rules in Implementation Notes. |
| `app/models/crux/agent_knowledge_source.rb` | create | `belongs_to :agent`; validates `source_type` against the shared canonical constant (next row), not a re-declared list. |
| `app/models/crux/knowledge_source.rb` (crx-005) | modify | Extract the 11-value canonical list into a shared constant/module (`Crux::Knowledge::CANONICAL_SOURCE_TYPES` or similar) referenced by both this model and the new `Crux::AgentKnowledgeSource` — prevents drift between the two tables' notion of "valid source type." |
| `app/services/crux/knowledge/retriever.rb` (crx-005) | modify | `#candidates(user:, project:, query:, agent:)` — adds a config-only `agent_allowed_types` read (`crux_agent_knowledge_sources.where(agent: agent, enabled: true).pluck(:source_type)`) alongside the existing `project_enabled_types` read, extending the existing two-way intersection to three-way, computed **before** `PermissionFilter` is called. |
| `app/services/crux/agents/context_assembler.rb` (crx-004) | modify | `#assemble(conversation:, user:, agent:)` — `agent:` becomes explicit and required; passed through to `Retriever#candidates`. |
| `app/services/crux/agents/runner.rb` (crx-004) | modify | Passes the specific agent about to be invoked into `ContextAssembler#assemble(agent: agent, ...)` explicitly, rather than relying on conversation-level inference. |
| `app/services/crux/agents/author.rb` (crx-022) | modify | Creates the new agent's 11 `crux_agent_knowledge_sources` rows at authoring time, `enabled` set from the authoring form's submitted checkboxes (default unchecked — least-privilege). |
| `db/seeds/crux_agents_seed.rb` (crx-004) | modify | Seeds the 12 catalog agents' `crux_agent_knowledge_sources` rows from `agent_catalog.md`'s documented Tools-column source affinities where named (Developer → Repository, Documents; QA Agent → Issues, Wiki; Documentation Agent → Wiki, Documents, Issues; Security Agent → Repository, Documents; Code Reviewer → Repository; Product Owner Agent → Issues); all-disabled for the six agents whose Tools line names "Knowledge Engine" with no source-level breakdown (Requirement Analyst, Planner, Reporter, DevOps Agent, Scrum Master Agent, Release Manager Agent) — flagged for developer confirmation before implementation. |
| `app/controllers/project_crux_agents_controller.rb` (crx-004/crx-022) | modify | Add an update action for an existing agent's knowledge-source checkboxes, gated `crux:manage_agents`; a project-override row created for an existing global catalog agent copies that agent's *current* scope (not zero). |
| `app/views/project_crux_agents/_form.html.erb` and the Agent Settings edit view | modify | Add the "Knowledge Sources" checkbox section (11 sources, same order as crx-005's Knowledge tab), visually and functionally separate from crx-024's "Allowed Tools" section. |

### Implementation Notes

- **The dividing line with crx-024 is precise, not approximate.** Knowledge Engine = Redmine-native reads feeding context, always structurally assembled pre-model-call (this task's domain). Tool Registry = model-initiated, optional, mid-run external-system actions (crx-024's domain). No shared table, no shared UI partial, no shared controller action — the two sections independently `PATCH` their own resource so neither task's migration blocks the other's.
- **The three-way intersection can only narrow, never widen, what crx-005 already computed.** `effective = permission_allowed ∩ project_enabled ∩ agent_allowed`. Set intersection with an additional operand (`agent_allowed`) can only shrink or preserve the result — there is no code path where `agent_allowed = true` alone grants anything; it is only ever a necessary condition alongside the other two, never sufficient. This is the concrete guarantee behind "per-agent scoping only narrows."
- **`PermissionFilter` runs on the already-narrowed source-type scope, preserving crx-005's "always the first content-touching operation" invariant exactly.** `Retriever#candidates` computes `source_type_scope = project_enabled_types ∩ agent_allowed_types` first — a config-only read touching zero content rows, the same kind of operation crx-005 already performs for `project_enabled_types` alone. `PermissionFilter#allowed_source_ids` is then called, **unmodified**, only for source types remaining in that scope — still the first genuinely *content-touching* operation in the pipeline, exactly as crx-005 mandates. Restricting which source types `PermissionFilter` is even asked about cannot leak anything: a source type excluded from `source_type_scope` would have contributed zero candidates from `PermissionFilter` anyway, since intersection is commutative — this is a scoping optimization, not a reordering or a bypass. `Ranker` receives the fully-filtered result and is completely untouched by this task, remaining agnostic to *why* a candidate survived.
- **`agent:` must be an explicit, required parameter on `ContextAssembler#assemble`, never inferred from `conversation.agent_id`.** crx-004's own hand-off design (two independent `crux_runs` rows per conversation) already makes single-conversation, multi-agent context assembly a real case today, not a hypothetical — if `ContextAssembler` inferred the agent from `conversation.agent_id` alone, a hand-off's second agent (e.g. Planner) could silently receive the first agent's (Requirement Analyst's) knowledge scope, a correctness bug with security-adjacent consequences. `Runner` already knows exactly which agent it's about to invoke at the point it calls `ContextAssembler`, so this is a one-line, no-ambiguity change. **When to revisit**: not expected to — this is the correct permanent shape; crx-007's Agent Collaboration and any future multi-agent chaining (crx-019) should inherit it rather than re-decide it.
- **No new permission.** Knowledge-scope editing reuses `crux:manage_agents` (the same tier that already governs model/temperature editing) — deliberately not `crux:manage_knowledge` (the project-level indexing toggle, a different concern per `security.md`'s own permission table) and not a new permission like crx-022's `crux:author_agents` (narrowing an already-bounded agent is not the "materially higher trust" action authoring a wholly new prompt template is). For custom agents, `Crux::Agents::Author` sets the *initial* checkbox state at creation time (gated `crux:author_agents` + tier, unchanged from crx-022); any later edit — catalog or custom — goes through `crux:manage_agents`, mirroring crx-022's own resolved edge case that the authoring permission gates creation only, not continued operation.
- **Missing-row semantics are fail-closed, never fail-open.** If `crux_agent_knowledge_sources` has no row at all for a given `(agent_id, source_type)` — e.g. an agent created before this migration ran and the backfill somehow missed it — that source type is treated as disabled, never enabled, mirroring crx-005's own defense-in-depth philosophy (Edge Case #5: missing data defaults to the safer, narrower interpretation). This makes the migration's backfill step correctness-critical, not merely tidy.
- **Catalog-agent defaults are seeded from `agent_catalog.md`'s own documented Tools-column affinities where they exist; all-disabled where the catalog doesn't commit to a specific list.** Inventing a specific source list for the six agents whose Tools line names only "Knowledge Engine" generically (Requirement Analyst, Planner, Reporter, DevOps Agent, Scrum Master Agent, Release Manager Agent) would be presumptuous beyond what any canonical doc states — flagged explicitly for developer confirmation before implementation, the same "no live dictation session" disclosure this repo's specs already use elsewhere.
- **A project-override row for an existing global catalog agent copies that agent's current knowledge scope, not zero.** These are different situations from a brand-new custom agent: overriding Planner's *model* on one project shouldn't silently also reset its *knowledge access* to nothing — that would be a confusing UX trap distinct from the deliberate least-privilege default for genuinely new (custom) agents.
- **The RAG-ready seam crx-018 established is preserved, not extended.** crx-018's own Implementation Notes already commit to "a second scoring strategy behind `Ranker`'s existing interface, not a rewrite," should semantic retrieval ever be committed. This task's job is to make sure the new `agent:` dimension doesn't compromise that seam — and it doesn't, because agent-scoping lives entirely in `Retriever`'s pre-`Ranker` filtering. The durable contract this task stabilizes is `Retriever#candidates(user:, project:, agent:, query:)`'s three-narrowing-dimension signature; no new abstract `Crux::Knowledge::Provider` base class is introduced now — that remains `future_scope.md` territory, not this task's to build.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Agent-level disable excludes despite project+permission allow | Source disabled at agent level; enabled at project level; user has full Redmine access | No candidates from that source for that agent — a dedicated test proving the three-way intersection can genuinely narrow beyond what crx-005 alone would allow | pending |
| 2 | Agent-level enable cannot widen beyond project-disabled | Source enabled at agent level; disabled at project level | No candidates — project-level disable still wins, confirming intersection, not union | pending |
| 3 | Agent-level enable cannot widen beyond permission-denied | Source enabled at agent+project level; user lacks Redmine permission for that content | No candidates — Redmine ACL still wins, confirming `PermissionFilter` is untouched and still authoritative | pending |
| 4 | `agent:` required and explicit | Call `ContextAssembler#assemble` without an `agent:` argument | Raises (missing required keyword), not a silent fallback to conversation-level inference | pending |
| 5 | Hand-off scenario respects per-agent scope | Requirement Analyst → Planner hand-off (crx-004), each with different knowledge scopes | Planner's context reflects Planner's own scope, not Requirement Analyst's | pending |
| 6 | Missing row defaults to disabled | An agent with no `crux_agent_knowledge_sources` row at all for a source type | Treated as disabled, not enabled | pending |
| 7 | Shared canonical constant prevents drift | Attempt to create a `crux_agent_knowledge_sources` row with a `source_type` not in the shared 11-value constant | Rejected at the model validation layer, same as crx-005's existing `crux_knowledge_sources` validation | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Custom agent knowledge scoping end-to-end | Author "SEO Agent" (crx-022) with Wiki + Documents checked, Issues unchecked; project has all three enabled | SEO Agent's responses/context never reference Issues, despite project-level enablement | pending |
| 2 | Catalog agent defaults render correctly | Open Developer Agent's settings after this task ships | Repository + Documents pre-checked, per `agent_catalog.md`'s documented affinity | pending |
| 3 | New custom agent defaults to zero | Author a new custom agent, submit with no knowledge checkboxes touched | All 11 sources disabled for that agent | pending |
| 4 | Project-override copies scope, doesn't zero it | Create a project-scoped override of an existing global catalog agent (e.g. Planner), changing only its model | The override's knowledge scope matches the global agent's current scope, not all-disabled | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Backfill migration coverage | An agent authored via crx-022 before this migration ships | Backfill inserts all 11 rows for it too, per the default rules — no agent is left in an undocumented gap state | pending |
| 2 | Zero knowledge sources enabled for an agent | An agent invoked with all 11 sources disabled at the agent level | `ContextAssembler`'s 4th layer is empty for that agent; it proceeds on conversation history alone, mirroring crx-005's own zero-sources-enabled edge case at the project level | pending |
| 3 | Agent-scope toggled off mid-conversation | An agent's knowledge scope is edited between two turns of an in-progress conversation | Accepted inconsistency, mirroring crx-005's own accepted "toggling a source off mid-conversation" behavior — the next turn simply reflects the new scope, no crash | pending |
| 4 | Custom-agent authoring form defaults to opt-out instead of opt-in (implementation bug) | Checkboxes rendered pre-checked instead of unchecked | Explicitly tested against — Functional Test #3 asserts zero enabled sources when no checkbox is touched | pending |

### QA Test Plan

**Scope**: Per-agent knowledge-source scoping correctness (the three-way intersection), catalog-agent seeded defaults, custom-agent least-privilege defaults, and UI/permission parity with crx-024's separate Allowed Tools section.

**Pre-conditions**: crx-001 through crx-024 in place; a project with Issues, Wiki, Repository all enabled at the project level; at least one private Wiki page.

**QA Steps**:
1. Author a custom agent with only Wiki + Documents checked; confirm Issues never appears in its output despite project-level enablement.
2. Open Developer Agent's settings; confirm Repository + Documents are pre-checked per `agent_catalog.md`'s documented affinity.
3. Author a new custom agent touching no checkboxes; confirm all 11 sources are disabled.
4. Create a project-override of an existing catalog agent; confirm its knowledge scope matches the global agent's current scope, not zero.
5. Confirm a user without Redmine access to the private Wiki page never sees it via any agent, regardless of that agent's knowledge-scope settings (permission filter still wins).

**Expected Outcomes**: Per-agent scoping only ever narrows what crx-005 already computed; `PermissionFilter`/`Ranker` behave identically to before this task shipped.

**Out of Scope**: Tool/write-action scoping (crx-024).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked inventing a second "Knowledge Source Registry" table, duplicating crx-005's already-validated 11-value enum — the same class of mistake crx-005's own Gate 1 already caught and fixed once for a different reason. | Code Changes, `knowledge_source.rb` modify row | Extracted into one shared constant referenced by both tables, preventing drift rather than duplicating the list. |
| 2 | HIGH | `ContextAssembler#assemble` risked inferring the agent from `conversation.agent_id`, which silently breaks the moment a hand-off (already real today, crx-004) involves a second agent. | Code Changes, `context_assembler.rb`/`runner.rb` rows; Test Case Unit #5 | `agent:` made explicit and required, threaded from `Runner` at the exact point it knows which agent it's invoking. |
| 3 | MEDIUM | The boundary with crx-024 needed to be stated precisely, not left as "these are both per-agent scoping tasks" — risking overlapping schema or UI. | Planning, Description; Implementation Notes | Explicit three-way domain split (Knowledge Engine / Workflow Engine / Tool Registry) stated and enforced via separate tables/partials/controller actions. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The load-bearing security claim of this entire task — that the new intersection can only narrow, never widen, access — needed an explicit, direct test, not just an argument in prose. | Test Case Unit #1/#2/#3 | Three dedicated tests each hold one of the three narrowing dimensions fixed and vary another, proving intersection (not union) behavior from every angle. |
| 2 | HIGH | `PermissionFilter`'s own code must remain completely untouched — any modification there would reopen crx-005's own non-negotiable Gate 2 finding. | Code Changes (no `permission_filter.rb` row present) | Confirmed zero changes to `PermissionFilter`; the new logic lives entirely in `Retriever`'s pre-filter scoping step. |
| 3 | MEDIUM | Missing-row semantics could default to fail-open (enabled) if not explicitly specified, which would silently grant access rather than restrict it. | Implementation Notes; Test Case Unit #6 | Explicitly fail-closed, directly tested. |
| 4 | MEDIUM | The new `agent_allowed_types` read must be a single indexed query, not N+1 per source type per candidate. | Code Changes, `retriever.rb` row | Specified as a single `pluck` query, matching the existing `project_enabled_types` pattern. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — shared canonical constant, explicit required `agent:` parameter, the precise crx-024 domain boundary, the three-way narrowing-only proof tests, `PermissionFilter`'s untouched status, fail-closed missing-row semantics, and single-query scoping are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Project-override creation forgetting to copy scope | An admin overriding only a catalog agent's model on one project silently also resets its knowledge scope to zero | Yes — Functional Test #4 |
| 2 | Missing `.includes` for associations iterated in a view | The Agent Settings/authoring view N+1-queries `crux_agent_knowledge_sources` per agent per row when listing many agents | Not directly test-covered (low agent count per project at this scale); flagged for implementation attention |
| 3 | Backfill migration missing a pre-existing custom agent | An agent authored via crx-022 before this migration ships is left without any `crux_agent_knowledge_sources` rows, silently interpreted correctly (fail-closed) but undocumented, risking a support mistake later | Yes — Edge Case #1 |
| 4 | Authoring form defaults to opt-out instead of opt-in | Checkboxes pre-checked instead of unchecked, inverting the least-privilege requirement | Yes — Functional Test #3 |

Verdict: Approved. Item #2 is an implementation-time attention item rather than a dedicated test, since realistic per-project agent counts don't yet stress this query shape.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
