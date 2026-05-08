class ExpandedRaiser
  def renew(plan)
    return false unless plan

    if plan.empty?
      raise StandardError.new("missing")
    end

    plan.upcase
  end
end
