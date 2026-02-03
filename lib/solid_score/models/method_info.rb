# frozen_string_literal: true

module SolidScore
  module Models
    # Represents information about a single method call.
    # Phase 1 改善: レシーバ情報を収集するために追加
    class MethodCallInfo
      attr_reader :method_name, :receiver, :receiver_type

      # @param method_name [Symbol] メソッド名
      # @param receiver [String, nil] レシーバの名前（定数名、変数名など）
      # @param receiver_type [Symbol] レシーバの種類 (:const, :ivar, :lvar, :self, :unknown)
      def initialize(method_name:, receiver: nil, receiver_type: :unknown)
        @method_name = method_name
        @receiver = receiver
        @receiver_type = receiver_type
      end

      # Check if this is a .new call on a constant (class instantiation)
      def new_call_on_const?
        method_name == :new && receiver_type == :const
      end
    end

    class MethodInfo
      attr_reader :name, :visibility, :line_start, :line_end,
                  :instance_variables, :called_methods, :parameters,
                  :cyclomatic_complexity, :raises, :calls_super,
                  :method_calls, :case_when_count

      def initialize(name:, visibility: :public, line_start: 0, line_end: 0,
                     instance_variables: [], called_methods: [], parameters: [],
                     cyclomatic_complexity: 1, raises: [], calls_super: false,
                     method_calls: [], case_when_count: 0)
        @name = name
        @visibility = visibility
        @line_start = line_start
        @line_end = line_end
        @instance_variables = instance_variables
        @called_methods = called_methods
        @parameters = parameters
        @cyclomatic_complexity = cyclomatic_complexity
        @raises = raises
        @calls_super = calls_super
        @method_calls = method_calls
        @case_when_count = case_when_count
      end

      def public?
        visibility == :public
      end

      def empty?
        line_start == line_end
      end
    end
  end
end
