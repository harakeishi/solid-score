# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SolidScore::CLI do
  let(:fixtures_path) { File.expand_path("../fixtures", __dir__) }

  describe "#run" do
    it "analyzes files and outputs results" do
      cli = described_class.new
      output = capture_stdout { cli.run([fixtures_path]) }

      expect(output).to include("solid-score")
      expect(output).to include("Average")
    end

    it "supports --format json" do
      cli = described_class.new
      output = capture_stdout { cli.run([fixtures_path, "--format", "json"]) }

      parsed = JSON.parse(output)
      expect(parsed["classes"]).to be_an(Array)
    end

    it "supports --version" do
      cli = described_class.new
      output = capture_stdout { cli.run(["--version"]) }

      expect(output).to include(SolidScore::VERSION)
    end

    it "returns exit code 1 when below threshold" do
      cli = described_class.new
      exit_code = nil

      capture_stdout do
        exit_code = cli.run([fixtures_path, "--min-score", "100"])
      end

      expect(exit_code).to eq(1)
    end

    it "returns exit code 0 when passing" do
      cli = described_class.new
      exit_code = nil

      capture_stdout do
        exit_code = cli.run([fixtures_path, "--min-score", "0"])
      end

      expect(exit_code).to eq(0)
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
