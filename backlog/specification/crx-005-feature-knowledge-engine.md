## Metadata
- **Task ID**: crx-005-feature-knowledge-engine
- **Title**: Knowledge Engine — 11 sources, permission-filtered retrieval, Coverage Score (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `knowledge_engine.md`, `architecture.md`, `security.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Fill the seam crx-004 left open in `Crux::Agents::ContextAssembler` — real, permission-filtered retrieval across the 11 canonical knowledge sources (Issues, Wiki, Repository, Documents, Files, News, Forums, Time Entries, Helpdesk, CRM, Custom Fields), replacing the "conversation history only" placeholder. This is the concrete mechanism behind Principle 6 (Secure by Construction): the permission filter must run *before* ranking, not after, so an agent's prompt is assembled from a candidate set the acting user could already see in Redmine — never a set an unauthorized document briefly entered before being filtered out.

**Goal**:

A project admin can enable/disable each of the 11 sources per project (replacing crx-001's Knowledge tab placeholder) and see a Coverage Score per source and overall. Every agent invocation from crx-004 onward assembles its 4th context layer — permission-filtered, ranked, budget-truncated knowledge — from only the sources enabled for that project and visible to the acting user, verified by the same Redmine ACL checks Core Platform already uses (no parallel ACL).

**Objectives**:
- [ ] Add `crux_knowledge_sources` table (`database_design.md`).
- [ ] Implement the per-project enable/disable toggle for each of the 11 sources; disabling removes a source from indexing and retrieval immediately, not just down-ranks it.
- [ ] Implement the permission-filter-before-rank pipeline: build the allowed-source set from Redmine's native ACL for the acting user, intersect with enabled sources, retrieve within that set only, then rank/truncate to a context budget.
- [ ] Implement the Coverage Score metric (indexed objects ÷ total addressable objects, per source and overall) and surface it on the Knowledge tab (crx-001 placeholder) and attached to each `crux_runs` row via `context_refs`.
- [ ] Extend `Crux::Agents::ContextAssembler` (crx-004) to call the Knowledge Engine for its 4th context layer, replacing the `# TODO: crx-005` seam.
- [ ] Indexing: a background job per source type that walks Core Platform's own data (Issues, Wiki pages, etc.) and records what's indexed vs. addressable, without duplicating the underlying content into a shadow copy beyond what retrieval needs.

**Deliverables**:
- [ ] Migration: `crux_knowledge_sources`.
- [ ] Model: `Crux::KnowledgeSource`.
- [ ] `Crux::Knowledge::PermissionFilter` — builds the allowed-source set from Redmine ACL, always the first operation in any retrieval path.
- [ ] `Crux::Knowledge::Retriever` — fetches candidates within the allowed ∩ enabled set.
- [ ] `Crux::Knowledge::Ranker` — scores, orders, truncates to context budget.
- [ ] `Crux::Knowledge::CoverageScore` — per-source and overall calculator.
- [ ] `Crux::Jobs::IndexKnowledgeSourceJob` (one per source type, or one parameterized job).
- [ ] `ProjectCruxKnowledgeController` rewritten from crx-001's placeholder to real enable/disable + Coverage Score display, gated `crux:manage_knowledge`.
- [ ] `Crux::Agents::ContextAssembler` (crx-004) updated to consume the Knowledge Engine's output as its 4th layer.
- [ ] `crux_runs.context_refs` populated with a reference to what was actually retrieved for that run (not the raw content inline — a reference, per `database_design.md`).

**Out of Scope**: RAG/vector-store semantic retrieval (`knowledge_engine.md` Future Enhancements — keyword/structured matching only for Phase 1); organization-wide (cross-project) retrieval; real-time/streaming indexing (near-real-time batch indexing is sufficient); any of the 11 sources this project doesn't already have installed/enabled in Redmine itself (e.g. Helpdesk/CRM require their own Redmine modules to exist — this task indexes what's there, it doesn't add those modules).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration; implements the single most security-critical data-access path in the product (permission-filter-before-rank, the concrete mechanism for Principle 6); spans all 11 heterogeneous Core Platform data types; wrong ordering here (rank-then-filter) would be a silent, hard-to-detect data leakage bug rather than a visible one — exactly the risk `architecture.md` calls "non-negotiable." HIGH per security-sensitivity and cross-module impact (every agent in crx-004 depends on this).

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_knowledge_sources.rb` | create | `crux_knowledge_sources(id, project_id, source_type, enabled)` per `database_design.md`; one row per project per of the 11 canonical `source_type` values, seeded (all `enabled: false` by default) when a project first enables the Crux AI module. |
| `app/models/crux/knowledge_source.rb` | create | `belongs_to :project`; validates `source_type` against the 11 canonical values (`knowledge_engine.md`), not a free-text field — prevents the "high schema variability" risk the doc already flags for Custom Fields from spreading to source-type naming itself. |
| `app/services/crux/knowledge/permission_filter.rb` | create | `#allowed_source_ids(user:, project:, source_type:)` — delegates entirely to Redmine's own ACL (`User#allowed_to?` and per-object visibility scopes already used by Core Platform), never a parallel access list. This is always the first call in `Retriever`, never a post-filter. |
| `app/services/crux/knowledge/retriever.rb` | create | `#candidates(user:, project:, query:)` — calls `PermissionFilter` first, then fetches only within the allowed ∩ enabled set, per source type's native Redmine query (e.g. `Issue.visible(user)`, not a hand-rolled visibility re-implementation). |
| `app/services/crux/knowledge/ranker.rb` | create | `#rank(candidates:, query:, budget:)` — keyword/structured scoring (no vector store this task), truncated to a configurable context-size budget. |
| `app/services/crux/knowledge/coverage_score.rb` | create | `#for(project:, source_type: nil)` — indexed ÷ addressable, per source or overall; reflects the last completed index pass, not live state (`knowledge_engine.md` Assumptions). |
| `app/jobs/crux/index_knowledge_source_job.rb` | create | Parameterized by `project_id`/`source_type`; walks the relevant Core Platform association, records indexed-object counts for `CoverageScore`; re-run on a schedule and on-demand ("re-index" action) rather than only once. |
| `app/controllers/project_crux_knowledge_controller.rb` | modify | Real enable/disable toggle per source (writes `crux_knowledge_sources.enabled`) + last-indexed timestamp + Coverage Score display, replacing crx-001's static placeholder; gated `crux:manage_knowledge`. |
| `app/views/project_crux_knowledge/index.html.erb` | modify | List all 11 sources with toggle, per-source Coverage Score, last-indexed timestamp, overall Coverage Score — per `knowledge_engine.md` UI Description. |
| `app/services/crux/agents/context_assembler.rb` (crx-004) | modify | Replace the `# TODO: crx-005` placeholder with a real call: `Retriever#candidates` → `Ranker#rank`, added as the 4th context layer alongside crx-004's existing 3. |
| `app/models/crux/run.rb` (crx-004) | modify | `context_refs` now populated with a real reference (e.g. a retrieval-result identifier) instead of always being empty/nil. |

### Implementation Notes

- **Filter-before-rank is enforced structurally, not by convention.** `Retriever#candidates` calls `PermissionFilter` as its literal first line, and `Ranker` only ever receives an already-filtered candidate list — there is no code path where `Ranker` sees an object `PermissionFilter` would have excluded, even transiently. This is deliberately over-engineered against the "implemented incorrectly at code time" risk `architecture.md` names explicitly for this exact ordering.
- **No parallel ACL.** `PermissionFilter` calls Redmine's own visibility scopes (`Issue.visible(user)`, `WikiPage` visibility via project membership, etc.) — it does not reimplement or cache a second copy of who-can-see-what. This is what makes "AI only accesses data the current user is authorized to view" true even if the retrieval/ranking logic itself is wrong about relevance — per `knowledge_engine.md`'s own framing.
- **Disabling a source is an immediate hard exclusion**, not a down-rank — `Retriever` intersects with `crux_knowledge_sources.enabled` before querying, so a disabled source never enters the candidate set at all, consistent with `knowledge_engine.md`'s "excluded from retrieval outright, not merely down-ranked."
- **Custom Fields' high schema variability (`knowledge_engine.md` Risks) is handled by treating it as its own `source_type`** with its own narrower retrieval logic (project/issue/user custom field values only, not free-form), rather than folding it into Issues' retrieval path where its variability would degrade Issues' own relevance scoring.
- **`context_refs` is a reference, not inline content**, per `database_design.md` — this task must not store raw retrieved text directly on `crux_runs`; it stores enough to reconstruct what was retrieved (source ids + ranking snapshot) for audit purposes, deferring the "dedicated blob/object store" question (`database_design.md` Future Enhancements) to a later task.
- **Toggling a source off mid-conversation can produce inconsistent context between turns** (`knowledge_engine.md` Risks) — this is accepted as-is for Phase 1, not resolved by this task; noted so it isn't mistaken for an oversight.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Permission filter excludes unauthorized content | A private Wiki page the acting user cannot see, Wiki source enabled | Page never appears in `Retriever#candidates`, confirmed by asserting `Ranker` never receives it (not just that it's absent from final output) | pending |
| 2 | Disabled source excluded regardless of permission | Repository source disabled for the project; user has full repository access | No repository candidates returned, despite the user being authorized | pending |
| 3 | Coverage Score calculation | 480/600 Issues indexed, 40/40 Wiki, 900/1,200 Repository, all enabled | Overall Coverage Score ≈ 77%, matching `knowledge_engine.md`'s worked example exactly | pending |
| 4 | Coverage Score is per-project | Two projects with different enabled-source sets and index states | Each project's Coverage Score is independent, no cross-project averaging | pending |
| 5 | Custom Fields source-type validation | Attempt to create a `crux_knowledge_sources` row with an invalid `source_type` string | Rejected at the model validation layer | pending |
| 6 | context_refs population | An agent run that retrieves 3 Issues and 1 Wiki page | `crux_runs.context_refs` references exactly those 4 items, not inline text | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Knowledge tab real toggles | Open Project Knowledge tab, enable Issues/Wiki/Repository, disable the rest | Enabled sources show a Coverage Score and last-indexed timestamp; disabled ones show neither (or a clear "disabled" state) | pending |
| 2 | Agent output reflects enabled sources only | Ask Reporter for a project summary with only Time Entries enabled | Summary content and `context_refs` reference only Time Entries, no Issue/Wiki content leaks in | pending |
| 3 | Re-index action | Trigger a manual re-index after a bulk Wiki import | Coverage Score updates to reflect the new indexed count after the job completes | pending |
| 4 | Cross-role retrieval difference | Same query, two users with different project roles/visibility | Each user's agent run retrieves a different (correctly scoped) candidate set | pending |
| 5 | Full 11-source list renders | Open the Knowledge tab | All 11 canonical sources listed in a stable order, none renamed or substituted | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Zero sources enabled | Every source disabled for a project, an agent is invoked anyway | `ContextAssembler`'s 4th layer is empty; agent proceeds on conversation history alone rather than erroring | pending |
| 2 | Source toggled off mid-conversation | User disables Wiki between two turns of the same conversation | Accepted inconsistency per Implementation Notes — the second turn simply omits Wiki, no crash | pending |
| 3 | Low Coverage Score | A source at 12% Coverage Score | Displayed plainly as a number — this task does not auto-disable or block agent use, per `knowledge_engine.md` Best Practices ("a signal to narrow scope, not a reason to disable") | pending |
| 4 | Indexing job failure for one source type | Repository indexing job errors (e.g. unreachable repository) | Other sources' indexing is unaffected; the failed source's Coverage Score simply doesn't advance, with a visible last-indexed timestamp that stops updating rather than a silent full-index-pipeline failure | pending |
| 5 | User with no project role attempting knowledge-backed action | A user who somehow reaches an agent call without project membership (should be blocked earlier by crx-001's module gate) | `PermissionFilter` still returns an empty allowed set as a defense-in-depth backstop, not just relying on the earlier gate | pending |

### QA Test Plan

**Scope**: Per-project source enablement, permission-filter-before-rank correctness, Coverage Score accuracy, and `Crux::Agents::ContextAssembler`'s integration with crx-004's agent runs.

**Pre-conditions**:
- crx-001 through crx-004 in place; at least one project with real Issues/Wiki/Repository content and at least one private Wiki page.
- Two users with different role/visibility on that project.

**QA Steps**:
1. As the project admin, enable Issues, Wiki, and Repository; leave the rest disabled; trigger initial indexing.
2. As a user without access to the private Wiki page, ask an agent a question that would naturally surface it if unfiltered; confirm it never appears in the response or `context_refs`.
3. As a user with full access, ask the same question; confirm the private page can now appear (proving the difference is permission-driven, not just off by default).
4. Disable Repository; re-ask a Repository-relevant question; confirm no Repository content appears despite the user being authorized.
5. Confirm the Knowledge tab's Coverage Score matches a manually computed indexed÷addressable ratio.
6. Force a re-index after adding new content; confirm the score updates.

**Expected Outcomes**:
- No unauthorized content ever reaches an agent's prompt or a run's `context_refs`, under any combination of enablement/permission.
- Coverage Score is accurate and per-project.
- Disabling a source is immediate and absolute, not a down-rank.

**Out of Scope**:
- Semantic/vector retrieval quality — Phase 1 is keyword/structured matching only.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked implementing `Retriever` to fetch broadly, then have `Ranker` (or the caller) drop unauthorized items afterward — functionally similar to "filter after rank," which `architecture.md` explicitly calls non-negotiable to avoid. | Code Changes, `retriever.rb`/`ranker.rb` rows; Implementation Notes | Spec restructures so `PermissionFilter` runs as `Retriever`'s literal first operation; `Ranker` structurally cannot see excluded candidates. |
| 2 | HIGH | Component sync: `crux_runs.context_refs` (crx-004) had no populating code path until this task — a gap between what the schema promised and what was actually written. | Code Changes, `run.rb` modify row | This task explicitly wires real population, closing the gap. |
| 3 | MEDIUM | `source_type` risked being a free-text column, allowing typos/drift from the 11 canonical names (violating the project's "never introduce alternate names for a canonical term" convention). | Code Changes, `knowledge_source.rb` row | Validated against the canonical 11-value list at the model layer. |
| 4 | LOW | Custom Fields' documented high schema variability risked degrading Issues' retrieval quality if folded into the same code path. | Implementation Notes | Kept as its own `source_type` with narrower, separate retrieval logic. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is the single highest-stakes cross-user data-leak surface in the entire plugin: any implementation bug that lets `Ranker` or `ContextAssembler` see an unauthorized object — even transiently, even if never surfaced in final output — is a real vulnerability class, not a UI bug. | Code Changes, `permission_filter.rb`/`retriever.rb` rows; Test Case Unit #1 | Structural ordering enforced (Gate 1 #1); Unit Test #1 explicitly asserts non-visibility at the `Ranker` input boundary, not just the final response. |
| 2 | HIGH | Re-implementing Redmine's own visibility logic (rather than calling it) is exactly the "parallel ACL" anti-pattern `security.md` warns against — a second, slightly-different implementation of "who can see this Issue" would drift from Core Platform's real rules over time. | Code Changes, `permission_filter.rb` row | Spec mandates calling Redmine's existing visibility scopes (`Issue.visible(user)` and equivalents) directly, never re-deriving them. |
| 3 | MEDIUM | Indexing jobs walking 11 source types across potentially large projects risk unbounded queries (`.all` without scope/limit) per the global performance checklist. | Code Changes, `index_knowledge_source_job.rb` row | Job is specified as parameterized/batched per source type, not a single unscoped full-project sweep; must paginate/batch large associations (e.g. Repository commits). |
| 4 | LOW | `context_refs` storing raw content inline (rather than a reference) would bloat `crux_runs` rows and risk re-exposing already-filtered content in exports/audits. | Code Changes, `run.rb` modify row; Implementation Notes | Explicitly specified as a reference, not inline content. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — structural filter-before-rank ordering, no-parallel-ACL requirement, source-type validation, batched indexing, and reference-only `context_refs` are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `.includes` for associations iterated in a view | Knowledge tab N+1 queries `crux_knowledge_sources` × Coverage Score computation per source, per page load | Not directly test-covered (low source count — 11 — makes this a minor concern versus the Runs/Agents lists in crx-004); flagged for implementation attention: precompute/batch the 11 Coverage Score calls in one query where possible |
| 2 | Retrieval silently returns stale results after a permission change | A user's role is downgraded mid-session; cached/stale retrieval still reflects the old, broader access | Yes — Edge Case #5 covers the no-membership backstop; role-downgrade specifically is flagged here as needing the same "filter is computed fresh per call, never cached across permission changes" guarantee, enforced by `PermissionFilter` never persisting a cached allowed-set |
| 3 | Indexing job treated as a single unscoped query | Full-project `.all` sweep on Repository commits for a large repo times out or exhausts memory | Yes — covered by the Gate 2 #3 resolution (batched/parameterized job); no dedicated load-test edge case since realistic repository scale isn't reachable in this task's QA environment |
| 4 | Coverage Score computed from a global count instead of per-project | A bug averages indexed/addressable across all projects instead of scoping to one | Yes — Unit Test #4 |
| 5 | Custom Fields retrieval bleeding into Issues relevance scoring | Custom Field values ranked alongside Issue text using the same scoring weights, degrading Issues relevance | Yes — covered by Gate 1 #4 resolution (separate retrieval path); no separate dedicated test since it's a ranking-quality concern rather than a correctness/security one |

Verdict: Approved. Items #1, #3, and #5 are implementation-time attention items rather than dedicated automated tests, since they concern performance/ranking-quality at a scale this task's QA environment can't realistically exercise — carried forward explicitly so they aren't lost before crx-005 reaches production data volumes.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
