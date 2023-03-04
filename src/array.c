#include "array.h"

#define MAX_DIMS 16
#define NUM_SHORTLENS (sizeof(uint *) / sizeof(short))

typedef struct {
	uint rc: (CHAR_BIT * sizeof(uint)) - (MAX_DIMS >> 2);
	uint dims: MAX_DIMS >> 2;
	union {
		uint *alloc;
		short embed[NUM_EMBED_LENS];
	} lens;
	union {
		void *items;
		char string[STR_EMBED_LEN + 1];
	};
} array;

array *alloc_array(uint dims) {
	expect(dims <= MAX_DIMS, "too many dimensions (%d) given; max: %d", dims, MAX_DIMS);

	array *a = malloc(sizeof(array));
	a->rc = 1;
	a->dims = dims;
	a->lens.alloc = 0; // will also set `embed` to 0 as well.
	a->items = 0;
}

array *alloc_array(uint dims);
array *alloc_string(uint len);
