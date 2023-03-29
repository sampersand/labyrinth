const std = @import("std");
const Allocator = std.mem.Allocator;
const Minotaur = @This();
const Labyrinth = @import("Labyrinth.zig");
const Coordinate = @import("Coordinate.zig");
const Vector = @import("Vector.zig");
const Value = @import("Value.zig");
const Function = @import("function.zig").Function;
const ForeignFunction = @import("function.zig").ForeignFunction;
const IntType = @import("types.zig").IntType;
const Array = @import("Array.zig");
const Maze = @import("Maze.zig");

const utils = @import("utils.zig");
const build_options = @import("build-options");
const positions_count = build_options.prev_positions + 1;

allocator: Allocator,
stack: std.ArrayListUnmanaged(Value),

velocity: Vector = Vector.Right,
positions: [positions_count]Coordinate = .{Coordinate.Origin} ** positions_count,

// We keep arguments here so we can check them in the debugger.
args: [Function.MaxArgc]Value = undefined,
mode: union(enum) { normal, integer: IntType, string: *Array } = .normal,
sleep_duration: usize = 0,
is_first: bool = false,
colour: u8 = 0,
exit_status: ?u8 = null,

/// Creates a new `Minotaur` with the given starting stack capacity.
pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!*Minotaur {
    var minotaur = try alloc.create(Minotaur);
    errdefer alloc.destroy(minotaur);

    minotaur.* = .{
        .stack = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap),
        .allocator = alloc,
    };

    return minotaur;
}

pub fn deinitNotDestroyThough(minotaur: *Minotaur) void {
    switch (minotaur.mode) {
        .string => |ary| ary.deinit(minotaur.allocator),
        else => {},
    }

    for (minotaur.stack.items) |item|
        item.deinit(minotaur.allocator);
    minotaur.stack.deinit(minotaur.allocator);
}

/// Deinitializes the minotaur and all associated items.
pub fn deinit(minotaur: *Minotaur) void {
    minotaur.deinitNotDestroyThough();
    minotaur.allocator.destroy(minotaur);
}

pub fn clone(minotaur: *const Minotaur) Allocator.Error!*Minotaur {
    var new = try Minotaur.initCapacity(minotaur.allocator, minotaur.stack.items.len);

    for (minotaur.stack.items) |value|
        new.push(value.clone()) catch unreachable; // we ensured we had enough capacity.

    new.positions = minotaur.positions;
    new.velocity = minotaur.velocity;
    new.colour = minotaur.colour +% 1;

    new.mode = minotaur.mode;
    new.sleep_duration = minotaur.sleep_duration;
    new.is_first = minotaur.is_first;
    new.exit_status = minotaur.exit_status;
    new.args = minotaur.args;

    return new;
}

/// The same as `Minotaur.clone`, except it also rotates in the given direction.
pub fn cloneRotate(minotaur: *const Minotaur, dir: Vector.Direction) Allocator.Error!*Minotaur {
    var copy = try minotaur.clone();
    copy.velocity = copy.velocity.rotate(dir);
    return copy;
}

/// Returns whether the minotaur has exited yet.
pub inline fn hasExited(minotaur: *const Minotaur) bool {
    return minotaur.exit_status != null;
}

/// Moves the minotaur to the `new` position, updating old positions as needed.
pub fn jumpTo(minotaur: *Minotaur, new: Coordinate) void {
    var i: usize = positions_count - 1;
    while (i != 0) : (i -= 1) {
        minotaur.positions[i] = minotaur.positions[i - 1];
    }

    minotaur.positions[0] = new;
}

/// Moves the minotaur forward by `minotaur.velocity` steps.
pub fn advance(minotaur: *Minotaur) Coordinate.MoveError!void {
    std.debug.assert(!minotaur.hasExited());
    minotaur.jumpTo(try minotaur.positions[0].moveBy(minotaur.velocity));
}

pub const StackError = error{StackTooSmall};

/// Helper function to return an index from the end, or an error if it's too small.
inline fn offset(minotaur: *const Minotaur, fromEnd: usize) StackError!usize {
    if (minotaur.stack.items.len <= fromEnd) return error.StackTooSmall;
    return minotaur.stack.items.len - fromEnd - 1;
}

/// Pushes `value` onto the end of the stack.
pub fn push(minotaur: *Minotaur, value: Value) Allocator.Error!void {
    try minotaur.stack.append(minotaur.allocator, value);
}

/// Get the `idx`th element from the top of the stack, or return an error.
pub fn dup(minotaur: *const Minotaur, fromEnd: usize) StackError!Value {
    return minotaur.stack.items[try minotaur.offset(fromEnd)].clone();
}

