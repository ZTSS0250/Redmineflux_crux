# Crux Plugin — Technical Design (v0.1 Draft)

| | |
|---|---|
| **Status** | Draft for review — architecture only, no build yet |
| **Inputs** | `CRUX-ONE-PAGER-2026.md` (pricing/GTM), `design_documents.md` (vision), this doc's own component split |
| **Scope** | How Crux is actually built as a Redmine/Redmineflux plugin — models, hooks, permissions, flow |

---

## 1. Reconciling the component lists

The vision doc named 9 pieces; you named 8. They're the same system described at two points in its lifecycle — collapse Chat + Approval into one Workflow Engine (they're really one state machine: draft → clarify → plan → approve → execute), and Integration Engine becomes explicit: MCP for agent-toolchain traffic, plus a thin Connector layer for GitHub/Slack/Teams. One addition: **Core Platform** isn't new work, it's Redmine itself — projects, issues, users, roles — which every other component reads and writes through, never around.

| Your component | Vision doc equivalent | What it actually is |
|---|---|---|
| Core Platform | *(implicit)* | Redmine's own Project/Issue/User/Role tables — Crux never duplicates these |
| Agent Engine | Agent Engine | Agent definitions, lifecycle, prompt/model config |
| Workflow Engine | Chat Engine + Approval Engine | Conversation state machine + the gate before execution |
| Context Engine | Knowledge Engine | Retrieval + permission filter over Redmine data |
| Run Ledger | Run Ledger | Every agent run, immutable, feeds audit + billing |
| MCP Integration | Integration Engine (partial) | Inbound/outbound MCP — external tools as clients of Crux |
| Billing & Subscription | Billing Engine | Outcome metering against the ledger, plan enforcement |
| Admin Console | Administration | Global settings, per-project settings, dashboards |

---

## 2. How this sits inside a Redmine plugin, concretely

Redmine plugins are Rails engines registered in `init.rb`. Crux is one plugin (`redmine_crux`) with this shape:

```
redmine_crux/
├── init.rb                          # Redmine::Plugin.register block
├── app/
│   ├── models/crux/                 # Agent, Run, Conversation, Outcome, KnowledgeSource...
│   ├── controllers/crux/            # ChatController, AgentsController, RunsController...
│   ├── views/crux/                  # chat, agents, runs, knowledge, automations, settings
│   ├── jobs/crux/                   # AgentRunJob, IndexKnowledgeJob (async, never inline)
│   └── helpers/crux/
├── lib/crux/
│   ├── workflow/                    # state machine: draft→clarify→plan→approve→execute
│   ├── agents/                      # agent runner, prompt assembly, model client
│   ├── context/                     # retrieval + permission filter
│   ├── mcp/                         # MCP server (inbound) + MCP client (outbound)
│   └── billing/                     # outcome meter, quota checks
├── config/
│   ├── routes.rb
│   └── locales/
├── db/migrate/
└── assets/
```

`init.rb` is where three Redmine-native hooks matter most:

- **`project_module :crux do permission :use_crux, {...} end`** — this is the literal implementation of "if the project checks the Crux module, the chatbot appears." No module = no menu item = no controller access (Redmine enforces this at the routing layer, not just the view).
- **`Redmine::MenuManager` entries** — adds "Crux" to the project menu (workspace tabs) and a top-level entry under Administration.
- **`settings :default => {...}, :partial => 'settings/crux_settings'`** — the plugin-level admin config screen (providers, models, global billing).

Everything downstream — chat, agents, runs — is normal Rails MVC underneath that gate.

---

## 3. Component design

### 3.1 Core Platform (Redmine, unmodified)
Crux reads/writes Projects, Issues, Users, Roles, Wiki, Versions, Time Entries through Redmine's existing models and `Issue.new(...).save` / ActiveRecord APIs — never raw SQL, never a shadow copy of project state. This is what keeps "same roles and approval gates as everyone else" true by construction rather than by policy.

**Key rule:** an agent's Redmine-side identity is a real `User` row (`type = 'CruxAgentUser'` or a dedicated agent flag), assigned real `Role`s on the project. This is why @-mentioning an agent and permission-checking it can reuse Redmine's existing member/role machinery instead of a parallel ACL system.

