# Crux — Release Plan

**Version**: 1.0 · **Status**: Draft

## Purpose

This document maps the four roadmap phases in [roadmap.md](roadmap.md) to shippable releases, defines Crux's versioning scheme, and gives rollout guidance for existing Redmine/Redmineflux instances — in particular, how the project-level module gate makes adoption zero-impact for any project that doesn't opt in.

## Scope

Covers release numbering (v0.1 through v4.0), what ships in each release, the versioning scheme, migration/rollout guidance for existing instances, and the feature-flag/module-gating strategy layered on top of Redmine's own module system. It does not redefine phase content (see [roadmap.md](roadmap.md)) or module/agent detail (see [architecture.md](architecture.md), [agent_catalog.md](agent_catalog.md)).

## Responsibilities

- Assign a release number to each unit of shippable scope and keep that mapping consistent with the four roadmap phases.
- Define how an existing Redmine instance upgrades the plugin, and how a single project opts into Crux without affecting any other project.
- Define the versioning scheme and the feature-flag layer used to expose in-progress capability safely.

## User Flow

For an administrator: install or upgrade the `redmine_crux` plugin → configure providers, models, and policies in Administration → nothing changes for any project yet. For a project manager: Project Settings → Modules → check **Crux AI** → the Crux tab and its nine Project Workspace tabs appear for that project only.

## UI Description

Rollout is visible in exactly one place per audience: the Administration section (global configuration, unaffected by per-project opt-in) and each project's **Modules** settings panel, where **☐ Crux AI** is the single switch that exposes the entire Project Workspace (see [plugin_overview.md](plugin_overview.md), [ui_design.md](ui_design.md)).

## Architecture

Release scope tracks the same 19 modules as [architecture.md](architecture.md); no release introduces a module outside that set. The module gate itself is not bespoke Crux machinery — it reuses Redmine's native project-module/permission pattern, the same mechanism any Redmine plugin uses to add an optional per-project feature, enforced at the routing layer so a project without the module checked has no route into Crux's controllers, not merely a hidden menu item.

## Components

### Release map

| Release | Phase | Ships | Type |
|---|---|---|---|
| v0.1 | — | This documentation set — vision, architecture, and specification documents. No executable code. | Docs only |
| v1.0 | Phase 1 | Chat, Project Creation, Issue Creation, Planning, Approval Workflow; the 7 GA agents; Run Ledger; Approval Engine; core Administration and Project Workspace tabs; single-provider Provider Layer | GA |
| v1.1 | Phase 2 (early) | The first Phase 2 capability to reach users ahead of the full phase — for example, a second model provider or the GitHub connector — shipped incrementally rather than held for v2.0 | Incremental |
| v2.0 | Phase 2 (complete) | Agent Collaboration (Security Agent, Code Reviewer GA), Multiple AI Providers, GitHub Integration, Slack Integration all GA | GA |
| v3.0 | Phase 3 | Automated Sprint Planning, Code Review, Test Generation, Knowledge Search; Product Owner, Scrum Master, and Release Manager agents GA — twelve-agent catalog complete | GA |
| v4.0 | Phase 4 | Multi-Agent Workflows, MCP Support, Custom Agents, Future Marketplace | GA |

### Versioning scheme

MAJOR.MINOR.PATCH, where MAJOR aligns to a completed roadmap phase (v1 = Phase 1 complete, v2 = Phase 2 complete, and so on), MINOR marks a feature wave shipped within an in-progress phase (v1.1, v1.2, …), and PATCH marks fixes or security patches with no scope change. The v0.x series is reserved for pre-GA work — documentation, design, and any alpha/internal builds that precede v1.0.

### Feature-flag / module-gating strategy

Two layers, both reusing patterns already native to Core Platform:
1. **Module gate** (coarse) — Project Settings → Modules → **Crux AI**. Binary, per project, enforced at routing. This is the safety boundary: a project that never checks the box is never touched by any Crux release.
2. **Policy-level feature flags** (fine) — within an opted-in project, Administration's **Policies** tab can gate individual in-progress capabilities (for example, piloting Automated Sprint Planning on one project before it is GA org-wide, or enabling MCP Support for a design-partner project ahead of v4.0). This layer lets a release ship code without every opted-in project seeing every capability on day one.

