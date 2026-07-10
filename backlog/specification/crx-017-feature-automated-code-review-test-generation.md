## Metadata
- **Task ID**: crx-017-feature-automated-code-review-test-generation
- **Title**: Automated Code Review & Test Generation Triggers (Phase 3)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `agent_catalog.md`, `integrations.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Delivers roadmap Phase 3's "Code Review" and "Test Generation" capabilities. **Neither is a new agent** — Code Reviewer (crx-007, Phase 2 GA) and QA Agent (crx-004, Phase 1 GA) already exist. This task wires two already-named-but-unbuilt trigger seams: Code Reviewer's own Execution Flow line ("invoked from Chat Engine **or an Integration Engine webhook**," `agent_catalog.md`) and `integrations.md`'s own canonical GitHub scenario verbatim ("A GitHub PR is merged... the webhook reaches the Integration Engine, which raises an intent for the QA Agent to draft a regression test plan"). This is distinct from crx-009's GitHub Integration (generic webhook ingestion + Intent-Detection classification, already *capable* of eventually reaching either agent) — this task's contribution is a curated, admin-opted-in deterministic policy pinning exactly these two event/agent pairs, skipping per-event classification for these two high-confidence, already-named combinations.

**Goal**:

A project can opt into: PR-opened events routing deterministically to Code Reviewer (rather than relying on generic Intent Detection classification every time), and PR-merged events routing deterministically to QA Agent for a regression test plan — matching `integrations.md`'s own literal worked example.

**Objectives**:
- [ ] Extend `crux_automation_policies` (crx-013) with an `integration_id` column (nullable FK → `crux_integrations`) — this is the first task introducing an integration-scoped (not just project-scoped) trigger.
- [ ] Extend the policy's `event_name` domain with `github_pr_opened`, `github_pr_merged`.
- [ ] Wire `github_pr_opened` → Code Reviewer (crx-007's webhook path, already built in crx-009 — this task adds the deterministic policy layer on top).
- [ ] Wire `github_pr_merged` → QA Agent regression test plan, matching `integrations.md`'s literal example.
- [ ] Both remain approval-gated exactly as crx-009's generic webhook path already established — no bypass.

**Deliverables**:
- [ ] Migration: `crux_automation_policies.integration_id`.
- [ ] `Crux::Automations::EventDispatcher` (crx-013) extended to accept integration-scoped policies alongside project-scoped ones.
- [ ] Two deterministic policy handlers: `github_pr_opened → code_reviewer`, `github_pr_merged → qa_agent`.
- [ ] `ProjectCruxAutomationsController` UI: opt-in toggles for these two specific curated policies, distinct from generic webhook handling.

**Out of Scope**: Bitbucket/Azure DevOps equivalents (only GitHub is Phase 2 GA); any new review/test-generation logic beyond what Code Reviewer/QA Agent already produce (this task adds the trigger only); generalizing to arbitrary webhook→agent policy authoring (deferred per crx-013's Implementation Notes to Phase 4, once Future Marketplace's custom-step-type mechanism exists); resolving `integrations.md`'s Open Question on two-way sync/conflict resolution — untouched here.

---

## Specification

**Complexity**: HIGH

**Reason**: First bridge from external, untrusted integration input into the automation-trigger path — `integrations.md`'s own Risks section names exactly this ("webhook/email bodies can carry adversarial content... must be treated as untrusted input"), and this task's entire point is deterministic routing that skips Intent Detection's usual classification safety net for these two named pairs, raising the validation bar. Also needs webhook-redelivery idempotency distinct from crx-013's cadence-based dedup. Matches the security-sensitivity + cross-module-impact criteria.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_add_integration_id_to_crux_automation_policies.rb` | create | `crux_automation_policies.integration_id` (nullable FK → `crux_integrations`); nullable because crx-013's/crx-014's/crx-016's policies remain project-scoped, not integration-scoped. |
| `app/services/crux/automations/event_dispatcher.rb` (crx-013) | modify | Extended to also match policies by `(integration_id, event_name)`, not only `(project_id, event_name)`. |
| `app/services/crux/integrations/git_hub.rb` (crx-009) | modify | Emits `github_pr_opened`/`github_pr_merged` as named events into `EventDispatcher`, alongside its existing generic Intent-Detection routing — this task's curated policies take the deterministic path *instead of* generic classification for these two specific event types, when the corresponding policy is enabled. |
| `db/seeds/crux_automation_policies_curated.rb` | create | Two reference policy definitions (`github_pr_opened → code_reviewer`, `github_pr_merged → qa_agent`), toggleable per project, not auto-enabled. |
| `app/controllers/project_crux_automations_controller.rb` (crx-009/013) | modify | UI toggle for these two curated policies, clearly distinguished from generic GitHub webhook configuration. |

### Implementation Notes

