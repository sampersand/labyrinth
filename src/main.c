#include "princess.c"
#include "board.c"
#include "value.c"
#include "handmaiden.c"

#define do_or(expr, msg) \
	if (expr) fprintf(stderr, "unable to "msg" '%s': ", file), perror(0), die("");
char *read_file(const char *file) {
	FILE *f;
	size_t len;
	char *buf;
	
	do_or(!(f = fopen(file, "r")), "open");
	do_or(fseek(f, 0, SEEK_END), "seek to end of");
	do_or((len = ftell(f)) < 0, "get the length of");
	do_or(fseek(f, 0, SEEK_SET), "seek to start of");
	do_or(!(buf = malloc(len + 1)), "allocate memory");
	do_or((len = fread(buf, 1, len, f), feof(f)), "read contents of");
	buf[len] = 0;
	do_or(fclose(f), "close");
	fflush(stdout);

	return buf;
}
#undef do_or

int main(int c, char **a) {
	srandomdev();
	if (c < 3 || a[1][0] != '-' || strlen(a[1]) != 2)
		die("usage: %s (-f file | -e 'expr') [ints to put on the stack]\n", a[0]);

	char *input = a[1][1] == 'e' ? a[2] : read_file(a[2]);
	princess p = new_princess(create_board(input));

	int i = 3;
	if (c >= 4 && a[3][0] == '-' && a[3][1] == 'd' && a[3][2] == '\0')
		p.options = DEBUG | DEBUG_PRINT_BOARD, ++i;
	while (i < c) push(p.handmaidens[0], i2v(atoi(a[i++])));

	return play(&p);
}
