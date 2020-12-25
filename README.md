# Pipeful

Pipeful makes it easy to pipe data through functions (callable objects). Just write the function classes and then chain them with the `>>` operator:

```ruby
extend Pipeful

'C:\test.txt' >> LoadFromFile >> ProcessData >> OutputResult(STDOUT)
```

## Usage

See [`pipeful_test.rb`](https://github.com/fps-vogel/pipeful/blob/master/test/pipeful_test.rb) for examples.

For the story of how this gem came to be, see [Beginning Functional Programming with Ruby](https://fpsvogel.netlify.app/posts/2020-12-21-ruby-functional-programming.html).

**NOTE:** If the body of a class/module has executable code that pipes functions defined in that same class/module, you should `extend Pipeful` *after* the function definitions. Like this:

```ruby
require "pipeful"

module App
  class Arithmetic
    def self.call(n, m, op:)
      n * m
    end
  end

  extend Pipeful  # must be AFTER function definitions!

  3 >> Arithmetic(2, op: :*)
end
```

Otherwise, if you call those functions with parenthetical arguments or a block, you will get a `NoMethodError`. The reason is that upon being extended, `Pipeful` looks for functions to "methodize" at the point of `extend` and also at the end of the class/module. So there are no methods to handle method-style function calls in executable code between those two points, if they refer to functions also defined between those two points.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "pipeful"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pipeful

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fps-vogel/pipeful.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
