# Crux — Security

**Version**: 1.0 · **Status**: Draft

## Purpose

Security in Crux keeps Core Principles 4 (Enterprise Governance) and 6 (Secure by Construction) true under real load: every action permission-checked against the acting user's actual Redmine access, every credential protected, every record of what happened immutable. This is the canonical reference for Crux's RBAC permissions, identity model, and data-protection posture.

## Scope

Covers the 9 canonical Crux permissions, the ACL design decision, project isolation, provider/API key protection, encryption, audit-log immutability, rate limiting, and compliance posture. Does not cover the Approval Engine's workflow mechanics ([workflow_engine.md](workflow_engine.md)) or the Run Ledger's schema ([database_design.md](database_design.md)) beyond what explains immutability.

## Responsibilities

- Define and enforce the 9 Crux permissions using Redmine's own ACL, with no parallel permission system.
- Ensure agents can only read or write what the acting user could already read or write in Redmine.
- Filter Knowledge Engine results by the requesting user's permissions before ranking, never after.
- Store and transmit provider credentials, tokens, and secrets so they are never exposed in logs, prompts, or the Run Ledger.
- Keep the Run Ledger append-only so audit history cannot be edited or backdated.
- Apply per-user and per-project rate limits to contain runaway or abusive usage.

## User Flow

1. A Redmine administrator grants Crux permissions to a role exactly as any other Redmine permission, under Roles & Permissions.
2. A user's visible Crux surface (chat, approvals, agent settings, billing, analytics) is a direct function of which of the 9 permissions their role holds on that project.
3. When an agent acts for a user, the action is checked against that user's permissions, not the agent's — an agent has no standing authority of its own.
4. A denied action surfaces the same way a denied Redmine action would: a clear message, logged as a denial, not a silent no-op.

## UI Description

Permissions appear inside Redmine's existing Roles & Permissions screen under a "Crux" group, not a separate permissions UI — reinforcing one ACL, not two. Administration → Crux → Security surfaces account-wide settings (rate limits, retention, data residency); project-level visibility of what a role can do is read directly from Redmine's permissions screen, per [ui_design.md](ui_design.md).

## Architecture

Security is not a single module — it is enforced at the boundary of every module in [architecture.md](architecture.md): the Chat and Workflow Engines check permissions before accepting or executing a request; the Knowledge Engine filters before ranking; the Run Ledger accepts inserts but never updates or deletes.

```
Request (user or integration) → permission check (Redmine ACL) → module boundary
   Knowledge Engine: filter-by-permission --> rank --> return
   Workflow Engine:  permission check --> plan --> approval gate --> execute
   Run Ledger:       append-only insert (no update/delete path exists)
```

## Components

**RBAC permission table**

| Permission | Grants |
|---|---|
| use_crux | See the Crux tab, use chat, view own runs |
| crux:approve | Approve or reject execution plans |
| crux:approve_destructive | Approve delete- or deploy-class plan steps specifically |
| crux:manage_agents | Enable/disable agents, edit prompts (tier-gated further by the Billing Engine) |
| crux:manage_knowledge | Toggle which knowledge sources are indexed |
| crux:manage_integrations | Configure project-level integrations |
| crux:view_billing | See project-level usage and billing |
| crux:view_analytics | See project AI dashboards |
| crux:administer | Global, admin-only: providers, global settings, cross-project dashboard |

**Agent identity** — each agent has a real Redmine User row (or a dedicated agent flag) with real Role assignments on the project it works in. This is why @-mentioning an agent, checking what it may touch, and listing it as a project member all reuse Redmine's existing member/role machinery instead of a second, parallel authorization system.

**Project isolation** — the Knowledge Engine applies a permission filter before ranking any retrieval candidate, not after. A document the requesting user cannot see in Redmine is excluded from the candidate set entirely, so it can never surface in a response, citation, or relevance score.

**Provider/API key security** — provider credentials (OpenAI, Anthropic, Google Gemini, Azure OpenAI, Ollama, local models, and others behind the Provider Layer) are stored encrypted and scoped per-provider, never embedded in prompt text or agent configuration. Secrets are excluded from logs, the Run Ledger, and exported usage reports by construction, not by redaction after the fact.

