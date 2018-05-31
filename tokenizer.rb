# tokenize.rb
def get_symbol(enum, result='')
  begin
    if enum.peek.match /[^\d\s\(\)]/
    result << enum.next
    get_symbol(enum, result)
        else
    result.strip.to_sym
      end
        rescue StopIteration
    result.strip.to_sym
  end
end
def get_number(enum, result='')
  begin
  if enum.peek.match /\d/
    result << enum.next
    get_number(enum, result)
  else
    result.strip.to_i
  end
  rescue StopIteration
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
  elsif e.peek == '#'
    e.next
    if e.next == 't'
      result << true
    else
      result << false
    end
  elsif e.peek.match /\d/
    result << get_number(e)
  elsif e.peek.match /[^\d\s\(\)]/
    result << get_symbol(e)
  else
    result << :error
    e.next
  end
  end
  result
end
