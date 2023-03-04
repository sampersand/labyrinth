#pragma once

#include "value.h"
#include "shared.h"
#include "board.h"
#include "handmaiden.h"

typedef struct princess {
    board board;
    int debug, nhm, hmcap;
    handmaiden *handmaidens;
} princess;

// void print_board(const board *b);
int play(princess *p);
void dump(const princess *p, FILE *f);
princess new_princess(board b);
void free_princess(princess *p);
