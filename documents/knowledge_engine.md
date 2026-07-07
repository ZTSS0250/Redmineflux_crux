# Knowledge Engine

*The retrieval and context subsystem that supplies every Crux agent with permission-scoped, project-scoped information.*

## Purpose

The Knowledge Engine (also referred to as the Context Engine) is what lets agents reason about a specific project instead of producing generic output. It indexes the data a project has opted into, filters that data to what the acting user is already permitted to see, and ranks it into the context window an agent uses on each call. Full module placement is in [architecture.md](architecture.md).

## Scope

**In scope**: the 11 canonical knowledge sources, the per-project toggle model, the permission-filter-before-rank principle, and the Coverage Score metric.

**Out of scope**: agent-specific reasoning over retrieved context ([agent_catalog.md](agent_catalog.md)); plan/approval flow ([approval_engine.md](approval_engine.md)); the underlying data schema, defined in full in [database_design.md](database_design.md).

## Responsibilities

- Enforce permission-filtering before ranking, on every retrieval, for every agent call.
- Maintain per-project enablement of each knowledge source via `crux_knowledge_sources`.
- Report indexing health through the Coverage Score.
- Supply ranked, budget-truncated context to the Agent Engine on demand.

## User Flow

1. A project admin enables the knowledge sources relevant to that project.
2. The Knowledge Engine indexes those sources continuously.
3. On each conversation turn, it builds the allowed-source set for the current user and project, retrieves within that set, ranks the result, and hands it to the Agent Engine.
4. The user never interacts with it directly — its effect surfaces only through agent output and the `context_refs` recorded against a run.

## UI Description

The **Knowledge Sources** settings page (project-level, gated by `crux:manage_knowledge`) lists all 11 sources with an enable/disable toggle, a per-source Coverage Score, and a last-indexed timestamp, plus an overall project Coverage Score. There is no separate end-user interface for retrieval itself — it is invisible infrastructure surfaced only through what agents produce.

## Architecture

The Knowledge Engine sits between the Agent Engine and Redmine's own permission system: it is called on every agent invocation, configured per project through `crux_knowledge_sources`, and always executes downstream of Redmine's native access checks and upstream of Provider Layer prompt assembly. See [architecture.md](architecture.md).

## Components

**The 11 canonical knowledge sources:**

| Source | What's Indexed |
|---|---|
| Issues | Subjects, descriptions, comments, custom field values |
| Wiki | Page content and revision history |
| Repository | Commit messages, diffs, and file contents from connected repositories |
| Documents | Uploaded document metadata and extracted text |
| Files | Project file attachments and extracted text |
| News | News item titles and body content |
| Forums | Forum topics and replies |
| Time Entries | Logged time descriptions and activity categorization |
| Helpdesk | Ticket subjects, descriptions, and resolution notes |
| CRM | Contact, lead, and deal records linked to the project |
| Custom Fields | Values of project, issue, and user custom fields |

**Per-project toggle model**: `crux_knowledge_sources(id, project_id, source_type, enabled)` — one row per project per source type. Disabling a source removes it from both indexing and the allowed-source set immediately; it is excluded from retrieval outright, not merely down-ranked.

## Sequence Flow

```
Agent Engine request (user, project, query)
        │
        ▼
Redmine Permission Check          (native ACL — what can this user see?)
        │  allowed source set
        ▼
crux_knowledge_sources            (enabled sources ∩ allowed set)
        │
        ▼
Retrieval                         (fetch candidates within allowed set only)
        │
        ▼
Ranking                           (score, order, truncate to context budget)
        │
        ▼
Agent Engine                      (assembled context)
```

## Design Decisions

> Retrieval is filtered before ranking, not after. For a given user+project, the allowed-source set is built from Redmine's own permission checks first, then retrieval happens only within it. This ordering is what makes "AI only accesses data the current user is authorized to view" true even when the AI itself is confidently wrong about something.

This is the single most important design constraint in the Knowledge Engine and the concrete mechanism behind Principle 6, Secure by Construction.

**Coverage Score** is defined as: indexed objects ÷ total addressable objects, across enabled modules, for that project. It is a per-source and overall metric, not a global one — it is meaningless outside the context of a specific project's enabled sources.

## Assumptions

- Redmine's native permission model is the single source of truth for what is "addressable"; the Knowledge Engine does not maintain a parallel access-control list.
- Indexing is near-real-time but not instantaneous; Coverage Score reflects the last completed index pass, not the current instant.

## Risks

- A low Coverage Score on a large repository or document set can silently degrade agent output with no obvious warning.
- Toggling a source off mid-conversation can produce inconsistent context between turns.
- Custom Fields has high schema variability across projects, risking noisy retrieval.

## Open Questions

- Should Coverage Score be surfaced to end users in conversation (for example, "answered using 62% of enabled sources"), or kept admin-only?
- Organization-wide retrieval (see Future Enhancements) will need a second permission-filter pass at the organization level — this has not yet been designed.

## Best Practices

- Enable only the sources a project actually uses, so Coverage Score stays meaningful.
- Re-index after bulk imports (a repository migration, for example) before relying on agent output.
- Treat a low Coverage Score as a signal to narrow agent scope, not a reason to disable the Knowledge Engine.

## Example Scenarios

A project enables Issues, Wiki, and Repository: 480 of 600 addressable issues are indexed, 40 of 40 wiki pages, 900 of 1,200 repository files.

```
Coverage Score = (480 + 40 + 900) / (600 + 40 + 1,200) = 1,420 / 1,840 ≈ 77%
```

An agent invoked here shows this 77% figure against the run, giving a reviewer a concrete reason to trust — or question — its output.

## Future Enhancements

RAG and vector-store support for semantic retrieval beyond keyword and structured matching; organization-wide (cross-project) retrieval with a second, organization-level permission-filter pass; incremental and streaming indexing to shrink the gap between a data change and its Coverage Score.
