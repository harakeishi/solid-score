# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::ConstantName do
  def superclass_node(source)
    Prism.parse(source).value.statements.body.first.superclass
  end

  it "returns nil for a missing node" do
    expect(described_class.of(nil)).to be_nil
  end

  it "renders a bare constant" do
    expect(described_class.of(superclass_node("class A < Base; end"))).to eq("Base")
  end

  it "joins a constant path with ::" do
    expect(described_class.of(superclass_node("class A < Foo::Bar::Baz; end"))).to eq("Foo::Bar::Baz")
  end

  it "keeps the leading :: of a top-level constant" do
    expect(described_class.of(superclass_node("class A < ::Foo::Bar; end"))).to eq("::Foo::Bar")
  end

  it "falls back to the source text for non-constant expressions" do
    expect(described_class.of(superclass_node("class A < Struct.new(:a, :b); end"))).to eq("Struct.new(:a, :b)")
  end
end
