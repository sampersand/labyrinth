#include "princess.c"
#include "value.c"
#embed "foo"
int main() {
	char *input = strdup(
"'10v\n"\
"v--<\n"\
"v      v-----_1$-----<   factorial function\n"\
"|      |             |\n"\
">--1$-->--.--?--$:*--^\n"\
"             |\n"\
"     Q-Ps,---<"
);
	princess p = new_princess(create_board(input));

	return play(&p);
}
