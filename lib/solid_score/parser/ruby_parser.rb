# frozen_string_literal: true

require "parser/current"

module SolidScore
  module Parser
    # Parses Ruby source files and extracts class/method information.
    #
    # Phase 1 改善:
    # - MethodCallInfo によるレシーバ情報の収集
    # - case/when 分岐数のカウント
    class RubyParser
      def parse_file(file_path)
        source = File.read(file_path)
        ast = ::Parser::CurrentRuby.parse(source)
        return [] unless ast

        extract_classes(ast, file_path)
      end

      private

      def extract_classes(node, file_path, classes = [])
        return classes unless node.is_a?(::AST::Node)

        if node.type == :class
          classes << build_class_info(node, file_path)
        else
          node.children.each { |child| extract_classes(child, file_path, classes) }
        end

        classes
      end

      def build_class_info(node, file_path)
        name = extract_class_name(node.children[0])
        superclass = node.children[1] ? extract_class_name(node.children[1]) : nil
        body = node.children[2]

        methods = []
        includes = []
        extends = []
        attr_readers = []
        attr_writers = []
        current_visibility = :public

        traverse_body(body, methods, includes, extends, attr_readers, attr_writers, current_visibility) if body

        instance_variables = methods.flat_map(&:instance_variables).uniq

        Models::ClassInfo.new(
          name: name,
          file_path: file_path,
          line_start: node.loc.line,
          line_end: node.loc.last_line,
          methods: methods,
          superclass: superclass,
          includes: includes,
          extends: extends,
          instance_variables: instance_variables,
          attr_readers: attr_readers,
          attr_writers: attr_writers
        )
      end

      def traverse_body(node, methods, includes, extends, attr_readers, attr_writers, current_visibility)
        return unless node.is_a?(::AST::Node)

        case node.type
        when :begin
          node.children.each do |child|
            current_visibility = traverse_body(child, methods, includes, extends,
                                               attr_readers, attr_writers, current_visibility)
          end
        when :def
          methods << build_method_info(node, current_visibility)
        when :send
          current_visibility = handle_send_node(node, current_visibility, includes, extends,
                                                attr_readers, attr_writers)
        end

        current_visibility
      end

      def handle_send_node(node, current_visibility, includes, extends, attr_readers, attr_writers)
        method_name = node.children[1]

        case method_name
        when :private, :protected, :public
          method_name
        when :include
          includes << extract_class_name(node.children[2]) if node.children[2]
          current_visibility
        when :extend
          extends << extract_class_name(node.children[2]) if node.children[2]
          current_visibility
        when :attr_reader
          node.children[2..].each { |arg| attr_readers << arg.children[0] if arg.type == :sym }
          current_visibility
        when :attr_accessor
          node.children[2..].each do |arg|
            next unless arg.type == :sym

            attr_readers << arg.children[0]
            attr_writers << arg.children[0]
          end
          current_visibility
        when :attr_writer
          node.children[2..].each { |arg| attr_writers << arg.children[0] if arg.type == :sym }
          current_visibility
        else
          current_visibility
        end
      end

      def build_method_info(node, visibility)
        name = node.children[0]
        args = node.children[1]
        body = node.children[2]

        instance_vars = []
        called_methods = []
        raises = []
        method_calls = []
        calls_super = false
        case_when_count = 0

        if body
          collect_method_details(body, instance_vars, called_methods, raises, method_calls)
          calls_super = contains_super?(body)
          case_when_count = count_case_when_branches(body)
        end

        parameters = extract_parameters(args)
        complexity = calculate_cyclomatic_complexity(body)

        Models::MethodInfo.new(
          name: name,
          visibility: visibility,
          line_start: node.loc.line,
          line_end: node.loc.last_line,
          instance_variables: instance_vars.uniq,
          called_methods: called_methods.uniq,
          parameters: parameters,
          cyclomatic_complexity: complexity,
          raises: raises,
          calls_super: calls_super,
          method_calls: method_calls,
          case_when_count: case_when_count
        )
      end

      # Phase 1 改善: レシーバ情報を含むメソッド呼び出し情報を収集
      def collect_method_details(node, instance_vars, called_methods, raises, method_calls)
        return unless node.is_a?(::AST::Node)

        case node.type
        when :ivar, :ivasgn
          instance_vars << node.children[0]
        when :send
          receiver_node = node.children[0]
          method_name = node.children[1]

          called_methods << method_name

          # Collect detailed method call info with receiver
          method_calls << build_method_call_info(receiver_node, method_name)

          if %i[raise fail].include?(method_name)
            raise_class = node.children[2]
            raises << extract_class_name(raise_class) if raise_class.is_a?(::AST::Node) && raise_class.type == :const
          end
        end

        node.children.each do |child|
          collect_method_details(child, instance_vars, called_methods, raises, method_calls)
        end
      end

      # Phase 1 改善: メソッド呼び出し情報を構築
      #
      # @param receiver_node [AST::Node, nil] レシーバのASTノード
      # @param method_name [Symbol] メソッド名
      # @return [MethodCallInfo] メソッド呼び出し情報
      def build_method_call_info(receiver_node, method_name)
        receiver, receiver_type = extract_receiver_info(receiver_node)

        Models::MethodCallInfo.new(
          method_name: method_name,
          receiver: receiver,
          receiver_type: receiver_type
        )
      end

      # Phase 1 改善: レシーバ情報を抽出
      #
      # @param node [AST::Node, nil] レシーバのASTノード
      # @return [Array<String, Symbol>] [レシーバ名, レシーバ種類]
      def extract_receiver_info(node)
        return [nil, :self] if node.nil?
        return [nil, :unknown] unless node.is_a?(::AST::Node)

        case node.type
        when :const
          [extract_class_name(node), :const]
        when :ivar
          [node.children[0].to_s, :ivar]
        when :lvar
          [node.children[0].to_s, :lvar]
        when :self
          [nil, :self]
        when :send
          # Chained method call (e.g., foo.bar.baz)
          [nil, :send]
        else
          [nil, :unknown]
        end
      end

      # Phase 1 改善: case/when 分岐数をカウント
      #
      # case文内のwhen節の数をカウントします。
      # OCP違反の兆候として特に重要な指標です。
      #
      # @param node [AST::Node] ASTノード
      # @param count [Integer] 現在のカウント
      # @return [Integer] case/when分岐の総数
      def count_case_when_branches(node, count = 0)
        return count unless node.is_a?(::AST::Node)

        # :case ノードの子要素から :when ノードの数をカウント
        if node.type == :case
          when_count = node.children.count { |child| child.is_a?(::AST::Node) && child.type == :when }
          count += when_count
        end

        node.children.each do |child|
          count = count_case_when_branches(child, count)
        end

        count
      end

      def contains_super?(node)
        return false unless node.is_a?(::AST::Node)
        return true if %i[super zsuper].include?(node.type)

        node.children.any? { |child| contains_super?(child) }
      end

      def extract_parameters(args_node)
        return [] unless args_node

        args_node.children.map do |arg|
          [arg.type, arg.children[0]]
        end
      end

      def calculate_cyclomatic_complexity(node, complexity = 1)
        return complexity unless node.is_a?(::AST::Node)

        case node.type
        when :if, :while, :until, :for, :when, :and, :or, :rescue
          complexity += 1
        end

        node.children.each do |child|
          complexity = calculate_cyclomatic_complexity(child, complexity)
        end

        complexity
      end

      def extract_class_name(node)
        return nil unless node.is_a?(::AST::Node)

        case node.type
        when :const
          parent = node.children[0]
          name = node.children[1].to_s
          parent ? "#{extract_class_name(parent)}::#{name}" : name
        else
          node.to_s
        end
      end
    end
  end
end
