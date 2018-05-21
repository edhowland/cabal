# cabal
Small Scheme implementation in Ruby


## Abstract

In order to play around with a meta-circular evaluator, from the video series
[Structure and Interpretation of Computer Programs (SICP)](https://youtube.com)
I first had to make a Scheme interpreter in the only language I know reasonably
well: Ruby. The goal was to have a single class (or at most 3 classes)
and one that could interact well with the underlying Ruby ecosystem.

This project is that Scheme interpreter. It is not meant to actually be a robust
language interpreter for any actual use cases. It is completely experimental.

For that reason, this code is in the public domain.

## About the name

This dialect of Scheme is called Cabal in keeping with the long tradition of
naming dirivitives of Scheme  with some form of malevilant name. A Cabal is some
secret group of conspirotors.


## Requirements

- Ruby version 2.+

## Running the code

The interpreter  runs entirely in any Ruby REPL like 'irb' or 'pry'.
In fact there is a pry_helper.rb file in the root to get you started.

```
$ pry -r ./pry_helper.rb

>>repl
cabal># Ruby style comment
cabal>[:exit]
$
# back in your shell
```

Once  you see the 'cabal> ' prompt, you can type in any Scheme expression.

### Changes from Scheme proper

As you can see from the '[:exit]' example above, which invokes the
:exit builtin procedure, you have to use Ruby list and symbol syntax. In fact,
anything you type in the Cabal REPL is eKernal.eval 'd before being passed along
to the Cabal evaluator. This implies that you can type in any valid Ruby
expression and it will not syntax error. However, you might not get what you
expect from Cabal.

Here are some valid Cabal expressions:

```
cabal> 42
42
cabal> true
true
cabal> [:+, 3, 6]
9
cabal> [:define, :XI, 11]
11
cabal> :XI
11
cabal> [:*, :XI, 8]
88
cabal> [:define, :ll, [:lambda, [:y], [:/, :y, 2]]]
Lambda formal parameters: [:y]
cabal> [:ll, 666]
333
```

### Ruby interface

#### The Environment

Cabal needs an environment to evaluate its expressions against.
It extends the current Ruby binding to do this. Therefore, it has access
to all variables created in the global or local context.
This is implemented int eh class Environment.

Note, variables cannot be named with trailing suffixes like '?', or '!', so they
are handled by providing aliases to some other primitive.

E.g.

- :+ is mapped to :add
- :- => :sub
- :* => :mult
- :/ => :div

##### Predicates

- :eq? => :equal
- :null? => :is_empty
- :pair? => :is_list


#### Ruby Lambdas

Cabal primitives and special forms are implemented with normal Ruby  lambdas. In
fact, you can always supply a Ruby lambda whereever any procedure would go.

```
# There is no power method in Cabal, so lets make one
[:define, :power, ->(x, n) { x ** n}]
[:power, 2, 6]
64
```




This make easy to extend Cabal with new primitives, that might be hard to implement in Cabal itself.

#### Special forms

In Scheme, and also in Cabal, it is necessary to make some primitives obey a
different type of evaluation order. 

You can add more special forms with the following function protocol.

##### defform

The special form 'defform' allows for binding Ruby lambdas to the special forms 
storage. It takes a Ruby lambda of the form: ->(sexp, bn) { ... }
where the 'sexp' is some S-Expression and the bn is the current environment

``` :ife for if/then/else
# ife.cb - form of if/then/else
[:defform, :ife, ->(sexp,bn) {
  (_eval(sexp[0],bn) && _eval(sexp[1],bn)) || _eval(sexp[2],bn) }
]

# Now in Cabal
cabal> [:load, 'ife.cb']
# now use it
cabal> [:ife, false, 'ok', 'not ok']
'not ok'
```

