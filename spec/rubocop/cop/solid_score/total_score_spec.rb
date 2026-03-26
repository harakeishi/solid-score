# frozen_string_literal: true

require "spec_helper"
require "rubocop"
require "rubocop/rspec/expect_offense"
require "rubocop-solid_score"

RSpec.describe RuboCop::Cop::SolidScore::TotalScore do
  subject(:cop) { described_class.new(config) }

  let(:config) do
    RuboCop::Config.new(
      "SolidScore/TotalScore" => cop_config
    )
  end

  let(:cop_config) do
    {
      "Enabled" => true,
      "MinScore" => min_score,
      "Weights" => {
        "srp" => 0.30,
        "ocp" => 0.15,
        "lsp" => 0.10,
        "isp" => 0.20,
        "dip" => 0.25
      },
      "DipWhitelist" => []
    }
  end

  let(:fixtures_path) { File.expand_path("../../../fixtures", __dir__) }

  describe "with a high threshold" do
    let(:min_score) { 95.0 }

    it "registers an offense for a class with low SOLID score" do
      source = File.read(File.join(fixtures_path, "bad_srp.rb"))
      expect_offense_in_file(source, File.join(fixtures_path, "bad_srp.rb"))
    end
  end

  describe "with a low threshold" do
    let(:min_score) { 10.0 }

    it "does not register an offense for a well-designed class" do
      source = File.read(File.join(fixtures_path, "good_srp.rb"))
      expect_no_offense_in_file(source, File.join(fixtures_path, "good_srp.rb"))
    end
  end

  describe "with default threshold (70)" do
    let(:min_score) { 70.0 }

    it "does not register an offense for a simple focused class" do
      source = File.read(File.join(fixtures_path, "simple_class.rb"))
      expect_no_offense_in_file(source, File.join(fixtures_path, "simple_class.rb"))
    end
  end

  private

  def expect_offense_in_file(source, file_path)
    offenses = investigate_source(source, file_path)
    expect(offenses).not_to be_empty, "Expected offenses but found none"
    offenses.each do |offense|
      expect(offense.message).to match(/SOLID total score .+ is below minimum/)
    end
  end

  def expect_no_offense_in_file(source, file_path)
    offenses = investigate_source(source, file_path)
    expect(offenses).to be_empty, "Expected no offenses but found: #{offenses.map(&:message).join(', ')}"
  end

  def investigate_source(source, file_path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    result = commissioner.investigate(processed_source)
    result.offenses
  end
end
