# frozen_string_literal: true

module SolidScore
  module Analyzers
    class LspAnalyzer < BaseAnalyzer
      SIGNATURE_CHANGE_PENALTY = 20
      EXTRA_RAISE_PENALTY = 15
      NO_SUPER_PENALTY = 10

      def analyze(class_info)
        return 100 unless class_info.has_superclass?

        score = 100.0

        class_info.methods.each do |method|
          next if method.name == :initialize

          score -= extra_raise_penalty(method)
          score -= no_super_penalty(method)
        end

        clamp_score(score)
      end

      private

      def extra_raise_penalty(method)
        standard_raises = ["NotImplementedError"]
        extra_raises = method.raises.reject { |r| standard_raises.include?(r) }

        extra_raises.any? ? EXTRA_RAISE_PENALTY : 0
      end

      def no_super_penalty(method)
        return 0 if method.calls_super

        NO_SUPER_PENALTY
      end
    end
  end
end
