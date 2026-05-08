# frozen_string_literal: true

module SolidScore
  class Scorer
    def initialize(weights: Models::ScoreResult::DEFAULT_WEIGHTS, dip_whitelist: [])
      @weights = weights
      @srp_analyzer = Analyzers::SrpAnalyzer.new
      @ocp_analyzer = Analyzers::OcpAnalyzer.new
      @lsp_analyzer = Analyzers::LspAnalyzer.new
      @isp_analyzer = Analyzers::IspAnalyzer.new
      @dip_analyzer = Analyzers::DipAnalyzer.new(user_whitelist: dip_whitelist)
    end

    def score(class_info)
      srp = @srp_analyzer.analyze_with_breakdown(class_info)

      Models::ScoreResult.new(
        class_name: class_info.name,
        file_path: class_info.file_path,
        srp: srp[:score],
        ocp: @ocp_analyzer.analyze(class_info),
        lsp: @lsp_analyzer.analyze(class_info),
        isp: @isp_analyzer.analyze(class_info),
        dip: @dip_analyzer.analyze(class_info),
        weights: @weights,
        class_info: class_info,
        subscores: { srp: srp[:breakdown] }
      )
    end

    def score_all(class_infos)
      class_infos.map { |ci| score(ci) }
    end
  end
end
