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
    AryEnd = ']',

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
    RandDir = 'R',
    // FGETPOS = 'r',
    // FRETURN = 'R',

    // conditionals
    IfR = '?',
    IfL = 'I',
    Ifpopold = 't',
    IfPop = 'T',
    JumpUnless = 'H',
    JumpNUnless = 'h',
    SpawnL = 'm', // hire them
    SpawnR = 'M', // hire them
    Slay1 = 'F', // fire
    SlayN = 'f', // fire n

    // math
    Add = '+',
    Sub = '_', // `-` is used by FMOVEH already.
    Mul = '*',
    Div = '/',
    Mod = '%',
    Inc = 'X',
    Dec = 'x',
    Rand = 'r',

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

    pub fn toByte(this: Function) u8 {
        return @enumToInt(this);
    }

    pub const ValidateError = error{NotAValidFunction};
    pub fn fromChar(chr: u8) ValidateError!Function {
        return std.meta.intToEnum(Function, chr) catch error.NotAValidFunction;
    }

    pub const MaxArgc = 4;

    pub fn arity(this: Function) usize {
        return switch (this) {
            .I0, .I1, .I2, .I3, .I4, .I5, .I6, .I7, .I8, .I9 => 0,
            .Dup, .Dup2, .Pop2, .Swap, .StackLen => 0,
            .MoveH, .MoveV, .Up, .Down, .Left, .Right, .SpeedUp, .SlowDown, .Sleep1 => 0,
            .Dump, .DumpQ, .Quit0, .Gets, .Str, .Jump1, .RandDir, .Rand, .SpawnL, .SpawnR => 0,

            .Pop, .DupN, .PopN, .Not, .Chr, .Ord, .ToS, .ToI, .Inc, .Dec => 1,
            .IfL, .IfR, .IfPop, .JumpUnless, .JumpN, .Quit, .Len => 1,
            .Print, .PrintNL, .DumpVal, .DumpValNL, .SleepN => 1,

            .Add, .Sub, .Mul, .Div, .Mod, .Eql, .Lth, .Gth, .Cmp, .JumpNUnless => 2,
            .Get => 3,
            .Set => 4,

            .Ary, .AryEnd, .Ifpopold, .Slay1, .SlayN => @panic("todo"),
        };
    }
};
