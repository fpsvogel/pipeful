# Pipeful

Pipeful makes it easy to pipe data through functions (callable objects). Just write the function classes and then chain them with the `>>` operator:

```ruby
extend Pipeful

'C:\test.txt' >> LoadFromFile >> ProcessData >> OutputResult(STDOUT)
```

## Usage

See [`pipeful_test.rb`](https://github.com/fps-vogel/pipeful/blob/master/test/pipeful_test.rb) for examples.

For the story of how this gem came to be, see [Beginning Functional Programming with Ruby](https://fpsvogel.netlify.app/posts/2020-12-21-ruby-functional-programming.html).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pipeful'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pipeful

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fps-vogel/pipeful.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
