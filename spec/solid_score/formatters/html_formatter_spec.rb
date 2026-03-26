# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Formatters::HtmlFormatter do
  let(:results) do
    [
      SolidScore::Models::ScoreResult.new(
        class_name: "OrderService",
        file_path: "app/services/order_service.rb",
        srp: 85.0, ocp: 70.0, lsp: 100.0, isp: 60.0, dip: 75.0
      ),
      SolidScore::Models::ScoreResult.new(
        class_name: "UserController",
        file_path: "app/controllers/user_controller.rb",
        srp: 40.0, ocp: 90.0, lsp: 80.0, isp: 50.0, dip: 30.0
      )
    ]
  end

  describe "#format" do
    it "returns valid HTML document" do
      output = described_class.new.format(results)

      expect(output).to include("<!DOCTYPE html>")
      expect(output).to include("<html")
      expect(output).to include("</html>")
      expect(output).to include("<style>")
    end

    it "includes version" do
      output = described_class.new.format(results)

      expect(output).to include("v#{SolidScore::VERSION}")
    end

    it "includes class names" do
      output = described_class.new.format(results)

      expect(output).to include("OrderService")
      expect(output).to include("UserController")
    end

    it "includes file paths" do
      output = described_class.new.format(results)

      expect(output).to include("app/services/order_service.rb")
    end

    it "includes scores" do
      output = described_class.new.format(results)

      expect(output).to include("85.0")
      expect(output).to include("70.0")
    end

    it "includes SVG chart" do
      output = described_class.new.format(results)

      expect(output).to include("<svg")
      expect(output).to include("SRP")
      expect(output).to include("OCP")
    end

    it "includes summary cards" do
      output = described_class.new.format(results)

      expect(output).to include("Average Score")
      expect(output).to include("Classes Analyzed")
    end

    it "applies color classes based on score" do
      output = described_class.new.format(results)

      expect(output).to include("score-green")
      expect(output).to include("score-red")
    end

    it "returns message for empty results" do
      output = described_class.new.format([])

      expect(output).to include("<!DOCTYPE html>")
      expect(output).to include("No classes found")
    end

    it "escapes HTML in class names" do
      results_with_html = [
        SolidScore::Models::ScoreResult.new(
          class_name: "Foo<Bar>",
          srp: 100.0, ocp: 100.0, lsp: 100.0, isp: 100.0, dip: 100.0
        )
      ]

      output = described_class.new.format(results_with_html)

      expect(output).not_to include("Foo<Bar>")
      expect(output).to include("Foo&lt;Bar&gt;")
    end
  end
end
