# frozen_string_literal: true

module SolidScore
  module Models
    class MethodInfo
      attr_reader :name, :visibility, :line_start, :line_end,
                  :instance_variables, :called_methods, :parameters,
                  :cyclomatic_complexity, :raises, :calls_super

      def initialize(name:, visibility: :public, line_start: 0, line_end: 0,
                     instance_variables: [], called_methods: [], parameters: [],
                     cyclomatic_complexity: 1, raises: [], calls_super: false)
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
