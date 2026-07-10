## Metadata
- **Task ID**: crx-018-feature-knowledge-search
- **Title**: Knowledge Search — first-class UI feature (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `knowledge_engine.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Delivers `roadmap.md`'s Phase 3 line "the Knowledge Engine's search capability maturing into a first-class feature." **This is a scope judgment call, not a pre-defined feature**: `knowledge_engine.md`'s Components section (its committed scope) defines only keyword/structured retrieval behind an agent-facing pipeline — there is no dedicated search UI/query-syntax/ranking-algorithm defined anywhere. The same document's own *Future Enhancements* section (explicitly uncommitted, not Components) names "RAG and vector-store support for semantic retrieval" as the only forward-looking search idea in the doc set. This task resolves the ambiguity as: promote crx-005's existing keyword/structured retrieval into a real, directly-queryable search box + results view inside the existing Knowledge tab — **not** RAG/vector/semantic search, which stays filed under Future Enhancements, out of Phase 3 scope entirely.

**Goal**:

A user can type a free-text query into the Knowledge tab and get permission-filtered, ranked results across the project's enabled sources directly — the same `PermissionFilter`/`Retriever`/`Ranker` pipeline crx-005 built for agent context assembly, now also reachable by a human typing a question directly, without going through an agent/model call at all.

**Objectives**:
- [ ] Add a search box + results view to the existing Knowledge tab (crx-005's placeholder-turned-real tab).
- [ ] Reuse `Crux::Knowledge::PermissionFilter`/`Retriever`/`Ranker` (crx-005) exactly as built — no new retrieval logic, no new ranking algorithm, only a new entry point.
- [ ] Confirm a direct human search query never produces a `crux_runs` row — no agent, no model call, no tokens/cost are involved, and `crux_runs.agent_id` is non-nullable per crx-004's model layer, so a direct search structurally doesn't fit that row shape.
- [ ] Explicitly do not build RAG/vector-store/semantic search — filed under `future_scope.md`, not committed to any roadmap phase.
- [ ] Explicitly do not build a dedicated query audit log — a search is no higher-risk than a user browsing Issues directly (`security.md`'s own framing), so it isn't separately audit-logged.

**Deliverables**:
- [ ] Search box + results view UI in the Project Knowledge tab.
- [ ] `Crux::Knowledge::SearchController` (or extension of the existing Knowledge controller) — a thin wrapper calling `Retriever#candidates` → `Ranker#rank` with a human-supplied query, reusing crx-005's services unmodified.

**Out of Scope**: RAG/vector-store/semantic retrieval (`knowledge_engine.md`'s own Future Enhancements, `future_scope.md` — not scheduled against any of the four roadmap phases); organization-wide (cross-project) search (`knowledge_engine.md`/`future_scope.md`); a dedicated query audit log.

---

## Specification

**Complexity**: HIGH

**Reason**: Despite being smaller net-new code than crx-005's original build, the exact same "single most security-critical data-access path in the product" reasoning crx-005 used for its own HIGH rating applies identically here — a naive new UI-driven search entry point could bypass `PermissionFilter` and re-derive its own visibility check instead of reusing it, exactly the anti-pattern crx-005's Gate 2 review called out. Matches the security-sensitivity criterion, reused from crx-005.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/controllers/project_crux_knowledge_controller.rb` (crx-005) | modify | Add a `search` action: accepts a free-text query, calls `Crux::Knowledge::Retriever#candidates(user: User.current, project: @project, query: params[:q])` → `Ranker#rank`, renders results — reuses crx-005's services with zero modification to their internals. |
| `app/views/project_crux_knowledge/index.html.erb` (crx-005) | modify | Add a search box + results partial above/alongside the existing per-source enable/disable list. |
| `app/views/project_crux_knowledge/_search_results.html.erb` | create | Renders ranked results with source-type badges, respecting the exact same enabled/permission-filtered set crx-005's agent-facing retrieval already respects. |

### Implementation Notes

- **Resolution of "Knowledge Search... first-class feature"**: promote crx-005's existing keyword/structured retrieval into a real search box + results view — **not** RAG/vector/semantic search. **Why**: `knowledge_engine.md`'s *Components* section (committed scope) defines only keyword/structured matching; RAG/vector-store support is named exclusively under that same document's own *Future Enhancements* section — a document-internal signal it's deliberately uncommitted, exactly like crx-005 already treated it for Phase 1. **Road not taken**: full semantic/vector search — belongs to `future_scope.md`, out of Phase 3 entirely (not even "later in Phase 3" — it isn't cited against any of the four canonical roadmap phases at all). **When to revisit**: if a future roadmap revision actually commits RAG work, it's a second scoring strategy behind `Ranker`'s existing interface, not a rewrite — crx-005 already isolated ranking behind that seam specifically to make this possible.
- **No new `crux_runs` row for a direct search.** No agent, no model call, no tokens/cost are involved, and `crux_runs.agent_id` is non-nullable per crx-004's own model layer, so a direct search structurally doesn't fit that row shape at all — this is a deliberate scope decision, not an oversight.
- **No dedicated query audit log.** A search is no higher-risk than a user browsing Issues directly (`security.md`'s own framing) — it isn't separately audit-logged in this task's scope. **When to revisit**: if compliance later needs "who searched for what," that's a narrow, dedicated future addition, not something to invent speculatively now.
- **Zero changes to `PermissionFilter`/`Retriever`/`Ranker`'s internals** — this task is purely a new entry point calling the exact same crx-005 services an agent invocation already calls, which is precisely what makes the security reasoning ("this is the same code path, already reviewed once") hold.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Search reuses PermissionFilter | A search query from a user without access to a private Wiki page | Page never appears in results, identical to crx-005's agent-facing behavior | pending |
| 2 | Search respects enabled/disabled sources | Repository disabled for the project | No repository results, regardless of user permission | pending |
| 3 | No crux_runs row created | Any search query | Zero new `crux_runs` rows | pending |
| 4 | Search results match ranking | A query with known relevant/irrelevant candidates | Ranking order matches `Ranker`'s existing scoring, unmodified | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end search | Open Knowledge tab, type a query | Results appear, correctly scoped and ranked | pending |
| 2 | Search reflects toggled sources | Disable a source, re-run the same query | Results no longer include that source | pending |
| 3 | Cross-user difference | Same query, two users with different visibility | Each sees a correctly different result set | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Empty query | Search box submitted with no text | No results / no-op, not an error | pending |
| 2 | Zero sources enabled | Search on a project with everything disabled | Empty results, not an error | pending |
| 3 | Very broad query on a large project | A single common-word query | Results are budget-truncated the same way agent-facing retrieval already is, not unbounded | pending |

### QA Test Plan

**Scope**: Direct human search reusing crx-005's retrieval/ranking pipeline, with identical permission-filter-before-rank guarantees.

**Pre-conditions**: crx-001 through crx-005 in place; a project with mixed-visibility content (some private, some accessible).

**QA Steps**:
1. As a user without access to a private Wiki page, search for a term only that page contains; confirm it never appears.
2. As a user with access, search the same term; confirm it can now appear.
3. Disable a source; re-run a query; confirm it's excluded.
4. Confirm no `crux_runs` rows are created by any search.

**Expected Outcomes**: Search results are exactly as permission-filtered as agent-facing retrieval; no audit/billing side effects from a plain search.

**Out of Scope**: Semantic/vector search quality.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked treating "Knowledge Search" as license to build RAG/vector search, which `knowledge_engine.md` files under Future Enhancements, not committed Components — a scope overreach beyond what Phase 3 actually names. | Implementation Notes | Explicitly scoped to promoting existing keyword/structured retrieval to a UI feature, not new retrieval technology. |
| 2 | MEDIUM | A naive implementation could re-derive its own visibility check for the new search entry point instead of calling crx-005's existing `PermissionFilter` — exactly the anti-pattern crx-005's own Gate 1 warned against. | Code Changes | Explicitly specified as reusing crx-005's services with zero internal modification. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Same class of risk crx-005's Gate 2 named as the single highest-stakes concern in the Knowledge Engine: any new entry point that lets ranking see unauthorized content, even transiently, is a real vulnerability, not a UI bug. | Test Case Unit #1 | Directly tested; reuses the exact already-reviewed code path. |
| 2 | LOW | An unbounded query on a large project could return unbounded results without the existing context-budget truncation. | Test Case Edge #3 | Confirmed to reuse the same budget-truncation `Ranker` already applies. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — scope narrowing away from RAG/vector search and reuse (not re-derivation) of `PermissionFilter` are both concrete rows above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `.includes` for associations iterated in a view | Search results view N+1 queries source metadata per result row | Not directly test-covered (low result-set size expected at this scale); flagged for implementation attention |
| 2 | A search silently creates audit-adjacent side effects | An implementation accidentally writes a `crux_runs` row "for consistency" with agent-facing retrieval | Yes — Unit Test #3 explicitly asserts zero new rows |
| 3 | Unbounded query causing slow response | A common-word query against a large project | Yes — Edge Case #3 |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
