module Crux
  # Single entry point for every agent invocation (crx-004 Objectives: "every
  # agent invocation runs as a background job"). Always re-resolves the
  # agent (and its `enabled` flag) from the database inside #perform, never
  # from a value captured at enqueue time -- this is what makes disabling an
  # agent take effect for a job already sitting on the queue (Edge Case #2),
  # not just for jobs enqueued afterward.
  #
  # Used two ways:
  #  - `perform_later(conversation_id: ...)` -- true async, enqueued by
  #    Crux::ChatEngine once a conversation reaches `planned` with no
  #    existing plan (Requirement Analyst -> Planner hand-off).
  #  - `.new.perform(plan_step_id: ...)` -- called directly (no second queue
  #    hop) from Crux::RetryManager, which already runs inside crx-003's
  #    async Crux::ExecutePlanJob and needs an immediate true/false result to
  #    drive its own attempt-count retry loop. Reusing this exact class/
  #    method, rather than duplicating its dispatch logic, is what keeps
  #    "every agent invocation" behaviorally identical regardless of which
  #    path triggered it.
  class RunAgentJob < ActiveJob::Base
    queue_as :default

    def perform(conversation_id: nil, plan_step_id: nil)
      return dispatch_for_step(Crux::PlanStep.find(plan_step_id)) if plan_step_id
      return dispatch_for_conversation(Crux::Conversation.find(conversation_id)) if conversation_id

      false
    end

    private

    def dispatch_for_conversation(conversation)
      user = conversation.user
      project = conversation.project

      requirement_analyst = Crux::Agent.effective(role: 'requirement_analyst', project: project)
      return false unless requirement_analyst

      ra_ok = Crux::Agents::Runner.call(agent: requirement_analyst, user: user, conversation: conversation)
      return false unless ra_ok

      planner = Crux::Agent.effective(role: 'planner', project: project)
      return false unless planner

      Crux::Agents::Runner.call(agent: planner, user: user, conversation: conversation)
    end

    def dispatch_for_step(step)
      plan = step.execution_plan
      conversation = plan.conversation
      user = User.find(plan.approved_by || conversation.user_id)
      agent = Crux::Agent.effective(role: step.responsible_agent_role, project: conversation.project)
      return false unless agent

      Crux::Agents::Runner.call(agent: agent, user: user, conversation: conversation, step: step)
    end
  end
end
