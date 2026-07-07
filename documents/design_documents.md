# CRUX Plugin — Vision & High-Level Design Document

| | |
|---|---|
| **Version** | 1.0 |
| **Status** | Draft |
| **Product** | Crux AI for Redmine / Redmineflux |

---

## 1. Vision

### Mission

Transform Redmine from a traditional project management system into an AI-native collaboration platform where humans and AI agents work together as a single team.

Instead of AI being a chatbot, Crux embeds intelligent agents directly into project workflows, allowing users to create, plan, develop, test, document, review, and manage software through natural conversation while maintaining complete governance, approvals, and auditability.

---

## 2. Problem Statement

Today's project management tools require users to manually perform many repetitive tasks.

Examples include:

- Creating projects
- Breaking requirements into issues
- Sprint planning
- Writing documentation
- Creating test cases
- Status reporting
- Assigning issues
- Reviewing project health

Existing AI assistants help answer questions but do not participate as governed members of a project team.

Organizations need an AI platform that:

- Understands project context
- Collaborates with users
- Executes approved work
- Operates under permissions
- Maintains complete audit history

---

## 3. Product Goal

Crux introduces AI Agents as first-class members of Redmine projects.

Users interact with Crux through conversational AI. Instead of navigating multiple pages and forms, users simply describe what they need.

**Example:**

> "Create a CRM System with Customer, Leads, and Invoice modules."

Crux:

1. Understands the request
2. Asks clarification questions
3. Prepares execution plan
4. Waits for approval
5. Creates the project
6. Generates roadmap
7. Creates issues
8. Assigns users
9. Generates documentation

---

## 4. Core Principles

### Human in Control

AI never performs major actions without user approval. Every important action requires confirmation.

### Conversation First

Natural language becomes the primary interaction model. Users describe outcomes instead of navigating complex forms.

### Governance

Every AI action is:

- Permission checked
- Approved
- Logged
- Auditable

### Modular

Each project chooses:

- Which agents are enabled
- Which knowledge sources AI can access
- Which integrations are active

### Secure

AI only accesses data that the current user is authorized to view.

---

## 5. Product Architecture

```
Redmine
├── Projects
├── Issues
├── Wiki
├── Repository
├── Files
├── Documents
└── Crux Plugin
    ├── Chat Engine
    ├── Agent Engine
    ├── Workflow Engine
    ├── Knowledge Engine
    ├── Approval Engine
    ├── Run Ledger
    ├── Billing Engine
    ├── Integration Engine
    └── Administration
```

---

## 6. Installation Experience

After installing the plugin:

```
Administration → Plugins → Crux
```

The administrator configures:

- AI Provider
- Models
- Billing
- Default Agents
- Integrations

> No project uses Crux until enabled.

---

## 7. Project Module

Each project receives a new module.

```
Project Settings → Modules → ☐ Crux AI
```

If enabled, the project menu displays:

- Overview
- Activity
- Issues
- Wiki
- Repository
- Crux

---

## 8. Crux Workspace

The Crux page is the central AI workspace.

### Tabs

- Overview
- Chat
- Agents
- Runs
- Knowledge
- Automations
- Settings

---

## 9. Chat Experience

Users communicate naturally.

**Example:**

> Create a Hospital Management System.

Crux performs:

```
Intent Detection
      ↓
Requirement Analysis
      ↓
Clarification Questions
      ↓
Execution Plan
      ↓
Approval
      ↓
Execution
      ↓
Completion
```

---

## 10. Conversation Lifecycle

```
User Prompt
      ↓
Intent Detection
      ↓
Context Retrieval
      ↓
Need Clarification? ── Yes ──► Ask Questions ──► Receive Answers
      ↓                                                  │
      └──────────────────────────────────────────────────┘
      ↓
Generate Execution Plan
      ↓
Preview
      ↓
User Approval
      ↓
Execute Tasks
      ↓
Generate Results
      ↓
Audit Log
```

---

## 11. Approval Workflow

Before execution, Crux shows an **Execution Plan**:

