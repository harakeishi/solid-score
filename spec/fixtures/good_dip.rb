class OrderService
  def initialize(repository:, notifier:)
    @repository = repository
    @notifier = notifier
  end

  def create(params)
    order = @repository.save(params)
    @notifier.notify(order)
    order
  end
end
