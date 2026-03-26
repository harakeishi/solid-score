# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum DIP (Dependency Inversion Principle) score.
      #
      # @example MinScore: 65 (default)
      #   SolidScore/DependencyInversion:
      #     Enabled: true
      #     MinScore: 65
      class DependencyInversion < PrincipleBase
        MSG = "DIP score %.1f is below minimum %g"

        private

        def principle_key = :dip
        def principle_name = "DIP"
      end
    end
  end
end
