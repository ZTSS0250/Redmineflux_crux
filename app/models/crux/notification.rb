module Crux
  class Notification < ActiveRecord::Base
    self.table_name = 'crux_notifications'

    belongs_to :user

    validates :event_type, presence: true

    # Polymorphic ref with no DB-level FK (database_design.md's accepted
    # risk) — resolving it must degrade gracefully rather than raise if the
    # referenced row is ever gone.
    def ref
      klass = ref_type.to_s.safe_constantize
      return nil unless klass

      klass.find_by(id: ref_id)
    rescue StandardError
      nil
    end
  end
end