| Action | Status |
|---|---|
| Create Project | ✔ |
| Create Versions | ✔ |
| Create Milestones | ✔ |
| Generate Wiki | ✔ |
| Create 42 Issues | ✔ |
| Assign Users | ✔ |

**Buttons:** Approve · Reject · Edit Plan

> Only after approval does execution begin.

---

## 12. AI Agents

Initial bundled agents:

| Agent | Responsibilities |
|---|---|
| **Planner** | Creates roadmap and work breakdown |
| **Requirement Analyst** | Converts user ideas into specifications |
| **Developer** | Generates implementation guidance |
| **QA Agent** | Creates test cases; finds missing scenarios |
| **Documentation Agent** | Creates Wiki pages, technical documentation, release notes |
| **Reporter** | Standups, project summaries, sprint reports |
| **DevOps Agent** | Deployment guidance, environment validation, CI/CD assistance |

---

## 13. Administration

Administration contains a dedicated Crux section.

### Dashboard

Displays:

- Projects
- AI Runs
- Outcomes
- Token Usage
- Estimated Cost
- Active Agents
- Top Projects

### Agents

- Enable / Disable
- Configure Prompt
- Choose Model
- Permissions
- Temperature
- Limits

### Providers

- OpenAI
- Anthropic
- Gemini
- Azure OpenAI
- Ollama
- Mock Provider

### Models

- Default model
- Fallback model
- Context limits
- Temperature

### Audit Logs

Every action performed by AI — searchable, filterable, exportable.

### Billing

- Current subscription
- Outcome usage
- Token usage
- Monthly consumption
- Historical usage

### Integrations

- GitHub
- GitLab
- Slack
- Microsoft Teams
- Jira Migration
- Webhook
- Email

### Settings

- Default Agents
- Approval Policies
- Knowledge Sources
- Rate Limits
- Security
- Retention

---

## 14. Project Dashboard

Each project has its own AI dashboard. Displays:

- AI Runs
- Outcomes
- Success Rate
- Token Usage
- Most Active Agent
- Most Used Model
- Pending Approvals

---

## 15. Knowledge Sources

Project administrator chooses AI access:

- Issues
- Wiki
- Repository
- Files
- Documents
- News
- Time Entries
- Custom Fields
- Helpdesk
- CRM

---

## 16. Integrations

Project level:

- GitHub Repository
- Slack Channel
- Teams Channel
- Webhook
- CI/CD

---

## 17. Pending Actions

AI never performs destructive operations immediately.

**Queue example:**

| Pending Action | Status |
|---|---|
| Project Creation | Waiting Approval |
| Issue Generation | Waiting Approval |
| Delete Milestone | Waiting Approval |
| Deploy | Waiting Approval |

**User actions:** Approve · Reject · Modify

---

## 18. Audit Trail

Every execution stores:

- User
- Agent
- Model
- Provider
- Prompt
- Context
- Execution Time
- Cost
- Tokens
- Output
- Approval
- Timestamp

---

## 19. Future Roadmap

### Phase 1
- Chat
- Project Creation
- Issue Creation
- Planning
- Approval Workflow

### Phase 2
- Agent Collaboration
- Multiple AI Providers
- GitHub Integration
- Slack Integration

### Phase 3
- Automated Sprint Planning
- Code Review
- Test Generation
- Knowledge Search

### Phase 4
- Multi-Agent Workflows
- MCP Support
- Custom Agents
- Marketplace

---

## 20. Success Metrics

The Crux plugin is considered successful when users can:

- Create complete projects using conversation.
- Generate requirements and issue hierarchies with AI.
- Approve AI-generated execution plans before changes are applied.
- Use specialized agents (Planner, QA, Documentation, DevOps, etc.) within projects.
- Review all AI actions through audit logs and dashboards.
- Integrate AI workflows with external tools such as GitHub, Slack, and Microsoft Teams.
- Scale from simple AI assistance to governed multi-agent collaboration while preserving Redmine's permissions and project-based architecture.
