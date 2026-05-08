# frozen_string_literal: true

module SolidScore
  # Splits a between-revision delta into structural and mechanical
  # components so reviewers can tell genuine OCP/DIP/LSP regressions
  # apart from mass-only SRP/ISP movements.
  #
  # - Δstructural = OCP + LSP + DIP (changes that signal architectural decay)
  # - Δmechanical = SRP + ISP    (changes driven mostly by code mass)
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
