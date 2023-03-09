const std = @import("std");
const Board = @import("Board.zig");
const Minotaur = @import("Minotaur.zig");
const types = @import("types.zig");
const assert = std.debug.assert;

const Labyrinth = @This();

board: Board,
options: i32 = 0,
minotaurs: std.ArrayList(Minotaur),
// const debug = 1;

pub fn init(board: Board, alloc: std.mem.Allocator) std.mem.Allocator.Error!Labyrinth {
    var minotaurs = try std.ArrayList(Minotaur).initCapacity(alloc, 8);
    try minotaurs.append(try Minotaur.initCapacity(alloc, 8));
    return Labyrinth{ .board = board, .minotaurs = minotaurs };
}

pub fn deinit(this: *Labyrinth) void {
    this.board.deinit();
    this.minotaurs.deinit();
}

pub fn dump(this: *const Labyrinth, writer: anytype) std.os.WriteError!void {
    _ = try writer.write("Labyrinth(");
    if (this.options & 1 == 1) {
        _ = try writer.write("board=");
        try this.board.dump(writer);
        _ = try writer.print(", options={d}, ", .{this.options});
    }

    _ = try writer.write("minotaurs=[");
    for (this.minotaurs.items) |minotaur, idx| {
        if (idx != 0) {
            _ = try writer.write(", ");
        }
        _ = try writer.write("\n\t");
        try minotaur.dump(writer);
    }
    try writer.print("\n])", .{});
}

fn print_board(board: *const Board, minotaurs: []Minotaur, writer: anytype) std.os.WriteError!void {
    _ = board;
    _ = minotaurs;
    _ = writer;
    // static void print_board(const board *b, handmaiden **hms, int nhms) {
    //     int indices[nhms], nindices;

    //     for (int col = 0; col < b->cols; ++col) {
    //         nindices = 0;

    //         for (int i = 0; i < nhms; ++i)
    //             if (hms[i]->position.y == col)
    //                 indices[nindices++] = hms[i]->position.x;

    //         if (!nindices) {
    //             puts(b->fns[col]);
    //             continue;
    //         }

    //         qsort(indices, nindices, sizeof(int), cmp_int);
    //         for (int i = 0; i < nindices; ++i) {
    //             if (i && indices[i] == indices[i-1]) continue;
    //             int start = (i == 0 ? 0 : indices[i - 1] + 1);
    //             printf("%.*s\033[7m%c\033[0m",
    //                 indices[i] - start, b->fns[col] + start, b->fns[col][indices[i]]);
    //         }
    //         puts(b->fns[col] + indices[nindices - 1] + 1);
    //     }
    // }
    // static void debug_print_board(princess *p) {
    //     fputs("\e[1;1H\e[2J", stdout); // clear screen

    //     if (p->options & DEBUG_PRINT_BOARD)
    //         print_board(&p->board, p->handmaidens, p->nhm);

    //     if (p->options & DEBUG_PRINT_STACKS)
    //         for (int i = 0; i < p->nhm; ++i) {
    //             printf("maiden %d: ", i);
    //             dump_value(a2v(p->handmaidens[i]->stack), stdout);
    //             putchar('\n');
    //         }
    // }

    // #ifdef PRINCESS_ISNT_WORKING_FOR_ME
    // #include <Windows.h>
    // static void sleep_for_ms(int ms){ Sleep(ms); }
    // #else
    // #include <time.h>
    // static void sleep_for_ms(int ms) {
    //     nanosleep(&(struct timespec) { 0, ms * 1000000 }, 0);
    // }
    // #endif
}

pub fn spawnMinotaur(this: *Labyrinth, minotaur: Minotaur) void {
    this.minotaurs.push(minotaur);
}

pub fn slayMinotaur(this: *Labyrinth, idx: usize) void {
    assert(idx < this.minotaurs.len);
    this.minotaurs.swapRemove(idx).deinit();
}

const sleepMs = 25;

pub fn play(this: *Labyrinth) !types.Int {
    for (this.minotaurs.items) |*minotaur| {
        minotaur.unstep();
    }

    while (true) {
        for (this.minotaurs.items) |*minotaur, idx| {
            switch (minotaur.play(this)) {
                .Continue => continue,
                .Error => @panic("error"),
                .Exit => |code| {
                    if (this.minotaurs.items.len == 0) {
                        return code;
                    }

                    _ = this.minotaurs.swapRemove(idx);
                },
            }
        }

        // if (this.options & debug) {
        //     this.debug_print_board();
        // }
    }
}
//         if (p->options & DEBUG)
//             debug_print_board(p), sleep_for_ms(SLEEP_MS);
//     }

//     return 0;
// }

// // // void print_board(const board *b);
// // int play(princess *p);
// // void dump(const princess *p, FILE *f);
// // princess new_princess(board b);
// // void free_princess(princess *p);
// // void hire_handmaiden(princess *p, handmaiden *hm);
// // void fire_handmaiden(princess *p, int i);
// // static inline void fire_when(princess *p, handmaiden *hm, int count) {

// // }
