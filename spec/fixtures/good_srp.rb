class TaxCalculator
  def initialize(rate)
    @rate = rate
  end

  def calculate(amount)
    amount * @rate
  end

  def calculate_with_discount(amount, discount)
    discounted = apply_discount(amount, discount)
    calculate(discounted)
  end

  private

  def apply_discount(amount, discount)
    amount * (1 - discount)
  end
end
