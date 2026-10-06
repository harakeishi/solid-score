# frozen_string_literal: true

require "prism"

module SolidScore
  module Parser
    # Builds a Models::ClassInfo from a single Prism ClassNode/ModuleNode by
    # scanning its direct body statements: method definitions, visibility
    # modifiers, mixins, attr_* declarations and Rails DSL calls.
    class ClassBodyScanner
      # Rails/ActiveSupport DSL methods treated as declarations rather than
      # ordinary method calls.
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

      VISIBILITY_MODIFIERS = %i[private protected public].freeze

      # Direct statements of a class/module body. The body is a
      # StatementsNode normally, but a BeginNode when the class itself has
      # a rescue/ensure clause, in which case the statements sit inside it.
      def self.body_statements(node)
        body = node.body
        body = body.statements if body.is_a?(::Prism::BeginNode)
        body&.body || []
      end

      def initialize(node, file_path, namespace)
        @node = node
        @file_path = file_path
        @namespace = namespace
        @methods = []
        @includes = []
        @extends = []
        @attr_readers = []
        @attr_writers = []
        @dsl_calls = []
        @visibility = :public
      end

      def class_info
        statements.each { |statement| scan(statement) }

        Models::ClassInfo.new(
          name: qualified_name,
          file_path: @file_path,
          line_start: @node.location.start_line,
          line_end: @node.location.end_line,
          methods: @methods,
          superclass: superclass_name,
          includes: @includes,
          extends: @extends,
          instance_variables: @methods.flat_map(&:instance_variables).uniq,
          attr_readers: @attr_readers,
          attr_writers: @attr_writers,
          kind: @node.is_a?(::Prism::ModuleNode) ? :module : :class,
          dsl_calls: @dsl_calls
        )
      end

      private

      def statements
        self.class.body_statements(@node)
      end

      def qualified_name
        raw = ConstantName.of(@node.constant_path)
        @namespace ? "#{@namespace}::#{raw}" : raw
      end

      def superclass_name
        return nil unless @node.is_a?(::Prism::ClassNode)

        ConstantName.of(@node.superclass)
      end

      def scan(statement)
        case statement
        when ::Prism::DefNode then scan_def(statement)
        when ::Prism::CallNode then scan_call(statement)
        end
      end

      def scan_def(node)
        @methods << if node.receiver
                      MethodAnalyzer.new(node, visibility: :public, kind: :class).method_info
                    else
                      MethodAnalyzer.new(node, visibility: @visibility, kind: :instance).method_info
                    end
      end

      def scan_call(node)
        name = node.name
        args = node.arguments&.arguments || []

        case name
        when *VISIBILITY_MODIFIERS then @visibility = name
        when :include then @includes << ConstantName.of(args.first) if args.first
        when :extend then @extends << ConstantName.of(args.first) if args.first
        when :attr_reader then @attr_readers.concat(symbol_args(args))
        when :attr_writer then @attr_writers.concat(symbol_args(args))
        when :attr_accessor
          names = symbol_args(args)
          @attr_readers.concat(names)
          @attr_writers.concat(names)
        else
          @dsl_calls << name if RAILS_DSL_METHODS.include?(name)
        end
      end

      def symbol_args(args)
        args.grep(::Prism::SymbolNode).map { |arg| arg.unescaped.to_sym }
      end
    end
  end
end
