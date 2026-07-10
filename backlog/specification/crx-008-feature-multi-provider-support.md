## Metadata
- **Task ID**: crx-008-feature-multi-provider-support
- **Title**: Multi-Provider Support — Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models (Phase 2)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `roadmap.md`, `architecture.md`, `security.md`, `billing.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Complete the Provider Layer's canonical roster by adding the five remaining named providers (Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models) alongside the already-shipped Mock (crx-004) and OpenAI (crx-006), each behind the identical `Crux::Providers::Base` interface, with zero agent-side branching on provider name (`architecture.md`'s existing rule, already proven once by crx-006). This task also closes a schema gap invisible until now: `crux_agents` has no explicit `provider` column, only `model`/`fallback_model` — inferable from the model string when OpenAI was the only real provider, but genuinely ambiguous once Ollama/Local Models' operator-defined model names exist.

**Goal**:

An administrator can connect any of the 7 canonical providers (Mock, OpenAI, Anthropic, Gemini, Azure OpenAI, Ollama, Local Models); every agent's configuration explicitly names both a provider and a model within it; Administration → Providers/Models present a real two-step selector (provider, then model within that provider) instead of crx-006's OpenAI-only assumption.

**Objectives**:
- [ ] Add `crux_agents.provider` (required, backfilled) — closes the provider/model inference ambiguity.
- [ ] Implement `Crux::Providers::Anthropic`, `::GoogleGemini`, `::AzureOpenAI`, `::Ollama`, `::LocalModels`, each implementing `Providers::Base#call` exactly like crx-006's OpenAI adapter.
- [ ] Store each provider's credential/config in `crux_settings` (global scope), following crx-006's exact pattern — encrypted API keys for Anthropic/Gemini/Azure OpenAI; endpoint-only config (no secret) for Ollama/Local Models.
- [ ] Extend `Crux::Models::Catalog` (crx-006) to a per-provider catalog, so model validation is scoped to "is this a known model for *this* provider," not one flat list.
- [ ] Backfill migration: for every existing `crux_agents` row, resolve `provider` from its current `model` value against `Models::Catalog` (OpenAI models → `provider: 'openai'`; anything else → `provider: 'mock'`), deterministically, no manual data entry.
- [ ] Replace crx-006's OpenAI-only Providers/Models Administration UI with a real multi-provider connect/disconnect + two-step (provider → model) selector.

