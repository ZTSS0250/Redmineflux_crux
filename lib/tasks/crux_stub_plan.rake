namespace :crux do
  desc 'QA only: generate the canonical stub execution plan for a conversation. Usage: rake crux:stub_plan CONVERSATION_ID=1 [FAIL_ON=create_issues]'
  task stub_plan: :environment do
    conversation_id = ENV['CONVERSATION_ID']
    abort 'Usage: rake crux:stub_plan CONVERSATION_ID=<id> [FAIL_ON=<action_type>]' if conversation_id.blank?

    conversation = Crux::Conversation.find(conversation_id)
    plan = RedminefluxCrux::Seed::StubPlanGenerator.call(conversation: conversation, simulate_failure_on: ENV['FAIL_ON'])
    puts "Created Crux::ExecutionPlan##{plan.id} with #{plan.plan_steps.count} steps for conversation ##{conversation.id}."
  end
end
