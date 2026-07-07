# Chat Engine

The turn-based orchestration layer that combines the Conversation Engine, Intent Detection, and Clarification Engine into a single experience: a user sends a message, and the Chat Engine decides whether to ask a question, assemble context and hand off to an agent, or decline the request.

## Purpose

To define how one chat turn is processed end to end — intent classification, clarification, context assembly, latency handling, and error handling — so that behavior is consistent across all 21 supported intents and every project, regardless of which agent ultimately picks up the request.

## Scope

Covered: the taxonomy of the 21 supported conversational intents and how they group; the mechanics of the Clarification Engine, including the canonical HRMS example; how prompt context is assembled conceptually; the UX for response latency while an agent runs asynchronously; and error handling for ambiguous, unsupported, or out-of-scope requests.

Not covered: plan approval and execution, which begin only after the Chat Engine hands a drafted plan to the Workflow Engine (see [workflow_engine.md](workflow_engine.md)); the visual layout of the Chat tab (see [ui_design.md](ui_design.md)); the full module map (see [architecture.md](architecture.md)); and the conversation and message table schema (see [database_design.md](database_design.md)).

## Responsibilities

The Chat Engine receives each user turn, runs Intent Detection against the 21 supported intents, decides whether the Clarification Engine needs to ask a follow-up question, assembles the context an agent needs to act, and — once enough information exists — hands the turn to the Workflow Engine to open or advance the execution plan. It also owns the conversational fallback when a request cannot be classified or is out of scope.

It does not gate or execute plan steps (Workflow Engine), does not decide which specific agent instance or model handles a request beyond routing by intent (Agent Engine, Provider Layer, Model Layer — see [architecture.md](architecture.md)), and does not render the interface (see [ui_design.md](ui_design.md)).

## User Flow

A user sends a message. The Chat Engine detects intent; if the request is one of the 21 supported intents but missing required information, the Clarification Engine asks a small set of specific questions and waits for answers before proceeding. Once intent and information are sufficient, the Chat Engine assembles context and hands off to the Workflow Engine, which opens (or advances) the execution plan and engages the responsible agent — for example, the Requirement Analyst on "Create a CRM System with Customer, Leads, and Invoice modules," which the Planner then turns into a draft plan. If the request cannot be classified, or falls outside the 21 intents, the Chat Engine responds with a clarifying question or a suggested-intent list instead of guessing.

### Intent taxonomy

All 21 supported intents, grouped for discoverability:

| Group | Intents |
|---|---|
| Project Setup | Create project, Generate roadmap |
| Planning | Generate milestones, Sprint planning, Backlog refinement, Estimate story points, Dependency analysis |
| Development | Create epics, Create issues, Resolve issue, Repository analysis |
| Documentation & Reporting | Generate documentation, Generate release notes, Daily standup, Weekly summary, Project health report |
| Analysis | Review bugs, Generate test cases, Knowledge search, Requirement generation, Risk analysis |

This grouping is a documentation and discoverability aid only — it is not a schema field, and an intent's group has no bearing on which agent handles it.

## UI Description

The Chat Engine's state is visible in the Chat tab (full mockup in [ui_design.md](ui_design.md)) through the composer and typing indicator:

```
[Composer: enabled]
        │ user sends message
        ▼
[Composer: disabled, "Planner is thinking…" ⋯]
        │ agent run completes (async, in the background)
        ▼
[Composer: enabled again, response appended to the thread]
```

Because agent runs execute asynchronously, the composer never blocks the rest of the workspace — a user can switch tabs while a run is in progress and return to find the thread updated.

## Architecture

The Chat Engine orchestrates three sub-modules described in [architecture.md](architecture.md): the Conversation Engine (turn and session state), Intent Detection (classification against the 21 intents), and the Clarification Engine (question generation and answer binding). Once a turn has a clear intent and enough information, the Chat Engine calls the Knowledge Engine for permission-filtered context and then hands the turn to the Workflow Engine, which is where plan generation and approval begin (see [workflow_engine.md](workflow_engine.md)).

## Components

