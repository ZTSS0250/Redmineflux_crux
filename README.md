# Crux Documentation Set

**Version**: 1.0 · **Status**: Draft — docs-first, no code yet

Crux transforms Redmine into an AI-Native Project Management Platform. Instead of AI being a chatbot, AI becomes a team member capable of planning, analyzing, documenting, testing, reviewing, coordinating, and assisting users throughout the complete project lifecycle — every action permission-aware, auditable, governed, and approved by humans. This README is the entry point to the 20-document set that specifies Crux end to end.

## Purpose

Orients a new reader: what Crux is (above), documentation status, the full document list, and reading order. No product or engineering detail lives here — every claim below points to the document that owns it.

## Scope

In scope: indexing the 20 documents, reading order, and recording that this set supersedes the repository's earlier drafts. Out of scope: everything else — see Components for where each topic lives.

## Responsibilities

Keep the index below accurate as documents change; be the first file a new contributor, reviewer, or stakeholder opens. Does not duplicate content owned by [vision.md](vision.md) or [architecture.md](architecture.md).

## User Flow

Path depends on role: a stakeholder or new hire starts at [vision.md](vision.md) and [plugin_overview.md](plugin_overview.md); an engineer goes to [architecture.md](architecture.md), [system_design.md](system_design.md), and [database_design.md](database_design.md); a reader chasing one capability jumps straight to that topic document via its cross-links.

## UI Description

Not applicable to this document. UI structure for the Project Workspace and Administration surfaces is specified in [ui_design.md](ui_design.md).

## Architecture

Not applicable to this document. The 19-module system architecture is specified in [architecture.md](architecture.md).

## Components

The set has 20 documents. Read them in this order:

| # | Document | Description |
|---|---|---|
| 1 | [README.md](README.md) | Entry point and reading guide for the full Crux documentation set (this file) |
| 2 | [vision.md](vision.md) | Product vision, mission, six core principles, and success criteria |
| 3 | [plugin_overview.md](plugin_overview.md) | What Crux is at a glance: target users, competitive differentiation, feature summary |
| 4 | [architecture.md](architecture.md) | The 19 architecture modules and how they fit together |
| 5 | [system_design.md](system_design.md) | Engineering design of the core engines and how data flows between them |
| 6 | [database_design.md](database_design.md) | Schema sketches for Crux's core tables and their relationships |
| 7 | [ui_design.md](ui_design.md) | Project Workspace and Administration tab structure and interaction design |
| 8 | [workflow_engine.md](workflow_engine.md) | The conversation state machine and the approval-gated execution lifecycle |
| 9 | [chat_engine.md](chat_engine.md) | Conversation Engine, Intent Detection, and Clarification Engine in detail |
| 10 | [agent_catalog.md](agent_catalog.md) | The 12 AI agents: responsibilities, scope, and rollout phase |
| 11 | [knowledge_engine.md](knowledge_engine.md) | Permission-filtered retrieval across Redmine's 11 knowledge sources |
| 12 | [approval_engine.md](approval_engine.md) | The approval gate: policies, roles, and destructive-action safeguards |
| 13 | [integrations.md](integrations.md) | External connectors and MCP: GitHub, Slack, Teams, Jenkins, and more |
| 14 | [billing.md](billing.md) | Outcome metering, the Billing Engine, and plan enforcement |
| 15 | [security.md](security.md) | Permissions model, governance guarantees, and secure-by-construction design |
| 16 | [analytics.md](analytics.md) | Dashboards, reporting, and usage analytics across projects and organization |
| 17 | [roadmap.md](roadmap.md) | Phased delivery plan, Phase 1 through Phase 4 |
| 18 | [release_plan.md](release_plan.md) | Release strategy, versioning, and rollout milestones |
| 19 | [future_scope.md](future_scope.md) | Long-term direction beyond Phase 4, including the Future Marketplace |
| 20 | [glossary.md](glossary.md) | Canonical definitions of terms used across the documentation set |

## Sequence Flow

Recommended order: `vision.md → plugin_overview.md → architecture.md → [topic docs in table order] → roadmap.md`. Topic docs (5–16) can be read in any order once architecture.md is understood.

## Design Decisions

Each fact — a name, a table, a principle — has exactly one owning document; every other document links to it rather than restating it. Duplicating facts across 20 parallel-authored documents is the single biggest risk to a set this size, hence this README carries no product detail of its own.

## Assumptions

- Readers have baseline familiarity with Redmine (projects, issues, roles, modules).
- The set is docs-first: no implementation exists yet, so no document should describe shipped behavior as fact.
- All 20 documents share one kernel of names and facts (agents, modules, tables, permissions, tabs) and must not introduce alternate names for them.

## Risks

- With six agents authoring in parallel, terminology drift (a renamed agent, a reordered tab list) is the primary risk to this set; correct drift against the shared kernel, don't propagate it.
- Cross-reference links can rot as documents are edited independently; treat broken links as defects.

## Open Questions

- What triggers a version bump of the whole set versus a single document?
- Once implementation begins, do these documents get a sibling `docs/api/` set, or evolve in place?

## Best Practices

- Update the table above whenever a document is added, renamed, or removed.
- Prefer a cross-reference link over restating another document's content.
- Use only the canonical names defined in [glossary.md](glossary.md) — no synonyms for agents, modules, tables, or permissions.

## Example Scenarios

A new engineer reads [vision.md](vision.md) for why, [plugin_overview.md](plugin_overview.md) for what, [architecture.md](architecture.md) for how, then drills into [workflow_engine.md](workflow_engine.md) and [agent_catalog.md](agent_catalog.md). A stakeholder preparing a demo needs only [vision.md](vision.md), [plugin_overview.md](plugin_overview.md), and [roadmap.md](roadmap.md).

## Future Enhancements

This set formalizes and supersedes the repository's earlier drafts — the previous `vision.md`, `design_documents.md`, and `technical_design.md`. Their still-relevant content is folded in: `design_documents.md` into [vision.md](vision.md), [plugin_overview.md](plugin_overview.md), and [ui_design.md](ui_design.md); `technical_design.md` into [architecture.md](architecture.md), [system_design.md](system_design.md), and [database_design.md](database_design.md). Those three files remain in the repository for historical reference only. Once implementation begins, this README should link to wherever API/code-level documentation lives.
