## Metadata
- **Task ID**: crx-026-feature-developer-agent-git-workflow
- **Title**: Developer Agent Git Workflow — propose diff, approve, execute git write, open PR (Phase 4)
- **Type**: feature
- **Status**: specification
- **Complexity**: HIGH
- **Created**: 2026-07-10
- **Author**: Sheetal Sharma (Planning section derived by Claude from `agent_catalog.md`, `integrations.md`, `security.md`, `database_design.md`, and existing `crx-003`/`crx-009`/`crx-021`/`crx-024` specs — no live developer dictation session; confirm before implementation)
- **Quality Gates**: Gate 1: Approved | Gate 2: Approved | Gate 3: Approved

---

## Planning
*(Derived from the documentation set and existing specs — flagged per the note above)*

**Description**:

This task is a **deliberate, user-approved scope expansion that supersedes existing canonical doc text**. `agent_catalog.md`'s Developer Agent entry currently states: "Purpose: Produces implementation guidance for issues and tasks — never commits code directly... Limitations: Does not write, commit, or run code or tests." This task explicitly amends that — Developer Agent gains the ability to draft a real diff against a connected GitHub repository and, only after a human approves the resulting plan step, have Crux execute the actual git write (branch, commit, push) and open a pull request. **Crux never merges** — a human always completes that step separately on GitHub's own side. This is the first task in the backlog where an agent's output becomes real code in a real external repository, so its design deliberately extends three already-approved mechanisms — crx-003's approval gate, crx-009's GitHub connector credentials, crx-024's Tool Registry read/write contract — rather than inventing a fourth, parallel one.

**Confirmed governance decision** (per direct user confirmation): `create_pull_request` is an ordinary `crux:approve` action, **not** added to `PlanStep::DESTRUCTIVE_ACTIONS`. A PR is reversible (closeable without merging, unlike delete/deploy) and Crux's complete non-participation in merging is itself the primary blast-radius control — not the rarer permission. If a future task ever adds "Crux may merge a PR," that action should very likely become `crux:approve_destructive`; this task does not build that capability and does not decide that permission now.

**Goal**:

A user (or a triggered conversation) asks Developer Agent to implement a change on a project with a connected GitHub repository (crx-009). Developer Agent clones the repository read-only into an ephemeral, isolated workspace, drafts a diff against real file content, and submits it as an ordinary `awaiting_approval` `crux_plan_steps` row (`action_type: create_pull_request`) containing the full diff for human review in the Approval card. On approval, Crux re-validates the diff against the current base branch, creates a namespaced branch, commits (bot identity + an `Approved-by` trailer naming the human), pushes, and opens a PR — recording the resulting PR URL/number in the Run Ledger. Crux's involvement ends there.

**Objectives**:
- [ ] Register two tools with crx-024's Tool Registry under a new "git" category: `git.read_repository` (`requires_approval: false` — clone/fetch/inspect, executes inline) and `git.propose_change` (`requires_approval: true` — branch/commit/push/PR, always produces a plan step, never executes directly).
- [ ] Add `create_pull_request` as a recognized `crux_plan_steps.action_type` value — explicitly confirmed **not** added to `PlanStep::DESTRUCTIVE_ACTIONS` (crx-003).
- [ ] Reuse crx-009's existing `crux_integrations` (`provider: github`) connector row and credentials for both the read and write halves — no new credential surface, no raw personal token anywhere.
- [ ] Implement `Crux::Git::Provider` (abstract) + `Crux::Git::Providers::GitHub` (concrete) for hosting-API-specific operations (default-branch lookup, PR creation); implement `Crux::Git::Workspace` for provider-agnostic ephemeral clone/branch/commit/push mechanics.
- [ ] Implement `Crux::Git::DiffValidator`: path-traversal containment, size/file-count limits, a sensitive-path deny-list, binary-file rejection — enforced at **both** draft time and execution time, never trusted once and forgotten.
- [ ] Guarantee ephemeral workspace cleanup on every code path (success, failure, crash) via an `ensure`-wrapped sequence, plus a TTL-based sweep job as a backstop against a crashed/killed process.
- [ ] Explicitly evaluate and reject raw terminal/shell tool access as part of this task's scope, documenting why.
- [ ] Update `documents/agent_catalog.md`'s Developer Agent entry to reflect this new, bounded capability (a described Code Change for whoever implements this task — not executed as part of writing this specification).

