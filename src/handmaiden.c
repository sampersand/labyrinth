#include "handmaiden.h"
#include "princess.h"

void dump_handmaiden(const handmaiden *hm, FILE *out) {
	fputs("{pos=", out);
	dump_coordinate(hm->position, out);
	fputs(", velo=", out);
	dump_coordinate(hm->velocity, out);
	fputs(", stack=", out);
	dump_value(a2v(hm->stack), out);
	fputc('}', out);
}


int isdigit(int);

VALUE scan_str(handmaiden *hm, const board *b) {
	array *a = aalloc(8);

	for (char c; (c = move(hm, b)) != FSTR; hm->steps_ahead++) {
		if (!c) die("unterminated string");
		apush(a, i2v(c));
	}


	return a2v(a);
}

VALUE scan_int(handmaiden *hm, const board *b) {
	int sign = 1;
	integer i = 0;

	hm->steps_ahead++;
	char c = move(hm, b);
	if (c == '-') sign = -1;
	else if (!isdigit(c)) return 0;
	else i = c2i(c);

	for (; isdigit(c = move(hm, b)); hm->steps_ahead++)
		i *= 10, i += c2i(c);

	if (c) unstep(hm);

	return i2v(i * sign);
}

static void _dupn(handmaiden *hm, int n) {
	push(hm, dupn(hm, n));
}

static void _popn(handmaiden *hm, int n) {
	drop(apop(hm->stack, n));
}


int do_chores(handmaiden *hm, function f, princess *p) {
	int status = RUN_CONTINUE;
	VALUE args[MAX_ARGC];

	for (int i = 0; i < arity(f); ++i)
		args[i] = pop(hm);

	switch (f) {
	case FRAND: push(hm, i2v(random())); break;
	case FI0: case FI1: case FI2:
	case FI3: case FI4: case FI5:
	case FI6: case FI7: case FI8: case FI9:
		unstep(hm);
		push(hm, scan_int(hm, &p->board));
		break;

	case FSTR: push(hm, scan_str(hm, &p->board)); break;
	case FARY: die("todo: func for `[`");
	case FARYEND: die("todo: func for `]`");

	// stack manipulation
	case FDUP:  _dupn(hm, 1); break;
	case FDUP2: _dupn(hm, 2); break;
	case FDUPN: _dupn(hm, v2i(args[0])); break;
	case FPOP:  break; // we already popped the argument off.
	case FPOP2: _popn(hm, 2); break;
	case FPOPN: _popn(hm, v2i(args[0])); break;
	case FSWAP: push(hm, apop(hm->stack, 2)); break;
	case FSTACKLEN: push(hm, i2v(hm->stack->len)); break;

	// directions
	case FNOPH: case FNOPV: break;
	case FRIGHT: hm->velocity = RIGHT; break;
	case FLEFT: hm->velocity = LEFT; break;
	case FUP: hm->velocity = UP; break;
	case FDOWN: hm->velocity = DOWN; break;
	case FSPEEDUP: hm->velocity = add_coordinates(hm->velocity, direction(hm->velocity)); break;
	case FSLOWDOWN: {
		coordinate old_velo = hm->velocity;
		hm->velocity = subtract_coordinates(hm->velocity, direction(hm->velocity));
		if (coordinate_equal(hm->velocity, ZERO))
			hm->velocity = subtract_coordinates(hm->velocity, direction(hm->velocity));
		break;
	}
	case FJUMP1: step(hm); break;
	case FJUMPN: for (int i = v2i(args[0]); i > 0; --i) step(hm); break;

	// conditionals
	case FIFR:
	case FIFL:
		if (!is_truthy(args[0]))
			hm->velocity = (f==FIFR ? rotate_right : rotate_left)(hm->velocity);
		break;
	case FIFPOP:
		if (!is_truthy(args[0])) pop(hm);
		break;


	// math
	case FADD: push(hm, vadd(args[1], args[0])); break;
	case FSUB: push(hm, vsub(args[1], args[0])); break;
	case FMUL: push(hm, vmul(args[1], args[0])); break;
	case FDIV: push(hm, vdiv(args[1], args[0])); break;
	case FMOD: push(hm, vmod(args[1], args[0])); break;
	case FINC: push(hm, vadd(args[0], i2v(1))); break;
	case FDEC: push(hm, vsub(args[0], i2v(1))); break;

	// comparisons
	case FEQL: push(hm, i2v(eql(args[1], args[0]))); break;
	case FLTH: push(hm, vlth(args[1], args[0])); break;
	case FGTH: push(hm, vgth(args[1], args[0])); break;
	case FCMP: push(hm, vcmp(args[1], args[0])); break;
	case FNOT: push(hm, i2v(!is_truthy(args[0]))); break;

	// integer functions
	case FCHR: push(hm, chr(args[0])); break;
	case FORD: push(hm, ord(args[0])); break;
	case FTOS: push(hm, a2v(to_string(args[0]))); break;
	case FTOI: push(hm, i2v(parse_int(args[0]))); break;

	// Array functions
	case FLEN:
		push(hm, i2v(len(args[0])));
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
	case FQUIT0: status = INT2EXIT(0); break;
	case FQUIT: status = INT2EXIT(v2i(args[0])); break;
	case FGETS: die("todo: getc");

	case FFORKL:
	case FFORKR:
		hire_handmaiden(p, 
			new_handmaiden(
				hm->position,
				(f == FFORKL ? rotate_left : rotate_right)(hm->velocity),
				ARY(duplicate(a2v(hm->stack)))
			)
		);
		break;
	// FFORKL = 'H', // hire them
	// FFORKR = 'R', // hire them
	// FJOIN1 = 'F', // fire
	// FJOINN = 'f', // fire n

	default:
		die("unknown function '%c' (%d) (%d,%d)", f, (int) f, hm->position.x, hm->position.y);
	}

	for (int i = 0; i < arity(f); ++i)
		drop(args[i]);

	return status;
}
