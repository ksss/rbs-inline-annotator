module RBS::Inline::Annotator
  class Processor
    class Result
      attr_reader :writer, :prism_result, :actions, :diagnostics

      def initialize(writer:, prism_result:)
        @writer = writer
        @prism_result = prism_result
        @diagnostics = []
      end
    end

    attr_reader :target, :env, :style

    def initialize(target:, env:, style:)
      @target = target
      @env = env
      @style = style
    end

    # @rbs return: [String, bool] -- [code string, changed flag]
    def process
      absolute_path = Pathname.pwd + target
      source = absolute_path.read
      writer = Writer.new(source)
      result = Result.new(writer:, prism_result: Prism.parse_file(absolute_path.to_s))
      result.prism_result.value.accept(Visitor.new(env:, result:, style:))
      if result.writer.actions.empty?
        [source, false]
      else
        [writer.process, true]
      end
    end
  end
end
