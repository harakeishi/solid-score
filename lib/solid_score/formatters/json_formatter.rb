# frozen_string_literal: true

require "json"

module SolidScore
  module Formatters
    class JsonFormatter < BaseFormatter
      def format(results)
        data = {
          version: VERSION,
          classes: results.map { |r| format_result(r) },
          summary: build_summary(results)
        }

        JSON.pretty_generate(data)
      end

      private

      def format_result(result)
        {
          class_name: result.class_name,
          file_path: result.file_path,
          srp: result.srp,
          ocp: result.ocp,
          lsp: result.lsp,
          isp: result.isp,
          dip: result.dip,
          total: result.total.round(1),
          confidence: result.confidence.transform_values(&:to_s)
        }
      end

      def build_summary(results)
        return { total_classes: 0, average_score: 0.0 } if results.empty?

        {
          total_classes: results.size,
          average_score: (results.sum(&:total) / results.size).round(1)
        }
      end
    end
  end
end
