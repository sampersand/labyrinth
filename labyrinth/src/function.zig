const std = @import("std");

pub const Function = enum(u8) {
    // integer literals
    int_0 = '0',
    int_1 = '1',
    int_2 = '2',
    int_3 = '3',
    int_4 = '4',
    int_5 = '5',
    int_6 = '6',
    int_7 = '7',
    int_8 = '8',
    int_9 = '9',

    // mode changing functions
    str = '\"',
    ary = '[',
    ary_end = ']',

    // stack manipulation
    dup = '.',
    dup2 = ':',
    pop = ',',
    pop2 = ';',
    dup_n = '#',
    pop_n = '@',
    swap = '$',
    stack_length = 'C',

    // directions
    move_h = '-',
    move_v = '|',
    right = '>',
    left = '<',
    up = '^',
    down = 'v',
    speedup = '{',
    slowdown = '}',
    jump_1 = 'J',
    jump_n = 'j',
    sleep_n = 'z',
    sleep_1 = 'Z',
    rand_direction = 'R',
    // FGETPOS = 'r',
    // FRETURN = 'R',

    // conditionals
    right_if = '?',
    left_if = 'I',
    pop_select = 'T',
    jump_1_if = 'K',
    jump_n_if = 'k',
    jump_1_unless = 'H',
    jump_n_unless = 'h',
    spawn_left = 'M', // hire them
    spawn_right = 'm', // hire them
    slay_1 = 'F', // fire
    slay_n = 'f', // fire n

    // math
    add = '+',
    subtract = '_', // `-` is used by FMOVEH already.
    multiply = '*',
    divide = '/',
    modulo = '%',
    increment = 'X',
    decrement = 'x',
    random = 'r',
    negate = '~',

    // comparisons
    are_equal = '=',
    is_less_than = 'l',
    is_greater_than = 'g',
    compare = 'c',
    not = '!',

    // integer functions
    chr = 'A',
    ord = 'a',
    to_str = 's',
    to_int = 'i',

    // ary functions
    length = 'L',
    get = 'G',
    set = 'S',

    // io
    print_newline = 'P',
    print = 'p',
    dump_value_newline = 'N',
    dump_value = 'n',
    dump_labryinth_quit = 'D',
    dump_labryinth = 'd',
    quit_0 = 'Q',
    quit_n = 'q',
    get_string = '(',
    increment_colour = 'U',
    set_colour = 'u',

    pub fn toByte(this: Function) u8 {
        return @enumToInt(this);
    }

    pub const ValidateError = error{NotAValidFunction};
    pub fn fromByte(chr: u8) ValidateError!Function {
        return std.meta.intToEnum(Function, chr) catch error.NotAValidFunction;
    }

    pub const MaxArgc = 4;

    pub fn arity(this: Function) usize {
        return switch (this) {
            .int_0, .int_1, .int_2, .int_3, .int_4, .int_5, .int_6, .int_7, .int_8, .int_9 => 0,
            .dup, .dup2, .pop2, .swap, .stack_length, .inccolour => 0,
            .move_h, .move_v, .up, .down, .left, .right, .speedup, .slowdown, .sleep1 => 0,
            .dump, .dumpq, .quit0, .gets, .str, .jump1, .randdir, .rand, .spawnl, .spawnr => 0,

            .pop, .dupn, .popn, .not, .chr, .ord, .tos, .toi, .inc, .dec => 1,
            .ifl, .ifr, .ifpop, .jumpunless, .jumpif, .jumpn, .quit, .len => 1,
            .print, .printnl, .dumpval, .dumpvalnl, .sleepn, .setcolour => 1,

            .add, .sub, .mul, .div, .mod, .eql, .lth, .gth, .cmp, .jumpnunless, .jumpnif => 2,
            .get => 3,
            .set => 4,

            .ary, .aryend, .ifpopold, .slay1, .slayn => @panic("todo"),
        };
    }
};
