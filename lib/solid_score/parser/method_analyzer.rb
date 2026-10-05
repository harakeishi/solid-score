# frozen_string_literal: true

require "prism"

module SolidScore
  module Parser
    # Builds a Models::MethodInfo from a Prism DefNode by walking the method
    # body once and collecting every metric the analyzers need.
    class MethodAnalyzer
      # Factory-style method names that count as instantiation for the
      # `@ivar ||= Const.new` memoisation pattern (Issue #12).
      # Mirrors DipAnalyzer::FACTORY_METHODS.
      FACTORY_METHODS = %i[new create build call open].freeze

      # Instance variable nodes: reads, every assignment form, and
      # multiple-assignment targets (`@a, @b = ...`).
      INSTANCE_VARIABLE_NODES = [
        ::Prism::InstanceVariableReadNode,
        ::Prism::InstanceVariableWriteNode,
        ::Prism::InstanceVariableOrWriteNode,
        ::Prism::InstanceVariableAndWriteNode,
        ::Prism::InstanceVariableOperatorWriteNode,
        ::Prism::InstanceVariableTargetNode
      ].freeze

      # Statement-like nodes that count toward the effective body size
      # (Issue #10). Calls, conditionals, assignments, loops, jumps and
      # blocks each count once; `||=`-style operator assignments count as
      # both the assignment and the operator (see OPERATOR_ASSIGNMENT_NODES).
      #
      # Deliberately not counted: `case/in` pattern matching, `begin`,
      # `rescue`/`ensure` wrappers, `when` clauses (the enclosing `case`
      # already counts) and variable reads.
      EFFECTIVE_STATEMENT_NODES = [
        ::Prism::CallNode,
        ::Prism::IfNode, ::Prism::UnlessNode, ::Prism::CaseNode, ::Prism::ReturnNode,
        ::Prism::InstanceVariableWriteNode, ::Prism::LocalVariableWriteNode,
        ::Prism::GlobalVariableWriteNode, ::Prism::ClassVariableWriteNode,
        ::Prism::MultiWriteNode,
        ::Prism::InstanceVariableTargetNode, ::Prism::LocalVariableTargetNode,
        ::Prism::GlobalVariableTargetNode, ::Prism::ClassVariableTargetNode,
        ::Prism::CallTargetNode, ::Prism::IndexTargetNode,
        ::Prism::ConstantOrWriteNode, ::Prism::ConstantAndWriteNode, ::Prism::ConstantOperatorWriteNode,
        ::Prism::ConstantPathOrWriteNode, ::Prism::ConstantPathAndWriteNode, ::Prism::ConstantPathOperatorWriteNode,
        ::Prism::YieldNode, ::Prism::BlockNode, ::Prism::LambdaNode,
        ::Prism::WhileNode, ::Prism::UntilNode, ::Prism::ForNode,
        ::Prism::NextNode, ::Prism::BreakNode, ::Prism::RetryNode, ::Prism::RedoNode,
        ::Prism::SuperNode, ::Prism::ForwardingSuperNode
      ].freeze

      # `x ||= v`, `x &&= v`, `x += v` on variables and attributes. Counted
      # twice so the effective statement count matches the previous parser,
      # which saw these as an assignment node wrapping an operator node.
      # The attribute and index forms also read the target (`self.a ||= v`
      # calls `a`), so they are recorded as method calls too.
      OPERATOR_ASSIGNMENT_NODES = [
        ::Prism::LocalVariableOrWriteNode, ::Prism::LocalVariableAndWriteNode,
        ::Prism::LocalVariableOperatorWriteNode,
        ::Prism::InstanceVariableOrWriteNode, ::Prism::InstanceVariableAndWriteNode,
        ::Prism::InstanceVariableOperatorWriteNode,
        ::Prism::GlobalVariableOrWriteNode, ::Prism::GlobalVariableAndWriteNode,
        ::Prism::GlobalVariableOperatorWriteNode,
        ::Prism::ClassVariableOrWriteNode, ::Prism::ClassVariableAndWriteNode,
        ::Prism::ClassVariableOperatorWriteNode,
        ::Prism::CallOrWriteNode, ::Prism::CallAndWriteNode, ::Prism::CallOperatorWriteNode,
        ::Prism::IndexOrWriteNode, ::Prism::IndexAndWriteNode, ::Prism::IndexOperatorWriteNode
      ].freeze

      ATTRIBUTE_ASSIGNMENT_NODES = [
        ::Prism::CallOrWriteNode, ::Prism::CallAndWriteNode, ::Prism::CallOperatorWriteNode
      ].freeze

      INDEX_ASSIGNMENT_NODES = [
        ::Prism::IndexOrWriteNode, ::Prism::IndexAndWriteNode, ::Prism::IndexOperatorWriteNode
      ].freeze

      # Branching nodes that add one to cyclomatic complexity. Rescue is
      # handled separately in visit_begin_node so that a multi-clause rescue
      # counts once, as the previous parser did.
      BRANCH_NODES = [
        ::Prism::IfNode, ::Prism::UnlessNode, ::Prism::WhileNode, ::Prism::UntilNode,
        ::Prism::ForNode, ::Prism::WhenNode, ::Prism::AndNode, ::Prism::OrNode,
        ::Prism::RescueModifierNode
      ].freeze

      def initialize(node, visibility:, kind:)
        @node = node
        @visibility = visibility
        @kind = kind
        @instance_variables = []
        @called_methods = []
        @method_calls = []
        @raises = []
        @calls_super = false
        @case_when_count = 0
        @cyclomatic_complexity = 1
        @effective_statement_count = 0
        @memoized_factory_receiver = nil
        @nested_definition_depth = 0
      end

      def method_info
        walk(@node.body)

        Models::MethodInfo.new(
          name: @node.name,
          visibility: @visibility,
          line_start: @node.location.start_line,
          line_end: @node.location.end_line,
          instance_variables: @instance_variables.uniq,
          called_methods: @called_methods.uniq,
          parameters: parameters,
          cyclomatic_complexity: @cyclomatic_complexity,
          raises: @raises,
          calls_super: @calls_super,
          method_calls: @method_calls,
          case_when_count: @case_when_count,
          kind: @kind,
          effective_statement_count: @effective_statement_count,
          memoized_factory_receiver: @memoized_factory_receiver
        )
      end

      private

      # Pre-order walk. Generic bookkeeping first, then node-specific hooks,
      # then recurse into children. A plain recursion is used instead of
      # Prism::Visitor because every visit_* there iterates children itself,
      # leaving no single place to hook all nodes.
      def walk(node)
        return unless node

        record_instance_variable(node)
        record_effective_statement(node)
        @cyclomatic_complexity += 1 if BRANCH_NODES.any? { |type| node.is_a?(type) }
        inspect_node(node)

        nested = node.is_a?(::Prism::DefNode)
        @nested_definition_depth += 1 if nested
        node.compact_child_nodes.each { |child| walk(child) }
        @nested_definition_depth -= 1 if nested
      end

      def inspect_node(node)
        case node
        when ::Prism::CallNode then inspect_call(node)
        when *ATTRIBUTE_ASSIGNMENT_NODES then record_call(node.read_name, node.receiver)
        when *INDEX_ASSIGNMENT_NODES then record_call(:[], node.receiver)
        when ::Prism::CallTargetNode then record_call(node.name, node.receiver)
        when ::Prism::IndexTargetNode then record_call(:[]=, node.receiver)
        when ::Prism::InstanceVariableOrWriteNode
          @memoized_factory_receiver ||= memoized_factory_receiver_for(node)
        when ::Prism::SuperNode, ::Prism::ForwardingSuperNode then @calls_super = true
        when ::Prism::CaseNode
          @case_when_count += node.conditions.count { |condition| condition.is_a?(::Prism::WhenNode) }
        when ::Prism::BeginNode then @cyclomatic_complexity += 1 if node.rescue_clause
        end
      end

      def inspect_call(node)
        record_call(node.name, node.receiver)
        record_raise(node)
      end

      def record_call(name, receiver_node)
        receiver, receiver_type = receiver_info(receiver_node)
        @called_methods << name
        @method_calls << Models::MethodCallInfo.new(method_name: name, receiver: receiver, receiver_type: receiver_type)
      end

      def record_instance_variable(node)
        @instance_variables << node.name if INSTANCE_VARIABLE_NODES.any? { |type| node.is_a?(type) }
      end

      def record_effective_statement(node)
        return if @nested_definition_depth.positive?

        @effective_statement_count += 1 if EFFECTIVE_STATEMENT_NODES.any? { |type| node.is_a?(type) }
        @effective_statement_count += 2 if OPERATOR_ASSIGNMENT_NODES.any? { |type| node.is_a?(type) }
      end

      def record_raise(node)
        return unless %i[raise fail].include?(node.name)

        raised = node.arguments&.arguments&.first
        return unless raised.is_a?(::Prism::ConstantReadNode) || raised.is_a?(::Prism::ConstantPathNode)

        @raises << ConstantName.of(raised)
      end

      def receiver_info(node)
        case node
        when nil, ::Prism::SelfNode then [nil, :self]
        when ::Prism::ConstantReadNode, ::Prism::ConstantPathNode then [ConstantName.of(node), :const]
        when ::Prism::InstanceVariableReadNode then [node.name.to_s, :ivar]
        when ::Prism::LocalVariableReadNode then [node.name.to_s, :lvar]
        when ::Prism::CallNode then [nil, :send]
        else [nil, :unknown]
        end
      end

      def memoized_factory_receiver_for(node)
        call = node.value
        return nil unless call.is_a?(::Prism::CallNode) && FACTORY_METHODS.include?(call.name)

        receiver = call.receiver
        return nil unless receiver.is_a?(::Prism::ConstantReadNode) || receiver.is_a?(::Prism::ConstantPathNode)

        ConstantName.of(receiver)
      end

      def parameters
        params = @node.parameters
        return [] unless params

        [
          *params.requireds.map { |p| positional(p) },
          *params.optionals.map { |p| [:optarg, p.name] },
          *Array(params.rest).map { |p| rest(p) },
          *params.posts.map { |p| positional(p) },
          *params.keywords.map { |p| keyword(p) },
          *Array(params.keyword_rest).map { |p| keyword_rest(p) },
          *Array(params.block).map { |p| [:blockarg, p.name] }
        ]
      end

      def positional(node)
        node.is_a?(::Prism::MultiTargetNode) ? [:mlhs, nil] : [:arg, node.name]
      end

      def rest(node)
        node.is_a?(::Prism::ImplicitRestNode) ? [:restarg, nil] : [:restarg, node.name]
      end

      def keyword(node)
        node.is_a?(::Prism::RequiredKeywordParameterNode) ? [:kwarg, node.name] : [:kwoptarg, node.name]
      end

      def keyword_rest(node)
        case node
        when ::Prism::ForwardingParameterNode then [:forward_arg, nil]
        when ::Prism::NoKeywordsParameterNode then [:kwnilarg, nil]
        else [:kwrestarg, node.name]
        end
      end
    end
  end
end