- **Curated determinism, not new classification.** Distinguishes Phase 2's GitHub Integration (generic webhook ingestion + Intent-Detection classification, already sufficient to *eventually* reach either agent) from this task's contribution (a curated, admin-opted-in deterministic policy for exactly these two event/agent pairs — the only two combinations named anywhere in the doc set). **Why sufficient now**: these are the only two GitHub-event-to-agent combinations `agent_catalog.md`/`integrations.md` name verbatim; a general webhook→agent policy-authoring UI is speculative beyond what's committed. **When to revisit**: generalizing to arbitrary webhook→agent policy authoring is deferred to Phase 4, once Future Marketplace's custom-step-type mechanism (`workflow_engine.md` Future Enhancements) exists.
- **Untrusted input, still.** This task's deterministic routing does *not* relax crx-009's HMAC signature verification or its "treat webhook content as untrusted input" posture — deterministic routing only changes *which agent* is dispatched, never *whether* the payload is trusted or *whether* the approval gate applies.
- **Webhook-redelivery idempotency is distinct from crx-013's cadence-based dedup** — GitHub may redeliver the same event (a documented platform behavior, already tested in crx-009's Edge Case #3); this task's curated policies reuse that same event-id-based dedup, not a new mechanism.
- **Not resolving two-way sync** (`integrations.md`'s own Open Question) — these are one-shot, event-triggered actions, exactly like crx-009's GitHub connector already established.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | PR-opened routes to Code Reviewer | Curated policy enabled, PR opened event received | Code Reviewer dispatched deterministically, not via generic classification | pending |
| 2 | PR-merged routes to QA Agent | Curated policy enabled, PR merged event received | QA Agent drafts a regression test plan, matching `integrations.md`'s literal example | pending |
| 3 | Policy disabled — falls back to generic path | Curated policy disabled | The event still reaches Intent Detection generically (crx-009's existing path), just not deterministically routed | pending |
| 4 | Signature verification still applies | An unsigned payload claiming a PR-opened event | Rejected before reaching either the generic or curated path, per crx-009's existing gate | pending |
| 5 | Redelivery dedup | The same PR-merged event delivered twice | No duplicate QA Agent dispatch | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end curated PR review | Enable the PR-opened curated policy; open a PR | Code Reviewer's review appears in Pending Actions, approval-gated identically to crx-009's generic path | pending |
| 2 | End-to-end curated regression plan | Enable the PR-merged curated policy; merge a PR | QA Agent's regression test plan appears, approval-gated | pending |
| 3 | Toggle UI clarity | Project → Automations | The two curated policies are clearly distinguished from generic GitHub webhook config | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Both curated policies enabled, generic classification also active | A PR-opened event | Curated policy takes precedence for its specific event type; no double-dispatch (both curated and generic routing firing for the same event) | pending |
| 2 | Malicious PR content | An adversarial PR title/description crafted to manipulate Code Reviewer's output | Treated as untrusted input fed into context, not as an instruction — normal output-routing (direct reply vs. plan step) still applies | pending |

### QA Test Plan

**Scope**: The two curated deterministic policies, their interaction with crx-009's generic webhook path, and confirmation that neither weakens signature verification or the approval gate.

**Pre-conditions**: crx-001 through crx-013 in place (crx-007 for Code Reviewer, crx-004 for QA Agent, crx-009 for GitHub webhook infrastructure).

**QA Steps**:
1. Enable the PR-opened curated policy; open a test PR; confirm deterministic Code Reviewer dispatch.
2. Enable the PR-merged curated policy; merge a test PR; confirm deterministic QA Agent dispatch.
3. Disable both; confirm the generic classification path (crx-009) still handles these events, just non-deterministically.
4. Redeliver an event; confirm no duplicate dispatch.

**Expected Outcomes**: Curated routing never bypasses signature verification or the approval gate; disabling curated policies gracefully falls back to crx-009's existing generic behavior.

**Out of Scope**: Any integration beyond GitHub; general policy authoring.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Without a clear distinction, "curated deterministic routing" risked being conflated with "new agents" or "new capability" — when in fact both agents already exist and this task only adds a trigger. | Planning, Description | Explicitly framed as wiring existing seams, not new agents. |
| 2 | MEDIUM | Enabling both curated and generic classification simultaneously for the same event type risked double-dispatch if not explicitly resolved. | Test Case Edge #1 | Explicit precedence rule: curated policy takes over for its specific event type, no double-dispatch. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Deterministic routing must not relax crx-009's untrusted-input posture or signature verification — a curated "fast path" is exactly the kind of shortcut that could tempt skipping validation. | Test Case Unit #4 | Explicitly confirmed unchanged; directly tested. |
| 2 | MEDIUM | Redelivery idempotency, already solved once in crx-009, needed explicit confirmation it applies to the curated path too rather than assuming it "just works." | Test Case Unit #5 | Explicitly retested for the curated path. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the existing-agents framing, double-dispatch precedence rule, unchanged signature verification, and redelivery dedup are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Untrusted input treated as pre-authorized instruction | Adversarial PR content manipulating agent output via a "faster," less-scrutinized curated path | Yes — Edge Case #2 |
| 2 | Double-dispatch on overlapping policies | Both curated and generic routing fire for the same event | Yes — Edge Case #1 |
| 3 | Missing index on the new `integration_id` column | Slow policy lookups as event volume grows | Not directly test-covered (low volume at Phase 3 scale); flagged for implementation attention — index the new FK per `database_design.md`'s existing convention |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
