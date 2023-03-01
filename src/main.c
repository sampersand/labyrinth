#include "princess.c"
#include "value.c"

int main() {
	char *input = strdup(
"'1000000>.?.s,v\n"\
"        ^}D{_1<"

"'10Dv\n"\
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
