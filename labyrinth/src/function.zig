const std = @import("std");

pub const Function = enum(u8) {
    // integer literals
    I0 = '0',
    I1 = '1',
    I2 = '2',
    I3 = '3',
    I4 = '4',
    I5 = '5',
    I6 = '6',
    I7 = '7',
    I8 = '8',
    I9 = '9',

    // mode changing functions
    Str = '\"',
    Ary = '[',
    Aryend = ']',

    // stack manipulation
    Dup = '.',
    Dup2 = ':',
    Pop = ',',
    Pop2 = ';',
    DupN = '#',
    PopN = '@',
    Swap = '$',
    StackLen = 'C',

    // directions
    MoveH = '-',
    MoveV = '|',
    Right = '>',
    Left = '<',
    Up = '^',
    Down = 'v',
    SpeedUp = '{',
    SlowDown = '}',
    Jump1 = 'J',
    JumpN = 'j',
    SleepN = 'z',
    Sleep1 = 'Z',
    // FGETPOS = 'r',
    // FRETURN = 'R',

    // conditionals
    IfR = '?',
    IfL = 'I',
    Ifpopold = 't',
    IfPop = 'T',
    JumpUnless = 'K',
    JumpNUnless = 'k',
    HireL = 'H', // hire them
    HireR = 'h', // hire them
    Fire1 = 'F', // fire
    FireN = 'f', // fire n

    // math
    Add = '+',
    Sub = '_', // `-` is used by FMOVEH already.
    Mul = '*',
    Div = '/',
    Mod = '%',
    Rand = 'r',
    RandDir = 'R',
    Inc = 'X',
    Dec = 'x',

    // comparisons
    Eql = '=',
    Lth = 'l',
    Gth = 'g',
    Cmp = 'c',
    Not = '!',

    // integer functions
    Chr = 'A',
    Ord = 'a',
    ToS = 's',
    ToI = 'i',

    // ary functions
    Len = 'L',
    Get = 'G',
    Set = 'S',

    // io
    PrintNL = 'P',
    Print = 'p',
    DumpValNL = 'N',
    DumpVal = 'n',
    DumpQ = 'D',
    Dump = 'd',
    Quit0 = 'Q',
    Quit = 'q',
    Gets = 'U',

    pub const ValidateError = error{NotAValidFunction};

    pub fn toByte(this: Function) u8 {
        return @enumToInt(this);
    }

    pub fn fromChar(chr: u8) ValidateError!Function {
        return std.meta.intToEnum(Function, chr) catch error.NotAValidFunction;
    }

    pub const MaxArgc = 4;

    pub fn arity(this: Function) usize {
        return switch (this) {
            .I0, .I1, .I2, .I3, .I4, .I5, .I6, .I7, .I8, .I9 => 0,
            .Dup, .Dup2, .Pop2, .Swap, .StackLen => 0,
            .MoveH, .MoveV, .Up, .Down, .Left, .Right, .SpeedUp, .SlowDown, .Sleep1 => 0,
            .Dump, .DumpQ, .Quit0, .Gets, .Str, .Jump1, .RandDir, .Rand, .HireL, .HireR => 0,

            .Pop, .DupN, .PopN, .Not, .Chr, .Ord, .ToS, .ToI, .Inc, .Dec => 1,
            .IfL, .IfR, .IfPop, .JumpUnless, .JumpN, .Quit, .Len => 1,
            .Print, .PrintNL, .DumpVal, .DumpValNL, .SleepN => 1,

            .Add, .Sub, .Mul, .Div, .Mod, .Eql, .Lth, .Gth, .Cmp, .JumpNUnless => 2,
            .Get => 3,
            .Set => 4,

            .Ary, .Aryend, .Ifpopold, .Fire1, .FireN => @panic("todo"),
        };
    }
};

// #define MAX_ARGC 4

// char *strchr(const char *c, int);

// static inline int arity(function f) {
//     if (strchr("0123456789.:;$-|><^v{}DdQU\"JRrCHh", f)) return 0;
//     if (strchr(",#@!aAsi?ItTPpqNnjxXKfz", f)) return 1;
//     if (strchr("+_*/%=lgck", f)) return 2;
//     if (strchr("G", f)) return 3;
//     if (strchr("S", f)) return 4;
//     return -1;
// }

