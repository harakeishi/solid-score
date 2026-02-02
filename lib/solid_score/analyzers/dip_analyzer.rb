# frozen_string_literal: true

require "set"

module SolidScore
  module Analyzers
    class DipAnalyzer < BaseAnalyzer
      DI_BONUS = 15

      def analyze(class_info)
        concrete_deps = count_concrete_instantiations(class_info)
        injected_deps = count_injected_dependencies(class_info)
        total_deps = concrete_deps + injected_deps

        return 100 if total_deps.zero?

        concrete_ratio = concrete_deps.to_f / total_deps
        score = 100 - (concrete_ratio * 100)

        score += DI_BONUS if injected_deps.positive?
        score -= ce_penalty(class_info)

        clamp_score(score)
      end

      private

      def count_concrete_instantiations(class_info)
        class_info.methods.sum do |method|
          method.called_methods.count { |m| m == :new }
        end
      end

      def count_injected_dependencies(class_info)
        init = class_info.methods.find { |m| m.name == :initialize }
        return 0 unless init

        init.parameters.count { |type, _| %i[key keyreq].include?(type) }
      end

      def ce_penalty(class_info)
        ce = count_concrete_instantiations(class_info)

        if ce > 20
          20
        elsif ce > 10
          10
        else
          0
        end
      end
    end
  end
end
