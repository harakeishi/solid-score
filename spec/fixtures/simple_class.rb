class Calculator
  def initialize(tax_rate)
    @tax_rate = tax_rate
  end

  def calculate(amount)
    amount + tax_amount(amount)
  end

  private

  def tax_amount(amount)
    amount * @tax_rate
  end
end
