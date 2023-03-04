#pragma once

typedef char function;
enum {
	// integer literals
	FI0 = '0',
	FI1 = '1',
	FI2 = '2',
	FI3 = '3',
	FI4 = '4',
	FI5 = '5',
	FI6 = '6',
	FI7 = '7',
	FI8 = '8',
	FI9 = '9',

	// mode changing functions
	FSTR = '\"',
	FARY = '[',
	FARYEND = ']',

	// stack manipulation
	FDUP = '.',
	FDUP2 = ':',
	FPOP = ',',
	FPOP2 = ';',
	FDUPN = '#',
	FPOPN = '@',
	FSWAP = '$',
	FSTACKLEN = 'C',

	// directions
	FNOPH = '-',
	FNOPV = '|',
	FRIGHT = '>',
	FLEFT = '<',
	FUP = '^',
	FDOWN = 'v',
	FSPEEDUP = '{',
	FSLOWDOWN = '}',
	FJUMP1 = 'J',
	FJUMPN = 'j',
	FGETPOS = 'r',
	// FRETURN = 'R',

	// conditionals
	FIFR = '?',
	FIFL = 'I',
	FIFPOP = 'T',
	FFORKL = 'H', // hire them
	FFORKR = 'h', // hire them
	FJOIN1 = 'F', // fire
	FJOINN = 'f', // fire n


	// math
	FADD = '+',
	FSUB = '_', // `-` is used by FNOPH already.
	FMUL = '*',
	FDIV = '/',
	FMOD = '%',
	FRAND = 'R',
	FINC = 'X',
	FDEC = 'x',

	// comparisons
	FEQL = '=',
	FLTH = 'l',
	FGTH = 'g',
	FCMP = 'c',
	FNOT = '!',

	// integer functions
	FCHR = 'A',
	FORD = 'a',
	FTOS = 's',
	FTOI = 'i',

	// ary functions
	FLEN = 'L',
	FGET = 'G',
	FSET = 'S',

	// io
	FPRINTNL = 'P',
	FPRINT = 'p',
	FDUMPVALNL = 'N',
	FDUMPVAL = 'n',
	FDUMPQ = 'D',
	FDUMP = 'd',
	FQUIT0 = 'Q',
	FQUIT = 'q',
	FGETS = 'U',

	DEBUG_SIGNIFIER_FUNCTION = 'o',
};

#define MAX_ARGC 4

char *strchr(const char *c, int);

static inline int arity(function f) {
	if (strchr("0123456789.:;$-|><^v{}DdQU\"JRC", f)) return 0;
	if (strchr(",#@!aAsi?ITPpqNnjxX", f)) return 1;
	if (strchr("+_*/%=lgc", f)) return 2;
	if (strchr("G", f)) return 3;
	if (strchr("S", f)) return 4;
	return -1;
}