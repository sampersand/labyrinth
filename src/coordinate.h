#pragma once
#include <stdio.h>

typedef struct { int x, y; } coordinate;

const coordinate ZERO = {0,0},
	UP = {0,-1},
	DOWN = {0,1},
	LEFT = {-1,0},
	RIGHT = {1,0};

static inline coordinate add_coordinates(coordinate c1, coordinate c2) {
	return (coordinate) { c1.x + c2.x, c1.y + c2.y };
}

static inline coordinate subtract_coordinates(coordinate c1, coordinate c2) {
	return (coordinate) { c1.x - c2.x, c1.y - c2.y };
}

static inline coordinate direction(coordinate c) {
	return (coordinate) {
		c.x == 0 ? 0 : c.x < 0 ? -1 : 1,
		c.y == 0 ? 0 : c.y < 0 ? -1 : 1,
	};
}

static inline coordinate rotate_left(coordinate c) {
	return (coordinate) {c.y, -c.x};
}

static inline coordinate rotate_right(coordinate c) {
	return (coordinate) {-c.y, c.x};
}

static inline void dump_coordinate(coordinate c, FILE *f) {
	fprintf(f, "(%d, %d)", c.x, c.y);
}
