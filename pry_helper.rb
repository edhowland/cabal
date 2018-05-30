# pry_helper.rb - for debugging
require_relative 'cabal'

# do initial setup - loading external *.cb files
cabal



require_relative 'repl'

def tx
  [LParen, :+, 1, LParen, :*, 4,5, RParen,RParen]
end
def tz
  [LParen, :+, 1, 2, RParen]
end
def ty
  [LParen, :+, LParen, :+, 1, 2, RParen, 6, RParen]
end

_eval [:define, :tkl, [:lambda, [], [:tokenize, [:_readline]]]]