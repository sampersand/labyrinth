const std = @import("std");

pub const Function = enum(u8) {
    // integer literals
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

    // mode changing functions
    str = '\"',
    ary = '[',
    ary_end = ']',

    // stack manipulation
    dup1 = '.',
    dup2 = ':',
    pop1 = ',',
    pop2 = ';',
    dup = '#',
    pop = '@',
    swap = '$',
    stacklen = 'C',

    // directions
    moveh = '-',
    movev = '|',
    right = '>',
    left = '<',
    up = '^',
    down = 'v',
    speedup = '{',
    slowdown = '}',
    jump1 = 'J',
    jump = 'j',
    sleep = 'z',
    sleep1 = 'Z',
    randdir = 'R',
    // FGETPOS = 'r',
    // FRETURN = 'R',

    // conditionals
    ifr = '?',
    ifl = 'I',
    ifpop = 'T',
    ifjump1 = 'K',
    ifjump = 'k',
    unlessjump1 = 'H',
    unlessjump = 'h',
    spawnl = 'M', // hire them
    spawnr = 'm', // hire them
    slay1 = 'F', // fire
    slay = 'f', // fire n

    // math
    add = '+',
    sub = '_', // `-` is used by FMOVEH already.
    mul = '*',
    div = '/',
    mod = '%',
    inc = 'X',
    dec = 'x',
    rand = 'r',
    neg = '~',

    // comparisons
    eql = '=',
    lth = 'l',
    gth = 'g',
    cmp = 'c',
    not = '!',

    // integer functions
    chr = 'A',
    ord = 'a',
    tos = 's',
    toi = 'i',

    // ary functions
    len = 'L',
    get = 'G',
    set = 'S',

    // io
    printnl = 'P',
    print = 'p',
    dumpvalnl = 'N',
    dumpval = 'n',
    dumpq = 'D',
    dump = 'd',
    quit0 = 'Q',
    quit = 'q',
    gets = '(',
    inccolour = 'U',
    setcolour = 'u',

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
            .int0, .int1, .int2, .int3, .int4, .int5, .int6, .int7, .int8, .int9 => 0,
            .dup1, .dup2, .pop2, .swap, .stacklen, .inccolour => 0,
            .moveh, .movev, .up, .down, .left, .right, .speedup, .slowdown, .sleep1 => 0,
            .dump, .dumpq, .quit0, .gets, .str, .jump1, .randdir, .rand, .spawnl, .spawnr => 0,

            .pop1, .dup, .pop, .not, .chr, .ord, .tos, .toi, .inc, .dec, .neg => 1,
            .ifl, .ifr, .ifpop, .unlessjump1, .ifjump1, .jump, .quit, .len => 1,
            .print, .printnl, .dumpval, .dumpvalnl, .sleep, .setcolour => 1,

            .add, .sub, .mul, .div, .mod, .eql, .lth, .gth, .cmp, .unlessjump, .ifjump => 2,
            .get => 3,
            .set => 4,

            .ary, .ary_end, .slay1, .slay => @panic("todo"),
        };
    }
};