- **Turn Manager** — tracks the current conversation's turn state and history.
- **Intent Classifier** — maps free text to one of the 21 canonical intents, or to "unclassified."
- **Context Assembler** — builds the packet an agent acts on: project identity, recent conversation history, permission-filtered knowledge, and any clarification answers collected so far.
- **Clarification Question Generator** — produces a small, specific set of follow-up questions for an under-specified request.
- **Suggested-Intent Fallback** — the pick-list offered when a request cannot be classified.
- **Typing/Progress Indicator Controller** — drives the composer's busy state while a run is in flight.

## Sequence Flow

The canonical conversation lifecycle:

```
User → Prompt → Intent Detection → Knowledge/Context Search
                                          │
                                No ◀──── Need Clarification? ────▶ Yes
                                │                                    │
                                │                          Ask Questions → Receive Answers
                                │                                    │
                                └──────────────┬─────────────────────┘
                                               ▼
                                  Generate Execution Plan → Preview
                                               │
                                    (handoff to Workflow Engine —
                                     see workflow_engine.md for
                                     approval and execution)
```

Context assembly, concretely, layers four inputs in order: the active project and the requesting user's role in it; the recent conversation history up to a bounded window; the knowledge sources enabled for the project and permitted for the user (never more than the user could see directly in Redmine); and the detected intent together with any clarification answers gathered so far.

## Design Decisions

Context assembly always filters knowledge by the requesting user's existing Redmine permissions — it narrows visibility, never widens it. On an ambiguous or unclassified request, the Chat Engine asks a clarifying question or offers the suggested-intent list; it never silently guesses, and this rule is absolute for anything that could resolve to a destructive action. Latency is handled by acknowledging the turn immediately with a typing indicator while the agent run executes asynchronously in the background and is tracked in the Run Ledger, rather than making the user wait on a blocking request. A conversation advances at most one plan lineage at a time; the Chat Engine will not open a second plan in the same conversation before the current one reaches `completed` (see [workflow_engine.md](workflow_engine.md)).

## Assumptions

Clarification rounds are capped at a small number of questions per message so a single reply is never overwhelming. A conversation's history window is bounded rather than unbounded, to keep context assembly predictable in size. Each conversation is single-intent at a time; a prompt that clearly bundles two unrelated requests is treated as ambiguous rather than silently split.

## Risks

A misclassified intent can route a request to the wrong agent, which is why a confidence threshold and a fallback to clarification exist rather than always acting on the top guess. Excessive clarification rounds risk user drop-off before a plan is ever generated. Long conversation history combined with large knowledge sets risks exceeding usable context size, which the bounded context window in Assumptions is meant to contain.

## Open Questions

Is there a maximum number of clarification rounds before the Chat Engine automatically escalates to the suggested-intent list rather than asking again? Can a user change intent mid-conversation without starting a new conversation, and if so, what happens to the plan already in `planned`? How should a single prompt that reasonably maps to two intents — for example, "create a CRM and summarize last sprint" — be handled: split into two plans, sequenced, or rejected as ambiguous?

## Best Practices

Ground every response in the 21 supported intents; never act on an unsupported one without saying so. Keep clarification questions specific and answerable in a single line, following the HRMS pattern. Never guess on a request that could resolve to a destructive action — always confirm explicitly before a destructive step is even drafted. Keep the asynchronous nature of agent work visible through the typing indicator rather than freezing the composer.

## Example Scenarios

**Clarification**: user asks "Create an HRMS." Crux asks: Which technology stack? Expected delivery timeline? Authentication method? Database? Expected modules? Deployment environment?

**Successful handoff**: user asks "Create a CRM System with Customer, Leads, and Invoice modules." The Requirement Analyst picks it up, and the Planner drafts the execution plan.

**Out of scope**: a user asks for something outside the 21 intents (for example, "order me a coffee"). The Chat Engine replies that it can't help with that here and offers the suggested-intent list instead of guessing at an action.

**Ambiguous**: a user says "clean up the backlog," which could map to Backlog refinement or to Resolve issue. The Chat Engine asks which one is intended rather than picking one silently.

## Future Enhancements

Parsing and sequencing multiple intents within a single prompt. Proactive intent suggestions based on project state, such as prompting Sprint planning near a sprint boundary. Voice input. Multi-turn plan refinement through follow-up chat after a Modify.
