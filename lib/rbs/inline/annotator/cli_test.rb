require "test_helper"
require "tempfile"

module CLITest
  def test_constants(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        class Constants
          CONST = 1
          OBJECT = Object.new
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        class Constants
          CONST: Integer
          OBJECT: Object
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class Constants
          CONST = 1 #: Integer
          OBJECT = Object.new #: Object
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_attributes(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        class Attributes
          attr_reader :a
          attr_accessor :b, :c, :d
          attr_writer :z

          %i[aaa bbb ccc].each do |name|
            attr_accessor name
          end
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        class Attributes
          attr_reader a: String
          attr_writer z: untyped
          attr_accessor b: Integer
          attr_accessor c: Float
          attr_accessor d: untyped
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class Attributes
          attr_reader :a #: String
          attr_accessor :b #: Integer
          attr_accessor :c #: Float
          attr_accessor :d #: untyped
          attr_writer :z

          %i[aaa bbb ccc].each do |name|
            attr_accessor name
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_methods(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        class Methods
          def foo(req, opt = nil, *rest, post, key:, keyopt: nil, **keyrest)
          end

          def bar(a = 0)
          end

          def dot3(...)
          end

          def endless = 1

          def block
          end

          def override
          end

          def annotation
          end

          def self.foo(a)
          end

          class << self
            def bar(a)
            end
          end
        end
      RUBY

      (dir / "target.rbs").write(<<~RBS)
        class Methods
          def foo: (Integer, ?Integer, *Integer, Integer, key: Integer, ?keyopt: Integer, **Integer) -> Rational

          def bar: () -> Integer
                | (Integer) -> Integer

          def dot3: (?) -> Integer

          def endless: () -> Integer

          def block: () ?{ (Integer) -> Integer } -> void

          def override: ...

          %a{pure} %a{deprecated}
          def annotation: () -> void

          def self.foo: (Integer) -> Integer

          def self.bar: (Integer) -> Integer
        end
      RBS

      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class Methods
          # @rbs req: Integer
          # @rbs opt: Integer
          # @rbs *rest: Integer
          # @rbs post: Integer
          # @rbs key: Integer
          # @rbs keyopt: Integer
          # @rbs **keyrest: Integer
          # @rbs return: Rational
          def foo(req, opt = nil, *rest, post, key:, keyopt: nil, **keyrest)
          end

          # @rbs () -> Integer
          #    | (Integer) -> Integer
          def bar(a = 0)
          end

          # @rbs return: Integer
          def dot3(...)
          end

          # @rbs return: Integer
          def endless = 1

          # @rbs &: ? (Integer) -> Integer
          # @rbs return: void
          def block
          end

          # @rbs overload
          def override
          end

          # @rbs %a{pure}
          # @rbs %a{deprecated}
          # @rbs return: void
          def annotation
          end

          # @rbs a: Integer
          # @rbs return: Integer
          def self.foo(a)
          end

          class << self
            # @rbs a: Integer
            # @rbs return: Integer
            def bar(a)
            end
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_mixin(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        class Mixin
          include Enumerable
          extend One, Two, Three
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        class Mixin
          include Enumerable[Integer]
          extend One[A]
          extend Two[A,B]
          extend Three[A,B,C]
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class Mixin
          include Enumerable #[Integer]
          extend One #[A]
          extend Two #[A, B]
          extend Three #[A, B, C]
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_superclass(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        class A < Array
        end

        class H < Hash
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        class A < Array[Integer]
        end

        class H < Hash[Symbol, String]
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class A < Array #[Integer]
        end

        class H < Hash #[Symbol, String]
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_module_self(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        module ModuleSelf
          module ModuleSelf2
          end
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        module ModuleSelf : Object
          module ModuleSelf2 : Object
          end
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        # @rbs module-self Object
        module ModuleSelf
          # @rbs module-self Object
          module ModuleSelf2
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_absolute_namespace(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = (dir / "target.rb")
      target.write(<<~RUBY)
        module ::Abs
          module ::Abs::Name
            def abs_name
            end
          end
        end
      RUBY
      (dir / "target.rbs").write(<<~RBS)
        module Abs
          module Name
            def abs_name: () -> void
          end
        end
      RBS

      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        module ::Abs
          module ::Abs::Name
            # @rbs return: void
            def abs_name
            end
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_emoji(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = dir / "sample.rb"
      target.write(<<~RUBY)
        class Foo
          # ☕️
          def bar
          end
        end
      RUBY
      (dir / "sample.rbs").write(<<~RBS)
        class Foo
          def bar: () -> void
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      cli.run

      expected = <<~RUBY
        class Foo
          # ☕️
          # @rbs return: void
          def bar
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_write(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = dir / "sample.rb"
      target.write(<<~RUBY)
        class Foo
          def bar(a)
          end
        end
      RUBY
      (dir / "sample.rbs").write(<<~RBS)
        class Foo
          def bar: (Integer) -> void
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "write", "-I", dir.to_s, target.to_s])
      capture do
        cli.run
      end

      expected = <<~RUBY
        class Foo
          # @rbs a: Integer
          # @rbs return: void
          def bar(a)
          end
        end
      RUBY
      unless target.read == expected
        t.error("target expected: \n```\n#{expected}```\n, but got:\n```\n#{target.read}```\n")
      end
    end
  end

  def test_print_only(t)
    Dir.mktmpdir do |dir|
      dir = Pathname(dir)
      target = dir / "sample.rb"
      target.write(<<~RUBY)
        class Foo
          def bar
          end
        end
      RUBY
      (dir / "sample.rbs").write(<<~RBS)
        class Foo
          def bar: () -> void
        end
      RBS
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "print-only", "-I", dir.to_s, target.to_s])
      capture do
        cli.run

        expected = <<~RUBY
          class Foo
            # @rbs return: void
            def bar
            end
          end
        RUBY
        unless $stdout.string == expected
          t.error("stdout expected: \n```\n#{expected}```\n, but got:\n```\n#{$stdout.string}```\n")
        end
      end
    end
  end

  def test_quiet(t)
    Tempfile.create do |file|
      file.write(<<~RUBY)
        class Foo
          def bar
          end
        end
      RUBY
      file.close
      target = file.path
      cli = RBS::Inline::Annotator::CLI.new(["--mode", "quiet", target])
      capture do
        cli.run

        unless $stdout.string.empty?
          t.error("stdout should be quiet, but got: \"#{$stdout.string.inspect}\"")
        end
        unless $stderr.string.empty?
          t.error("stderr should be quiet, but got: \"#{$stderr.string.inspect}\"")
        end
      end
    end
  end

  private

  def capture
    orig_stdout = $stdout
    orig_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = orig_stdout
    $stderr = orig_stderr
  end
end
