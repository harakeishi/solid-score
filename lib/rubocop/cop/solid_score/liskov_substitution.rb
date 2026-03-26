# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum LSP (Liskov Substitution Principle) score.
      #
      # @example MinScore: 60 (default)
      #   SolidScore/LiskovSubstitution:
      #     Enabled: true
      #     MinScore: 60
      class LiskovSubstitution < PrincipleBase
        MSG = "LSP score %.1f is below minimum %g"

        private

        def principle_key = :lsp
        def principle_name = "LSP"
      end
    end
  end
end
