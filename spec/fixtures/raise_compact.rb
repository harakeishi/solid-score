class CompactRaiser
  def renew(plan)
    return false unless plan
    raise StandardError, "missing" if plan.empty?
    plan.upcase
  end
end