/// Removes the `fromEnd`th element from the stack, returning an error if that's not possible.
pub fn pop(minotaur: *Minotaur, fromEnd: usize) StackError!Value {
    const index = try minotaur.offset(fromEnd);
    return switch (fromEnd) {
        0 => minotaur.stack.pop(),
        1 => minotaur.stack.swapRemove(index),
        else => minotaur.stack.orderedRemove(index),
    };
}

/// Prints a debug representation of `minotaur` out.
pub fn format(
    minotaur: *const Minotaur,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print(
        "Minotaur{{position={any},velocity={any},colour={d},stack=[",
        .{ minotaur.positions[0], minotaur.velocity, minotaur.colour },
    );

    for (minotaur.stack.items) |*value, idx| {
        if (idx != 0) try writer.writeAll(", ");
        try writer.print("{}", .{value});
    }

    try writer.writeAll("]}");
}

//
const PlayError = error{
    TooFewArgumentsForFunction,
    IntOutOfBounds,
    IntLiteralOverflow,
    UnknownForeignFunction,
    EmptyArray,
} || StackError || std.os.WriteError || Allocator.Error ||
    Array.ParseIntError || Function.ValidateError || Value.OrdError || Value.MathError ||
    Coordinate.MoveError || Labyrinth.MinotaurGetError;

pub fn tick(minotaur: *Minotaur, labyrinth: *Labyrinth) PlayError!void {
    // If we're currently sleeping, then continue sleeping.
    if (utils.unlikely(minotaur.sleep_duration != 0)) {
        minotaur.sleep_duration -= 1;
        return;
    }

    // If it's the very first time any minotaur in the entire program has moved,
    // then don't actually move. This is so we don't skip the first step.
    if (utils.unlikely(minotaur.is_first)) {
        minotaur.is_first = false;
    } else {
        try minotaur.advance();
    }

    // Get the byte we're looking at.
    const byte = labyrinth.maze.get(minotaur.positions[0]) orelse return error.CoordinateOutOfBounds;

    switch (minotaur.mode) {
        .string => |*ary| {
            // If it's not the end quote, then just push it to the end.
            if (byte != comptime Function.str.toByte()) {
                ary.* = try ary.*.prependNoIncrement(minotaur.allocator, Value.from(@intCast(IntType, byte)));
            } else {
                // It's the closing quote, then push it onto the list of chars and return.
                try minotaur.push(Value.from(try ary.*.reverse(minotaur.allocator)));
                ary.*.decrement(minotaur.allocator);
                minotaur.mode = .normal;
            }

            return;
        },

        .integer => |*int| {
            // If it's another digit, continue adding it to the integer.
            if (std.fmt.charToDigit(byte, 10) catch null) |digit| {
                int.* = std.math.add(
                    IntType,
                    std.math.mul(IntType, 10, int.*) catch return error.IntLiteralOverflow,
                    digit,
                ) catch return error.IntLiteralOverflow;
                return;
            }

            // It's not a digit, so instead add our int to the list of ints and execute what we
            // just saw.
            try minotaur.push(Value.from(int.*));
            minotaur.mode = .normal;
        },
        .normal => {},
    }

    try minotaur.tickFunction(labyrinth, try Function.fromByte(byte));
}

fn setArguments(minotaur: *Minotaur, arity: usize) PlayError!void {
    var i: usize = 0;
    errdefer minotaur.deinitArgs(i);

    while (i < arity) : (i += 1)
        minotaur.args[i] = minotaur.pop(0) catch return error.TooFewArgumentsForFunction;
}

fn deinitArgs(minotaur: *Minotaur, arity: usize) void {
    for (minotaur.args[0..arity]) |arg|
        arg.deinit(minotaur.allocator);
}

fn castInt(comptime T: type, int: IntType) PlayError!T {
    return std.math.cast(T, int) orelse return error.IntOutOfBounds;
}

fn jumpn(minotaur: *Minotaur, n: Value) PlayError!void {
    const CoordInt = i32;
    const int = try n.toInt();
    const scalar = try castInt(CoordInt, int);
    minotaur.positions[0] = try minotaur.positions[0].moveBy(minotaur.velocity.scale(scalar));
}

fn randomVelocity(rng: *std.rand.DefaultPrng) Vector {
    return switch (rng.random().int(u2)) {
        0b00 => Vector.Up,
        0b01 => Vector.Down,
        0b10 => Vector.Left,
        0b11 => Vector.Right,
    };
}

