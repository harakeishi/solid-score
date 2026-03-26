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

      # 基本信頼度（解析手法の本質的な精度）
      BASE_CONFIDENCE = {
        srp: :high,
        ocp: :medium,
        lsp: :medium,
        isp: :medium_high,
        dip: :high
      }.freeze

      CONFIDENCE_ORDER = %i[low low_medium medium medium_high high].freeze

      attr_reader :class_name, :file_path, :srp, :ocp, :lsp, :isp, :dip, :weights, :class_info

      def initialize(class_name:, file_path: "", srp: 0.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0,
                     weights: DEFAULT_WEIGHTS, class_info: nil)
        @class_name = class_name
        @file_path = file_path
        @srp = srp
        @ocp = ocp
        @lsp = lsp
        @isp = isp
        @dip = dip
        @weights = weights
        @class_info = class_info
      end

      def total
        (srp * weights[:srp]) +
          (ocp * weights[:ocp]) +
          (lsp * weights[:lsp]) +
          (isp * weights[:isp]) +
          (dip * weights[:dip])
      end

      # Phase 2b: class_infoに基づく動的な信頼度計算
      def confidence
        return BASE_CONFIDENCE unless class_info

        {
          srp: adjusted_confidence(:srp),
          ocp: adjusted_confidence(:ocp),
          lsp: adjusted_confidence(:lsp),
          isp: adjusted_confidence(:isp),
          dip: adjusted_confidence(:dip)
        }
      end

      private

      def adjusted_confidence(principle)
        base = BASE_CONFIDENCE[principle]

        # メソッド数が少ない場合、全原則の信頼度が低下
        base = lower_confidence(base) if few_methods?

        case principle
        when :lsp
          # モジュールの場合はLSPは常にhigh（継承なしで100点固定）
          return :high if class_info.module?
          # 継承なしもhigh
          return :high unless class_info.has_superclass?
        when :srp
          # メソッド数が非常に少ない場合、LCOM4の意味が薄い
          base = lower_confidence(base) if class_info.methods.size <= 2
        end

        base
      end

      def few_methods?
        class_info.methods.size <= 1
      end

      def lower_confidence(level)
        idx = CONFIDENCE_ORDER.index(level) || 0
        CONFIDENCE_ORDER[[idx - 1, 0].max]
      end
    end
  end
end
