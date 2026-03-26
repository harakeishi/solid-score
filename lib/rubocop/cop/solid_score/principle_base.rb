# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Abstract base for per-principle cops.
      # Subclasses must define `principle_key` (e.g. :srp) and `principle_name` (e.g. "SRP").
      class PrincipleBase < Base
        include Helpers

        def on_class(node)
          check_principle(node)
        end

        def on_module(node)
          check_principle(node)
        end

        private

        def check_principle(node)
          score_results_for.each do |result|
            target_node = find_class_node_for(result) || node
            next unless same_node?(target_node, node)

            score = result.send(principle_key)
            threshold = score_threshold
            next unless score < threshold

            add_offense(node, message: format(
              self.class::MSG,
              score, threshold
            ))
          end
        end

        def principle_key
          raise NotImplementedError
        end

        def principle_name
          raise NotImplementedError
        end
      end
    end
  end
end
