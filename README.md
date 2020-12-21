# Pipeful

Pipeful makes it easy to pipe data through functions (callable objects). Just write the function classes and then chain them with the `>>` operator:

```ruby
extend Pipeful

'C:\test.txt' >> LoadFromFile >> ProcessData >> OutputResult(STDOUT)
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pipeful'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pipeful

## Usage

See `pipeful_test.rb` for examples.

For the story of how this gem came to be, see [Beginning Functional Programming with Ruby](https://fpsvogel.netlify.app/posts/2020-12-21-ruby-functional-programming.html).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fps-vogel/pipeful.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
