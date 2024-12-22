const std = @import("std");
const IntType = @import("types.zig").IntType;

pub const ForeignFunction = enum(IntType) {
    program_name,
    print_maze,
    print_minotaurs,
};

pub const Function = enum(u8) {
    // zig fmt: off
    // Mode-changing functions.
    int0 = '0',
    int1 = '1',
    int2 = '2',
    int3 = '3',
    int4 = '4',
    int5 = '5',
    int6 = '6',
    int7 = '7',
    int8 = '8',
    int9 = '9',

    str     = '\"',
    ary     = '[',
    ary_end = ']',

    set_at = 'e',
    get_at = 'E',

    // Stack manipulation & Querying
    dup      = '@', // Duplicate the nth element, where n is the (popped) topmost element.
    dup1     = '.', // Duplicate top element of the stack
    dup2     = ':', // Duplicate the 2nd topmost element of the stack.
    pop      = '\'', // Pop the nth element, where n is the (popped) topmost element.
    pop1     = ',', // Pop the top element of the stack.
    pop2     = ';', // Pop the 2nd-to-top element of the stack.
    swap     = '$', // Swap the top 2 elements of the stack.
    stacklen = 'C', // Pushes the current length of the stack.
    ifpop    = 'T', // Pops the 3rd-to-top if the top is truthy, else pop 2nd; top is always popped.

    // Minotaur functions
    moveh  = '-', // If moving horizontally, no-op; else go left and spawn a minotaur going right.
    movev  = '|', // If moving vertically, no-op; else go left and spawn a minotaur going right.
    spawnl = 'O', // Spawn a minotaur going left.
    spawnr = 'o', // Spawn a minotaur going right.
    slay1  = 'F', // todo
    // slay = 'f', // todo
    branchl = 'B',
    branchr = 'b',
    branch = 'V',
    travel = 't',
    travelq = '`',

    // Movement Functions
    right         = '>', // Set velocity to 1 unit rightwards.
    left          = '<', // Set velocity to 1 unit leftwards.
    up            = '^', // Set velocity to 1 unit upwards.
    down          = 'v', // Set velocity to 1 unit downwards.
    speedup       = '{', // Increase velocity by 1.
    slowdown      = '}', // Decrease velocity by 1.
    jump1         = 'J', // Skip the next square.
    jump          = 'j', // Skip the next n squares.
    randdir       = 'R', // Move in a random direction.
    x_to_neg1     = '\\',// move in a `^>` and `<v`
    neg_x_to_neg1 = '/', // move in a `<^` and `v>` pattern

    // Conditional Movement.
    ifr         = '?', // If the top element is falsey, turn right.
    ifl         = 'I', // If the top element is falsey, turn left.
    ifjump1     = 'H', // If the top element is falsey, skip the next square.
    ifjump      = 'h', // If the 2nd-to-top element is falsey, skip the next n squares.
    unlessjump1 = 'K', // If the top element is truthy, skip the next square.
    unlessjump  = 'k', // If the 2nd-to-top element is truthy, skip the next n squares.

    // Misc
    sleep1    = 'Z', // Sleep for 1 tick.
    sleep     = 'z', // Sleep for the next n ticks.
    getcolour = 'U', // Gets the colour for the current minotaur
    setcolour = 'u', // Sets the colour to the topmost stack for the current minotaur.
    foreign   = 'f', // Does a foreign function.

    // Math
    neg  = '~', // Negate the topmost element.
    inc  = 'X', // Increment the topmost element.
    dec  = 'x', // Decrement the topmost element.
    add  = '+', // Add the top two elements.
    sub  = '_', // Subtract the topmost element from the 2nd-to-top element. (`-` is already used)
    mul  = '*', // Multiply the top two elements.
    div  = '%', // Divide the 2nd-to-top element by the topmost.
    mod  = 'm', // Modulo the 2nd-to-top element by the topmost.
    rand = 'r', // Push a random integer.

    // Logic
    not = '!', // Negate the topmost element.
    eql = '=', // Check to see if the top two elements are equal
    lth = 'l', // See if the second-to-top element is less than the topmost.
    gth = 'g', // See if the second-to-top element is less than the topmost.
    cmp = 'c', // Compare the second-to-top element to the topmost.

    // Integer & Array functions
    chr = 'A', // [top]
    ord = 'a', // top[0]
    tos = 's', // Convert the topmost integer to a string.
    toi = 'i', // Convert the topmost string to an int.
    len = 'L', // Get the length of the topmost item.
    get = 'G', // TODO
    set = 'S', // TODO
    head = '(', // top[0]
    tail = ')', // top[1..]
    cons = '&', // top + secondtotop

    // io
    printnl   = 'P', // Print the topmost element with a newline. See print for details
    print     = 'p', // Print topmost element; Ints are `putchar`, arys are `fputs(stdout)` w/o `\0`.
    dumpvalnl = 'N', // Dumps the topmost element and a newline; prints its normally.
    dumpval   = 'n', // Same as dumpval withotu the newline.
    dumpq     = 'D', // Dumps the labyrinth and then exits.
    dump      = 'd', // Dumps the labyrinth without quitting.
    quit0     = 'Q', // Kills the current minotaur; Exits with code 0 if it's the last minotaur.
    quit      = 'q', // Kills the current minotaur; Exits with code n if it's the last minotaur.
    gets      = 0x01, // TODO
    // zig fmt: on

    // Gets the byte representation of `func`.
    pub inline fn toByte(func: Function) u8 {
        return @intFromEnum(func);
    }

    pub const ValidateError = error{NotAValidFunction};
    pub fn fromByte(chr: u8) ValidateError!Function {
        return std.meta.intToEnum(Function, chr) catch error.NotAValidFunction;
    }

    pub const MaxArgc = 4;

    pub fn arity(func: Function) usize {
        return switch (func) {
            .int0, .int1, .int2, .int3, .int4, .int5, .int6, .int7, .int8, .int9 => 0,
            .dup1, .dup2, .pop2, .swap, .stacklen, .getcolour, .branchl, .branchr, .branch => 0,
            .moveh, .movev, .up, .down, .left, .right, .speedup, .slowdown, .sleep1 => 0,
            .dump, .dumpq, .quit0, .gets, .str, .jump1, .randdir, .rand, .spawnl, .spawnr => 0,
            .rotl, .rotr => 0,

            .pop1, .dup, .pop, .not, .chr, .ord, .tos, .toi, .inc, .dec, .neg => 1,
            .ifl, .ifr, .ifpop, .ifjump1, .unlessjump1, .jump, .quit, .len => 1,
            .print, .printnl, .dumpval, .dumpvalnl, .sleep, .setcolour => 1,
            .head, .tail => 1,

            .add, .sub, .mul, .div, .mod, .eql, .lth, .gth, .cmp, .ifjump, .unlessjump, .travel, .travelq => 2,
            .cons => 2,
            .get => 3,
            .set => 4,

            .set_at => 3,
            .get_at => 2,

            .foreign => 1,

            .ary, .ary_end, .slay1 => @panic("todo"),
        };
    }
};
