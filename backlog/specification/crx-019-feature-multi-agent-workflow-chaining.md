## Metadata
- **Task ID**: crx-019-feature-multi-agent-workflow-chaining
- **Title**: Multi-Agent Workflows — N-agent hand-off chaining (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `future_scope.md`, `architecture.md`, `workflow_engine.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Generalizes crx-007's two-agent hand-off (`parent_run_id`) into support for arbitrarily long sequential agent chains within one already-approved execution plan — `future_scope.md`'s own cited example: Requirement Analyst → Planner → Developer → QA → Code Reviewer → Release Manager — so the full sequence can be reconstructed and displayed as one traceable thing in the Runs tab, not inferred by a human joining rows by hand. This task's job is dispatch generalization (`Crux::Agents::Runner` hands its output to the *next* plan step's assigned agent automatically, not just two hardcoded roles) plus chain reconstruction/audit tooling. It does not invent hand-off chaining from a blank slate — it extends crx-007's already-approved column and reasoning.

**Goal**:

An approved multi-step plan involving several different agents' steps executes as one traceable, sequential chain; the Runs tab can display the entire sequence — who did what, in what order, with what outcome — as a single reconstructable unit, without a human manually joining `parent_run_id` rows by hand.

**Objectives**:
- [ ] Add `crux_runs.chain_root_run_id` (nullable, self-referential FK) and `.chain_position` (nullable integer) — denormalized so an N-hop chain is retrievable in one indexed query instead of a recursive `parent_run_id` walk.
- [ ] Generalize `Crux::Agents::Runner` (crx-004/007) dispatch: on a plan step's completion, automatically hand off to the next plan step's assigned agent within the same approved plan, in declared order (`workflow_engine.md`'s existing "steps execute in their declared order by default" rule, unchanged).
- [ ] Every hop remains an ordinary plan step inside one human-approved execution plan — an agent's output surfacing a wholly new, previously-unplanned step for another agent does **not** auto-continue the chain; it creates a new `awaiting_approval` plan step, going back through the normal gate.
- [ ] A failed hop (retried via crx-003's existing Retry Manager) still gets `chain_root_run_id` set and appears in the reconstructed chain view — full audit fidelity over a "clean" but incomplete picture.
- [ ] Build a Runs-tab chain view: given any run, display its full chain (all hops, in order, with status).

**Deliverables**:
- [ ] Migration: `crux_runs.chain_root_run_id`, `.chain_position` (+ composite index).
- [ ] `Crux::Agents::Runner` dispatch generalization for N-hop, multi-step plans.
- [ ] Runs tab chain-reconstruction view.

**Out of Scope**: The formal, first-class hand-off primitive with its own auditable lifecycle (`future_scope.md`'s Multi-agent hand-off chains — explicitly beyond Phase 4, speculative future work); agent-to-agent negotiation prior to plan submission (`agent_catalog.md` Future Enhancements — a materially different, still-ungoverned mechanism, not built here); parallel (non-sequential) multi-agent execution (`workflow_engine.md`'s own Future Enhancements lists this separately — "parallel execution for steps with no data dependency"; this task's chains remain strictly sequential); cross-project chains (`future_scope.md`'s organization-wide knowledge retrieval area, not this task).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration on the append-only `crux_runs` table; generalizes `Runner`'s dispatch logic away from a hardcoded two-step sequence; touches Workflow Engine, Agent Engine, and a new Runs-tab UI surface simultaneously. Matches the new-migration + architecture-defining-interface criterion crx-004/007 used for their own HIGH ratings.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_add_chain_columns_to_crux_runs.rb` | create | `crux_runs.chain_root_run_id` (nullable, self-referential FK), `.chain_position` (nullable integer, 0-based); composite index `(chain_root_run_id, chain_position)`. |
| `app/services/crux/agents/runner.rb` (crx-004/007) | modify | On dispatch, if the invoking plan step is part of a multi-step plan with more than one distinct agent assignment, sets `chain_root_run_id` (the first hop's own run id, or inherited from the prior hop) and `chain_position` (incremented from the prior hop, or 0 for the first). Reuses `parent_run_id` (crx-007) unchanged for the immediate-predecessor edge — this task adds the denormalized root/position pair *alongside* it, not instead of it. |
| `app/services/crux/workflow_engine.rb` (crx-003) | modify | Plan-step executor (already executes "in declared order by default") now automatically triggers the next step's agent dispatch on the current step's completion, within the same approved plan — no new approval step is introduced for this automatic continuation, since the *whole plan* was already approved as a unit. |
| `app/services/crux/agents/chain_reconstructor.rb` | create | `#for(run:)` — one indexed query via `chain_root_run_id` returning every hop in `chain_position` order. |
| `app/views/project_crux_runs/_chain.html.erb` | create | Renders a reconstructed chain: each hop's agent, status, and attribution, in order. |

### Implementation Notes

- **How far chaining goes before deferring to `future_scope.md`'s "formal hand-off primitive."** This task treats a chain as **N independent, append-only `crux_runs` rows linked by `chain_root_run_id`/`chain_position`** — not a new first-class object with its own lifecycle/status. It stops short of introducing a `crux_agent_handoffs` table with its own state machine, certification, or retry semantics distinct from the plan step retry semantics `workflow_engine.md` already owns. **Why sufficient now**: every hop is still a plan step executing inside one Workflow-Engine-owned plan, so existing retry/rejection/approval mechanics apply unmodified — no parallel state machine is needed to get audit fidelity for N hops instead of 2. **When to revisit**: once `future_scope.md`'s formal hand-off primitive is actually pulled into a future roadmap phase and needs, e.g., partial-chain replay or hand-off-level (not run-level) retry.
- **Chains stay inside one approved plan; they don't bypass approval per hop.** Every hop is a plan step that was already part of the human-approved execution plan — no engine change needed to `workflow_engine.md`'s existing ordered-execution rule. An agent's output surfacing a wholly new, previously-unplanned step for another agent does **not** auto-continue the chain; it creates a new `crux_plan_steps` row in `awaiting_approval`, going back through the normal gate. **Why**: this is the direct, load-bearing application of `integrations.md`'s universal governance rule ("an integration can trigger a plan step, but write-back to Redmine still goes through the normal approval gate") to the agent-to-agent case, and it's the reason this task is *not* the same thing as `agent_catalog.md`'s Future Enhancement "agent-to-agent negotiation before a plan is submitted for approval" — negotiation-before-submission is a materially different, still-ungoverned mechanism, explicitly out of scope.
- **Failed hops stay in the chain.** A hop that fails and retries (crx-003's existing fallback/retry mechanics) still gets chain columns set and appears in the reconstructed view, rather than being silently excluded — full audit fidelity over a "clean" but incomplete picture.
- **`chain_root_run_id`/`chain_position` are denormalized specifically to avoid a fragile recursive `parent_run_id` walk** that gets slower and more error-prone as N grows — a direct, explicit design choice over the alternative of just querying `parent_run_id` recursively.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Chain columns set correctly across N hops | A 5-step plan involving 5 different agents | All 5 runs share `chain_root_run_id`; `chain_position` is 0,1,2,3,4 in order | pending |
| 2 | parent_run_id still set alongside chain columns | Same scenario | Each hop's `parent_run_id` still points to its immediate predecessor (crx-007's column, unchanged) | pending |
| 3 | Failed hop remains in the chain | One hop fails and retries (crx-003) | The retried run still carries correct chain columns and appears in reconstruction | pending |
| 4 | Chain reconstruction query performance | A 10-hop chain | Retrieved in one indexed query, no recursive walk | pending |
| 5 | New unplanned step still requires approval | An agent's output implies a step not in the original approved plan | New `awaiting_approval` plan step created, not auto-continued into the chain | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end multi-agent plan | Approve a plan with steps for Requirement Analyst, Planner, Developer, QA Agent, Code Reviewer, Release Manager | All 6 execute in declared order automatically, forming one reconstructable chain | pending |
| 2 | Runs tab chain view | Open a run that's part of a chain | Full chain displayed with agent/status/order for every hop | pending |
| 3 | Chain with a mid-chain failure | One hop fails, retries, then succeeds | Chain view shows the failure and retry, not a silently "clean" record | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Single-agent plan (no chain) | A plan with only one agent's steps | `chain_root_run_id`/`chain_position` remain null — not every run is forced into a chain | pending |
| 2 | Chain spanning a rejected/modified plan | A plan is rejected mid-chain and returns to `planned` (crx-003) | The partial chain up to that point remains visible/auditable; the plan's later re-approval starts a fresh continuation, not a corrupted chain | pending |
| 3 | Cyclic chain attempt | A crafted scenario where a hop's next-step assignment would loop back to an earlier agent in the same chain | Rejected/detected — a chain must not cycle, consistent with crx-007's existing cycle-prevention rule extended to N hops | pending |

### QA Test Plan

**Scope**: N-agent sequential dispatch generalization, chain column correctness, and the Runs-tab chain reconstruction view.

**Pre-conditions**: crx-001 through crx-018 in place, with the full 12-agent roster available (crx-014/015/016 completing it).

**QA Steps**:
1. Approve a plan spanning at least 4 different agents; confirm automatic sequential dispatch.
2. Confirm the Runs tab shows the full chain as one reconstructable unit.
3. Force a mid-chain failure/retry; confirm it remains visible in the chain.
4. Confirm a single-agent plan doesn't get forced chain columns.

**Expected Outcomes**: Every multi-agent plan's execution is fully auditable as one traceable sequence; no hop ever bypasses the approval gate that governed the whole plan.

**Out of Scope**: True parallel execution; agent-to-agent negotiation before approval.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked building a full first-class hand-off primitive (its own table, lifecycle, retry semantics) — directly contradicting `future_scope.md`'s own framing that this remains speculative, beyond-Phase-4 work. | Implementation Notes | Explicitly scoped to denormalized columns on the existing append-only `crux_runs`, not a new object. |
| 2 | HIGH | Recursive `parent_run_id` walks to reconstruct a chain would get fragile/slow as N grows. | Code Changes, migration row | Denormalized `chain_root_run_id`/`chain_position` added specifically to avoid this. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Automatic sequential dispatch across N agents must never let a new, previously-unplanned step skip the approval gate — the single biggest risk this task could introduce. | Test Case Unit #5 | Explicitly tested: unplanned steps always require fresh approval. |
| 2 | MEDIUM | A cyclic chain (a hop looping back to an earlier agent) could cause an infinite dispatch loop. | Test Case Edge #3 | Explicit cycle-prevention, extending crx-007's existing rule. |
| 3 | LOW | Missing index on `(chain_root_run_id, chain_position)` would make chain reconstruction slow at scale. | Code Changes, migration row | Composite index explicitly specified. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — denormalized-not-first-class-object scoping, approval-gate preservation for unplanned steps, cycle prevention, and required indexing are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Forcing chain columns onto single-agent plans | Every run gets a `chain_root_run_id` even when there's no real chain, creating noise in the Runs tab | Yes — Edge Case #1 |
| 2 | Chain corruption across a reject/modify cycle | A rejected-and-resubmitted plan's chain columns become inconsistent | Yes — Edge Case #2 |
| 3 | Missing `.includes` for chain reconstruction | The chain view N+1 queries each hop's agent/status individually | Not directly test-covered by a UI test; flagged for implementation attention — the reconstruction query must eager-load agent data |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
