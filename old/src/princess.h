#pragma once

#include "value.h"
#include "shared.h"
#include "board.h"
#include "handmaiden.h"

enum options {
	DEBUG              = 1 << 0,
	DEBUG_PRINT_BOARD  = 1 << 1,
	DEBUG_PRINT_STACKS = 1 << 2,
};
typedef struct princess {
    board board;
    int options, nhm, hmcap;
    handmaiden **handmaidens;
} princess;

// void print_board(const board *b);
int play(princess *p);
void dump(const princess *p, FILE *f);
princess new_princess(board b);
void free_princess(princess *p);
void hire_handmaiden(princess *p, handmaiden *hm);
void fire_handmaiden(princess *p, int i);
static inline void fire_when(princess *p, handmaiden *hm, int count) {

}
