## Metadata
- **Task ID**: crx-009-feature-integration-engine-github
- **Title**: Integration Engine Foundation + GitHub Connector (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `integrations.md`, `database_design.md`, `security.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Build the Integration Engine for real — today it's only a placeholder Administration tab (crx-001) with no `crux_integrations` table despite that table being named in `database_design.md`'s canonical 11-table schema since Phase 1. This task creates the table, the inbound-webhook-to-outbound-approval-gated-write pipeline (`integrations.md`'s Sequence Flow), and the first concrete connector, GitHub. It also extends crx-007's Code Reviewer with the Integration-Engine-webhook invocation path `agent_catalog.md` names ("invoked from Chat Engine **or** an Integration Engine webhook") but crx-007 deliberately left unbuilt.

**Goal**:

A project can connect a GitHub repository (GitHub App/OAuth or scoped PAT); a merged PR raises an intent that routes to QA Agent for a regression test plan (`integrations.md`'s own canonical worked example); a PR-opened event routes to Code Reviewer; both flow through the identical plan → approval → execution path a chat-originated request would, with a real Redmine-authenticated human on record as the run's authority even though the event itself came from GitHub, not a logged-in browser session.

**Objectives**:
- [ ] Add `crux_integrations` table (`database_design.md`) — first real creation.
- [ ] Implement the inbound webhook receiver: signature-verified (HMAC), converts a GitHub event into an Intent-Detection-routed conversation, exactly as `integrations.md` specifies ("hand it to Intent Detection like a chat message").
- [ ] GitHub connector: Auth = GitHub App (OAuth) or scoped PAT; In: push, PR opened/merged, issue_comment, release; Out: PR/issue comments, status checks — approval-gated.
- [ ] Resolve "on whose authority does a webhook-triggered run execute" — the `crux:manage_integrations` holder who configured that connector, per `integrations.md`'s own literal instruction that this be "identical in shape to a chat-triggered run."
- [ ] Wire Code Reviewer's webhook path (crx-007's agent, this task's trigger) and post its review back to the actual GitHub PR as a comment.
- [ ] Wire QA Agent's (crx-004's agent) PR-merged → regression-test-plan path, matching `integrations.md`'s literal canonical example.
- [ ] Enforce the universal governance rule: every outbound write, regardless of entry point, clears the same Workflow Engine approval gate — no "trusted integration" shortcut.

**Deliverables**:
- [ ] Migration: `crux_integrations`.
- [ ] Model: `Crux::Integration`.
- [ ] `Crux::Integrations::WebhookReceiver` — HMAC-verifies, parses, hands off to Intent Detection.
- [ ] `Crux::Integrations::GitHub` connector (auth, event parsing, outbound comment/status-check dispatch).
- [ ] Real `ProjectCruxAutomationsController` (crx-001 placeholder) — project-level connector configuration, gated `crux:manage_integrations`.
- [ ] Real global Integrations Administration page (crx-001 placeholder) — org-wide GitHub App registration, gated `crux:administer`.
- [ ] Code Reviewer (crx-007) extended with a webhook-invoked path.
- [ ] QA Agent (crx-004) extended with a PR-merged-invoked path.

**Out of Scope**: Slack connector (crx-010); any integration beyond GitHub (GitLab, Bitbucket, MS Teams, Jenkins, Azure DevOps, Webhooks, MCP, Email, Calendar — Phase 3–4); true two-way sync/conflict resolution (`integrations.md`'s own unresolved Open Question); formal schema support for tracking an external object across multiple syncs (this task uses `crux_plan_steps.payload` for the external reference, not a new polymorphic target type).

---

## Specification

**Complexity**: HIGH

**Reason**: First creation of a canonical-but-never-built table; introduces a genuinely new security surface (an inbound, externally-reachable HTTP endpoint — no prior Crux task has needed one); first outbound credential toward a source-control system; cross-module wiring into an already-shipped agent (crx-007). Matches the security-changes + new-migration + cross-module criteria this project's other HIGH tasks were rated on.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_integrations.rb` | create | `crux_integrations(id, project_id, provider, config, enabled)` per `database_design.md`. |
| `app/models/crux/integration.rb` | create | `belongs_to :project`; validates `provider` against the 12 canonical integration identifiers; `config` holds credentials/tokens, never logged (per `security.md`). |
| `app/controllers/webhooks/crux_github_controller.rb` | create | Public (unauthenticated-by-session, HMAC-authenticated-by-signature) endpoint receiving GitHub webhook POSTs; rejects any payload whose signature doesn't verify *before* anything else runs. |
| `app/services/crux/integrations/webhook_receiver.rb` | create | Shared receiver logic: verify signature → parse event → hand to `Crux::IntentClassifier`/`ChatEngine` (crx-002) as if it were a chat message, per `integrations.md`'s literal instruction. |
| `app/services/crux/integrations/git_hub.rb` | create | GitHub-specific: parses push/PR/issue_comment/release payloads into a normalized event; posts outbound comments/status checks via the GitHub API, only after the corresponding `crux_plan_steps` row is approved. |
| `app/services/crux/agents/context_assembler.rb` (crx-004/005) | modify | Add a lightweight resolution: a webhook-originated conversation's "user" is the `crux_integrations.config`-referenced `crux:manage_integrations` holder who configured the connector — reused for Knowledge Engine permission-filtering exactly as any other user would be. |
| `app/models/crux/conversation.rb` (crx-002) | modify | No schema change; a webhook-triggered conversation is created identically to a chat-triggered one, `user_id` set to the integration-owner as above. |
| `app/models/crux/agent.rb` (crx-007 Code Reviewer, crx-004 QA Agent) | modify | Extend Code Reviewer's Execution Flow to accept webhook-originated invocation (PR opened); extend QA Agent's to accept webhook-originated invocation (PR merged) — both reuse `Crux::Agents::Runner` (crx-004) unmodified. |
| `app/controllers/project_crux_automations_controller.rb` (crx-001) | modify | Real connector configuration UI: connect GitHub (OAuth/PAT), select events, view last-event timestamp — gated `crux:manage_integrations`. |
| `app/controllers/global_crux_integrations_controller.rb` (crx-001) | modify | Real org-wide GitHub App registration (client id/secret) — gated `crux:administer`. |
| `config/routes.rb` | modify | Add the public webhook receiver route, outside the normal `authorize`-gated project routes (it authenticates via HMAC signature instead). |

### Implementation Notes

- **Webhook trust boundary is a hard gate, not best-effort.** `integrations.md`'s own Risk ("untrusted inbound payloads... must be treated as untrusted input, not pre-authorized instruction") means `WebhookReceiver` rejects any payload whose HMAC signature doesn't verify *before* it ever reaches Intent Detection — there is no code path where an unverified payload is parsed at all.
- **"On whose authority does a webhook-triggered run execute?"** — a genuine gap crx-004's Gate 2 rule (every `crux_runs.user_id` must be a real human) otherwise leaves unanswered for events with no attached Redmine session. **Resolution**: the Integration Engine creates a real `crux_conversations` row with `user_id` = the user who configured that `crux_integrations` connector — matching `integrations.md`'s own literal words, "identical in shape to a chat-triggered run," with zero new code paths in Conversation Engine/Workflow Engine/Agent Engine. That user's own Redmine permissions become the Knowledge Engine ceiling for that run. **Why sufficient now**: reuses every mechanism crx-002/003/004/007 already built. **When to revisit**: if a future connector's events need to represent *multiple distinct external humans* per event (e.g. attributing each of several GitHub PR reviewers individually) rather than one integration-owner identity, this single-owner model won't be enough — not needed for this connector.
- **External targets on `crux_plan_steps` use the existing free-form `payload` field**, not new schema. GitHub's two outbound action types (comment, status check) are discrete writes, not object-CRUD requiring `target_id` tracking, so no formal external-target polymorphism is introduced. **When to revisit**: if a later connector needs Redmine-side tracking of an external object across multiple syncs (e.g. "this Issue mirrors that GitHub Issue"), formal schema support becomes worth adding then.
- **Two-way sync is explicitly not attempted.** `integrations.md`'s own Open Question ("how are conflicting updates resolved") is left unresolved by design — GitHub's Phase 2 events are one-shot, event-triggered actions, not continuous bidirectional mirroring.
- **Every outbound write still clears the same approval gate.** A merged-PR-triggered QA Agent regression-test-plan is an ordinary `awaiting_approval` plan step, reviewed by a project lead exactly like a chat-originated one — `integrations.md`'s universal governance rule, reused unmodified.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Signature verification — valid | A correctly HMAC-signed GitHub payload | Accepted, parsed, routed to Intent Detection | pending |
| 2 | Signature verification — invalid/missing | A payload with a wrong or absent signature | Rejected before any parsing occurs | pending |
| 3 | Webhook-run authority | A PR-merged event on a project whose connector was configured by user X | The resulting `crux_conversations.user_id` = X | pending |
| 4 | Governance gate applies identically | A webhook-triggered plan step | Requires the same `crux:approve`/`crux:approve_destructive` as a chat-originated step | pending |
| 5 | Code Reviewer webhook invocation | PR opened event | Code Reviewer produces structured review comments as a plan step | pending |
| 6 | QA Agent webhook invocation | PR merged event | QA Agent produces a regression test plan as a plan step, matching `integrations.md`'s canonical example | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end GitHub PR review | Connect GitHub, open a PR | Code Reviewer's review appears as a Pending Actions item; approving it posts the comment to the real GitHub PR | pending |
| 2 | End-to-end regression test plan | Merge a PR | QA Agent's regression test plan appears in Pending Actions; approving it completes normally | pending |
| 3 | Connector configuration UI | Project Workspace → Automations, connect/disconnect GitHub | Reflects real connection state, last-event timestamp updates on each received webhook | pending |
| 4 | Org-wide GitHub App registration | Administration → Integrations, register a GitHub App | Available for any project's connector setup afterward | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Malformed/adversarial webhook payload | A payload crafted to inject unexpected content into Intent Detection | Treated as untrusted input; no instruction from the payload is executed without the normal plan/approval path | pending |
| 2 | Connector disconnected mid-flight | A webhook arrives after `crux_integrations.enabled` is set false | Rejected/ignored, not processed as if still connected | pending |
| 3 | Duplicate webhook delivery | GitHub redelivers the same event (a known GitHub behavior) | No duplicate plan/conversation created for the same event id | pending |
| 4 | Integration owner's permissions change after configuration | The `crux:manage_integrations` user who set up the connector loses project access | The next webhook-triggered run correctly reflects that user's *current*, reduced permissions — not a cached, broader set | pending |

### QA Test Plan

**Scope**: `crux_integrations` creation, webhook signature verification, GitHub connector (both directions), webhook-run authority resolution, and Code Reviewer/QA Agent's new trigger paths.

**Pre-conditions**: crx-001 through crx-008 in place; a test GitHub repository and App/PAT credentials.

**QA Steps**:
1. Connect GitHub to a test project; open a PR; confirm Code Reviewer's review appears in Pending Actions.
2. Approve it; confirm the comment posts to the real PR.
3. Merge a PR; confirm QA Agent's regression test plan appears and can be approved.
4. Send a payload with an invalid signature directly to the webhook endpoint; confirm it's rejected.
5. Redeliver the same webhook event; confirm no duplicate plan/conversation.

**Expected Outcomes**: No unsigned/invalid webhook payload is ever processed; every GitHub-triggered write clears the identical approval gate a chat-originated one would.

**Out of Scope**: Slack (crx-010); any other integration.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | `crux_integrations` has been named in `database_design.md`'s canonical schema since Phase 1 but was never actually created — a gap that would have blocked every Integration Engine task indefinitely if not closed here. | Code Changes, migration row | Table created per the exact schema already specified. |
| 2 | HIGH | Webhook-triggered runs had no answer for "who is the human authority" — a real gap against crx-004's own Gate 2 rule that every run's `user_id` be a genuine human. | Implementation Notes | Resolved: the connector-configuring `crux:manage_integrations` user, matching `integrations.md`'s literal instruction. |
| 3 | MEDIUM | Extending Code Reviewer/QA Agent's Execution Flow for webhook invocation risked introducing agent-specific webhook-handling code, duplicating logic already centralized in `Crux::Agents::Runner`. | Code Changes, agent model rows | Both reuse `Runner` unmodified — only the *trigger* is new, not the invocation mechanism. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is the plugin's first inbound, externally-reachable HTTP endpoint — an unauthenticated or improperly-verified webhook is a real attacker-facing surface, not a theoretical one. | Code Changes, `webhook_receiver.rb`/`crux_github_controller.rb` rows; Test Case Unit #1/#2 | HMAC signature verification is a hard gate before any parsing, with a dedicated test for both valid and invalid signatures. |
| 2 | HIGH | A webhook-triggered write must clear the exact same approval gate as any other write — any shortcut here would be the "trusted integration" anti-pattern `integrations.md` explicitly warns against. | Test Case Unit #4 | Explicitly tested; no bypass path exists in the spec. |
| 3 | MEDIUM | GitHub webhook redelivery (a documented GitHub platform behavior) could cause duplicate plan/conversation creation if event idempotency isn't handled. | Test Case Edge #3 | Explicit dedup-by-event-id requirement. |
| 4 | LOW | Credentials (GitHub App secret/PAT) must never appear in `crux_runs`/logs, consistent with crx-006's established requirement, now extended to this connector. | Code Changes, `integration.rb` row | Config never logged, per `security.md`. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — table creation, webhook-authority resolution, signature verification, approval-gate parity, and redelivery idempotency are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `authorize` on a non-obvious action | The webhook endpoint accidentally routed through the normal `authorize`-gated controller stack instead of its own HMAC-verified path, causing every webhook to 403 | Not directly test-covered by a UI test (this is a routing-configuration concern); flagged for implementation attention — the webhook route must be explicitly excluded from session-based authorization |
| 2 | Untrusted input treated as pre-authorized instruction | A crafted payload's content is interpreted as a direct command rather than routed through Intent Detection's normal classification | Yes — Edge Case #1 |
| 3 | Stale permission snapshot | The integration-owner's permissions are cached/resolved once at connector setup instead of freshly at each run | Yes — Edge Case #4 |
| 4 | Duplicate event processing | Webhook redelivery not deduplicated | Yes — Edge Case #3 |
| 5 | Wrong `dependent:` on association | `crux_integrations belongs_to :project` deletion cascade not deliberately chosen (should not silently cascade-delete without an explicit decision) | Not directly test-covered; flagged for implementation attention alongside crx-003's identical pattern-2 finding — set `dependent:` deliberately, not by Rails default |

Verdict: Approved. Items #1 and #5 are implementation-time attention items rather than dedicated tests, since they concern routing/association configuration rather than independently observable runtime behavior.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
