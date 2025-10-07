# frozen_string_literal: true

require_relative "lib/rbs/inline/annotator/version"

Gem::Specification.new do |spec|
  spec.name = "rbs-inline-annotator"
  spec.version = RBS::Inline::Annotator::VERSION
  spec.authors = ["ksss"]
  spec.email = ["co000ri@gmail.com"]

  spec.summary = "RBS inline annotator from RBS"
  spec.description = "RBS inline annotator from RBS"
  spec.homepage = "https://github.com/ksss/rbs-inline-annotator"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    [
      %w[CHANGELOG.md CODE_OF_CONDUCT.md LICENSE.txt README.md],
      Dir.glob("lib/**/*.rb").grep_v(/_test\.rb\z/),
      Dir.glob("exe/*")
    ].flatten
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "prism"
  spec.add_dependency "rbs", "~> 4.0.0.dev.4"
end
