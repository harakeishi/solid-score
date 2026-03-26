# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Presets do
  describe ".fetch" do
    it "returns Rails preset" do
      preset = described_class.fetch("rails")

      expect(preset[:paths]).to include("app/models", "app/controllers", "app/services", "lib")
      expect(preset[:exclude]).to include("spec/**", "test/**", "vendor/**")
      expect(preset[:weights]).to be_a(Hash)
      expect(preset[:weights].values.sum).to be_within(0.001).of(1.0)
      expect(preset[:dip_whitelist]).to include("Rails", "Logger")
    end

    it "accepts symbol name" do
      expect(described_class.fetch(:rails)).to eq(described_class.fetch("rails"))
    end

    it "raises ArgumentError for unknown preset" do
      expect { described_class.fetch("unknown") }.to raise_error(ArgumentError, /Unknown preset: unknown/)
    end
  end

  describe ".available" do
    it "returns list of available preset names" do
      expect(described_class.available).to include("rails")
    end
  end
end
