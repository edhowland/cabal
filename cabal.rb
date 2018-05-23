# cabal.rb - small Ruby implementation of Scheme lang

require 'readline'

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
      :zero? => :is_zero, :list? => :is_list, :eq? => :equal, :pair? => :is_list,
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
  :cons => ->(a, d) {
    if d.kind_of?(Array)
      [a] + d
    else
      [a, d]
    end
  },
    :car => ->(sexp) { sexp.first },
  :cdr => ->(sexp) { f, *r = *sexp; r},
    :load => ->(s) { _eval(Kernel.eval(File.read(s))) },
    :map => ->(fn, l) { l.map {|e| _eval([fn, e]) } },
    :char_alphabetic => ->(ch) { ch.kind_of?(String) && !ch.empty? && !ch[0].match(/[a-zA-Z]/).nil? },
    :char_numeric => ->(ch) { ch.kind_of?(String) && !ch.empty? && !ch.match(/\d/).nil? },
    :read_char => ->() { $stdin.getch },
    :join => ->(l, s) { l.join(s) },
    :_print => ->(o) { $stdout.print o },
  :add => ->(a, b) { a + b },
  :sub => ->(a, b) { a - b },
  :mult => ->(a, b) { a * b},
  :div => ->(a, b) { a / b }
}.each_pair {|k,p| $env[k] = p }

$forms = {
  :quote => ->(sexp, bn) { sexp[0] },
  :define => ->(sexp, bn) { bn[sexp[0]]= _eval(sexp[1], bn) },
  :lambda => ->(sexp, bn) { Lambda.new(bn, sexp[0], sexp[1])},
  :set! => ->(sexp, bn) { bn[sexp[0]]= _eval(sexp[1], bn) },
  :eval => ->(sexp, bn) { _eval(sexp[0], bn) },
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
    _eval(@body, env)}, 
    ->() { 
      nparms = @formals[0..(args.length - 1)]
      self.class.new @environment.bind(nparms, args),  @formals[(args.length)..(-1)], @body
    },
    ->() { raise "Wrong number of arguments"}][(@formals.length <=> args.length)].call
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
    if $forms[fn]
      $forms[fn].call(obj[1..-1], bn)
    else
        apply(_eval(obj[0], bn), obj[1..-1].map { |a| _eval(a,bn) })
      end
  else
    obj
  end
end

def apply(fn, args=[])
  if args.empty?
    fn.call
  else
   args.reduce(fn.curry) {|f,j| f.call(j)}
 end
end


def read
  expr = Readline.readline
  expr.chomp unless expr.nil?
  Kernel.eval(expr)
end

# startup
def cabal
  _eval [:load, 'inspect.cb']
  _eval [:define, :print, [:lambda, [:o], [:_print, [:inspect, :o]]]]
end

def repl
  loop {
    print "cabal> "
  _ =  _eval(read)
  break if _.nil?
      _eval [:print, [:quote, _]]
      puts
  }
end
