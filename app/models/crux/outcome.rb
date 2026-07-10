module Crux
  class Outcome < ActiveRecord::Base
    self.table_name = 'crux_outcomes'

    belongs_to :run, class_name: 'Crux::Run'

    validates :run_id, presence: true
    validates :outcome_type, presence: true
    validates :project_id, presence: true
  end
end
