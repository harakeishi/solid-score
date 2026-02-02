# frozen_string_literal: true

module SolidScore
  module Analyzers
    class BaseAnalyzer
      def analyze(class_info)
        raise NotImplementedError, "#{self.class}#analyze must be implemented"
      end

      private

      def clamp_score(score)
        [[score, 0].max, 100].min.round(1)
      end
    end
  end
end
