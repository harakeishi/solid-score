# frozen_string_literal: true

module SolidScore
  module Models
    class ClassInfo
      attr_reader :name, :file_path, :line_start, :line_end,
                  :methods, :superclass, :includes, :extends,
                  :instance_variables, :attr_readers, :attr_writers

      def initialize(name:, file_path: "", line_start: 0, line_end: 0,
                     methods: [], superclass: nil, includes: [], extends: [],
                     instance_variables: [], attr_readers: [], attr_writers: [])
        @name = name
        @file_path = file_path
        @line_start = line_start
        @line_end = line_end
        @methods = methods
        @superclass = superclass
        @includes = includes
        @extends = extends
        @instance_variables = instance_variables
        @attr_readers = attr_readers
        @attr_writers = attr_writers
      end

      def public_methods_list
        methods.select { |m| m.public? && m.name != :initialize }
      end

      def line_count
        line_end - line_start + 1
      end

      def has_superclass?
        !superclass.nil? && !superclass.empty?
      end

      def data_class?
        all_attrs = attr_readers + attr_writers
        return false if all_attrs.empty?

        non_init_methods = methods.reject { |m| m.name == :initialize }
        non_init_methods.all? { |m| all_attrs.include?(m.name) }
      end
    end
  end
end
