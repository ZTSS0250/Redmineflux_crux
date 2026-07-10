## Metadata
- **Task ID**: crx-023-feature-marketplace-listings
- **Title**: Future Marketplace listing mechanism (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `future_scope.md`, `architecture.md`, `integrations.md`, `database_design.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

The minimal, real listing/distribution mechanism `roadmap.md` names as Phase 4's last capability, built directly on top of crx-022 (Custom Agents): an org can publish one of its Custom Agents as a listing (metadata: name, description, version, publisher, declared provider requirement); another project within the same Redmine instance can browse listings and "install" one, which concretely means instantiating a new, independent, project-scoped `crux_agents` row sourced from the listing — governed identically to any other custom agent from that point forward. Directly implements `architecture.md`'s Future Enhancements note that this requires "a new module boundary... likely inserted between Agent Engine and Integration Engine" — this task stands up that `Crux::Marketplace` namespace, not just a feature inside Agent Engine. `roadmap.md`'s own Design Decision states the dependency chain explicitly: this is deliberately last because it depends on Phase 2's multi-provider support and Phase 3's stable twelve-agent roster.

**Goal**:

A publisher can list a custom agent for other projects in the same Redmine instance to discover and install; installing creates an independent, governed copy — never a live link back to the publisher's original, and never auto-updated when the publisher changes their listing.

**Objectives**:
- [ ] Add `crux_marketplace_listings` table: source agent, publisher, name/description/version, status (draft/published/delisted).
- [ ] Add `crux_agents.marketplace_listing_id` (nullable FK) — provenance only, answerable as "which listings installed this agent" via a simple query, no separate installations join table needed (per `database_design.md`'s "don't shadow a table" best practice).
- [ ] Ship **agent listings only at GA** — explicitly not connector distribution, even though `integrations.md`/`architecture.md` both list "Future Marketplace" among the 12 canonical integrations, because both `integrations.md` and `future_scope.md` independently flag "what vetting will Marketplace connectors undergo before holding outbound credentials" as unresolved, and a connector (unlike an agent) needs to hold credentials the moment it's installed.
- [ ] Ship publish / browse (simple list, no ranking algorithm) / install / delist only — explicitly deferring rating/review, a certification tier, and any pricing/revenue-share model, all three named verbatim in `future_scope.md`'s Marketplace growth section as forward work.
- [ ] Installing forks the listing into an independent `crux_agents` row at install time — no auto-propagation of later listing updates/delists to already-installed copies (a supply-chain-style risk this task deliberately avoids).
- [ ] Scope Marketplace to a single Redmine instance, per `architecture.md`'s own Assumption ("a single Crux plugin installation serves one Redmine instance; multi-instance federation is not modeled") — no cross-instance/public marketplace.

**Deliverables**:
- [ ] Migration: `crux_marketplace_listings`; `crux_agents.marketplace_listing_id`.
- [ ] `Crux::Marketplace::Listing` model.
- [ ] `Crux::Marketplace::Publisher` — publish/delist flow, sourced from an existing custom agent (crx-022).
- [ ] `Crux::Marketplace::Installer` — forks a listing into a new project-scoped `crux_agents` row.
- [ ] A simple browse/list UI (Administration or Project Workspace — no ranking algorithm, just a list).

**Out of Scope**: Certification/rating/review tier (`future_scope.md`, Marketplace growth); revenue-share/marketplace-specific pricing (`future_scope.md`, and `billing.md`'s own forward pointer); connector distribution via Marketplace (deferred pending the connector-vetting Open Question in both `integrations.md` and `future_scope.md`); cross-Redmine-instance/public marketplace (an implied gap in `future_scope.md`, not committed anywhere); push-style version propagation to installed copies (`future_scope.md`, Marketplace growth).

---

## Specification

**Complexity**: HIGH

**Reason**: Two new schema elements plus a genuinely new architectural pattern (publish-once/install-many, the first intentional cross-project data-sharing pattern in the entire schema, deliberately crossing Principle 5's project-isolation boundary by design), plus standing up the new module boundary `architecture.md` explicitly calls out as required. Matches the new-migration + new-module-boundary + first-cross-project-sharing-pattern combination, the same architecture-impact criterion crx-004 used, not merely file count.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_create_crux_marketplace_listings.rb` | create | `crux_marketplace_listings(id, source_agent_id FK crux_agents, publisher_user_id FK User, name, description, version, status [draft/published/delisted], created_at, updated_at)`. |
| `db/migrate/XXXX_add_marketplace_listing_id_to_crux_agents.rb` | create | `crux_agents.marketplace_listing_id` (nullable FK) — set only on installed copies. |
| `app/models/crux/marketplace/listing.rb` | create | `belongs_to :source_agent`, `belongs_to :publisher, class_name: 'User'`; validates `status` transitions (draft→published→delisted, no skipping). |
| `app/services/crux/marketplace/publisher.rb` | create | Publishes a custom agent (crx-022, `origin: 'custom'` required — catalog agents cannot be listed) as a new `Listing`; delists on request. |
| `app/services/crux/marketplace/installer.rb` | create | `#install(listing:, project:)` — creates a new, independent `crux_agents` row (`origin: 'marketplace'`, `marketplace_listing_id: listing.id`) copying the listing's prompt template/provider requirement at install time; no live reference back to the source agent's ongoing state. |
| `app/controllers/crux_marketplace_controller.rb` | create | Browse (simple list, filterable by name), publish, delist, install actions. |

### Implementation Notes

- **What "minimal but real" means for Phase 4 GA, without over-building toward `future_scope.md`'s speculative growth**: IN scope — publish, browse/list (simple list, no ranking algorithm), install (creates a governed `crux_agents` row), delist. OUT of scope, explicitly deferred — rating/review of listings, a certification tier ("agents that pass Crux's own governance checks"), and any marketplace-specific pricing/revenue-share model — all three named verbatim in `future_scope.md`'s Marketplace growth section as forward work, not silently reinvented here.
- **Marketplace ships agent listings only in Phase 4 GA — not connector listings**, even though `integrations.md` names "Future Marketplace" as one of its 12 canonical integrations and `architecture.md` lists it in the Integration Engine's connector roster. **Why**: both `integrations.md` and `future_scope.md` independently flag the same unresolved Open Question — "what vetting will Future Marketplace connectors undergo before holding outbound credentials?" — and a connector, unlike an agent, needs to *hold outbound credentials* the moment it's installed. Shipping connector distribution without an answer to that question means shipping a real credential-holding surface with a known, acknowledged gap. Agent listings carry no equivalent problem (an installed agent is governed by mechanics crx-022 already established). **When to revisit**: once the connector-vetting question is actually answered — a natural, explicit trigger for graduating connector listings out of `future_scope.md`.
- **No auto-propagation from a listing update/delist to already-installed copies.** An installed agent is forked at install time into an independent row; updating or delisting the source listing does not remotely alter or disable copies already running in other projects. **Why**: this avoids a publisher silently changing behavior already running inside another organization's governed project without that project's own approval — a supply-chain-style risk that would otherwise undercut Principle 6 the moment Marketplace exists. Re-installing a newer version is a deliberate, opt-in action a project takes, not a push. **When to revisit**: automatic version propagation is a reasonable `future_scope.md` Marketplace-growth candidate once the trust/certification model above is further along.
- **Marketplace scope is single-Redmine-instance-wide, not cross-instance/public.** `architecture.md`'s own Assumption means Phase 4 GA's marketplace can only span projects within the same instance. A genuinely public, cross-instance marketplace is a natural follow-on but isn't named verbatim anywhere in `future_scope.md` today — flagged as an implied gap in that document's Marketplace-growth bucket rather than invented as committed scope here.
- **Only `origin: 'custom'` agents can be published** — catalog agents (the fixed 12) are never listed, since they're already universally available and doc-defined; listing them would be meaningless and could confuse the trust model crx-022 established for distinguishing custom/marketplace agents from catalog ones.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Publish a custom agent | An `origin: 'custom'` agent | Creates a `draft`/`published` listing | pending |
| 2 | Cannot publish a catalog agent | An `origin: 'catalog'` agent | Rejected | pending |
| 3 | Install forks independently | Install a listing into Project B | A new `crux_agents` row exists, `origin: 'marketplace'`, independent of the source agent | pending |
| 4 | No live propagation | Publisher updates the source agent's prompt template after installs exist | Already-installed copies are unaffected | pending |
| 5 | Delist doesn't disable installed copies | Publisher delists | Existing installs continue functioning; new installs are no longer possible | pending |
| 6 | Status transition validation | Attempt draft→delisted directly (skipping published) | Rejected — must follow draft→published→delisted | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end publish and install | Publish a custom agent from Project A; browse and install it into Project B | Project B has a fully functional, independently-governed copy | pending |
| 2 | Installed agent behaves like any custom agent | Invoke the installed copy | Approval-gated, Run Ledger recorded, Knowledge Engine filtered, attribution badge shows marketplace provenance | pending |
| 3 | Browse/list UI | Multiple published listings | Simple list view, no ranking/sorting algorithm beyond basic filtering | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Install a delisted listing (via a stale link) | User attempts to install a listing that's since been delisted | Rejected — delisted listings are not installable | pending |
| 2 | Publisher's project loses `crux:author_agents`/tier eligibility after publishing | Existing listing | Remains published and installable (installation is a project-level action, not gated by the publisher's ongoing permission) — flagged for confirmation at implementation time given no doc specifies this explicitly | pending |
| 3 | Cross-instance install attempt | An attempt to reference a listing from a different Redmine instance (not modeled) | Not possible — no mechanism exists for it, consistent with `architecture.md`'s single-instance Assumption | pending |