**Encryption** — data is encrypted at rest (database and any indexed knowledge store) and in transit (TLS for every Crux-to-provider and Crux-to-integration connection).

**Audit-log immutability** — the Run Ledger is append-only: every run is inserted once and never updated or deleted, which is what makes it usable as the single source for audit, billing, and dashboards simultaneously (see [billing.md](billing.md)).

**Rate limiting** — applied per-user (one account's runaway usage) and per-project (a project's aggregate load), independent of any provider-side limits.

## Sequence Flow

```
User/agent action → Redmine ACL check (permission present?)
   no  → denial logged, action refused
   yes → Knowledge Engine filters candidates by permission → module executes
      → Run Ledger append (immutable) → Notification Engine (if applicable)
```

## Design Decisions

- **Reuse Redmine's ACL, no parallel system** — Crux permissions are checked through Redmine::AclBase like any native permission, so a project's existing role structure is the single source of truth for what a user, or an agent acting for them, can do. A parallel system would require every access decision kept in sync twice; reuse removes that class of drift entirely.
- **Agents are Users, not a special actor type** — a real User row with real Role assignments means permission checks, @-mentions, and audit attribution all use one mechanism, and an agent's access shrinks or grows exactly as a human's would.
- **Filter-before-rank** — the Knowledge Engine's permission filter runs before ranking so an unauthorized document can never influence relevance scoring, even transiently.
- **Append-only Run Ledger** — no update or delete path exists at the schema or application layer, so "the log says X happened" cannot be contradicted later by an edited row.

## Assumptions

- The Redmine instance's own authentication (password policy, SSO/LDAP) is the trust boundary Crux inherits; it does not introduce a second login system.
- Provider API keys are organization-level secrets managed by crux:administer, not per-user secrets.
- Enterprise on-prem/local indexing still enforces filter-before-rank inside the customer's own environment.

## Risks

- **Role sprawl** — over-permissioned project roles are a Redmine-wide risk Crux inherits, amplified when an agent acting under that role runs at machine speed.
- **Prompt-borne secret leakage** — a user could paste a credential into chat; this needs its own handling (e.g., redaction heuristics) distinct from Crux's own credential protections, to avoid it landing in the Run Ledger or Knowledge Engine index.
- **Rate-limit evasion via multiple entry points** — chat, integrations, and MCP inbound reach the same execution path; per-user limits must aggregate across entry points, not apply separately to each.

## Open Questions

- Should crux:approve_destructive require a second, independent approver for the highest-risk plan steps?
- How is a compromised agent User row detected and revoked distinctly from a compromised human account?
- What is the default Run Ledger retention before Enterprise-configurable retention applies, and can shortening it conflict with billing reconciliation ([billing.md](billing.md))?

## Best Practices

- Audit project roles for over-broad Crux grants on the same cadence as other Redmine permission reviews.
- Grant crux:approve_destructive narrowly — rarer than crux:approve, not a superset assumed to follow from it.
- Rotate provider API keys on a schedule and immediately on staff offboarding, since a leaked key affects every project using that provider.

## Example Scenarios

**Read-only settings surface**
> A user without crux:manage_integrations opens Settings → Integrations and sees the list read-only — the UI reflects the ACL rather than duplicating it with its own check.

**Knowledge filtering before ranking**
> A Developer Agent, acting as its own User with Developer-role permissions, is asked to reference a private wiki page it has no Role access to. The Knowledge Engine excludes that page before the agent's prompt is even assembled — the agent never learns it exists.

**On-prem indexing with central billing**
> An Enterprise customer configures on-prem indexing for a regulated project; indexed content never leaves their environment, but Run Ledger entries for runs against it still sync to the Billing Engine for quota purposes, per [billing.md](billing.md).

## Future Enhancements

Planned hardening — anomaly detection on agent-driven activity, configurable step-up approval for crux:approve_destructive, and expanded data-residency options beyond Enterprise on-prem indexing — is tracked in [future_scope.md](future_scope.md).
