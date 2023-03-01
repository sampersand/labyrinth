class FalseClass def to_i = 0 end
class TrueClass def to_i = 1 end

def truthy?(ele) = !ele.zero? rescue !ele.empty?

class Princess
  LEFT = -1
  RIGHT = 1
  UP = -1i
  DOWN = 1i

  FUNCTIONS = {
    # Stack manipulation
    '.' => ->{ dupn 1 }, # DUP
    ',' => ->{ popn 1 }, # POP
    ':' => ->{ dupn 2 }, # dup2
    ';' => ->{ popn 2 }, # pop2
    '#' => ->n{ dupn n.to_i }, # dup the nth element
    '@' => ->n{ popn n.to_i }, # pop the nth element
    '$' => ->{ push pop2 }, # Swap

    # Directions
    '-' => ->{},
    '|' => ->{},
    '>' => ->{ @velocity = RIGHT },
    '<' => ->{ @velocity = LEFT  },
    '^' => ->{ @velocity = UP },
    'v' => ->{ @velocity = DOWN },
    '{' => ->{ @velocity += direction },
    '}' => ->{ @velocity -= direction },
    'C' => ->{ @jumpstack << [@position, @velocity] },
    'R' => ->{
      p, v = @jumpstack.pop
      @velocity = v
      @position = p - @velocity
    },

    # Math
    '+' => ->b,a{ push a + b },
    '_' => ->b,a{ push a - b }, # `-` is already used
    '*' => ->b,a{ push a * b },
    '/' => ->b,a{ push a / b },
    '%' => ->b,a{ push a % b },

    # Comparisons
    '=' => ->b,a{ push (a  == b).to_i },
    'l' => ->b,a{ push (a  <  b).to_i },
    'g' => ->b,a{ push (a  >  b).to_i },
    'c' => ->b,a{ push (a <=> b).to_i },
    '!' => ->a{ push truthy?(a).!.to_i },

    # String <-> Int functions
    'a' => ->c{ push c.then{_1.is_a?(String) ? _1.ord : _1.chr} },
    's' => ->x{ push x.to_s },
    'i' => ->x{ push x.to_i },
    'G' => ->l,i,s{ push s[i.to_i, l.to_i]},
    'S' => ->r,l,i,s{ s[i.to_i, l.to_i] = r.to_s },
    '[' => ->{ push [] }
    ']' => ->{ push Array.new n, 0 }


    # Conditionals
    '?' => ->c{ @velocity *= DOWN unless truthy? c },
    'I' => ->c{ @velocity *= UP  unless truthy? c },
    'T' => ->c{ pop unless truthy? c },

    # I/O
    'P' => ->s{ print s, "\n" },
    'p' => ->s{ print s },
    'D' => ->{ p self; $stdout.flush; exit },
    'd' => ->{ p self; $stdout.flush },
    'Q' => ->{ exit },
    'q' => ->c{ exit c.to_i },
    'U' => ->{ push gets.chomp },
  }

  def dupn(idx) = @stack.push(@stack[-idx])
  def popn(idx) = @stack.delete_at(-idx)
  def push(ele) = @stack.push(ele)
  def pop  = popn(1)
  def pop2 = popn(2)

  def initialize(board, stack: [], velocity: RIGHT, position: 0)
    @board = board.lines.map(&:chomp)
    @velocity, @position, @stack = velocity, position, stack
    @jumpstack = []
  end
  def inspect = "Princess(position=#@position, velocity=#@velocity, stack=#@stack)"
  def direction = @velocity / @velocity.magnitude

  def [](pos) = @board[pos.imag][pos.real]
  def run(name)
    function = FUNCTIONS[name] or raise "bad function: #{name.inspect} (#@velocity)"
    args = function.arity.times.map{pop}

    instance_exec(*args, &function)
  end

  def step! = @position += @velocity
  def next! = self[step!]

  def play
    @position -= @velocity
    tmp = nil
    loop do
      case (func = next!)
      when /\d/ then push $&.to_i
      when '"' then push ''.tap { _1 << tmp until (tmp = next!) == '"'}
      else run func 
      end
    rescue
      warn "#@pos"
      raise
    end
  end
end


def play(msg, stack: []) = Princess.new(msg.lstrip, stack: stack).play

play <<EOS, stack:['++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.'] if true
55*.*82*3***]v
v--------------<
>:01G--."+"=?D
            D

" "0v
   >3#D
5C.?.Pv   print 5 downto 1
   QR_1<
EOS
play <<EOS if false
5>.?.P-v   print 5 downto 1
 ^}Q{_1<
v           >--Q     print 9 downto 1
|           |
>--9-->--.--I-----v
      |           |
      ^--_1.--P.--<

shortened:

5>.?.P-v   print 5 downto 1
 ^}Q{_1<
EOS

play <<EOS, stack: [10] if false
v      v-----_1$-----<   factorial function
|      |             |
>--1$-->--.--?--$:*--^
             |
     Q--P,---<

shortened:

v    >,PQ
>1$>.I$:v
   ^_1$*<
EOS

play <<EOS, stack: [100] if false||1
v      Q
>1>::=!I.3%?D
"FBiuzzzz"
   ,p"zziF"<

v v+1P------<  shortened fizzbuzz
>1>::=?Q    |
      >.3%?v|
   v"zziF"<|^<
   >-p---v-<|"
   v-I%5.<  |"
   | >"Buzz"^,
   >-..3%!--I^


v v+1P------<  shortened fizzbuzz
>1>::=?Q    |
      >.3%?v|
   v"zziF"<|^<
   >-p---v-<|"
   v-I%5.<  |"
   | >"Buzz"^,
   >-..3%!--I^

v                         expanded fizzbuzz
|
>-1->-::=-?---Q 
    |     |      
    ^-----|-+1P<
          |    |
      v---<    |
      |        | 
      >.3%?-v  |
          | |  |
v-p"zziF"-< |  |
|           |  |
>--------v--<  |
         |     |
   v-I%5.<   >-^-<
   | |       | " | 
   | >"Buzz"-^ " .
   |           | |
   >--.3%------I-^
EOS
