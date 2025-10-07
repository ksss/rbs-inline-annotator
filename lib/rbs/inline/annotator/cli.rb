# frozen_string_literal: true

require "optparse"

module RBS::Inline::Annotator
  class CLI
    class Spinner
      DOTS = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏]

      def initialize
        @index = 0
      end

      def tick
        @index = (@index + 1) % DOTS.size
        DOTS[@index]
      end
    end

    Options = Struct.new(:mode)

    def initialize(argv)
      @loader = RBS::EnvironmentLoader.new(core_root: nil)
      @argv = argv
      @options = Options.new(
        mode: 'write'
      )
      OptionParser.new do |opt|
        opt.on("-I DIR", "Load RBS files from the directory") do |dir|
          @loader.add(path: Pathname(dir))
        end
        opt.on("-m", "--mode MODE", "Mode [quiet, print-only, write] (default: write)") do |mode|
          @options.mode = mode
        end
      end.parse!(@argv)
    end

    def run
      env = RBS::Environment.from_loader(@loader)
      targets = @argv.flat_map { Pathname.glob(_1) }.flat_map do |path|
        if path.directory?
          pattern = path / "**/*.rb"
          Pathname.glob(pattern.to_s)
        else
          path
        end
      end

      targets.sort!
      targets.uniq!

      Spinner.new.tap do |spinner|
        print "\e[?25l" if @options.mode == 'write'
        targets.each do |target|
          annotated_code = Processor.new(target:, env:).process
          case @options.mode
          when 'write'
            File.write(target, annotated_code)
          when 'print-only'
            puts annotated_code
          when 'quiet'
            # do nothing
          else
            raise "invalid mode: #{@options.mode}"
          end
          print "\r#{spinner.tick}" if @options.mode == 'write'
        end
      ensure
        print "\e[?25h" if @options.mode == 'write'
      end

      puts "\rDone!" if @options.mode == 'write'

      0 # exit code
    end
  end
end
