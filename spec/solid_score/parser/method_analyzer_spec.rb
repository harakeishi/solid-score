# frozen_string_literal: true

require "spec_helper"

RSpec.describe SolidScore::Parser::MethodAnalyzer do
  def analyze(source, visibility: :public, kind: :instance)
    node = Prism.parse(source).value.statements.body.first
    described_class.new(node, visibility: visibility, kind: kind).method_info
  end

  it "records name, visibility, kind and line range" do
    info = analyze("def foo\n  1\nend", visibility: :private)

    expect(info.name).to eq(:foo)
    expect(info.visibility).to eq(:private)
    expect(info.kind).to eq(:instance)
    expect(info.line_start).to eq(1)
    expect(info.line_end).to eq(3)
  end

  it "collects instance variables from reads and every assignment form" do
    info = analyze("def foo\n  @a = @b\n  @c ||= 1\n  @d += 1\n  @e, @f = 1, 2\nend")

    expect(info.instance_variables).to eq(%i[@a @b @c @d @e @f])
  end

  it "collects called methods with receiver information" do
    info = analyze("def foo(x)\n  Foo::Bar.new\n  @repo.find\n  x.to_s\n  helper\n  self.class.name\nend")

    expect(info.called_methods).to include(:new, :find, :to_s, :helper, :name)
    types = info.method_calls.to_h { |c| [c.method_name, [c.receiver, c.receiver_type]] }
    expect(types[:new]).to eq(["Foo::Bar", :const])
    expect(types[:find]).to eq(["@repo", :ivar])
    expect(types[:to_s]).to eq(["x", :lvar])
    expect(types[:helper]).to eq([nil, :self])
    expect(types[:name]).to eq([nil, :send])
  end

  it "records the read side of attribute and index assignments as calls" do
    info = analyze("def foo\n  self.cache ||= 1\n  h[:k] ||= 2\nend")

    expect(info.called_methods).to include(:cache, :[])
  end

  it "records attribute and index targets of a multiple assignment as calls" do
    info = analyze("def foo(a, h)\n  a.x, h[:k] = 1, 2\nend")

    expect(info.called_methods).to eq(%i[x= []=])
    types = info.method_calls.to_h { |c| [c.method_name, [c.receiver, c.receiver_type]] }
    expect(types[:x=]).to eq(["a", :lvar])
    expect(types[:[]=]).to eq(["h", :lvar])
    expect(info.effective_statement_count).to eq(3)
  end

  it "collects raised constants" do
    info = analyze("def foo\n  raise ArgumentError, 'x'\n  fail Errors::Bad\n  raise Other.new('y')\nend")

    expect(info.raises).to eq(%w[ArgumentError Errors::Bad])
  end

  it "detects super calls with and without arguments" do
    expect(analyze("def foo\n  super\nend").calls_super).to be true
    expect(analyze("def foo\n  super(1)\nend").calls_super).to be true
    expect(analyze("def foo\n  bar\nend").calls_super).to be false
  end

  it "counts case/when branches but not case/in patterns" do
    source = <<~RUBY
      def foo(v)
        case v
        when 1 then :a
        when 2, 3 then :b
        else :c
        end
        case v
        in Integer then :i
        end
      end
    RUBY

    expect(analyze(source).case_when_count).to eq(2)
  end

  it "computes cyclomatic complexity from branches, loops, boolean operators and rescue" do
    source = <<~RUBY
      def foo(v)
        return 1 if v.nil?
        x = v && v.positive? ? 1 : 2
        while v > 0
          v -= 1
        end
        case v
        when 1 then :a
        when 2 then :b
        end
        begin
          risky
        rescue ArgumentError, TypeError
          retry
        rescue StandardError
          nil
        end
        v rescue nil
      end
    RUBY

    # 1 + if + and + ternary + while + when x2 + rescue (once) + rescue modifier
    expect(analyze(source).cyclomatic_complexity).to eq(9)
  end

  it "counts effective statements without descending into nested definitions" do
    source = "def foo\n  bar\n  x = 1\n  def inner\n    a\n    b\n  end\nend"

    expect(analyze(source).effective_statement_count).to eq(2)
  end

  it "counts operator assignments as two statements" do
    expect(analyze("def foo\n  @x ||= 1\nend").effective_statement_count).to eq(2)
  end

  it "counts a block as a statement in addition to its call" do
    expect(analyze("def foo\n  items.each { |i| i }\nend").effective_statement_count).to eq(3)
  end

  it "detects the memoized factory receiver" do
    expect(analyze("def foo\n  @s ||= Foo::Service.new(1)\nend").memoized_factory_receiver).to eq("Foo::Service")
    expect(analyze("def foo\n  @s ||= build\nend").memoized_factory_receiver).to be_nil
    expect(analyze("def foo\n  @s ||= Foo.fetch\nend").memoized_factory_receiver).to be_nil
  end

  it "maps parameters to parser-style type symbols" do
    info = analyze("def foo(a, b = 1, *c, d, e:, f: 2, **g, &h); end")

    expect(info.parameters).to eq([
                                    %i[arg a], %i[optarg b], %i[restarg c], %i[arg d],
                                    %i[kwarg e], %i[kwoptarg f], %i[kwrestarg g], %i[blockarg h]
                                  ])
  end

  it "maps anonymous, forwarding and destructured parameters" do
    expect(analyze("def foo(*, **, &); end").parameters)
      .to eq([[:restarg, nil], [:kwrestarg, nil], [:blockarg, nil]])
    expect(analyze("def foo(...); end").parameters).to eq([[:forward_arg, nil]])
    expect(analyze("def foo((a, b), **nil); end").parameters).to eq([[:mlhs, nil], [:kwnilarg, nil]])
    expect(analyze("def foo; end").parameters).to eq([])
  end
end
