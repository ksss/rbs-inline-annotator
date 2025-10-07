# RBS::Inline::Annotator

Add rbs-inline annotation to ruby code by rbs code.

```rb
# lib/foo.rb
class Foo
  def foo(a)
    a.to_s
  end
end
```

\+

```rbs
# sig/foo.rbs
class Foo
  def foo: (Integer) -> String
end
```

=

```rb
# lib/foo.rb
class Foo
  # @rbs a: Integer
  # @rbs return: String
  def foo(a)
    a.to_s
  end
end
```

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

### Add rbs-inline annotation to ruby file

```shell
$ bundle exec rbs-inline-annotator -I sig target_dir_or_file
```

### Print result code to stdout only

```shell
$ bundle exec rbs-inline-annotator -I sig --mode print-only target_dir_or_file
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ksss/rbs-inline-annotator. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ksss/rbs-inline-annotator/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rbs::Inline::Annotator project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ksss/rbs-inline-annotator/blob/main/CODE_OF_CONDUCT.md).
