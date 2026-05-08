# frozen_string_literal: true

module SolidScore
  # Splits a between-revision delta into structural and mechanical
  # components so reviewers can tell genuine OCP/DIP/LSP regressions
  # apart from mass-only SRP/ISP movements.
  #
  # - +delta_structural+ = OCP + LSP + DIP (architectural decay signals)
  # - +delta_mechanical+ = SRP + ISP       (mass-driven movement)
  # - +delta_total+      = +ScoreResult#total+ delta (weighted)
  #
  # The classification is performed at the principle-score level rather
  # than the subscore level for now. The original IMPROVEMENT_PLAN.md
  # discusses subscore-level classification (e.g. attributing the SRP
  # +wmc_penalty+ to mechanical and the LCOM4 movement to structural);
  # extending this requires breakdowns from every analyzer and is
  # tracked as a follow-up.
  #
  # IMPORTANT: +delta_structural+ and +delta_mechanical+ are unweighted
  # sums while +delta_total+ applies +ScoreResult+ weights. They are NOT
  # required to add up to +delta_total+. Consumers that need the weighted
  # split should multiply the unweighted contributions by the relevant
  # weights themselves.
  #
  # Compare with +DiffAnalyzer+, which detects which classes/files
  # changed between two revisions but does not interpret score deltas.
  class DiffClassifier
    STRUCTURAL_PRINCIPLES = %i[ocp lsp dip].freeze
    MECHANICAL_PRINCIPLES = %i[srp isp].freeze

    def classify(before_result, after_result)
      {
        delta_total: round1(after_result.total - before_result.total),
        delta_structural: round1(principle_delta(before_result, after_result, STRUCTURAL_PRINCIPLES)),
        delta_mechanical: round1(principle_delta(before_result, after_result, MECHANICAL_PRINCIPLES))
      }
    end

    private

    def principle_delta(before_result, after_result, principles)
      principles.sum { |p| after_result.public_send(p) - before_result.public_send(p) }
    end

    def round1(value)
      value.round(1)
    end
  end
end
