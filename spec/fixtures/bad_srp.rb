class GodClass
  def initialize
    @users = []
    @orders = []
    @log = []
  end

  def add_user(user)
    @users << user
  end

  def find_user(name)
    @users.find { |u| u.name == name }
  end

  def create_order(order)
    @orders << order
  end

  def total_orders
    @orders.sum(&:total)
  end

  def log_message(msg)
    @log << msg
  end

  def print_log
    @log.each { |l| puts l }
  end
end
