# frozen_string_literal: true

require_relative "test_helper"
require "binding_of_caller"  # for eval mode (experimental) for using functions in local scope

class PipefulTest < Minitest::Test
  module Pipelines
    extend Pipeful

    def self.basic
      100 >>
        ASimple >>           # == 110
        BNested >>           # == 121
        CNoCallParams >>     # == +[121, 10] (unary "+" means "this is a pipe buffer, not a normal array")
        DPushResults >>      # == +[121, 10, 20, 30]
        EPopArgs >>          # == +[121, 10, 50]
        FNoReturn >>         # == 121
        GClassMethod >>      # == 121
        HWithBlock do |n1, n2|
          +[n1, n2] >>       # == +[121, 5]; could also be n1 >> n2 >>
            IConstant >>     # == +[121, 5]
            JNotFunction     # == JNotFunction object containing [121, 5]
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

    IConstant = ->(*args) { +[*args] }

    class JNotFunction
      extend Forwardable
      def_delegators :@nums, :to_a
      def initialize(*args)
        @nums = args
      end
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    def self.parenthetical_args
      +[3, 12] >>
        InstanceMethodGrow(operator: :*) >>   # parenth. args go to initialize
                                              #   same as ".new(operator: :*).call(3, 12)
        ClassMethodShrink(4, operator: :/)    # or added to pipe arg(s) if .call is class method
                                              #   same as ".call(36, 4, operator: :/)
    end

    class InstanceMethodGrow
      OPERATORS = %i[+ * **]

      def initialize(operator: :+)
        raise ArgumentError unless OPERATORS.include?(operator)
        @op = operator
      end

      def call(x, y)
        x.send(@op, y)
      end
    end

    class ClassMethodShrink
      OPERATORS = %i[- /]

      def self.call(x, y, operator: :-)
        raise ArgumentError unless OPERATORS.include?(operator)
        x.send(operator, y)
      end
    end

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    def self.module_notation
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

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    def self.eval_mode
      funct_local = ->(n) { n * 2 }
      @funct_instance = -> (n) { n + 1 }

      Pipeful.eval_mode do
        5 >>
          funct_local >>
          @funct_instance
      end
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  def test_basic
    assert_equal [121, 5], Pipelines.basic.to_a
  end

  def test_parenthetical_args
    assert_equal 9, Pipelines.parenthetical_args
  end

  def test_module_notation
    assert_equal 10, Pipelines.module_notation
  end

  def test_eval_mode
    assert_equal 11, Pipelines.eval_mode
  end

  def test_that_it_has_a_version_number
    refute_nil ::Pipeful::VERSION
  end
end
