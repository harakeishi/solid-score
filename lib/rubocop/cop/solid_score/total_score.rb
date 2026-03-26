# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum SOLID total score.
      #
      # @example EnforcedMinScore: 70 (default)
      #   # bad - total score below threshold
      #   class GodObject
      #     # ... many responsibilities, concrete deps, etc.
      #   end
      #
      #   # good - total score above threshold
      #   class FocusedService
      #     # ... single responsibility, injected deps
      #   end
      #
      # @example Configuration in .rubocop.yml
      #   SolidScore/TotalScore:
      #     Enabled: true
      #     MinScore: 70
      class TotalScore < Base
        include Helpers

        MSG = "SOLID total score %.1f is below minimum %g (SRP=%.1f OCP=%.1f LSP=%.1f ISP=%.1f DIP=%.1f)"

        def on_class(node)
          check_scores(node)
        end

        def on_module(node)
          check_scores(node)
        end

        private

        def check_scores(node)
          results = score_results_for(node)
          results.each do |result|
            target_node = find_class_node_for(result) || node
            next unless same_node?(target_node, node)
            next unless result.total < score_threshold

            add_offense(node, message: format(
              MSG,
              result.total, score_threshold,
              result.srp, result.ocp, result.lsp, result.isp, result.dip
            ))
          end
        end

        def same_node?(target, current)
          target.loc.keyword.line == current.loc.keyword.line
        end
      end
    end
  end
end
