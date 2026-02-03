# frozen_string_literal: true

# Uses standard library classes - should NOT be penalized
class DataProcessor
  def process(data)
    result = Array.new
    hash = Hash.new(0)
    time = Time.new
    mutex = Mutex.new

    data.each do |item|
      mutex.synchronize do
        hash[item] += 1
        result << item.to_s
      end
    end

    result
  end
end

# Uses custom classes - SHOULD be penalized
class OrderProcessor
  def process(order)
    repo = OrderRepository.new
    notifier = EmailNotifier.new
    logger = AuditLogger.new

    saved = repo.save(order)
    notifier.notify(saved)
    logger.log(saved)
  end
end

# Mixed: uses both standard and custom classes with DI
class MixedProcessor
  def initialize(service:)
    @service = service
  end

  def process(data)
    # Standard library - not penalized
    cache = Hash.new
    timestamp = Time.new

    # Custom class via DI - not directly instantiated
    # Plus one local instantiation for comparison
    helper = ProcessingHelper.new

    @service.execute(data, cache: cache, timestamp: timestamp, helper: helper)
  end
end
