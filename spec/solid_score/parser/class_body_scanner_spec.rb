# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::ClassBodyScanner do
  def scan(source, namespace: nil)
    node = Prism.parse(source).value.statements.body.first
    described_class.new(node, "example.rb", namespace).class_info
  end

  it "builds class info with name, superclass, kind and line range" do
    info = scan("class Foo::Bar < Base\nend")

    expect(info.name).to eq("Foo::Bar")
    expect(info.superclass).to eq("Base")
    expect(info.kind).to eq(:class)
    expect(info.file_path).to eq("example.rb")
    expect(info.line_start).to eq(1)
    expect(info.line_end).to eq(2)
  end

  it "qualifies the name with the namespace" do
    expect(scan("class Bar; end", namespace: "Foo").name).to eq("Foo::Bar")
  end

  it "builds module info without a superclass" do
    info = scan("module Helper\nend")

    expect(info.kind).to eq(:module)
    expect(info.superclass).to be_nil
  end

  it "tracks visibility modifiers for instance methods" do
    source = <<~RUBY
      class A
        def a; end
        private
        def b; end
        protected
        def c; end
        public
        def d; end
      end
    RUBY

    expect(scan(source).methods.map { |m| [m.name, m.visibility] })
      .to eq([%i[a public], %i[b private], %i[c protected], %i[d public]])
  end

  it "treats methods with a receiver as public class methods" do
    info = scan("class A\n  private\n  def self.build; end\nend")

    build = info.methods.first
    expect(build.kind).to eq(:class)
    expect(build.visibility).to eq(:public)
  end

  it "collects include and extend targets" do
    info = scan("class A\n  include Comparable\n  extend Forwardable\nend")

    expect(info.includes).to eq(["Comparable"])
    expect(info.extends).to eq(["Forwardable"])
  end

  it "collects attr declarations given as symbols" do
    info = scan("class A\n  attr_reader :a\n  attr_writer :b\n  attr_accessor :c, :d\n  attr_reader 'ignored'\nend")

    expect(info.attr_readers).to eq(%i[a c d])
    expect(info.attr_writers).to eq(%i[b c d])
  end

  it "records Rails DSL calls without treating them as methods" do
    info = scan("class A\n  has_many :items\n  validates :name\n  custom_macro :x\nend")

    expect(info.dsl_calls).to eq(%i[has_many validates])
    expect(info.methods).to be_empty
  end

  it "scans methods when the class body has a rescue clause" do
    source = "class A\n  def a; end\nrescue StandardError\n  nil\nend"

    expect(scan(source).methods.map(&:name)).to eq(%i[a])
  end

  it "aggregates instance variables from its methods" do
    info = scan("class A\n  def a\n    @x = 1\n  end\n  def b\n    @x + @y\n  end\nend")

    expect(info.instance_variables).to eq(%i[@x @y])
  end
end
