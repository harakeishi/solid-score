# frozen_string_literal: true

module RuboCop
  module Cop
    module SolidScore
      # Checks that each class/module meets a minimum ISP (Interface Segregation Principle) score.
      #
      # @example MinScore: 70 (default)
      #   SolidScore/InterfaceSegregation:
      #     Enabled: true
      #     MinScore: 70
      class InterfaceSegregation < PrincipleBase
        MSG = "ISP score %.1f is below minimum %g"

        private

        def principle_key = :isp
        def principle_name = "ISP"
      end
    end
  end
end
