/*
 * tclArithSeries.c --
 *
 *     This file contains the ArithSeries concrete abstract list
 *     implementation. It implements the inner workings of the lseq command.
 *
 * Copyright © 2022 Brian S. Griffin.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include <math.h>

/*
 * The structure below defines the arithmetic series Tcl object type by
 * means of procedures that can be invoked by generic object code.
 *
 * The arithmetic series object is a special case of Tcl list representing
 * an interval of an arithmetic series in constant space.
 *
 * The arithmetic series is internally represented with three integers,
 * *start*, *end*, and *step*, Where the length is calculated with
 * the following algorithm:
 *
 * if RANGE == 0 THEN
 *   ERROR
 * if RANGE > 0
 *   LEN is (((END-START)-1)/STEP) + 1
 * else if RANGE < 0
 *   LEN is (((END-START)-1)/STEP) - 1
 *
 * And where the equivalent's list I-th element is calculated
 * as:
 *
 * LIST[i] = START + (STEP * i)
 *
 * Zero elements ranges, like in the case of START=10 END=10 STEP=1
 * are valid and will be equivalent to the empty list.
 */

/*
 * The structure used for the ArithSeries internal representation.
 * Note that the len can in theory be always computed by start,end,step
 * but it's faster to cache it inside the internal representation.
 */

typedef struct {
    Tcl_Size len;
    Tcl_Obj **elements;
    int isDouble;
    Tcl_Size refCount;
} ArithSeries;

typedef struct {
    ArithSeries base;
    Tcl_WideInt start;
    Tcl_WideInt step;
} ArithSeriesInt;

typedef struct {
    ArithSeries base;
    double start;
    double step;
    unsigned precision;		/* Number of decimal places to render. */
} ArithSeriesDbl;

/* Forward declarations. */

static int		TclArithSeriesObjIndex(TCL_UNUSED(Tcl_Interp *),
			    Tcl_Obj *arithSeriesObj, Tcl_Size index,
			    Tcl_Obj **elemObj);
static Tcl_Size		ArithSeriesObjLength(Tcl_Obj *arithSeriesObj);
static int		TclArithSeriesObjRange(Tcl_Interp *interp,
			    Tcl_Obj *arithSeriesObj, Tcl_Size fromIdx,
			    Tcl_Size toIdx, Tcl_Obj **newObjPtr);
static int		TclArithSeriesObjReverse(Tcl_Interp *interp,
			    Tcl_Obj *arithSeriesObj, Tcl_Obj **newObjPtr);
static int		TclArithSeriesGetElements(Tcl_Interp *interp,
			    Tcl_Obj *objPtr, Tcl_Size *objcPtr,
			    Tcl_Obj ***objvPtr);
static void		DupArithSeriesInternalRep(Tcl_Obj *srcPtr,
			    Tcl_Obj *copyPtr);
static void		FreeArithSeriesInternalRep(Tcl_Obj *arithSeriesObjPtr);
static void		UpdateStringOfArithSeries(Tcl_Obj *arithSeriesObjPtr);
static int		ArithSeriesInOperation(Tcl_Interp *interp,
			    Tcl_Obj *valueObj, Tcl_Obj *arithSeriesObj,
			    int *boolResult);

/* ------------------------ ArithSeries object type -------------------------- */

static const Tcl_ObjType arithSeriesType = {
    "arithseries",			/* name */
    FreeArithSeriesInternalRep,		/* freeIntRepProc */
    DupArithSeriesInternalRep,		/* dupIntRepProc */
    UpdateStringOfArithSeries,		/* updateStringProc */
    NULL,				/* setFromAnyProc */
    TCL_OBJTYPE_V2(
    ArithSeriesObjLength,
    TclArithSeriesObjIndex,
    TclArithSeriesObjRange,
    TclArithSeriesObjReverse,
    TclArithSeriesGetElements,
    NULL, // SetElement
    NULL, // Replace
    ArithSeriesInOperation) // "in" operator
};

/*
 * Helper functions
 *
 * - power10 -- Fast version of pow(10, (int) n) for common cases.
 * - ArithRound -- Round doubles to the number of significant fractional
 *                 digits
 * - ArithSeriesIndexDbl -- base list indexing operation for doubles
 * - ArithSeriesIndexInt --   "    "      "        "      "  integers
 * - ArithSeriesGetInternalRep -- Return the internal rep from a Tcl_Obj
 * - Precision -- determine the number of factional digits for the given
 *   double value
 * - maxPrecision -- Using the values provide, determine the longest percision
 *   in the arithSeries
 */

static inline double
power10(
    unsigned n)
{
    /* few "precomputed" powers (note, max double is mostly 1.7e+308) */
    static const double powers[] = {
	1, 10, 100, 1000, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10,
	1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
	1e21, 1e22, 1e23, 1e24, 1e25, 1e26, 1e27, 1e28, 1e29, 1e30,
	1e31, 1e32, 1e33, 1e34, 1e35, 1e36, 1e37, 1e38, 1e39, 1e40,
	1e41, 1e42, 1e43, 1e44, 1e45, 1e46, 1e47, 1e48, 1e49, 1e50
    };

    if (n < sizeof(powers) / sizeof(*powers)) {
	return powers[n];
    } else {
	// Not an expected case. Doesn't need to be so fast
	return pow(10, n);
    }
}

