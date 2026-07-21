#ifndef BN_TCL_H_
#define BN_TCL_H_

#include <stdint.h>
#if defined(TCL_NO_TOMMATH_H)
    typedef size_t mp_digit;
    typedef int mp_sign;
#   define MP_ZPOS       0   /* positive integer */
#   define MP_NEG        1   /* negative */
    typedef int mp_ord;
#   define MP_LT        -1   /* less than */
#   define MP_EQ         0   /* equal to */
#   define MP_GT         1   /* greater than */
    typedef int mp_err;
#   define MP_OKAY       0   /* no error */
#   define MP_ERR        -1  /* unknown error */
#   define MP_MEM        -2  /* out of mem */
#   define MP_VAL        -3  /* invalid input */
#   define MP_ITER       -4  /* maximum iterations reached */
#   define MP_BUF        -5  /* buffer overflow, supplied buffer too small */
    typedef int mp_order;
#   define MP_LSB_FIRST -1
#   define MP_MSB_FIRST  1
    typedef int mp_endian;
#   define MP_LITTLE_ENDIAN  -1
#   define MP_NATIVE_ENDIAN  0
#   define MP_BIG_ENDIAN     1
#   define MP_DEPRECATED_PRAGMA(s) /* nothing */
#   define MP_WUR            /* nothing */
#   define mp_iszero(a) ((a)->used == 0)
#   define mp_isneg(a)  ((a)->sign != 0)

    /* the infamous mp_int structure */
#   ifndef MP_INT_DECLARED
#	define MP_INT_DECLARED
	typedef struct mp_int mp_int;
#   endif
    struct mp_int {
	int used, alloc;
	mp_sign sign;
	mp_digit *dp;
};

#elif !defined(BN_H_) /* If BN_H_ already defined, don't try to include tommath.h again. */
#   include "tommath.h"
#endif
#include "tclTomMathDecls.h"  /* IWYU pragma: export */

#endif
