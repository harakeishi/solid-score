class OrderService
  def create(params)
    order = OrderRepository.new.save(params)
    EmailNotifier.new.notify(order)
    SlackNotifier.new.post(order)
    AuditLogger.new.log(order)
    InventoryManager.new.reserve(order)
    PaymentGateway.new.charge(order)
    order
  end
end
