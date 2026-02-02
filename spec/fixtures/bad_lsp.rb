class BaseLogger
  def log(message)
    puts message
  end
end

class StrictLogger < BaseLogger
  def log(message, level = :info)
    raise ArgumentError, "message too short" if message.length < 5

    super(message)
  end
end
