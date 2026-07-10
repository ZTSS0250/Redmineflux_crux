## Metadata
- **Task ID**: crx-006-feature-provider-model-layer
- **Title**: Provider Layer & Model Layer — first real provider, end-to-end (Phase 1)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `vision.md`, `roadmap.md`, `billing.md`, `security.md`, `architecture.md` — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set — flagged per the note above)*

**Description**:

Complete Phase 1's "Provider Layer and Model Layer support a single provider end-to-end" requirement (`roadmap.md`) by adding the first real model provider — OpenAI, matching the provider/model already shown as the default in crx-001's placeholder Administration → Settings data (`Default Provider: OpenAI`, `Default Model: gpt-4o`) — behind crx-004's `Crux::Providers::Base` interface, alongside the already-shipped Mock Provider. This task also builds the Model Layer proper: per-agent model/fallback-model/temperature resolution, and replaces crx-001's dummy Administration → Providers/Models tab data with real, credential-backed configuration.

**Goal**:

An administrator can configure an OpenAI API key in Administration → Providers; every GA agent (crx-004) can be assigned `gpt-4o` (or another supported OpenAI model) as its primary model and a cheaper/faster model as fallback via Administration/Project → Agents (crx-004); a real agent invocation calls OpenAI instead of the Mock Provider when configured, with the exact same `Crux::Agents::Runner` code path crx-004 already built — no agent-side branching on provider name anywhere.

**Objectives**:
- [ ] Implement `Crux::Providers::OpenAI` against crx-004's `Providers::Base` interface — the only new provider this task adds (single-provider Phase 1 scope; Gemini/Azure OpenAI/Ollama/Local Models are explicitly Phase 2+ per `roadmap.md`).
- [ ] Store the OpenAI API key encrypted, scoped as an organization-level (`crux:administer`-only) secret in `crux_settings` (scope: global) — never per-user, never in prompt text, never in the Run Ledger (`security.md`).
- [ ] Implement the Model Layer's model/fallback-model/temperature resolution: `Crux::Agent#model`/`#fallback_model` validated against OpenAI's actual supported model list (not an arbitrary string), replacing crx-004's deferred validation.
- [ ] Replace crx-001's dummy `GlobalCruxProvidersController`/`GlobalCruxModelsController`/`GlobalCruxSettingsController` data with real reads/writes.
- [ ] Encrypt the API key at rest; use TLS for every Crux-to-OpenAI call (`security.md`).
- [ ] Ensure the credential is referenced by id from `Crux::Providers::OpenAI`, never embedded in `crux_agents.prompt_template` or logged anywhere, including on call failure.
- [ ] Confirm `Crux::Agents::Runner`'s existing fallback-on-failure logic (crx-004) works unmodified against a real provider (i.e., a real OpenAI failure triggers the same fallback path Mock Provider's simulated failure already tests).

**Deliverables**:
- [ ] `Crux::Providers::OpenAI` implementation of `Providers::Base`.
- [ ] Encrypted credential storage (`crux_settings`, scope: global, `crux:administer`-gated read/write).
- [ ] `Crux::Models::Catalog` — the known-good OpenAI model list used to validate `crux_agents.model`/`fallback_model` assignment.
- [ ] `GlobalCruxProvidersController` rewritten: real connect/disconnect flow for OpenAI (Mock Provider always shown as available, no credential needed).
- [ ] `GlobalCruxModelsController` rewritten: real per-agent model/fallback/temperature editor, validated against `Models::Catalog`.
- [ ] `GlobalCruxSettingsController` rewritten: the "Default Provider"/"Default Model"/"Fallback Model" dummy rows become real, editable, `crux:administer`-gated settings.
- [ ] Updated Agents tab (crx-004) model-assignment dropdown populated from `Models::Catalog` instead of accepting free text.