### QA Test Plan

**Scope**: Publish/browse/install/delist flow, install-time independence (no live coupling), and confirmation that installed agents are fully governed like any custom agent.

**Pre-conditions**: crx-001 through crx-022 in place; at least two projects, one with a publishable custom agent.

**QA Steps**:
1. Publish a custom agent from Project A.
2. Browse listings from Project B; install the listing.
3. Confirm Project B's installed copy functions independently — approval-gated, Run Ledger recorded, correctly attributed.
4. Update the source agent in Project A; confirm Project B's copy is unaffected.
5. Delist from Project A; confirm Project B's installed copy still works, but the listing is no longer installable elsewhere.

**Expected Outcomes**: Installed agents are fully independent and fully governed; no live coupling back to the publisher exists after install.

**Out of Scope**: Certification, ratings, pricing, connector listings.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked including connector distribution in this task's GA scope, since `integrations.md`/`architecture.md` both name "Future Marketplace" as a canonical integration — this would ship a credential-holding surface with a known, doc-acknowledged vetting gap. | Implementation Notes | Explicitly scoped to agent listings only; connector distribution deferred pending the unresolved vetting question. |
| 2 | HIGH | Auto-propagating listing updates to installed copies risked being the default design, which would let a publisher silently alter behavior already running in another project's governed environment. | Implementation Notes | Explicitly resolved as fork-at-install with no propagation. |
| 3 | MEDIUM | Publishing a catalog agent (one of the fixed 12) would be both meaningless and confusing against crx-022's custom/catalog distinction. | Test Case Unit #2 | Explicitly restricted to `origin: 'custom'` only. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This is the first intentional cross-project data-sharing pattern in the entire schema, deliberately crossing Principle 5's project isolation — it must be explicit, opt-in (publish/install), and never implicit/automatic. | Code Changes; Test Case Functional #1 | Publish and install are both explicit, separately-permissioned actions; no implicit sharing exists. |
| 2 | MEDIUM | An installed agent must be governed exactly like any custom agent — no shortcut around Approval Gate/Run Ledger/Knowledge Engine filtering for marketplace-sourced agents. | Test Case Functional #2 | Explicitly tested for full governance parity. |
| 3 | LOW | Status transitions (`draft`/`published`/`delisted`) need validation to prevent an invalid state (e.g. skipping `published`). | Test Case Unit #6 | Explicitly validated. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — agent-only scope, no-propagation-on-update, catalog-agent exclusion, explicit opt-in sharing, and full governance parity are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Wrong `dependent:` on association | `crux_marketplace_listings belongs_to :source_agent` — if the source custom agent is later deleted, existing listings/installed copies risk being silently orphaned or cascade-deleted | Not directly test-covered; flagged for implementation attention — set `dependent:` deliberately (likely `restrict_with_error` or nullify the listing reference, never cascade-delete installed copies) |
| 2 | Installable-after-delist bug | A stale link allows installing an already-delisted listing | Yes — Edge Case #1 |
| 3 | Cross-instance reference silently accepted | A crafted request references a listing id from data that doesn't belong to this instance (not applicable in a single-instance model, but worth confirming no code path assumes multi-instance) | Yes — Edge Case #3 |

Verdict: Approved. Item #1 is an implementation-time attention item since it concerns association deletion-policy configuration rather than independently observable behavior distinct from what's already tested.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
