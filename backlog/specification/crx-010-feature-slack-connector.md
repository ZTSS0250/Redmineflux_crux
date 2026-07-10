## Metadata
- **Task ID**: crx-010-feature-slack-connector
- **Title**: Slack Connector (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: MEDIUM
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `integrations.md`, `security.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

The second Integration Engine connector, reusing crx-009's webhook/event pipeline and `crux_integrations` table entirely. Slack OAuth app per workspace; inbound: slash commands (`/crux status`) and @mentions; outbound: run status and approval requests, approval-gated only where a Redmine write actually results (`integrations.md`'s own worked example: `/crux status` is read-only via Reporter Agent and explicitly bypasses approval, since there's nothing to approve).

Unlike GitHub's webhook events (system-of-record events with no individual human attached), Slack slash commands and mentions are issued by an identifiable workspace member — this task's central new concern is mapping that Slack identity to a real Redmine user *before* running anything with that user's permissions, rather than falling back to the connector-installer's identity the way crx-009 correctly did for GitHub.

**Goal**:

A user can type `/crux status` in a connected Slack workspace and get the Reporter Agent's project summary in-thread, with no approval needed since nothing is written to Redmine. A user can @mention Crux with a request that does imply a write, and receive an approval prompt in Slack, gated exactly as it would be in the Chat tab. An unmapped Slack user (one who hasn't linked their Redmine account) is refused with a clear prompt to link, never silently granted the connector-installer's access.

**Objectives**:
- [ ] Add `crux_external_identities` table — maps a Slack user id to a real Redmine `user_id`, scoped per `crux_integrations` connector.
- [ ] Implement Slack OAuth app connection per workspace (`crux:manage_integrations`).
- [ ] Implement slash command (`/crux status` and others as Intent Detection supports) and @mention handling, routed through crx-002's Chat Engine "like a chat message" (`integrations.md`'s own phrasing).
- [ ] Implement the identity-mapping/linking flow: an unmapped Slack user's command is refused with a "link your Redmine account" reply, never silently run under any other identity.
- [ ] Implement outbound: run status and approval-request messages posted back to the originating Slack channel/thread.
- [ ] Confirm the read-only bypass (`/crux status` → Reporter Agent → no approval) reuses the existing "is this a fixed-deliverable write or a read-only reply" branch (crx-004's Reporter Agent already exhibits this behavior for chat) rather than inventing a Slack-specific governance carve-out.

**Deliverables**:
- [ ] Migration: `crux_external_identities`.
- [ ] Model: `Crux::ExternalIdentity`.
- [ ] `Crux::Integrations::Slack` connector (OAuth, slash command/mention parsing, outbound posting).
- [ ] Identity-linking flow (a lightweight "connect your Redmine account" web view a Slack user is directed to).
- [ ] `ProjectCruxAutomationsController` (crx-009) extended with Slack connector configuration.

**Out of Scope**: GitLab, Bitbucket, Microsoft Teams (other chat/source-control integrations — Phase 3–4); rich interactive Slack components (buttons, modals) beyond slash commands/mentions — not named in `integrations.md`'s Slack section at all, genuinely unscheduled.

---

## Specification

**Complexity**: MEDIUM

**Reason**: The hard, novel infrastructure (webhook/event pipeline, signature verification, first `crux_integrations` migration) already shipped in crx-009; this task is "second connector against an established interface," which is why it doesn't repeat crx-009's HIGH rating outright. The one sub-component warranting HIGH-caliber scrutiny — Slack-user-to-Redmine-user identity mapping, a genuine privilege-escalation surface — is called out explicitly in Gate 2 despite the task's overall MEDIUM file/migration footprint.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_external_identities.rb` | create | `crux_external_identities(id, integration_id FK crux_integrations, external_user_id, user_id FK Redmine users, created_at)`. |
| `app/models/crux/external_identity.rb` | create | `belongs_to :integration`, `belongs_to :user`; uniqueness on `(integration_id, external_user_id)`. |
| `app/services/crux/integrations/slack.rb` | create | OAuth connection per workspace; parses slash commands/@mentions; looks up `ExternalIdentity` for the Slack user id — if found, routes to Chat Engine as that Redmine user; if not found, replies with a link-your-account prompt instead of proceeding. |
| `app/controllers/crux_identity_links_controller.rb` | create | The web view a Slack user is directed to for linking; requires the user to already be logged into Redmine (reuses Redmine's own session, no new auth mechanism), then creates the `ExternalIdentity` row. |
| `app/services/crux/integrations/webhook_receiver.rb` (crx-009) | modify | Extended to handle Slack's own signature-verification scheme (a different HMAC variant than GitHub's) — the shared receiver's verify-then-parse structure is unchanged, only the specific verification algorithm is added. |
| `app/controllers/project_crux_automations_controller.rb` (crx-009) | modify | Add Slack connector configuration (OAuth connect flow) alongside GitHub's. |

### Implementation Notes

- **Slack identity resolves differently than crx-009's webhook identity, deliberately.** crx-009's GitHub events aren't per-human interactive commands (they're system-of-record events), so falling back to the integration-owner's identity was correct there. Slack slash commands *are* issued by an identifiable human — falling back to the integration owner here would let any workspace member act with the *connector-installer's* permissions, a real privilege-escalation risk. **Resolution**: an unmapped Slack user's commands are refused with a "link your Redmine account" reply rather than silently running under the integration owner's identity. **Why sufficient now**: keeps Principle 6 intact for the one Phase 2 integration where it's actually load-bearing. **When to revisit**: if Phase 3/4 adds Microsoft Teams (structurally identical "interactive human command" integration), this same `crux_external_identities` table and mapping flow should be reused, not reinvented.
- **`/crux status` bypassing approval is not a new exception invented for Slack** — it reuses the exact same "is this a fixed-deliverable write, or a read-only reply" branch Intent Detection/Reporter already implement (Reporter's Phase 1 behavior already "typically bypasses the plan/approval gate because it is read-only," per `agent_catalog.md`). Flagged explicitly so it isn't mistaken for a Slack-specific governance carve-out.
- **The identity-linking flow reuses Redmine's own session/login** — it does not introduce a second authentication mechanism. A Slack user must already be able to log into Redmine normally; linking just associates their Slack id with that existing, already-authenticated account.
- **Slack's signature-verification scheme is added to the shared `WebhookReceiver`, not duplicated into a Slack-specific receiver** — the verify-then-parse structure crx-009 established is reused; only the specific algorithm/header format differs per platform.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Mapped Slack user resolves correctly | A slash command from a Slack user id with an existing `ExternalIdentity` row | Routed to Chat Engine as that mapped Redmine user | pending |
| 2 | Unmapped Slack user is refused | A slash command from a Slack user id with no `ExternalIdentity` row | Refused with a "link your account" reply; no fallback to the integration owner | pending |
| 3 | Read-only bypass | `/crux status` from a mapped user | Reporter Agent's reply posted in-thread; no `crux_execution_plans` row created, no approval needed | pending |
| 4 | Write-implying command requires approval | An @mention that implies a Redmine write | An `awaiting_approval` plan step is created, an approval-request message posted to Slack | pending |
| 5 | Identity uniqueness | Attempt to link the same Slack user id twice for the same integration | Second attempt updates/rejects cleanly, no duplicate `ExternalIdentity` row | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end status command | Connect Slack; a mapped user runs `/crux status` | Reporter Agent's summary appears in-thread within seconds | pending |
| 2 | End-to-end write via mention | A mapped user @mentions Crux with a request implying a write | Approval-request message appears in Slack; approving it (via the Pending Actions tab, since this task doesn't build in-Slack approval buttons) executes normally | pending |
| 3 | Unmapped user flow | An unmapped Slack user attempts any command | Prompted to link; after linking via the web flow, a retried command succeeds | pending |
| 4 | Connector configuration | Project Workspace → Automations, connect Slack | Shows connected workspace, last-event timestamp | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Slack signature invalid | A request claiming to be from Slack with a bad signature | Rejected before any parsing, same posture as crx-009's GitHub signature check | pending |
| 2 | Mapped user's Redmine permissions revoked after linking | A previously-mapped user loses project access | Subsequent commands reflect their *current* (reduced) permissions, not a cached broader set | pending |
| 3 | Same Redmine user links two different Slack accounts | User links a second Slack identity to the same Redmine account | Both function independently; no conflict | pending |
| 4 | Disconnected Slack workspace | Integration disabled mid-session | New commands are rejected/ignored, not processed as if still connected | pending |

### QA Test Plan

**Scope**: Slack OAuth connection, identity mapping/linking, slash command and @mention handling, and the read-only-bypass vs. approval-gated-write distinction.

**Pre-conditions**: crx-001 through crx-009 in place; a test Slack workspace and app credentials; at least one mapped and one unmapped test user.

**QA Steps**:
1. Connect a Slack workspace to a test project.
2. As a mapped user, run `/crux status`; confirm an in-thread reply with no approval prompt.
3. As a mapped user, @mention Crux with a write-implying request; confirm an approval-request message and that approving it in the Pending Actions tab executes correctly.
4. As an unmapped user, attempt any command; confirm the link-account prompt, then confirm the command succeeds after linking.
5. Revoke a mapped user's project access; confirm subsequent commands reflect the reduction.

**Expected Outcomes**: No unmapped Slack user ever runs a command under any identity other than "refused, please link"; read-only commands never require approval; write-implying commands always do.

**Out of Scope**: In-Slack interactive approval buttons (approval still happens via the Pending Actions tab in this task's scope).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked reusing crx-009's GitHub identity-resolution pattern (fall back to the connector-installer) for Slack too — which would be a real privilege-escalation bug here, since Slack commands are per-human, unlike GitHub's system events. | Implementation Notes | Explicitly resolved differently: unmapped users are refused, never defaulted to the installer's identity. |
| 2 | MEDIUM | The identity-linking flow risked inventing a second authentication mechanism instead of reusing Redmine's existing login. | Code Changes, `crux_identity_links_controller.rb` row | Explicitly specified to require an existing Redmine session, no new auth. |
| 3 | LOW | Slack's distinct webhook signature scheme risked being implemented as a parallel, duplicated receiver instead of extending crx-009's shared one. | Code Changes, `webhook_receiver.rb` modify row | Extended, not duplicated. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | The single biggest risk in this task: an unmapped Slack user gaining the connector-installer's Redmine permissions by typing a command — a genuine privilege-escalation vulnerability class, not a cosmetic gap. | Implementation Notes; Test Case Unit #2 | Explicitly refused with no fallback identity; directly tested. |
| 2 | MEDIUM | A mapped user whose Redmine permissions are later reduced must not continue operating under a stale, broader permission snapshot. | Test Case Edge #2 | Explicitly required: permissions resolved fresh per command, not cached at link time. |
| 3 | LOW | `crux_external_identities` needs a uniqueness constraint on `(integration_id, external_user_id)` to prevent duplicate/conflicting mappings. | Code Changes, model row | Explicitly specified. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the refuse-not-fallback identity rule, reused Redmine login, extended (not duplicated) signature verification, fresh-permission resolution, and the uniqueness constraint are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Missing `authorize` on a non-obvious action | The identity-linking controller accepts a link request without confirming the current Redmine session actually belongs to the user being linked | Not directly test-covered by a UI edge case in this task's list (session-handling is Rails/Redmine's own auth, reused as-is); flagged for implementation attention — the linking action must operate on `User.current`, never a client-supplied user id |
| 2 | Silent mass-assignment | The linking flow accepts a client-supplied Redmine `user_id` param instead of deriving it from the current session | Same as #1 — flagged together as one implementation-time attention item |
| 3 | Stale permission snapshot | Permissions cached at link time rather than resolved per-command | Yes — Edge Case #2 |
| 4 | DB-level uniqueness missing | Duplicate `ExternalIdentity` rows for the same Slack user | Yes — Unit Test #5 |
| 5 | Wrong `dependent:` on association | `crux_external_identities` tied to `crux_integrations` without a deliberate deletion policy when a connector is disconnected | Not directly test-covered; flagged for implementation attention — disconnecting Slack should not silently orphan or cascade-delete identity mappings without an explicit decision |

Verdict: Approved. Items #1/#2 and #5 are implementation-time attention items rather than dedicated tests, since they concern controller/association wiring correctness rather than independently observable behavior distinct from what's already tested.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
