# frozen_string_literal: true

require "forwardable"
# require "binding_of_caller"  # if you'll use eval mode

module Pipeful
  # -----------------------------------------------------------------
  #     PIPE OPERATOR
  # -----------------------------------------------------------------

  # if you change the operator, be sure to change the override classes and aliases as well
  pipe_operator = :>>
  operator_overrides_aliases = { Proc => :+,
                                 Integer => :rshift }

  operator_overrides_aliases.each do |op_class, op_alias|
    op_class.alias_method(op_alias, pipe_operator)
  end

  # -----------------------------------------------------------------
  #     METHOD AND OBJECT MONKEYPATCHING
  # -----------------------------------------------------------------

  with_arity = [Method, UnboundMethod, Proc]

  class ::Method
    def self.arity_range(method, subtract: 0)
      parameters = method.parameters
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

  with_arity.each do |methodlike|
    methodlike.define_method(:arity_range) do |subtract: 0|
      Method.arity_range(self, subtract: subtract)
    end
  end

  class ::Object
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
      method.arity_range
    end

    protected

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

    def self.call(*args)
      args
    end
  end

  # -----------------------------------------------------------------
  #     Object#>> (THE PIPE METHOD)
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
  #     DEFINE METHODS FOR FUNCTIONS (to allow parenthetical args and blocks)
  # -----------------------------------------------------------------

  def self.function_method_proc(const = nil,
                                eval_self: nil,
                                orig_method_missing: nil)
    proc do |*method_args, **method_kwargs, &method_block|
      # if in eval mode and a previously defined method_missing has been overridden,
      # it must be put back in place temporarily to avoid an infinite method_missing loop due to eval
      if eval_self
        method_m = method_args.shift.to_s
        if orig_method_missing
          eval_method_missing = method(:method_missing)
          # orig_method_missing is added indirectly here because the bare method_m (without args)
          # is tried in case it is a local variable. if that fails, it goes to this second version
          # of method_missing, which is an intermediate stage where the args are added back in to
          # a call to the original method_missing
          eval_self.define_singleton_method(:method_missing) do |m, *_args, **_kwargs, &_block|
            eval_self.define_singleton_method(:method_missing, orig_method_missing)
            eval_self.send(:method_missing, m, *method_args, **method_kwargs, &method_block)
          end
        end
        begin
          funct = binding.of_caller(1).eval(method_m)
        rescue NameError  # happens for constant- or class-style names like NonexistentFunct
          funct = binding.of_caller(1).eval("#{method_m}()")
        end
        if orig_method_missing
          eval_self.define_singleton_method(:method_missing, eval_method_missing)
        end
      else
        funct = const
      end
      if funct.is_a?(Class)
        Class.new(funct) do
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
              superclass.method(:call).arity_range(subtract: parenth_arity)
            end
          when :instance_function
            def self.call(*args)
              superclass.new(*@parenth_args, **@parenth_kwargs).call(*args, &@block)
            end
            def self.pipe_arity
              superclass.instance_method(:call).arity_range(subtract: parenth_arity)
            end
          when :object_class
            def self.call(*args)
              superclass.new(*args, *@parenth_args, **@parenth_kwargs, &@block)
            end
            def self.pipe_arity
              superclass.instance_method(:initialize).arity_range(subtract: parenth_arity)
            end
          end
        end
      elsif funct.methods.include?(:call)  # funct is a callable object (in a constant, unless in eval mode)
        Class.new do
          @funct_obj = funct
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
            @funct_obj.arity_range(subtract: parenth_arity)
          end
        end
      else  # in eval mode, if funct resolves to a non-callable object
        funct
      end
    end
  end

  class ::Module
    def module_parent
      @module_parent ||= name =~ /::[^:]+\Z/ ? Object.const_get($`) : Object
    end

    # all classes/constants contained in parents up to (and including) top_level
    def all_constants(top_level = Object::Object)
      self_class = methods.include?(:constants) ? self : self.class
      consts_hash = ->(parent) { parent.constants.map { |name| [name, parent.const_get(name)] }.to_h }
      all_consts = {}
      loop do
        all_consts.merge!(consts_hash.call(self_class))
        break if self_class == top_level
        self_class = self_class.module_parent
      end
      all_consts
    end

    def all_pipable_constants
      all_constants.select do |_name, const|
        const.is_a?(Class) || const.methods.include?(:call)
      end
    end
  end

  def self.add_function_methods(obj, mode)
    obj.all_pipable_constants.each do |name, const|
      next if obj.methods.include?(name)
      method_type = { extended: :define_singleton_method,
                      included: :define_method }[mode]
      method_proc = function_method_proc(const)
      obj.send(method_type, name, method_proc)
    end
  end

  def self.at_end(obj, &block)
    # from https://stackoverflow.com/questions/32233860/how-can-i-set-a-hook-to-run-code-at-the-end-of-a-ruby-class-definition
    TracePoint.trace(:end) do |t|
      if obj == t.self
        block.call(obj)
        t.disable
      end
    end
  end

  def self.extended(obj)
    at_end(obj) { |o| add_function_methods(o, :extended) }
  end

  def self.included(obj)
    at_end(obj) { |o| add_function_methods(o, :included) }
  end

  # -----------------------------------------------------------------
  #     EVAL MODE
  # -----------------------------------------------------------------

  # not recommended for production!
  # relies on binding_of_caller gem, and metaprogramming sorcery
  def pipe_eval(&pipeline)
    orig_method_missing = method(:method_missing) if methods.include?(:method_missing)
    eval_method_missing = Pipeful.function_method_proc(orig_method_missing: orig_method_missing,
                                                       eval_self: self)
    define_singleton_method(:method_missing, eval_method_missing)
    result = pipeline.call
    if orig_method_missing
      define_singleton_method(:method_missing, orig_method_missing)
    else
      singleton_class.undef_method(:method_missing)
    end
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
