# frozen_string_literal: true

require "prism"

module SolidScore
  module Parser
    # Renders a Prism constant node as its qualified name ("Foo::Bar").
    # Non-constant expressions (e.g. `Struct.new(:a)` as a superclass)
    # fall back to their source text so callers still get a stable string.
    module ConstantName
      module_function

      def of(node)
        case node
        when nil then nil
        when ::Prism::ConstantReadNode then node.name.to_s
        when ::Prism::ConstantPathNode then "#{of(node.parent)}::#{node.name}"
        else node.slice
        end
      end
    end
  end
end
