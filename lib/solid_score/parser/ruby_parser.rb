# frozen_string_literal: true

require "parser/current"

module SolidScore
  module Parser
    # Parses Ruby source files and extracts class/method information.
    #
    # Phase 1 改善:
    # - MethodCallInfo によるレシーバ情報の収集
    # - case/when 分岐数のカウント
    #
    # Phase 2a 改善:
    # - クラスメソッド (def self.xxx) の解析対応
    # - モジュール (module) の解析対応
    # - ネストしたクラス/モジュール対応
    # - Rails DSL認識
    class RubyParser
      # Rails/ActiveSupport DSLメソッド
      # これらはメソッド定義ではなくDSL宣言として扱う
      RAILS_DSL_METHODS = %i[
        has_many has_one belongs_to has_and_belongs_to_many
        validates validate validates_presence_of validates_uniqueness_of
        validates_format_of validates_length_of validates_numericality_of
        validates_inclusion_of validates_exclusion_of validates_associated
        before_action after_action around_action skip_before_action
        before_filter after_filter around_filter
        before_validation after_validation
        before_create after_create before_update after_update
        before_save after_save before_destroy after_destroy
        after_commit after_rollback
        scope enum delegate
        serialize store
        accepts_nested_attributes_for
      ].freeze

      def parse_file(file_path)
        source = File.read(file_path)
        ast = ::Parser::CurrentRuby.parse(source)
        return [] unless ast

        extract_definitions(ast, file_path)
      end

      private

      # Phase 2a: クラスとモジュールの両方を抽出し、ネストにも対応
      def extract_definitions(node, file_path, classes = [], namespace = nil)
        return classes unless node.is_a?(::AST::Node)

        case node.type
        when :class
          class_info = build_class_info(node, file_path, namespace)
          classes << class_info
          # ネストしたクラス/モジュールを探索
          extract_nested_definitions(node.children[2], file_path, classes, class_info.name)
        when :module
          module_info = build_module_info(node, file_path, namespace)
          classes << module_info
          # モジュール内のネストしたクラス/モジュールを探索
          extract_nested_definitions(node.children[1], file_path, classes, module_info.name)
        else
          node.children.each { |child| extract_definitions(child, file_path, classes, namespace) }
        end

        classes
      end

      # ネストしたクラス/モジュールを探索（親のbodyから）
      def extract_nested_definitions(body, file_path, classes, parent_name)
        return unless body.is_a?(::AST::Node)

        nodes = body.type == :begin ? body.children : [body]
        nodes.each do |child|
          next unless child.is_a?(::AST::Node)

          case child.type
          when :class, :module
            extract_definitions(child, file_path, classes, parent_name)
          end
        end
      end

      def build_class_info(node, file_path, namespace = nil)
        raw_name = extract_class_name(node.children[0])
        name = namespace ? "#{namespace}::#{raw_name}" : raw_name
        superclass = node.children[1] ? extract_class_name(node.children[1]) : nil
        body = node.children[2]

        build_definition_info(name, file_path, node, body, superclass: superclass, kind: :class)
      end

      # Phase 2a: モジュール情報を構築
      def build_module_info(node, file_path, namespace = nil)
        raw_name = extract_class_name(node.children[0])
        name = namespace ? "#{namespace}::#{raw_name}" : raw_name
        body = node.children[1]

        build_definition_info(name, file_path, node, body, kind: :module)
      end

      # クラス/モジュール共通の情報構築
      def build_definition_info(name, file_path, node, body, superclass: nil, kind: :class)
        methods = []
        includes = []
        extends = []
        attr_readers = []
        attr_writers = []
        dsl_calls = []
        current_visibility = :public

        if body
          traverse_body(body, methods, includes, extends, attr_readers, attr_writers,
                        dsl_calls, current_visibility)
        end

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
          attr_writers: attr_writers,
          kind: kind,
          dsl_calls: dsl_calls
        )
      end

      def traverse_body(node, methods, includes, extends, attr_readers, attr_writers,
                        dsl_calls, current_visibility)
        return unless node.is_a?(::AST::Node)

        case node.type
        when :begin
          node.children.each do |child|
            current_visibility = traverse_body(child, methods, includes, extends,
                                               attr_readers, attr_writers,
                                               dsl_calls, current_visibility)
          end
        when :def
          methods << build_method_info(node, current_visibility, kind: :instance)
        when :defs
          # Phase 2a: クラスメソッド (def self.xxx)
          # :defs ノード構造: [receiver, name, args, body]
          methods << build_method_info(node, :public, kind: :class)
        when :send
          current_visibility = handle_send_node(node, current_visibility, includes, extends,
                                                attr_readers, attr_writers, dsl_calls)
        when :class, :module
          # ネストしたクラス/モジュールはtraverse_bodyではスキップ
          # extract_nested_definitionsで別途処理する
        end

        current_visibility
      end

      def handle_send_node(node, current_visibility, includes, extends,
                           attr_readers, attr_writers, dsl_calls)
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
          # Phase 2a: Rails DSL認識
          if RAILS_DSL_METHODS.include?(method_name)
            dsl_calls << method_name
          end
          current_visibility
        end
      end

      # :def ノード構造: [name, args, body]
      # :defs ノード構造: [receiver, name, args, body]
      def build_method_info(node, visibility, kind: :instance)
        name, args, body = extract_method_parts(node, kind)

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
          case_when_count: case_when_count,
          kind: kind
        )
      end

      def extract_method_parts(node, kind)
        case kind
        when :class
          [node.children[1], node.children[2], node.children[3]]
        else
          [node.children[0], node.children[1], node.children[2]]
        end
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
      def build_method_call_info(receiver_node, method_name)
        receiver, receiver_type = extract_receiver_info(receiver_node)

        Models::MethodCallInfo.new(
          method_name: method_name,
          receiver: receiver,
          receiver_type: receiver_type
        )
      end

      # Phase 1 改善: レシーバ情報を抽出
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
      def count_case_when_branches(node, count = 0)
        return count unless node.is_a?(::AST::Node)

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