**Deliverables**:
- [ ] Migration: `crux_agents.provider` (+ backfill).
- [ ] 5 new provider adapter classes.
- [ ] `Crux::Models::Catalog` extended to per-provider model lists.
- [ ] `GlobalCruxProvidersController`/`GlobalCruxModelsController` (crx-006) rewritten for N providers instead of 1.
- [ ] Per-provider `crux_settings` credential/config rows, each write-only in the UI (crx-006's established pattern).

**Out of Scope**: On-prem/local-model data-residency guarantees beyond basic Ollama/Local Models connectivity (`future_scope.md`'s "on-prem/local-model indexing for Enterprise" is a separate, later concern about the Knowledge Engine's indexing pipeline, not the Provider Layer this task builds); per-provider billing/tier gating (`billing.md`'s tier table doesn't name provider choice as tier-restricted — confirmed non-finding, not invented here); dynamic runtime provider-capability negotiation (e.g. function-calling support varying per model) — not named in any doc, flagged as an implementation-time attention item only.

---

## Specification

**Complexity**: HIGH

**Reason**: Repeats crx-006's "first real credential" security surface five more times (each a new outbound credential/network dependency), and requires a genuine backfill migration that every existing agent configuration row depends on — a botched backfill would silently mis-resolve every agent's provider in production. Matches the new-migration + cross-module-impact criterion.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `db/migrate/XXXX_add_provider_to_crux_agents.rb` | create | `crux_agents.provider` (string, required after backfill); backfill logic: known OpenAI model → `'openai'`, else → `'mock'`. |
| `app/lib/crux/providers/anthropic.rb` | create | Implements `Providers::Base#call`; API-key-only config (`crux_settings` key: `anthropic_api_key`). |
| `app/lib/crux/providers/google_gemini.rb` | create | Implements `Providers::Base#call`; API-key-only config. |
| `app/lib/crux/providers/azure_open_ai.rb` | create | Implements `Providers::Base#call`; config shape includes endpoint + deployment name + API key (three fields, not just a key — Azure OpenAI's real auth model). |
| `app/lib/crux/providers/ollama.rb` | create | Implements `Providers::Base#call`; endpoint-only config, no secret (self-hosted). |
| `app/lib/crux/providers/local_models.rb` | create | Implements `Providers::Base#call`; endpoint-only config, no secret. |
| `app/models/crux/models/catalog.rb` (crx-006) | modify | Restructured from a flat OpenAI-only list to `Catalog.for(provider)` returning that provider's known model list; existing OpenAI entries unchanged. |
| `app/models/crux/agent.rb` (crx-004/006) | modify | Add `provider` validation (must be one of the 7 canonical provider identifiers); `model`/`fallback_model` validated against `Models::Catalog.for(provider)` rather than a single flat list. |
| `app/controllers/global_crux_providers_controller.rb` (crx-006) | modify | Real connect/disconnect for all 7 providers; Mock always available with no config; each real provider's connected state reflects whether its `crux_settings` config is present and (where applicable) valid. |
| `app/controllers/global_crux_models_controller.rb` (crx-006) | modify | Two-step selector: pick provider, then pick model from `Models::Catalog.for(provider)`. |
| `app/views/global_crux_providers/index.html.erb`, `app/views/global_crux_models/index.html.erb` | modify | Real forms for all 7 providers; Azure OpenAI's 3-field form distinct from the 1-field API-key forms; Ollama/Local Models show an endpoint field only, no secret field. |

### Implementation Notes

- **Explicit `provider` column, not inference.** Backfill: every existing `crux_agents` row's `model` is looked up against `Models::Catalog`; OpenAI matches backfill to `'openai'`, everything else (i.e., rows still using Mock Provider's identifier) backfill to `'mock'` — deterministic, no manual data entry required, since only these two providers existed before this task.
- **Config-shape variance across providers is not agent-side branching.** API-key-only (Anthropic, Gemini), API-key-plus-endpoint-plus-deployment (Azure OpenAI), and endpoint-only/no-secret (Ollama, Local Models) are three different config shapes — each provider adapter owns parsing/validating its own `crux_settings` value; `Crux::Agents::Runner` (crx-004) still only ever calls `Providers::Base#call` uniformly, completely unmodified by this task. This is a restatement of crx-006's own "no `if provider == X` outside the provider class" rule, now genuinely exercised five more times rather than once.
- **In-flight-job-vs-config-change race** (mirrors crx-006 Edge Case #3): the same rule applies uniformly across all six real providers — an in-flight job started under the old credential/endpoint fails cleanly; the next invocation picks up the new config. Not re-litigated per provider, just confirmed to generalize.
- **No new tier gate invented.** `billing.md`'s plan-tier table doesn't name provider choice as a tier-restricted capability (only Agent editing, Knowledge indexing, Integrations, Usage visibility, Outcomes/month are) — confirmed non-finding, not an oversight.
- **Ollama/Local Models genuinely have no secret to protect**, unlike the other five providers — their `crux_settings` config row holds only an endpoint URL. This is not a security shortcut; it reflects that these are self-hosted, no-API-key architectures by design (`architecture.md`'s own framing).

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Each provider implements the shared interface | Call each of the 5 new providers with an identical prompt/context shape | All 5 return the same `{content:, tokens_in:, tokens_out:}` shape as Mock/OpenAI | pending |
| 2 | Backfill correctness — OpenAI rows | A pre-existing agent row with `model: 'gpt-4o'` | Backfilled `provider: 'openai'` | pending |
| 3 | Backfill correctness — Mock rows | A pre-existing agent row with the Mock Provider's model identifier | Backfilled `provider: 'mock'` | pending |
| 4 | Model validation scoped per provider | Assign a Gemini-only model name to an agent whose `provider` is `'anthropic'` | Rejected — model must belong to the assigned provider's catalog | pending |
| 5 | Azure OpenAI 3-field config | Save Azure OpenAI config missing the deployment name | Rejected — all 3 fields required for this provider specifically | pending |
| 6 | Ollama config has no secret field | Save Ollama config | Only endpoint is persisted; no credential field exists to populate | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Connect all 7 providers | Administration → Providers, configure each in turn | Each shows "connected" independently; disconnecting one doesn't affect another | pending |
| 2 | Real agent call via a second real provider | Assign an Anthropic model to QA Agent, invoke it | Real Anthropic call recorded in `crux_runs` with accurate tokens/cost | pending |
| 3 | Two-step model selector | Administration → Models, change Planner's provider from OpenAI to Ollama | Model dropdown repopulates with Ollama's catalog, previous OpenAI model selection cleared | pending |
| 4 | Fallback across providers | Assign `provider: openai` primary, `provider: anthropic` fallback (if the schema allows cross-provider fallback — confirm at implementation time) | Fallback triggers correctly on primary failure, consistent with crx-004's existing fallback test | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Local Models/Ollama endpoint unreachable | Real call attempted | Clean failure recorded in Run Ledger, consistent with crx-006's existing "provider not configured"-style handling, not a crash | pending |
| 2 | Provider disconnected while an agent is still assigned to it | Attempt to invoke that agent | Clear "provider not configured" failure, not a silent fallback to a provider the user didn't choose | pending |
| 3 | Backfill migration run twice (idempotency) | Re-run the backfill migration/rake task | No duplicate work, no already-correct rows altered incorrectly | pending |
| 4 | Credential leakage check across all 5 new providers | Inspect `crux_runs`/logs after a real call to each | No API key/endpoint credential appears anywhere, matching crx-006's existing requirement extended to every new provider | pending |

### QA Test Plan

**Scope**: All 5 new provider adapters, the `provider` column/backfill, per-provider model validation, and credential security parity with crx-006.

**Pre-conditions**: crx-001 through crx-007 in place; test/sandbox credentials for Anthropic, Gemini, Azure OpenAI; a reachable Ollama/Local Models test endpoint.

**QA Steps**:
1. Connect each of the 5 new providers in turn; confirm independent connect/disconnect state.
2. Assign each provider to at least one agent; invoke each; confirm real calls and accurate Run Ledger data.
3. Attempt to assign a model that doesn't belong to the selected provider; confirm rejection.
4. Run the backfill migration against a copy of existing data; confirm all rows resolve correctly.
5. Inspect logs/Run Ledger for credential leakage across all 5 providers.

**Expected Outcomes**: All 7 canonical providers (Mock, OpenAI, + 5 new) are independently configurable and callable through the identical interface; no credential ever leaks; `provider` is always explicit, never inferred.

**Out of Scope**: On-prem indexing pipeline locality (`future_scope.md`); per-provider billing tiers (confirmed non-finding).

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Provider inference from `model` string, workable when OpenAI was the only real provider, becomes genuinely ambiguous once Ollama/Local Models' operator-defined model names exist — an early draft risked continuing to infer rather than adding an explicit column. | Code Changes, migration row | Explicit `crux_agents.provider` column added, backfilled deterministically. |
| 2 | MEDIUM | Azure OpenAI's config shape (endpoint + deployment + key) is structurally different from the other API-key-only providers — treating it identically risked a broken or incomplete connect flow. | Code Changes, `azure_open_ai.rb` row; Test Case Unit #5 | Spec calls this out explicitly as a 3-field form, validated as such. |
| 3 | LOW | Ollama/Local Models' lack of a credential field could be mistaken for an incomplete implementation rather than a deliberate architectural difference. | Implementation Notes | Explicitly documented as by-design, not a gap. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Five new outbound credentials (Anthropic, Gemini, Azure OpenAI keys) repeat crx-006's highest-severity risk five times over — any deviation from crx-006's encrypted-storage/write-only-field/no-Run-Ledger-leakage pattern for any one of them is a real vulnerability. | Code Changes; Test Case Edge #4 | Explicitly required to follow crx-006's exact credential-security pattern for all 3 credentialed providers, verified by a dedicated leakage test across all 5. |
| 2 | MEDIUM | A botched backfill migration on `crux_agents.provider` (the required column every existing agent depends on) could silently mis-resolve provider for an existing agent, causing it to call the wrong (or no) provider in production. | Test Case Unit #2/#3; Edge Case #3 | Backfill logic is deterministic and idempotency-tested. |
| 3 | LOW | No indexing/N+1 concern beyond what crx-006 already established — confirmed no new finding. | — | No action needed. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — explicit `provider` column, Azure OpenAI's distinct config shape, Ollama/Local Models' by-design credential-free config, and backfill determinism/idempotency are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Silent mass-assignment via a missing `permit` key | The Models editor accepts a `provider` value not in the canonical 7-provider list | Yes — Unit Test #4 (model-provider mismatch validation extends to provider validation itself) |
| 2 | Missing index causing slow provider lookups | `crux_agents.provider` unindexed, queried per-project Agent tab render | Not directly test-covered (low row count at this scale); flagged for implementation attention — index recommended alongside the migration |
| 3 | Wrong `dependent:` on association | N/A — no new association introduced by this task | Not applicable |
| 4 | Date/time or quota logic incorrectly assumed | N/A — no time/quota logic in this task | Not applicable |
| 5 | Cross-provider fallback assumed to "just work" without verification | `agent.fallback_model` set to a model on a *different* provider than `agent.provider`/primary model, with no explicit handling for cross-provider fallback | Yes — Functional Test #4 flags this for implementation-time confirmation of whether cross-provider fallback is supported or explicitly disallowed |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
