# frozen_string_literal: true

# Template Method pattern - parent raises NotImplementedError
class BaseProcessor
  def process(data)
    raise NotImplementedError
  end
end

# Simple override - should NOT be penalized
class SimpleProcessor < BaseProcessor
  def process(data)
    data.to_s
  end
end

# Abstract parent pattern - parent name contains "Base"
class BaseHandler
  def handle(request)
    # default implementation
  end
end

# Simple implementation without super - should NOT be penalized
class JsonHandler < BaseHandler
  def handle(request)
    JSON.parse(request)
  end
end

# Complex override without super - should be penalized (reduced)
class ComplexProcessor < BaseProcessor
  def process(data)
    if data.nil?
      raise ArgumentError, "data cannot be nil"
    elsif data.empty?
      return []
    else
      result = data.map { |item| transform(item) }
      result.compact
    end
  end

  private

  def transform(item)
    item.to_s.upcase
  end
end

# Child-specific method - should NOT be penalized heavily
class Animal
  def speak
    "..."
  end
end

class Dog < Animal
  def speak
    "Woof!"
  end

  # This method doesn't exist in parent, but currently analyzed as override
  def fetch
    "fetching..."
  end
end
