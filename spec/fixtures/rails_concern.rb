class AuditableRecord < ApplicationRecord
  include Comparable
  include ActiveModel::Validations
  include ActiveModel::Dirty
  include ActiveSupport::Callbacks

  def <=>(other)
    created_at <=> other.created_at
  end

  def audit_log
    @audit_log ||= []
  end

  def record_change(field, old_value, new_value)
    audit_log << { field: field, from: old_value, to: new_value }
  end
end
