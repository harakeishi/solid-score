# frozen_string_literal: true

require "prism"

module SolidScore
  module Parser
    # Raised when a source file cannot be parsed. Prism itself never raises
    # on syntax errors (it returns a partial tree plus diagnostics), so the
    # first error is surfaced here for callers that want to skip the file.
    class SyntaxError < StandardError; end

    # Parses Ruby source with Prism's native node API and extracts
    # class/module definitions as Models::ClassInfo.
    class RubyParser
      def parse_file(file_path)
        result = ::Prism.parse_file(file_path)
        raise SyntaxError, format_error(file_path, result.errors.first) if result.failure?

        collector = DefinitionCollector.new(file_path)
        result.value.accept(collector)
        collector.classes
      end

      private

      def format_error(file_path, error)
        "#{file_path}:#{error.location.start_line}:#{error.location.start_column}: #{error.message}"
      end
    end
  end
end