**Deliverables**:
- [ ] `Crux::Git::Provider` (interface) + `Crux::Git::Providers::GitHub` (implementation).
- [ ] `Crux::Git::Workspace` (ephemeral clone/branch/commit/push mechanics).
- [ ] `Crux::Git::DiffValidator`.
- [ ] `Crux::Git::ChangeProposer` (read-half tool logic, registered as `git.read_repository`/feeding `git.propose_change`).
- [ ] `Crux::Git::ChangeExecutor` + `Crux::Git::ExecuteChangeJob` (write-half, invoked only from `WorkflowEngine`'s `approved → executing` transition via crx-024's `Dispatcher#execute_approved!`).
- [ ] `crux_settings` policy keys: `git.max_diff_bytes`, `git.max_files_changed`, `git.sensitive_path_denylist`, `git.workspace_ttl_seconds`, `git.workspace_quota_bytes`.
- [ ] Approval card (crx-003) extended to render a syntax-highlighted, file-by-file diff view for `create_pull_request` steps.
- [ ] Updated `agent_catalog.md` Developer Agent entry (described here; executed at implementation time).

**Out of Scope**: Crux merging a PR itself (a deliberate, permanent-for-this-task boundary — no `merge_pull_request` method exists anywhere in this task's code); a general-purpose terminal/shell tool (evaluated and explicitly rejected — see Implementation Notes); GitLab/Bitbucket `Crux::Git::Provider` implementations (interface generalized now, second implementation is future work, mirroring crx-006's OpenAI-only-for-now pattern); fully autonomous fix-and-merge for "low-risk" changes with no human approval (contradicts Principle 2 as currently understood); automatic conflict resolution/rebase when the base branch has moved (fails clean back to `planned` instead); CI-status-aware follow-up on an opened PR (a distinct future capability with its own tool-vs-plan-step governance question).

---

## Specification

**Complexity**: HIGH

**Reason**: This is the first task where an agent's output becomes real code in a real external repository — a categorically new class of consequence beyond every prior HIGH task. It simultaneously extends three previously-HIGH mechanisms at once (crx-003's approval gate with a new, deliberately-non-destructive action type; crx-009's GitHub credentials, now used for a write path crx-009 never contemplated; crx-024's Tool Registry, whose first real write-capable tool category this is). It introduces the plugin's first host-filesystem I/O (every other engine to date is DB- or web-API-only) and its first structured, adversarially-shaped untrusted-input class (a diff/patch requiring path-traversal and size validation, distinct from crx-021's plain-text untrusted tool responses). It also amends a canonical doc rather than merely citing it. Matches and exceeds the cross-module + security-changes + new-class-of-risk criteria that made crx-003/009/021/024 HIGH.

### Code Changes

