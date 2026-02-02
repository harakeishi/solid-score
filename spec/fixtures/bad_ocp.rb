class ShapeCalculator
  def area(shape)
    case shape.type
    when :circle
      Math::PI * shape.radius**2
    when :rectangle
      shape.width * shape.height
    when :triangle
      0.5 * shape.base * shape.height
    end
  end

  def perimeter(shape)
    if shape.is_a?(Circle)
      2 * Math::PI * shape.radius
    elsif shape.is_a?(Rectangle)
      2 * (shape.width + shape.height)
    elsif shape.is_a?(Triangle)
      shape.side_a + shape.side_b + shape.side_c
    end
  end
end
