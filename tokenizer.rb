# tokenize.rb
def get_number(enum, result='')
  if enum.peek.match /\d/
    result << enum.next
    get_number(enum, result)
  else
    result.strip.to_i
  end
end


class LParen; end
class RParen; end
def to_tokens ary
  result = []
  e = ary.each
    loop do
    if e.peek.match /\s/
      # ignore whitespace
      e.next
    elsif e.peek == '('
    e.next
    result << LParen
  elsif e.peek == ')'
    result << RParen
    e.next
  elsif e.peek.match /\d/
    result << get_number(e)
  else
    result << :error
    e.next
  end
  end
  result
end
