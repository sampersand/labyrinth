#pragma once

#include "coordinate.h"
#include "value.h"
#include "shared.h"
#include "vm.h"

typedef struct {
	int rows, cols;
	function **fns;
} board;

typedef struct {
	board board;
	coordinate velocity, position;
	array *stack;
	int debug;
} princess;

static inline function getfn(const board *b, coordinate c) {
	return b->fns[c.y][c.x];
}

static inline void setfn(board *b, coordinate c, function f) {
	b->fns[c.y][c.x] = f;
}

static inline void step(princess *p) {
	p->position = add_coordinates(p->position, p->velocity);
}

static inline function move(princess *p) {
	return step(p), getfn(&p->board, p->position);
}

static inline void unstep(princess *p) {
	p->position = subtract_coordinates(p->position, p->velocity);
}

#define INT2EXIT(n) (((n) << 1) | 1)
#define EXIT2INT(n) ((n) >> 1)
#define RUN_CONTINUE 0

// void print_board(const board *b);
int run(princess *p, function f);
int play(princess *p);
board create_board(char *input);
void pdump(const princess *p, FILE *f);
VALUE scan_str(princess *p);
VALUE scan_int(princess *p);

static inline princess new_princess(board b) {
	return (princess) {
		.board = b,
		.velocity = RIGHT,
		.position = ZERO,
		.debug = 0,
		.stack = aalloc(16),
	};
}

static inline void free_princess(princess *p) {
	free(p->board.fns), afree(p->stack);
}

static inline VALUE nth(const princess *p, int idx) {
	ensure(idx, "indexing starts at 1, not 0");
	ensure(idx <= p->stack->len, "index %d out of bounds for stack len %d", idx, p->stack->len);
	return p->stack->items[p->stack->len - idx];
}

static inline VALUE dupn(const princess *p, int idx) {
	return clone(nth(p, idx));
}

static inline void push(princess *p, VALUE v) {
	apush(p->stack, v);
}

static inline VALUE pop(princess *p) {
	return apop(p->stack, 1);
}

