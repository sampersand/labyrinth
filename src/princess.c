#include "princess.h"
#include <string.h>
#include <ctype.h>
#include "vm.h"

function **create_board(char *input) {
	int len = 0, cap = 8;
	char *line, fn;
	function **board = malloc(sizeof(function *) * cap);

	while ((line = strsep(&input, "\n"))) {
		if (len == cap) board = realloc(board, sizeof(function *) * (cap *= 2));
		board[len++] = (function *) line;
	}

	return realloc(board, sizeof(function*) * len);
}

princess new_princess(function **board) {
	return (princess) {
		.board = board,
		.velocity = RIGHT,
		.position = ZERO,
		.stack = aalloc(16),
	};
}

void free_princess(princess *p) {
	free(p->board);
	afree(p->stack);
	free(p);
}

void dump(const princess *p, FILE *out) {
	fprintf(out, "Princess(position=(%d,%d), velocity=(%d,%d), stack=[",
		p->position.x, p->position.y,
		p->velocity.x, p->velocity.y
	);

	for (int i = 0; i < p->stack->len; ++i) {
		if (i) fputs(", ", out);
		dump_value(p->stack->items[i], out);
	}

	fputs("])", out);
}

void push(princess *p, VALUE v) {
	if (p->stack->len == p->stack->cap)
		p->stack->items = realloc(p->stack->items, sizeof(VALUE) * (p->stack->cap *= 2));

	p->stack->items[p->stack->len++] = v;
}

VALUE popn(princess *p, int n) {
	if (n == 1) return pop(p);
	ensure(n, "indexing starts at 1");
	ensure(n <= p->stack->len, "index %d is out of boudns for stack len %d", n, p->stack->len);

	VALUE v = p->stack->items[p->stack->len - n];

	do
		p->stack->items[p->stack->len - n] = p->stack->items[p->stack->len - n+1];
	while (n--);
	p->stack->len--;
	return v;
}

int play(princess *p) {
	unstep(p);

	while (1) {
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
	drop(popn(p, n));
}

static VALUE scan_str(princess *p) {
	array *a = aalloc(8);
	char c;

	while ((c = move(p)) != FSTR) {
		if (!c) die("unterminated string");
		apush(a, i2v(c));
	}

	return a2v(a);
}

static VALUE scan_int(princess *p) {
	int sign = 1;
	integer i = 0;

	char c = move(p);
	if (c == '-') sign = -1;
	else if (!isdigit(c)) return 0;
	else i = c - '0';

	while (isdigit(c = move(p)))
		i *= 10, i += c-'0';

	if (c) unstep(p);

	return i2v(i * sign);
}

int run(princess *p, function f) {
	int status = RUN_CONTINUE;
	VALUE args[MAX_ARGC];

	for (int i = 0; i < arity(f); ++i)
		args[i] = pop(p);

	switch (f) {
	case FI0: case FI1: case FI2:
	case FI3: case FI4: case FI5:
	case FI6: case FI7: case FI8: case FI9:
		push(p, i2v(f - '0'));
		break;

	case FSTR: push(p, scan_str(p)); break;
	case FINT: push(p, scan_int(p)); break;
	case FARY: die("todo: func for `[`");
	case FARYEND: die("todo: func for `]`");

	// stack manipulation
	case FDUP:  _dupn(p, 1); break;
	case FDUP2: _dupn(p, 2); break;
	case FDUPN: _dupn(p, v2i(args[0])); break;
	case FPOP:  break; // we already popped the argument off.
	case FPOP2: _popn(p, 2); break;
	case FPOPN: _popn(p, v2i(args[0])); break;
	case FSWAP: push(p, popn(p, 2)); break;

	// directions
	case FNOPH: case FNOPV: break;
	case FRIGHT: p->velocity = RIGHT; break;
	case FLEFT: p->velocity = LEFT; break;
	case FUP: p->velocity = UP; break;
	case FDOWN: p->velocity = DOWN; break;
	case FSPEEDUP: p->velocity = add_coordinates(p->velocity, direction(p->velocity)); break;
	case FSLOWDOWN: p->velocity = subtract_coordinates(p->velocity, direction(p->velocity)); break;

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
		if (f == FPRINTNL)
			fputc('\n', stdout);
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
