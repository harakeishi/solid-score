# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SolidScore::Formatters::JsonFormatter do
  let(:results) do
    [
      SolidScore::Models::ScoreResult.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0, ocp: 70.0, lsp: 100.0, isp: 60.0, dip: 75.0
      )
    ]
  end

  describe "#format" do
    it "returns valid JSON" do
      formatter = described_class.new
      output = formatter.format(results)
      parsed = JSON.parse(output)

      expect(parsed).to be_a(Hash)
      expect(parsed["classes"]).to be_an(Array)
      expect(parsed["classes"].first["class_name"]).to eq("OrderService")
      expect(parsed["classes"].first["srp"]).to eq(85.0)
    end

    it "includes summary" do
      formatter = described_class.new
      output = formatter.format(results)
      parsed = JSON.parse(output)

      expect(parsed["summary"]).to include("total_classes")
      expect(parsed["summary"]).to include("average_score")
    end
  end
end