static inline double
ArithRound(
    double d,
    unsigned n)
{
    double scaleFactor;

    if (!n) {
	return d;
    }
    scaleFactor = power10(n);
    return round(d * scaleFactor) / scaleFactor;
}

static inline double
ArithSeriesEndDbl(
    ArithSeriesDbl *dblRepPtr)
{
    double d;
    if (!dblRepPtr->base.len) {
	return dblRepPtr->start;
    }
    d = dblRepPtr->start + ((double)(dblRepPtr->base.len-1) * dblRepPtr->step);
    return ArithRound(d, dblRepPtr->precision);
}

static inline Tcl_WideInt
ArithSeriesEndInt(
    ArithSeriesInt *intRepPtr)
{
    if (!intRepPtr->base.len) {
	return intRepPtr->start;
    }
    return intRepPtr->start + ((intRepPtr->base.len-1) * intRepPtr->step);
}

static inline double
ArithSeriesIndexDbl(
    ArithSeries *arithSeriesRepPtr,
    Tcl_WideInt index)
{
    ArithSeriesDbl *dblRepPtr = (ArithSeriesDbl *)arithSeriesRepPtr;
    assert(arithSeriesRepPtr->isDouble);
    double d = dblRepPtr->start;
    if (index) {
	d += ((double)index * dblRepPtr->step);
    }

    return ArithRound(d, dblRepPtr->precision);
}

static inline Tcl_WideInt
ArithSeriesIndexInt(
    ArithSeries *arithSeriesRepPtr,
    Tcl_WideInt index)
{
    ArithSeriesInt *intRepPtr = (ArithSeriesInt *)arithSeriesRepPtr;
    assert(!arithSeriesRepPtr->isDouble);
    return intRepPtr->start + (index * intRepPtr->step);
}

static inline ArithSeries *
ArithSeriesGetInternalRep(
    Tcl_Obj *objPtr)
{
    const Tcl_ObjInternalRep *irPtr = TclFetchInternalRep(objPtr,
	    &arithSeriesType);
    return irPtr ? (ArithSeries *) irPtr->twoPtrValue.ptr1 : NULL;
}

/*
 * Compute number of significant fractional digits
 */
static inline unsigned
ObjPrecision(
    Tcl_Obj *numObj)
{
    void *ptr;
    int type;

    if (TclHasInternalRep(numObj, &tclDoubleType) || (
	    Tcl_GetNumberFromObj(NULL, numObj, &ptr, &type) == TCL_OK
	    && type == TCL_NUMBER_DOUBLE)
    ) { /* TCL_NUMBER_DOUBLE */
	const char *str = TclGetString(numObj);

	if (strchr(str, 'e') == NULL && strchr(str, 'E') == NULL) {
	    str = strchr(str, '.');
	    return (str ? (unsigned)strlen(str + 1) : 0);
	}
	/* don't calculate precision for e-notation */
    }
    /* no fraction for TCL_NUMBER_NAN, TCL_NUMBER_INT, TCL_NUMBER_BIG */
    return 0;
}

/*
 * Find longest number of digits after the decimal point.
 */
static inline unsigned
maxObjPrecision(
    Tcl_Obj *start,
    Tcl_Obj *end,
    Tcl_Obj *step)
{
    unsigned i, dp = 0;
    if (step) {
	dp = ObjPrecision(step);
    }
    if (start) {
	i = ObjPrecision(start);
	if (i > dp) {
	    dp = i;
	}
    }
    if (end) {
	i = ObjPrecision(end);
	if (i > dp) {
	    dp = i;
	}
    }
    return dp;
}

/*
 *----------------------------------------------------------------------
 *
 * ArithSeriesLen --
 *
 *	Compute the length of the equivalent list where
 *	every element is generated starting from *start*,
 *	and adding *step* to generate every successive element
 *	that's < *end* for positive steps, or > *end* for negative
 *	steps.
 *
 * Results:
 *	The length of the list generated by the given range,
 *	that may be zero.
 *	The function returns -1 if the list is of length infinite.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static Tcl_WideInt
ArithSeriesLenInt(
    Tcl_WideInt start,
    Tcl_WideInt end,
    Tcl_WideInt step)
{
    Tcl_WideInt len;

    if (step == 0) {
	return 0;
    }
    len = (end - start) / step + 1;
    if (len < 0) {
	return 0;
    }
    return len;
}

static Tcl_WideInt
ArithSeriesLenDbl(
    double start,
    double end,
    double step,
    unsigned precision)
{
    double scaleFactor;
    volatile double len; /* use volatile for more deterministic cross-platform
			  * FP arithmetics, (e. g. to avoid wrong optimization
			  * and divergent results by different compilers/platforms
			  * with and w/o FPU_INLINE_ASM, _CONTROLFP, etc) */

    if (step == 0) {
	return 0;
    }
    if (precision) {
	scaleFactor = power10(precision);
	start *= scaleFactor;
	end *= scaleFactor;
	step *= scaleFactor;
    }
    /* distance */
    end -= start;
    /*
     * To improve numerical stability use wide arithmetic instead of IEEE-754
     * when distance and step do not exceed wide-integers.
     */
    if (((double)WIDE_MIN <= end && end <= (double)WIDE_MAX) &&
	    ((double)WIDE_MIN <= step && step <= (double)WIDE_MAX)) {
	Tcl_WideInt iend = end < 0 ? end - 0.5 : end + 0.5;
	Tcl_WideInt istep = step < 0 ? step - 0.5 : step + 0.5;
	if (istep) { /* avoid div by zero, steps like 0.1, precision 0 */
	    return (iend / istep) + 1;
	}
    }
    /*
     * Too large, so use double (note the result may be instable due
     * to IEEE-754, so to be as precise as possible we'll use volatile len)
     */
    len = (end / step) + 1;
    if (len >= (double)TCL_SIZE_MAX) {
	return TCL_SIZE_MAX;
    }
    if (len < 0) {
	return 0;
    }
    return (Tcl_WideInt)len;
}