### 3.2 Workflow Engine (Chat + Approval, unified)
A single state machine per conversation:

```
draft → clarifying → planned → awaiting_approval → executing → completed
                                        ↓
                                   rejected / edited → planned (loop)
```

- `Crux::Conversation` holds state, project_id, user_id, agent_id.
- `Crux::ExecutionPlan` is the artifact shown at the approval gate — a list of proposed actions (`create_project`, `create_issue`, `resolve_issue`, `run_test`, `delete_milestone`, ...) each with a status.
- **The approval gate is the only place execution is authorized.** No agent code path calls `Issue.save` outside a plan step that has `approved_at` set by a real Redmine user. This is the technical enforcement of "human in control," not a UI convention.
- Destructive actions (delete, deploy) get a stricter gate: require a specific role/permission (`crux:approve_destructive`), separate from ordinary create/update approval.

### 3.3 Agent Engine
`Crux::Agent` = name, role (Planner/QA/Reporter/...), system prompt template, model + fallback model, temperature, per-agent permission scope, enabled/disabled per project.

Execution is a `Crux::AgentRunJob` (background, async — never block the request thread on an LLM call): assemble context (via Context Engine) → call model → parse structured output into plan steps or direct outputs → write to Run Ledger. Bundled agents (Planner, Requirement Analyst, Developer, QA, Documentation, Reporter, DevOps) are seed data, editable per your tiering (prompt-only on Starter, full pipeline edits from Team up) — that tier gate lives here, checked against Billing Engine's plan lookup.

### 3.4 Context Engine (Knowledge)
Retrieval is **filtered before ranking, not after**. For a given user+project, build the allowed-source set from Redmine's own permission checks (`User#allowed_to?`) first, then retrieve only from within it. This ordering is the whole point — it's what makes "AI only accesses data the current user is authorized to view" true even when the AI is confidently wrong about something.

Per-project toggles (Issues, Wiki, Repository, Files, Documents, News, Time Entries, Custom Fields, Helpdesk, CRM) map to a `Crux::KnowledgeSource` join table — admin picks sources, Context Engine only indexes/retrieves what's checked. Coverage Score (from the one-pager) is a derived metric: indexed objects ÷ total addressable objects across enabled Redmineflux modules for that project.

### 3.5 Run Ledger
Append-only. One row per agent run: user, agent, model, provider, prompt hash, context refs, tokens, cost, output ref, plan_step_id, approved_by, approved_at, timestamp. This table is deliberately the single source for three different consumers — Audit Logs (search/filter/export), Billing (outcome metering), and the Project Dashboard (success rate, most active agent). Never denormalize a second copy for billing; the one-pager's "billing event and acceptance event are the same click" only holds if there's one ledger, not one ledger plus a billing shadow table.

### 3.6 MCP Integration
Two directions, don't conflate them:
- **Inbound (Crux as MCP server):** exposes Redmine/Redmineflux operations as MCP tools so Claude Code/Cursor can pull the next ready task and write results back. Write-back is a real plan step through the Workflow Engine's approval gate — an external tool doesn't get to bypass governance just because it's calling MCP instead of using the chat UI.
- **Outbound (Crux as MCP client):** agents themselves may call out to configured MCP servers (GitHub, Slack, Teams) as tool calls during a run — logged in the Run Ledger like any other agent action.

### 3.7 Billing & Subscription
Reads the Run Ledger, writes nothing to it. `Crux::Outcome` is created only when a plan step's three tests pass (fixed deliverable type, human-approved gate, ledger receipt) — this is a query/materialization over ledger rows, not a separate manually-maintained counter. Quota checks (active projects, indexed objects, outcomes/mo) gate feature access at the Workflow Engine and Context Engine boundaries, not just at invoice time.

