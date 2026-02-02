# frozen_string_literal: true

module SolidScore
  module Models
    class ScoreResult
      DEFAULT_WEIGHTS = {
        srp: 0.30,
        ocp: 0.15,
        lsp: 0.10,
        isp: 0.20,
        dip: 0.25
      }.freeze

      CONFIDENCE_LEVELS = {
        srp: :high,
        ocp: :low,
        lsp: :low_medium,
        isp: :medium_high,
        dip: :high
      }.freeze

      attr_reader :class_name, :file_path, :srp, :ocp, :lsp, :isp, :dip, :weights

      def initialize(class_name:, file_path: "", srp: 0.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0,
                     weights: DEFAULT_WEIGHTS)
        @class_name = class_name
        @file_path = file_path
        @srp = srp
        @ocp = ocp
        @lsp = lsp
        @isp = isp
        @dip = dip
        @weights = weights
      end

      def total
        (srp * weights[:srp]) +
          (ocp * weights[:ocp]) +
          (lsp * weights[:lsp]) +
          (isp * weights[:isp]) +
          (dip * weights[:dip])
      end

      def confidence
        CONFIDENCE_LEVELS
      end
    end
  end
end
