# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum SRP (Single Responsibility Principle) score.
      #
      # @example MinScore: 60 (default)
      #   SolidScore/SingleResponsibility:
      #     Enabled: true
      #     MinScore: 60
      class SingleResponsibility < PrincipleBase
        MSG = "SRP score %.1f is below minimum %g"

        private

        def principle_key = :srp
        def principle_name = "SRP"
      end
    end
  end
end