### 3.8 Admin Console
Two surfaces, both real Redmine screens, not a separate app:
- **Global** (`Administration → Crux`): providers/models, default agents, approval policies, rate limits, retention, plugin-wide billing view — this is the `settings :partial` screen plus a few dedicated admin controllers.
- **Per-project** (`Project → Crux` tab, only visible if module checked): Overview / Chat / Agents / Runs / Knowledge / Automations / Settings — your one-page-multiple-tabs instinct is right, and it maps directly to Redmine's existing tabbed-page convention (same pattern as Issues' own sub-nav).

---

## 4. End-to-end flow (matches your description, made explicit)

```
1. Admin enables "Crux AI" module on Project X                     [Core Platform]
2. Crux tab + Chat sub-tab appear for members with :use_crux perm  [Workflow Engine gate]
3. User: "Create a CRM system with Customer, Leads, Invoice modules"
4. Intent detection → Requirement Analyst agent picks it up         [Agent Engine]
5. Context Engine pulls existing project conventions if any        [Context Engine, permission-filtered]
6. Missing info? → Crux asks clarifying questions in chat           [Workflow Engine: clarifying]
7. User answers → Planner agent drafts Execution Plan               [Workflow Engine: planned]
8. Plan shown: create project, N issues, versions, wiki page        [UI: approval card]
9. User clicks Approve (or edits, or rejects)                       [Workflow Engine: awaiting_approval → executing]
10. Each plan step executes via real Redmine model calls            [Core Platform writes]
11. Each step + the run that produced it lands in the Run Ledger    [Run Ledger]
12. Outcome(s) materialize from completed, approved steps           [Billing Engine]
13. Project Dashboard + Admin Dashboard update                      [Admin Console]
```

---

## 5. Data model sketch (core tables only)

```
crux_agents            id, name, role, prompt_template, model, fallback_model, temperature, enabled, project_id(nullable=global)
crux_conversations      id, project_id, user_id, agent_id, state, created_at
crux_messages           id, conversation_id, role(user/agent/system), content, created_at
crux_execution_plans    id, conversation_id, status, approved_by, approved_at
crux_plan_steps         id, plan_id, action_type, target_type, target_id, status, payload
crux_runs               id, agent_id, plan_step_id(nullable), user_id, model, provider,
                        prompt_ref, context_refs, tokens_in, tokens_out, cost, output_ref, created_at
crux_outcomes           id, run_id, outcome_type, project_id, billed_at
crux_knowledge_sources  id, project_id, source_type, enabled
crux_settings           key, value, scope(global/project), project_id
```

`crux_runs` and `crux_outcomes` are the two tables the one-pager's entire pricing model rests on — worth treating them as close to immutable/append-only from day one, since retrofitting audit integrity later is much harder than designing for it now.

---

## 6. Permissions model

Reuses Redmine's `Redmine::AclBase` pattern — no parallel permission system:

| Permission | Grants |
|---|---|
| `use_crux` | See Crux tab, use chat, view own runs |
| `crux:approve` | Approve/reject execution plans |
| `crux:approve_destructive` | Approve delete/deploy-class steps specifically |
| `crux:manage_agents` | Enable/disable agents, edit prompts (tier-gated further) |
| `crux:manage_knowledge` | Toggle knowledge sources |
| `crux:view_billing` | See project-level usage/billing |
| *(global, admin-only)* `crux:administer` | Providers, global settings, cross-project dashboard |

---

## 7. Open questions before build scope

1. **Agent identity:** dedicated `User` subtype, or a lighter-weight `Member` that isn't a full user seat? Affects licensing math against "unlimited humans and agents."
2. **Sync vs. async chat:** is the first response to a prompt ever synchronous (fast intent detection), with only the actual agent run going async? Matters for perceived latency.
3. **Plan step granularity:** is "Create 42 Issues" one plan step or 42? Affects partial-approval UX and ledger row count.
4. **Multi-agent runs:** when Planner hands off to QA within one conversation, is that one Run Ledger row or a chain? Ties into outcome weighting (flagged as unresolved in the one-pager too).
5. **Where does Crux Context's index live** — same DB, separate vector store, or per-tier (per the one-pager's on-prem indexing note for Enterprise)?

---

*Next: pick which of the 8 components to detail into a full schema + API spec first — Run Ledger and Workflow Engine are the two with the least room for later rework, since billing and governance both depend on getting them right from the start.*