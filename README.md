_UPDATE, March 2023: Here's an approach that is far simpler and less hacky, and achieves nearly the same thing: https://www.gregnavis.com/articles/elixir-style-pipelines-in-9-lines-of-ruby.html_

_UPDATE, May 2022: I have removed this gem from RubyGems. I've changed my mind and I no longer think this syntax is helpful. In fact, it can easily become a source of confusion and bugs. So I'm no longer maintaining this gem._

# Pipeful

Pipeful makes it easy to pipe data through functions (callable objects). Just write the function classes and then chain them with the `>>` operator:

```ruby
extend Pipeful

'C:\test.txt' >> LoadFromFile >> ProcessData >> OutputResult(STDOUT)
```

## Usage

See [`pipeful_test.rb`](https://github.com/fpsvogel/pipeful/blob/master/test/pipeful_test.rb) for examples.

For the story of how this gem came to be, see [Functional programming techniques in Ruby](https://fpsvogel.netlify.app/posts/2020-12-21-ruby-functional-programming.html).

## Installation

Still, if you want to use the gem, you can add this line to your application's Gemfile:

```ruby
gem "pipeful", :git => "git://github.com/fpsvogel/pipeful.git"
```

And then execute:

    $ bundle install

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fpsvogel/pipeful.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
