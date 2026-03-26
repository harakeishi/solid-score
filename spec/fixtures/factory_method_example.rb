class OrderProcessor
  def process(order_data)
    order = Order.create(order_data)
    receipt = Receipt.build(order)
    NotificationService.call(order)
    report = File.open("report.txt", "w")
    report.close
    order
  end
end