## Sequence Flow

```
Plugin upgrade (admin)
        │
        ▼
Existing projects: unchanged (module unchecked)
        │
        ▼
Admin configures providers/policies (org-wide, no project impact yet)
        │
        ▼
Project opts in:  ☐ Crux AI  →  ☑ Crux AI
        │
        ▼
Crux tab + 9 Project Workspace tabs appear for that project only
```

## Design Decisions

- Plugin version upgrades and project-level adoption are deliberately decoupled: installing v2.0 does not turn Crux on anywhere by itself, so upgrading is never itself a change-management event for teams not using Crux.
- Release numbering tracks roadmap phases exactly (v1 = Phase 1, v2 = Phase 2, v3 = Phase 3, v4 = Phase 4) rather than calendar time, so "what's in v3.0" is always answerable by reading [roadmap.md](roadmap.md).
- Incremental MINOR releases (v1.1, v1.x) exist specifically so a phase's earliest-ready feature doesn't wait for every other feature in that phase.

## Assumptions

- v0.1 (documentation) precedes any code; no released version ships code before v1.0.
- Downgrading the plugin, or unchecking the module, does not delete a project's `crux_*` data — it stops new writes for that project, leaving existing history intact and re-enable-able, consistent with the Run Ledger's append-only design in [database_design.md](database_design.md).
- Policy-level feature flags are an Administration → Policies capability from Phase 1 onward, even though the phases that most need them (piloting Phase 3/4 features) come later.

## Risks

- **Silent scope creep in MINOR releases** — if v1.1/v1.x incremental releases aren't tracked against the roadmap, a phase's "complete" MAJOR release (v2.0) can arrive with undocumented drift from what [roadmap.md](roadmap.md) promised.
- **Module gate bypassed by direct URL/API access** — the routing-layer enforcement must cover API endpoints, not just menu visibility, or a disabled module could still leak access.
- **Mid-flight state on opt-out** — a project with open Pending Actions or an in-progress execution plan whose module gets unchecked mid-plan needs defined behavior (see Open Questions); undefined behavior here is a rollout risk for every release.

## Open Questions

- What happens to an execution plan awaiting approval, or a Run in progress, if a project's Crux AI module is unchecked mid-flight — is Crux AI a hard block, or does the plan safely persist for reactivation on re-enable?
- Do policy-level feature flags need their own audit trail distinct from the Run Ledger, given they gate capability rather than execute an action?
- Should v0.1 (documentation-only) be tagged in the same release train as code releases, or tracked separately since it ships no runtime behavior?

## Best Practices

- Before enabling a new MINOR release's feature flag on a production project, confirm it in a pilot project first — the same "start small, expand" guidance [vision.md](vision.md) gives for agent adoption applies to release adoption.
- Keep the release map in this document synchronized with [roadmap.md](roadmap.md) whenever phase scope changes; treat a mismatch between the two as a documentation defect.

## Example Scenarios

An organization running Redmine upgrades to Crux v2.0. No project changes behavior on upgrade day. Two weeks later, a PM checks **Crux AI** on one active project; that project alone gains the Overview, Chat, Agents, Runs, Knowledge, Automations, Pending Actions, Analytics, and Settings tabs, while every other project in the instance is unaffected.

An administrator piloting v4.0's MCP Support enables the corresponding policy flag for a single design-partner project weeks before enabling it instance-wide, observing audit and cost impact through [analytics.md](analytics.md) before wider rollout.

## Future Enhancements

A self-service in-app release notes/changelog view inside Administration, staged rollout percentages for policy-level flags (rather than project-by-project only), and marketplace-specific versioning for third-party agents are natural extensions once the four-phase release train is established; see [future_scope.md](future_scope.md).
