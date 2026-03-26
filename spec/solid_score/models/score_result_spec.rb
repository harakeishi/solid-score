# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Models::ScoreResult do
  describe "#initialize" do
    it "stores scores for each principle" do
      result = described_class.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0,
        ocp: 70.0,
        lsp: 100.0,
        isp: 60.0,
        dip: 75.0
      )

      expect(result.srp).to eq(85.0)
      expect(result.ocp).to eq(70.0)
      expect(result.class_name).to eq("OrderService")
    end
  end

  describe "#total" do
    it "calculates weighted average with default weights" do
      result = described_class.new(
        class_name: "Foo",
        srp: 100.0, ocp: 100.0, lsp: 100.0, isp: 100.0, dip: 100.0
      )
      expect(result.total).to eq(100.0)
    end

    it "applies custom weights" do
      result = described_class.new(
        class_name: "Foo",
        srp: 100.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0,
        weights: { srp: 1.0, ocp: 0.0, lsp: 0.0, isp: 0.0, dip: 0.0 }
      )
      expect(result.total).to eq(100.0)
    end
  end

  describe "#confidence" do
    it "returns base confidence levels without class_info" do
      result = described_class.new(class_name: "Foo")
      confidence = result.confidence

      expect(confidence[:srp]).to eq(:high)
      expect(confidence[:ocp]).to eq(:medium)
      expect(confidence[:dip]).to eq(:high)
    end

    # Phase 2b: class_infoに基づく動的な信頼度
    it "lowers confidence when class has few methods" do
      class_info = SolidScore::Models::ClassInfo.new(
        name: "Tiny",
        methods: [
          SolidScore::Models::MethodInfo.new(name: :foo, line_start: 1, line_end: 3)
        ]
      )
      result = described_class.new(class_name: "Tiny", class_info: class_info)
      confidence = result.confidence

      # 1メソッドしかない → 全体的に信頼度低下
      expect(SolidScore::Models::ScoreResult::CONFIDENCE_ORDER.index(confidence[:srp])).to be <
        SolidScore::Models::ScoreResult::CONFIDENCE_ORDER.index(:high)
    end

    it "returns high LSP confidence for modules" do
      class_info = SolidScore::Models::ClassInfo.new(
        name: "MyModule",
        kind: :module,
        methods: [
          SolidScore::Models::MethodInfo.new(name: :foo, line_start: 1, line_end: 3),
          SolidScore::Models::MethodInfo.new(name: :bar, line_start: 5, line_end: 7)
        ]
      )
      result = described_class.new(class_name: "MyModule", class_info: class_info)

      expect(result.confidence[:lsp]).to eq(:high)
    end
  end
end
