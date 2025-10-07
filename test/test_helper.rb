require 'rbs/inline/annotator'
require 'rgot/cli'

unless $PROGRAM_NAME.end_with?("/rgot")
  at_exit do
    exit Rgot::Cli.new(["-v", "lib"]).run
  end
end
