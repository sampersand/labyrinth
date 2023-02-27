#pragma once

#include <stdio.h>
#include <stdlib.h>

#define ensure(cond, ...) do { if (!(cond)) die(__VA_ARGS__); } while(0)
#define die(...) (fprintf(stderr, __VA_ARGS__),exit(1))

#if defined(__has_c_attribute) && __has_c_attribute(fallthrough)
# define FALLTHROUGH [[fallthrough]];
#elif defined(__cplusplus) && __cplusplus >= 201703L
# define FALLTHROUGH [[fallthrough]];
#else
# define FALLTHROUGH 
#endif
