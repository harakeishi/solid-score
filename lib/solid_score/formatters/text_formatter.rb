# frozen_string_literal: true

module SolidScore
  module Formatters
    class TextFormatter < BaseFormatter
      def format(results)
        return "No classes found to analyze.\n" if results.empty?

        lines = []
        lines << "solid-score v#{VERSION}\n"
        lines << "Analyzed #{results.size} class(es)\n\n"
        lines << header_line
        lines << separator_line

        results.each { |r| lines << result_line(r) }

        lines << separator_line
        lines << average_line(results)
        lines << ""

        lines.join("\n")
      end

      private

      def header_line
        "Class                                      SRP   OCP   LSP   ISP   DIP   Total"
      end

      def separator_line
        "-" * 75
      end

      def result_line(result)
        Kernel.format("%-40s %5.1f %5.1f %5.1f %5.1f %5.1f %7.1f",
                      truncate(result.class_name, 40),
                      result.srp, result.ocp, result.lsp, result.isp, result.dip, result.total)
      end

      def average_line(results)
        avg = ->(method) { results.sum(&method) / results.size.to_f }

        Kernel.format("%-40s %5.1f %5.1f %5.1f %5.1f %5.1f %7.1f",
                      "Average",
                      avg.call(:srp), avg.call(:ocp), avg.call(:lsp),
                      avg.call(:isp), avg.call(:dip), avg.call(:total))
      end

      def truncate(str, max)
        str.length > max ? "#{str[0..(max - 4)]}..." : str
      end
    end
  end
end
