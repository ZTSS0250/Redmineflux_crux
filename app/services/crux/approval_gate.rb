module Crux
  # The permission-check specialization inside WorkflowEngine (architecture.md:
  # "not a separate module"). Called from exactly one place — WorkflowEngine —
  # never duplicated as a second controller-level check.
  class ApprovalGate
    def self.can_approve?(user, plan_step)
      project = plan_step.execution_plan.conversation.project
      return false unless user.allowed_to?(:crux_approve, project)
      return true unless plan_step.destructive?

      user.allowed_to?(:crux_approve_destructive, project)
    end
  end
end
