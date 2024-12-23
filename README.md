# Labyrinth
This is my 2d array-programing langauge. It's a WIP.

Your "Minotaur" starts at the upper-left corner of the program `(0,0)` with an initial velocity of one to the right. At the beginning of "round," every minotaur steps forward and does something


# Building
Built using zig 0.13.0. Zig is somewhat unstable, so it (hopefuly) will work on newer version.

```
$ zig build
$ ./zig-out/bin/labyrinth -e '"hello world"-P-Q'
```

## Commands
#### Movement
| Command | # of args | Description | Equivalent to |
| ------- | --------- | ----------- | ------------- |
| `|` | 0 | If moving vertically, whitespace; If moving horizontally, spawn another Minotaur and fork. |
| `-` | 0 | If moving horizontally, whitespace; If moving vertically, spawn another Minotaur fork. |
| `>` | 0 | Sets the velocity to 1 right |
| `<` | 0 | Sets the velocity to 1 left |
| `^` | 0 | Sets the velocity to 1 up |
| `v` | 0 | Sets the velocity to 1 down |
| `{` | 0 | Increase the velocity by 1 in the current direction |
| `}` | 0 | Decreases the velocity by 1 in the current direction; If this results in 0 velocity, the direction is swapped instead. |
| `J` | 0 | Steps an additional time, skipping what would be the next instruction. | `1j` |
| `j` | 1 | Steps `n` times |

#### Control Flow
| Command | # of args | Description |
| ------- | --------- | ----------- |
| `?` | 1 | If the topmost element is falsey, turn 90º right. |
| `I` | 1 | If the topmost element is falsey, turn 90º left. |
| `T` | 1 | If the topmost element is falsey, pop the penultimate element. |

#### Stack manipulation
| Command | # of args | Description | Equivalent to |
| ------- | --------- | ----------- | ------------- |
| `.` | 0 | Duplicates the topmost element on the stack | `1#` |
| `:` | 0 | Duplicates the penultimate element on the stack | `2#` |
| `#` | 1 | Duplicate the `n`th element on the stack (topmost is `1`) |
| `,` | 0 | Pops the topmost element off the stack | `1@` |
| `;` | 0 | Pops the penultimate element off the stack | `2@` |
| `@` | 1 | Pops the `nth` element off the stack |
| `$` | 0 | Swaps the topmost and penultimate elements on the stack | `:3@` |
| `C` | 0 | Pushes the length of the stack before `C` is executed |

#### Math
| Command | # of args | Description | Equivalent to |
| ------- | --------- | ----------- | ------------- |
| `+` | 2 | Adds the top two elements of the stack together |
| `_` | 2 | Subtracts the topmost element from the penultimate element |
| `*` | 2 | Multiplies the top two elements of the stack together |
| `/` | 2 | Divides the topmost element from the penultimate element |
| `R` | 0 | Pushes a random integer onto the stack |
| `=` | 2 | Pushes whether the top twomost elements are equal. |
| `l` | 2 | Pushes whether the penultimate element is smaller than the topmost element. |
| `g` | 2 | Pushes whether the penultimate element is smaller than the topmost element. |
| `c` | 2 | Pushes `1`, `0`, and `-1` depending on how the penultimate element compares to the ultimate. |
| `!` | 1 | 1 if the topmost element is 0 or an empty array; pushes 0 otherwise |
| `X` | 1 | Increment by one |
| `x` | 1 | Decrement by one |

#### Integer <-> String functions.
| Command | # of args | Description |
| ------- | --------- | ----------- |
| `A` | 1 | `chr`; cast the topmost value as an char and create a string. |
| `a` | 1 | `ord`; cast the topmost value as a string and return the codepoint of the first element. |
| `s` | 1 | Converts the topmost element from an int to a string. |
| `i` | 1 | Converts the topmost element from a string to an int. |

#### Array functions.
| Command | # of args | Description |
| ------- | --------- | ----------- |
| `L` | 1 | Pushes the length of the topmost element. |
| `G` | 3 | todo: explain more. (`str[index..index+len]`) |
| `S` | 3 | todo: explain more. (`str[index..index+len] = value`) |

#### I/O functions.
| Command | # of args | Description | Equivalent to |
| ------- | --------- | ----------- | ------------- |
| `P` | 1 | Interprets the topmost value as a string, and prints it followed by a newline. | `p10P` |
| `p` | 1 | Interprets the topmost value as a string and prints it. |
| `N` | 1 | Interprets the topmost value as an integer and prints it, followed by a newline. |
| `n` | 1 | Interprets the topmost value as an integer and prints it. | `n10P` |
| `D` | 0 | Dumps the interpreter out and then exits. | `dQ` |
| `d` | 0 | Dumps the interpreter out. |
| `Q` | 0 | Exits with status code 0. | `0q` |
| `q` | 1 | Exits with status code `n`. |
| `U` | 0 | reads a line from stdin. |
