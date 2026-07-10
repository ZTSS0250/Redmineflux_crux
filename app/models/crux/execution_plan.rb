module Crux
  class ExecutionPlan < ActiveRecord::Base
    self.table_name = 'crux_execution_plans'

    belongs_to :conversation, class_name: 'Crux::Conversation', foreign_key: 'conversation_id'
    # Never :destroy — an execution plan is the audit record of what was
    # proposed/approved; deleting it out from under its steps would risk
    # silent loss of that record, so deletion is blocked rather than
    # cascaded (Gate 3 finding on `dependent:` choice).
    has_many :plan_steps, -> { order(:id) },
             class_name: 'Crux::PlanStep',
             foreign_key: 'plan_id',
             dependent: :restrict_with_error

    enum status: {
      planned: 'planned',
      awaiting_approval: 'awaiting_approval',
      executing: 'executing',
      completed: 'completed'
    }

    validates :conversation_id, presence: true
  end
end
