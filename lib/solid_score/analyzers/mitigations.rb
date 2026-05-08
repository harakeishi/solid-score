# frozen_string_literal: true

module SolidScore
  module Analyzers
    # Shared score-mitigation helpers used by multiple analyzers.
    module Mitigations
      INSPECTION_MIN_SCORE = 80

      private

      # Issue #9: floor inspection / diagnostic helpers at INSPECTION_MIN_SCORE.
      def mitigate_inspection(score, class_info)
        return score unless class_info.inspection_class?

        [score, INSPECTION_MIN_SCORE].max
      end
    end
  end
end
