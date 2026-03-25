class Payments
  class Processor
    def initialize(gateway:)
      @gateway = gateway
    end

    def charge(amount)
      @gateway.charge(amount)
    end
  end

  class Refund
    def initialize(transaction_id:)
      @transaction_id = transaction_id
    end

    def process
      # refund logic
      @transaction_id
    end
  end
end
