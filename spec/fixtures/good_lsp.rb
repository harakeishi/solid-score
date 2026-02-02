class BaseProcessor
  def process(data)
    raise NotImplementedError
  end
end

class CsvProcessor < BaseProcessor
  def process(data)
    super
  rescue NotImplementedError
    data.split(",")
  end
end
