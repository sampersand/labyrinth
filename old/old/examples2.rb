def play(msg, stack:[]) = Princess.new(msg.lstrip, stack: stack).play


play <<EOS if true
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
