# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum OCP (Open/Closed Principle) score.
      #
      # @example MinScore: 50 (default)
      #   SolidScore/OpenClosed:
      #     Enabled: true
      #     MinScore: 50
      class OpenClosed < PrincipleBase
        MSG = "OCP score %.1f is below minimum %g"

        private

        def principle_key = :ocp
        def principle_name = "OCP"
      end
    end
  end
end
