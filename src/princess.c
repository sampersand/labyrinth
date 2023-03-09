#include "princess.h"
#include <string.h>
#include <ctype.h>
#include "coordinate.h"

princess new_princess(board b) {
	princess p = {
		.board = b,
		.options = 0,
		.nhm = 1,
		.hmcap = 4,
		.handmaidens = malloc(sizeof(handmaiden *) * 4)
	};
	p.handmaidens[0] = new_handmaiden(ZERO, RIGHT, aalloc(16));
	return p;
}

void free_princess(princess *p) {
	free_board(&p->board);
	for (int i = 0; i < p->nhm; ++i)
		free_handmaiden(p->handmaidens[i]);
	free(p->handmaidens);
}

void dump(const princess *p, FILE *out) {
	fputs("Princess(", out);

	for (int i = 0; i < p->nhm; ++i) {
		if (i) fputs(", ", out);
		dump_handmaiden(p->handmaidens[i], out);
	}

	fputc(')', out);
}

static int cmp_int(const void *l, const void *r) {
	return *(int *)l - *(int *)r;
}

static void print_board(const board *b, handmaiden **hms, int nhms) {
	int indices[nhms], nindices;

	for (int col = 0; col < b->cols; ++col) {
		nindices = 0;

		for (int i = 0; i < nhms; ++i)
			if (hms[i]->position.y == col)
				indices[nindices++] = hms[i]->position.x;

		if (!nindices) {
			puts(b->fns[col]);
			continue;
		}

		qsort(indices, nindices, sizeof(int), cmp_int);
		for (int i = 0; i < nindices; ++i) {
			if (i && indices[i] == indices[i-1]) continue;
			int start = (i == 0 ? 0 : indices[i - 1] + 1);
			printf("%.*s\033[7m%c\033[0m",
				indices[i] - start, b->fns[col] + start, b->fns[col][indices[i]]);
		}
		puts(b->fns[col] + indices[nindices - 1] + 1);
	}
}
static void debug_print_board(princess *p) {
	fputs("\e[1;1H\e[2J", stdout); // clear screen

	if (p->options & DEBUG_PRINT_BOARD)
		print_board(&p->board, p->handmaidens, p->nhm);

	if (p->options & DEBUG_PRINT_STACKS)
		for (int i = 0; i < p->nhm; ++i) {
			printf("maiden %d: ", i);
			dump_value(a2v(p->handmaidens[i]->stack), stdout);
			putchar('\n');
		}
}

#ifdef PRINCESS_ISNT_WORKING_FOR_ME
#include <Windows.h>
static void sleep_for_ms(int ms){ Sleep(ms); }
#else
#include <time.h>
static void sleep_for_ms(int ms) {
	nanosleep(&(struct timespec) { 0, ms * 1000000 }, 0);
}
#endif

void hire_handmaiden(princess *p, handmaiden *hm) {
	if (p->nhm == p->hmcap) grow(p->handmaidens, p->hmcap);
	p->handmaidens[p->nhm++] = hm;
}

void fire_handmaiden(princess *p, int i) {
	assume(i < p->nhm);
	free_handmaiden(p->handmaidens[i]);

	p->handmaidens[i] = p->handmaidens[--p->nhm];
}

#ifndef SLEEP_MS
#define SLEEP_MS 25
#endif
int play(princess *p) {
	for (int i = 0; i < p->nhm; ++i)
		unstep(p->handmaidens[i]);

	while (1) {
		int nhm = p->nhm; // store it so if it's updated during running we won't do more work.

		for (int i = 0; i < nhm; ++i) {
			if (p->handmaidens[i]->steps_ahead) {
				--p->handmaidens[i]->steps_ahead;
				continue;
			}
			int status = do_chores(p->handmaidens[i], move(p->handmaidens[i], &p->board), p);
			if (status == RUN_CONTINUE) continue;
			if (p->nhm == 1) return EXIT2INT(status);
			fire_handmaiden(p, i);
			i--;
			nhm--;
		}
		if (p->options & DEBUG)
			debug_print_board(p), sleep_for_ms(SLEEP_MS);
	}

	return 0;
}
