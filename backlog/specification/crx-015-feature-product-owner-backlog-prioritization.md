## Metadata
- **Task ID**: crx-015-feature-product-owner-backlog-prioritization
- **Title**: Product Owner Agent — Backlog Prioritization (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: MEDIUM
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `agent_catalog.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Enables the seeded Product Owner Agent `crux_agents` row (crx-004, `enabled: false`); chat-invoked only — unlike Scrum Master/Release Manager, `agent_catalog.md`'s Execution Flow for this agent names no automation trigger, so this task does not touch crx-013's automation mechanism at all. Produces a proposed re-ranked backlog + rationale as a `reorder_backlog` plan step, gated by ordinary `crux:approve` — `agent_catalog.md` is explicit this is not a destructive action.

**Goal**:

A user can ask Product Owner Agent to re-rank the project's backlog against stated business goals; it cross-references Issues (crx-005) and Analytics Engine (crx-012) age/activity signals to propose an ordering with rationale, presented as an ordinary approval-gated plan step.

**Objectives**:
- [ ] Write Product Owner Agent's real `prompt_template` (role: product owner; context: backlog + goals; constraint: prioritization framework; output: ranked list + rationale).
- [ ] Cross-reference Issues (crx-005 Knowledge Engine) and Analytics Engine (crx-012, age/activity signals) to propose ordering.
- [ ] Implement the `reorder_backlog` plan step executor: on approval, mutates Redmine's own native ordering/priority field.
- [ ] Confirm reordering is a recommendation only until approved — `agent_catalog.md`'s explicit limitation.

**Deliverables**:
- [ ] Real `prompt_template` for Product Owner Agent (crx-004's schema, no new fields).
- [ ] New `crux_plan_steps.action_type: reorder_backlog`, `target_type: Issue` (free-form column, no migration).
- [ ] Executor mapping `reorder_backlog` onto Redmine's native `Issue#priority_id` (or equivalent native ordering field) on approval.

**Out of Scope**: Goal-weighted auto-prioritization, stakeholder voting integration (`agent_catalog.md`'s own Future Roadmap for this agent); any automation trigger (chat-only, per the doc — no cadence/event wiring to crx-013).

---

## Specification

**Complexity**: MEDIUM

**Reason**: No new migrations, single self-contained new agent, no automation-trigger complexity — closest in shape to a Phase 1 per-agent slice of crx-004. The one real new code surface is the executor mutating Redmine's issue ordering/priority on approval, a genuine (if narrow) Core Platform write.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/models/crux/agent.rb` (crx-004) | modify | Add Product Owner Agent's real `prompt_template` content. |
| `db/seeds/crux_agents_seed.rb` (crx-004) | modify | Flip `Product Owner Agent.enabled` to `true` (global default), per `roadmap.md`'s Phase 3 "new GA" listing. |
| `app/services/crux/plan_steps/reorder_backlog_executor.rb` | create | On a `reorder_backlog` plan step's approval, applies the proposed ordering to Redmine's native `Issue#priority_id` (this doc set's 11 canonical tables are treated as fixed — no new Crux-owned position column is added). |

### Implementation Notes

- **"Reordering the backlog" maps to Redmine's own native `Issue#priority_id`**, since Crux's canonical schema doesn't define an ordering column of its own and the 11 canonical tables are treated as fixed. This task does not add a Crux-owned position column, and does not assume coupling to any separate, non-canonical backlog-visualization plugin that might exist in a given Redmine instance.
- **Reordering is a recommendation only, never applied without `crux:approve`** — `agent_catalog.md`'s explicit limitation, enforced by the ordinary (not destructive) plan-step gate crx-003 already built, no new gate type needed.
- **No automation trigger for this agent** — unlike Scrum Master/Release Manager, `agent_catalog.md` names no scheduled/event trigger for Product Owner Agent; this task deliberately does not wire it into crx-013's mechanism.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Product Owner enabled by default | New project after this task ships | `enabled: true` | pending |
| 2 | Reorder proposal produced | A user asks for backlog prioritization | A `reorder_backlog` plan step is drafted with rationale | pending |
| 3 | No premature mutation | Plan step at `awaiting_approval` | Redmine's `Issue#priority_id` unchanged until approved | pending |
| 4 | Priority applied on approval | Plan step approved | `Issue#priority_id` updated to match the proposed order | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end backlog reprioritization | Ask Product Owner Agent to re-rank the backlog; approve the result | Issue priorities update correctly, visible in the standard Redmine Issues view | pending |
| 2 | Reject a reorder proposal | Reject it | No changes applied; plan returns to `planned` | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Empty backlog | Agent invoked on a project with no open issues | Produces a clear "nothing to prioritize" response, not an error | pending |
| 2 | Partial approval | A large reorder proposal, user modifies a subset before approving | Modify (crx-003 mechanics) applies correctly to the payload before re-preview | pending |

### QA Test Plan

**Scope**: Product Owner Agent's real behavior and the `reorder_backlog` executor's approval-gated Core Platform write.

**Pre-conditions**: crx-001 through crx-012 in place; a project with a real backlog of open issues.

**QA Steps**:
1. Ask Product Owner Agent to prioritize the backlog; confirm a plan step with rationale appears.
2. Approve it; confirm issue priorities update.
3. Reject a separate proposal; confirm no changes apply.

**Expected Outcomes**: No backlog reordering ever applies without explicit approval.

**Out of Scope**: Automated/scheduled prioritization.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | MEDIUM | An early draft risked adding a new Crux-owned "position" column for backlog ordering instead of reusing Redmine's own native priority field, unnecessarily duplicating Core Platform data. | Implementation Notes | Resolved to reuse `Issue#priority_id` directly, no new schema. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The `reorder_backlog` executor is a genuine Core Platform write (Issue priority) — it must only ever run after `crux:approve`, with no direct-from-chat mutation path. | Test Case Unit #3/#4 | Explicitly tested that the write only happens post-approval. |
| 2 | LOW | No indexing/N+1 concern beyond standard issue queries already covered by Redmine's own scopes. | — | No action needed. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — native-field reuse and approval-gated write timing are both concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `permit` key on a nested reorder payload | The reorder proposal's per-issue priority mapping accepts an incomplete/malformed payload that silently skips some issues on approval | Not directly test-covered; flagged for implementation attention — validate the payload covers every referenced issue before applying |
| 2 | `respond_to :js` missing | The reorder plan step's approval doesn't refresh the Issues view in place | Not directly test-covered (view-refresh mechanics inherited from crx-003's existing approval card); no new finding beyond what crx-003 already established |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
