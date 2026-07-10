## Metadata
- **Task ID**: crx-020-feature-mcp-inbound
- **Title**: MCP Inbound — Crux as MCP server (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `integrations.md`, `security.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Exposes a defined set of Redmine operations as MCP tools so an external MCP client (Claude Code, Cursor, etc.) can connect, pull the tasks assigned to a specific Redmine user, and write results back — with every write-implying tool call routed through the existing plan → approval → execution path, identically to a webhook (`integrations.md`'s Sequence Flow). This is Crux's first genuinely *inbound* credential surface (crx-006's OpenAI key was Crux's first *outbound* one) — a bearer-token auth model scoped to the token owner's own Redmine permissions, never a standing agent-level authority. Per `integrations.md`'s own explicit Design Decision ("MCP is two capabilities, not one"), this task covers inbound only; outbound is crx-021.

**Goal**:

A user can generate an MCP token scoped to one project; an external MCP client using that token can list/read the user's assigned issues and propose a change, which enters the normal approval-gated plan flow attributed to that user — never with more access than the user already has in the Redmine UI.

**Objectives**:
- [ ] Add `crux_mcp_tokens` table: `user_id`, `project_id`, hashed token, `revoked_at`, `last_used_at`.
- [ ] Implement a narrow, deliberately limited GA tool surface: read/list/get operations plus "propose a change" (creates an ordinary `awaiting_approval` plan step) — **no destructive-action-type tool exposed via MCP inbound at all**, even though `crux:approve_destructive` would still gate its execution if it existed.
- [ ] Token scope is per-project, not account-wide, even though functionally a token just proxies the user's own already-project-scoped Redmine permissions.
- [ ] An inbound tool call that implies a write synthesizes a `crux_conversations` row (entering directly at `planned`, skipping `draft`/`clarifying` since the MCP client supplied complete parameters), attributed to the token's owning user — reusing Workflow Engine/Approval Engine/Run Ledger entirely unmodified.
- [ ] Token generation/revocation UI, gated by the user's own action (a user can only manage their own tokens — no admin-issued tokens on a user's behalf).

**Deliverables**:
- [ ] Migration: `crux_mcp_tokens`.
- [ ] `Crux::Mcp::Server` — the tool-exposing endpoint, authenticated by bearer token.
- [ ] Token generation/revocation UI (Project Workspace, user-scoped).
- [ ] Tool definitions: `list_assigned_issues`, `get_issue`, `propose_change` (the only write-capable tool, non-destructive only).

**Out of Scope**: MCP outbound (crx-021 — different trust boundary, different code path per `integrations.md`'s own explicit split); destructive-action MCP tools (deferred to `future_scope.md`'s MCP ecosystem growth); cross-project single-token convenience (same); vetting/certification of *which* external MCP clients may connect (not named anywhere in the doc set, not invented here — a token, once issued, works with any compliant client).

---

## Specification

**Complexity**: HIGH

**Reason**: This is the plugin's first *inbound* credential/auth surface, meaning a leaked token is a new class of external-attacker risk distinct from anything shipped so far (previous credentials were all outbound-only, held entirely server-side). Matches the global security-changes criterion, the same rubric line crx-006/009 used.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_mcp_tokens.rb` | create | `crux_mcp_tokens(id, user_id, project_id, token_digest, revoked_at, last_used_at, created_at)` — token stored hashed at rest, never in plaintext, matching crx-006's credential-security posture. |
| `app/models/crux/mcp_token.rb` | create | `belongs_to :user`, `belongs_to :project`; `#authenticate(raw_token)` compares digest, checks `revoked_at.nil?`. |
| `app/services/crux/mcp/server.rb` | create | Bearer-token-authenticated MCP server exposing the narrow tool surface; resolves the calling context to the token's `user`/`project`, never a broader identity. |
| `app/services/crux/mcp/tools/list_assigned_issues.rb`, `get_issue.rb` | create | Read-only tools, scoped to what `Issue.visible(token.user)` already returns — no new visibility logic, reuses Redmine's own scopes. |
| `app/services/crux/mcp/tools/propose_change.rb` | create | The only write-capable tool: creates a `crux_conversations` row (state: `planned`) + a `crux_execution_plans`/`crux_plan_steps` row (state: `awaiting_approval`), attributed to `token.user`, non-destructive action types only — destructive `action_type`s are rejected by this tool outright. |
| `app/controllers/crux_mcp_tokens_controller.rb` | create | User-scoped token generation/revocation UI — a user manages only their own tokens, no admin-on-behalf-of issuance. |

### Implementation Notes

- **Token scope is per-project, not account-wide**, even though functionally a token just proxies the user's own permissions (which are already project-scoped in Redmine). **Why sufficient now**: narrows blast radius on leak — a compromised token only ever grants what that project's role already allows, not every project the user happens to touch — at negligible added complexity (one row per project a user actively uses MCP against). **When to revisit**: if `future_scope.md`'s MCP ecosystem growth area wants single-token convenience across many projects, that's a deliberate trade-off to make later, not a default now.
- **An inbound tool call that implies a Redmine write synthesizes a `crux_conversations` row** (state entering directly at `planned`, skipping `draft`/`clarifying` since the MCP client already supplied complete parameters), attributed to the token's owning user. **Why**: this reuses Workflow Engine/Approval Engine/Run Ledger entirely unmodified — no new state, no bypass path, exactly matching `integrations.md`'s instruction to hand inbound events "to Intent Detection like a chat message." **When to revisit**: if MCP inbound volume ever needs a lighter-weight non-conversational execution path, that's a performance optimization for a later phase, not a Phase 4 GA concern.
- **The GA tool surface is deliberately narrow: read/list/get operations plus "propose a change" — no destructive-action-type tool is exposed via MCP inbound at all in Phase 4**, even though `crux:approve_destructive` would still gate its execution if it existed. **Why sufficient now**: this is the plugin's very first external-facing (not admin-configured) auth surface; narrowing the tool surface itself reduces blast radius independent of the approval gate, a defense-in-depth argument, not a redundant one. **When to revisit**: `future_scope.md`'s MCP ecosystem growth area explicitly names "more inbound tool integrations" as forward work — destructive-action tool exposure belongs there, once the inbound surface has track record.
- **Token digest, never plaintext, stored at rest** — mirrors crx-006's credential-security pattern exactly, extended to an inbound (not outbound) secret.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Token authentication | A valid, unrevoked token | Authenticates, resolves to the correct user/project | pending |
| 2 | Revoked token rejected | A revoked token | Authentication fails | pending |
| 3 | Token scoped to its project only | A token issued for Project A used against Project B's data | Rejected/returns nothing for Project B | pending |
| 4 | propose_change rejects destructive types | A tool call attempting a `deploy`/`delete_*` action type | Rejected outright, not routed to `crux:approve_destructive` at all | pending |
| 5 | list_assigned_issues respects visibility | A token whose user has limited project role | Returns only issues that user could see in the Redmine UI | pending |
| 6 | Token stored hashed | Inspect `crux_mcp_tokens.token_digest` | Not plaintext | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Generate and use a token | User generates a token, an MCP client calls `list_assigned_issues` | Correct, scoped results returned | pending |
| 2 | Propose a change end-to-end | MCP client calls `propose_change` | A real `awaiting_approval` plan step appears in Pending Actions, attributed to the token's user | pending |
| 3 | Revoke a token | User revokes their token | Subsequent calls with that token fail | pending |
| 4 | User manages only their own tokens | User A attempts to view/revoke User B's token | Not possible via the UI | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Token leaked/compromised | An attacker uses a leaked token | Blast radius is limited to exactly that project and that user's existing permissions — no privilege escalation beyond what the UI would already allow | pending |
| 2 | User's project role reduced after token issuance | Same token used after a permission downgrade | Reflects the *current*, reduced permissions, not a cached broader set | pending |
| 3 | Malformed/malicious tool call payload | A crafted `propose_change` payload with unexpected fields | Rejected/validated, not blindly trusted | pending |

### QA Test Plan

**Scope**: Token generation/revocation, authentication, project-scoping, the narrow read/write tool surface, and confirmation that no destructive action is ever reachable via MCP inbound.

**Pre-conditions**: crx-001 through crx-019 in place; an MCP-compliant test client.

**QA Steps**:
1. Generate a token for a test project; use it via a test MCP client to list assigned issues.
2. Call `propose_change`; confirm a real, attributed, approval-gated plan step appears.
3. Attempt a destructive action type via the tool; confirm outright rejection.
4. Revoke the token; confirm subsequent calls fail.
5. Reduce the token owner's project role; confirm the token immediately reflects the reduction.

**Expected Outcomes**: No MCP inbound call ever exceeds the token owner's actual Redmine permissions; no destructive action is ever reachable via this surface.

**Out of Scope**: MCP outbound (crx-021).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked exposing a broader tool surface (including destructive actions, relying solely on `crux:approve_destructive` to gate them) rather than narrowing the surface itself as defense in depth for this plugin's first external-facing auth mechanism. | Implementation Notes | Explicitly narrowed: no destructive-action tool exists at all in this task's GA surface. |
| 2 | MEDIUM | Token scope risked being account-wide for convenience, widening blast radius on a leak. | Implementation Notes | Explicitly per-project. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is the plugin's first inbound, externally-facing credential — a leaked token is a genuinely new attacker-facing risk class; it must never grant more than the owning user's existing Redmine permissions. | Test Case Edge #1 | Explicit blast-radius-limiting design (per-project scope, no destructive tools), directly tested. |
| 2 | HIGH | Token must be stored hashed, never plaintext, consistent with crx-006's established credential posture. | Test Case Unit #6 | Explicitly specified and tested. |
| 3 | MEDIUM | A permission downgrade after token issuance must be reflected immediately, not via a cached snapshot. | Test Case Edge #2 | Explicitly tested. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — narrowed tool surface, per-project scoping, hashed token storage, and fresh-permission resolution are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Silent mass-assignment via a missing `permit` key | `propose_change`'s payload accepts an unexpected field that bypasses the non-destructive-only validation | Yes — Edge Case #3 |
| 2 | Missing index on token lookup | `crux_mcp_tokens.token_digest` unindexed, slow authentication as token volume grows | Not directly test-covered (low volume at Phase 4 GA scale); flagged for implementation attention — index the digest column |
| 3 | Cached/stale permission snapshot | Same as Gate 2 #3 | Yes — Edge Case #2 |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
