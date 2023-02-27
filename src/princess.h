#pragma once

#include "coordinate.h"
#include "value.h"
#include "shared.h"
#include "vm.h"

typedef struct {
	function **board;
	coordinate velocity, position;
	array *stack;
} princess;

static inline function getfn(const princess *p, coordinate c) {
	return p->board[c.y][c.x];
}

static inline void step(princess *p) {
	p->position = add_coordinates(p->position, p->velocity);
}

static inline function move(princess *p) {
	return step(p), getfn(p, p->position);
}

static inline void unstep(princess *p) {
	p->position = subtract_coordinates(p->position, p->velocity);
}


#define INT2EXIT(n) (((n) << 1) | 1)
#define EXIT2INT(n) ((n) >> 1)
#define RUN_CONTINUE 0

int run(princess *p, function f);
int play(princess *p);
function **create_board(char *input);
princess new_princess(function **board);
void free_princess(princess *p);
void pdump(const princess *p, FILE *f);
void push(princess *p, VALUE v);
VALUE popn(princess *p, int i);

static inline VALUE nth(const princess *p, int idx) {
	ensure(idx, "indexing starts at 1, not 0");
	ensure(idx <= p->stack->len, "index %d out of bounds for stack len %d", idx, p->stack->len);
	return p->stack->items[p->stack->len - idx];
}

static inline VALUE dupn(const princess *p, int idx) {
	return clone(nth(p, idx));
}

static inline VALUE pop(princess *p) {
	ensure(p->stack->len, "popping from an empty stack");
	return p->stack->items[--p->stack->len];
}

