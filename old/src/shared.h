#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

typedef unsigned uint;
typedef long long integer;

static inline integer c2i(char c) {return c - '0'; }
#define ensure(cond, ...) do { if (!(cond)) die(__VA_ARGS__); } while(0)
#define die(...) (fprintf(stderr, __VA_ARGS__),exit(1))
#define grow(stack, cap) ((stack) = realloc((stack), sizeof(*(stack)) * ((cap) *= 2)))

#define likely(cond) cond
// __builtin_expect
#ifndef NDEBUG
# define assume assert
#elif defined(__has_builtin) && __has_builtin(__builtin_assume)
# define assume(cond) __builtin_assume(cond)
#endif

#if defined(__has_c_attribute) && __has_c_attribute(fallthrough)
# define FALLTHROUGH [[fallthrough]];
#elif defined(__cplusplus) && __cplusplus >= 201703L
# define FALLTHROUGH [[fallthrough]];
#else
# define FALLTHROUGH 
#endif
