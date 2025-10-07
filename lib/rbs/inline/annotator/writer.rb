module RBS::Inline::Annotator
  # action:
  #   insert_before(range, "# @rbs foo: Integer")
  #   insert_before(range, "# @rbs bar: Integer")
  # expect:
  #   # @rbs foo: Integer
  #   # @rbs bar: Integer
  #   def foo(foo, bar)
  class Writer
    class Action
      attr_reader :range, :text

      def initialize(range:, text:)
        @range = range
        @text = text
      end
    end

    class InsertBefore < Action
      def process(writer)
        if writer.before_pos < range.begin
          writer.slice << writer.source[writer.before_pos...range.begin]
          writer.before_pos = range.begin
        elsif writer.before_pos == range.begin
          # do nothing
        else
          raise "invalid range: #{range}, before_pos: #{writer.before_pos}"
        end
        writer.slice << text
      end
    end

    class InsertAfter < Action
      def process(writer)
        if writer.before_pos < range.end
          writer.slice << writer.source[writer.before_pos...range.end]
          writer.before_pos = range.end
        elsif writer.before_pos == range.end - 1
          # do nothing
        else
          raise "invalid range: #{range}, before_pos: #{writer.before_pos}"
        end
        writer.slice << text
      end
    end

    class Replace < Action
      def process(writer)
        if writer.before_pos < range.begin
          writer.slice << writer.source[writer.before_pos...range.begin]
          writer.before_pos = range.end
        elsif writer.before_pos == range.begin
          writer.before_pos = range.end
        else
          raise "invalid range: #{range}, before_pos: #{writer.before_pos}"
        end
        writer.slice << text
      end
    end

    attr_reader :source, :actions, :slice
    attr_accessor :before_pos

    def initialize(source)
      @source = source
      @actions = []
      @slice = []
      @before_pos = 0
    end

    def insert_before(range:, text:)
      actions << InsertBefore.new(range:, text:)
    end

    def insert_after(range:, text:)
      actions << InsertAfter.new(range:, text:)
    end

    def replace(range:, text:)
      actions << Replace.new(range:, text:)
    end

    def process
      actions.sort_by { |action|
        action.range.begin
      }.each do |action|
        action.process(self)
      end

      if before_pos < source.length
        slice << source[before_pos..]
      end

      slice.join
    end
  end
end
