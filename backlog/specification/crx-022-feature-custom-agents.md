## Metadata
- **Task ID**: crx-022-feature-custom-agents
- **Title**: Custom Agents — organization-authored agents (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `agent_catalog.md`, `future_scope.md`, `billing.md`, `security.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Lets an organization author its own agent outside the fixed 12-role catalog — a genuinely new `crux_agents` row with an org-written prompt template, model/provider assignment (crx-008), and full participation in every existing governance mechanic (Run Ledger, Approval Engine, Knowledge Engine permission filtering) exactly like a catalog agent. This is the direct prerequisite for crx-023 (Marketplace): a marketplace listing is fundamentally "a custom agent, packaged for distribution," so authoring must exist as a private, single-org capability first. This task also finally resolves, in code, the tension the documentation set itself carries: `security.md` states as a settled Design Decision that "Agents are Users," while `architecture.md`/`roadmap.md` still list this as an unresolved Open Question — crx-007 already made the call (no Core Platform identity row) for the fixed catalog; this task inherits that ruling rather than re-deciding it, since custom agents are the first place it becomes genuinely load-bearing at scale.

**Goal**:

A user holding a new, distinct permission (`crux:author_agents`) can write a custom agent's prompt template, assign it a provider/model (crx-008), and enable it on a project — where it behaves identically to any catalog agent: subject to the Approval Gate, recorded in the Run Ledger, permission-filtered by Knowledge Engine, attributed via badges. A custom agent is visibly distinguished from the 12 catalog agents so no one mistakes its output for a well-understood, doc-defined behavior.

**Objectives**:
- [ ] Add `crux_agents.origin` (`catalog`/`custom`/`marketplace`), `.author_user_id` (nullable FK), `.description` (nullable text) — breaking `agent_catalog.md`'s own prior Assumption that all 12 agents share one schema with "no bespoke fields," deliberately, for the first time.
- [ ] Introduce a new permission, `crux:author_agents`, distinct from `crux:manage_agents` (which continues to gate enabling/disabling/model-reassignment of an *existing* agent, catalog or custom) — authoring a wholly new prompt template that then runs with a project's actual Redmine access is a materially higher-trust action.
- [ ] Gate Custom Agent creation at the same billing tier as full prompt-template editing (`billing.md`'s Team/Enterprise "Full pipeline + prompt-template editing" row) — Starter gets zero custom-agent capability.
- [ ] Extend attribution badges (crx-004/007) to visibly distinguish custom/marketplace agents from catalog agents (e.g. a "Custom" tag).
- [ ] Confirm a custom agent may only select from providers/servers already configured by `crux:administer`/`crux:manage_integrations` — it cannot self-provision new outbound Provider Layer or MCP configuration.
- [ ] Inherit crx-007's agent-identity resolution (no Core Platform `User`/`Member` row) for custom agents as well — not re-decided here.

**Deliverables**:
- [ ] Migration: `crux_agents.origin`, `.author_user_id`, `.description`.
- [ ] New permission: `crux:author_agents`.
- [ ] `Crux::Agents::Author` — the prompt-template authoring flow (structural sections, same as catalog agents' `agent_catalog.md`-derived shape).
- [ ] Tier-gate check reusing crx-011's `TierPolicy` (Team/Enterprise required).
- [ ] Attribution badge extension for `custom`/`marketplace` origin.

**Out of Scope**: Distribution/listing of a custom agent to other projects/orgs (crx-023); certification/vetting of custom agent quality or safety (`future_scope.md`'s Marketplace growth "certification tier," explicitly future, not decided here); a custom agent registering its own new Provider or MCP server (it may only select from already-configured ones — no self-provisioning); cross-project reuse of one project's custom agent without going through crx-023 (no informal "clone this agent into another project" shortcut).

---

## Specification

**Complexity**: HIGH

**Reason**: New migration on `crux_agents` — previously described as one schema shared identically by all 12 agents with "no bespoke fields" per `agent_catalog.md`'s own Assumptions, a deliberate break from that pattern; plus a new permission (a security-model change, the same category of finding that made crx-001's permission remapping a HIGH item); plus this is the direct architectural seam crx-023 (Marketplace) extends. Matches the new-migration + security-changes + architecture-defining-interface criteria.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_add_custom_agent_fields_to_crux_agents.rb` | create | `crux_agents.origin` (enum `catalog`/`custom`/`marketplace`, default `catalog` for existing rows), `.author_user_id` (nullable FK → Redmine User), `.description` (nullable text). |
| `init.rb` | modify | Register `crux:author_agents` as a new permission, distinct from `crux:manage_agents`. |
| `app/services/crux/agents/author.rb` | create | The authoring flow: validates a prompt template's structural sections, assigns provider/model from crx-008's already-configured set only, creates the `crux_agents` row with `origin: 'custom'`, `author_user_id: User.current`. |
| `app/services/crux/billing/tier_policy.rb` (crx-011) | modify | Add a check: custom agent creation requires the same tier as full prompt-template editing (Team/Enterprise). |
| `app/controllers/project_crux_agents_controller.rb` (crx-004) | modify | Add a "create custom agent" action, gated `crux:author_agents` **and** the tier check — both must pass. |
| `app/views/shared/_crux_attribution_badge.html.erb` (crx-004/007) | modify | Shows a "Custom" tag for `origin: custom`/`marketplace` agents, distinguishing them from the 12 catalog agents' well-understood behavior. |

### Implementation Notes

- **A new permission, `crux:author_agents`, is introduced** — distinct from `crux:manage_agents`. **Why**: authoring a wholly new prompt template that then runs with a project's actual Redmine access is a materially higher-trust action than toggling a pre-vetted catalog agent on or off; conflating the two would let anyone who can currently flip Planner's `enabled` flag also write arbitrary custom agent logic, a bigger blast-radius jump than `crux:manage_agents` was ever scoped for. **Why this is safe to do now despite `security.md`'s "9 canonical permissions" framing**: `future_scope.md`'s own Open Questions already anticipate this exact tension ("does [marketplace certification] require a new permission beyond the nine already defined in `security.md`?") — this resolves it one step earlier and more narrowly (authoring, not certification), with an explicit call to reconcile `security.md`'s permission table at implementation time rather than treating the 9-permission count as immovable.
- **Custom Agent creation is tier-gated at the same level as full prompt-template editing** (`billing.md`'s Team/Enterprise row), even though `billing.md`'s tier table doesn't name "creating a new agent" as its own row. **Why sufficient now**: creating an agent is a superset of editing one's prompt template, so gating it no lower than that tier is the conservative, defensible reading; a Starter-tier org gets zero custom-agent capability, consistent with Starter's "prompt text only" ceiling. **When to revisit**: if commercial strategy wants a narrower/cheaper tier specifically for custom agents, that's `future_scope.md`'s "new pricing models" territory, not this task's call to make unilaterally.
- **Attribution badges must visibly distinguish custom/marketplace agents from catalog agents** so a chat/plan-step viewer can't mistake a third-party-authored agent's output for one of the twelve governed catalog agents' well-understood behavior — directly protects the trust model `vision.md`'s "trust recovery" risk (echoed in `future_scope.md`'s Marketplace trust risk) depends on.
- **A custom agent may only select from providers/servers already configured by `crux:administer`/`crux:manage_integrations`** — it cannot self-provision new outbound configuration, preserving the existing admin-gated configuration model unchanged.
- **Agent identity is inherited from crx-007's ruling, not re-decided**: no Core Platform `User`/`Member` row for a custom agent either — attribution stays within `crux_agents`/`crux_runs.agent_id`, `author_user_id` records provenance only, not standing authority.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Permission gate — authoring | User with `crux:manage_agents` but not `crux:author_agents` | Cannot create a custom agent | pending |
| 2 | Permission gate — allowed | User with `crux:author_agents` on a Team-tier org | Can create a custom agent | pending |
| 3 | Tier gate | Starter-tier org, user with `crux:author_agents` | Creation refused with a "requires Team" message | pending |
| 4 | Provider restriction | Custom agent authoring flow attempts to specify a provider not already configured | Rejected — cannot self-provision | pending |
| 5 | Origin defaults correctly | Existing (pre-migration) `crux_agents` rows | All backfilled to `origin: 'catalog'` | pending |
| 6 | Custom agent participates in Run Ledger identically | A custom agent's invocation | Produces a `crux_runs` row exactly like a catalog agent's | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end custom agent creation | As an authorized Team-tier user, author a custom agent, enable it on a project, invoke it | Behaves identically to a catalog agent — approval-gated, Run Ledger recorded, Knowledge Engine permission-filtered | pending |
| 2 | Attribution badge distinguishes custom agents | View a custom agent's chat message/plan step | Shows a visible "Custom" tag, distinct from catalog agents | pending |
| 3 | Custom agent respects Knowledge Engine filtering | Custom agent invoked by a user without access to some content | Content excluded identically to any catalog agent (crx-005's filter-before-rank, unmodified) | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Org downgrades from Team to Starter after custom agents exist | Existing custom agents | Continue to function (not retroactively disabled), but no *new* custom agent can be created until re-upgrading — consistent with crx-011's "live plan lookup at the moment of the action" | pending |
| 2 | Custom agent authored by a user who later loses `crux:author_agents` | The already-created agent | Continues to exist and function; the permission only gates *creation*, not continued operation | pending |
| 3 | Custom agent attempts a destructive action type | Authoring flow includes a `deploy`/`delete_*` step in its prompt-driven output | Still requires `crux:approve_destructive` exactly like any catalog agent — no bypass for custom agents | pending |

### QA Test Plan

**Scope**: Custom agent authoring permission/tier gating, provider restriction, Run Ledger/Approval Gate/Knowledge Engine parity with catalog agents, and attribution badge distinction.

**Pre-conditions**: crx-001 through crx-021 in place; a Team-tier (or higher) test org; a user with `crux:author_agents`.

**QA Steps**:
1. As an authorized user, author a custom agent; confirm it can only select already-configured providers.
2. Enable it on a project; invoke it; confirm identical governance behavior to a catalog agent.
3. Confirm its attribution badge is visibly distinct.
4. As a Starter-tier user with `crux:author_agents`, attempt creation; confirm refusal.
5. Confirm a custom agent's destructive-action step still requires `crux:approve_destructive`.

**Expected Outcomes**: Custom agents are fully governed exactly like catalog agents, distinguishable in the UI, and gated by both permission and tier.

**Out of Scope**: Marketplace distribution (crx-023).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked reusing `crux:manage_agents` for authoring too, conflating "toggle an existing agent" with "write arbitrary new agent logic" — a real privilege-scope mismatch. | Implementation Notes | New `crux:author_agents` permission introduced specifically. |
| 2 | MEDIUM | `agent_catalog.md`'s own Assumption ("all 12 agents share one schema... no bespoke fields") is being broken here — needed explicit acknowledgment rather than a silent schema drift. | Planning, Description | Explicitly called out as a deliberate, first-time break from that prior Assumption. |
| 3 | LOW | Attribution badges risked not distinguishing custom agents from catalog agents, a trust-model gap given `vision.md`'s own "trust recovery" risk. | Implementation Notes | Explicit "Custom" tag requirement. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | A custom agent must not be able to self-provision a new Provider or MCP server credential — that would let an authoring user indirectly gain outbound-credential-configuration power without holding `crux:administer`/`crux:manage_integrations`. | Test Case Unit #4 | Explicitly restricted to already-configured providers/servers; directly tested. |
| 2 | HIGH | A custom agent's destructive-action steps must still require `crux:approve_destructive` — no bypass for non-catalog agents. | Test Case Edge #3 | Explicitly tested; reuses crx-003's centralized `DESTRUCTIVE_ACTIONS` check unmodified. |
| 3 | MEDIUM | Tier-gating needed a live-lookup check (crx-011's pattern), not a check cached at some earlier point, given orgs can change tier at any time. | Edge Case #1 | Explicitly reuses crx-011's "live plan lookup" behavior. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the new permission, provider-self-provisioning restriction, destructive-gate reuse, and live tier-lookup are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Silent mass-assignment via a missing `permit` key | The authoring form accepts a `provider` value not already configured, bypassing the restriction | Yes — Unit Test #4 |
| 2 | Permission checked only at creation, not re-verified | A custom agent's continued operation incorrectly re-checks `crux:author_agents` on every invocation instead of only at creation | Yes — Edge Case #2 explicitly clarifies the permission only gates creation |
| 3 | Retroactive disabling on tier downgrade | An org downgrade incorrectly disables existing custom agents instead of only blocking new creation | Yes — Edge Case #1 |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
