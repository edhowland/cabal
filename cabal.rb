# cabal.rb - small Ruby implementation of Scheme lang

require 'readline'
require_relative 'tokenizer'
require_relative 'parsexp'


# exceptions
class CabalError < RuntimeError; end

# Tokens
#LParen = 0xfffffffe
#RParen = 0xfffffffd


# helper funcs
def safe_send obj, msg, *args
  obj.respond_to?(msg) && obj.send(msg, *args)
end

# fcond clauses list - implements :cond on lists
def fcond(cl, bn)
  if cl.empty?
    []
  elsif cl[0][0] == :else
      _eval(cl[0][1], bn)
  else
    (_eval(cl[0][0], bn) && _eval(cl[0][1], bn)) || fcond(cl[1..-1], bn)
  end
end

# main classes
class Environment
  def initialize bn=binding
    @binding = bn
    @binding.local_variable_set(:null, [])
    @aliases = {:+ => :add, :- => :sub, :* => :mult, :/ => :div, :null? => :is_empty,
      :zero? => :is_zero, :list? => :is_list, :eq? => :equal, :eql? => :equal_equal, :pair? => :is_list,
      :boolean? => :is_bool, :symbol? => :is_symbol, :procedure? => :is_lambda,
      "char-alphatic?".to_sym => :char_alphabetic, "char-numeric?".to_sym => :char_numeric}

  end
  attr_reader :binding
  attr_accessor :aliases
  def [](k)
    temp = @aliases[k] || k
    @binding.local_variable_get(temp)
  end
  def []=(k, v)
    @binding.local_variable_set(k, v)
  end
  def dup(&blk)
    result = self.class.new @binding.dup
    yield result if block_given?
    result
  end
  # bind a list of values to symbols in new environment
  def bind(syms=[], values=[])
    self.dup do |bn|
    syms.zip(values).reject {|k,v| v.nil? }.each {|k, v| bn[k] = v }
    end
  end
  def inspect
    "#{self.class.name} alaiases count: #{@aliases.keys.length}"
  end
end

$env=Environment.new(binding)

{
  :exit => ->() { exit },
  :is_bool => ->(o) { o.class == TrueClass or o.class == FalseClass },
  :b_to_s => ->(o) { "##{o.to_s[0]}" },
  :is_symbol => ->(o) { o.kind_of?(Symbol) },
  :is_lambda => ->(l) { l.kind_of?(Lambda) or l.kind_of?(Proc) },
  :to_s => ->(o) { o.to_s },
  :_inspect => ->(o) { o.inspect },
  :is_list => ->(o) { safe_send(o, :kind_of?, Array) },
  :is_empty => ->(l) { safe_send(l, :empty?) },
  :is_zero => ->(o) { safe_send(o, :zero?) },
  :not => ->(o) { ! o },
  :equal => ->(a, b) { a.equal? b },
  :equal_equal => ->(a, b) { a == b },
  :cons => ->(a, d) {
    if d.kind_of?(Array)
      [a] + d
    else
      [a, d]
    end
  },
    :car => ->(sexp) { sexp.first },
  :cdr => ->(sexp) { f, *r = *sexp; r},
    :loadr => ->(s) { _eval(Kernel.eval(File.read(s))) },
    :display => ->(o) { $stdout.puts(o) },
    :mksym => ->(o) { o.to_sym },
    :str_chars => ->(s) { s.chars },
    :mkint => ->(o) { o.to_i },
  :eval => ->(sexp) { _eval(sexp) },
  :force => ->(exp) { apply(exp, []) },
  :eval_seq => ->(seq) { _eval_seq(seq) },
    :map => ->(fn, l) { l.map {|e| _eval([fn, e]) } },
    :foldr => ->(p, i, l) { l.reduce(i) {|x,j| apply(p, [x, j]) }},
    :char_whitespace => ->(ch) { ch.kind_of?(String) && !ch.empty? && !ch.match(/\s/).nil? },
    :char_alphabetic => ->(ch) { ch.kind_of?(String) && !ch.empty? && !ch[0].match(/[a-zA-Z\+\-\*\/]/).nil? },
    :char_numeric => ->(ch) { ch.kind_of?(String) && !ch.empty? && !ch.match(/\d/).nil? },
    :read_char => ->() { $stdin.getch },
    :join => ->(l, s) { l.join(s) },
    :_print => ->(o) { $stdout.print(o); $stdout.puts },
    :error => ->(s) { raise CabalError.new(s) },
  :add => ->(a, b) { a + b },
  :sub => ->(a, b) { a - b },
  :mult => ->(a, b) { a * b},
  :div => ->(a, b) { a / b }
}.each_pair {|k,p| $env[k] = p }

