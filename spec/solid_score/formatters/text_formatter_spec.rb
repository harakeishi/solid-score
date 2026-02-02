# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Formatters::TextFormatter do
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
    it "includes class name and scores" do
      formatter = described_class.new
      output = formatter.format(results)

      expect(output).to include("OrderService")
      expect(output).to include("85")
      expect(output).to include("70")
    end

    it "includes project average" do
      formatter = described_class.new
      output = formatter.format(results)

      expect(output).to include("Average")
    end
  end
end
