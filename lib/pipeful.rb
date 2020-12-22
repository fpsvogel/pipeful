# frozen_string_literal: true

require "forwardable"
# require "binding_of_caller"  # if you'll use eval mode

module Pipeful
  # -----------------------------------------------------------------
  #     PIPE OPERATOR
  # -----------------------------------------------------------------

  # if you change the operator, be sure to alias previous methods (see below) and change pipe_overrides
  pipe_operator = :>>
  pipe_overrides = [Integer, Proc]

  # make proc composition still usable
  class Object::Proc
    alias + >>
  end

  # make right bitwise shift still usable
  class Object::Integer
    alias rshift >>
  end

  # -----------------------------------------------------------------
  #     PIPE MODE
  # -----------------------------------------------------------------

  @pipe_mode = :constants
  @all_modes = %i[constants eval]

  def self.pipe_mode
    @pipe_mode
  end

  def self.pipe_mode=(mode)
    raise ArgumentError unless @all_modes.include?(mode)
    @pipe_mode = mode
  end

  # relies on binding_of_caller gem, not recommended for production
  def self.eval_mode(&pipeline)
    self.pipe_mode = :eval
    result = pipeline.call
    self.pipe_mode = :constants
    result
  end

  # -----------------------------------------------------------------
  #     OBJECT MONKEYPATCHING
  # -----------------------------------------------------------------

  class Object::Object
    def pipe_target
      case pipe_type
      when :function_class
        ->(*args, &block) { new.call(*args, &block) }
      when :function_object, :class_function_class
        ->(*args, &block) { call(*args, &block) }
      when :object_class
        ->(*args, &block) { new(*args, &block) }
      when :object
        nil
      end
    end

    def pipe_arity
      case pipe_type
      when :function_class
        instance_method(:call).arity
      when :function_object, :class_function_class
        if is_a?(Proc)
          arity
        else
          method(:call).arity
        end
      when :object_class
        instance_method(:initialize).arity
      when :object
        0
      end
    end

    protected

    def pipe_type
      if methods.include?(:instance_methods)
        if methods.include?(:call)
          :class_function_class
        elsif instance_methods.include?(:call)
          :function_class
        else
          :object_class
        end
      elsif methods.include?(:call)
        :function_object
      else
        :object
      end
    end
  end

  # -----------------------------------------------------------------
  #     PIPE BUFFER
  # -----------------------------------------------------------------

  class PipeBuffer
    extend Forwardable
    def_delegators :@array, :size, :slice, :to_a, :first

    def initialize(*els)
      @array = debuffer(els)
    end

    def to_s
      "+#{@array}"
    end

    # used by Object#>> when returning a pipe buffer
    def unwrap?
      return first if size == 1
      self
    end

    def self.unwrap?(buffer)
      return buffer unless buffer.is_a?(PipeBuffer)
      buffer.unwrap?
    end

    private

    # prevents nested pipe buffer (but checks only one level deep)
    def debuffer(arr)
      arr.map do |el|
        el.is_a?(PipeBuffer) ? [*el] : [el]
      end.flatten(1)
    end
  end

  # unary operator to convert an Array into a PipeBuffer
  class Object::Array
    def +@
      PipeBuffer.new(*self)
    end
  end

  # -----------------------------------------------------------------
  #     Object#>> THE PIPE MECHANISM
  # -----------------------------------------------------------------

  ([Object] + pipe_overrides).each do |pipe_class|
    pipe_class.define_method(pipe_operator) do |other, &block|
      funct = other.pipe_target
      arity = other.pipe_arity
      if funct.nil?               # other is an object without .call
        return PipeBuffer.new(self, other).unwrap?
      elsif !(is_a? PipeBuffer)   # self is single value
        if arity.zero?  # funct won't pipe self in, so self and result must be buffered
          return PipeBuffer.new(self, funct.call).unwrap?
        else            # funct will take self as argument
          return funct.call(self)
        end
      else                        # self is a pipe buffer
        if arity.between?(0, size)
          pop_args = slice(-arity, arity)
          leftover = slice(0, size - arity)
        else
          pop_args = slice(0, size)
          leftover = []
        end
        result = funct.call(*pop_args, &block)
        if leftover.empty?  # all pipe args were passed into funct
          return PipeBuffer.unwrap?(result)
        else                # one or more args remain in the pipeline
          return PipeBuffer.new(*leftover, result).unwrap?
        end
      end
    end
  end

  # -----------------------------------------------------------------
  #     PARENTHETICAL ARGUMENTS TO FUNCTIONS VIA method_missing
  # -----------------------------------------------------------------

  class Object::Module
    def module_parent
      @module_parent ||= name =~ /::[^:]+\Z/ ? Object.const_get($`) : Object
    end
  end

  # all classes/constants contained in parents up to (but not including) Object
  def all_pipe_constants
    self_class = methods.include?(:constants) ? self : self.class
    consts_hash = ->(parent) { parent.constants.map { |name| [name, parent.const_get(name)] }.to_h }
    all_consts = {}
    loop do
      all_consts.merge!(consts_hash.call(self_class))
      self_class = self_class.module_parent
      break if self_class == Object::Object
    end
    all_consts
  end

  # allows parenthetical args and/or blocks after bare class/constant name: x >> SomeFunct(y) { ... }
  # or (FRAGILE! see below) after local variable holding a callable object: x >> some_proc(y) { ... }
  def method_missing(m, *missing_args, **missing_kwargs, &block)
    pipe_item = case Pipeful.pipe_mode
                when :constants
                  all_pipe_constants[m]
                when :eval
                  binding.of_caller(1).eval(m.to_s)
                end
    if pipe_item.nil?
      super
    elsif pipe_item.is_a?(Class)
      Class.new(pipe_item) do
        @piped_args = missing_args
        @piped_kwargs = missing_kwargs
        @piped_block = block
        case pipe_type
        when :class_function_class
          def self.call(*args)
            superclass.call(*args, *@piped_args, **@piped_kwargs, &@piped_block)
          end
          def self.pipe_arity
            superclass.method(:call).arity
          end
        when :function_class
          def self.call(*args)
            superclass.new(*@piped_args, **@piped_kwargs).call(*args, &@piped_block)
          end
          def self.pipe_arity
            superclass.instance_method(:call).arity
          end
        when :object_class
          def self.call(*args)
            superclass.new(*args, *@piped_args, **@piped_kwargs, &@piped_block)
          end
          def self.pipe_arity
            superclass.instance_method(:initialize).arity
          end
        end
      end
    else  # pipe_item is a callable object (in a constant, unless Pipeful.pipe_mode == :eval)
      Class.new do
        @piped_object = pipe_item
        @piped_block = block
        def self.call(*args)
          @piped_object.call(*args, *@piped_args, **@piped_kwargs, &@piped_block)
        end
        def self.pipe_arity
          @piped_object.arity
        end
      end
    end
  end

  def respond_to_missing?(m, *_args)
    constants.include?(m)  # also local variables if eval mode enabled, but only constants are reflected here
  end

  # DEPRECATED, now using binding_of_caller gem instead
  # # EXPERIMENTAL! for finding local variable in method_missing
  # # it allows this to work: ... >> c { |n| n * 2 } >> ...
  # # where c is a variable holding a callable object whose .call takes argument(s) and a block
  # # from https://stackoverflow.com/questions/1314592/how-can-i-get-the-binding-from-method-missing
  # TRACE_STACK = []
  # def first_with_variables
  #   # this is the part I'm not sure about: where in TRACE_STACK will the desired binding consistently be found?
  #   TRACE_STACK.find { |item| !item[:binding].local_variables.empty? }
  # end
  # def caller_binding
  #   first_with_variables[:binding]
  # end
  # set_trace_func(lambda do |event, file, line, id, binding, classname|
  #   item = {:event=>event,:file=>file,:line=>line,:id=>id,:binding=>binding,:classname=>classname}
  #   case(event)
  #   when "line"
  #     TRACE_STACK.push(item) if TRACE_STACK.empty?
  #   when /\b(?:(?:c-)?call|class)\b/
  #     TRACE_STACK.push(item)
  #   when /\b(?:(?:c-)?return|end|raise)\b/
  #     TRACE_STACK.pop
  #   end
  # end)
end
