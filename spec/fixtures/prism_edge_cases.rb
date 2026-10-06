# frozen_string_literal: true

class PrismEdgeCases < ::Base::Thing
  def forwarding(...)
    other(...)
  end

  def destructure((first, second), *)
    [first, second]
  end

  def safe_navigation(user)
    user&.name
  end

  def attribute_assignment
    self.cache ||= build
  end

  def failing
    raise ::Errors::Bad, "message"
  end
end

class FromStruct < Struct.new(:a, :b)
end
