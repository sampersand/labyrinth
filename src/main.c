#include "princess.c"
#include "value.c"

#define do_or(expr, msg) \
	if (expr) fprintf(stderr, "unable to "msg" '%s': ", file), perror(0), die("");
char *read_file(const char *file) {
	FILE *f;
	long len;
	char *buf;
	
	do_or(!(f = fopen(file, "r")), "open");
	do_or(fseek(f, 0, SEEK_END), "seek to end of");
	do_or((len = ftell(f)) < 0, "get the length of");
	do_or(fseek(f, 0, SEEK_SET), "seek to start of");
	do_or(!(buf = malloc(len)), "allocate memory");
	do_or((fread(buf, 1, len, f), feof(f)), "read contents of");
	do_or(fclose(f), "close");

	return buf;
}
#undef do_or

int main(int c, char **a) {
	if (c < 3 || a[1][0] != '-' || strlen(a[1]) != 2)
		die("usage: %s (-f file | -e 'expr') [ints to put on the stack]\n", a[0]);

	char *input = a[1][1] == 'e' ? a[2] : read_file(a[2]);
	princess p = new_princess(create_board(input));
	for (int i = 3; i < c; ++i)
		push(&p, i2v(atoi(a[i])));

	return play(&p);
}
