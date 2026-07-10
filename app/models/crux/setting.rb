module Crux
  # Generic key/value configuration, scoped global or per-project
  # (database_design.md). This task's only consumer is the Retry Manager's
  # configurable max-attempts count, stored now even though the
  # Administration -> Policies UI that would edit it isn't built yet.
  class Setting < ActiveRecord::Base
    self.table_name = 'crux_settings'

    validates :key, presence: true
    validates :scope, inclusion: { in: %w[global project] }

    def self.get(key, scope: 'global', project_id: nil, default: nil)
      record = find_by(key: key, scope: scope, project_id: project_id)
      record ? record.value : default
    end

    def self.set(key, value, scope: 'global', project_id: nil)
      record = find_or_initialize_by(key: key, scope: scope, project_id: project_id)
      record.value = value
      record.save!
      record
    end
  end
end
