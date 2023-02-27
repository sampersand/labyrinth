#pragma once
#include <assert.h>
#include "shared.h"

typedef long long VALUE;
typedef long long integer;

typedef struct {
	int len, cap, rc;
	VALUE *items;
} array;

extern const array *empty_array;

static inline int isint(VALUE v) {
	return v & 1;
}

static inline VALUE i2v(integer i) {
	return (i << 1) | 1;
}

static inline VALUE a2v(array *a) {
	assert(!isint((VALUE) a));
	return (VALUE) a;
}

static inline array *ARY(VALUE v) {
	assert(!isint(v));
	return (array *) v;
}

static inline integer INT(VALUE v) {
	assert(isint(v));
	return v >> 1;
}


static inline integer a2i(const array *a);
static inline integer v2i(VALUE v) {
	return isint(v) ? INT(v) : a2i(ARY(v));
}

static inline integer a2i(const array *a) {
	ensure(a->len == 1, "can only convert arrays of length 1 to ints, not length %d", a->len);
	return v2i(a->items[0]);
}

static inline int is_truthy(VALUE v) {
	return v > 1;
}

static inline int len(VALUE v) {
	return isint(v) ? 1 : ARY(v)->len;
}

integer parse_int(VALUE v);
array *to_string(VALUE v);
array *aalloc(int size);
void afree(array *a);
void vdump(VALUE v, FILE *f);
void apush(array *a, VALUE v);
void print(VALUE v, FILE *f);
VALUE apop(array *a);
VALUE map(VALUE l, VALUE r, integer (*fn)(integer, integer));
static inline integer _v_add(integer l, integer r) { return l + r; }
static inline integer _v_sub(integer l, integer r) { return l - r; }
static inline integer _v_mul(integer l, integer r) { return l * r; }
static inline integer _v_div(integer l, integer r) { return l / r; }
static inline integer _v_mod(integer l, integer r) { return l % r; }
static inline integer _v_lth(integer l, integer r) { return l < r; }
static inline integer _v_gth(integer l, integer r) { return l > r; }
static inline integer _v_cmp(integer l, integer r) { return l < r ? -1 : l == r ? 0 : 1; }

static inline VALUE vadd(VALUE l, VALUE r) { return map(l, r, _v_add); }
static inline VALUE vsub(VALUE l, VALUE r) { return map(l, r, _v_sub); }
static inline VALUE vmul(VALUE l, VALUE r) { return map(l, r, _v_mul); }
static inline VALUE vdiv(VALUE l, VALUE r) { return map(l, r, _v_div); }
static inline VALUE vmod(VALUE l, VALUE r) { return map(l, r, _v_mod); }
int eql(VALUE l, VALUE r);
static inline VALUE vlth(VALUE l, VALUE r) { return map(l, r, _v_lth); }
static inline VALUE vgth(VALUE l, VALUE r) { return map(l, r, _v_gth); }
static inline VALUE vcmp(VALUE l, VALUE r) { return map(l, r, _v_cmp); }


static inline VALUE clone(VALUE v) {
	if (!isint(v)) ARY(v)->rc++;
	return v;
}

static inline void drop(VALUE v) {
	if (!isint(v)) afree(ARY(v));
}

static inline VALUE chr(VALUE v) {
	if (isint(v)) {
		array *a = aalloc(1);
		a->items[a->len++] = v;
		return a2v(a);
	}
	return clone(v);
}

static inline VALUE ord(VALUE v) {
	die("todo");
	// if (isint(v)) {
	// 	array *a = aalloc(1);
	// 	a->items[a->len++] = v;
	// 	return a2v(a);
	// }
	// return clone(v);
}
// 	case FCHR: push(p, chr(args[0])); break;
// 	case FORD: push(p, ord(args[0])); break;
