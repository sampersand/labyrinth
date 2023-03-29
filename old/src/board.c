#include "board.h"
#include "shared.h"
#include <stdlib.h>
#include <string.h>

board create_board(char *input) {
	int cap = 8, row;
	char *line;
	board b = {
		.rows = 0,
		.cols = 0,
		.fns = malloc(sizeof(function *) * cap),	
	};

	while ((line = strsep(&input, "\n"))) {
		if (b.cols == cap) grow(b.fns, cap);
		b.fns[b.cols++] = (function *) line;
		if (b.rows < (row = strlen(line))) b.rows = row;
	}

	return b;
}

void free_board(board *b) {
	for (int i = 0; i < b->rows; ++i)
		free(b->fns[i]);
}
