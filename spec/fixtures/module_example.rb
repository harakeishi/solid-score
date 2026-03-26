module Serializable
  def to_json
    serialize(:json)
  end

  def to_xml
    serialize(:xml)
  end

  private

  def serialize(format)
    case format
    when :json then "{}"
    when :xml then "<root/>"
    end
  end
end