$forms = {
  :quote => ->(sexp, bn) { sexp[0] },
  :define => ->(sexp, bn) { bn[sexp[0]]= _eval(sexp[1], bn) },
  :lambda => ->(sexp, bn) { Lambda.new(bn, sexp[0], sexp[1..-1])},
  :set! => ->(sexp, bn) { bn[sexp[0]]= _eval(sexp[1], bn) },
  :cond => ->(sexp, bn) {
    fcond(sexp, bn)
},
:defform => ->(sexp, bn) { $forms[sexp[0]] = sexp[1] },
:or => ->(sexp, bn) { 
    if sexp.nil? or sexp.empty?
      false
    else
      _eval(sexp[0], bn) || _eval([:or, *sexp[1..-1]], bn)
    end
  },
  :and => ->(sexp, bn) { 
  if sexp.nil? or sexp.empty?
      true
  else
      if sexp[1].nil?
        _eval(sexp[0], bn)
      else
        _eval(sexp[0], bn) && _eval([:and, *sexp[1..-1]], bn)
      end
end
},
:delay => ->(sexp, bn) { _eval([:lambda, [], sexp[0]]) },
:let => ->(sexp, bn) {
    binds = sexp[0]
    body = sexp[1]
    vars = binds.map(&:first)
    exprs = binds.map(&:last)
    _eval [[:lambda, vars, body], *exprs], bn
}
}

class Lambda
# A Lambda consists of the environment:binding, the formal parameters and the body.
  def initialize environment, formals, body 
    @environment = environment
    @formals = formals
    @body = body
  end
  attr_reader :environment, :formals, :body
  # curry args, returns new Lambda if args less than formals
  def curry
    self
  end
  def arity
    @formals.length
  end

  def remains(enum)
    result = []
    loop do
      result << enum.next
    end
    result
  end
  def bind(args)
    bn = @binding.dup
    p = @formals.each
    args.each { |a| bn[p.next] = a }
    [bn, remains(p)]
  end
  def call(*args)
    [->() {
      env = @environment.bind(@formals, args)
    _eval_seq(@body, env)}, 
    ->() { 
      nparms = @formals[0..(args.length - 1)]
      self.class.new @environment.bind(nparms, args),  @formals[(args.length)..(-1)], @body
    },
    ->() { raise CabalError.new "Wrong number of arguments"}][(@formals.length <=> args.length)].call
  end
  def inspect
    "#{self.class.name} formal parameters: #{@formals}"
  end
end

def _eval(obj, bn=$env)
  case obj
  when Symbol
      bn[obj]
  when Array
  fn = obj[0]
  raise CabalError.new "Missing procedure for procedure application" if fn.nil?
    if $forms[fn]
      $forms[fn].call(obj[1..-1], bn)
    else
        apply(_eval(obj[0], bn), obj[1..-1].map { |a| _eval(a,bn) })
      end
  else
    obj
  end
end
def _eval_seq(seq, env=$env)
     result=nil
  seq.each {|e| result=_eval(e, env)}
  result 
end

def apply(fn, args=[])
  if args.empty?
    fn.call
  else
   args[0..(fn.arity-1)].reduce(fn.curry) {|f,j| f.call(j)}
 end
end


def read
  expr = Readline.readline
  expr.chomp unless expr.nil?
  Kernel.eval(expr)
end

# startup
def cabal
  _eval [:define, :tokenize, ->(a) { to_tokens(a) }]
  _eval [:define, :fread, ->(fname) { File.read(fname) }]
  _eval [:define, :load, [:lambda, [:fname],
    [:eval_seq, [:read, [:tokenize, [:str_chars, [:fread, :fname]]]]
  ]]]
  _eval [:loadr, 'inspect.cbr']
  _eval [:define, :print, [:lambda, [:o], [:_print, [:inspect, :o]]]]
  _eval [:define, :_readline, ->() { Readline.readline.chomp.chars }]
_eval [:define, :read, ->(array) { 
  r, s = parse_sexp(array)
  result = [r]
  until s.empty?
    r, s = parse_sexp(s)
    result << r
    end
  result
  }] 
  _eval [:define, :rep, [:lambda, [], [:print, [:eval_seq, [:read, [:tokenize, [:_readline]]]]]]]
end

def xrepl
  loop {
    print "cabal> "
  _ =  _eval(read)
  break if _.nil?
      _eval [:print, [:quote, _]]
      puts
  }
end
