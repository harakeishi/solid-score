# frozen_string_literal: true

require "prism"

module SolidScore
  module Parser
    # Walks a Prism syntax tree and collects every class/module definition
    # as Models::ClassInfo, qualifying nested names with their namespace.
    #
    # Top-level definitions are found anywhere in the tree (e.g. inside an
    # `if defined?(...)` guard). Inside a class/module body only direct
    # child definitions are collected, matching the previous parser.
    class DefinitionCollector < ::Prism::Visitor
      attr_reader :classes

      def initialize(file_path)
        super()
        @file_path = file_path
        @namespace = nil
        @classes = []
      end

      def visit_class_node(node)
        collect_definition(node)
      end

      def visit_module_node(node)
        collect_definition(node)
      end

      private

      def collect_definition(node)
        info = ClassBodyScanner.new(node, @file_path, @namespace).class_info
        @classes << info
        collect_nested(node, info.name)
      end

      def collect_nested(node, namespace)
        with_namespace(namespace) do
          ClassBodyScanner.body_statements(node)
                          .select { |child| child.is_a?(::Prism::ClassNode) || child.is_a?(::Prism::ModuleNode) }
                          .each { |child| visit(child) }
        end
      end

      def with_namespace(namespace)
        previous = @namespace
        @namespace = namespace
        yield
      ensure
        @namespace = previous
      end
    end
  end
end
