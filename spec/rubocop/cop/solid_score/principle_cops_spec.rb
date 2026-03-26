# frozen_string_literal: true

require "spec_helper"
require "rubocop"
require "rubocop/rspec/expect_offense"
require "rubocop-solid_score"

RSpec.describe "Principle-specific cops" do
  let(:fixtures_path) { File.expand_path("../../../fixtures", __dir__) }

  shared_examples "a principle cop" do |cop_class, principle_name, config_key|
    subject(:cop) { cop_class.new(config) }

    let(:config) do
      RuboCop::Config.new(
        config_key => {
          "Enabled" => true,
          "MinScore" => min_score,
          "Weights" => {
            "srp" => 0.30, "ocp" => 0.15, "lsp" => 0.10,
            "isp" => 0.20, "dip" => 0.25
          },
          "DipWhitelist" => []
        }
      )
    end

    context "with a very high threshold (99)" do
      let(:min_score) { 99.0 }

      it "registers an offense for a class scoring below threshold" do
        source = File.read(File.join(fixtures_path, fixture_file))
        offenses = investigate_source(source, File.join(fixtures_path, fixture_file))
        expect(offenses).not_to be_empty, "Expected #{principle_name} offense for #{fixture_file}"
        offenses.each do |offense|
          expect(offense.message).to match(/#{principle_name} score .+ is below minimum/)
        end
      end
    end

    context "with a very low threshold (1)" do
      let(:min_score) { 1.0 }

      it "does not register an offense for a well-designed class" do
        source = File.read(File.join(fixtures_path, good_fixture_file))
        offenses = investigate_source(source, File.join(fixtures_path, good_fixture_file))
        expect(offenses).to be_empty,
                            "Expected no #{principle_name} offenses but found: #{offenses.map(&:message).join(', ')}"
      end
    end
  end

  describe RuboCop::Cop::SolidScore::SingleResponsibility do
    it_behaves_like "a principle cop",
                    RuboCop::Cop::SolidScore::SingleResponsibility,
                    "SRP", "SolidScore/SingleResponsibility" do
      let(:fixture_file) { "bad_srp.rb" }
      let(:good_fixture_file) { "good_srp.rb" }
    end
  end

  describe RuboCop::Cop::SolidScore::OpenClosed do
    it_behaves_like "a principle cop",
                    RuboCop::Cop::SolidScore::OpenClosed,
                    "OCP", "SolidScore/OpenClosed" do
      let(:fixture_file) { "bad_ocp.rb" }
      let(:good_fixture_file) { "good_ocp.rb" }
    end
  end

  describe RuboCop::Cop::SolidScore::LiskovSubstitution do
    it_behaves_like "a principle cop",
                    RuboCop::Cop::SolidScore::LiskovSubstitution,
                    "LSP", "SolidScore/LiskovSubstitution" do
      let(:fixture_file) { "bad_lsp.rb" }
      let(:good_fixture_file) { "good_lsp.rb" }
    end
  end

  describe RuboCop::Cop::SolidScore::InterfaceSegregation do
    it_behaves_like "a principle cop",
                    RuboCop::Cop::SolidScore::InterfaceSegregation,
                    "ISP", "SolidScore/InterfaceSegregation" do
      let(:fixture_file) { "bad_isp.rb" }
      let(:good_fixture_file) { "good_isp.rb" }
    end
  end

  describe RuboCop::Cop::SolidScore::DependencyInversion do
    it_behaves_like "a principle cop",
                    RuboCop::Cop::SolidScore::DependencyInversion,
                    "DIP", "SolidScore/DependencyInversion" do
      let(:fixture_file) { "bad_dip.rb" }
      let(:good_fixture_file) { "good_dip.rb" }
    end
  end

  private

  def investigate_source(source, file_path)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, file_path)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    result = commissioner.investigate(processed_source)
    result.offenses
  end
end
