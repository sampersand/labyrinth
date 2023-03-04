#pragma once
#include "function.h"
#include "coordinate.h"

typedef struct {
    int rows, cols;
    function **fns;
} board;

static inline function getfn(const board *b, coordinate c) {
	return b->fns[c.y][c.x];
}

static inline void setfn(board *b, coordinate c, function f) {
	b->fns[c.y][c.x] = f;
}

board create_board(char *input);
void free_board(board *b);
