class Integer alias truthy? nonzero? end
class String def truthy? = !empty? end

class Princess
  LEFT = -1
  RIGHT = 1
  UP = -1i
  DOWN = 1i
  FUNCTIONS = {
    '-' => ->{},
    '|' => ->{},
    '@' => ->{ push @stack.last },
    '$' => ->{ push @stack[-2] },
    'A' => ->{ @dir = @dir + @dir/@dir.magnitude },
    'C' => ->{ push pop.chr },
    ':' => ->{ a = pop; b = pop; push a; push b; },
    '>' => ->{ @dir = RIGHT },
    '<' => ->{ @dir = LEFT },
    '^' => ->{ @dir = UP },
    'v' => ->{ @dir = DOWN },
    '=' => ->{ push (pop == pop ? 1 : 0) },
    '!' => ->{ push pop.truthy? ? 0 : 1 },
    'N' => ->{ self[update_position.tap { @dir = 0 }] },
    '+' => ->{ push pop(-2) + pop },
    '_' => ->{ push pop(-2) - pop },
    '*' => ->{ push pop(-2) * pop },
    '/' => ->{ push pop(-2) / pop },
    '%' => ->{ push pop(-2) % pop },
    '?' => ->{ @dir *= 1i unless pop.truthy? },
    'I' => ->{ @dir *= -1i unless pop.truthy? },
    '.' => ->{ print pop },
    ',' => ->{ puts pop },
    'Q' => ->{ exit pop.to_i },
    'i' => ->{ push gets.chomp },
    'D' => ->{ p self; $stdout.flush; exit },
    'd' => ->{ p self;$stdout.flush },
    'L' => ->{ @dir = @dir.real * -1i },
    # 'R' => ->{ @dir = @dir.real * 1i },
    'R' => ->{ @dir *= 1i },
  }
  def initialize(board, stack: [], dir: RIGHT, pos: 0)
    @board = board.lines.map(&:chomp)
    @dir = dir
    @pos = pos
    @stack = stack 
  end

  def set_velocity_maybe_increase(dir)
    if @dir.imag.negative? && dir.imag.negative? \
    || @dir.imag.positive? && dir.imag.positive? \
    || @dir.real.negative? && dir.real.negative? \
    || @dir.real.positive? && dir.real.positive?
    then 
      @dir += dir
    else @dir = dir end
  end

  def pop(n=-1) = @stack.delete_at(n)
  def push(m) = @stack.push(m)
  def run(x)
    instance_exec(&FUNCTIONS[x])
  end

  def [](pos)
    @board[pos.imag][pos.real]
  end

  def step! = @pos += @dir
  def next! = self[step!]

  def play
    @pos -= @dir
    loop do
      case (func = next!)
      when /\d/ then push $&.to_i
        # acc = $&
        # while (tmp = next!) =~ /\d/
        #   acc << $&
        # end
        # @pos -= @dir
        # push acc.to_i
      when '"'
        acc = ''
        while (tmp = next!) != '"'
          acc << tmp
        end
        push acc
      else
        instance_exec(&(FUNCTIONS[func] or abort"bad function: #{func.inspect} (#@dir)"))
      end
    rescue
      warn "#@pos"
      raise
    end
  end
end


Princess.new(<<EOS, stack: [10]).play
vv
35
>>>""FBuizzzz""..0Q
EOS


Princess.new(<<EOS, stack: [10]).play
1:>@?:$-:1_v
  | >:.0Q  |
  ^--------<
EOS
__END__
Princess.new(<<EOS, stack: [100]).play
"Hello, world".0Q
EOS
Princess.new(<<EOS, stack: [100]).play
1v-----------------<
 >$$=?0Q           |
     >@3%!?"Fizz".v|
v-------< >--v----<|
v."zzuB"?!%5@<     |
>@3%$5%*?@.1?1+"",-^
^       >--0^
EOS

__END__
iN
# - dup nth 
<>^v set direction to thatl if already moving that way, increase velocity by 1.
= - check if equal
-| - do nothing
R/L - move forward one, then reset velocity to 1 in 90º right/left
N - set velocity to whatever the next one is.
?/I - if truthy, continue same direction, otherwise, go 90º right/left
    v------------<
    |        v---|<
fizzbuzz(m)-1$$=?^|
   >v."zziF"I%3@< |
   ^|<------<     |
    >@5%?"Buzz".v<|
        >------>|^|
      v.I*%3$%5@< |
      >N>"\n".1+--^