fn foreign(minotaur: *Minotaur, labyrinth: *Labyrinth, function: ForeignFunction) !void {
    switch (function) {
        .program_name => try minotaur.push(Value.from(try Array.fromString(
            labyrinth.allocator,
            labyrinth.maze.filename,
        ))),
        .print_maze => try labyrinth.printMaze(labyrinth.stdout.writer()),
        .print_minotaurs => try labyrinth.printMinotaurs(labyrinth.stdout.writer()),
    }
}

fn tickFunction(minotaur: *Minotaur, labyrinth: *Labyrinth, function: Function) PlayError!void {
    std.debug.assert(minotaur.sleep_duration == 0);

    try minotaur.setArguments(function.arity());
    defer minotaur.deinitArgs(function.arity());
    var ret: ?Value = null;

    switch (function) {
        .int0, .int1, .int2, .int3, .int4, .int5, .int6, .int7, .int8, .int9 => minotaur.mode = .{
            .integer = std.fmt.charToDigit(function.toByte(), 10) catch unreachable,
        },
        .str => minotaur.mode = .{ .string = Array.empty },

        .dup1 => ret = try minotaur.dup(0),
        .dup2 => ret = try minotaur.dup(1),
        .dup => ret = try minotaur.dup(try castInt(usize, try minotaur.args[0].toInt())),
        .pop1 => {}, // already handled by taking one argument.
        .pop2 => _ = try minotaur.pop(1),
        .pop => _ = try minotaur.pop(try castInt(usize, try minotaur.args[0].toInt())),
        .swap => ret = try minotaur.pop(1),
        .stacklen => ret = Value.from(
            // on no computer I know if can this actually occur
            std.math.cast(IntType, minotaur.stack.items.len) orelse @panic("this should never happen"),
        ),
        .ifpop => _ = try minotaur.pop(if (minotaur.args[0].isTruthy()) 1 else 0),

        // Minotaur functions
        .moveh, .movev => {
            const perp = 0 != if (function == .moveh) minotaur.velocity.x else minotaur.velocity.y;
            if (utils.unlikely(!perp)) {
                try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.left));
                minotaur.velocity = minotaur.velocity.rotate(.right);
            }
        },
        .spawnl => try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.left)),
        .spawnr => try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.right)),
        .branchl, .branchr => {
            var cl = try minotaur.cloneRotate(if (function == .branchl) .left else .right);
            errdefer cl.deinit();
            const id = try labyrinth.addTimeline(cl);
            ret = Value.from(@intCast(IntType, id));
        },
        .branch => {
            const id = try labyrinth.addTimeline(try minotaur.clone());
            ret = Value.from(@intCast(IntType, id));
        },
        .travel, .travelq => {
            const id = try castInt(usize, try minotaur.args[0].toInt());
            var alternate_reality = try (try labyrinth.getTimeline(id)).clone();
            errdefer alternate_reality.deinit();
            try alternate_reality.push(minotaur.args[1].clone());
            if (function == .travelq) {
                minotaur.exit_status = 0;
            }
            try labyrinth.spawnMinotaur(alternate_reality);
        },

        // Movement
        .left => minotaur.velocity = Vector.Left,
        .right => minotaur.velocity = Vector.Right,
        .up => minotaur.velocity = Vector.Up,
        .down => minotaur.velocity = Vector.Down,
        .speedup => minotaur.velocity = minotaur.velocity.speedUp(),
        .slowdown => minotaur.velocity = minotaur.velocity.slowDown(),
        .jump1 => try minotaur.advance(),
        .jump => try minotaur.jumpn(minotaur.args[0]),
        .randdir => minotaur.velocity = randomVelocity(&labyrinth.rng),

        .get_at => {
            const x = try castInt(u32, try minotaur.args[0].toInt());
            const y = try castInt(u32, try minotaur.args[1].toInt());
            ret = Value.from(@as(IntType, labyrinth.maze.get(.{ .x = x, .y = y }) orelse 0));
        },
        .set_at => {
            const x = try castInt(u32, try minotaur.args[0].toInt());
            const y = try castInt(u32, try minotaur.args[1].toInt());
            try labyrinth.maze.set(
                labyrinth.allocator,
                .{ .x = x, .y = y },
                try castInt(u8, try minotaur.args[2].toInt()),
            );
        },
        // Conditional Movement.
        .ifl => if (!minotaur.args[0].isTruthy()) {
            minotaur.velocity = minotaur.velocity.rotate(.left);
        },
        .ifr => if (!minotaur.args[0].isTruthy()) {
            minotaur.velocity = minotaur.velocity.rotate(.right);
        },
        .ifjump1 => if (!minotaur.args[0].isTruthy()) {
            try minotaur.advance();
        },
        .ifjump => if (!minotaur.args[1].isTruthy()) {
            try minotaur.jumpn(minotaur.args[0]);
        },
        .unlessjump1 => if (minotaur.args[0].isTruthy()) {
            try minotaur.advance();
        },
        .unlessjump => if (minotaur.args[1].isTruthy()) {
            try minotaur.jumpn(minotaur.args[0]);
        },

        // Misc
        .sleep1 => minotaur.sleep_duration = 1,
        .sleep => minotaur.sleep_duration = try castInt(usize, try minotaur.args[0].toInt()),
        .getcolour => ret = Value.from(minotaur.colour),
        .setcolour => minotaur.colour = @bitCast(u8, @truncate(i8, try minotaur.args[0].toInt())),
        .foreign => {
            const func = std.meta.intToEnum(ForeignFunction, try minotaur.args[0].toInt()) catch return error.UnknownForeignFunction;
            try minotaur.foreign(labyrinth, func);
        },

        // Math
        .neg => ret = try minotaur.args[0].mul(minotaur.allocator, Value.from(-1)),
        .inc => ret = try minotaur.args[0].add(minotaur.allocator, Value.from(1)),
        .dec => ret = try minotaur.args[0].sub(minotaur.allocator, Value.from(1)),
        .add => ret = try minotaur.args[1].add(minotaur.allocator, minotaur.args[0]),
        .sub => ret = try minotaur.args[1].sub(minotaur.allocator, minotaur.args[0]),
        .mul => ret = try minotaur.args[1].mul(minotaur.allocator, minotaur.args[0]),
        .div => ret = try minotaur.args[1].div(minotaur.allocator, minotaur.args[0]),
        .mod => ret = try minotaur.args[1].mod(minotaur.allocator, minotaur.args[0]),
        .rand => ret = Value.from(labyrinth.rng.random().int(IntType)),

        // Logic
        .not => ret = Value.from(!minotaur.args[0].isTruthy()),
        .eql => ret = Value.from(minotaur.args[1].equals(minotaur.args[0])),
        .lth => ret = Value.from(minotaur.args[1].cmp(minotaur.args[0]) < 0),
        .gth => ret = Value.from(minotaur.args[1].cmp(minotaur.args[0]) > 0),
        .cmp => ret = Value.from(minotaur.args[1].cmp(minotaur.args[0])),

        // Integer & Array functions
        .ord => ret = try minotaur.args[0].ord(),
        .chr => ret = try minotaur.args[0].chr(minotaur.allocator),
        .len => {
            var ary = try minotaur.args[0].toArray(minotaur.allocator);
            defer ary.deinit(minotaur.allocator);

            ret = Value.from(std.math.cast(IntType, ary.len()) orelse return error.IntOutOfBounds);
        },
        .toi => ret = Value.from(try minotaur.args[0].toInt()),
        .tos => ret = Value.from(try minotaur.args[0].toArray(minotaur.allocator)),
        .head => {
            const ary = try minotaur.args[0].toArray(minotaur.allocator);
            defer ary.decrement(minotaur.allocator);
            var iter = ary.iter();
            ret = (iter.next() orelse return error.EmptyArray).clone();
        },
        .tail => {
            const ary = try minotaur.args[0].toArray(minotaur.allocator);
            defer ary.decrement(minotaur.allocator);
            var next = ary.next orelse return error.EmptyArray;
            next.increment();
            ret = Value.from(next);
        },
        .cons => {
            const begin = try minotaur.args[1].toArray(minotaur.allocator);
            defer begin.decrement(minotaur.allocator);

            const end = try minotaur.args[0].toArray(minotaur.allocator);
            defer end.decrement(minotaur.allocator);

            ret = Value.from(try begin.cons(minotaur.allocator, end));
        },

        // io
        .print => try labyrinth.stdout.writer().print("{s}", .{minotaur.args[0]}),
        .printnl => try labyrinth.stdout.writer().print("{s}\n", .{minotaur.args[0]}),
        .dumpval => try labyrinth.stdout.writer().print("{d}", .{minotaur.args[0]}),
        .dumpvalnl => try labyrinth.stdout.writer().print("{d}\n", .{minotaur.args[0]}),
        .dumpq, .dump => {
            try labyrinth.stdout.writer().print("{}\n", .{labyrinth});
            if (function == .dumpq) minotaur.exit_status = 0;
        },
        .quit0 => minotaur.exit_status = 0,
        .quit => minotaur.exit_status = try castInt(u8, try minotaur.args[0].toInt()),

        // to implement:
        .ary, .ary_end, .slay1, .gets, .get, .set => @panic("todo"),
    }

    if (ret) |value| try minotaur.push(value);
}
