## Metadata
- **Task ID**: crx-016-feature-release-manager-version-close
- **Title**: Release Manager Agent — Release Notes/Plan & version-close trigger (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `agent_catalog.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Enables the seeded Release Manager Agent `crux_agents` row (crx-004, `enabled: false`); the second and only other consumer of crx-013's mechanism, this time the `core_event` (`version_closed`) path. Compiles release notes from completed issues and drafts a release plan/timeline; any Deploy step it coordinates reuses crx-003's existing `PlanStep::DESTRUCTIVE_ACTIONS` constant unchanged (`deploy` is already in it) — no new destructive-action type is introduced.

**Goal**:

When a Version closes, Release Manager drafts release notes (from completed issues in that version) and a release plan/timeline as a plan preview; if a Deploy step is included, it requires `crux:approve_destructive` specifically, exactly as DevOps Agent's Deploy steps already do (crx-004).

**Objectives**:
- [ ] Write Release Manager's real `prompt_template` (role: release manager; context: version + issue history; constraint: release-note format; output: release notes + release plan).
- [ ] Extend crx-013's `EventDispatcher` with the concrete `version_closed` hook — the first real Core Platform model callback that mechanism triggers off (crx-013's own Implementation Notes anticipated this exact usage).
- [ ] Guard against re-firing on every subsequent save of an already-closed Version, not just checking `status == closed` naively — must fire only on the *transition into* closed, once.
- [ ] Compile release notes from completed issues in that version (reusing crx-005's Knowledge Engine Issues source).
- [ ] "Coordinate with DevOps Agent on deployment sequencing" resolved narrowly as Release Manager drafting a Deploy-shaped plan step DevOps Agent would otherwise draft — dispatched through the single-agent `Runner` path (crx-004), not a live multi-agent conversational hand-off.

**Deliverables**:
- [ ] Real `prompt_template` for Release Manager Agent.
- [ ] `crux_automation_policies` support for `event_name: 'version_closed'` with a transition-guard (fires once per close, not on every subsequent save).
- [ ] New `crux_plan_steps.action_type` values: `compile_release_notes`, `draft_release_plan` (free-form column, no migration); reuses existing `deploy`.

**Out of Scope**: Automated multi-environment release trains (`agent_catalog.md`'s own Future Roadmap line); a live DevOps↔Release Manager conversational hand-off (crx-007's Agent Collaboration primitive is the natural mechanism if real multi-agent negotiation is wanted later — deliberately not built here, per the judgment call below).

---

## Specification

**Complexity**: HIGH

**Reason**: First task to hook a Core Platform model save callback (`Version`) for automation purposes — must guard against re-firing on every subsequent save of an already-closed version, not just check `status == closed` naively; any Deploy step it drafts is destructive-adjacent, one of two agents `agent_catalog.md` flags for exactly this blast-radius risk (alongside DevOps Agent). Matches the security-changes + governance-sensitivity criteria.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/models/crux/agent.rb` (crx-004) | modify | Add Release Manager's real `prompt_template` content. |
| `db/seeds/crux_agents_seed.rb` (crx-004) | modify | Flip `Release Manager Agent.enabled` to `true` (global default), per `roadmap.md`'s Phase 3 "new GA" listing. |
| `app/services/crux/automations/event_dispatcher.rb` (crx-013) | modify | Adds the concrete `version_closed` transition-guard: fires only on the save where `status` *changes* to closed (`saved_change_to_status?` or equivalent), never on a subsequent save of an already-closed Version. |
| `app/services/crux/plan_steps/compile_release_notes.rb`, `draft_release_plan.rb` | create | Executors for the two new `action_type` values — read-and-format only (release notes), or draft-a-timeline (release plan); neither is destructive. |

### Implementation Notes

- **Transition-guard, not a status check.** A naive `if version.status == 'closed'` hook would re-fire on every subsequent unrelated save of an already-closed Version (e.g., editing its description later). The correct implementation checks the *transition into* closed specifically (Rails' `saved_change_to_status?` pattern, or equivalent), firing exactly once per close event. This is the first real-world stress test of crx-013's `EventDispatcher`, which anticipated exactly this usage in its own Implementation Notes.
- **"Coordinate with DevOps Agent" resolved narrowly**: Release Manager drafts a Deploy-shaped plan step DevOps Agent would otherwise draft, dispatched through the single-agent `Crux::Agents::Runner` (crx-004) path — not a live multi-agent conversational hand-off. **Why sufficient now**: Phase 3 doesn't need real-time negotiation between the two agents; a single agent producing the deploy step is enough to deliver "release plan coordination." **When to revisit**: crx-007's Agent Collaboration primitive (`parent_run_id`) is the natural mechanism if real DevOps↔Release Manager conversational hand-off is wanted later — flagged explicitly, not built here.
- **Any Deploy step Release Manager drafts reuses `PlanStep::DESTRUCTIVE_ACTIONS`** (crx-003) unchanged — no new destructive-action type, no separate gate. This is a direct application of crx-003's "centralized, single source of truth" design decision to a second agent.
- **Release notes compilation is read-only against completed issues** — no Core Platform write beyond the ordinary wiki-page-or-document-style output any Documentation-Agent-shaped deliverable already produces (crx-004's existing pattern).

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Release Manager enabled by default | New project after this task ships | `enabled: true` | pending |
| 2 | version_closed fires once | A Version transitions to closed | Exactly one plan drafted | pending |
| 3 | No re-fire on subsequent saves | The same Version is saved again (e.g. description edited) while still closed | No new plan drafted | pending |
| 4 | Deploy step requires destructive approval | Release Manager's plan includes a `deploy` step | Requires `crux:approve_destructive`, identical to DevOps Agent's existing Deploy gate | pending |
| 5 | Release notes accuracy | A version with 10 completed issues | Compiled notes reference exactly those 10, no fabrication | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end version-close trigger | Close a test Version | Release notes + release plan appear in Pending Actions, "Automated" badge (crx-013) | pending |
| 2 | Deploy-inclusive release plan | A release plan includes a Deploy step | The Deploy step alone requires `crux:approve_destructive`; the rest can be approved by a `crux:approve`-only user | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Version reopened and reclosed | A closed Version is reopened, then closed again | Fires again on the second close (a genuine new transition), not treated as a duplicate of the first | pending |
| 2 | Version closed with zero completed issues | No issues completed in that version | Produces a clear "no changes to report" output, not fabricated notes | pending |
| 3 | Release Manager disabled at close time | Version closes on a project where the agent is disabled | Firing skipped/fails cleanly (crx-013's Edge Case #1 pattern) | pending |

### QA Test Plan

**Scope**: Release Manager's real behavior, the version-close transition guard, and Deploy-step destructive gating.

**Pre-conditions**: crx-001 through crx-013 in place; a test project with a Version containing completed issues.

**QA Steps**:
1. Enable Release Manager; close a test Version; confirm release notes + plan appear, correctly badged.
2. Edit the closed Version's description afterward; confirm no duplicate firing.
3. Reopen and reclose the Version; confirm a fresh, second firing.
4. Include a Deploy step in a release plan; confirm it alone requires `crux:approve_destructive`.

**Expected Outcomes**: Firing happens exactly once per genuine close transition; Deploy steps are never approvable by a `crux:approve`-only user.

**Out of Scope**: Automated multi-environment release trains; live agent-to-agent negotiation.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | A naive `status == 'closed'` check would re-fire on every subsequent save of an already-closed Version — a real, predictable implementation bug given how common "edit a closed version's description later" is in practice. | Implementation Notes; Test Case Unit #3 | Explicit transition-guard specified (fires on transition, not on state), directly tested. |
| 2 | MEDIUM | "Coordinate with DevOps Agent" risked being over-built into a live multi-agent negotiation loop before crx-007's collaboration primitive could support it cleanly. | Implementation Notes | Resolved narrowly as single-agent dispatch, with an explicit flag for when to revisit via crx-007's mechanism. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | A Deploy step drafted by Release Manager must never be approvable via ordinary `crux:approve` alone — it must reuse crx-003's exact destructive gate, not a new/parallel check that could drift from DevOps Agent's identical requirement. | Test Case Unit #4, Functional #2 | Reuses `PlanStep::DESTRUCTIVE_ACTIONS` unchanged; explicitly tested. |
| 2 | LOW | No new indexing/performance concern beyond crx-013's already-established pattern. | — | No action needed. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — transition-guard and destructive-gate reuse are both concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Date/time comparison without timezone conversion | A Version's "closed at" timestamp compared inconsistently across timezones, causing the transition-guard to misfire near a day boundary | Not directly test-covered; flagged for implementation attention — use a consistent timezone (e.g. UTC) for transition-detection logic |
| 2 | Wrong `dependent:` on association | N/A — no new association introduced | Not applicable |
| 3 | Reopened/reclosed version treated as a duplicate | The transition-guard incorrectly suppresses a genuine second close after a reopen | Yes — Edge Case #1 |
| 4 | Fabricated output on empty data | Release notes generated even when no issues actually completed | Yes — Edge Case #2 |

Verdict: Approved. Item #1 is an implementation-time attention item since it's a configuration/timezone-consistency concern rather than independently testable business logic in this task's QA environment.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
