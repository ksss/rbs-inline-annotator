# frozen_string_literal: true

require "bundler/gem_tasks"
require "rgot/cli"

require "rake/testtask"
Rake::TestTask.new do |task|
  task.libs = %w[lib test]
  task.test_files = FileList["lib/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: [:rubocop, :test]
