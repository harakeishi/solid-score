# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::DefinitionCollector do
  def collect(source)
    collector = described_class.new("example.rb")
    Prism.parse(source).value.accept(collector)
    collector.classes
  end

  it "collects top-level classes and modules in source order" do
    names = collect("class A; end\nmodule B; end\nclass C; end").map(&:name)

    expect(names).to eq(%w[A B C])
  end

  it "qualifies nested definitions with their namespace" do
    source = "module Payments\n  class Processor\n    class Error; end\n  end\n  module Util; end\nend"

    expect(collect(source).map(&:name))
      .to eq(%w[Payments Payments::Processor Payments::Processor::Error Payments::Util])
  end

  it "keeps the namespace after an empty-bodied sibling definition" do
    source = "module Outer\n  class Empty < StandardError; end\n  class Sibling\n    def run; end\n  end\nend"

    expect(collect(source).map(&:name)).to eq(%w[Outer Outer::Empty Outer::Sibling])
  end

  it "finds top-level definitions inside guard expressions" do
    expect(collect("if defined?(Rails)\n  class Guarded; end\nend").map(&:name)).to eq(%w[Guarded])
  end

  it "ignores definitions nested inside a class body expression" do
    source = "class A\n  if ENV['X']\n    class Hidden; end\n  end\nend"

    expect(collect(source).map(&:name)).to eq(%w[A])
  end

  it "collects nested definitions when the body has an ensure clause" do
    source = "module Outer\n  class Inner; end\nensure\n  nil\nend"

    expect(collect(source).map(&:name)).to eq(%w[Outer Outer::Inner])
  end

  it "attaches the file path to every definition" do
    expect(collect("class A; end").first.file_path).to eq("example.rb")
  end
end
