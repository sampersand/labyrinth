#pragma once

#include "coordinate.h"
#include "board.h"
#include "value.h"

typedef struct {
    coordinate velocity, position;
    array *stack;
} handmaiden;


#define INT2EXIT(n) (((n) << 1) | 1)
#define EXIT2INT(n) ((n) >> 1)
#define RUN_CONTINUE 0
struct princess;
int do_chores(handmaiden *hm, function f, struct princess *p);
VALUE scan_str(handmaiden *hm, const board *b);
VALUE scan_int(handmaiden *hm, const board *b);
void dump_handmaiden(const handmaiden *p, FILE *out);

static void free_handmaiden(handmaiden *hm) {
	afree(hm->stack);
}

static inline void step(handmaiden *hm) {
	hm->position = add_coordinates(hm->position, hm->velocity);
}

static inline void unstep(handmaiden *hm) {
	hm->position = subtract_coordinates(hm->position, hm->velocity);
}

static inline function move(handmaiden *hm, const board *b) {
	return step(hm), getfn(b, hm->position);
}

static inline VALUE nth(const handmaiden *hm, int idx) {
	ensure(idx, "indexing starts at 1, not 0");
	ensure(idx <= hm->stack->len, "index %d out of bounds for stack len %d", idx, hm->stack->len);
	return hm->stack->items[hm->stack->len - idx];
}

static inline VALUE dupn(const handmaiden *hm, int idx) {
	return clone(nth(hm, idx));
}

static inline void push(handmaiden *hm, VALUE v) {
	apush(hm->stack, v);
}

static inline VALUE pop(handmaiden *hm) {
	return apop(hm->stack, 1);
}


