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
  end
end
