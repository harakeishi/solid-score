# frozen_string_literal: true

# OCP violation: case/when pattern that requires modification for new types
class TypeHandler
  def process(item)
    case item.type
    when :text
      process_text(item)
    when :image
      process_image(item)
    when :video
      process_video(item)
    end
  end

  private

  def process_text(item)
    item.content
  end

  def process_image(item)
    resize(item)
  end

  def process_video(item)
    transcode(item)
  end
end

# Better OCP compliance: polymorphism
class ItemProcessor
  def initialize(strategy:)
    @strategy = strategy
  end

  def process(item)
    @strategy.process(item)
  end
end

# No case/when - good OCP
class SimpleProcessor
  def process(item)
    item.to_s
  end
end
