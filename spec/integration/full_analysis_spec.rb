# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Full analysis integration" do
  let(:fixtures_path) { File.expand_path("../fixtures", __dir__) }

  it "analyzes all fixture files end-to-end" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    results = runner.run

    expect(results).not_to be_empty

    results.each do |result|
      expect(result.srp).to be_between(0, 100)
      expect(result.ocp).to be_between(0, 100)
      expect(result.lsp).to be_between(0, 100)
      expect(result.isp).to be_between(0, 100)
      expect(result.dip).to be_between(0, 100)
      expect(result.total).to be_between(0, 100)
    end
  end

  it "good classes score higher than bad classes on SRP" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    results = runner.run

    good_srp = results.find { |r| r.class_name == "TaxCalculator" }
    bad_srp = results.find { |r| r.class_name == "GodClass" }

    expect(good_srp.srp).to be > bad_srp.srp if good_srp && bad_srp
  end

  it "outputs valid text format" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]

    runner = SolidScore::Runner.new(config)
    runner.run
    output = runner.formatted_output

    expect(output).to include("solid-score")
    expect(output).to include("Average")
  end

  it "outputs valid JSON format" do
    config = SolidScore::Configuration.default
    config.paths = [fixtures_path]
    config.format = :json

    runner = SolidScore::Runner.new(config)
    runner.run
    output = runner.formatted_output

    parsed = JSON.parse(output)
    expect(parsed["classes"]).to be_an(Array)
    expect(parsed["summary"]["total_classes"]).to be > 0
  end
end