| File | Action | Description |
|------|--------|-------------|
| `app/lib/crux/git/provider.rb` | create | Abstract interface: `#default_branch(repo)`, `#authenticated_clone_credential(repo)`, `#open_pull_request(repo:, branch:, base:, title:, body:) → {url:, number:}`. Mirrors `Crux::Providers::Base`'s "one interface, credentials read only inside the call boundary" shape (crx-004/crx-006). |
| `app/lib/crux/git/providers/git_hub.rb` | create | GitHub implementation; resolves the project's `crux_integrations` (`provider: github`) row, exchanges the stored credential for a short-lived, repo-scoped token only inside this class, calls GitHub's API for default-branch lookup and PR creation. |
| `app/services/crux/git/workspace.rb` | create | Ephemeral per-run working directory: unique unguessable path (keyed by `SecureRandom.uuid` + the owning `crux_plan_steps`/`crux_runs` id) under a dedicated non-web-served scratch root, mode `0700`; path-containment validation on every file write; guaranteed removal via an `ensure` block wrapping the entire operation sequence. |
| `app/services/crux/git/diff_validator.rb` | create | Path-traversal/out-of-root rejection; configurable max diff size/file count (`crux_settings`); sensitive-path deny-list (CI/workflow config, dotfiles, `.git/`); binary-file rejection. Invoked at both draft time and execution time. |
| `app/services/crux/git/change_proposer.rb` | create | Read-half: clones read-only, drafts a diff against real content, runs `DiffValidator`, hands the result to `Crux::Agents::Runner`/crx-024's `Dispatcher` to become a `create_pull_request` plan step via `#propose`. Registered in crx-024's Tool Registry as `git.read_repository` (inline clone/inspect) feeding `git.propose_change` (`#propose`). |
| `app/services/crux/git/change_executor.rb` | create | Write-half `#execute`, invoked only via crx-024's `Dispatcher#execute_approved!` on the step's `approved → executing` transition: re-validates the diff against the *current* base HEAD, creates the branch, commits (bot identity + `Approved-by` trailer), pushes, opens the PR, records `{url, number}` into that invocation's `crux_runs.output_ref`. |
| `app/jobs/crux/git/execute_change_job.rb` | create | Background job wrapping `ChangeExecutor`; re-checks the step is still `approved` at execution time, not only enqueue time — the same precedent crx-004's Gate 2 established for agent-enablement checks. |
| `app/models/crux/plan_step.rb` (crx-003) | modify | Add `create_pull_request` to the recognized `action_type` vocabulary. Explicitly **not** added to `PlanStep::DESTRUCTIVE_ACTIONS` (confirmed governance decision above). |
| `app/views/shared/_crux_approval_card.html.erb` (crx-003) | modify | Render a syntax-highlighted, file-by-file diff view for `create_pull_request` steps (reading `payload`'s `diff_ref`), alongside the existing step-table rendering. |
| `documents/agent_catalog.md` | modify (doc, described here — not executed by this specification) | Update Developer Agent's Purpose/Limitations to reflect the new, bounded capability, replacing the "never commits code... does not write, commit, or run code" text this task deliberately supersedes. |
| `crux_settings` rows (no migration) | config | New global-scope keys: `git.max_diff_bytes`, `git.max_files_changed`, `git.sensitive_path_denylist`, `git.workspace_ttl_seconds`, `git.workspace_quota_bytes` — mirroring crx-003's retry-count precedent (a setting that must exist before the UI to manage it does). |

**No new database migrations.** This task reuses `crux_plan_steps.action_type` (new value only), crx-009's existing `crux_integrations` row/config, `crux_runs.output_ref` (PR reference recorded here per the established reference-not-inline pattern), and `crux_settings` (new key/value rows) — matching `database_design.md`'s explicit "never add a new table to shadow `crux_runs`... extend the query, not the schema" best practice and crx-021's identical precedent.

### Implementation Notes

- **Read-half (clone-and-draft) is unprivileged read, no approval needed; write-half (branch/commit/push/PR-open) only after approval — confirmed, with a sharpened caveat.** Governance-wise this is the direct, correct reading of Principle 2, which gates create/delete/close/deploy/bulk-update, not read. But unlike crx-005's Repository knowledge-source retrieval (which reads through Redmine's own already-integrated SCM browser), a `git clone` here is a genuinely new kind of read — a live outbound network call using stored connector credentials, writing to local disk. "No approval needed" must not be read as "no security control needed" — that's exactly why workspace isolation, path containment, and credential scoping (below) are mandatory on the read half too, even though it isn't approval-gated.
- **TOCTOU handling**: the workspace used to draft the diff is not blindly reused untouched across the approval gap. At execution time (`ChangeExecutor`, post-approval), the base branch is re-fetched and the stored diff is re-validated (`git apply --check` or equivalent) against its *current* HEAD before anything is written. If the base branch has moved in a way the diff no longer applies cleanly, the step fails clean and the plan returns to `planned` (crx-003's existing rejected/edited loop) with a "base branch changed, please regenerate" message — it never force-applies a stale patch. This is the same "propose against a snapshot, re-verify before mutating" discipline crx-003 already requires for atomic plan-step transitions, applied here to repository state instead of `crux_execution_plans.status`.
- **`create_pull_request` is ordinary `crux:approve`, not destructive — the confirmed governance decision.** A PR is reversible (close without merging; delete the branch) — categorically unlike `delete_project`/`delete_milestone`/`deploy`, the three entries `PlanStep::DESTRUCTIVE_ACTIONS` currently names, all irreversible or externally consequential in a way nothing here undoes. Direct precedent: crx-009 already treats GitHub outbound writes (comments, status checks) as ordinary `crux:approve` despite reaching an external system — this is the same risk class, one step further along the same connector. `security.md`'s own Best Practice warns against inflating `crux:approve_destructive` ("grant narrowly... not a superset assumed to follow from `crux:approve`") — folding a reversible action into that list to hedge against a vaguely larger "external blast radius" would blur the one thing that makes the destructive list useful. The actual containment of blast radius comes from branch namespacing, diff validation, and — critically — no merge capability at all, not from gating behind the rarer permission. **When to revisit**: if a future task ever adds "Crux may merge the PR," that action should very likely become `crux:approve_destructive` — flagged for that future task, not decided here.
- **Crux never merges — a deliberate, permanent-for-this-task omission, not a gap.** `Crux::Git::Provider` has no `merge_pull_request` method anywhere in this task's code. This gives two independent human checkpoints (Crux's own approval gate, and GitHub's separate PR review/merge) before code reaches a protected branch — meaningful defense in depth even if one gate were somehow subverted. **When to revisit**: only as its own dedicated, separately-reviewed future task with its own Gate 2 review and, per the point above, very likely its own destructive-action classification.
- **No arbitrary shell/terminal access — explicitly evaluated and rejected.** The entire design here depends on a closed, enumerable action space (clone, branch, commit, push, open-PR) whose effects can each be validated, size-limited, and rendered as a reviewable diff before execution. A hypothetical `terminal_tool` would be an open action space — there is no way to enumerate in advance what an arbitrary shell command could do, so none of the structural mitigations here (path containment, size limits, deny-lists) would apply; the only available mitigation would be a runtime sandbox/command-allowlist, a categorically larger and different security investment (container-escape surface, network-egress control, resource exhaustion) than "validate a text diff." It would also break this task's governance model: a shell command's effect isn't a reviewable diff the way a git patch is, so Principle 2's "approve the actual state-changing action" can't be satisfied for it the same way. Raw shell access is out of scope for this task and would need its own, separately-reviewed, heavily sandboxed task if ever pursued — not folded into this tool set later without that review.
- **Commit attribution uses the connector's bot identity plus an `Approved-by` trailer, never the approving human's own git identity** — Crux doesn't hold personal git credentials, so it cannot truthfully author as a human. The human's authority is recorded in the commit message (`Approved-by: <name/email>`, `Crux-Plan-Step: #<id>`), mirroring crx-009's already-resolved pattern ("authority resolves to the connector-configuring human, without inventing a new identity mechanism") extended to commit metadata.
- **Zero new database migrations, reusing existing reference-not-inline conventions.** `payload`'s `diff_ref` and `output_ref`'s PR reference both follow the same "reference, not inline content" rule `prompt_ref`/`context_refs` already established (crx-004/crx-005) — a real source diff can be sizable, so it is never embedded as raw JSON on the row itself.

---

## Test Cases

### Unit Tests
| # | Test Name | Input / Condition | Expected Result | Status |
|---|-----------|-------------------|-----------------|--------|
| 1 | Read-half executes without approval | Developer Agent calls `git.read_repository` | Clones and drafts a diff inline, no plan step created yet | pending |
| 2 | Write-half always creates a plan step | Developer Agent calls `git.propose_change` | An `awaiting_approval` `crux_plan_steps` row (`action_type: create_pull_request`) is created; no branch/commit/push/PR occurs yet | pending |
| 3 | `create_pull_request` is not destructive | Inspect `PlanStep::DESTRUCTIVE_ACTIONS` after this task ships | Does not include `create_pull_request`; only `delete_project`, `delete_milestone`, `deploy` | pending |
| 4 | Ordinary approval executes the write | A user holding `crux:approve` (not `crux:approve_destructive`) approves a `create_pull_request` step | Approval succeeds; `ChangeExecutor` runs | pending |
| 5 | Path-traversal rejection | A diff containing a `../` path or absolute path outside the workspace root | `DiffValidator` rejects it at both draft time and execution time | pending |
| 6 | Size/file-count limits | A diff exceeding `git.max_diff_bytes`/`git.max_files_changed` | Rejected outright at draft time, not silently truncated | pending |
| 7 | Sensitive-path deny-list | A diff touching a CI/workflow config file or `.git/` | Rejected at draft time, before a plan step can even be created | pending |
| 8 | TOCTOU re-validation | Base branch moves between draft and approval such that the diff no longer applies cleanly | `ChangeExecutor` fails clean, plan returns to `planned`, no patch is force-applied | pending |
| 9 | Commit attribution | An approved change executes | Commit author is the connector's bot identity; commit message includes `Approved-by: <human>` | pending |
| 10 | No merge capability exists | Inspect `Crux::Git::Provider`'s public interface | No `merge_pull_request` method exists anywhere | pending |

### Functional Tests
| # | Test Name | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1 | End-to-end propose → approve → PR opened | Ask Developer Agent to implement a small change on a connected test repo; approve the resulting plan step | A real branch is created, committed, pushed, and a PR is opened; the PR URL is recorded and visible in the Runs tab | pending |
| 2 | Approval card renders the diff | Open Pending Actions for a `create_pull_request` step | A syntax-highlighted, file-by-file diff is shown, not just a generic step description | pending |
| 3 | Rejecting a proposed change | Reject a `create_pull_request` step | No git operations occur; plan returns to `planned` for revision | pending |
| 4 | Reused GitHub credentials, no new credential prompt | Exercise this task's full flow on a project with crx-009's GitHub connector already configured | No new credential UI/prompt appears — the existing connector is reused transparently | pending |

### Edge Cases
| # | Scenario | Expected Behaviour | Status |
|---|----------|--------------------|--------|
| 1 | Workspace cleanup on mid-sequence failure | A push fails partway through `ChangeExecutor`'s sequence | The `ensure` block still removes the ephemeral workspace directory | pending |
| 2 | Crashed job leaves an orphaned workspace | A job is killed (e.g. OOM) mid-sequence, skipping its own `ensure` block | The TTL-based sweep job removes the orphaned directory once it exceeds the configured TTL | pending |
| 3 | Retry after a transient push failure | A push is rejected due to a remote race, then retried (crx-003's `RetryManager`) | The retry is idempotent — it does not create a duplicate branch/commit/PR if the first attempt partially succeeded | pending |
| 4 | Binary file in the diff | A proposed diff includes a binary file change | Rejected in v1 — not meaningfully reviewable in a diff-based Approval card | pending |
| 5 | Disk quota exceeded | Aggregate ephemeral workspace storage exceeds `git.workspace_quota_bytes` | A new clone is refused with a clear error rather than silently degrading host disk | pending |
| 6 | No GitHub connector configured | Developer Agent invoked on a project with no enabled `crux_integrations` (`provider: github`) row | Degrades to today's guidance-only behavior — no `git.*` tools are available, no error, no credential prompt | pending |

### QA Test Plan

**Scope**: The full propose → approve → execute → PR-opened flow, diff validation (path/size/sensitive-path/binary), TOCTOU re-validation, commit attribution, workspace isolation/cleanup, and confirmation that no merge capability and no destructive-gate misclassification exist anywhere.

**Pre-conditions**: crx-001 through crx-025 in place (specifically crx-009 for the GitHub connector and crx-024 for the Tool Registry); a test GitHub repository with a connected connector; a test branch protection setup to confirm Crux never pushes to the base branch directly.

**QA Steps**:
1. Ask Developer Agent to implement a small, well-scoped change; confirm a diff-bearing plan step appears in Pending Actions.
2. Approve it; confirm a namespaced branch, an attributed commit, and a real PR are created — and that the PR URL is recorded in the Runs tab.
3. Attempt a diff with a path-traversal attempt, an oversized diff, a sensitive-path change, and a binary file — confirm each is rejected at draft time.
4. Move the base branch (e.g. merge an unrelated change) between drafting and approving a separate proposal; confirm the stale proposal fails clean at approval time rather than force-applying.
5. Force a mid-sequence failure (e.g. simulate a push rejection); confirm workspace cleanup still occurs and a retry doesn't duplicate the branch/PR.
6. Confirm no code path anywhere merges the opened PR.
7. Confirm a `crux:approve`-only user (no `crux:approve_destructive`) can approve the step.

**Expected Outcomes**: No unapproved git write ever occurs; no adversarial diff content escapes validation; Crux's involvement always ends at "PR opened," never "PR merged."

**Out of Scope**: GitLab support; autonomous merge; raw shell access.

---

## Quality Gates

### Gate 1 — Senior Developer Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Read/write split could blur if the read-half and write-half shared code paths, risking a push happening before approval. | Code Changes, `change_proposer.rb`/`change_executor.rb` rows | Kept as two distinct classes; only `ChangeExecutor` ever touches push/PR-open, invoked exclusively from crx-024's `Dispatcher#execute_approved!` on the `approved → executing` transition. |
| 2 | HIGH | Partial-failure mid-sequence (branch created + committed, but push or PR-open fails) had no defined retry/idempotency story, risking duplicate branches/PRs on retry. | Implementation Notes; Test Case Edge #3 | `ChangeExecutor`'s sequence is designed idempotent-retryable, keyed by the deterministic branch name — a retry checks whether the branch/commit/PR already exists before re-creating. |
| 3 | HIGH | Risk of a second, bespoke tool-calling mechanism parallel to crx-024's registry, rather than genuinely building on it. | Objectives, Deliverables | Designed explicitly as two registered tools (`git.read_repository`, `git.propose_change`) reusing crx-024's read-inline/write-always-a-plan-step split, not a Developer-Agent-only bespoke code path. |
| 4 | MEDIUM | `DiffValidator` trusted once at draft time could go stale by execution time (base branch moved, or the validator's own rules changed). | Implementation Notes (TOCTOU handling); Test Case Unit #5/#8 | Re-invoked at execution time as well, not just draft time. |

Verdict: Approved.

### Gate 2 — Security & Performance Review
Date: 2026-07-10 | Status: complete

| # | Severity | Finding | Location in Spec | Resolution |
|---|----------|---------|-----------------|------------|
| 1 | HIGH | Path traversal via a hallucinated/adversarial diff (absolute paths, `../` segments, symlink escape) writing outside the intended checkout — the single most concrete new attack surface this task introduces. | Code Changes, `diff_validator.rb` row; Test Case Unit #5 | Mandatory path-containment check, enforced at both draft and execution time (TOCTOU-safe), with a dedicated test. |
| 2 | HIGH | Credential leakage — the GitHub token appearing in `payload`, `diff_ref`, `output_ref`, or logs, including on failure. | Implementation Notes; existing crx-006/009/021 precedent reused | `Crux::Git::Providers::GitHub` reads/exchanges the credential only inside its own call boundary; never persisted into logged/persisted content. |
| 3 | HIGH | Workspace cross-visibility — two concurrent runs able to read/clobber each other's in-flight workspace. | Code Changes, `workspace.rb` row | Unique, unguessable per-run directory, `0700` permissions, never under a web-served path. |
| 4 | HIGH | TOCTOU: base branch moves between draft and approval; a stale diff gets force-applied anyway, potentially corrupting the target branch or applying unintended changes. | Implementation Notes; Test Case Unit #8 | `ChangeExecutor` re-validates against current base HEAD before any write; on mismatch, fails clean back to `planned`. |
| 5 | HIGH | `create_pull_request`'s destructive-vs-ordinary classification is the single highest-stakes governance decision in this task — misclassifying it either way (too permissive or needlessly restrictive) has real consequences. | Confirmed via direct user question before finalizing this spec; Test Case Unit #3 | Explicitly confirmed ordinary `crux:approve`, with the reasoning and revisit condition documented in Implementation Notes; directly tested that it is absent from `DESTRUCTIVE_ACTIONS`. |
| 6 | MEDIUM | Diff size/file-count limits enforced only loosely (e.g. UI-side truncation) rather than server-side, letting an approver approve something they didn't fully see. | Code Changes, `diff_validator.rb` row; Test Case Unit #6 | Enforced server-side; an oversized diff is rejected outright at draft time, never silently truncated then approved. |
| 7 | MEDIUM | Sensitive-path changes (CI/workflow config, `.git/`, dotfiles) proposed without special scrutiny. | Code Changes, `diff_validator.rb` row; Test Case Unit #7 | Deny-list enforced before a plan step can even be created. |
| 8 | MEDIUM | Ephemeral workspace accumulation exhausting host disk if jobs crash without cleanup. | Objectives; Test Case Edge #1/#2/#5 | `ensure`-block cleanup plus a TTL-based sweep job backstop and a configurable disk quota. |

Verdict: Approved.

### Gate 3 — Pre-Development Sweep
Date: 2026-07-10 | Status: complete

**Part A — Gate 1 & 2 resolution confirmed**: Confirmed — the two-class read/write split, idempotent-retry design, genuine crx-024 registry reuse, TOCTOU re-validation at execution time, path-traversal/credential-leakage/workspace-isolation controls, the confirmed non-destructive classification, server-side size limits, sensitive-path deny-list, and workspace cleanup/quota are all concrete rows/tests above.

**Part B — Predicted implementation bugs**:
| # | Pattern | Predicted Bug | Edge Case Added? |
|---|---------|--------------|-----------------|
| 1 | Job re-checks status only at enqueue time | `ExecuteChangeJob` dispatched before a concurrent rejection lands, then executes anyway | Not directly test-covered by a dedicated edge case in this task's list (the underlying pattern is already covered by crx-004's identical precedent and this task's Test Case Unit #4/`RetryManager` reuse); flagged for implementation attention — re-check `approved` status at execution time, not enqueue time |
| 2 | `ensure` wraps only part of the sequence | A mid-sequence exception (e.g., push fails) skips workspace cleanup, leaking a directory | Yes — Edge Case #1 |
| 3 | Retry assumes a clean slate | A retried job re-runs branch creation and fails because the branch already exists from a partially-successful first attempt | Yes — Edge Case #3 |
| 4 | Ambient git config used for commits | The workspace inherits the host's local/global git identity instead of an explicit bot identity per clone | Not directly test-covered by a dedicated edge case; flagged for implementation attention — `user.name`/`user.email` must be set explicitly per clone, never relying on ambient config |
| 5 | Unbounded full-history clone | Cloning full history increases time/disk per run unnecessarily when only a diff against the current HEAD is needed | Not directly test-covered (a performance optimization, not a correctness/security issue); flagged for implementation attention — prefer a shallow clone where sufficient |

Verdict: Approved. Items #1, #4, and #5 are implementation-time attention items rather than dedicated tests, since #1 is already covered by an existing cross-task precedent and #4/#5 are implementation-quality concerns rather than independently observable correctness/security behaviors distinct from what's already tested.

---

## Done

- **PR**: —
- **Merged**: —
- **Release Notes entry**: —
