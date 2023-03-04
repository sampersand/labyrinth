#include "princess.h"
#include <string.h>
#include <ctype.h>
#include "coordinate.h"

princess new_princess(board b) {
	princess p = {
		.board = b,
		.debug = 0,
		.nhm = 1,
		.hmcap = 4,
		.handmaidens = malloc(sizeof(handmaiden) * 4)
	};
	p.handmaidens[0] = (handmaiden) {
		.velocity = RIGHT,
		.position = ZERO,
		.stack = aalloc(16)
	};
	return p;
}

void free_princess(princess *p) {
	free_board(&p->board);
	for (int i = 0; i < p->nhm; ++i)
		free_handmaiden(&p->handmaidens[i]);
	free(p->handmaidens);
}

void dump(const princess *p, FILE *out) {
	fputs("Princess(", out);

	for (int i = 0; i < p->nhm; ++i) {
		if (i) fputs(", ", out);
		dump_handmaiden(&p->handmaidens[i], out);
	}

	fputc(')', out);
}

static void print_board(const board *b, coordinate invert) {
	for (int i = 0; i < b->cols; ++i) {
		if (i != invert.y) puts(b->fns[i]);
		else printf("%.*s\033[7m%c\033[0m%s\n",
			invert.x, b->fns[i], b->fns[i][invert.x], b->fns[i] + invert.x + 1);
	}
}
static void debug_print_board(princess *p) {
	puts("\e[1;1H\e[2J"); // clear screen
	print_board(&p->board, p->handmaidens[0].position);
	for (int i = 0; i < p->nhm; ++i)
		dump_value(a2v(p->handmaidens[i].stack), stdout),
		putchar('\n');
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

static void fire_handmaiden(princess *p, int i) {
	assume(i && i < p->nhm);
	die("todo");
}

int play(princess *p) {
	for (int i = 0; i < p->nhm; ++i)
		unstep(&p->handmaidens[i]);

	while (1) {
		if (p->debug)
			debug_print_board(p), sleep_for_ms(25);

		int nhm = p->nhm; // store it so if it's updated during running we won't do more work.
		for (int i = 0; i < nhm; ++i) {
			int status = do_chores(&p->handmaidens[i], move(&p->handmaidens[i], &p->board), p);
			if (status == RUN_CONTINUE) continue;
			if (!i) return EXIT2INT(status);
			fire_handmaiden(p, i);
			i--;
			nhm--;
		}
	}

	return 0;
}
