module Crux
  module Agents
    # Shared invocation path for every agent (agent_catalog.md Architecture):
    # assemble context -> call the Provider Layer (primary model, falling
    # back once on failure) -> route the output to a direct chat reply or new
    # crux_plan_steps -> always write crux_runs -> write crux_outcomes only
    # when all 3 Outcome tests from billing.md pass.
    class Runner
      PROVIDER_NAME = 'mock'.freeze

      def self.call(agent:, user:, conversation:, step: nil)
        new(agent: agent, user: user, conversation: conversation, step: step).call
      end

      def initialize(agent:, user:, conversation:, step: nil)
        @agent = agent
        @user = user
        @conversation = conversation
        @step = step
      end

      # Returns true on a successful invocation, false otherwise (both
      # primary and fallback model failed, or the agent was disabled at
      # execution time). Crux::RetryManager uses this boolean directly to
      # decide whether its own attempt-count loop should retry the step.
      def call
        unless @agent.enabled?
          record_failed_run(reason: 'agent disabled')
          return false
        end

        context = Crux::Agents::ContextAssembler.assemble(conversation: @conversation, user: @user)

        outcome = invoke(@agent.model, context)
        outcome ||= invoke(@agent.fallback_model, context) if @agent.fallback_model.present?

        if outcome
          finalize(model: outcome[:model], result: outcome[:result])
          true
        else
          record_failed_run(reason: 'primary and fallback models both failed')
          false
        end
      end

      private

      def invoke(model, context)
        return nil if model.blank?

        result = Crux::Providers::Mock.new.call(
          prompt: prompt_text,
          context: context.merge(model: model, simulate_failure: simulate_failure?(model)),
          agent: @agent
        )
        { model: model, result: result }
      rescue Crux::Providers::Error
        nil
      end

      # QA-only seam, the same convention crx-003's stub_plan_generator
      # established with `simulate_failure`: `simulate_failure` fails both
      # primary and fallback (Edge Case #1); `simulate_primary_failure` fails
      # only the primary model so the fallback path is exercised
      # deterministically (Unit Test #2 -- crux_runs.model must reflect the
      # fallback, not the primary).
      def simulate_failure?(model)
        return false unless @step

        payload = @step.payload
        return true if payload['simulate_failure']
        return model == @agent.model if payload['simulate_primary_failure']

        false
      end

      def prompt_text
        "role:#{@agent.role} conversation:#{@conversation.id}"
      end

      def finalize(model:, result:)
        output_ref = route_output(result)
        run = write_run(model: model, tokens_in: result[:tokens_in], tokens_out: result[:tokens_out], output_ref: output_ref)
        materialize_outcome(run)
      end

      # A plan-step-driven invocation doesn't itself author chat/plan
      # content in this task's scope -- Crux::RetryManager (the caller, one
      # level up) owns marking the step completed/failed once this returns.
      def route_output(result)
        return "Crux::PlanStep:#{@step.id}" if @step

        if @agent.role == 'planner'
          create_plan_from(result[:content])
        else
          message = post_chat_reply(result[:content])
          "Crux::Message:#{message.id}"
        end
      end

      def post_chat_reply(content)
        text = content.is_a?(String) ? content : content.to_s
        @conversation.messages.create!(role: 'agent', content: text, agent_id: @agent.id)
      end

      # Requirement Analyst -> Planner hand-off (agent_catalog.md's only
      # wired hand-off for crx-004): two independent crux_runs rows, one per
      # agent, both referencing the same conversation_id -- not a single
      # merged row. Replaces crx-003's QA-only stub_plan_generator for real
      # conversations.
      def create_plan_from(steps)
        plan = Crux::ExecutionPlan.create!(
          conversation_id: @conversation.id,
          estimated_time: '~6 min',
          estimated_cost: '$0.42'
        )

        Array(steps).each do |step_data|
          Crux::PlanStep.create!(
            plan_id: plan.id,
            action_type: step_data[:action_type],
            target_type: step_data[:target_type],
            status: 'awaiting_approval',
            payload: step_data[:payload] || {}
          )
        end

        Crux::WorkflowEngine.submit_for_approval!(plan)
        post_chat_reply("Drafted a #{plan.plan_steps.count}-step execution plan — review it in Pending Actions.")
        "Crux::ExecutionPlan:#{plan.id}"
      end

      def write_run(model:, output_ref:, tokens_in: 0, tokens_out: 0)
        Crux::Run.create!(
          agent_id: @agent.id,
          plan_step_id: @step&.id,
          user_id: @user.id,
          model: model,
          provider: PROVIDER_NAME,
          prompt_ref: "crux_conversations:#{@conversation.id}",
          context_refs: 'history:conversation_messages',
          tokens_in: tokens_in,
          tokens_out: tokens_out,
          cost: 0,
          output_ref: output_ref,
          created_at: Time.current
        )
      end

      def record_failed_run(reason:)
        run = write_run(model: @agent.model, output_ref: "#{Crux::Run::FAILURE_PREFIX} #{reason}")
        Crux::NotificationEmitter.agent_run_failed(run)
        run
      end

      # Outcome materialization (billing.md's 3 tests, reused exactly):
      # (1) fixed deliverable type, not an open-ended chat reply -- only a
      #     plan-step-driven run qualifies; a direct chat reply (Requirement
      #     Analyst) or a Planner's own plan-authoring run never does
      #     (Unit Test #4, Edge Case #4).
      # (2) passed a human-approved gate -- already guaranteed by
      #     construction: Runner only ever executes a step that is already
      #     `executing`, which only happens after WorkflowEngine.approve!
      #     required human approval.
      # (3) has a Run Ledger receipt -- always true for a successful run,
      #     since `write_run` above always populates prompt/model/tokens/
      #     output refs.
      def materialize_outcome(run)
        return unless @step

        Crux::Outcome.create!(
          run_id: run.id,
          outcome_type: @step.action_type,
          project_id: @conversation.project_id,
          billed_at: nil
        )
      end
    end
  end
end
