# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::DiffClassifier do
  let(:classifier) { described_class.new }

  def make_result(srp:, ocp:, lsp:, isp:, dip:, breakdown: {})
    SolidScore::Models::ScoreResult.new(
      class_name: "Demo", srp: srp, ocp: ocp, lsp: lsp, isp: isp, dip: dip,
      subscores: breakdown
    )
  end

  describe "#classify" do
    it "returns the total delta" do
      before = make_result(srp: 100, ocp: 100, lsp: 100, isp: 100, dip: 100)
      after = make_result(srp: 80, ocp: 100, lsp: 100, isp: 80, dip: 100)
      result = classifier.classify(before, after)
      # default weights: srp 0.30 + isp 0.20 = 0.50 weight on the changed scores
      # 80 - 100 = -20 each → total drop = -20*0.30 + -20*0.20 = -10
      expect(result[:delta_total]).to be_within(0.01).of(-10.0)
    end

    it "labels OCP / DIP / LSP deltas as structural" do
      before = make_result(srp: 100, ocp: 100, lsp: 100, isp: 100, dip: 100)
      after = make_result(srp: 100, ocp: 80, lsp: 90, isp: 100, dip: 70)
      result = classifier.classify(before, after)
      # ocp: -20, lsp: -10, dip: -30 → structural delta = -60
      expect(result[:delta_structural]).to eq(-60.0)
      expect(result[:delta_mechanical]).to eq(0.0)
    end

    it "labels SRP / ISP deltas as mechanical" do
      before = make_result(srp: 100, ocp: 100, lsp: 100, isp: 100, dip: 100)
      after = make_result(srp: 80, ocp: 100, lsp: 100, isp: 70, dip: 100)
      result = classifier.classify(before, after)
      # srp: -20, isp: -30 → mechanical delta = -50
      expect(result[:delta_mechanical]).to eq(-50.0)
      expect(result[:delta_structural]).to eq(0.0)
    end

    it "splits a mixed degradation correctly" do
      before = make_result(srp: 100, ocp: 100, lsp: 100, isp: 100, dip: 100)
      after = make_result(srp: 90, ocp: 95, lsp: 100, isp: 80, dip: 60)
      result = classifier.classify(before, after)
      # structural: ocp -5 + lsp 0 + dip -40 = -45
      # mechanical: srp -10 + isp -20 = -30
      expect(result[:delta_structural]).to eq(-45.0)
      expect(result[:delta_mechanical]).to eq(-30.0)
    end

    # Issue #13 follow-up: edge cases.
    it "returns zero deltas when results are identical" do
      score = make_result(srp: 80, ocp: 70, lsp: 100, isp: 90, dip: 60)
      result = classifier.classify(score, score)
      expect(result).to eq(delta_total: 0.0, delta_structural: 0.0, delta_mechanical: 0.0)
    end

    it "reports positive deltas for improvements" do
      before = make_result(srp: 50, ocp: 50, lsp: 50, isp: 50, dip: 50)
      after = make_result(srp: 100, ocp: 100, lsp: 100, isp: 100, dip: 100)
      result = classifier.classify(before, after)
      expect(result[:delta_structural]).to eq(150.0)
      expect(result[:delta_mechanical]).to eq(100.0)
      expect(result[:delta_total]).to be > 0
    end

    it "rounds to one decimal place" do
      before = make_result(srp: 100.0, ocp: 100.0, lsp: 100.0, isp: 100.0, dip: 100.0)
      after = make_result(srp: 99.55, ocp: 100.0, lsp: 100.0, isp: 100.0, dip: 100.0)
      result = classifier.classify(before, after)
      # 99.55 - 100.0 = -0.45 -> rounds to -0.5 (Ruby Float#round(1), half-away-from-zero).
      # The exact half-rounding direction is irrelevant; what matters is the
      # result has at most 1 decimal place.
      expect(result[:delta_mechanical] * 10).to eq((result[:delta_mechanical] * 10).round)
    end
  end
end