**Out of Scope**: Any provider beyond OpenAI (Anthropic, Google Gemini, Azure OpenAI, Ollama, Local Models are Phase 2's "Multiple AI Providers" capability per `roadmap.md`); per-user API keys (organization-level only, per `security.md` Assumptions); on-prem/local model hosting (`future_scope.md`).

---

## Specification

**Complexity**: HIGH

**Reason**: Introduces the plugin's first outbound credential and its first real external network dependency — the highest-stakes security surface added so far (credential storage/transmission), plus the Model Layer's validation logic that every agent's configuration now depends on. HIGH per the global security-changes criterion, even though the file count is smaller than crx-003/004/005.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/lib/crux/providers/open_ai.rb` | create | Implements `Providers::Base#call(prompt:, context:, agent:)`; reads the encrypted API key by reference (never embeds it in the prompt payload); raises a typed error on failure that `Crux::Agents::Runner` (crx-004) already knows how to catch and retry against `fallback_model`. |
| `app/models/crux/models/catalog.rb` | create | Static/queryable list of OpenAI's supported chat-completion models (e.g. `gpt-4o`, `gpt-4o-mini`) — the single source of truth `crux_agents.model`/`fallback_model` are validated against. |
| `db/migrate/XXXX_add_provider_credentials_to_crux_settings.rb` | create (or confirm `crux_settings` already generic enough) | Ensures `crux_settings` can hold an encrypted `value` for `key: 'openai_api_key'`, `scope: 'global'` — uses Rails' built-in attribute encryption (or equivalent), not application-level base64/obfuscation. |
| `app/models/crux/agent.rb` (crx-004) | modify | Add a validation: `model`/`fallback_model` must be present in `Models::Catalog` (for agents whose provider resolves to OpenAI) or be the literal Mock Provider identifier — closes the validation gap crx-004 explicitly deferred. |
| `app/controllers/global_crux_providers_controller.rb` | modify | Replace the hardcoded `@providers` array: OpenAI shows `connected`/`not_configured` based on whether a valid encrypted key exists; all other canonical providers (Anthropic, Gemini, Azure OpenAI, Ollama, Local Models) continue to show `not_configured` truthfully (not fabricated as available); Mock Provider always shows `dev_only`/available. Connect/disconnect actions gated `crux:administer`. |
| `app/controllers/global_crux_models_controller.rb` | modify | Replace the hardcoded `@agents` model list with a real per-agent editor reading/writing `crux_agents.model`/`fallback_model`/`temperature`, options populated from `Models::Catalog`. |
| `app/controllers/global_crux_settings_controller.rb` | modify | "Default Provider"/"Default Model"/"Fallback Model" become real `crux_settings` rows (scope: global), editable only via a form gated `crux:administer`, not hardcoded display strings. |
| `app/views/global_crux_providers/index.html.erb`, `app/views/global_crux_models/index.html.erb`, `app/views/global_crux_settings/index.html.erb` | modify | Real forms/state instead of static tables; the API key field is write-only (never redisplays the stored secret, standard credential-form practice). |

### Implementation Notes

- **The API key is an organization-level secret, not a per-user one** (`security.md` Assumptions) — stored once in `crux_settings` at global scope, gated `crux:administer` for both read (existence-check only, never the raw value) and write. No project-level override of the credential exists in this task.
- **No agent-side branching on provider name.** `Crux::Agents::Runner` (crx-004) already calls `Providers::Base#call` uniformly; this task's entire job is to make `Crux::Providers::OpenAI` a drop-in second implementation of that same interface. If any code path needs an `if provider == 'openai'` branch outside the `Providers::OpenAI` class itself, that is a design violation of `architecture.md`'s "no agent-side branching on provider name" rule.
- **Secrets are excluded from logs, prompts, and the Run Ledger by construction** (`security.md`) — `crux_runs.prompt_ref` and `context_refs` must never contain the API key even transiently; `Providers::OpenAI` reads the key only inside its own call boundary and never passes it into anything `Runner` subsequently persists.
- **The write-only credential field is standard practice, not a UX shortcut** — once saved, the Providers tab shows "connected" with a masked indicator, never the key itself, including to `crux:administer` holders on a later page load.
- **`Models::Catalog` existing now (even though it only lists OpenAI models this task) is what lets crx-004's deferred model-list validation finally close** — this was explicitly flagged as an open item in crx-004's Gate 3 Part B ("silent mass-assignment via a missing permit key... flagged here so crx-006 adds the validation").

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | OpenAI provider implements the shared interface | `Crux::Providers::OpenAI.new.call(...)` | Returns the same `{content:, tokens_in:, tokens_out:}` shape `Providers::Mock` returns | pending |
| 2 | Credential never appears in Run Ledger | A successful OpenAI call | `crux_runs.prompt_ref`/`context_refs`/`output_ref` contain no trace of the API key | pending |
| 3 | Model validation — valid | Assign `gpt-4o` to Planner | Accepted | pending |
| 4 | Model validation — invalid | Assign `not-a-real-model` to Planner | Rejected with a clear validation error | pending |
| 5 | Fallback on real provider failure | Simulate an OpenAI error (e.g. rate limit) via a test double | `Runner` retries against `fallback_model`, identical code path to the Mock Provider failure test in crx-004 | pending |
| 6 | Credential storage is encrypted at rest | Inspect the raw `crux_settings` row for `openai_api_key` | Value is not plaintext in the database | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | Connect OpenAI | Administration → Providers → enter a valid API key → Save | Provider shows "connected"; key field does not redisplay the raw value on reload | pending |
| 2 | Real agent call end-to-end | With OpenAI connected and Planner assigned `gpt-4o`, send the canonical CRM prompt | Plan is generated via a real OpenAI call, not Mock Provider, with a real `crux_runs.tokens_in/tokens_out/cost` recorded | pending |
| 3 | Model editor reflects the catalog | Administration → Models | Dropdown for each agent's model/fallback lists only `Models::Catalog` entries, not free text | pending |
| 4 | Disconnect OpenAI | Remove the API key | Provider reverts to "not_configured"; any agent still assigned an OpenAI model falls back to Mock Provider or a clear "provider not configured" run failure, not a crash | pending |
| 5 | Non-admin access to Providers/Models/Settings | A non-`crux:administer` user attempts these Administration pages | 403, consistent with crx-001's admin-gating pattern | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | OpenAI key present but invalid/expired | A real call is attempted | `Runner`'s existing failure/fallback handling (crx-004) catches it identically to a simulated Mock Provider failure — no special-cased error handling needed for "real" vs "mock" failures | pending |
| 2 | Both primary (OpenAI) and fallback (also OpenAI, e.g. `gpt-4o` → `gpt-4o-mini`) fail | Recorded as a failed `crux_runs` row per crx-004's existing Scenario 2 handling — this task adds no new failure-handling code path, it only adds a real provider that can exercise the existing one | pending |
| 3 | API key rotated mid-session | An in-flight `RunAgentJob` using the old key | Fails cleanly with a retry option, does not silently use a cached stale key indefinitely — next invocation picks up the new key | pending |
| 4 | Agent assigned an OpenAI model while OpenAI is disconnected | Attempt to invoke that agent | Clear "provider not configured" failure recorded in Run Ledger, surfaced to the user, not a silent Mock Provider substitution the user didn't ask for | pending |

### QA Test Plan

**Scope**: OpenAI provider connection/disconnection, credential security (encryption, no logging/prompt leakage), Model Layer validation, and real end-to-end agent invocation via a real provider.

**Pre-conditions**:
- crx-001 through crx-005 in place.
- A valid (test/sandbox) OpenAI API key available for QA use.

**QA Steps**:
1. As admin, connect a valid OpenAI API key; confirm "connected" status and that the key never redisplays.
2. Assign `gpt-4o` to Planner; send the canonical CRM prompt; confirm a real plan is generated and `crux_runs` shows real token/cost figures (not Mock Provider's fixed canned values).
3. Attempt an invalid model assignment; confirm rejection.
4. Disconnect the API key; re-attempt the same prompt; confirm a clear, non-crashing failure is recorded.
5. Inspect application logs and the `crux_runs` table directly; confirm the API key never appears anywhere.
6. As a non-admin, attempt to reach Providers/Models/Settings directly by URL; confirm 403.

**Expected Outcomes**:
- The API key is never observable outside Administration → Providers' own write-only form, encrypted at rest, absent from every log and Run Ledger row.
- Model assignment is impossible outside the validated catalog.
- Real provider failures are handled by the exact same code path crx-004 already built and tested against Mock Provider.

**Out of Scope**:
- Any provider other than OpenAI and the already-shipped Mock Provider.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | An early draft risked adding provider-specific conditionals inside `Crux::Agents::Runner` (e.g. `if agent.provider == 'openai'`) to handle OpenAI's response shape, which `architecture.md` explicitly prohibits ("no agent-side branching on provider name"). | Code Changes, `open_ai.rb` row; Implementation Notes | All OpenAI-specific handling is contained entirely inside `Providers::OpenAI`; `Runner` is unmodified from crx-004 and remains provider-agnostic. |
| 2 | HIGH | `crux_agents.model`/`fallback_model` validation was deferred by crx-004's own Gate 3 (Part B item #2) pending a real model list — left unresolved, this task would ship with agents still assignable to nonexistent model strings. | Code Changes, `agent.rb` modify row; Test Case Unit #3/#4 | `Models::Catalog` introduced specifically to close this deferred item. |
| 3 | MEDIUM | The Providers tab risked showing all 7 canonical providers as generically "not configured" without being explicit that only OpenAI is actually wired this task — a reviewer could mistake the placeholder rows (Anthropic, Gemini, etc.) for functional-but-unconfigured rather than genuinely not-yet-implemented. | Code Changes, `global_crux_providers_controller.rb` row | Spec explicitly states these remain truthful placeholders (Phase 2 scope), not silently implying near-term availability. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | This task introduces the plugin's first real credential — the single highest-severity thing that could go wrong is the API key leaking into logs, the Run Ledger, or a redisplayed form field. | Code Changes; Implementation Notes; Test Case Unit #2, #6 | Encrypted storage, write-only field, explicit "never appears in Run Ledger/logs" requirement, and a dedicated test asserting it. |
| 2 | HIGH | Storing the key in plaintext (or with reversible-but-weak obfuscation) in `crux_settings.value` would violate `security.md`'s "encrypted at rest" requirement. | Code Changes, migration row | Specified to use real attribute-level encryption (Rails' built-in `encrypts` or equivalent), not custom obfuscation. |
| 3 | MEDIUM | A key-rotation-mid-session race (an in-flight job using a stale key after rotation) needed explicit handling to avoid an ambiguous silent failure. | Test Case Edge #3 | Specified: next invocation picks up the new key; in-flight jobs fail cleanly on the old one rather than silently succeeding with mismatched state. |
| 4 | LOW | No new N+1/pagination surface — this task's data volume (one credential, ~10 catalog models) is trivial; confirmed no performance finding applies. | — | No action needed. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — provider-agnostic `Runner` (no branching), `Models::Catalog` validation, truthful placeholder status for unwired providers, encrypted credential storage, write-only field, and key-rotation handling are all concrete rows/notes above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Credential accidentally interpolated into a prompt string | A debugging convenience temporarily logs the full request payload including the Authorization header | Yes — Unit Test #2 and the general "never appears in Run Ledger/logs" requirement; implementation must also confirm no framework-level HTTP request/response logging captures headers in production config |
| 2 | Silent mass-assignment via a missing `permit` key | The Models editor form accepts a `provider` field change without validating it against a known provider list, similar to the model-list gap this task closes for `model`/`fallback_model` | Yes — covered by Test Case Unit #3/#4's validation requirement, extended implicitly to `provider` itself; implementation must validate provider identifiers the same way as model identifiers |
| 3 | Date/time or quota logic incorrectly assumed | None applicable — this task has no time-based or quota logic (Billing Engine enforcement is out of scope for Phase 1's engine tasks) | Not applicable — no finding |
| 4 | Wrong `dependent:` on association | `crux_settings` credential row deletion path (disconnect) must not cascade-delete unrelated global settings rows if they share a table without careful scoping | Yes — Functional Test #4 (disconnect flow) implicitly requires that only the targeted key/value pair is affected |
| 5 | Fallback silently masking a real provider outage | A real OpenAI outage falls back to `gpt-4o-mini` (still OpenAI) without any visible signal distinguishing "primary model swapped" from "provider fully down" | Yes — Edge Case #2 requires this be recorded and surfaced via Run Ledger/notification, consistent with crx-004's existing fallback-observability requirement |

Verdict: Approved.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
