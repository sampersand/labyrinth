#include "princess.h"
#include <string.h>
#include <ctype.h>
#include "vm.h"

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

void dump(const princess *p, FILE *out) {
	fputs("Princess(position=", out);
	dump_coordinate(p->velocity, out);
	fputs(", velocity=", out);
	dump_coordinate(p->position, out);
	fputs(", stack=[", out);

	for (int i = 0; i < p->stack->len; ++i) {
		if (i) fputs(", ", out);
		dump_value(p->stack->items[i], out);
	}

	fputs("])", out);
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
	dump_value(a2v(p->stack), stdout);
	putchar('\n');
	print_board(&p->board, p->position);
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

int play(princess *p) {
	unstep(p);

	while (1) {
		if (p->debug)
			debug_print_board(p), sleep_for_ms(25);

		int status = run(p, move(p));
		if (status != RUN_CONTINUE)
			return EXIT2INT(status);
	}

	return 0;
}

static void _dupn(princess *p, int n) {
	push(p, dupn(p, n));
}

static void _popn(princess *p, int n) {
	drop(apop(p->stack, n));
}

VALUE scan_str(princess *p) {
	array *a = aalloc(8);
	char c;

	while ((c = move(p)) != FSTR) {
		if (!c) die("unterminated string");
		apush(a, i2v(c));
	}

	return a2v(a);
}

VALUE scan_int(princess *p) {
	int sign = 1;
	integer i = 0;

	char c = move(p);
	if (c == '-') sign = -1;
	else if (!isdigit(c)) return 0;
	else i = c2i(c);

	while (isdigit(c = move(p)))
		i *= 10, i += c2i(c);

	if (c) unstep(p);

	return i2v(i * sign);
}

int run(princess *p, function f) {
	int status = RUN_CONTINUE;
	VALUE args[MAX_ARGC];

	for (int i = 0; i < arity(f); ++i)
		args[i] = pop(p);

	switch (f) {
	case FRAND: push(p, i2v(random())); break;
	case FI0: case FI1: case FI2:
	case FI3: case FI4: case FI5:
	case FI6: case FI7: case FI8: case FI9:
		unstep(p);
		push(p, scan_int(p));
		break;

	case FSTR: push(p, scan_str(p)); break;
	case FARY: die("todo: func for `[`");
	case FARYEND: die("todo: func for `]`");

	// stack manipulation
	case FDUP:  _dupn(p, 1); break;
	case FDUP2: _dupn(p, 2); break;
	case FDUPN: _dupn(p, v2i(args[0])); break;
	case FPOP:  break; // we already popped the argument off.
	case FPOP2: _popn(p, 2); break;
	case FPOPN: _popn(p, v2i(args[0])); break;
	case FSWAP: push(p, apop(p->stack, 2)); break;
	case FSTACKLEN: push(p, i2v(p->stack->len)); break;

	// directions
	case FNOPH: case FNOPV: break;
	case FRIGHT: p->velocity = RIGHT; break;
	case FLEFT: p->velocity = LEFT; break;
	case FUP: p->velocity = UP; break;
	case FDOWN: p->velocity = DOWN; break;
	case FSPEEDUP: p->velocity = add_coordinates(p->velocity, direction(p->velocity)); break;
	case FSLOWDOWN: {
		coordinate old_velo = p->velocity;
		p->velocity = subtract_coordinates(p->velocity, direction(p->velocity));
		if (coordinate_equal(p->velocity, ZERO))
			p->velocity = subtract_coordinates(p->velocity, direction(p->velocity));
		break;
	}
	case FJUMP1: step(p); break;
	case FJUMPN: for (int i = v2i(args[0]); i > 0; --i) step(p); break;

	// conditionals
	case FIFR:
	case FIFL:
		if (!is_truthy(args[0]))
			p->velocity = (f==FIFR ? rotate_right : rotate_left)(p->velocity);
		break;
	case FIFPOP:
		if (!is_truthy(args[0])) pop(p);
		break;


	// math
	case FADD: push(p, vadd(args[1], args[0])); break;
	case FSUB: push(p, vsub(args[1], args[0])); break;
	case FMUL: push(p, vmul(args[1], args[0])); break;
	case FDIV: push(p, vdiv(args[1], args[0])); break;
	case FMOD: push(p, vmod(args[1], args[0])); break;
	case FINC: push(p, vadd(args[0], i2v(1))); break;
	case FDEC: push(p, vsub(args[0], i2v(1))); break;

	// comparisons
	case FEQL: push(p, i2v(eql(args[1], args[0]))); break;
	case FLTH: push(p, vlth(args[1], args[0])); break;
	case FGTH: push(p, vgth(args[1], args[0])); break;
	case FCMP: push(p, vcmp(args[1], args[0])); break;
	case FNOT: push(p, i2v(!is_truthy(args[0]))); break;

	// integer functions
	case FCHR: push(p, chr(args[0])); break;
	case FORD: push(p, ord(args[0])); break;
	case FTOS: push(p, a2v(to_string(args[0]))); break;
	case FTOI: push(p, i2v(parse_int(args[0]))); break;

	// Array functions
	case FLEN:
		push(p, i2v(len(args[0])));
		break;
	case FGET:
	case FSET:
		die("todo: get/set");

	// I/O
	case FPRINTNL:
	case FPRINT:
		print(args[0], stdout);
		if (f == FPRINTNL) putchar('\n');
		break;
	case FDUMPVALNL:
	case FDUMPVAL:
		dump_value(args[0], stdout);
		if (f == FDUMPVALNL) putchar('\n');
		break;

	case FDUMPQ:
	case FDUMP:
		dump(p, stdout);
		putchar('\n');
		fflush(stdout);
		if (f != FDUMPQ) break;
		FALLTHROUGH
	case 'Q': status = INT2EXIT(0); break;
	case 'q': status = INT2EXIT(v2i(args[0])); break;
	case 'U': die("todo: getc");
	default:
		die("unknown function '%c' (%d) (%d,%d)", f, (int) f, p->position.x, p->position.y);
	}

	for (int i = 0; i < arity(f); ++i)
		drop(args[i]);

	return status;
}
