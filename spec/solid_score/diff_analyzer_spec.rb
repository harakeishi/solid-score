# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::DiffAnalyzer do
  describe "#changed_files" do
    it "returns list of changed .rb files" do
      analyzer = described_class.new("HEAD~1")
      allow(analyzer).to receive(:git_diff_names).and_return(
        "app/models/user.rb\napp/models/order.rb\nREADME.md\n"
      )

      files = analyzer.changed_files
      expect(files).to eq(["app/models/user.rb", "app/models/order.rb"])
    end
  end

  describe "#changed_line_ranges" do
    it "parses diff output into file => ranges hash" do
      analyzer = described_class.new("HEAD~1")
      diff_output = <<~DIFF
        --- a/app/models/user.rb
        +++ b/app/models/user.rb
        @@ -10,5 +10,8 @@ class User
      DIFF

      allow(analyzer).to receive(:git_diff_output).and_return(diff_output)

      ranges = analyzer.changed_line_ranges
      expect(ranges).to have_key("app/models/user.rb")
      expect(ranges["app/models/user.rb"]).to include(10..17)
    end
  end

  describe "#filter_classes" do
    it "filters classes to only those with changes in their line ranges" do
      analyzer = described_class.new("HEAD~1")

      class_a = SolidScore::Models::ClassInfo.new(
        name: "User", file_path: "app/models/user.rb",
        line_start: 5, line_end: 30
      )
      class_b = SolidScore::Models::ClassInfo.new(
        name: "Order", file_path: "app/models/order.rb",
        line_start: 1, line_end: 10
      )
      class_c = SolidScore::Models::ClassInfo.new(
        name: "Product", file_path: "app/models/product.rb",
        line_start: 1, line_end: 20
      )

      file_ranges = {
        "app/models/user.rb" => [10..17],
        "app/models/order.rb" => [50..55]
      }

      filtered = analyzer.filter_classes([class_a, class_b, class_c], file_ranges)
      expect(filtered.map(&:name)).to eq(["User"])
    end
  end
end
