# frozen_string_literal: true

require_relative "test_helper"
require "binding_of_caller"  # for local mode (experimental) for piping local variables

class InfoTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Pipeful::VERSION
  end
end

class PipeFeaturesTest < Minitest::Test
  def test_basic_pipe_features
    assert_equal [121, 5, 42], AppModule.result.to_a
  end

  module AppModule
    extend Pipeful

    def self.result
      100 >>
        ASimple >>           # == 110
        BNested >>           # == 121
        CNoCallParams >>     # == +[121, 10] (unary "+" means "this is a pipe buffer, not a normal array")
        DPushResults >>      # == +[121, 10, 20, 30]
        EPopArgs >>          # == +[121, 10, 50]
        FNoReturn >>         # == 121
        GClassMethod >>      # == 121
        HWithBlock do |n1, n2|
          +[n1, n2] >>       # == +[121, 5]
            I_CONSTANT >>    # == +[121, 5]
            42 >>            # == +[121, 5, 42]
            JNotFunction     # == JNotFunction object containing [121, 5, 42]
        end
    end

    class ASimple
      def call(n)
        n + 10
      end
    end

    class BNested
      include Pipeful

      def call(n)
        n >> ASimple >> InsideB
      end

      class InsideB
        def call(n)
          n + 1
        end
      end
    end

    class CNoCallParams
      # no parameters, so value is simply pushed onto the pipe buffer
      def call
        10
      end
    end

    class DPushResults
      # use "+" pipe buffer conversion to push multiple values onto the buffer.
      # if this were returned as an array, it would be passed into the next function as a single argument
      def call
        +[20, 30]
      end
    end

    class EPopArgs
      # if there are more items in the pipe buffer than arguments in the next .call,
      # then the last item(s) are popped off the buffer, and the result is pushed to it.
      def call(second_to_last, last)
        second_to_last + last
      end
    end

    class FNoReturn
      # to return nothing, simply return an empty pipe buffer
      def call(_second_to_last, _last)
        +[]
      end
    end

    class GClassMethod
      # not called in the pipeline because self.call (below) takes precedence
      # but could be called with ... >> GClassMethod.new >> ...
      def call(n)
        n + 1000
      end

      # order of precedence: FunctClass.call (here),
      #                      FunctClass.new.call (as in all classes above)
      #                      FunctClass.new (as in the last class below)
      def self.call(n)
        n
      end
    end

    class HWithBlock
      def call(*args, &block)
        block.(*args, 5)
      end
    end

    I_CONSTANT = ->(*args) { +[*args] }

    class JNotFunction
      extend Forwardable
      def_delegators :@nums, :to_a
      def initialize(*args)
        @nums = args
      end
    end
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class ClassFunct
  def self.call(x, y, operator: :-)
    x.send(operator, y)
  end
end

class ParentheticalArgsTest < Minitest::Test
  include Pipeful

  def test_parenthetical_args
    assert_equal [0, 9], result
  end

  private

  def result
    +[0, 3, 12] >>
      InstanceFunct(operator: :*) >>        # here parenth. args go to initialize
                                            #     same as ".new(operator: :*).call(3, 12)
      ClassFunct(4, operator: :/) >>        # they're added on to piped arg(s) if .call is class method
                                            #     same as ".call(36, 4, operator: :/)
      Array
  end

  class InstanceFunct
    def initialize(operator: :+)
      @op = operator
    end

    def call(x, y)
      x.send(@op, y)
    end
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class ModuleNotationTest < Minitest::Test
  include Pipeful

  def test_module_notation
    assert_equal 10, result
  end

  private

  def result
    10 >>
      ContainerNormal::Funct >>
      # ContainerNormal.Funct >>  # NoMethodError
      ContainerPipeful::Funct >>
      ContainerPipeful.Funct >>
      ContainerPipefulBlock::Funct(&:itself) >>
      ContainerPipefulBlock.Funct(&:itself) >>
      # ContainerPipefulBlock::Funct { |n| n } >>  # syntax error
      ContainerPipefulBlock.Funct { |n| n }
  end

  module ContainerNormal
    class Funct
      def call(n); n; end
    end
  end

  module ContainerPipeful
    extend Pipeful
    class Funct
      def call(n); n; end
    end
  end

  module ContainerPipefulBlock
    extend Pipeful
    class Funct
      def call(n, &block); block.(n); end
    end
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class LocalModeTest < Minitest::Test
  include Pipeful

  def test_local_mode
    assert_equal 11, result
  end

  private

  def result
    funct_local = ->(n, mult:) { n * mult }
    @funct_instance = -> (n) { n + 1 }

    pipe_local do
      5 >>
        funct_local(mult: 2) >>
        @funct_instance
    end
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class MethodMissingTest < Minitest::Test
  include Pipeful

  def test_method_missing_in_instance
    assert_equal [12, 1, 2], result
  end

    def test_method_missing_in_class_method
    result = ClassFunctionMethodMissing.result
    assert_equal [12, 1, 2], result
  end

  private

  def result
    +[3, 4] >>
      ClassFunct(operator: :*) >>
      NonexistentFunct(1) >>
      nonexistent_method(2) >>
      Array
  end

  def method_missing(m, *args, **kwargs, &block)
    if m.to_s.downcase.include?("nonexistent")
      args.first
    else
      super
    end
  end

  class ClassFunctionMethodMissing
    extend Pipeful

    def self.result
      +[3, 4] >>
        ClassFunct(operator: :*) >>
        NonexistentFunct(1) >>
        nonexistent_method(2) >>
        Array
    end

    def self.method_missing(m, *args, **kwargs, &block)
      if m.to_s.downcase.include?("nonexistent")
        args.first
      else
        super
      end
    end
  end
end

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module Another
  def method_missing(m, *args, **kwargs, &block)
    super
  end
end

module YetAnother
  def method_missing(m, *args, **kwargs, &block)
    super
  end
end

class LocalModeWithMethodMissingTest < Minitest::Test
  include Pipeful
  include Another
  include YetAnother

  def test_local_mode_with_method_missing
    assert_equal [12, 100, 200], result
  end

  private

  def result
    multiply_by = ->(n, m) { n * m }

    pipe_local do
      3 >>
        multiply_by(4) >>
        NonexistentFunct(100) >>
        also_nonexistent(50) >>
        multiply_by(4) >>
        Array
    end
  end

  def method_missing(m, *args, **kwargs, &block)
    if m.to_s.downcase.include?("nonexistent")
      args.first
    else
      super
    end
  end
end



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

class ComplexNestedFunctionsTest < Minitest::Test
  include Pipeful

  def test_complex_nested_functions
    assert_equal [13, 300], result
  end

  private

  def result
    10 >> LocalParenthNested >> Array
  end

  class LocalParenthNested
    include Pipeful

    def call(n)
      multiply_by = ->(n, m) { n * m }

      non_local = n >>
        InsideLocalParenth(3, operator: :+) >>
        Nonexistent(150)

      pipe_local do
        non_local >> multiply_by(2)
      end
    end

    class InsideLocalParenth
      def self.call(a, b, operator:)
        a.send(operator, b)
      end
    end

    def method_missing(m, *args, **kwargs, &block)
      if m.to_s.downcase.include?("nonexistent")
        args.first
      else
        super
      end
    end
  end
end