/*
 *----------------------------------------------------------------------
 *
 * DupArithSeriesInternalRep --
 *
 *	Initialize the internal representation of a arithseries Tcl_Obj to a
 *	copy of the internal representation of an existing arithseries object.
 *	The copy does not share the cache of the elements.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	We set "copyPtr"s internal rep to a pointer to a
 *	newly allocated ArithSeries structure.
 *
 *----------------------------------------------------------------------
 */

static void
DupArithSeriesInternalRep(
    Tcl_Obj *srcPtr,		/* Object with internal rep to copy. */
    Tcl_Obj *copyPtr)		/* Object with internal rep to set. */
{
    ArithSeries *srcRepPtr = (ArithSeries *)
	    srcPtr->internalRep.twoPtrValue.ptr1;

    srcRepPtr->refCount++;
    copyPtr->internalRep.twoPtrValue.ptr1 = srcRepPtr;
    copyPtr->internalRep.twoPtrValue.ptr2 = NULL;
    copyPtr->typePtr = &arithSeriesType;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeArithSeriesInternalRep --
 *
 *	Free any allocated memory in the ArithSeries Rep
 *
 * Results:
 *	None.
 *
 * Side effects:
 *
 *----------------------------------------------------------------------
 */

static inline void
FreeElements(
    ArithSeries *arithSeriesRepPtr)
{
    if (arithSeriesRepPtr->elements) {
	Tcl_WideInt i, len = arithSeriesRepPtr->len;

	for (i=0; i<len; i++) {
	    Tcl_DecrRefCount(arithSeriesRepPtr->elements[i]);
	}
	Tcl_Free((void *)arithSeriesRepPtr->elements);
	arithSeriesRepPtr->elements = NULL;
    }
}

static void
FreeArithSeriesInternalRep(
    Tcl_Obj *arithSeriesObjPtr)
{
    ArithSeries *arithSeriesRepPtr = (ArithSeries *)
	    arithSeriesObjPtr->internalRep.twoPtrValue.ptr1;

    if (arithSeriesRepPtr && arithSeriesRepPtr->refCount-- <= 1) {
	FreeElements(arithSeriesRepPtr);
	Tcl_Free((void *)arithSeriesRepPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * NewArithSeriesInt --
 *
 *	Creates a new ArithSeries object. The returned object has
 *	refcount = 0.
 *
 * Results:
 *	A Tcl_Obj pointer to the created ArithSeries object.
 *	A NULL pointer of the range is invalid.
 *
 * Side Effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
static Tcl_Obj *
NewArithSeriesInt(
    Tcl_WideInt start,
    Tcl_WideInt step,
    Tcl_WideInt length)
{
    Tcl_Obj *arithSeriesObj = NULL;
    ArithSeriesInt *arithSeriesRepPtr;

    TclNewObj(arithSeriesObj);

    if (length <= 0) {
	/* TODO - should negative lengths be an error? */
	return arithSeriesObj;
    } else if (length > 1) {
	/* Check for numeric overflow. Not needed for single element lists */
	Tcl_WideUInt absoluteStep;
	Tcl_WideInt numIntervals = length - 1;
	/*
	 * The checks below can probably be condensed but it is very easy to
	 * either inadvertently use undefined C behavior or unintended type
	 * promotion. Separating the cases helps me think more clearly.
	 */
	if (step >= 0) {
	    absoluteStep = step;
	} else if (step == WIDE_MIN) {
	    /* -step and abs(step) are both undefined behavior */
	    absoluteStep = 1 + (Tcl_WideUInt)WIDE_MAX;
	} else {
	    absoluteStep = -step;
	}
	/* First, step*number of intervals should not overflow */
	if ((UWIDE_MAX / absoluteStep) < (Tcl_WideUInt) numIntervals) {
	    goto invalid_range;
	}
	if (step > 0) {
	    /*
	     * Because of check above and UWIDE_MAX=2*WIDE_MAX+1,
	     * second term will not underflow a Tcl_WideInt
	     */
	    if (start > (WIDE_MAX - (step * numIntervals))) {
		goto invalid_range;
	    }
	} else if (step == WIDE_MIN) {
	    if (numIntervals > 0 || start < 0) {
		goto invalid_range;
	    }
	} else if (step < 0) {
	    /*
	     * Because of check above and UWIDE_MAX=2*WIDE_MAX+1 and
	     * step != WIDE_MIN second term will not underflow a Tcl_WideInt.
	     * DON'T use absoluteStep here because of unsigned type promotion
	     */
	    if (start < (WIDE_MIN + ((-step) * numIntervals))) {
		goto invalid_range;
	    }
	} else /* step == 0 */ {
	    /* TODO - step == 0 && length > 1 should be error? */
	}
    }

    arithSeriesRepPtr = (ArithSeriesInt *) Tcl_Alloc(sizeof(ArithSeriesInt));
    arithSeriesRepPtr->base.len = length;
    arithSeriesRepPtr->base.elements = NULL;
    arithSeriesRepPtr->base.isDouble = 0;
    arithSeriesRepPtr->base.refCount = 1;
    arithSeriesRepPtr->start = start;
    arithSeriesRepPtr->step = step;
    arithSeriesObj->internalRep.twoPtrValue.ptr1 = arithSeriesRepPtr;
    arithSeriesObj->internalRep.twoPtrValue.ptr2 = NULL;
    arithSeriesObj->typePtr = &arithSeriesType;
    Tcl_InvalidateStringRep(arithSeriesObj);

    return arithSeriesObj;

invalid_range:
    Tcl_BounceRefCount(arithSeriesObj);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * NewArithSeriesDbl --
 *
 *	Creates a new ArithSeries object with doubles. The returned object has
 *	refcount = 0.
 *
 * Results:
 *	A Tcl_Obj pointer to the created ArithSeries object.
 *	A NULL pointer of the range is invalid.
 *
 * Side Effects:
 *	None.
 *----------------------------------------------------------------------
 */
static Tcl_Obj *
NewArithSeriesDbl(
    double start,
    double step,
    Tcl_WideInt len,
    unsigned precision)
{
    Tcl_WideInt length;
    Tcl_Obj *arithSeriesObj;
    ArithSeriesDbl *arithSeriesRepPtr;

    length = len>=0 ? len : -1;
    if (length < 0) {
	length = -1;
    }

    TclNewObj(arithSeriesObj);

    if (length <= 0) {
	return arithSeriesObj;
    }

    arithSeriesRepPtr = (ArithSeriesDbl *) Tcl_Alloc(sizeof(ArithSeriesDbl));
    arithSeriesRepPtr->base.len = length;
    arithSeriesRepPtr->base.elements = NULL;
    arithSeriesRepPtr->base.isDouble = 1;
    arithSeriesRepPtr->base.refCount = 1;
    arithSeriesRepPtr->start = start;
    arithSeriesRepPtr->step = step;
    arithSeriesRepPtr->precision = precision;
    arithSeriesObj->internalRep.twoPtrValue.ptr1 = arithSeriesRepPtr;
    arithSeriesObj->internalRep.twoPtrValue.ptr2 = NULL;
    arithSeriesObj->typePtr = &arithSeriesType;

    if (length > 0) {
	Tcl_InvalidateStringRep(arithSeriesObj);
    }

    return arithSeriesObj;
}

/*
 *----------------------------------------------------------------------
 *
 * assignNumber --
 *
 *	Create the appropriate Tcl_Obj value for the given numeric values.
 *      Used locally only for decoding [lseq] numeric arguments.
 *	refcount = 0.
 *
 * Results:
 *	A Tcl_Obj pointer.  No assignment on error.
 *
 * Side Effects:
 *	None.
 *----------------------------------------------------------------------
 */
static int
assignNumber(
    Tcl_Interp *interp,
    int useDoubles,
    Tcl_WideInt *intNumberPtr,
    double *dblNumberPtr,
    Tcl_Obj *numberObj)
{
    void *ptr;
    int type;

    if (Tcl_GetNumberFromObj(interp, numberObj, &ptr, &type) != TCL_OK) {
	return TCL_ERROR;
    }
    if (type == TCL_NUMBER_BIG) {
	/* bignum is not supported yet. */
	Tcl_WideInt w;
	(void)Tcl_GetWideIntFromObj(interp, numberObj, &w);
	return TCL_ERROR;
    }
    if (useDoubles) {
	if (type != TCL_NUMBER_INT) {
	    double value = *(double *)ptr;
	    *intNumberPtr = (Tcl_WideInt)value;
	    *dblNumberPtr = value;
	} else {
	    Tcl_WideInt value = *(Tcl_WideInt *)ptr;
	    *intNumberPtr = value;
	    *dblNumberPtr = (double)value;
	}
    } else {
	if (type == TCL_NUMBER_INT) {
	    Tcl_WideInt value = *(Tcl_WideInt *)ptr;
	    *intNumberPtr = value;
	    *dblNumberPtr = (double)value;
	} else {
	    double value = *(double *)ptr;
	    *intNumberPtr = (Tcl_WideInt)value;
	    *dblNumberPtr = value;
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclNewArithSeriesObj --
 *
 *	Creates a new ArithSeries object. Some arguments may be NULL and will
 *	be computed based on the other given arguments.
 *      refcount = 0.
 *
 * Results:
 *	A Tcl_Obj pointer to the created ArithSeries object.
 *	NULL if the range is invalid.
 *
 * Side Effects:
 *	None.
 *----------------------------------------------------------------------
 */
Tcl_Obj *
TclNewArithSeriesObj(
    Tcl_Interp *interp,		/* For error reporting */
    int useDoubles,		/* Flag indicates values start,
				 * end, step, are treated as doubles */
    Tcl_Obj *startObj,		/* Starting value */
    Tcl_Obj *endObj,		/* Ending limit */
    Tcl_Obj *stepObj,		/* increment value */
    Tcl_Obj *lenObj)		/* Number of elements */
{
    double dstart, dend, dstep = 1.0;
    Tcl_WideInt start, end, step = 1;
    Tcl_WideInt len = -1;
    Tcl_Obj *objPtr;
    unsigned precision = (unsigned)-1; /* unknown precision */

    if (startObj) {
	if (assignNumber(interp, useDoubles, &start, &dstart, startObj) != TCL_OK) {
	    return NULL;
	}
    } else {
	start = 0;
	dstart = 0.0;
    }
    if (stepObj) {
	if (assignNumber(interp, useDoubles, &step, &dstep, stepObj) != TCL_OK) {
	    return NULL;
	}
	if (!useDoubles ? !step : !dstep) {
	    TclNewObj(objPtr);
	    return objPtr;
	}
    }
    if (endObj) {
	if (assignNumber(interp, useDoubles, &end, &dend, endObj) != TCL_OK) {
	    return NULL;
	}
    }
    if (lenObj) {
	if (Tcl_GetWideIntFromObj(interp, lenObj, &len) != TCL_OK) {
	    return NULL;
	}
    }

    if (endObj) {
	if (!stepObj) {
	    if (useDoubles) {
		if (dstart > dend) {
		    dstep = -1.0;
		    step = -1;
		}
	    } else {
		if (start > end) {
		    step = -1;
		    dstep = -1.0;
		}
	    }
	}
	assert(dstep!=0);
	if (!lenObj) {
	    if (useDoubles) {
		if (isinf(dstart) || isinf(dend)) {
		    goto exceeded;
		}
		if (isnan(dstart) || isnan(dend)) {
		    const char *description = "non-numeric floating-point value";
		    char tmp[TCL_DOUBLE_SPACE + 2];

		    tmp[0] = '\0';
		    Tcl_PrintDouble(NULL, isnan(dstart)?dstart:dend, tmp);
		    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"cannot use %s \"%s\" to estimate length of arith-series",
			description, tmp));
		    Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", description,
			(char *)NULL);
		    return NULL;
		}
		precision = maxObjPrecision(startObj, endObj, stepObj);
		len = ArithSeriesLenDbl(dstart, dend, dstep, precision);
	    } else {
		len = ArithSeriesLenInt(start, end, step);
	    }
	}
    } else {
	if (useDoubles) {
	    // Compute precision based on given command argument values
	    precision = maxObjPrecision(startObj, NULL, stepObj);

	    dend = dstart + (dstep * (double)(len-1));
	    // Make computed end value match argument(s) precision
	    dend = ArithRound(dend, precision);
	    end = dend;
	}
    }

    /*
     * todo: check whether the boundary must be rather LIST_MAX, to be more
     * similar to plain lists, otherwise it'd generate an error or panic later
     * (0x0ffffffffffffffa instead of 0x7fffffffffffffff by 64bit)
     */
    if (len > TCL_SIZE_MAX) {
    exceeded:
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"max length of a Tcl list exceeded", TCL_AUTO_LENGTH));
	Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
	return NULL;
    }

    if (useDoubles) {
	/* ensure we'll not get NaN somewhere in the arith-series,
	 * so simply check the end of it and behave like [expr {Inf - Inf}] */
	double d = dstart + (double)(len - 1) * dstep;
	if (isnan(d)) {
	    const char *s = "domain error: argument not in valid range";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(s, -1));
	    Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", s, (char *)NULL);
	    return NULL;
	}

	if (precision == (unsigned)-1) {
	    precision = maxObjPrecision(startObj, endObj, stepObj);
	}

	objPtr = NewArithSeriesDbl(dstart, dstep, len, precision);
    } else {
	objPtr = NewArithSeriesInt(start, step, len);
    }

    if (objPtr == NULL && interp) {
	const char *description = "invalid arithmetic series parameter values";
	Tcl_SetResult(interp, description, TCL_STATIC);
	Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", description, (char *)NULL);
    }
    return objPtr;
}

/*
 *----------------------------------------------------------------------
 *
 * TclArithSeriesObjIndex --
 *
 *	Returns the element with the specified index in the list
 *	represented by the specified Arithmetic Sequence object.
 *	If the index is out of range, TCL_ERROR is returned,
 *	otherwise TCL_OK is returned and the integer value of the
 *	element is stored in *element.
 *
 * Results:
 *	TCL_OK on success.
 *
 * Side Effects:
 *	On success, the integer pointed by *element is modified.
 *	An empty string ("") is assigned if index is out-of-bounds.
 *
 *----------------------------------------------------------------------
 */
int
TclArithSeriesObjIndex(
    TCL_UNUSED(Tcl_Interp *),
    Tcl_Obj *arithSeriesObj,	/* List obj */
    Tcl_Size index,		/* index to element of interest */
    Tcl_Obj **elemObj)		/* Return value */
{
    ArithSeries *arithSeriesRepPtr = ArithSeriesGetInternalRep(arithSeriesObj);

    if (index < 0 || arithSeriesRepPtr->len <= index) {
	*elemObj = NULL;
    } else {
	/* List[i] = Start + (Step * index) */
	if (arithSeriesRepPtr->isDouble) {
	    *elemObj = Tcl_NewDoubleObj(ArithSeriesIndexDbl(arithSeriesRepPtr, index));
	} else {
	    *elemObj = Tcl_NewWideIntObj(ArithSeriesIndexInt(arithSeriesRepPtr, index));
	}
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ArithSeriesObjLength
 *
 *	Returns the length of the arithmetic series.
 *
 * Results:
 *	The length of the series as Tcl_WideInt.
 *
 * Side Effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */
Tcl_Size
ArithSeriesObjLength(
    Tcl_Obj *arithSeriesObj)
{
    ArithSeries *arithSeriesRepPtr = (ArithSeries *)
	    arithSeriesObj->internalRep.twoPtrValue.ptr1;
    return arithSeriesRepPtr->len;
}

/*
 *----------------------------------------------------------------------
 *
 * TclArithSeriesObjRange --
 *
 *	Makes a slice of an ArithSeries value.
 *      *arithSeriesObj must be known to be a valid list.
 *
 * Results:
 *	Returns a pointer to the sliced series.
 *      This may be a new object or the same object if not shared.
 *
 * Side effects:
 *	?The possible conversion of the object referenced by listPtr?
 *	?to a list object.?
 *
 *----------------------------------------------------------------------
 */

int
TclArithSeriesObjRange(
    Tcl_Interp *interp,		/* For error message(s) */
    Tcl_Obj *arithSeriesObj,	/* List object to take a range from. */
    Tcl_Size fromIdx,		/* Index of first element to include. */
    Tcl_Size toIdx,		/* Index of last element to include. */
    Tcl_Obj **newObjPtr)	/* return value */
{
    ArithSeries *arithSeriesRepPtr;
    Tcl_WideInt len;

    (void)interp; /* silence compiler */

    arithSeriesRepPtr = ArithSeriesGetInternalRep(arithSeriesObj);

    if (fromIdx == TCL_INDEX_NONE) {
	fromIdx = 0;
    }

    if (toIdx >= arithSeriesRepPtr->len) {
	toIdx = arithSeriesRepPtr->len-1;
    }

    if (fromIdx > toIdx || fromIdx >= arithSeriesRepPtr->len) {
	TclNewObj(*newObjPtr);
	return TCL_OK;
    }

    if (fromIdx < 0) {
	fromIdx = 0;
    }
    if (toIdx < 0) {
	toIdx = 0;
    }

    len = toIdx - fromIdx + 1;

    if (arithSeriesRepPtr->isDouble) {
	ArithSeriesDbl *dblRepPtr = (ArithSeriesDbl *)arithSeriesRepPtr;
	double dstart = ArithSeriesIndexDbl(arithSeriesRepPtr, fromIdx);

	if (Tcl_IsShared(arithSeriesObj) || ((arithSeriesRepPtr->refCount > 1))) {
	    /* as new object */
	    *newObjPtr = NewArithSeriesDbl(dstart, dblRepPtr->step, len,
		dblRepPtr->precision);
	} else {
	    /* in-place is possible */
	    *newObjPtr = arithSeriesObj;
	    /*
	     * Even if nothing below causes any changes, we still want the
	     * string-canonizing effect of [lrange 0 end].
	     */
	    TclInvalidateStringRep(arithSeriesObj);

	    dblRepPtr->start = dstart;
	    /* step and precision remain the same */
	    dblRepPtr->base.len = len;
	    FreeElements(arithSeriesRepPtr);
	}
    } else {
	ArithSeriesInt *intRepPtr = (ArithSeriesInt *) arithSeriesRepPtr;
	Tcl_WideInt start = ArithSeriesIndexInt(arithSeriesRepPtr, fromIdx);

	if (Tcl_IsShared(arithSeriesObj) || ((arithSeriesRepPtr->refCount > 1))) {
	    /* as new object */
	    *newObjPtr = NewArithSeriesInt(start, intRepPtr->step, len);
	} else {
	    /* in-place is possible. */
	    *newObjPtr = arithSeriesObj;
	    /*
	     * Even if nothing below causes any changes, we still want the
	     * string-canonizing effect of [lrange 0 end].
	     */
	    TclInvalidateStringRep(arithSeriesObj);

	    intRepPtr->start = start;
	    /* step remains the same */
	    intRepPtr->base.len = len;
	    FreeElements(arithSeriesRepPtr);
	}
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclArithSeriesGetElements --
 *
 *	This function returns an (objc,objv) array of the elements in a list
 *	object.
 *
 * Results:
 *	The return value is normally TCL_OK; in this case *objcPtr is set to
 *	the count of list elements and *objvPtr is set to a pointer to an
 *	array of (*objcPtr) pointers to each list element. If listPtr does not
 *	refer to an Abstract List object and the object can not be converted
 *	to one, TCL_ERROR is returned and an error message will be left in the
 *	interpreter's result if interp is not NULL.
 *
 *	The objects referenced by the returned array should be treated as
 *	readonly and their ref counts are _not_ incremented; the caller must
 *	do that if it holds on to a reference. Furthermore, the pointer and
 *	length returned by this function may change as soon as any function is
 *	called on the list object; be careful about retaining the pointer in a
 *	local data structure.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclArithSeriesGetElements(
    Tcl_Interp *interp,		/* Used to report errors if not NULL. */
    Tcl_Obj *objPtr,		/* ArithSeries object for which an element
				 * array is to be returned. */
    Tcl_Size *objcPtr,		/* Where to store the count of objects
				 * referenced by objv. */
    Tcl_Obj ***objvPtr)		/* Where to store the pointer to an array of
				 * pointers to the list's objects. */
{
    if (TclHasInternalRep(objPtr, &arithSeriesType)) {
	ArithSeries *arithSeriesRepPtr = ArithSeriesGetInternalRep(objPtr);
	Tcl_Obj **objv;
	Tcl_Size objc = arithSeriesRepPtr->len;

	if (objc > 0) {
	    if (arithSeriesRepPtr->elements) {
		/* If this exists, it has already been populated */
		objv = arithSeriesRepPtr->elements;
	    } else {
		/* Construct the elements array */
		objv = (Tcl_Obj **) Tcl_Alloc(sizeof(Tcl_Obj*) * objc);
		if (objv == NULL) {
		    if (interp) {
			Tcl_SetObjResult(interp, Tcl_NewStringObj(
				"max length of a Tcl list exceeded",
				TCL_AUTO_LENGTH));
			Tcl_SetErrorCode(interp, "TCL", "MEMORY", (char *)NULL);
		    }
		    return TCL_ERROR;
		}
		arithSeriesRepPtr->elements = objv;

		Tcl_Size i;
		for (i = 0; i < objc; i++) {
		    int status = TclArithSeriesObjIndex(interp, objPtr, i, &objv[i]);

		    if (status) {
			return TCL_ERROR;
		    }
		    Tcl_IncrRefCount(objv[i]);
		}
	    }
	} else {
	    objv = NULL;
	}
	*objvPtr = objv;
	*objcPtr = objc;
    } else {
	if (interp != NULL) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "value is not an arithseries", TCL_AUTO_LENGTH));
	    Tcl_SetErrorCode(interp, "TCL", "VALUE", "UNKNOWN", (char *)NULL);
	}
	return TCL_ERROR;
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclArithSeriesObjReverse --
 *
 *	Reverse the order of the ArithSeries value. The arithSeriesObj is
 *	assumed to be a valid ArithSeries. The new Obj has the Start and End
 *	values appropriately swapped and the Step value sign is changed.
 *
 * Results:
 *      The result will be an ArithSeries in the reverse order.
 *
 * Side effects:
 *      The ogiginal obj will be modified and returned if it is not Shared.
 *
 *----------------------------------------------------------------------
 */
int
TclArithSeriesObjReverse(
    Tcl_Interp *interp,		/* For error message(s) */
    Tcl_Obj *arithSeriesObj,	/* List object to reverse. */
    Tcl_Obj **newObjPtr)
{
    ArithSeries *arithSeriesRepPtr;
    Tcl_Obj *resultObj;

    (void)interp;

    assert(newObjPtr != NULL);

    arithSeriesRepPtr = ArithSeriesGetInternalRep(arithSeriesObj);

    if (Tcl_IsShared(arithSeriesObj) || (arithSeriesRepPtr->refCount > 1)) {
	if (arithSeriesRepPtr->isDouble) {
	    ArithSeriesDbl *dblRepPtr = (ArithSeriesDbl *)arithSeriesRepPtr;
	    resultObj = NewArithSeriesDbl(ArithSeriesEndDbl(dblRepPtr),
		-dblRepPtr->step, arithSeriesRepPtr->len, dblRepPtr->precision);
	} else {
	    ArithSeriesInt *intRepPtr = (ArithSeriesInt *)arithSeriesRepPtr;
	    resultObj = NewArithSeriesInt(ArithSeriesEndInt(intRepPtr),
		-intRepPtr->step, arithSeriesRepPtr->len);
	}
    } else {
	/*
	 * In-place is possible.
	 */

	TclInvalidateStringRep(arithSeriesObj);

	if (arithSeriesRepPtr->isDouble) {
	    ArithSeriesDbl *dblRepPtr = (ArithSeriesDbl *)arithSeriesRepPtr;

	    dblRepPtr->start = ArithSeriesEndDbl(dblRepPtr);
	    dblRepPtr->step = -dblRepPtr->step;
	    /* precision remains the same */
	} else {
	    ArithSeriesInt *intRepPtr = (ArithSeriesInt *)arithSeriesRepPtr;

	    intRepPtr->start = ArithSeriesEndInt(intRepPtr);
	    intRepPtr->step = -intRepPtr->step;
	}
	FreeElements(arithSeriesRepPtr);
	resultObj = arithSeriesObj;
    }

    *newObjPtr = resultObj;

    return resultObj ? TCL_OK : TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * UpdateStringOfArithSeries --
 *
 *	Update the string representation for an arithseries object.
 *	Note: This procedure does not invalidate an existing old string rep
 *	so storage will be lost if this has not already been done.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The object's string is set to a valid string that results from
 *	the list-to-string conversion. This string will be empty if the
 *	list has no elements. The list internal representation
 *	should not be NULL and we assume it is not NULL.
 *
 * Notes:
 *	At the cost of overallocation it's possible to estimate
 *	the length of the string representation and make this procedure
 *	much faster. Because the programmer shouldn't expect the
 *	string conversion of a big arithmetic sequence to be fast
 *	this version takes more care of space than time.
 *
 *----------------------------------------------------------------------
 */
static void
UpdateStringOfArithSeries(
    Tcl_Obj *arithSeriesObjPtr)
{
    ArithSeries *arithSeriesRepPtr = (ArithSeries *)
	    arithSeriesObjPtr->internalRep.twoPtrValue.ptr1;
    char *p, *srep;
    Tcl_Size i, bytlen = 0;

    if (arithSeriesRepPtr->len == 0) {
	(void)Tcl_InitStringRep(arithSeriesObjPtr, NULL, 0);
	return;
    }

    /*
     * Pass 1: estimate space.
     */
    if (!arithSeriesRepPtr->isDouble) {
	for (i = 0; i < arithSeriesRepPtr->len; i++) {
	    double d = (double)ArithSeriesIndexInt(arithSeriesRepPtr, i);
	    Tcl_Size slen = d>0 ? log10(d)+1 : d<0 ? log10(-d)+2 : 1;

	    bytlen += slen;
	}
    } else {
	char tmp[TCL_DOUBLE_SPACE + 2];
	for (i = 0; i < arithSeriesRepPtr->len; i++) {
	    double d = ArithSeriesIndexDbl(arithSeriesRepPtr, i);
	    Tcl_Size elen;

	    tmp[0] = '\0';
	    Tcl_PrintDouble(NULL,d,tmp);
	    elen = strlen(tmp);
	    if (bytlen > TCL_SIZE_MAX - elen) {
		/* overflow, todo: check we could use some representation instead of the panic
		 * to signal it is too large for string representation, because too heavy */
		Tcl_Panic("UpdateStringOfArithSeries: too large to represent");
	    }
	    bytlen += elen;
	}
    }
    bytlen += arithSeriesRepPtr->len; // Space for each separator

    /*
     * Pass 2: generate the string repr.
     */

    p = srep = Tcl_InitStringRep(arithSeriesObjPtr, NULL, bytlen);
    TclOOM(p, bytlen+1);

    if (!arithSeriesRepPtr->isDouble) {
	for (i = 0; i < arithSeriesRepPtr->len; i++) {
	    Tcl_WideInt d = ArithSeriesIndexInt(arithSeriesRepPtr, i);
	    p += TclFormatInt(p, d);
	    assert(p - arithSeriesObjPtr->bytes <= bytlen);
	    *p++ = ' ';
	}
    } else {
	for (i = 0; i < arithSeriesRepPtr->len; i++) {
	    double d = ArithSeriesIndexDbl(arithSeriesRepPtr, i);

	    *p = '\0';
	    Tcl_PrintDouble(NULL,d,p);
	    p += strlen(p);
	    assert(p - arithSeriesObjPtr->bytes <= bytlen);
	    *p++ = ' ';
	}
    }
    (void) Tcl_InitStringRep(arithSeriesObjPtr, NULL, (--p - srep));
}

/*
 *----------------------------------------------------------------------
 *
 * ArithSeriesInOperator --
 *
 *	Evaluate the "in" operation for expr
 *
 *      This can be done more efficiently in the Arith Series relative to
 *      doing a linear search as implemented in expr.
 *
 * Results:
 *	Boolean true or false (1/0)
 *
 * Side effects:
 *      None
 *
 *----------------------------------------------------------------------
 */

static int
ArithSeriesInOperation(
    Tcl_Interp *interp,
    Tcl_Obj *valueObj,
    Tcl_Obj *arithSeriesObjPtr,
    int *boolResult)
{
    ArithSeries *repPtr = (ArithSeries *)
	    arithSeriesObjPtr->internalRep.twoPtrValue.ptr1;
    int status;
    Tcl_Size index, incr, elen, vlen;

    if (repPtr->isDouble) {
	ArithSeriesDbl *dblRepPtr = (ArithSeriesDbl *) repPtr;
	double y;
	int test = 0;

	incr = 0; // Check index+incr where incr is 0 and 1
	status = Tcl_GetDoubleFromObj(interp, valueObj, &y);
	if (status != TCL_OK) {
	    test = 0;
	} else {
	    const char *vstr = TclGetStringFromObj(valueObj, &vlen);
	    index = (y - dblRepPtr->start) / dblRepPtr->step;
	    while (incr<2) {
		Tcl_Obj *elemObj;

		elen = 0;
		TclArithSeriesObjIndex(interp, arithSeriesObjPtr, (index+incr), &elemObj);

		const char *estr = elemObj ? TclGetStringFromObj(elemObj, &elen) : "";

		/* "in" operation defined as a string compare */
		test = (elen == vlen) ? (memcmp(estr, vstr, elen) == 0) : 0;
		Tcl_BounceRefCount(elemObj);
		/* Stop if we have a match */
		if (test) {
		    break;
		}
		incr++;
	    }
	}
	if (boolResult) {
	    *boolResult = test;
	}
    } else {
	ArithSeriesInt *intRepPtr = (ArithSeriesInt *) repPtr;
	Tcl_WideInt y;

	status = Tcl_GetWideIntFromObj(NULL, valueObj, &y);
	if (status != TCL_OK) {
	    if (boolResult) {
		*boolResult = 0;
	    }
	} else {
	    Tcl_Obj *elemObj;

	    elen = 0;
	    index = (y - intRepPtr->start) / intRepPtr->step;
	    TclArithSeriesObjIndex(interp, arithSeriesObjPtr, index, &elemObj);

	    char const *vstr = TclGetStringFromObj(valueObj, &vlen);
	    char const *estr = elemObj ? TclGetStringFromObj(elemObj, &elen) : "";

	    if (boolResult) {
		*boolResult = (elen == vlen) ? (memcmp(estr, vstr, elen) == 0) : 0;
	    }
	    Tcl_BounceRefCount(elemObj);
	}
    }
    return TCL_OK;
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
