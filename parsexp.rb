# parsexp.rb - parse S-Expressions from tokenized stream
def unmatch stream
  [false, stream]
end
def plparen stream
  if stream[0] == LParen
    [true, stream[1..-1]]
  else
    unmatch stream
  end
end

def prparen stream
  if stream[0] == RParen
    [true, stream[1..-1]]
  else
    unmatch stream
  end
  #
end

def not_rparen stream, result=[]
  if stream[0] == RParen
    [result, stream]
      elsif stream.empty?
        [false, stream]
  else
    result << stream[0]
    not_rparen stream[1..-1], result
  end
end

def parse_list stream
  r, s = plparen stream
  return unmatch(stream) if !r
  result, s = not_rparen s
  return unmatch(stream) if result == false
  r, s = prparen s
  return unmatch(stream) if !r
  [result, s]
end

def parse_atom stream
  return unmatch(stream) if (stream.first == LParen or stream.first == RParen)
  [stream.first, stream[1..-1]]
end
  
  def parse_sexp stream
    r, s = parse_list stream
    if !r
      r, s = parse_atom(stream)
    end
    [r, s]
  end
  