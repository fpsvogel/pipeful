# frozen_string_literal: true

require "forwardable"
# require "binding_of_caller"  # if you'll use local mode

module Pipeful
  # -----------------------------------------------------------------
  #     PIPE OPERATOR
  # -----------------------------------------------------------------

  # MONKEY PATCH WARNING: Be aware that a class/module that inherits a Pipeful class/
  # module will also be Pipeful. That is, the pipe operator will still be a pipe
  # operator, and the unary "+" operator will still turn an Array into a PipeBuffer.
  # See PIPE BUFFER and PIPE METHOD below.

  # THE REASON: I like refinements and per-object extensions, but I don't see how
  # refinements can be used for all Pipeful features, so that we can add just "using
  # Pipeful" to the top of a class/module. This is because some features rely on
  # method_missing (and therefore inheritance). We could turn all features except
  # method_missing into refinements, but then we would need to add "using Pipeful"
  # AND "extend/include Pipeful", which is cumbersome. So I'm trading the risks of
  # monkey patching for the convenience of just extending/including Pipeful.

  # if you change the operator, be sure to change the override classes and aliases as well
  pipe_operator = :>>
  operator_overrides_aliases = { Proc => :+,
                                 Integer => :rshift }

  operator_overrides_aliases.each do |op_class, op_alias|
    op_class.alias_method(op_alias, pipe_operator)
  end

  # -----------------------------------------------------------------
  #     PIPE HELPER METHODS
  # -----------------------------------------------------------------

  # an extension rather than a refinement so that it can be patched in
  # on a per-object basis rather than having to specify every class
  # that needs it (Method, UnboundMethod, and Proc at least)
  module ArityRange
    def arity_range(subtract: 0)
      min_arity = parameters.select { |type, _name| type == :req }
                            .count - subtract
      if parameters.assoc(:rest)
        max_arity = Float::INFINITY
      else
        max_arity = min_arity +
                      parameters.select { |type, _name| type == :opt }
                                .count
      end
      min_arity..max_arity
    end
  end

  module PipableObject
    refine Object do
      def pipe_target
        case pipe_type
        when :instance_function
          ->(*args, &block) { new.call(*args, &block) }
        when :function_object, :class_function
          ->(*args, &block) { call(*args, &block) }
        when :object_class
          ->(*args, &block) { new(*args, &block) }
        when :object
          nil
        end
      end

      def pipe_arity
        case pipe_type
        when :instance_function
          method = instance_method(:call)
        when :function_object, :class_function
          if is_a?(Proc)
            method = self
          else
            method = method(:call)
          end
        when :object_class
          method = instance_method(:initialize)
        when :object
          return 0..0
        end
        method.extend(ArityRange).arity_range
      end

      def pipe_type
        if methods.include?(:instance_methods)
          if methods.include?(:call)
            :class_function
          elsif instance_methods.include?(:call)
            :instance_function
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
  end

  using PipableObject

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

  class ::Array
    # unary operator to convert an Array into a PipeBuffer
    def +@
      PipeBuffer.new(*self)
    end

    # convenience to convert piped args: ... >> Array
    def self.call(*args)
      args
    end
  end

  # -----------------------------------------------------------------
  #     PIPE METHOD
  # -----------------------------------------------------------------

  ([Object] + operator_overrides_aliases.keys).each do |pipe_class|
    pipe_class.define_method(pipe_operator) do |other, &block|
      funct = other&.pipe_target
      arity = other&.pipe_arity&.max
      if funct.nil?               # other is an object without .call
        return PipeBuffer.new(self, other).unwrap?
      elsif !(is_a? PipeBuffer)   # self is single value
        if arity.zero?  # funct won't pipe self in, so self and result must be buffered
          return PipeBuffer.new(self, funct.call).unwrap?
        else            # funct will take self as argument
          return funct.call(self)
        end
      else                        # self is a pipe buffer
        if size > arity
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

  module FindConstant
    refine Module do
      def module_parent
        @module_parent ||= name =~ /::[^:]+\Z/ ? Object.const_get($`) : Object
      end

      # finds a class/constant by name contained in self or parents up to (and including) top_level
      def find_constant(name, top_level: ::Object)
        return const_get(name) if constants.include?(name)
        return nil if self == top_level
        module_parent.find_constant(name, top_level: top_level)
      end
    end
  end

  using FindConstant

  # allows parenthetical args and/or blocks after bare class/constant name: x >> SomeFunct(y) { ... }
  # or (FRAGILE! see local mode below) after callable object in local variable: x >> some_proc(y) { ... }
  def method_missing(m, *method_args, **method_kwargs, &method_block)
    pipe_next = if @pipe_local_mode
                  level = 1
                  level += 1 while binding.of_caller(level).eval("__method__") == :method_missing
                  binding.of_caller(level).eval(m.to_s)
                else
                  self_module = methods.include?(:constants) ? self : self.class
                  self_module.find_constant(m)
                end
    if pipe_next.nil?
      super
    elsif pipe_next.is_a?(Class)
      Class.new(pipe_next) do
        @parenth_args = method_args
        @parenth_kwargs = method_kwargs
        @block = method_block
        def self.parenth_arity
          @parenth_args.count
        end
        case pipe_type
        when :class_function
          def self.call(*args)
            superclass.call(*args, *@parenth_args, **@parenth_kwargs, &@block)
          end
          def self.pipe_arity
            superclass.method(:call)
                      .extend(ArityRange)
                      .arity_range(subtract: parenth_arity)
          end
        when :instance_function
          def self.call(*args)
            superclass.new(*@parenth_args, **@parenth_kwargs)
                      .call(*args, &@block)
          end
          def self.pipe_arity
            superclass.instance_method(:call)
                      .extend(ArityRange)
                      .arity_range
          end
        when :object_class
          def self.call(*args)
            superclass.new(*args, *@parenth_args, **@parenth_kwargs, &@block)
          end
          def self.pipe_arity
            superclass.instance_method(:initialize)
                      .extend(ArityRange)
                      .arity_range(subtract: parenth_arity)
          end
        end
      end
    else  # pipe_next is a callable object (in a constant, unless in local mode)
      Class.new do
        @funct_obj = pipe_next
        @parenth_args = method_args
        @parenth_kwargs = method_kwargs
        @block = method_block
        def self.parenth_arity
          @parenth_args.count
        end
        def self.call(*args)
          @funct_obj.call(*args, *@parenth_args, **@parenth_kwargs, &@block)
        end
        def self.pipe_arity
          @funct_obj.extend(ArityRange)
                    .arity_range(subtract: parenth_arity)
        end
      end
    end
  end

  # -----------------------------------------------------------------
  #     LOCAL MODE
  # -----------------------------------------------------------------

  # not recommended for production! relies on binding_of_caller gem, and iffy stack-climbing (above)
  def pipe_local(&block)
    @pipe_local_mode = true
    result = block.call
    @pipe_local_mode = false
    result
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
