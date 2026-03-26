class ResponseHandler
  def handle(response)
    if response.respond_to?(:to_json)
      process_json(response.to_json)
    elsif response.respond_to?(:to_xml)
      process_xml(response.to_xml)
    elsif response.respond_to?(:to_csv)
      process_csv(response.to_csv)
    else
      process_raw(response.to_s)
    end
  end

  private

  def process_json(data)
    data
  end

  def process_xml(data)
    data
  end

  def process_csv(data)
    data
  end

  def process_raw(data)
    data
  end
end
