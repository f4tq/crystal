GC.disable
require 'bundler/setup'
require 'pry'
require 'pry-debugger'
require(File.expand_path("../../lib/crystal",  __FILE__))

RSpec.configure do |c|
  c.treat_symbols_as_metadata_keys_with_true_values = true
  c.filter_run_excluding :integration
end

include Crystal

# Escaped regexp
def regex(str)
  /#{Regexp.escape(str)}/
end

def assert_type(str, options = {}, &block)
  input = parse str
  mod = infer_type input, options
  expected_type = mod.instance_eval &block
  if input.is_a?(Expressions)
    input.last.type.should eq(expected_type)
  else
    input.type.should eq(expected_type)
  end
end

def permutate_primitive_types
  [['Int', ''], ['Long', 'L'], ['Float', '.0f'], ['Double', '.0']].repeated_permutation(2) do |p1, p2|
    type1, suffix1 = p1
    type2, suffix2 = p2
    yield type1, type2, suffix1, suffix2
  end
end

def primitive_operation_type(*types)
  return double if types.include?('Double')
  return float if types.include?('Float')
  return long if types.include?('Long')
  return int if types.include?('Int')
end

def rw(name, restriction = nil)
  %Q(
  def #{name}=(value#{restriction ? " : #{restriction}" : ""})
    @#{name} = value
  end

  def #{name}
    @#{name}
  end
  )
end

# Extend some Ruby core classes to make it easier
# to create Crystal AST nodes.

class FalseClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class TrueClass
  def bool
    Crystal::BoolLiteral.new self
  end
end

class Fixnum
  def int
    Crystal::IntLiteral.new self
  end

  def long
    Crystal::LongLiteral.new self
  end

  def float
    Crystal::FloatLiteral.new self.to_f
  end

  def double
    Crystal::DoubleLiteral.new self.to_f
  end
end

class Float
  def float
    Crystal::FloatLiteral.new self
  end

  def double
    Crystal::DoubleLiteral.new self
  end
end

class String
  def var
    Crystal::Var.new self
  end

  def arg
    Crystal::Arg.new self
  end

  def call(*args)
    Crystal::Call.new nil, self, args
  end

  def ident
    Crystal::Ident.new [self]
  end

  def instance_var
    Crystal::InstanceVar.new self
  end

  def string
    Crystal::StringLiteral.new self
  end

  def symbol
    Crystal::SymbolLiteral.new self
  end

  def object(instance_vars = {})
    Crystal::ObjectType.new(self).with_vars(instance_vars)
  end

  def struct(instance_vars = {})
    ivars = instance_vars.map { |name, type| Var.new(name.to_s, type) }
    Crystal::StructType.new(self, ivars)
  end

  def generic(type_vars)
    @generic = true
    object.of(type_vars)
  end

  def hierarchy
    object.hierarchy_type
  end
end

class Array
  def ident
    Ident.new self
  end

  def array
    Crystal::ArrayLiteral.new self
  end

  def array_of(type)
    Crystal::ArrayLiteral.new self, type
  end
end

class Crystal::ObjectType
  def with_var(name, type)
    name = name.to_s
    name = "@#{name}" unless name[0] == '@'
    @instance_vars[name] = Var.new(name, type)
    self
  end

  def with_vars(hash)
    hash.each do |name, type|
      with_var name, type
    end
    self
  end

  def of(type_vars)
    @type_vars = Hash[type_vars.map { |name, type| [name.to_s, Var.new(name.to_s, type)] }]
    self
  end
end

class Crystal::ASTNode
  def not
    Call.new(self, :"!@")
  end
end