# repl.rb - REPL in Cabal but meant to be required in cabal.rb
_eval [:define, :loop, ->(sexp) { loop { _eval(sexp) } }]

_eval [:define, :repl, [:lambda, [],
  [:loop, [:print, [:eval, [:read, [:tokenize, [:_readline]]]]]]
  ]
  ]
  