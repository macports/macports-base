/*
 * tclExecute.c --
 *
 *	This file contains procedures that execute byte-compiled Tcl commands.
 *
 * Copyright © 1996-1997 Sun Microsystems, Inc.
 * Copyright © 1998-2000 Scriptics Corporation.
 * Copyright © 2001 Kevin B. Kenny. All rights reserved.
 * Copyright © 2002-2010 Miguel Sofer.
 * Copyright © 2005-2007 Donal K. Fellows.
 * Copyright © 2007 Daniel A. Steffen <das@users.sourceforge.net>
 * Copyright © 2006-2008 Joe Mistachkin.  All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclCompile.h"
#include "tclOOInt.h"
#include "tclTomMath.h"
#include <math.h>

/*
 * Hack to determine whether we may expect IEEE floating point. The hack is
 * formally incorrect in that non-IEEE platforms might have the same precision
 * and range, but VAX, IBM, and Cray do not; are there any other floating
 * point units that we might care about?
 */

#if (FLT_RADIX == 2) && (DBL_MANT_DIG == 53) && (DBL_MAX_EXP == 1024)
#define IEEE_FLOATING_POINT
#endif

/*
 * A counter that is used to work out when the bytecode engine should call
 * Tcl_AsyncReady() to see whether there is a signal that needs handling, and
 * other expensive periodic operations.
 */

#ifndef ASYNC_CHECK_COUNT
#   define ASYNC_CHECK_COUNT	64
#endif /* !ASYNC_CHECK_COUNT */

/*
 * Boolean flag indicating whether the Tcl bytecode interpreter has been
 * initialized.
 */

static int execInitialized = 0;
TCL_DECLARE_MUTEX(execMutex)

static int cachedInExit = 0;

#ifdef TCL_COMPILE_DEBUG
/*
 * Variable that controls whether execution tracing is enabled and, if so,
 * what level of tracing is desired:
 *    0: no execution tracing
 *    1: trace invocations of Tcl procs only
 *    2: trace invocations of all (not compiled away) commands
 *    3: display each instruction executed
 * This variable is linked to the Tcl variable "tcl_traceExec".
 */

int tclTraceExec = 0;
#endif

/*
 * Mapping from expression instruction opcodes to strings; used for error
 * messages. Note that these entries must match the order and number of the
 * expression opcodes (e.g., INST_LOR) in tclCompile.h.
 *
 * Does not include the string for INST_EXPON (and beyond), as that is
 * disjoint for backward-compatibility reasons.
 */

static const char *const operatorStrings[] = {
    "|", "^", "&", "==", "!=", "<", ">", "<=", ">=", "<<", ">>",
    "+", "-", "*", "/", "%", "+", "-", "~", "!"
};

/*
 * Mapping from Tcl result codes to strings; used for error and debugging
 * messages.
 */

#ifdef TCL_COMPILE_DEBUG
static const char *const resultStrings[] = {
    "TCL_OK", "TCL_ERROR", "TCL_RETURN", "TCL_BREAK", "TCL_CONTINUE"
};
#endif

/*
 * These are used by evalstats to monitor object usage in Tcl.
 */

#ifdef TCL_COMPILE_STATS
size_t		tclObjsAlloced = 0;
size_t		tclObjsFreed = 0;
size_t		tclObjsShared[TCL_MAX_SHARED_OBJ_STATS] = { 0, 0, 0, 0, 0 };
#endif /* TCL_COMPILE_STATS */

/*
 * NR_TEBC
 * Helpers for NR - non-recursive calls to TEBC
 * Minimal data required to fully reconstruct the execution state.
 */

typedef struct {
    ByteCode *codePtr;		/* Constant until the BC returns */
				/* -----------------------------------------*/
    Tcl_Obj **catchTop;		/* These fields are used on return TO this */
    Tcl_Obj *auxObjList;	/* level: they record the state when a new */
    CmdFrame cmdFrame;		/* codePtr was received for NR execution. */
    Tcl_Obj *stack[1];		/* Start of the actual combined catch and obj
				 * stacks; the struct will be expanded as
				 * necessary */
} TEBCdata;

#define TEBC_YIELD() \
    do {						\
	esPtr->tosPtr = tosPtr;				\
	TclNRAddCallback(interp, TEBCresume,		\
		TD, pc, INT2PTR(cleanup), NULL);	\
    } while (0)

#define TEBC_DATA_DIG() \
    do {					\
	tosPtr = esPtr->tosPtr;			\
    } while (0)

#define PUSH_TAUX_OBJ(objPtr) \
    do {							\
	if (auxObjList) {					\
	    (objPtr)->length += auxObjList->length;		\
	}							\
	(objPtr)->internalRep.twoPtrValue.ptr1 = auxObjList;	\
	auxObjList = (objPtr);					\
    } while (0)

#define POP_TAUX_OBJ() \
    do {							\
	tmpPtr = auxObjList;					\
	auxObjList = (Tcl_Obj *)tmpPtr->internalRep.twoPtrValue.ptr1;	\
	Tcl_DecrRefCount(tmpPtr);				\
    } while (0)

/*
 * These variable-access macros have to coincide with those in tclVar.c
 */

#define VarHashGetValue(hPtr) \
    ((Var *) ((char *)hPtr - offsetof(VarInHash, entry)))

static inline Var *
VarHashFindVar(
    TclVarHashTable *tablePtr,
    Tcl_Obj *key)
{
    Tcl_HashEntry *hPtr = Tcl_FindHashEntry(&tablePtr->table,
	    key);
    if (!hPtr) {
	return NULL;
    }
    return VarHashGetValue(hPtr);
}

/*
 * The new macro for ending an instruction; note that a reasonable C-optimiser
 * will resolve all branches at compile time. (result) is always a constant;
 * the macro NEXT_INST_F handles constant (nCleanup), NEXT_INST_V is resolved
 * at runtime for variable (nCleanup).
 *
 * ARGUMENTS:
 *    pcAdjustment: how much to increment pc
 *    nCleanup: how many objects to remove from the stack
 *    resultHandling: 0 indicates no object should be pushed on the stack;
 *	otherwise, push objResultPtr. If (result < 0), objResultPtr already
 *	has the correct reference count.
 *
 * We use the new compile-time assertions to check that nCleanup is constant
 * and within range.
 */

/* Verify the stack depth, only when no expansion is in progress */

#ifdef TCL_COMPILE_DEBUG
#define CHECK_STACK() \
    do {								\
	ValidatePcAndStackTop(codePtr, pc, CURR_DEPTH,			\
		/*checkStack*/ !(starting || auxObjList));		\
	starting = 0;							\
    } while (0)
#else
#define CHECK_STACK()
#endif

#define NEXT_INST_F(pcAdjustment, nCleanup, resultHandling) \
    do {								\
	TCL_CT_ASSERT((nCleanup >= 0) && (nCleanup <= 2));		\
	CHECK_STACK();							\
	if (nCleanup == 0) {						\
	    if (resultHandling != 0) {					\
		if ((resultHandling) > 0) {				\
		    PUSH_OBJECT(objResultPtr);				\
		} else {						\
		    *(++tosPtr) = objResultPtr;				\
		}							\
	    }								\
	    pc += (pcAdjustment);					\
	    goto cleanup0;						\
	} else if (resultHandling != 0) {				\
	    if ((resultHandling) > 0) {					\
		Tcl_IncrRefCount(objResultPtr);				\
	    }								\
	    pc += (pcAdjustment);					\
	    switch (nCleanup) {						\
	    case 1: goto cleanup1_pushObjResultPtr;			\
	    case 2: goto cleanup2_pushObjResultPtr;			\
	    case 0: break;						\
	    }								\
	} else {							\
	    pc += (pcAdjustment);					\
	    switch (nCleanup) {						\
	    case 1: goto cleanup1;					\
	    case 2: goto cleanup2;					\
	    case 0: break;						\
	    }								\
	}								\
    } while (0)

#define NEXT_INST_V(pcAdjustment, nCleanup, resultHandling) \
    CHECK_STACK();							\
    do {								\
	pc += (pcAdjustment);						\
	cleanup = (nCleanup);						\
	if (resultHandling) {						\
	    if ((resultHandling) > 0) {					\
		Tcl_IncrRefCount(objResultPtr);				\
	    }								\
	    goto cleanupV_pushObjResultPtr;				\
	} else {							\
	    goto cleanupV;						\
	}								\
    } while (0)

#ifndef TCL_COMPILE_DEBUG
#define JUMP_PEEPHOLE_F(condition, pcAdjustment, cleanup) \
    do {								\
	pc += (pcAdjustment);						\
	switch (*pc) {							\
	case INST_JUMP_FALSE1:						\
	    NEXT_INST_F(((condition)? 2 : TclGetInt1AtPtr(pc+1)), (cleanup), 0); \
	    break;							\
	case INST_JUMP_TRUE1:						\
	    NEXT_INST_F(((condition)? TclGetInt1AtPtr(pc+1) : 2), (cleanup), 0); \
	    break;							\
	case INST_JUMP_FALSE4:						\
	    NEXT_INST_F(((condition)? 5 : TclGetInt4AtPtr(pc+1)), (cleanup), 0); \
	    break;							\
	case INST_JUMP_TRUE4:						\
	    NEXT_INST_F(((condition)? TclGetInt4AtPtr(pc+1) : 5), (cleanup), 0); \
	    break;							\
	default:							\
	    if ((condition) < 0) {					\
		TclNewIntObj(objResultPtr, -1);				\
	    } else {							\
		objResultPtr = TCONST((condition) > 0);			\
	    }								\
	    NEXT_INST_F(0, (cleanup), 1);				\
	    break;							\
	}								\
    } while (0)
#define JUMP_PEEPHOLE_V(condition, pcAdjustment, cleanup) \
    do {								\
	pc += (pcAdjustment);						\
	switch (*pc) {							\
	case INST_JUMP_FALSE1:						\
	    NEXT_INST_V(((condition)? 2 : TclGetInt1AtPtr(pc+1)), (cleanup), 0); \
	    break;							\
	case INST_JUMP_TRUE1:						\
	    NEXT_INST_V(((condition)? TclGetInt1AtPtr(pc+1) : 2), (cleanup), 0); \
	    break;							\
	case INST_JUMP_FALSE4:						\
	    NEXT_INST_V(((condition)? 5 : TclGetInt4AtPtr(pc+1)), (cleanup), 0); \
	    break;							\
	case INST_JUMP_TRUE4:						\
	    NEXT_INST_V(((condition)? TclGetInt4AtPtr(pc+1) : 5), (cleanup), 0); \
	    break;							\
	default:							\
	    if ((condition) < 0) {					\
		TclNewIntObj(objResultPtr, -1);				\
	    } else {							\
		objResultPtr = TCONST((condition) > 0);			\
	    }								\
	    NEXT_INST_V(0, (cleanup), 1);				\
	    break;							\
	}								\
    } while (0)
#else /* TCL_COMPILE_DEBUG */
#define JUMP_PEEPHOLE_F(condition, pcAdjustment, cleanup) \
    do{									\
	if ((condition) < 0) {						\
	    TclNewIntObj(objResultPtr, -1);				\
	} else {							\
	    objResultPtr = TCONST((condition) > 0);			\
	}								\
	NEXT_INST_F((pcAdjustment), (cleanup), 1);			\
    } while (0)
#define JUMP_PEEPHOLE_V(condition, pcAdjustment, cleanup) \
    do{									\
	if ((condition) < 0) {						\
	    TclNewIntObj(objResultPtr, -1);				\
	} else {							\
	    objResultPtr = TCONST((condition) > 0);			\
	}								\
	NEXT_INST_V((pcAdjustment), (cleanup), 1);			\
    } while (0)
#endif

/*
 * Macros used to cache often-referenced Tcl evaluation stack information
 * in local variables. Note that a DECACHE_STACK_INFO()-CACHE_STACK_INFO()
 * pair must surround any call inside TclNRExecuteByteCode (and a few other
 * procedures that use this scheme) that could result in a recursive call
 * to TclNRExecuteByteCode.
 */

#define CACHE_STACK_INFO() \
    checkInterp = 1

#define DECACHE_STACK_INFO() \
    esPtr->tosPtr = tosPtr

/*
 * Macros used to access items on the Tcl evaluation stack. PUSH_OBJECT
 * increments the object's ref count since it makes the stack have another
 * reference pointing to the object. However, POP_OBJECT does not decrement
 * the ref count. This is because the stack may hold the only reference to the
 * object, so the object would be destroyed if its ref count were decremented
 * before the caller had a chance to, e.g., store it in a variable. It is the
 * caller's responsibility to decrement the ref count when it is finished with
 * an object.
 *
 * WARNING! It is essential that objPtr only appear once in the PUSH_OBJECT
 * macro. The actual parameter might be an expression with side effects, and
 * this ensures that it will be executed only once.
 */

#define PUSH_OBJECT(objPtr) \
    Tcl_IncrRefCount(*(++tosPtr) = (objPtr))

#define POP_OBJECT()	*(tosPtr--)

#define OBJ_AT_TOS	*tosPtr

#define OBJ_UNDER_TOS	tosPtr[-1]

#define OBJ_AT_DEPTH(n)	tosPtr[-(n)]

#define CURR_DEPTH	(tosPtr - initTosPtr)

#define STACK_BASE(esPtr) ((esPtr)->stackWords - 1)

/*
 * Macros used to trace instruction execution. The macros TRACE,
 * TRACE_WITH_OBJ, and O2S are only used inside TclNRExecuteByteCode. O2S is
 * only used in TRACE* calls to get a string from an object.
 */

#ifdef TCL_COMPILE_DEBUG
#   define TRACE(a) \
    while (traceInstructions) {						\
	fprintf(stdout, "%2" TCL_SIZE_MODIFIER "d: %2" TCL_SIZE_MODIFIER	\
		"d (%" TCL_SIZE_MODIFIER "d) %s ", iPtr->numLevels,	\
		CURR_DEPTH,						\
		(pc - codePtr->codeStart),				\
		GetOpcodeName(pc));					\
	printf a;							\
	break;								\
    }
#   define TRACE_APPEND(a) \
    while (traceInstructions) {		\
	printf a;			\
	break;				\
    }
#   define TRACE_ERROR(interp) \
    TRACE_APPEND(("ERROR: %.30s\n", O2S(Tcl_GetObjResult(interp))));
#   define TRACE_WITH_OBJ(a, objPtr) \
    while (traceInstructions) {						\
	fprintf(stdout, "%2" TCL_SIZE_MODIFIER "d: %2" TCL_SIZE_MODIFIER	\
		"d (%" TCL_SIZE_MODIFIER "d) %s ", iPtr->numLevels,	\
		CURR_DEPTH,						\
		(pc - codePtr->codeStart),				\
		GetOpcodeName(pc));					\
	printf a;							\
	TclPrintObject(stdout, objPtr, 30);				\
	fprintf(stdout, "\n");						\
	break;								\
    }
#   define O2S(objPtr) \
    (objPtr ? TclGetString(objPtr) : "")
#else /* !TCL_COMPILE_DEBUG */
#   define TRACE(a)
#   define TRACE_APPEND(a)
#   define TRACE_ERROR(interp)
#   define TRACE_WITH_OBJ(a, objPtr)
#   define O2S(objPtr)
#endif /* TCL_COMPILE_DEBUG */

/*
 * DTrace instruction probe macros.
 */

#define TCL_DTRACE_INST_NEXT() \
    do {								\
	if (TCL_DTRACE_INST_DONE_ENABLED()) {				\
	    if (curInstName) {						\
		TCL_DTRACE_INST_DONE(curInstName, CURR_DEPTH,	\
			tosPtr);					\
	    }								\
	    curInstName = tclInstructionTable[*pc].name;		\
	    if (TCL_DTRACE_INST_START_ENABLED()) {			\
		TCL_DTRACE_INST_START(curInstName, CURR_DEPTH,	\
			tosPtr);					\
	    }								\
	} else if (TCL_DTRACE_INST_START_ENABLED()) {			\
	    TCL_DTRACE_INST_START(tclInstructionTable[*pc].name,	\
			CURR_DEPTH, tosPtr);			\
	}								\
    } while (0)
#define TCL_DTRACE_INST_LAST() \
    do {								\
	if (TCL_DTRACE_INST_DONE_ENABLED() && curInstName) {		\
	    TCL_DTRACE_INST_DONE(curInstName, CURR_DEPTH, tosPtr);\
	}								\
    } while (0)

/*
 * Macro used in this file to save a function call for common uses of
 * Tcl_GetNumberFromObj(). The ANSI C "prototype" is:
 *
 * MODULE_SCOPE int GetNumberFromObj(Tcl_Interp *interp, Tcl_Obj *objPtr,
 *			void **ptrPtr, int *tPtr);
 */

#define GetNumberFromObj(interp, objPtr, ptrPtr, tPtr) \
    ((TclHasInternalRep((objPtr), &tclIntType))				\
	?	(*(tPtr) = TCL_NUMBER_INT,				\
		*(ptrPtr) = (void *)					\
		    (&((objPtr)->internalRep.wideValue)), TCL_OK) :	\
    TclHasInternalRep((objPtr), &tclDoubleType)				\
	?	(((isnan((objPtr)->internalRep.doubleValue))		\
		    ?	(*(tPtr) = TCL_NUMBER_NAN)			\
		    :	(*(tPtr) = TCL_NUMBER_DOUBLE)),			\
		*(ptrPtr) = (void *)					\
		    (&((objPtr)->internalRep.doubleValue)), TCL_OK) :	\
    (((objPtr)->bytes != NULL) && ((objPtr)->length == 0))		\
	? TCL_ERROR :			\
    Tcl_GetNumberFromObj((interp), (objPtr), (ptrPtr), (tPtr)))

/*
 * Macro used to make the check for type overflow more mnemonic. This works by
 * comparing sign bits; the rest of the word is irrelevant. The ANSI C
 * "prototype" (where inttype_t is any integer type) is:
 *
 * MODULE_SCOPE int Overflowing(inttype_t a, inttype_t b, inttype_t sum);
 *
 * Check first the condition most likely to fail in usual code (at least for
 * usage in [incr]: do the first summand and the sum have != signs?
 */

#define Overflowing(a,b,sum) \
    ((((a)^(sum)) < 0) && (((a)^(b)) >= 0))

/*
 * Macro for checking whether the type is NaN, used when we're thinking about
 * throwing an error for supplying a non-number number.
 */

#ifndef ACCEPT_NAN
#define IsErroringNaNType(type)		((type) == TCL_NUMBER_NAN)
#else
#define IsErroringNaNType(type)		0
#endif

/*
 * Auxiliary tables used to compute powers of small integers.
 */

/*
 * Maximum base that, when raised to powers 2, 3, ..., 16, fits in a
 * Tcl_WideInt.
 */

static const Tcl_WideInt MaxBase64[] = {
    (Tcl_WideInt)46340*65536+62259,	/* 3037000499 == isqrt(2**63-1) */
    (Tcl_WideInt)2097151, (Tcl_WideInt)55108, (Tcl_WideInt)6208,
    (Tcl_WideInt)1448, (Tcl_WideInt)511, (Tcl_WideInt)234, (Tcl_WideInt)127,
    (Tcl_WideInt)78, (Tcl_WideInt)52, (Tcl_WideInt)38, (Tcl_WideInt)28,
    (Tcl_WideInt)22, (Tcl_WideInt)18, (Tcl_WideInt)15
};
static const size_t MaxBase64Size = sizeof(MaxBase64)/sizeof(Tcl_WideInt);

/*
 * Table giving 3, 4, ..., 13 raised to powers greater than 16 when the
 * results fit in a 64-bit signed integer.
 */

static const unsigned short Exp64Index[] = {
    0, 23, 38, 49, 57, 63, 67, 70, 72, 74, 75, 76
};
static const size_t Exp64IndexSize =
    sizeof(Exp64Index) / sizeof(unsigned short);
static const Tcl_WideInt Exp64Value[] = {
    (Tcl_WideInt)243*243*243*3*3,
    (Tcl_WideInt)243*243*243*3*3*3,
    (Tcl_WideInt)243*243*243*3*3*3*3,
    (Tcl_WideInt)243*243*243*243,
    (Tcl_WideInt)243*243*243*243*3,
    (Tcl_WideInt)243*243*243*243*3*3,
    (Tcl_WideInt)243*243*243*243*3*3*3,
    (Tcl_WideInt)243*243*243*243*3*3*3*3,
    (Tcl_WideInt)243*243*243*243*243,
    (Tcl_WideInt)243*243*243*243*243*3,
    (Tcl_WideInt)243*243*243*243*243*3*3,
    (Tcl_WideInt)243*243*243*243*243*3*3*3,
    (Tcl_WideInt)243*243*243*243*243*3*3*3*3,
    (Tcl_WideInt)243*243*243*243*243*243,
    (Tcl_WideInt)243*243*243*243*243*243*3,
    (Tcl_WideInt)243*243*243*243*243*243*3*3,
    (Tcl_WideInt)243*243*243*243*243*243*3*3*3,
    (Tcl_WideInt)243*243*243*243*243*243*3*3*3*3,
    (Tcl_WideInt)243*243*243*243*243*243*243,
    (Tcl_WideInt)243*243*243*243*243*243*243*3,
    (Tcl_WideInt)243*243*243*243*243*243*243*3*3,
    (Tcl_WideInt)243*243*243*243*243*243*243*3*3*3,
    (Tcl_WideInt)243*243*243*243*243*243*243*3*3*3*3,
    (Tcl_WideInt)1024*1024*1024*4*4,
    (Tcl_WideInt)1024*1024*1024*4*4*4,
    (Tcl_WideInt)1024*1024*1024*4*4*4*4,
    (Tcl_WideInt)1024*1024*1024*1024,
    (Tcl_WideInt)1024*1024*1024*1024*4,
    (Tcl_WideInt)1024*1024*1024*1024*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*4*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*4*4*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*1024,
    (Tcl_WideInt)1024*1024*1024*1024*1024*4,
    (Tcl_WideInt)1024*1024*1024*1024*1024*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*1024*4*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*1024*4*4*4*4,
    (Tcl_WideInt)1024*1024*1024*1024*1024*1024,
    (Tcl_WideInt)1024*1024*1024*1024*1024*1024*4,
    (Tcl_WideInt)3125*3125*3125*5*5,
    (Tcl_WideInt)3125*3125*3125*5*5*5,
    (Tcl_WideInt)3125*3125*3125*5*5*5*5,
    (Tcl_WideInt)3125*3125*3125*3125,
    (Tcl_WideInt)3125*3125*3125*3125*5,
    (Tcl_WideInt)3125*3125*3125*3125*5*5,
    (Tcl_WideInt)3125*3125*3125*3125*5*5*5,
    (Tcl_WideInt)3125*3125*3125*3125*5*5*5*5,
    (Tcl_WideInt)3125*3125*3125*3125*3125,
    (Tcl_WideInt)3125*3125*3125*3125*3125*5,
    (Tcl_WideInt)3125*3125*3125*3125*3125*5*5,
    (Tcl_WideInt)7776*7776*7776*6*6,
    (Tcl_WideInt)7776*7776*7776*6*6*6,
    (Tcl_WideInt)7776*7776*7776*6*6*6*6,
    (Tcl_WideInt)7776*7776*7776*7776,
    (Tcl_WideInt)7776*7776*7776*7776*6,
    (Tcl_WideInt)7776*7776*7776*7776*6*6,
    (Tcl_WideInt)7776*7776*7776*7776*6*6*6,
    (Tcl_WideInt)7776*7776*7776*7776*6*6*6*6,
    (Tcl_WideInt)16807*16807*16807*7*7,
    (Tcl_WideInt)16807*16807*16807*7*7*7,
    (Tcl_WideInt)16807*16807*16807*7*7*7*7,
    (Tcl_WideInt)16807*16807*16807*16807,
    (Tcl_WideInt)16807*16807*16807*16807*7,
    (Tcl_WideInt)16807*16807*16807*16807*7*7,
    (Tcl_WideInt)32768*32768*32768*8*8,
    (Tcl_WideInt)32768*32768*32768*8*8*8,
    (Tcl_WideInt)32768*32768*32768*8*8*8*8,
    (Tcl_WideInt)32768*32768*32768*32768,
    (Tcl_WideInt)59049*59049*59049*9*9,
    (Tcl_WideInt)59049*59049*59049*9*9*9,
    (Tcl_WideInt)59049*59049*59049*9*9*9*9,
    (Tcl_WideInt)100000*100000*100000*10*10,
    (Tcl_WideInt)100000*100000*100000*10*10*10,
    (Tcl_WideInt)161051*161051*161051*11*11,
    (Tcl_WideInt)161051*161051*161051*11*11*11,
    (Tcl_WideInt)248832*248832*248832*12*12,
    (Tcl_WideInt)371293*371293*371293*13*13
};
static const size_t Exp64ValueSize = sizeof(Exp64Value) / sizeof(Tcl_WideInt);

/*
 * Markers for ExecuteExtendedBinaryMathOp.
 */

#define DIVIDED_BY_ZERO		((Tcl_Obj *) -1)
#define EXPONENT_OF_ZERO	((Tcl_Obj *) -2)
#define GENERAL_ARITHMETIC_ERROR ((Tcl_Obj *) -3)
#define OUT_OF_MEMORY ((Tcl_Obj *) -4)

/*
 * Declarations for local procedures to this file:
 */

#ifdef TCL_COMPILE_STATS
static Tcl_ObjCmdProc EvalStatsCmd;
#endif /* TCL_COMPILE_STATS */
#ifdef TCL_COMPILE_DEBUG
static const char *	GetOpcodeName(const unsigned char *pc);
static void		PrintByteCodeInfo(ByteCode *codePtr);
static const char *	StringForResultCode(int result);
static void		ValidatePcAndStackTop(ByteCode *codePtr,
			    const unsigned char *pc, size_t stackTop,
			    int checkStack);
#endif /* TCL_COMPILE_DEBUG */
static ByteCode *	CompileExprObj(Tcl_Interp *interp, Tcl_Obj *objPtr);
static void		DeleteExecStack(ExecStack *esPtr);
static void		DupExprCodeInternalRep(Tcl_Obj *srcPtr,
			    Tcl_Obj *copyPtr);
static Tcl_Obj *	ExecuteExtendedBinaryMathOp(Tcl_Interp *interp,
			    int opcode, Tcl_Obj **constants,
			    Tcl_Obj *valuePtr, Tcl_Obj *value2Ptr);
static Tcl_Obj *	ExecuteExtendedUnaryMathOp(int opcode,
			    Tcl_Obj *valuePtr);
static void		FreeExprCodeInternalRep(Tcl_Obj *objPtr);
static ExceptionRange *	GetExceptRangeForPc(const unsigned char *pc,
			    int searchMode, ByteCode *codePtr);
static const char *	GetSrcInfoForPc(const unsigned char *pc,
			    ByteCode *codePtr, Tcl_Size *lengthPtr,
			    const unsigned char **pcBeg, Tcl_Size *cmdIdxPtr);
static Tcl_Obj **	GrowEvaluationStack(ExecEnv *eePtr, size_t growth,
			    int move);
static void		IllegalExprOperandType(Tcl_Interp *interp, const char *ord,
			    const unsigned char *pc, Tcl_Obj *opndPtr);
static void		InitByteCodeExecution(Tcl_Interp *interp);
static inline int	wordSkip(void *ptr);
static void		ReleaseDictIterator(Tcl_Obj *objPtr);
/* Useful elsewhere, make available in tclInt.h or stubs? */
static Tcl_Obj **	StackAllocWords(Tcl_Interp *interp, size_t numWords);
static Tcl_Obj **	StackReallocWords(Tcl_Interp *interp, size_t numWords);
static Tcl_NRPostProc	CopyCallback;
static Tcl_NRPostProc	ExprObjCallback;
static Tcl_NRPostProc	FinalizeOONext;
static Tcl_NRPostProc	FinalizeOONextFilter;
static Tcl_NRPostProc   TEBCresume;

/*
 * The structure below defines a bytecode Tcl object type to hold the
 * compiled bytecode for Tcl expressions.
 */

const Tcl_ObjType tclExprCodeType = {
    "exprcode",
    FreeExprCodeInternalRep,	/* freeIntRepProc */
    DupExprCodeInternalRep,	/* dupIntRepProc */
    NULL,			/* updateStringProc */
    NULL,			/* setFromAnyProc */
    TCL_OBJTYPE_V0
};

/*
 * Custom object type only used in this file; values of its type should never
 * be seen by user scripts.
 */

static const Tcl_ObjType dictIteratorType = {
    "dictIterator",
    ReleaseDictIterator,
    NULL, NULL, NULL,
    TCL_OBJTYPE_V0
};

/*
 *----------------------------------------------------------------------
 *
 * ReleaseDictIterator --
 *
 *	This takes apart a dictionary iterator that is stored in the given Tcl
 *	object.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Deallocates memory, marks the object as being untyped.
 *
 *----------------------------------------------------------------------
 */

static void
ReleaseDictIterator(
    Tcl_Obj *objPtr)
{
    Tcl_DictSearch *searchPtr;
    Tcl_Obj *dictPtr;
    const Tcl_ObjInternalRep *irPtr;

    irPtr = TclFetchInternalRep(objPtr, &dictIteratorType);
    assert(irPtr != NULL);

    /*
     * First kill the search, and then release the reference to the dictionary
     * that we were holding.
     */

    searchPtr = (Tcl_DictSearch *)irPtr->twoPtrValue.ptr1;
    Tcl_DictObjDone(searchPtr);
    Tcl_Free(searchPtr);

    dictPtr = (Tcl_Obj *)irPtr->twoPtrValue.ptr2;
    TclDecrRefCount(dictPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * InitByteCodeExecution --
 *
 *	This procedure is called once to initialize the Tcl bytecode
 *	interpreter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	This procedure initializes the array of instruction names. If
 *	compiling with the TCL_COMPILE_STATS flag, it initializes the array
 *	that counts the executions of each instruction and it creates the
 *	"evalstats" command. It also establishes the link between the Tcl
 *	"tcl_traceExec" and C "tclTraceExec" variables.
 *
 *----------------------------------------------------------------------
 */

#if defined(TCL_COMPILE_STATS) || defined(TCL_COMPILE_DEBUG)
static void
InitByteCodeExecution(
    Tcl_Interp *interp)		/* Interpreter for which the Tcl variable
				 * "tcl_traceExec" is linked to control
				 * instruction tracing. */
{
#ifdef TCL_COMPILE_DEBUG
    if (Tcl_LinkVar(interp, "tcl_traceExec", &tclTraceExec,
	    TCL_LINK_INT) != TCL_OK) {
	Tcl_Panic("InitByteCodeExecution: can't create link for tcl_traceExec variable");
    }
#endif
#ifdef TCL_COMPILE_STATS
    Tcl_CreateObjCommand(interp, "evalstats", EvalStatsCmd, NULL, NULL);
#endif /* TCL_COMPILE_STATS */
}

#else

static void
InitByteCodeExecution(
    TCL_UNUSED(Tcl_Interp *))
{
}
#endif

/*
 *----------------------------------------------------------------------
 *
 * TclCreateExecEnv --
 *
 *	This procedure creates a new execution environment for Tcl bytecode
 *	execution. An ExecEnv points to a Tcl evaluation stack. An ExecEnv is
 *	typically created once for each Tcl interpreter (Interp structure) and
 *	recursively passed to TclNRExecuteByteCode to execute ByteCode sequences
 *	for nested commands.
 *
 * Results:
 *	A newly allocated ExecEnv is returned. This points to an empty
 *	evaluation stack of the standard initial size.
 *
 * Side effects:
 *	The bytecode interpreter is also initialized here, as this procedure
 *	will be called before any call to TclNRExecuteByteCode.
 *
 *----------------------------------------------------------------------
 */

ExecEnv *
TclCreateExecEnv(
    Tcl_Interp *interp,		/* Interpreter for which the execution
				 * environment is being created. */
    size_t size)		/* The initial stack size, in number of words
				 * [sizeof(Tcl_Obj*)] */
{
    ExecEnv *eePtr = (ExecEnv *)Tcl_Alloc(sizeof(ExecEnv));
    ExecStack *esPtr = (ExecStack *)Tcl_Alloc(offsetof(ExecStack, stackWords)
	    + size * sizeof(Tcl_Obj *));

    eePtr->execStackPtr = esPtr;
    TclNewIntObj(eePtr->constants[0], 0);
    Tcl_IncrRefCount(eePtr->constants[0]);
    TclNewIntObj(eePtr->constants[1], 1);
    Tcl_IncrRefCount(eePtr->constants[1]);
    eePtr->interp = interp;
    eePtr->callbackPtr = NULL;
    eePtr->corPtr = NULL;
    eePtr->rewind = 0;

    esPtr->prevPtr = NULL;
    esPtr->nextPtr = NULL;
    esPtr->markerPtr = NULL;
    esPtr->endPtr = &esPtr->stackWords[size-1];
    esPtr->tosPtr = STACK_BASE(esPtr);

    Tcl_MutexLock(&execMutex);
    if (!execInitialized) {
	InitByteCodeExecution(interp);
	execInitialized = 1;
    }
    Tcl_MutexUnlock(&execMutex);

    return eePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * TclDeleteExecEnv --
 *
 *	Frees the storage for an ExecEnv.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Storage for an ExecEnv and its contained storage (e.g. the evaluation
 *	stack) is freed.
 *
 *----------------------------------------------------------------------
 */

static void
DeleteExecStack(
    ExecStack *esPtr)
{
    if (esPtr->markerPtr && !cachedInExit) {
	Tcl_Panic("freeing an execStack which is still in use");
    }

    if (esPtr->prevPtr) {
	esPtr->prevPtr->nextPtr = esPtr->nextPtr;
    }
    if (esPtr->nextPtr) {
	esPtr->nextPtr->prevPtr = esPtr->prevPtr;
    }
    Tcl_Free(esPtr);
}

void
TclDeleteExecEnv(
    ExecEnv *eePtr)		/* Execution environment to free. */
{
    ExecStack *esPtr = eePtr->execStackPtr, *tmpPtr;

	cachedInExit = TclInExit();

    /*
     * Delete all stacks in this exec env.
     */

    while (esPtr->nextPtr) {
	esPtr = esPtr->nextPtr;
    }
    while (esPtr) {
	tmpPtr = esPtr;
	esPtr = tmpPtr->prevPtr;
	DeleteExecStack(tmpPtr);
    }

    TclDecrRefCount(eePtr->constants[0]);
    TclDecrRefCount(eePtr->constants[1]);
    if (eePtr->callbackPtr && !cachedInExit) {
	Tcl_Panic("Deleting execEnv with pending TEOV callbacks!");
    }
    if (eePtr->corPtr && !cachedInExit) {
	Tcl_Panic("Deleting execEnv with existing coroutine");
    }
    Tcl_Free(eePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeExecution --
 *
 *	Finalizes the execution environment setup so that it can be later
 *	reinitialized.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	After this call, the next time TclCreateExecEnv will be called it will
 *	call InitByteCodeExecution.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeExecution(void)
{
    Tcl_MutexLock(&execMutex);
    execInitialized = 0;
    Tcl_MutexUnlock(&execMutex);
}

/*
 * Auxiliary code to insure that GrowEvaluationStack always returns correctly
 * aligned memory.
 *
 * WALLOCALIGN represents the alignment reqs in words, just as TCL_ALLOCALIGN
 * represents the reqs in bytes. This assumes that TCL_ALLOCALIGN is a
 * multiple of the wordsize 'sizeof(Tcl_Obj *)'.
 */

#define WALLOCALIGN \
    (TCL_ALLOCALIGN/sizeof(Tcl_Obj *))

/*
 * wordSkip computes how many words have to be skipped until the next aligned
 * word. Note that we are only interested in the low order bits of ptr, so
 * that any possible information loss in PTR2INT is of no consequence.
 */

static inline int
wordSkip(
    void *ptr)
{
    size_t mask = TCL_ALLOCALIGN-1;
    size_t base = PTR2UINT(ptr) & mask;
    return (TCL_ALLOCALIGN - base)/sizeof(Tcl_Obj *);
}

/*
 * Given a marker, compute where the following aligned memory starts.
 */

#define MEMSTART(markerPtr) \
    ((markerPtr) + wordSkip(markerPtr))

/*
 *----------------------------------------------------------------------
 *
 * GrowEvaluationStack --
 *
 *	This procedure grows a Tcl evaluation stack stored in an ExecEnv,
 *	copying over the words since the last mark if so requested. A mark is
 *	set at the beginning of the new area when no copying is requested.
 *
 * Results:
 *	Returns a pointer to the first usable word in the (possibly) grown
 *	stack.
 *
 * Side effects:
 *	The size of the evaluation stack may be grown, a marker is set
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj **
GrowEvaluationStack(
    ExecEnv *eePtr,		/* Points to the ExecEnv with an evaluation
				 * stack to enlarge. */
    size_t growth1,		/* How much larger than the current used
				 * size. */
    int move)			/* 1 if move words since last marker. */
{
    ExecStack *esPtr = eePtr->execStackPtr, *oldPtr = NULL;
    size_t newBytes;
    Tcl_Size growth = growth1;
    Tcl_Size newElems, currElems, needed = growth - (esPtr->endPtr - esPtr->tosPtr);
    Tcl_Obj **markerPtr = esPtr->markerPtr, **memStart;
    Tcl_Size moveWords = 0;

    if (move) {
	if (!markerPtr) {
	    Tcl_Panic("STACK: Reallocating with no previous alloc");
	}
	if (needed <= 0) {
	    return MEMSTART(markerPtr);
	}
    } else {
#ifndef PURIFY
	Tcl_Obj **tmpMarkerPtr = esPtr->tosPtr + 1;
	int offset = wordSkip(tmpMarkerPtr);

	if (needed + offset < 0) {
	    /*
	     * Put a marker pointing to the previous marker in this stack, and
	     * store it in esPtr as the current marker. Return a pointer to
	     * the start of aligned memory.
	     */

	    esPtr->markerPtr = tmpMarkerPtr;
	    memStart = tmpMarkerPtr + offset;
	    esPtr->tosPtr = memStart - 1;
	    *esPtr->markerPtr = (Tcl_Obj *) markerPtr;
	    return memStart;
	}
#endif
    }

    /*
     * Reset move to hold the number of words to be moved to new stack (if
     * any) and growth to hold the complete stack requirements: add one for
     * the marker, (WALLOCALIGN-1) for the maximal possible offset.
     */

    if (move) {
	moveWords = esPtr->tosPtr - MEMSTART(markerPtr) + 1;
    }
    needed = growth + moveWords + WALLOCALIGN;

    /*
     * Check if there is enough room in the next stack (if there is one, it
     * should be both empty and the last one!)
     */

    if (esPtr->nextPtr) {
	oldPtr = esPtr;
	esPtr = oldPtr->nextPtr;
	currElems = esPtr->endPtr - STACK_BASE(esPtr);
	if (esPtr->markerPtr || (esPtr->tosPtr != STACK_BASE(esPtr))) {
	    Tcl_Panic("STACK: Stack after current is in use");
	}
	if (esPtr->nextPtr) {
	    Tcl_Panic("STACK: Stack after current is not last");
	}
	if (needed <= currElems) {
	    goto newStackReady;
	}
	DeleteExecStack(esPtr);
	esPtr = oldPtr;
    } else {
	currElems = esPtr->endPtr - STACK_BASE(esPtr);
    }

    /*
     * We need to allocate a new stack! It needs to store 'growth' words,
     * including the elements to be copied over and the new marker.
     */

#ifndef PURIFY
    newElems = 2*currElems;
    while (needed > newElems) {
	newElems *= 2;
    }
#else
    newElems = needed;
#endif

    newBytes = offsetof(ExecStack, stackWords) + newElems * sizeof(Tcl_Obj *);

    oldPtr = esPtr;
    esPtr = (ExecStack *)Tcl_Alloc(newBytes);

    oldPtr->nextPtr = esPtr;
    esPtr->prevPtr = oldPtr;
    esPtr->nextPtr = NULL;
    esPtr->endPtr = &esPtr->stackWords[newElems-1];

  newStackReady:
    eePtr->execStackPtr = esPtr;

    /*
     * Store a NULL marker at the beginning of the stack, to indicate that
     * this is the first marker in this stack and that rewinding to here
     * should actually be a return to the previous stack.
     */

    esPtr->stackWords[0] = NULL;
    esPtr->markerPtr = &esPtr->stackWords[0];
    memStart = MEMSTART(esPtr->markerPtr);
    esPtr->tosPtr = memStart - 1;

    if (move) {
	memcpy(memStart, MEMSTART(markerPtr), moveWords*sizeof(Tcl_Obj *));
	esPtr->tosPtr += moveWords;
	oldPtr->markerPtr = (Tcl_Obj **) *markerPtr;
	oldPtr->tosPtr = markerPtr-1;
    }

    /*
     * Free the old stack if it is now unused.
     */

    if (!oldPtr->markerPtr) {
	DeleteExecStack(oldPtr);
    }

    return memStart;
}

/*
 *--------------------------------------------------------------
 *
 * TclStackAlloc, TclStackRealloc, TclStackFree --
 *
 *	Allocate memory from the execution stack; it has to be returned later
 *	with a call to TclStackFree.
 *
 * Results:
 *	A pointer to the first byte allocated, or panics if the allocation did
 *	not succeed.
 *
 * Side effects:
 *	The execution stack may be grown.
 *
 *--------------------------------------------------------------
 */

static Tcl_Obj **
StackAllocWords(
    Tcl_Interp *interp,
    size_t numWords)
{
    /*
     * Note that GrowEvaluationStack sets a marker in the stack. This marker
     * is read when rewinding, e.g., by TclStackFree.
     */

    Interp *iPtr = (Interp *) interp;
    ExecEnv *eePtr = iPtr->execEnvPtr;
    Tcl_Obj **resPtr = GrowEvaluationStack(eePtr, numWords, 0);

    eePtr->execStackPtr->tosPtr += numWords;
    return resPtr;
}

static Tcl_Obj **
StackReallocWords(
    Tcl_Interp *interp,
    size_t numWords)
{
    Interp *iPtr = (Interp *) interp;
    ExecEnv *eePtr = iPtr->execEnvPtr;
    Tcl_Obj **resPtr = GrowEvaluationStack(eePtr, numWords, 1);

    eePtr->execStackPtr->tosPtr += numWords;
    return resPtr;
}

void
TclStackFree(
    Tcl_Interp *interp,
    void *freePtr)
{
    Interp *iPtr = (Interp *) interp;
    ExecEnv *eePtr;
    ExecStack *esPtr;
    Tcl_Obj **markerPtr, *marker;

    if (iPtr == NULL || iPtr->execEnvPtr == NULL) {
	Tcl_Free(freePtr);
	return;
    }

    /*
     * Rewind the stack to the previous marker position. The current marker,
     * as set in the last call to GrowEvaluationStack, contains a pointer to
     * the previous marker.
     */

    eePtr = iPtr->execEnvPtr;
    esPtr = eePtr->execStackPtr;
    markerPtr = esPtr->markerPtr;
    marker = *markerPtr;

    if ((freePtr != NULL) && (MEMSTART(markerPtr) != (Tcl_Obj **)freePtr)) {
	Tcl_Panic("TclStackFree: incorrect freePtr (%p != %p). Call out of sequence?",
		freePtr, MEMSTART(markerPtr));
    }

    esPtr->tosPtr = markerPtr - 1;
    esPtr->markerPtr = (Tcl_Obj **) marker;
    if (marker) {
	return;
    }

    /*
     * Return to previous active stack. Note that repeated expansions or
     * reallocs could have generated several unused intervening stacks: free
     * them too.
     */

    while (esPtr->nextPtr) {
	esPtr = esPtr->nextPtr;
    }
    esPtr->tosPtr = STACK_BASE(esPtr);
    while (esPtr->prevPtr) {
	ExecStack *tmpPtr = esPtr->prevPtr;
	if (tmpPtr->tosPtr == STACK_BASE(tmpPtr)) {
	    DeleteExecStack(tmpPtr);
	} else {
	    break;
	}
    }
    if (esPtr->prevPtr) {
	eePtr->execStackPtr = esPtr->prevPtr;
#ifdef PURIFY
	eePtr->execStackPtr->nextPtr = NULL;
	DeleteExecStack(esPtr);
#endif
    } else {
	eePtr->execStackPtr = esPtr;
    }
}

void *
TclStackAlloc(
    Tcl_Interp *interp,
    size_t numBytes)
{
    Interp *iPtr = (Interp *) interp;
    size_t numWords;

    if (iPtr == NULL || iPtr->execEnvPtr == NULL) {
	return Tcl_Alloc(numBytes);
    }
    numWords = (numBytes + (sizeof(Tcl_Obj *) - 1))/sizeof(Tcl_Obj *);
    return StackAllocWords(interp, numWords);
}

void *
TclStackRealloc(
    Tcl_Interp *interp,
    void *ptr,
    size_t numBytes)
{
    Interp *iPtr = (Interp *) interp;
    ExecEnv *eePtr;
    ExecStack *esPtr;
    Tcl_Obj **markerPtr;
    size_t numWords;

    if (iPtr == NULL || iPtr->execEnvPtr == NULL) {
	return Tcl_Realloc(ptr, numBytes);
    }

    eePtr = iPtr->execEnvPtr;
    esPtr = eePtr->execStackPtr;
    markerPtr = esPtr->markerPtr;

    if (MEMSTART(markerPtr) != (Tcl_Obj **)ptr) {
	Tcl_Panic("TclStackRealloc: incorrect ptr. Call out of sequence?");
    }

    numWords = (numBytes + (sizeof(Tcl_Obj *) - 1))/sizeof(Tcl_Obj *);
    return (void *) StackReallocWords(interp, numWords);
}

/*
 *--------------------------------------------------------------
 *
 * Tcl_ExprObj --
 *
 *	Evaluate an expression in a Tcl_Obj.
 *
 * Results:
 *	A standard Tcl object result. If the result is other than TCL_OK, then
 *	the interpreter's result contains an error message. If the result is
 *	TCL_OK, then a pointer to the expression's result value object is
 *	stored in resultPtrPtr. In that case, the object's ref count is
 *	incremented to reflect the reference returned to the caller; the
 *	caller is then responsible for the resulting object and must, for
 *	example, decrement the ref count when it is finished with the object.
 *
 * Side effects:
 *	Any side effects caused by subcommands in the expression, if any. The
 *	interpreter result is not modified unless there is an error.
 *
 *--------------------------------------------------------------
 */

int
Tcl_ExprObj(
    Tcl_Interp *interp,		/* Context in which to evaluate the
				 * expression. */
    Tcl_Obj *objPtr,		/* Points to Tcl object containing expression
				 * to evaluate. */
    Tcl_Obj **resultPtrPtr)	/* Where the Tcl_Obj* that is the expression
				 * result is stored if no errors occur. */
{
    NRE_callback *rootPtr = TOP_CB(interp);
    Tcl_Obj *resultPtr;

    TclNewObj(resultPtr);
    TclNRAddCallback(interp, CopyCallback, resultPtrPtr, resultPtr,
	    NULL, NULL);
    Tcl_NRExprObj(interp, objPtr, resultPtr);
    return TclNRRunCallbacks(interp, TCL_OK, rootPtr);
}

static int
CopyCallback(
    void *data[],
    TCL_UNUSED(Tcl_Interp *),
    int result)
{
    Tcl_Obj **resultPtrPtr = (Tcl_Obj **)data[0];
    Tcl_Obj *resultPtr = (Tcl_Obj *)data[1];

    if (result == TCL_OK) {
	*resultPtrPtr = resultPtr;
	Tcl_IncrRefCount(resultPtr);
    } else {
	Tcl_DecrRefCount(resultPtr);
    }
    return result;
}

/*
 *--------------------------------------------------------------
 *
 * Tcl_NRExprObj --
 *
 *	Request evaluation of the expression in a Tcl_Obj by the NR stack.
 *
 * Results:
 *	Returns TCL_OK.
 *
 * Side effects:
 *	Compiles objPtr as a Tcl expression and places callbacks on the
 *	NR stack to execute the bytecode and store the result in resultPtr.
 *	If bytecode execution raises an exception, nothing is written
 *	to resultPtr, and the exceptional return code flows up the NR
 *	stack.  If the exception is TCL_ERROR, an error message is left
 *	in the interp result and the interp's return options dictionary
 *	holds additional error information too.  Execution of the bytecode
 *	may have other side effects, depending on the expression.
 *
 *--------------------------------------------------------------
 */

int
Tcl_NRExprObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,
    Tcl_Obj *resultPtr)
{
    ByteCode *codePtr;
    Tcl_InterpState state = Tcl_SaveInterpState(interp, TCL_OK);

    Tcl_ResetResult(interp);
    codePtr = CompileExprObj(interp, objPtr);

    Tcl_NRAddCallback(interp, ExprObjCallback, state, resultPtr,
	    NULL, NULL);
    return TclNRExecuteByteCode(interp, codePtr);
}

static int
ExprObjCallback(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Tcl_InterpState state = (Tcl_InterpState)data[0];
    Tcl_Obj *resultPtr = (Tcl_Obj *)data[1];

    if (result == TCL_OK) {
	TclSetDuplicateObj(resultPtr, Tcl_GetObjResult(interp));
	(void) Tcl_RestoreInterpState(interp, state);
    } else {
	Tcl_DiscardInterpState(state);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * CompileExprObj --
 *	Compile a Tcl expression value into ByteCode.
 *
 * Results:
 *	A (ByteCode *) is returned pointing to the resulting ByteCode.
 *
 * Side effects:
 *	The Tcl_ObjType of objPtr is changed to the "exprcode" type,
 *	and the ByteCode is kept in the internal rep (along with context
 *	data for checking validity) for faster operations the next time
 *	CompileExprObj is called on the same value.
 *
 *----------------------------------------------------------------------
 */

static ByteCode *
CompileExprObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr)
{
    Interp *iPtr = (Interp *) interp;
    CompileEnv compEnv;		/* Compilation environment structure allocated
				 * in frame. */
    ByteCode *codePtr = NULL;	/* Tcl Internal type of bytecode. Initialized
				 * to avoid compiler warning. */

    /*
     * Get the expression ByteCode from the object. If it exists, make sure it
     * is valid in the current context.
     */

    ByteCodeGetInternalRep(objPtr, &tclExprCodeType, codePtr);

    if (codePtr != NULL) {
	Namespace *namespacePtr = iPtr->varFramePtr->nsPtr;

	if (((Interp *) *codePtr->interpHandle != iPtr)
		|| (codePtr->compileEpoch != iPtr->compileEpoch)
		|| (codePtr->nsPtr != namespacePtr)
		|| (codePtr->nsEpoch != namespacePtr->resolverEpoch)
		|| (codePtr->localCachePtr != iPtr->varFramePtr->localCachePtr)) {
	    Tcl_StoreInternalRep(objPtr, &tclExprCodeType, NULL);
	    codePtr = NULL;
	}
    }

    if (codePtr == NULL) {
	/*
	 * TIP #280: No invoker (yet) - Expression compilation.
	 */

	Tcl_Size length;
	const char *string = TclGetStringFromObj(objPtr, &length);

	TclInitCompileEnv(interp, &compEnv, string, length, NULL, 0);
	TclCompileExpr(interp, string, length, &compEnv, 0);

	/*
	 * Successful compilation. If the expression yielded no instructions,
	 * push an zero object as the expression's result.
	 */

	if (compEnv.codeNext == compEnv.codeStart) {
	    TclEmitPush(TclRegisterLiteral(&compEnv, "0", 1, 0),
		    &compEnv);
	}

	/*
	 * Add a "done" instruction as the last instruction and change the
	 * object into a ByteCode object. Ownership of the literal objects and
	 * aux data items is given to the ByteCode object.
	 */

	TclEmitOpcode(INST_DONE, &compEnv);
	codePtr = TclInitByteCodeObj(objPtr, &tclExprCodeType, &compEnv);
	TclFreeCompileEnv(&compEnv);
	if (iPtr->varFramePtr->localCachePtr) {
	    codePtr->localCachePtr = iPtr->varFramePtr->localCachePtr;
	    codePtr->localCachePtr->refCount++;
	}
	TclDebugPrintByteCodeObj(objPtr);
    }
    return codePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * DupExprCodeInternalRep --
 *
 *	Part of the Tcl object type implementation for Tcl expression
 *	bytecode. We do not copy the bytecode internalrep. Instead, we return
 *	without setting copyPtr->typePtr, so the copy is a plain string copy
 *	of the expression value, and if it is to be used as a compiled
 *	expression, it will just need a recompile.
 *
 *	This makes sense, because with Tcl's copy-on-write practices, the
 *	usual (only?) time Tcl_DuplicateObj() will be called is when the copy
 *	is about to be modified, which would invalidate any copied bytecode
 *	anyway. The only reason it might make sense to copy the bytecode is if
 *	we had some modifying routines that operated directly on the internalrep,
 *	like we do for lists and dicts.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
DupExprCodeInternalRep(
    TCL_UNUSED(Tcl_Obj *),
    TCL_UNUSED(Tcl_Obj *))
{
    return;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeExprCodeInternalRep --
 *
 *	Part of the Tcl object type implementation for Tcl expression
 *	bytecode. Frees the storage allocated to hold the internal rep, unless
 *	ref counts indicate bytecode execution is still in progress.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	May free allocated memory. Leaves objPtr untyped.
 *
 *----------------------------------------------------------------------
 */

static void
FreeExprCodeInternalRep(
    Tcl_Obj *objPtr)
{
    ByteCode *codePtr;
    ByteCodeGetInternalRep(objPtr, &tclExprCodeType, codePtr);
    assert(codePtr != NULL);

    TclReleaseByteCode(codePtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileObj --
 *
 *	This procedure compiles the script contained in a Tcl_Obj.
 *
 * Results:
 *	A pointer to the corresponding ByteCode, never NULL.
 *
 * Side effects:
 *	The object is shimmered to bytecode type.
 *
 *----------------------------------------------------------------------
 */

ByteCode *
TclCompileObj(
    Tcl_Interp *interp,
    Tcl_Obj *objPtr,
    const CmdFrame *invoker,
    int word)
{
    Interp *iPtr = (Interp *) interp;
    ByteCode *codePtr;		/* Tcl Internal type of bytecode. */
    Namespace *namespacePtr = iPtr->varFramePtr->nsPtr;

    /*
     * If the object is not already of tclByteCodeType, compile it (and reset
     * the compilation flags in the interpreter; this should be done after any
     * compilation). Otherwise, check that it is "fresh" enough.
     */

    ByteCodeGetInternalRep(objPtr, &tclByteCodeType, codePtr);
    if (codePtr != NULL) {
	/*
	 * Make sure the Bytecode hasn't been invalidated by, e.g., someone
	 * redefining a command with a compile procedure (this might make the
	 * compiled code wrong). The object needs to be recompiled if it was
	 * compiled in/for a different interpreter, or for a different
	 * namespace, or for the same namespace but with different name
	 * resolution rules. Precompiled objects, however, are immutable and
	 * therefore they are not recompiled, even if the epoch has changed.
	 *
	 * To be pedantically correct, we should also check that the
	 * originating procPtr is the same as the current context procPtr
	 * (assuming one exists at all - none for global level). This code is
	 * #def'ed out because [info body] was changed to never return a
	 * bytecode type object, which should obviate us from the extra checks
	 * here.
	 */

	if (((Interp *) *codePtr->interpHandle != iPtr)
		|| (codePtr->compileEpoch != iPtr->compileEpoch)
		|| (codePtr->nsPtr != namespacePtr)
		|| (codePtr->nsEpoch != namespacePtr->resolverEpoch)) {
	    if (!(codePtr->flags & TCL_BYTECODE_PRECOMPILED)) {
		goto recompileObj;
	    }
	    if ((Interp *) *codePtr->interpHandle != iPtr) {
		Tcl_Panic("Tcl_EvalObj: compiled script jumped interps");
	    }
	    codePtr->compileEpoch = iPtr->compileEpoch;
	}

	/*
	 * Check that any compiled locals do refer to the current proc
	 * environment! If not, recompile.
	 */

	if (!(codePtr->flags & TCL_BYTECODE_PRECOMPILED) &&
		(codePtr->procPtr == NULL) &&
		(codePtr->localCachePtr != iPtr->varFramePtr->localCachePtr)){
	    goto recompileObj;
	}

	/*
	 * #280.
	 * Literal sharing fix. This part of the fix is not required by 8.4
	 * nor 8.5, because they eval-direct any literals, so just saving the
	 * argument locations per command in bytecode is enough, embedded
	 * 'eval' commands, etc. get the correct information.
	 *
	 * But in 8.6 all the embedded script are compiled, and the resulting
	 * bytecode stored in the literal. Now the shared literal has bytecode
	 * with location data for _one_ particular location this literal is
	 * found at. If we get executed from a different location the bytecode
	 * has to be recompiled to get the correct locations. Not doing this
	 * will execute the saved bytecode with data for a different location,
	 * causing 'info frame' to point to the wrong place in the sources.
	 *
	 * Future optimizations ...
	 * (1) Save the location data (ExtCmdLoc) keyed by start line. In that
	 *     case we recompile once per location of the literal, but not
	 *     continuously, because the moment we have all locations we do not
	 *     need to recompile any longer.
	 *
	 * (2) Alternative: Do not recompile, tell the execution engine the
	 *     offset between saved starting line and actual one. Then modify
	 *     the users to adjust the locations they have by this offset.
	 *
	 * (3) Alternative 2: Do not fully recompile, adjust just the location
	 *     information.
	 */

	if (invoker == NULL) {
	    return codePtr;
	} else {
	    Tcl_HashEntry *hePtr =
		    Tcl_FindHashEntry(iPtr->lineBCPtr, codePtr);
	    ExtCmdLoc *eclPtr;
	    CmdFrame *ctxCopyPtr;
	    int redo;

	    if (!hePtr) {
		return codePtr;
	    }

	    eclPtr = (ExtCmdLoc *)Tcl_GetHashValue(hePtr);
	    redo = 0;
	    ctxCopyPtr = (CmdFrame *)TclStackAlloc(interp, sizeof(CmdFrame));
	    *ctxCopyPtr = *invoker;

	    if (invoker->type == TCL_LOCATION_BC) {
		/*
		 * Note: Type BC => ctx.data.eval.path    is not used.
		 *		    ctx.data.tebc.codePtr used instead
		 */

		TclGetSrcInfoForPc(ctxCopyPtr);
		if (ctxCopyPtr->type == TCL_LOCATION_SOURCE) {
		    /*
		     * The reference made by 'TclGetSrcInfoForPc' is dead.
		     */

		    Tcl_DecrRefCount(ctxCopyPtr->data.eval.path);
		    ctxCopyPtr->data.eval.path = NULL;
		}
	    }

	    if (word < ctxCopyPtr->nline) {
		/*
		 * Note: We do not care if the line[word] is -1. This is a
		 * difference and requires a recompile (location changed from
		 * absolute to relative, literal is used fixed and through
		 * variable)
		 *
		 * Example:
		 * test info-32.0 using literal of info-24.8
		 *     (dict with ... vs           set body ...).
		 */

		redo = ((eclPtr->type == TCL_LOCATION_SOURCE)
			    && (eclPtr->start != ctxCopyPtr->line[word]))
			|| ((eclPtr->type == TCL_LOCATION_BC)
			    && (ctxCopyPtr->type == TCL_LOCATION_SOURCE));
	    }

	    TclStackFree(interp, ctxCopyPtr);
	    if (!redo) {
		return codePtr;
	    }
	}
    }

  recompileObj:
    iPtr->errorLine = 1;

    /*
     * TIP #280. Remember the invoker for a moment in the interpreter
     * structures so that the byte code compiler can pick it up when
     * initializing the compilation environment, i.e. the extended location
     * information.
     */

    iPtr->invokeCmdFramePtr = invoker;
    iPtr->invokeWord = word;
    TclSetByteCodeFromAny(interp, objPtr, NULL, NULL);
    iPtr->invokeCmdFramePtr = NULL;
    ByteCodeGetInternalRep(objPtr, &tclByteCodeType, codePtr);
    if (iPtr->varFramePtr->localCachePtr) {
	codePtr->localCachePtr = iPtr->varFramePtr->localCachePtr;
	codePtr->localCachePtr->refCount++;
    }
    return codePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * TclIncrObj --
 *
 *	Increment an integral value in a Tcl_Obj by an integral value held
 *	in another Tcl_Obj. Caller is responsible for making sure we can
 *	update the first object.
 *
 * Results:
 *	TCL_ERROR if either object is non-integer, and TCL_OK otherwise. On
 *	error, an error message is left in the interpreter (if it is not NULL,
 *	of course).
 *
 * Side effects:
 *	valuePtr gets the new incremented value.
 *
 *----------------------------------------------------------------------
 */

int
TclIncrObj(
    Tcl_Interp *interp,
    Tcl_Obj *valuePtr,
    Tcl_Obj *incrPtr)
{
    void *ptr1, *ptr2;
    int type1, type2;
    mp_int value, incr;
    mp_err err;

    if (Tcl_IsShared(valuePtr)) {
	Tcl_Panic("%s called with shared object", "TclIncrObj");
    }

    if (GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK) {
	/*
	 * Produce error message (reparse?!)
	 */

	return TclGetIntFromObj(interp, valuePtr, &type1);
    }
    if (GetNumberFromObj(NULL, incrPtr, &ptr2, &type2) != TCL_OK) {
	/*
	 * Produce error message (reparse?!)
	 */

	TclGetIntFromObj(interp, incrPtr, &type1);
	Tcl_AddErrorInfo(interp, "\n    (reading increment)");
	return TCL_ERROR;
    }

    if ((type1 == TCL_NUMBER_DOUBLE) || (type1 == TCL_NUMBER_NAN)) {
	/*
	 * Produce error message (reparse?!)
	 */

	return TclGetIntFromObj(interp, valuePtr, &type1);
    }
    if ((type2 == TCL_NUMBER_DOUBLE) || (type2 == TCL_NUMBER_NAN)) {
	/*
	 * Produce error message (reparse?!)
	 */

	TclGetIntFromObj(interp, incrPtr, &type1);
	Tcl_AddErrorInfo(interp, "\n    (reading increment)");
	return TCL_ERROR;
    }

    if ((type1 == TCL_NUMBER_INT) && (type2 == TCL_NUMBER_INT)) {
	Tcl_WideInt w1, w2, sum;

	w1 = *((const Tcl_WideInt *)ptr1);
	w2 = *((const Tcl_WideInt *)ptr2);
	sum = (Tcl_WideInt)((Tcl_WideUInt)w1 + (Tcl_WideUInt)w2);

	/*
	 * Check for overflow.
	 */

	if (!Overflowing(w1, w2, sum)) {
	    TclSetIntObj(valuePtr, sum);
	    return TCL_OK;
	}
    }

    Tcl_TakeBignumFromObj(interp, valuePtr, &value);
    Tcl_GetBignumFromObj(interp, incrPtr, &incr);
    err = mp_add(&value, &incr, &value);
    mp_clear(&incr);
    if (err != MP_OKAY) {
	return TCL_ERROR;
    }
    Tcl_SetBignumObj(valuePtr, &value);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * ArgumentBCEnter --
 *
 *	This is a helper for TclNRExecuteByteCode/TEBCresume that encapsulates
 *	a code sequence that is fairly common in the code but *not* commonly
 *	called.
 *
 * Results:
 *	None
 *
 * Side effects:
 *	May register information about the bytecode in the command frame.
 *
 *----------------------------------------------------------------------
 */

static void
ArgumentBCEnter(
    Tcl_Interp *interp,
    ByteCode *codePtr,
    TEBCdata *tdPtr,
    const unsigned char *pc,
    Tcl_Size objc,
    Tcl_Obj **objv)
{
    Tcl_Size cmd;

    if (GetSrcInfoForPc(pc, codePtr, NULL, NULL, &cmd)) {
	TclArgumentBCEnter(interp, objv, objc, codePtr, &tdPtr->cmdFrame, cmd,
		pc - codePtr->codeStart);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclNRExecuteByteCode --
 *
 *	This procedure executes the instructions of a ByteCode structure. It
 *	returns when a "done" instruction is executed or an error occurs.
 *
 * Results:
 *	The return value is one of the return codes defined in tcl.h (such as
 *	TCL_OK), and interp->objResultPtr refers to a Tcl object that either
 *	contains the result of executing the code or an error message.
 *
 * Side effects:
 *	Almost certainly, depending on the ByteCode's instructions.
 *
 *----------------------------------------------------------------------
 */
#define	bcFramePtr	(&TD->cmdFrame)
#define	initCatchTop	(TD->stack-1)
#define	initTosPtr	(initCatchTop+codePtr->maxExceptDepth)
#define esPtr		(iPtr->execEnvPtr->execStackPtr)

int
TclNRExecuteByteCode(
    Tcl_Interp *interp,		/* Token for command interpreter. */
    ByteCode *codePtr)		/* The bytecode sequence to interpret. */
{
    Interp *iPtr = (Interp *) interp;
    TEBCdata *TD;
    size_t size = sizeof(TEBCdata) - 1
	    + (codePtr->maxStackDepth + codePtr->maxExceptDepth)
		* sizeof(void *);
    size_t numWords = (size + sizeof(Tcl_Obj *) - 1) / sizeof(Tcl_Obj *);

    TclPreserveByteCode(codePtr);

    /*
     * Reserve the stack, setup the TEBCdataPtr (TD) and CallFrame
     *
     * The execution uses a unified stack: first a TEBCdata, immediately
     * above it a CmdFrame, then the catch stack, then the execution stack.
     *
     * Make sure the catch stack is large enough to hold the maximum number of
     * catch commands that could ever be executing at the same time (this will
     * be no more than the exception range array's depth). Make sure the
     * execution stack is large enough to execute this ByteCode.
     */

    TD = (TEBCdata *) GrowEvaluationStack(iPtr->execEnvPtr, numWords, 0);
    esPtr->tosPtr = initTosPtr;

    TD->codePtr     = codePtr;
    TD->catchTop    = initCatchTop;
    TD->auxObjList  = NULL;

    /*
     * TIP #280: Initialize the frame. Do not push it yet: it will be pushed
     * every time that we call out from this TD, popped when we return to it.
     */

    bcFramePtr->type = ((codePtr->flags & TCL_BYTECODE_PRECOMPILED)
	    ? TCL_LOCATION_PREBC : TCL_LOCATION_BC);
    bcFramePtr->level = (iPtr->cmdFramePtr ? iPtr->cmdFramePtr->level+1 : 1);
    bcFramePtr->framePtr = iPtr->framePtr;
    bcFramePtr->nextPtr = iPtr->cmdFramePtr;
    bcFramePtr->nline = 0;
    bcFramePtr->line = NULL;
    bcFramePtr->litarg = NULL;
    bcFramePtr->data.tebc.codePtr = codePtr;
    bcFramePtr->data.tebc.pc = NULL;
    bcFramePtr->cmdObj = NULL;
    bcFramePtr->cmd = NULL;
    bcFramePtr->len = 0;

#ifdef TCL_COMPILE_STATS
    iPtr->stats.numExecutions++;
#endif

    /*
     * Test namespace-50.9 demonstrates the need for this call.
     * Use a --enable-symbols=mem bug to see.
     */

    TclResetRewriteEnsemble(interp, 1);

    /*
     * Push the callback for bytecode execution
     */

    TclNRAddCallback(interp, TEBCresume, TD, /* pc */ NULL,
	    /* cleanup */ NULL, INT2PTR(iPtr->evalFlags));

    /*
     * Reset discard result flag - because it is applicable for this call only,
     * and should not affect all the nested invocations may return result.
     */
    iPtr->evalFlags &= ~TCL_EVAL_DISCARD_RESULT;

    return TCL_OK;
}

static int
TEBCresume(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    /*
     * Compiler cast directive - not a real variable.
     *	   Interp *iPtr = (Interp *) interp;
     */
#define iPtr ((Interp *) interp)

    /*
     * Check just the read-traced/write-traced bit of a variable.
     */

#define ReadTraced(varPtr) ((varPtr)->flags & VAR_TRACED_READ)
#define WriteTraced(varPtr) ((varPtr)->flags & VAR_TRACED_WRITE)
#define UnsetTraced(varPtr) ((varPtr)->flags & VAR_TRACED_UNSET)

    /*
     * Bottom of allocated stack holds the NR data
     */

    /*
     * Constants: variables that do not change during the execution, used
     * sporadically: no special need for speed.
     */

    unsigned interruptCounter = 1;
				/* Counter that is used to work out when to
				 * call Tcl_AsyncReady(). This must be 1
				 * initially so that we call the async-check
				 * stanza early, otherwise there are command
				 * sequences that can make the interpreter
				 * busy-loop without an opportunity to
				 * recognise an interrupt. */
    const char *curInstName;
#ifdef TCL_COMPILE_DEBUG
    int traceInstructions;	/* Whether we are doing instruction-level
				 * tracing or not. */
#endif

    Var *compiledLocals = iPtr->varFramePtr->compiledLocals;
    Tcl_Obj **constants = &iPtr->execEnvPtr->constants[0];

#define LOCAL(i)	(&compiledLocals[(i)])
#define TCONST(i)	(constants[(i)])

    /*
     * These macros are just meant to save some global variables that are not
     * used too frequently
     */

    TEBCdata *TD = (TEBCdata *)data[0];
#define auxObjList	(TD->auxObjList)
#define catchTop	(TD->catchTop)
#define codePtr		(TD->codePtr)
#define curEvalFlags	PTR2INT(data[3])  /* calling iPtr->evalFlags */

    /*
     * Globals: variables that store state, must remain valid at all times.
     */

    Tcl_Obj **tosPtr;		/* Cached pointer to top of evaluation
				 * stack. */
    const unsigned char *pc = (const unsigned char *)data[1];
				/* The current program counter. */
    unsigned char inst;		/* The currently running instruction */

    /*
     * Transfer variables - needed only between opcodes, but not while
     * executing an instruction.
     */

    int cleanup = PTR2INT(data[2]);
    Tcl_Obj *objResultPtr;
    int checkInterp = 0;	/* Indicates when a check of interp readyness
				 * is necessary. Set by CACHE_STACK_INFO() */

    /*
     * Locals - variables that are used within opcodes or bounded sections of
     * the file (jumps between opcodes within a family).
     * NOTE: These are now mostly defined locally where needed.
     */

    Tcl_Obj *objPtr, *valuePtr, *value2Ptr, *part1Ptr, *part2Ptr, *tmpPtr;
    Tcl_Obj **objv = NULL;
    Tcl_Size length, objc = 0;
    int opnd, pcAdjustment;
    Var *varPtr, *arrayPtr;
#ifdef TCL_COMPILE_DEBUG
    char cmdNameBuf[21];
#endif

#ifdef TCL_COMPILE_DEBUG
    int starting = 1;
    traceInstructions = (tclTraceExec == 3);
#endif

    TEBC_DATA_DIG();

#ifdef TCL_COMPILE_DEBUG
    if (!pc && (tclTraceExec >= 2)) {
	PrintByteCodeInfo(codePtr);
	fprintf(stdout, "  Starting stack top=%" TCL_SIZE_MODIFIER "d\n", CURR_DEPTH);
	fflush(stdout);
    }
#endif

    if (!pc) {
	/* bytecode is starting from scratch */
	pc = codePtr->codeStart;

	/*
	 * Reset the interp's result to avoid possible duplications of large
	 * objects [3c6e47363e], [781585], [804681], This can happen by start
	 * also in nested compiled blocks (enclosed in parent cycle).
	 * See else branch below for opposite handling by continuation/resume.
	 */

	objPtr = iPtr->objResultPtr;
	if (objPtr->refCount > 1) {
	    TclDecrRefCount(objPtr);
	    TclNewObj(objPtr);
	    Tcl_IncrRefCount(objPtr);
	    iPtr->objResultPtr = objPtr;
	}

	goto cleanup0;
    } else {
	/* resume from invocation */
	CACHE_STACK_INFO();

	NRE_ASSERT(iPtr->cmdFramePtr == bcFramePtr);
	if (bcFramePtr->cmdObj) {
	    Tcl_DecrRefCount(bcFramePtr->cmdObj);
	    bcFramePtr->cmdObj = NULL;
	    bcFramePtr->cmd = NULL;
	}
	iPtr->cmdFramePtr = bcFramePtr->nextPtr;
	if (iPtr->flags & INTERP_DEBUG_FRAME) {
	    TclArgumentBCRelease(interp, bcFramePtr);
	}
	if (iPtr->execEnvPtr->rewind) {
	    result = TCL_ERROR;
	    goto abnormalReturn;
	}
	if (codePtr->flags & TCL_BYTECODE_RECOMPILE) {
	    codePtr->flags &= ~TCL_BYTECODE_RECOMPILE;
	    checkInterp = 1;
	    iPtr->flags |= ERR_ALREADY_LOGGED;
	}

	if (result != TCL_OK) {
	    pc--;
	    goto processExceptionReturn;
	}

	/*
	 * Push the call's object result and continue execution with the next
	 * instruction.
	 */

	TRACE_WITH_OBJ(("%" TCL_SIZE_MODIFIER "d => ... after \"%.20s\": TCL_OK, result=",
		objc, cmdNameBuf), Tcl_GetObjResult(interp));

	/*
	 * Obtain and reset interp's result to avoid possible duplications of
	 * objects [Bug 781585]. We do not call Tcl_ResetResult to avoid any
	 * side effects caused by the resetting of errorInfo and errorCode
	 * [Bug 804681], which are not needed here. We chose instead to
	 * manipulate the interp's object result directly.
	 *
	 * Note that the result object is now in objResultPtr, it keeps the
	 * refCount it had in its role of iPtr->objResultPtr.
	 */

	objResultPtr = Tcl_GetObjResult(interp);
	TclNewObj(objPtr);
	Tcl_IncrRefCount(objPtr);
	iPtr->objResultPtr = objPtr;
#ifndef TCL_COMPILE_DEBUG
	if (*pc == INST_POP) {
	    TclDecrRefCount(objResultPtr);
	    NEXT_INST_V(1, cleanup, 0);
	}
#endif
	NEXT_INST_V(0, cleanup, -1);
    }

    /*
     * Targets for standard instruction endings; unrolled for speed in the
     * most frequent cases (instructions that consume up to two stack
     * elements).
     *
     * This used to be a "for(;;)" loop, with each instruction doing its own
     * cleanup.
     */

  cleanupV_pushObjResultPtr:
    switch (cleanup) {
    case 0:
	*(++tosPtr) = (objResultPtr);
	goto cleanup0;
    default:
	cleanup -= 2;
	while (cleanup--) {
	    objPtr = POP_OBJECT();
	    TclDecrRefCount(objPtr);
	}
	/* FALLTHRU */
    case 2:
    cleanup2_pushObjResultPtr:
	objPtr = POP_OBJECT();
	TclDecrRefCount(objPtr);
	/* FALLTHRU */
    case 1:
    cleanup1_pushObjResultPtr:
	objPtr = OBJ_AT_TOS;
	TclDecrRefCount(objPtr);
    }
    OBJ_AT_TOS = objResultPtr;
    goto cleanup0;

  cleanupV:
    switch (cleanup) {
    default:
	cleanup -= 2;
	while (cleanup--) {
	    objPtr = POP_OBJECT();
	    TclDecrRefCount(objPtr);
	}
	/* FALLTHRU */
    case 2:
    cleanup2:
	objPtr = POP_OBJECT();
	TclDecrRefCount(objPtr);
	/* FALLTHRU */
    case 1:
    cleanup1:
	objPtr = POP_OBJECT();
	TclDecrRefCount(objPtr);
	/* FALLTHRU */
    case 0:
	/*
	 * We really want to do nothing now, but this is needed for some
	 * compilers (SunPro CC).
	 */

	break;
    }
  cleanup0:

    /*
     * Check for asynchronous handlers [Bug 746722]; we do the check every
     * ASYNC_CHECK_COUNT instructions.
     */

    if ((--interruptCounter) == 0) {
	interruptCounter = ASYNC_CHECK_COUNT;
	DECACHE_STACK_INFO();
	if (TclAsyncReady(iPtr)) {
	    result = Tcl_AsyncInvoke(interp, result);
	    if (result == TCL_ERROR) {
		CACHE_STACK_INFO();
		goto gotError;
	    }
	}

	if (TclCanceled(iPtr)) {
	    if (Tcl_Canceled(interp, TCL_LEAVE_ERR_MSG) == TCL_ERROR) {
		CACHE_STACK_INFO();
		goto gotError;
	    }
	}

	if (TclLimitReady(iPtr->limit)) {
	    if (Tcl_LimitCheck(interp) == TCL_ERROR) {
		CACHE_STACK_INFO();
		goto gotError;
	    }
	}
	CACHE_STACK_INFO();
    }

    /*
     * These two instructions account for 26% of all instructions (according
     * to measurements on tclbench by Ben Vitale
     * [http://www.cs.toronto.edu/syslab/pubs/tcl2005-vitale-zaleski.pdf]
     * Resolving them before the switch reduces the cost of branch
     * mispredictions, seems to improve runtime by 5% to 15%, and (amazingly!)
     * reduces total obj size.
     */

    inst = *pc;

    peepholeStart:
#ifdef TCL_COMPILE_STATS
    iPtr->stats.instructionCount[*pc]++;
#endif

#ifdef TCL_COMPILE_DEBUG
    /*
     * Skip the stack depth check if an expansion is in progress.
     */

    CHECK_STACK();
    if (traceInstructions) {
	fprintf(stdout, "%2" TCL_SIZE_MODIFIER "d: %2" TCL_SIZE_MODIFIER "d ", iPtr->numLevels, CURR_DEPTH);
	TclPrintInstruction(codePtr, pc);
	fflush(stdout);
    }
#endif /* TCL_COMPILE_DEBUG */

    TCL_DTRACE_INST_NEXT();

    if (inst == INST_LOAD_SCALAR1) {
	goto instLoadScalar1;
    } else if (inst == INST_PUSH1) {
	PUSH_OBJECT(codePtr->objArrayPtr[TclGetUInt1AtPtr(pc+1)]);
	TRACE_WITH_OBJ(("%u => ", TclGetUInt1AtPtr(pc + 1)), OBJ_AT_TOS);
	inst = *(pc += 2);
	goto peepholeStart;
    } else if (inst == INST_START_CMD) {
	/*
	 * Peephole: do not run INST_START_CMD, just skip it
	 */

	iPtr->cmdCount += TclGetUInt4AtPtr(pc + 5);
	if (checkInterp) {
	    if (((codePtr->compileEpoch != iPtr->compileEpoch) ||
		    (codePtr->nsEpoch != iPtr->varFramePtr->nsPtr->resolverEpoch)) &&
		    !(codePtr->flags & TCL_BYTECODE_PRECOMPILED)) {
		goto instStartCmdFailed;
	    }
	    checkInterp = 0;
	}
	inst = *(pc += 9);
	goto peepholeStart;
    } else if (inst == INST_NOP) {
#ifndef TCL_COMPILE_DEBUG
	while (inst == INST_NOP)
#endif
	{
	    inst = *++pc;
	}
	goto peepholeStart;
    }

    switch (inst) {
    case INST_SYNTAX:
    case INST_RETURN_IMM: {
	int code = TclGetInt4AtPtr(pc+1);
	int level = TclGetUInt4AtPtr(pc+5);

	/*
	 * OBJ_AT_TOS is returnOpts, OBJ_UNDER_TOS is resultObjPtr.
	 */

	TRACE(("%u %u => ", code, level));
	result = TclProcessReturn(interp, code, level, OBJ_AT_TOS);
	if (result == TCL_OK) {
	    TRACE_APPEND(("continuing to next instruction (result=\"%.30s\")\n",
		    O2S(objResultPtr)));
	    NEXT_INST_F(9, 1, 0);
	}
	Tcl_SetObjResult(interp, OBJ_UNDER_TOS);
	if (*pc == INST_SYNTAX) {
	    iPtr->flags &= ~ERR_ALREADY_LOGGED;
	}
	cleanup = 2;
	TRACE_APPEND(("\n"));
	goto processExceptionReturn;
    }

    case INST_RETURN_STK:
	TRACE(("=> "));
	objResultPtr = POP_OBJECT();
	result = Tcl_SetReturnOptions(interp, OBJ_AT_TOS);
	if (result == TCL_OK) {
	    Tcl_DecrRefCount(OBJ_AT_TOS);
	    OBJ_AT_TOS = objResultPtr;
	    TRACE_APPEND(("continuing to next instruction (result=\"%.30s\")\n",
		    O2S(objResultPtr)));
	    NEXT_INST_F(1, 0, 0);
	} else if (result == TCL_ERROR) {
	    /*
	     * BEWARE! Must do this in this order, because an error in the
	     * option dictionary overrides the result (and can be verified by
	     * test).
	     */

	    Tcl_SetObjResult(interp, objResultPtr);
	    Tcl_SetReturnOptions(interp, OBJ_AT_TOS);
	    Tcl_DecrRefCount(OBJ_AT_TOS);
	    OBJ_AT_TOS = objResultPtr;
	} else {
	    Tcl_DecrRefCount(OBJ_AT_TOS);
	    OBJ_AT_TOS = objResultPtr;
	    Tcl_SetObjResult(interp, objResultPtr);
	}
	cleanup = 1;
	TRACE_APPEND(("\n"));
	goto processExceptionReturn;

    {
	CoroutineData *corPtr;
	void *yieldParameter;

    case INST_YIELD:
	corPtr = iPtr->execEnvPtr->corPtr;
	TRACE(("%.30s => ", O2S(OBJ_AT_TOS)));
	if (!corPtr) {
	    TRACE_APPEND(("ERROR: yield outside coroutine\n"));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "yield can only be called in a coroutine", -1));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "COROUTINE", "ILLEGAL_YIELD",
		    (char *)NULL);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

#ifdef TCL_COMPILE_DEBUG
	if (tclTraceExec >= 2) {
	    if (traceInstructions) {
		TRACE_APPEND(("YIELD...\n"));
	    } else {
		fprintf(stdout, "%" TCL_SIZE_MODIFIER "d: (%" TCL_T_MODIFIER "d) yielding value \"%.30s\"\n",
			iPtr->numLevels, (pc - codePtr->codeStart),
			Tcl_GetString(OBJ_AT_TOS));
	    }
	    fflush(stdout);
	}
#endif
	yieldParameter = NULL;	/*==CORO_ACTIVATE_YIELD*/
	Tcl_SetObjResult(interp, OBJ_AT_TOS);
	goto doYield;

    case INST_YIELD_TO_INVOKE:
	corPtr = iPtr->execEnvPtr->corPtr;
	valuePtr = OBJ_AT_TOS;
	if (!corPtr) {
	    TRACE(("[%.30s] => ERROR: yield outside coroutine\n",
		    O2S(valuePtr)));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "yieldto can only be called in a coroutine", -1));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "COROUTINE", "ILLEGAL_YIELD",
		    (char *)NULL);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	if (((Namespace *)TclGetCurrentNamespace(interp))->flags & NS_DYING) {
	    TRACE(("[%.30s] => ERROR: yield in deleted\n",
		    O2S(valuePtr)));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "yieldto called in deleted namespace", -1));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "COROUTINE", "YIELDTO_IN_DELETED",
		    (char *)NULL);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

#ifdef TCL_COMPILE_DEBUG
	if (tclTraceExec >= 2) {
	    if (traceInstructions) {
		TRACE(("[%.30s] => YIELD...\n", O2S(valuePtr)));
	    } else {
		/* FIXME: What is the right thing to trace? */
		fprintf(stdout, "%" TCL_SIZE_MODIFIER "d: (%" TCL_T_MODIFIER "d) yielding to [%.30s]\n",
			iPtr->numLevels, (pc - codePtr->codeStart),
			TclGetString(valuePtr));
	    }
	    fflush(stdout);
	}
#endif

	/*
	 * Install a tailcall record in the caller and continue with the
	 * yield. The yield is switched into multi-return mode (via the
	 * 'yieldParameter').
	 */

	iPtr->execEnvPtr = corPtr->callerEEPtr;
	Tcl_IncrRefCount(valuePtr);
	TclSetTailcall(interp, valuePtr);
	corPtr->yieldPtr = valuePtr;
	iPtr->execEnvPtr = corPtr->eePtr;
	yieldParameter = INT2PTR(1);	/*==CORO_ACTIVATE_YIELDM*/

    doYield:
	/* TIP #280: Record the last piece of info needed by
	 * 'TclGetSrcInfoForPc', and push the frame.
	 */

	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;

	if (iPtr->flags & INTERP_DEBUG_FRAME) {
	    ArgumentBCEnter(interp, codePtr, TD, pc, objc, objv);
	}

	pc++;
	cleanup = 1;
	TEBC_YIELD();
	TclNRAddCallback(interp, TclNRCoroutineActivateCallback, corPtr,
		yieldParameter, NULL, NULL);
	return TCL_OK;
    }

    case INST_TAILCALL: {
	Tcl_Obj *listPtr;

	opnd = TclGetUInt1AtPtr(pc+1);

	if (!(iPtr->varFramePtr->isProcCallFrame & 1)) {
	    TRACE(("%d => ERROR: tailcall in non-proc context\n", opnd));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "tailcall can only be called from a proc or lambda", -1));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "TAILCALL", "ILLEGAL", (char *)NULL);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

#ifdef TCL_COMPILE_DEBUG
	/* FIXME: What is the right thing to trace? */
	{
	    int i;

	    TRACE(("%d [", opnd));
	    for (i=opnd-1 ; i>=0 ; i--) {
		TRACE_APPEND(("\"%.30s\"", O2S(OBJ_AT_DEPTH(i))));
		if (i > 0) {
		    TRACE_APPEND((" "));
		}
	    }
	    TRACE_APPEND(("] => RETURN..."));
	}
#endif

	/*
	 * Push the evaluation of the called command into the NR callback
	 * stack.
	 */

	listPtr = Tcl_NewListObj(opnd, &OBJ_AT_DEPTH(opnd-1));
	TclListObjSetElement(NULL, listPtr, 0, TclNewNamespaceObj(
		(Tcl_Namespace *) iPtr->varFramePtr->nsPtr));
	if (iPtr->varFramePtr->tailcallPtr) {
	    Tcl_DecrRefCount(iPtr->varFramePtr->tailcallPtr);
	}
	iPtr->varFramePtr->tailcallPtr = listPtr;

	result = TCL_RETURN;
	cleanup = opnd;
	goto processExceptionReturn;
    }

    case INST_DONE:
	if (tosPtr > initTosPtr) {

	    if ((curEvalFlags & TCL_EVAL_DISCARD_RESULT) && (result == TCL_OK)) {
		/* simulate pop & fast done (like it does continue in loop) */
		TRACE_WITH_OBJ(("=> discarding "), OBJ_AT_TOS);
		objPtr = POP_OBJECT();
		TclDecrRefCount(objPtr);
		goto abnormalReturn;
	    }
	    /*
	     * Set the interpreter's object result to point to the topmost
	     * object from the stack, and check for a possible [catch]. The
	     * stackTop's level and refCount will be handled by "processCatch"
	     * or "abnormalReturn".
	     */

	    Tcl_SetObjResult(interp, OBJ_AT_TOS);
#ifdef TCL_COMPILE_DEBUG
	    TRACE_WITH_OBJ(("=> return code=%d, result=", result),
		    iPtr->objResultPtr);
	    if (traceInstructions) {
		fprintf(stdout, "\n");
	    }
#endif
	    goto checkForCatch;
	}
	(void) POP_OBJECT();
	goto abnormalReturn;

    case INST_PUSH4:
	objResultPtr = codePtr->objArrayPtr[TclGetUInt4AtPtr(pc+1)];
	TRACE_WITH_OBJ(("%u => ", TclGetUInt4AtPtr(pc+1)), objResultPtr);
	NEXT_INST_F(5, 0, 1);
    break;

    case INST_POP:
	TRACE_WITH_OBJ(("=> discarding "), OBJ_AT_TOS);
	objPtr = POP_OBJECT();
	TclDecrRefCount(objPtr);
	NEXT_INST_F(1, 0, 0);
    break;

    case INST_DUP:
	objResultPtr = OBJ_AT_TOS;
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;

    case INST_OVER:
	opnd = TclGetUInt4AtPtr(pc+1);
	objResultPtr = OBJ_AT_DEPTH(opnd);
	TRACE_WITH_OBJ(("%u => ", opnd), objResultPtr);
	NEXT_INST_F(5, 0, 1);
    break;

    case INST_REVERSE: {
	Tcl_Obj **a, **b;

	opnd = TclGetUInt4AtPtr(pc + 1);
	a = tosPtr - (opnd - 1);
	b = tosPtr;
	while (a < b) {
	    tmpPtr = *a;
	    *a = *b;
	    *b = tmpPtr;
	    a++;
	    b--;
	}
	TRACE(("%u => OK\n", opnd));
	NEXT_INST_F(5, 0, 0);
    }
    break;

    case INST_STR_CONCAT1:

	opnd = TclGetUInt1AtPtr(pc+1);
	DECACHE_STACK_INFO();
	objResultPtr = TclStringCat(interp, opnd, &OBJ_AT_DEPTH(opnd-1),
		TCL_STRING_IN_PLACE);
	if (objResultPtr == NULL) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	CACHE_STACK_INFO();
	TRACE_WITH_OBJ(("%u => ", opnd), objResultPtr);
	NEXT_INST_V(2, opnd, 1);
    break;

    case INST_CONCAT_STK:
	/*
	 * Pop the opnd (objc) top stack elements, run through Tcl_ConcatObj,
	 * and then decrement their ref counts.
	 */

	opnd = TclGetUInt4AtPtr(pc+1);
	objResultPtr = Tcl_ConcatObj(opnd, &OBJ_AT_DEPTH(opnd - 1));
	TRACE_WITH_OBJ(("%u => ", opnd), objResultPtr);
	NEXT_INST_V(5, opnd, 1);
    break;

    case INST_EXPAND_START:
	/*
	 * Push an element to the auxObjList. This records the current
	 * stack depth - i.e., the point in the stack where the expanded
	 * command starts.
	 *
	 * Use a Tcl_Obj as linked list element; slight mem waste, but faster
	 * allocation than Tcl_Alloc. This also abuses the Tcl_Obj structure, as
	 * we do not define a special tclObjType for it. It is not dangerous
	 * as the obj is never passed anywhere, so that all manipulations are
	 * performed here and in INST_INVOKE_EXPANDED (in case of an expansion
	 * error, also in INST_EXPAND_STKTOP).
	 */

	TclNewObj(objPtr);
	objPtr->internalRep.twoPtrValue.ptr2 = INT2PTR(CURR_DEPTH);
	objPtr->length = 0;
	PUSH_TAUX_OBJ(objPtr);
	TRACE(("=> mark depth as %" TCL_SIZE_MODIFIER "d\n", CURR_DEPTH));
	NEXT_INST_F(1, 0, 0);
    break;

    case INST_EXPAND_DROP:
	/*
	 * Drops an element of the auxObjList, popping stack elements to
	 * restore the stack to the state before the point where the aux
	 * element was created.
	 */

	CLANG_ASSERT(auxObjList);
	objc = CURR_DEPTH - PTR2INT(auxObjList->internalRep.twoPtrValue.ptr2);
	POP_TAUX_OBJ();
#ifdef TCL_COMPILE_DEBUG
	/* Ugly abuse! */
	starting = 1;
#endif
	TRACE(("=> drop %" TCL_SIZE_MODIFIER "d items\n", objc));
	NEXT_INST_V(1, objc, 0);

    case INST_EXPAND_STKTOP: {
	Tcl_Size i;
	TEBCdata *newTD;
	Tcl_Size oldCatchTopOff, oldTosPtrOff;

	/*
	 * Make sure that the element at stackTop is a list; if not, just
	 * leave with an error. Note that the element from the expand list
	 * will be removed at checkForCatch.
	 */

	objPtr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" => ", O2S(objPtr)));
	if (TclListObjGetElements(interp, objPtr, &objc, &objv) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	(void) POP_OBJECT();

	/*
	 * Make sure there is enough room in the stack to expand this list
	 * *and* process the rest of the command (at least up to the next
	 * argument expansion or command end). The operand is the current
	 * stack depth, as seen by the compiler.
	 */

	auxObjList->length += objc - 1;
	if ((objc > 1) && (auxObjList->length > 0)) {
	    length = auxObjList->length /* Total expansion room we need */
		    + codePtr->maxStackDepth /* Beyond the original max */
		    - CURR_DEPTH;	/* Relative to where we are */
	    DECACHE_STACK_INFO();
	    oldCatchTopOff = catchTop - initCatchTop;
	    oldTosPtrOff = tosPtr - initTosPtr;
	    newTD = (TEBCdata *)
		    GrowEvaluationStack(iPtr->execEnvPtr, length, 1);
	    if (newTD != TD) {
		/*
		 * Change the global data to point to the new stack: move the
		 * TEBCdataPtr TD, recompute the position of every other
		 * stack-allocated parameter, update the stack pointers.
		 */

		TD = newTD;

		catchTop = initCatchTop + oldCatchTopOff;
		tosPtr = initTosPtr + oldTosPtrOff;
	    }
	}

	/*
	 * Expand the list at stacktop onto the stack; free the list. Knowing
	 * that it has a freeIntRepProc we use Tcl_DecrRefCount().
	 */

	for (i = 0; i < objc; i++) {
	    PUSH_OBJECT(objv[i]);
	}

	TRACE_APPEND(("OK\n"));
	Tcl_DecrRefCount(objPtr);
	NEXT_INST_F(5, 0, 0);
    }
    break;

    case INST_EXPR_STK: {
	ByteCode *newCodePtr;

	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;
	DECACHE_STACK_INFO();
	newCodePtr = CompileExprObj(interp, OBJ_AT_TOS);
	CACHE_STACK_INFO();
	cleanup = 1;
	pc++;
	TEBC_YIELD();
	return TclNRExecuteByteCode(interp, newCodePtr);
    }

	/*
	 * INVOCATION BLOCK
	 */

    case INST_EVAL_STK:
    instEvalStk:
	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;

	cleanup = 1;
	pc += 1;
	/* yield next instruction */
	TEBC_YIELD();
	/* add TEBCResume for object at top of stack */
	return TclNRExecuteByteCode(interp,
		    TclCompileObj(interp, OBJ_AT_TOS, NULL, 0));

    case INST_INVOKE_EXPANDED:
	CLANG_ASSERT(auxObjList);
	objc = CURR_DEPTH - PTR2INT(auxObjList->internalRep.twoPtrValue.ptr2);
	POP_TAUX_OBJ();
	if (objc) {
	    pcAdjustment = 1;
	    goto doInvocation;
	}

	/*
	 * Nothing was expanded, return {}.
	 */

	TclNewObj(objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;

    case INST_INVOKE_STK4:
	objc = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	goto doInvocation;

    case INST_INVOKE_STK1:
	objc = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;

    doInvocation:
	objv = &OBJ_AT_DEPTH(objc-1);
	cleanup = objc;

#ifdef TCL_COMPILE_DEBUG
	if (tclTraceExec >= 2) {
	    Tcl_Size i;

	    if (traceInstructions) {
		strncpy(cmdNameBuf, TclGetString(objv[0]), 20);
		TRACE(("%" TCL_SIZE_MODIFIER "d => call ", objc));
	    } else {
		fprintf(stdout, "%" TCL_SIZE_MODIFIER "d: (%" TCL_T_MODIFIER "d) invoking ", iPtr->numLevels,
			(pc - codePtr->codeStart));
	    }
	    for (i = 0;  i < objc;  i++) {
		TclPrintObject(stdout, objv[i], 15);
		fprintf(stdout, " ");
	    }
	    fprintf(stdout, "\n");
	    fflush(stdout);
	}
#endif /*TCL_COMPILE_DEBUG*/

	/*
	 * Finally, let TclEvalObjv handle the command.
	 *
	 * TIP #280: Record the last piece of info needed by
	 * 'TclGetSrcInfoForPc', and push the frame.
	 */

	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;

	if (iPtr->flags & INTERP_DEBUG_FRAME) {
	    ArgumentBCEnter(interp, codePtr, TD, pc, objc, objv);
	}

	DECACHE_STACK_INFO();

	pc += pcAdjustment;
	TEBC_YIELD();
	if (objc > INT_MAX) {
	    return TclCommandWordLimitError(interp, objc);
	} else {
	    return TclNREvalObjv(interp, objc, objv,
		TCL_EVAL_NOERR | TCL_EVAL_SOURCE_IN_FRAME, NULL);
	}

    case INST_INVOKE_REPLACE:
	objc = TclGetUInt4AtPtr(pc+1);
	opnd = TclGetUInt1AtPtr(pc+5);
	objPtr = POP_OBJECT();
	objv = &OBJ_AT_DEPTH(objc-1);
	cleanup = objc;
#ifdef TCL_COMPILE_DEBUG
	if (tclTraceExec >= 2) {
	    Tcl_Size i;

	    if (traceInstructions) {
		strncpy(cmdNameBuf, TclGetString(objv[0]), 20);
		TRACE(("%" TCL_SIZE_MODIFIER "u => call (implementation %s) ", objc, O2S(objPtr)));
	    } else {
		fprintf(stdout,
			"%" TCL_SIZE_MODIFIER "d: (%" TCL_T_MODIFIER "u) invoking (using implementation %s) ",
			iPtr->numLevels, (pc - codePtr->codeStart),
			O2S(objPtr));
	    }
	    for (i = 0;  i < objc;  i++) {
		if (i < opnd) {
		    fprintf(stdout, "<");
		    TclPrintObject(stdout, objv[i], 15);
		    fprintf(stdout, ">");
		} else {
		    TclPrintObject(stdout, objv[i], 15);
		}
		fprintf(stdout, " ");
	    }
	    fprintf(stdout, "\n");
	    fflush(stdout);
	}
#endif /*TCL_COMPILE_DEBUG*/

	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;
	if (iPtr->flags & INTERP_DEBUG_FRAME) {
	    ArgumentBCEnter(interp, codePtr, TD, pc, objc, objv);
	}

	TclInitRewriteEnsemble(interp, opnd, 1, objv);

	{
	    Tcl_Obj *copyPtr = Tcl_NewListObj(objc - opnd + 1, NULL);

	    Tcl_ListObjAppendElement(NULL, copyPtr, objPtr);
	    Tcl_ListObjReplace(NULL, copyPtr, LIST_MAX, 0,
		    objc - opnd, objv + opnd);
	    Tcl_DecrRefCount(objPtr);
	    objPtr = copyPtr;
	}

	DECACHE_STACK_INFO();
	pc += 6;
	TEBC_YIELD();

	TclMarkTailcall(interp);
	TclNRAddCallback(interp, TclClearRootEnsemble, NULL, NULL, NULL, NULL);
	TclListObjGetElements(NULL, objPtr, &objc, &objv);
	TclNRAddCallback(interp, TclNRReleaseValues, objPtr, NULL, NULL, NULL);
	return TclNREvalObjv(interp, objc, objv, TCL_EVAL_INVOKE, NULL);

    /*
     * -----------------------------------------------------------------
     *	   Start of INST_LOAD instructions.
     *
     * WARNING: more 'goto' here than your doctor recommended! The different
     * instructions set the value of some variables and then jump to some
     * common execution code.
     */

    case INST_LOAD_SCALAR1:
    instLoadScalar1:
	opnd = TclGetUInt1AtPtr(pc+1);
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u => ", opnd));
	if (TclIsVarDirectReadable(varPtr)) {
	    /*
	     * No errors, no traces: just get the value.
	     */

	    objResultPtr = varPtr->value.objPtr;
	    TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	    NEXT_INST_F(2, 0, 1);
	}
	pcAdjustment = 2;
	cleanup = 0;
	arrayPtr = NULL;
	part1Ptr = part2Ptr = NULL;
	goto doCallPtrGetVar;

    case INST_LOAD_SCALAR4:
	opnd = TclGetUInt4AtPtr(pc+1);
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u => ", opnd));
	if (TclIsVarDirectReadable(varPtr)) {
	    /*
	     * No errors, no traces: just get the value.
	     */

	    objResultPtr = varPtr->value.objPtr;
	    TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	    NEXT_INST_F(5, 0, 1);
	}
	pcAdjustment = 5;
	cleanup = 0;
	arrayPtr = NULL;
	part1Ptr = part2Ptr = NULL;
	goto doCallPtrGetVar;

    case INST_LOAD_ARRAY4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	goto doLoadArray;

    case INST_LOAD_ARRAY1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;

    doLoadArray:
	part1Ptr = NULL;
	part2Ptr = OBJ_AT_TOS;
	arrayPtr = LOCAL(opnd);
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	TRACE(("%u \"%.30s\" => ", opnd, O2S(part2Ptr)));
	if (TclIsVarArray(arrayPtr) && !ReadTraced(arrayPtr)) {
	    varPtr = VarHashFindVar(arrayPtr->value.tablePtr, part2Ptr);
	    if (varPtr && TclIsVarDirectReadable(varPtr)) {
		/*
		 * No errors, no traces: just get the value.
		 */

		objResultPtr = varPtr->value.objPtr;
		TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
		NEXT_INST_F(pcAdjustment, 1, 1);
	    }
	}
	varPtr = TclLookupArrayElement(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "read", 0, 1, arrayPtr, opnd);
	if (varPtr == NULL) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	cleanup = 1;
	goto doCallPtrGetVar;

    case INST_LOAD_ARRAY_STK:
	cleanup = 2;
	part2Ptr = OBJ_AT_TOS;		/* element name */
	objPtr = OBJ_UNDER_TOS;		/* array name */
	TRACE(("\"%.30s(%.30s)\" => ", O2S(objPtr), O2S(part2Ptr)));
	goto doLoadStk;

    case INST_LOAD_STK:
    case INST_LOAD_SCALAR_STK:
	cleanup = 1;
	part2Ptr = NULL;
	objPtr = OBJ_AT_TOS;		/* variable name */
	TRACE(("\"%.30s\" => ", O2S(objPtr)));

    doLoadStk:
	part1Ptr = objPtr;
	varPtr = TclObjLookupVarEx(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "read", /*createPart1*/0, /*createPart2*/1,
		&arrayPtr);
	if (!varPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	if (TclIsVarDirectReadable2(varPtr, arrayPtr)) {
	    /*
	     * No errors, no traces: just get the value.
	     */

	    objResultPtr = varPtr->value.objPtr;
	    TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	    NEXT_INST_V(1, cleanup, 1);
	}
	pcAdjustment = 1;
	opnd = -1;

    doCallPtrGetVar:
	/*
	 * There are either errors or the variable is traced: call
	 * TclPtrGetVar to process fully.
	 */

	DECACHE_STACK_INFO();
	objResultPtr = TclPtrGetVarIdx(interp, varPtr, arrayPtr,
		part1Ptr, part2Ptr, TCL_LEAVE_ERR_MSG, opnd);
	CACHE_STACK_INFO();
	if (!objResultPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(pcAdjustment, cleanup, 1);

    /*
     *	   End of INST_LOAD instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_STORE and related instructions.
     *
     * WARNING: more 'goto' here than your doctor recommended! The different
     * instructions set the value of some variables and then jump to somme
     * common execution code.
     */

    {
	int storeFlags;
	Tcl_Size len;

    case INST_STORE_ARRAY4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	goto doStoreArrayDirect;

    case INST_STORE_ARRAY1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;

    doStoreArrayDirect:
	valuePtr = OBJ_AT_TOS;
	part2Ptr = OBJ_UNDER_TOS;
	arrayPtr = LOCAL(opnd);
	TRACE(("%u \"%.30s\" <- \"%.30s\" => ", opnd, O2S(part2Ptr),
		O2S(valuePtr)));
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	if (TclIsVarArray(arrayPtr) && !WriteTraced(arrayPtr)) {
	    varPtr = VarHashFindVar(arrayPtr->value.tablePtr, part2Ptr);
	    if (varPtr && TclIsVarDirectWritable(varPtr)) {
		tosPtr--;
		Tcl_DecrRefCount(OBJ_AT_TOS);
		OBJ_AT_TOS = valuePtr;
		goto doStoreVarDirect;
	    }
	}
	cleanup = 2;
	storeFlags = TCL_LEAVE_ERR_MSG;
	part1Ptr = NULL;
	goto doStoreArrayDirectFailed;

    case INST_STORE_SCALAR4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	goto doStoreScalarDirect;

    case INST_STORE_SCALAR1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;

    doStoreScalarDirect:
	valuePtr = OBJ_AT_TOS;
	varPtr = LOCAL(opnd);
	TRACE(("%u <- \"%.30s\" => ", opnd, O2S(valuePtr)));
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	if (!TclIsVarDirectWritable(varPtr)) {
	    storeFlags = TCL_LEAVE_ERR_MSG;
	    part1Ptr = NULL;
	    goto doStoreScalar;
	}

	/*
	 * No traces, no errors, plain 'set': we can safely inline. The value
	 * *will* be set to what's requested, so that the stack top remains
	 * pointing to the same Tcl_Obj.
	 */

    doStoreVarDirect:
	valuePtr = varPtr->value.objPtr;
	if (valuePtr != NULL) {
	    TclDecrRefCount(valuePtr);
	}
	objResultPtr = OBJ_AT_TOS;
	varPtr->value.objPtr = objResultPtr;
#ifndef TCL_COMPILE_DEBUG
	if (pc[pcAdjustment] == INST_POP) {
	    tosPtr--;
	    NEXT_INST_F((pcAdjustment+1), 0, 0);
	}
#else
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
#endif
	Tcl_IncrRefCount(objResultPtr);
	NEXT_INST_F(pcAdjustment, 0, 0);

    case INST_LAPPEND_STK:
	valuePtr = OBJ_AT_TOS; /* value to append */
	part2Ptr = NULL;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreStk;

    case INST_LAPPEND_ARRAY_STK:
	valuePtr = OBJ_AT_TOS; /* value to append */
	part2Ptr = OBJ_UNDER_TOS;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreStk;

    case INST_APPEND_STK:
	valuePtr = OBJ_AT_TOS; /* value to append */
	part2Ptr = NULL;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreStk;

    case INST_APPEND_ARRAY_STK:
	valuePtr = OBJ_AT_TOS; /* value to append */
	part2Ptr = OBJ_UNDER_TOS;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreStk;

    case INST_STORE_ARRAY_STK:
	valuePtr = OBJ_AT_TOS;
	part2Ptr = OBJ_UNDER_TOS;
	storeFlags = TCL_LEAVE_ERR_MSG;
	goto doStoreStk;

    case INST_STORE_STK:
    case INST_STORE_SCALAR_STK:
	valuePtr = OBJ_AT_TOS;
	part2Ptr = NULL;
	storeFlags = TCL_LEAVE_ERR_MSG;

    doStoreStk:
	objPtr = OBJ_AT_DEPTH(1 + (part2Ptr != NULL)); /* variable name */
	part1Ptr = objPtr;
#ifdef TCL_COMPILE_DEBUG
	if (part2Ptr == NULL) {
	    TRACE(("\"%.30s\" <- \"%.30s\" =>", O2S(part1Ptr),O2S(valuePtr)));
	} else {
	    TRACE(("\"%.30s(%.30s)\" <- \"%.30s\" => ",
		    O2S(part1Ptr), O2S(part2Ptr), O2S(valuePtr)));
	}
#endif
	varPtr = TclObjLookupVarEx(interp, objPtr, part2Ptr, TCL_LEAVE_ERR_MSG,
		"set", /*createPart1*/ 1, /*createPart2*/ 1, &arrayPtr);
	if (!varPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	cleanup = ((part2Ptr == NULL)? 2 : 3);
	pcAdjustment = 1;
	opnd = -1;
	goto doCallPtrSetVar;

    case INST_LAPPEND_ARRAY4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreArray;

    case INST_LAPPEND_ARRAY1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreArray;

    case INST_APPEND_ARRAY4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreArray;

    case INST_APPEND_ARRAY1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreArray;

    doStoreArray:
	valuePtr = OBJ_AT_TOS;
	part2Ptr = OBJ_UNDER_TOS;
	arrayPtr = LOCAL(opnd);
	TRACE(("%u \"%.30s\" <- \"%.30s\" => ", opnd, O2S(part2Ptr),
		O2S(valuePtr)));
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	cleanup = 2;
	part1Ptr = NULL;

    doStoreArrayDirectFailed:
	varPtr = TclLookupArrayElement(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "set", 1, 1, arrayPtr, opnd);
	if (!varPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	goto doCallPtrSetVar;

    case INST_LAPPEND_SCALAR4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreScalar;

    case INST_LAPPEND_SCALAR1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE
		| TCL_LIST_ELEMENT);
	goto doStoreScalar;

    case INST_APPEND_SCALAR4:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreScalar;

    case INST_APPEND_SCALAR1:
	opnd = TclGetUInt1AtPtr(pc+1);
	pcAdjustment = 2;
	storeFlags = (TCL_LEAVE_ERR_MSG | TCL_APPEND_VALUE);
	goto doStoreScalar;

    doStoreScalar:
	valuePtr = OBJ_AT_TOS;
	varPtr = LOCAL(opnd);
	TRACE(("%u <- \"%.30s\" => ", opnd, O2S(valuePtr)));
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	cleanup = 1;
	arrayPtr = NULL;
	part1Ptr = part2Ptr = NULL;

    doCallPtrSetVar:
	DECACHE_STACK_INFO();
	objResultPtr = TclPtrSetVarIdx(interp, varPtr, arrayPtr,
		part1Ptr, part2Ptr, valuePtr, storeFlags, opnd);
	CACHE_STACK_INFO();
	if (!objResultPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
#ifndef TCL_COMPILE_DEBUG
	if (pc[pcAdjustment] == INST_POP) {
	    NEXT_INST_V((pcAdjustment+1), cleanup, 0);
	}
#endif
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(pcAdjustment, cleanup, 1);

    case INST_LAPPEND_LIST:
	opnd = TclGetUInt4AtPtr(pc+1);
	valuePtr = OBJ_AT_TOS;
	varPtr = LOCAL(opnd);
	cleanup = 1;
	pcAdjustment = 5;
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u <- \"%.30s\" => ", opnd, O2S(valuePtr)));
	if (TclListObjGetElements(interp, valuePtr, &objc, &objv)
		!= TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (TclIsVarDirectReadable(varPtr)
		&& TclIsVarDirectWritable(varPtr)) {
	    goto lappendListDirect;
	}
	arrayPtr = NULL;
	part1Ptr = part2Ptr = NULL;
	goto lappendListPtr;

    case INST_LAPPEND_LIST_ARRAY:
	opnd = TclGetUInt4AtPtr(pc+1);
	valuePtr = OBJ_AT_TOS;
	part1Ptr = NULL;
	part2Ptr = OBJ_UNDER_TOS;
	arrayPtr = LOCAL(opnd);
	cleanup = 2;
	pcAdjustment = 5;
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	TRACE(("%u \"%.30s\" \"%.30s\" => ",
		opnd, O2S(part2Ptr), O2S(valuePtr)));
	if (TclListObjGetElements(interp, valuePtr, &objc, &objv)
		!= TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (TclIsVarArray(arrayPtr) && !ReadTraced(arrayPtr)
		&& !WriteTraced(arrayPtr)) {
	    varPtr = VarHashFindVar(arrayPtr->value.tablePtr, part2Ptr);
	    if (varPtr && TclIsVarDirectReadable(varPtr)
		    && TclIsVarDirectWritable(varPtr)) {
		goto lappendListDirect;
	    }
	}
	varPtr = TclLookupArrayElement(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "set", 1, 1, arrayPtr, opnd);
	if (varPtr == NULL) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	goto lappendListPtr;

    case INST_LAPPEND_LIST_ARRAY_STK:
	pcAdjustment = 1;
	cleanup = 3;
	valuePtr = OBJ_AT_TOS;
	part2Ptr = OBJ_UNDER_TOS;	/* element name */
	part1Ptr = OBJ_AT_DEPTH(2);	/* array name */
	TRACE(("\"%.30s(%.30s)\" \"%.30s\" => ",
		O2S(part1Ptr), O2S(part2Ptr), O2S(valuePtr)));
	goto lappendList;

    case INST_LAPPEND_LIST_STK:
	pcAdjustment = 1;
	cleanup = 2;
	valuePtr = OBJ_AT_TOS;
	part2Ptr = NULL;
	part1Ptr = OBJ_UNDER_TOS;	/* variable name */
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(part1Ptr), O2S(valuePtr)));
	goto lappendList;

    lappendListDirect:
	objResultPtr = varPtr->value.objPtr;
	if (TclListObjLength(interp, objResultPtr, &len) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (Tcl_IsShared(objResultPtr)) {
	    Tcl_Obj *newValue = Tcl_DuplicateObj(objResultPtr);

	    TclDecrRefCount(objResultPtr);
	    varPtr->value.objPtr = objResultPtr = newValue;
	    Tcl_IncrRefCount(newValue);
	}
	if (TclListObjAppendElements(interp, objResultPtr, objc, objv)
		!= TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(pcAdjustment, cleanup, 1);

    lappendList:
	opnd = -1;
	if (TclListObjGetElements(interp, valuePtr, &objc, &objv)
		!= TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	DECACHE_STACK_INFO();
	varPtr = TclObjLookupVarEx(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "set", 1, 1, &arrayPtr);
	CACHE_STACK_INFO();
	if (!varPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

    lappendListPtr:
	if (TclIsVarInHash(varPtr)) {
	    VarHashRefCount(varPtr)++;
	}
	if (arrayPtr && TclIsVarInHash(arrayPtr)) {
	    VarHashRefCount(arrayPtr)++;
	}
	DECACHE_STACK_INFO();
	objResultPtr = TclPtrGetVarIdx(interp, varPtr, arrayPtr,
		part1Ptr, part2Ptr, TCL_LEAVE_ERR_MSG, opnd);
	CACHE_STACK_INFO();
	if (TclIsVarInHash(varPtr)) {
	    VarHashRefCount(varPtr)--;
	}
	if (arrayPtr && TclIsVarInHash(arrayPtr)) {
	    VarHashRefCount(arrayPtr)--;
	}

	{
	    int createdNewObj = 0;
	    Tcl_Obj *valueToAssign;

	    if (!objResultPtr) {
		valueToAssign = valuePtr;
	    } else if (TclListObjLength(interp, objResultPtr, &len)!=TCL_OK) {
		TRACE_ERROR(interp);
		goto gotError;
	    } else {
		if (Tcl_IsShared(objResultPtr)) {
		    valueToAssign = Tcl_DuplicateObj(objResultPtr);
		    createdNewObj = 1;
		} else {
		    valueToAssign = objResultPtr;
		}
		if (TclListObjAppendElements(interp, valueToAssign,
			objc, objv) != TCL_OK) {
		    if (createdNewObj) {
			TclDecrRefCount(valueToAssign);
		    }
		    goto errorInLappendListPtr;
		}
	    }
	    DECACHE_STACK_INFO();
	    objResultPtr = TclPtrSetVarIdx(interp, varPtr, arrayPtr, part1Ptr,
		    part2Ptr, valueToAssign, TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    if (!objResultPtr) {
	    errorInLappendListPtr:
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(pcAdjustment, cleanup, 1);
    }

    /*
     *	   End of INST_STORE and related instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_INCR instructions.
     *
     * WARNING: more 'goto' here than your doctor recommended! The different
     * instructions set the value of some variables and then jump to some
     * common execution code.
     */

/*TODO: Consider more untangling here; merge with LOAD and STORE ? */

    {
	Tcl_Obj *incrPtr;
	Tcl_WideInt w;
	long increment;

    case INST_INCR_SCALAR1:
    case INST_INCR_ARRAY1:
    case INST_INCR_ARRAY_STK:
    case INST_INCR_SCALAR_STK:
    case INST_INCR_STK:
	opnd = TclGetUInt1AtPtr(pc+1);
	incrPtr = POP_OBJECT();
	switch (*pc) {
	case INST_INCR_SCALAR1:
	    pcAdjustment = 2;
	    goto doIncrScalar;
	case INST_INCR_ARRAY1:
	    pcAdjustment = 2;
	    goto doIncrArray;
	default:
	    pcAdjustment = 1;
	    goto doIncrStk;
	}

    case INST_INCR_ARRAY_STK_IMM:
    case INST_INCR_SCALAR_STK_IMM:
    case INST_INCR_STK_IMM:
	increment = TclGetInt1AtPtr(pc+1);
	TclNewIntObj(incrPtr, increment);
	Tcl_IncrRefCount(incrPtr);
	pcAdjustment = 2;

    doIncrStk:
	if ((*pc == INST_INCR_ARRAY_STK_IMM)
		|| (*pc == INST_INCR_ARRAY_STK)) {
	    part2Ptr = OBJ_AT_TOS;
	    objPtr = OBJ_UNDER_TOS;
	    TRACE(("\"%.30s(%.30s)\" (by %ld) => ",
		    O2S(objPtr), O2S(part2Ptr), increment));
	} else {
	    part2Ptr = NULL;
	    objPtr = OBJ_AT_TOS;
	    TRACE(("\"%.30s\" (by %ld) => ", O2S(objPtr), increment));
	}
	part1Ptr = objPtr;
	opnd = -1;
	varPtr = TclObjLookupVarEx(interp, objPtr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "read", 1, 1, &arrayPtr);
	if (!varPtr) {
	    DECACHE_STACK_INFO();
	    Tcl_AddErrorInfo(interp,
		    "\n    (reading value of variable to increment)");
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    Tcl_DecrRefCount(incrPtr);
	    goto gotError;
	}
	cleanup = ((part2Ptr == NULL)? 1 : 2);
	goto doIncrVar;

    case INST_INCR_ARRAY1_IMM:
	opnd = TclGetUInt1AtPtr(pc+1);
	increment = TclGetInt1AtPtr(pc+2);
	TclNewIntObj(incrPtr, increment);
	Tcl_IncrRefCount(incrPtr);
	pcAdjustment = 3;

    doIncrArray:
	part1Ptr = NULL;
	part2Ptr = OBJ_AT_TOS;
	arrayPtr = LOCAL(opnd);
	cleanup = 1;
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	TRACE(("%u \"%.30s\" (by %ld) => ", opnd, O2S(part2Ptr), increment));
	varPtr = TclLookupArrayElement(interp, part1Ptr, part2Ptr,
		TCL_LEAVE_ERR_MSG, "read", 1, 1, arrayPtr, opnd);
	if (!varPtr) {
	    TRACE_ERROR(interp);
	    Tcl_DecrRefCount(incrPtr);
	    goto gotError;
	}
	goto doIncrVar;

    case INST_INCR_SCALAR1_IMM:
	opnd = TclGetUInt1AtPtr(pc+1);
	increment = TclGetInt1AtPtr(pc+2);
	pcAdjustment = 3;
	cleanup = 0;
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}

	if (TclIsVarDirectModifyable(varPtr)) {
	    void *ptr;
	    int type;

	    objPtr = varPtr->value.objPtr;
	    if (GetNumberFromObj(NULL, objPtr, &ptr, &type) == TCL_OK) {
		if (type == TCL_NUMBER_INT) {
		    Tcl_WideInt augend = *((const Tcl_WideInt *)ptr);
		    Tcl_WideInt sum = (Tcl_WideInt)((Tcl_WideUInt)augend + (Tcl_WideUInt)increment);

		    /*
		     * Overflow when (augend and sum have different sign) and
		     * (augend and increment have the same sign). This is
		     * encapsulated in the Overflowing macro.
		     */

		    if (!Overflowing(augend, increment, sum)) {
			TRACE(("%u %ld => ", opnd, increment));
			if (Tcl_IsShared(objPtr)) {
			    objPtr->refCount--;	/* We know it's shared. */
			    TclNewIntObj(objResultPtr, sum);
			    Tcl_IncrRefCount(objResultPtr);
			    varPtr->value.objPtr = objResultPtr;
			} else {
			    objResultPtr = objPtr;
			    TclSetIntObj(objPtr, sum);
			}
			goto doneIncr;
		    }
		    w = (Tcl_WideInt)augend;

		    TRACE(("%u %ld => ", opnd, increment));
		    if (Tcl_IsShared(objPtr)) {
			objPtr->refCount--;	/* We know it's shared. */
			TclNewIntObj(objResultPtr, w + increment);
			Tcl_IncrRefCount(objResultPtr);
			varPtr->value.objPtr = objResultPtr;
		    } else {
			objResultPtr = objPtr;

			/*
			 * We know the sum value is outside the Tcl_WideInt range;
			 * use macro form that doesn't range test again.
			 */

			TclSetIntObj(objPtr, w+increment);
		    }
		    goto doneIncr;
		}	/* end if (type == TCL_NUMBER_INT) */
	    }
	    if (Tcl_IsShared(objPtr)) {
		objPtr->refCount--;	/* We know it's shared */
		objResultPtr = Tcl_DuplicateObj(objPtr);
		Tcl_IncrRefCount(objResultPtr);
		varPtr->value.objPtr = objResultPtr;
	    } else {
		objResultPtr = objPtr;
	    }
	    TclNewIntObj(incrPtr, increment);
	    if (TclIncrObj(interp, objResultPtr, incrPtr) != TCL_OK) {
		Tcl_DecrRefCount(incrPtr);
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    Tcl_DecrRefCount(incrPtr);
	    goto doneIncr;
	}

	/*
	 * All other cases, flow through to generic handling.
	 */

	TclNewIntObj(incrPtr, increment);
	Tcl_IncrRefCount(incrPtr);

    doIncrScalar:
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	arrayPtr = NULL;
	part1Ptr = part2Ptr = NULL;
	cleanup = 0;
	TRACE(("%u %s => ", opnd, TclGetString(incrPtr)));

    doIncrVar:
	if (TclIsVarDirectModifyable2(varPtr, arrayPtr)) {
	    objPtr = varPtr->value.objPtr;
	    if (Tcl_IsShared(objPtr)) {
		objPtr->refCount--;	/* We know it's shared */
		objResultPtr = Tcl_DuplicateObj(objPtr);
		Tcl_IncrRefCount(objResultPtr);
		varPtr->value.objPtr = objResultPtr;
	    } else {
		objResultPtr = objPtr;
	    }
	    if (TclIncrObj(interp, objResultPtr, incrPtr) != TCL_OK) {
		Tcl_DecrRefCount(incrPtr);
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    Tcl_DecrRefCount(incrPtr);
	} else {
	    DECACHE_STACK_INFO();
	    objResultPtr = TclPtrIncrObjVarIdx(interp, varPtr, arrayPtr,
		    part1Ptr, part2Ptr, incrPtr, TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    Tcl_DecrRefCount(incrPtr);
	    if (objResultPtr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
    doneIncr:
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
#ifndef TCL_COMPILE_DEBUG
	if (pc[pcAdjustment] == INST_POP) {
	    NEXT_INST_V((pcAdjustment+1), cleanup, 0);
	}
#endif
	NEXT_INST_V(pcAdjustment, cleanup, 1);
    }

    /*
     *	   End of INST_INCR instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_EXIST instructions.
     */

    case INST_EXIST_SCALAR:
	cleanup = 0;
	pcAdjustment = 5;
	opnd = TclGetUInt4AtPtr(pc+1);
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u => ", opnd));
	if (ReadTraced(varPtr)) {
	    DECACHE_STACK_INFO();
	    TclObjCallVarTraces(iPtr, NULL, varPtr, NULL, NULL,
		    TCL_TRACE_READS, 0, opnd);
	    CACHE_STACK_INFO();
	    if (TclIsVarUndefined(varPtr)) {
		TclCleanupVar(varPtr, NULL);
		varPtr = NULL;
	    }
	}
	goto afterExistsPeephole;

    case INST_EXIST_ARRAY:
	cleanup = 1;
	pcAdjustment = 5;
	opnd = TclGetUInt4AtPtr(pc+1);
	part2Ptr = OBJ_AT_TOS;
	arrayPtr = LOCAL(opnd);
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	TRACE(("%u \"%.30s\" => ", opnd, O2S(part2Ptr)));
	if (TclIsVarArray(arrayPtr) && !ReadTraced(arrayPtr)) {
	    varPtr = VarHashFindVar(arrayPtr->value.tablePtr, part2Ptr);
	    if (!varPtr || !ReadTraced(varPtr)) {
		goto afterExistsPeephole;
	    }
	}
	varPtr = TclLookupArrayElement(interp, NULL, part2Ptr, 0, "access",
		0, 1, arrayPtr, opnd);
	if (varPtr) {
	    if (ReadTraced(varPtr) || (arrayPtr && ReadTraced(arrayPtr))) {
		DECACHE_STACK_INFO();
		TclObjCallVarTraces(iPtr, arrayPtr, varPtr, NULL, part2Ptr,
			TCL_TRACE_READS, 0, opnd);
		CACHE_STACK_INFO();
	    }
	    if (TclIsVarUndefined(varPtr)) {
		TclCleanupVar(varPtr, arrayPtr);
		varPtr = NULL;
	    }
	}
	goto afterExistsPeephole;

    case INST_EXIST_ARRAY_STK:
	cleanup = 2;
	pcAdjustment = 1;
	part2Ptr = OBJ_AT_TOS;		/* element name */
	part1Ptr = OBJ_UNDER_TOS;	/* array name */
	TRACE(("\"%.30s(%.30s)\" => ", O2S(part1Ptr), O2S(part2Ptr)));
	goto doExistStk;

    case INST_EXIST_STK:
	cleanup = 1;
	pcAdjustment = 1;
	part2Ptr = NULL;
	part1Ptr = OBJ_AT_TOS;		/* variable name */
	TRACE(("\"%.30s\" => ", O2S(part1Ptr)));

    doExistStk:
	varPtr = TclObjLookupVarEx(interp, part1Ptr, part2Ptr, 0, "access",
		/*createPart1*/0, /*createPart2*/1, &arrayPtr);
	if (varPtr) {
	    if (ReadTraced(varPtr) || (arrayPtr && ReadTraced(arrayPtr))) {
		DECACHE_STACK_INFO();
		TclObjCallVarTraces(iPtr, arrayPtr, varPtr, part1Ptr, part2Ptr,
			TCL_TRACE_READS, 0, -1);
		CACHE_STACK_INFO();
	    }
	    if (TclIsVarUndefined(varPtr)) {
		TclCleanupVar(varPtr, arrayPtr);
		varPtr = NULL;
	    }
	}

	/*
	 * Peep-hole optimisation: if you're about to jump, do jump from here.
	 */

    afterExistsPeephole: {
	int found = (varPtr && !TclIsVarUndefined(varPtr));

	TRACE_APPEND(("%d\n", found ? 1 : 0));
	JUMP_PEEPHOLE_V(found, pcAdjustment, cleanup);
    }

    /*
     *	   End of INST_EXIST instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_UNSET instructions.
     */

    {
	int flags;

    case INST_UNSET_SCALAR:
	flags = TclGetUInt1AtPtr(pc+1) ? TCL_LEAVE_ERR_MSG : 0;
	opnd = TclGetUInt4AtPtr(pc+2);
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%s %u => ", (flags ? "normal" : "noerr"), opnd));
	if (TclIsVarDirectUnsettable(varPtr) && !TclIsVarInHash(varPtr)) {
	    /*
	     * No errors, no traces, no searches: just make the variable cease
	     * to exist.
	     */

	    if (!TclIsVarUndefined(varPtr)) {
		TclDecrRefCount(varPtr->value.objPtr);
	    } else if (flags & TCL_LEAVE_ERR_MSG) {
		goto slowUnsetScalar;
	    }
	    varPtr->value.objPtr = NULL;
	    TRACE_APPEND(("OK\n"));
	    NEXT_INST_F(6, 0, 0);
	}

    slowUnsetScalar:
	DECACHE_STACK_INFO();
	if (TclPtrUnsetVarIdx(interp, varPtr, NULL, NULL, NULL, flags,
		opnd) != TCL_OK && flags) {
	    goto errorInUnset;
	}
	CACHE_STACK_INFO();
	NEXT_INST_F(6, 0, 0);

    case INST_UNSET_ARRAY:
	flags = TclGetUInt1AtPtr(pc+1) ? TCL_LEAVE_ERR_MSG : 0;
	opnd = TclGetUInt4AtPtr(pc+2);
	part2Ptr = OBJ_AT_TOS;
	arrayPtr = LOCAL(opnd);
	while (TclIsVarLink(arrayPtr)) {
	    arrayPtr = arrayPtr->value.linkPtr;
	}
	TRACE(("%s %u \"%.30s\" => ",
		(flags ? "normal" : "noerr"), opnd, O2S(part2Ptr)));
	if (TclIsVarArray(arrayPtr) && !UnsetTraced(arrayPtr)
		&& !(arrayPtr->flags & VAR_SEARCH_ACTIVE)) {
	    varPtr = VarHashFindVar(arrayPtr->value.tablePtr, part2Ptr);
	    if (varPtr && TclIsVarDirectUnsettable(varPtr)) {
		/*
		 * No nasty traces and element exists, so we can proceed to
		 * unset it. Might still not exist though...
		 */

		if (!TclIsVarUndefined(varPtr)) {
		    TclDecrRefCount(varPtr->value.objPtr);
		    TclSetVarUndefined(varPtr);
		    TclClearVarNamespaceVar(varPtr);
		    TclCleanupVar(varPtr, arrayPtr);
		} else if (flags & TCL_LEAVE_ERR_MSG) {
		    goto slowUnsetArray;
		}
		TRACE_APPEND(("OK\n"));
		NEXT_INST_F(6, 1, 0);
	    } else if (!varPtr && !(flags & TCL_LEAVE_ERR_MSG)) {
		/*
		 * Don't need to do anything here.
		 */

		TRACE_APPEND(("OK\n"));
		NEXT_INST_F(6, 1, 0);
	    }
	}
    slowUnsetArray:
	DECACHE_STACK_INFO();
	varPtr = TclLookupArrayElement(interp, NULL, part2Ptr, flags, "unset",
		0, 0, arrayPtr, opnd);
	if (!varPtr) {
	    if (flags & TCL_LEAVE_ERR_MSG) {
		goto errorInUnset;
	    }
	} else if (TclPtrUnsetVarIdx(interp, varPtr, arrayPtr, NULL, part2Ptr,
		flags, opnd) != TCL_OK && (flags & TCL_LEAVE_ERR_MSG)) {
	    goto errorInUnset;
	}
	CACHE_STACK_INFO();
	NEXT_INST_F(6, 1, 0);

    case INST_UNSET_ARRAY_STK:
	flags = TclGetUInt1AtPtr(pc+1) ? TCL_LEAVE_ERR_MSG : 0;
	cleanup = 2;
	part2Ptr = OBJ_AT_TOS;		/* element name */
	part1Ptr = OBJ_UNDER_TOS;	/* array name */
	TRACE(("%s \"%.30s(%.30s)\" => ", (flags ? "normal" : "noerr"),
		O2S(part1Ptr), O2S(part2Ptr)));
	goto doUnsetStk;

    case INST_UNSET_STK:
	flags = TclGetUInt1AtPtr(pc+1) ? TCL_LEAVE_ERR_MSG : 0;
	cleanup = 1;
	part2Ptr = NULL;
	part1Ptr = OBJ_AT_TOS;		/* variable name */
	TRACE(("%s \"%.30s\" => ", (flags ? "normal" : "noerr"),
		O2S(part1Ptr)));

    doUnsetStk:
	DECACHE_STACK_INFO();
	if (TclObjUnsetVar2(interp, part1Ptr, part2Ptr, flags) != TCL_OK
		&& (flags & TCL_LEAVE_ERR_MSG)) {
	    goto errorInUnset;
	}
	CACHE_STACK_INFO();
	TRACE_APPEND(("OK\n"));
	NEXT_INST_V(2, cleanup, 0);

    errorInUnset:
	CACHE_STACK_INFO();
	TRACE_ERROR(interp);
	goto gotError;
    }
    break;

    /*
     *	   End of INST_UNSET instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_CONST instructions.
     */
    {
	const char *msgPart;

    case INST_CONST_IMM:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	cleanup = 1;
	part1Ptr = NULL;
	objPtr = OBJ_AT_TOS;
	TRACE(("%u \"%.30s\" => \n", opnd, O2S(objPtr)));
	varPtr = LOCAL(opnd);
	arrayPtr = NULL;
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	goto doConst;
    case INST_CONST_STK:
	opnd = -1;
	pcAdjustment = 1;
	cleanup = 2;
	part1Ptr = OBJ_UNDER_TOS;
	objPtr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(part1Ptr), O2S(objPtr)));
	varPtr = TclObjLookupVarEx(interp, part1Ptr, NULL, 0, NULL,
		/*createPart1*/1, /*createPart2*/0, &arrayPtr);
    doConst:
	if (TclIsVarConstant(varPtr)) {
	    TRACE_APPEND(("\n"));
	    NEXT_INST_V(pcAdjustment, cleanup, 0);
	}
	if (TclIsVarArray(varPtr)) {
	    msgPart = "variable is array";
	    goto constError;
	} else if (TclIsVarArrayElement(varPtr)) {
	    msgPart = "name refers to an element in an array";
	    goto constError;
	} else if (!TclIsVarUndefined(varPtr)) {
	    msgPart = "variable already exists";
	    goto constError;
	}
	if (TclIsVarDirectModifyable(varPtr)) {
	    varPtr->value.objPtr = objPtr;
	    Tcl_IncrRefCount(objPtr);
	} else {
	    Tcl_Obj *resPtr;

	    DECACHE_STACK_INFO();
	    resPtr = TclPtrSetVarIdx(interp, varPtr, arrayPtr, part1Ptr, NULL,
		    objPtr, TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    if (resPtr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
	TclSetVarConstant(varPtr);
	TRACE_APPEND(("\n"));
	NEXT_INST_V(pcAdjustment, cleanup, 0);

    constError:
	TclObjVarErrMsg(interp, part1Ptr, NULL, "make constant", msgPart, opnd);
	Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "CONST", (char *)NULL);
	TRACE_ERROR(interp);
	goto gotError;
    }

    /*
     *	   End of INST_CONST instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_ARRAY instructions.
     */

    case INST_ARRAY_EXISTS_IMM:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	cleanup = 0;
	part1Ptr = NULL;
	arrayPtr = NULL;
	TRACE(("%u => ", opnd));
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	goto doArrayExists;
    case INST_ARRAY_EXISTS_STK:
	opnd = -1;
	pcAdjustment = 1;
	cleanup = 1;
	part1Ptr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" => ", O2S(part1Ptr)));
	varPtr = TclObjLookupVarEx(interp, part1Ptr, NULL, 0, NULL,
		/*createPart1*/0, /*createPart2*/0, &arrayPtr);
    doArrayExists:
	DECACHE_STACK_INFO();
	result = TclCheckArrayTraces(interp, varPtr, arrayPtr, part1Ptr, opnd);
	CACHE_STACK_INFO();
	if (result == TCL_ERROR) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (varPtr && TclIsVarArray(varPtr) && !TclIsVarUndefined(varPtr)) {
	    objResultPtr = TCONST(1);
	} else {
	    objResultPtr = TCONST(0);
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(pcAdjustment, cleanup, 1);

    case INST_ARRAY_MAKE_IMM:
	opnd = TclGetUInt4AtPtr(pc+1);
	pcAdjustment = 5;
	cleanup = 0;
	part1Ptr = NULL;
	arrayPtr = NULL;
	TRACE(("%u => ", opnd));
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	goto doArrayMake;
    case INST_ARRAY_MAKE_STK:
	opnd = -1;
	pcAdjustment = 1;
	cleanup = 1;
	part1Ptr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" => ", O2S(part1Ptr)));
	varPtr = TclObjLookupVarEx(interp, part1Ptr, NULL, TCL_LEAVE_ERR_MSG,
		"set", /*createPart1*/1, /*createPart2*/0, &arrayPtr);
	if (varPtr == NULL) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
    doArrayMake:
	if (varPtr && !TclIsVarArray(varPtr)) {
	    if (TclIsVarArrayElement(varPtr) || !TclIsVarUndefined(varPtr)) {
		/*
		 * Either an array element, or a scalar: lose!
		 */

		TclObjVarErrMsg(interp, part1Ptr, NULL, "array set",
			"variable isn't array", opnd);
		DECACHE_STACK_INFO();
		Tcl_SetErrorCode(interp, "TCL", "WRITE", "ARRAY", (char *)NULL);
		CACHE_STACK_INFO();
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    TclInitArrayVar(varPtr);
#ifdef TCL_COMPILE_DEBUG
	    TRACE_APPEND(("done\n"));
	} else {
	    TRACE_APPEND(("nothing to do\n"));
#endif
	}
	NEXT_INST_V(pcAdjustment, cleanup, 0);

    /*
     *	   End of INST_ARRAY instructions.
     * -----------------------------------------------------------------
     *	   Start of variable linking instructions.
     */

    {
	Var *otherPtr;
	CallFrame *framePtr, *savedFramePtr;
	Tcl_Namespace *nsPtr;
	Namespace *savedNsPtr;

    case INST_UPVAR:
	TRACE(("%d %.30s %.30s => ", TclGetInt4AtPtr(pc+1),
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS)));

	if (TclObjGetFrame(interp, OBJ_UNDER_TOS, &framePtr) == -1) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Locate the other variable.
	 */

	savedFramePtr = iPtr->varFramePtr;
	iPtr->varFramePtr = framePtr;
	otherPtr = TclObjLookupVarEx(interp, OBJ_AT_TOS, NULL,
		TCL_LEAVE_ERR_MSG, "access", /*createPart1*/ 1,
		/*createPart2*/ 1, &varPtr);
	iPtr->varFramePtr = savedFramePtr;
	if (!otherPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	goto doLinkVars;

    case INST_NSUPVAR:
	TRACE(("%d %.30s %.30s => ", TclGetInt4AtPtr(pc+1),
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS)));
	if (TclGetNamespaceFromObj(interp, OBJ_UNDER_TOS, &nsPtr) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Locate the other variable.
	 */

	savedNsPtr = iPtr->varFramePtr->nsPtr;
	iPtr->varFramePtr->nsPtr = (Namespace *) nsPtr;
	otherPtr = TclObjLookupVarEx(interp, OBJ_AT_TOS, NULL,
		(TCL_NAMESPACE_ONLY|TCL_LEAVE_ERR_MSG|TCL_AVOID_RESOLVERS),
		"access", /*createPart1*/ 1, /*createPart2*/ 1, &varPtr);
	iPtr->varFramePtr->nsPtr = savedNsPtr;
	if (!otherPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	goto doLinkVars;

    case INST_VARIABLE:
	TRACE(("%d, %.30s => ", TclGetInt4AtPtr(pc+1), O2S(OBJ_AT_TOS)));
	otherPtr = TclObjLookupVarEx(interp, OBJ_AT_TOS, NULL,
		(TCL_NAMESPACE_ONLY | TCL_LEAVE_ERR_MSG), "access",
		/*createPart1*/ 1, /*createPart2*/ 1, &varPtr);
	if (!otherPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Do the [variable] magic.
	 */

	TclSetVarNamespaceVar(otherPtr);

    doLinkVars:

	/*
	 * If we are here, the local variable has already been created: do the
	 * little work of TclPtrMakeUpvar that remains to be done right here
	 * if there are no errors; otherwise, let it handle the case.
	 */

	opnd = TclGetInt4AtPtr(pc+1);
	varPtr = LOCAL(opnd);
	if ((varPtr != otherPtr) && !TclIsVarTraced(varPtr)
		&& (TclIsVarUndefined(varPtr) || TclIsVarLink(varPtr))) {
	    if (!TclIsVarUndefined(varPtr)) {
		/*
		 * Then it is a defined link.
		 */

		Var *linkPtr = varPtr->value.linkPtr;

		if (linkPtr == otherPtr) {
		    TRACE_APPEND(("already linked\n"));
		    NEXT_INST_F(5, 1, 0);
		}
		if (TclIsVarInHash(linkPtr)) {
		    VarHashRefCount(linkPtr)--;
		    if (TclIsVarUndefined(linkPtr)) {
			TclCleanupVar(linkPtr, NULL);
		    }
		}
	    }
	    TclSetVarLink(varPtr);
	    varPtr->value.linkPtr = otherPtr;
	    if (TclIsVarInHash(otherPtr)) {
		VarHashRefCount(otherPtr)++;
	    }
	} else if (TclPtrObjMakeUpvarIdx(interp, otherPtr, NULL, 0,
		opnd) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Do not pop the namespace or frame index, it may be needed for other
	 * variables - and [variable] did not push it at all.
	 */

	TRACE_APPEND(("link made\n"));
	NEXT_INST_F(5, 1, 0);
    }
    break;

    /*
     *	   End of variable linking instructions.
     * -----------------------------------------------------------------
     */

    case INST_JUMP1:
	opnd = TclGetInt1AtPtr(pc+1);
	TRACE(("%d => new pc %" TCL_Z_MODIFIER "u\n", opnd,
		(size_t)(pc + opnd - codePtr->codeStart)));
	NEXT_INST_F(opnd, 0, 0);
    break;

    case INST_JUMP4:
	opnd = TclGetInt4AtPtr(pc+1);
	TRACE(("%d => new pc %" TCL_Z_MODIFIER "u\n", opnd,
		(size_t)(pc + opnd - codePtr->codeStart)));
	NEXT_INST_F(opnd, 0, 0);

    {
	int jmpOffset[2], b;

	/* TODO: consider rewrite so we don't compute the offset we're not
	 * going to take. */
    case INST_JUMP_FALSE4:
	jmpOffset[0] = TclGetInt4AtPtr(pc+1);	/* FALSE offset */
	jmpOffset[1] = 5;			/* TRUE offset */
	goto doCondJump;

    case INST_JUMP_TRUE4:
	jmpOffset[0] = 5;
	jmpOffset[1] = TclGetInt4AtPtr(pc+1);
	goto doCondJump;

    case INST_JUMP_FALSE1:
	jmpOffset[0] = TclGetInt1AtPtr(pc+1);
	jmpOffset[1] = 2;
	goto doCondJump;

    case INST_JUMP_TRUE1:
	jmpOffset[0] = 2;
	jmpOffset[1] = TclGetInt1AtPtr(pc+1);

    doCondJump:
	valuePtr = OBJ_AT_TOS;
	TRACE(("%d => ", jmpOffset[
		(*pc==INST_JUMP_FALSE1 || *pc==INST_JUMP_FALSE4) ? 0 : 1]));

	/* TODO - check claim that taking address of b harms performance */
	/* TODO - consider optimization search for constants */
	if (TclGetBooleanFromObj(interp, valuePtr, &b) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

#ifdef TCL_COMPILE_DEBUG
	if (b) {
	    if ((*pc == INST_JUMP_TRUE1) || (*pc == INST_JUMP_TRUE4)) {
		TRACE_APPEND(("%.20s true, new pc %" TCL_Z_MODIFIER "u\n", O2S(valuePtr),
			(size_t)(pc + jmpOffset[1] - codePtr->codeStart)));
	    } else {
		TRACE_APPEND(("%.20s true\n", O2S(valuePtr)));
	    }
	} else {
	    if ((*pc == INST_JUMP_TRUE1) || (*pc == INST_JUMP_TRUE4)) {
		TRACE_APPEND(("%.20s false\n", O2S(valuePtr)));
	    } else {
		TRACE_APPEND(("%.20s false, new pc %" TCL_Z_MODIFIER "u\n", O2S(valuePtr),
			(size_t)(pc + jmpOffset[0] - codePtr->codeStart)));
	    }
	}
#endif
	NEXT_INST_F(jmpOffset[b], 1, 0);
    }
    break;

    case INST_JUMP_TABLE: {
	Tcl_HashEntry *hPtr;
	JumptableInfo *jtPtr;

	/*
	 * Jump to location looked up in a hashtable; fall through to next
	 * instr if lookup fails.
	 */

	opnd = TclGetInt4AtPtr(pc+1);
	jtPtr = (JumptableInfo *) codePtr->auxDataArrayPtr[opnd].clientData;
	TRACE(("%d \"%.20s\" => ", opnd, O2S(OBJ_AT_TOS)));
	hPtr = Tcl_FindHashEntry(&jtPtr->hashTable, TclGetString(OBJ_AT_TOS));
	if (hPtr != NULL) {
	    Tcl_Size jumpOffset = PTR2INT(Tcl_GetHashValue(hPtr));

	    TRACE_APPEND(("found in table, new pc %" TCL_Z_MODIFIER "u\n",
		    (size_t)(pc - codePtr->codeStart + jumpOffset)));
	    NEXT_INST_F(jumpOffset, 1, 0);
	} else {
	    TRACE_APPEND(("not found in table\n"));
	    NEXT_INST_F(5, 1, 0);
	}
    }
    break;

    /*
     * -----------------------------------------------------------------
     *	   Start of general introspector instructions.
     */

    case INST_NS_CURRENT:
	objResultPtr = TclNewNamespaceObj(TclGetCurrentNamespace(interp));
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;
    case INST_COROUTINE_NAME: {
	CoroutineData *corPtr = iPtr->execEnvPtr->corPtr;

	TclNewObj(objResultPtr);
	if (corPtr && !(corPtr->cmdPtr->flags & CMD_DYING)) {
	    Tcl_GetCommandFullName(interp, (Tcl_Command) corPtr->cmdPtr,
		    objResultPtr);
	}
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    }
    break;
    case INST_INFO_LEVEL_NUM:
	TclNewIntObj(objResultPtr, (int)iPtr->varFramePtr->level);
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;
    case INST_INFO_LEVEL_ARGS: {
	int level;
	CallFrame *framePtr = iPtr->varFramePtr;
	CallFrame *rootFramePtr = iPtr->rootFramePtr;

	TRACE(("\"%.30s\" => ", O2S(OBJ_AT_TOS)));
	if (TclGetIntFromObj(interp, OBJ_AT_TOS, &level) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (level <= 0) {
	    level += framePtr->level;
	}
	for (; ((int)framePtr->level!=level) && (framePtr!=rootFramePtr) ;
		framePtr = framePtr->callerVarPtr) {
	    /* Empty loop body */
	}
	if (framePtr == rootFramePtr) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad level \"%s\"", TclGetString(OBJ_AT_TOS)));
	    TRACE_ERROR(interp);
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "STACK_LEVEL",
		    TclGetString(OBJ_AT_TOS), (char *)NULL);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	objResultPtr = Tcl_NewListObj(framePtr->objc, framePtr->objv);
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 1, 1);
    }
    {
	Tcl_Command cmd, origCmd;

    case INST_RESOLVE_COMMAND:
	cmd = Tcl_GetCommandFromObj(interp, OBJ_AT_TOS);
	TclNewObj(objResultPtr);
	if (cmd != NULL) {
	    Tcl_GetCommandFullName(interp, cmd, objResultPtr);
	}
	TRACE_WITH_OBJ(("\"%.20s\" => ", O2S(OBJ_AT_TOS)), objResultPtr);
	NEXT_INST_F(1, 1, 1);

    case INST_ORIGIN_COMMAND:
	TRACE(("\"%.30s\" => ", O2S(OBJ_AT_TOS)));
	cmd = Tcl_GetCommandFromObj(interp, OBJ_AT_TOS);
	if (cmd == NULL) {
	    goto instOriginError;
	}
	origCmd = TclGetOriginalCommand(cmd);
	if (origCmd == NULL) {
	    origCmd = cmd;
	}

	TclNewObj(objResultPtr);
	Tcl_GetCommandFullName(interp, origCmd, objResultPtr);
	if (TclCheckEmptyString(objResultPtr) == TCL_EMPTYSTRING_YES ) {
	    Tcl_DecrRefCount(objResultPtr);
	    instOriginError:
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "invalid command name \"%s\"", TclGetString(OBJ_AT_TOS)));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "COMMAND",
		    TclGetString(OBJ_AT_TOS), (char *)NULL);
	    CACHE_STACK_INFO();
	    TRACE_APPEND(("ERROR: not command\n"));
	    goto gotError;
	}
	TRACE_APPEND(("\"%.30s\"", O2S(OBJ_AT_TOS)));
	NEXT_INST_F(1, 1, 1);
    }

    /*
     * -----------------------------------------------------------------
     *	   Start of TclOO support instructions.
     */

    {
	Object *oPtr;
	CallFrame *framePtr;
	CallContext *contextPtr;
	Tcl_Size skip, newDepth;

    case INST_TCLOO_SELF:
	framePtr = iPtr->varFramePtr;
	if (framePtr == NULL ||
		!(framePtr->isProcCallFrame & FRAME_IS_METHOD)) {
	    TRACE(("=> ERROR: no TclOO call context\n"));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "self may only be called from inside a method",
		    -1));
	    DECACHE_STACK_INFO();
	    OO_ERROR(interp, CONTEXT_REQUIRED);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	contextPtr = (CallContext *)framePtr->clientData;

	/*
	 * Call out to get the name; it's expensive to compute but cached.
	 */

	objResultPtr = TclOOObjectName(interp, contextPtr->oPtr);
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);

    case INST_TCLOO_NEXT_CLASS:
	opnd = TclGetUInt1AtPtr(pc+1);
	framePtr = iPtr->varFramePtr;
	valuePtr = OBJ_AT_DEPTH(opnd - 2);
	objv = &OBJ_AT_DEPTH(opnd - 1);
	skip = 2;
	TRACE(("%d => ", opnd));
	if (framePtr == NULL ||
		!(framePtr->isProcCallFrame & FRAME_IS_METHOD)) {
	    TRACE_APPEND(("ERROR: no TclOO call context\n"));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "nextto may only be called from inside a method",
		    -1));
	    DECACHE_STACK_INFO();
	    OO_ERROR(interp, CONTEXT_REQUIRED);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	contextPtr = (CallContext *)framePtr->clientData;

	oPtr = (Object *) Tcl_GetObjectFromObj(interp, valuePtr);
	if (oPtr == NULL) {
	    TRACE_APPEND(("ERROR: \"%.30s\" not object\n", O2S(valuePtr)));
	    goto gotError;
	} else {
	    Class *classPtr = oPtr->classPtr;
	    struct MInvoke *miPtr;
	    Tcl_Size i;
	    const char *methodType;

	    if (classPtr == NULL) {
		TRACE_APPEND(("ERROR: \"%.30s\" not class\n", O2S(valuePtr)));
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"\"%s\" is not a class", TclGetString(valuePtr)));
		DECACHE_STACK_INFO();
		OO_ERROR(interp, CLASS_REQUIRED);
		CACHE_STACK_INFO();
		goto gotError;
	    }

	    for (i=contextPtr->index+1 ; i<contextPtr->callPtr->numChain ; i++) {
		miPtr = contextPtr->callPtr->chain + i;
		if (!miPtr->isFilter &&
			miPtr->mPtr->declaringClassPtr == classPtr) {
		    newDepth = i;
#ifdef TCL_COMPILE_DEBUG
		    if (tclTraceExec >= 2) {
			if (traceInstructions) {
			    strncpy(cmdNameBuf, TclGetString(objv[0]), 20);
			} else {
			    fprintf(stdout, "%" TCL_SIZE_MODIFIER "d: (%" TCL_T_MODIFIER "d) invoking ",
				    iPtr->numLevels,
				    (size_t)(pc - codePtr->codeStart));
			}
			for (i = 0;  i < opnd;  i++) {
			    TclPrintObject(stdout, objv[i], 15);
			    fprintf(stdout, " ");
			}
			fprintf(stdout, "\n");
			fflush(stdout);
		    }
#endif /*TCL_COMPILE_DEBUG*/
		    goto doInvokeNext;
		}
	    }

	    if (contextPtr->callPtr->flags & CONSTRUCTOR) {
		methodType = "constructor";
	    } else if (contextPtr->callPtr->flags & DESTRUCTOR) {
		methodType = "destructor";
	    } else {
		methodType = "method";
	    }

	    TRACE_APPEND(("ERROR: \"%.30s\" not on reachable chain\n",
		    O2S(valuePtr)));
	    for (i = contextPtr->index ; i != TCL_INDEX_NONE ; i--) {
		miPtr = contextPtr->callPtr->chain + i;
		if (miPtr->isFilter
			|| miPtr->mPtr->declaringClassPtr != classPtr) {
		    continue;
		}
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"%s implementation by \"%s\" not reachable from here",
			methodType, TclGetString(valuePtr)));
		DECACHE_STACK_INFO();
		OO_ERROR(interp, CLASS_NOT_REACHABLE);
		CACHE_STACK_INFO();
		goto gotError;
	    }
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "%s has no non-filter implementation by \"%s\"",
		    methodType, TclGetString(valuePtr)));
	    DECACHE_STACK_INFO();
	    OO_ERROR(interp, CLASS_NOT_THERE);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

    case INST_TCLOO_NEXT:
	opnd = TclGetUInt1AtPtr(pc+1);
	objv = &OBJ_AT_DEPTH(opnd - 1);
	framePtr = iPtr->varFramePtr;
	skip = 1;
	TRACE(("%d => ", opnd));
	if (framePtr == NULL ||
		!(framePtr->isProcCallFrame & FRAME_IS_METHOD)) {
	    TRACE_APPEND(("ERROR: no TclOO call context\n"));
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "next may only be called from inside a method",
		    -1));
	    DECACHE_STACK_INFO();
	    OO_ERROR(interp, CONTEXT_REQUIRED);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	contextPtr = (CallContext *)framePtr->clientData;

	newDepth = contextPtr->index + 1;
	if (newDepth >= contextPtr->callPtr->numChain) {
	    /*
	     * We're at the end of the chain; generate an error message unless
	     * the interpreter is being torn down, in which case we might be
	     * getting here because of methods/destructors doing a [next] (or
	     * equivalent) unexpectedly.
	     */

	    const char *methodType;

	    if (contextPtr->callPtr->flags & CONSTRUCTOR) {
		methodType = "constructor";
	    } else if (contextPtr->callPtr->flags & DESTRUCTOR) {
		methodType = "destructor";
	    } else {
		methodType = "method";
	    }

	    TRACE_APPEND(("ERROR: no TclOO next impl\n"));
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "no next %s implementation", methodType));
	    DECACHE_STACK_INFO();
	    OO_ERROR(interp, NOTHING_NEXT);
	    CACHE_STACK_INFO();
	    goto gotError;
#ifdef TCL_COMPILE_DEBUG
	} else if (tclTraceExec >= 2) {
	    int i;

	    if (traceInstructions) {
		strncpy(cmdNameBuf, TclGetString(objv[0]), 20);
	    } else {
		fprintf(stdout, "%" TCL_SIZE_MODIFIER "d: (%" TCL_Z_MODIFIER "u) invoking ",
			iPtr->numLevels, (pc - codePtr->codeStart));
	    }
	    for (i = 0;  i < opnd;  i++) {
		TclPrintObject(stdout, objv[i], 15);
		fprintf(stdout, " ");
	    }
	    fprintf(stdout, "\n");
	    fflush(stdout);
#endif /*TCL_COMPILE_DEBUG*/
	}

    doInvokeNext:
	bcFramePtr->data.tebc.pc = (char *) pc;
	iPtr->cmdFramePtr = bcFramePtr;

	if (iPtr->flags & INTERP_DEBUG_FRAME) {
	    ArgumentBCEnter(interp, codePtr, TD, pc, opnd, objv);
	}

	pcAdjustment = 2;
	cleanup = opnd;
	DECACHE_STACK_INFO();
	iPtr->varFramePtr = framePtr->callerVarPtr;
	pc += pcAdjustment;
	TEBC_YIELD();

	TclPushTailcallPoint(interp);
	oPtr = contextPtr->oPtr;
	if (oPtr->flags & FILTER_HANDLING) {
	    TclNRAddCallback(interp, FinalizeOONextFilter,
		    framePtr, contextPtr, INT2PTR(contextPtr->index),
		    INT2PTR(contextPtr->skip));
	} else {
	    TclNRAddCallback(interp, FinalizeOONext,
		    framePtr, contextPtr, INT2PTR(contextPtr->index),
		    INT2PTR(contextPtr->skip));
	}
	contextPtr->skip = skip;
	contextPtr->index = newDepth;
	if (contextPtr->callPtr->chain[newDepth].isFilter
		|| contextPtr->callPtr->flags & FILTER_HANDLING) {
	    oPtr->flags |= FILTER_HANDLING;
	} else {
	    oPtr->flags &= ~FILTER_HANDLING;
	}

	{
	    Method *const mPtr =
		    contextPtr->callPtr->chain[newDepth].mPtr;

	    if (mPtr->typePtr->version < TCL_OO_METHOD_VERSION_2) {
		return mPtr->typePtr->callProc(mPtr->clientData, interp,
			(Tcl_ObjectContext) contextPtr, opnd, objv);
	    }
	    return ((Tcl_MethodCallProc2 *)(void *)(mPtr->typePtr->callProc))(mPtr->clientData, interp,
		    (Tcl_ObjectContext) contextPtr, opnd, objv);
	}

    case INST_TCLOO_IS_OBJECT:
	oPtr = (Object *) Tcl_GetObjectFromObj(interp, OBJ_AT_TOS);
	objResultPtr = TCONST(oPtr != NULL ? 1 : 0);
	TRACE_WITH_OBJ(("%.30s => ", O2S(OBJ_AT_TOS)), objResultPtr);
	NEXT_INST_F(1, 1, 1);
    case INST_TCLOO_CLASS:
	oPtr = (Object *) Tcl_GetObjectFromObj(interp, OBJ_AT_TOS);
	if (oPtr == NULL) {
	    TRACE(("%.30s => ERROR: not object\n", O2S(OBJ_AT_TOS)));
	    goto gotError;
	}
	objResultPtr = TclOOObjectName(interp, oPtr->selfCls->thisPtr);
	TRACE_WITH_OBJ(("%.30s => ", O2S(OBJ_AT_TOS)), objResultPtr);
	NEXT_INST_F(1, 1, 1);
    case INST_TCLOO_NS:
	oPtr = (Object *) Tcl_GetObjectFromObj(interp, OBJ_AT_TOS);
	if (oPtr == NULL) {
	    TRACE(("%.30s => ERROR: not object\n", O2S(OBJ_AT_TOS)));
	    goto gotError;
	}

	objResultPtr = TclNewNamespaceObj(oPtr->namespacePtr);
	TRACE_WITH_OBJ(("%.30s => ", O2S(OBJ_AT_TOS)), objResultPtr);
	NEXT_INST_F(1, 1, 1);
    }

    /*
     *	   End of TclOO support instructions.
     * -----------------------------------------------------------------
     *	   Start of INST_LIST and related instructions.
     */

    {
	int numIndices, nocase, match, cflags;
	Tcl_Size slength, length2, fromIdx, toIdx, index, s1len, s2len;
	const char *s1, *s2;

    case INST_LIST:
	/*
	 * Pop the opnd (objc) top stack elements into a new list obj and then
	 * decrement their ref counts.
	 */

	opnd = TclGetUInt4AtPtr(pc+1);
	objResultPtr = Tcl_NewListObj(opnd, &OBJ_AT_DEPTH(opnd-1));
	TRACE_WITH_OBJ(("%u => ", opnd), objResultPtr);
	NEXT_INST_V(5, opnd, 1);

    case INST_LIST_LENGTH:
	TRACE(("\"%.30s\" => ", O2S(OBJ_AT_TOS)));
	if (TclListObjLength(interp, OBJ_AT_TOS, &length) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TclNewIntObj(objResultPtr, length);
	TRACE_APPEND(("%" TCL_SIZE_MODIFIER "d\n", length));
	NEXT_INST_F(1, 1, 1);

    case INST_LIST_INDEX:	/* lindex with objc == 3 */
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(valuePtr), O2S(value2Ptr)));

	/* special case for AbstractList */
	if (TclObjTypeHasProc(valuePtr, indexProc)) {
	    DECACHE_STACK_INFO();
	    length = TclObjTypeLength(valuePtr);
	    if (TclGetIntForIndexM(NULL, value2Ptr, length-1, &index)!=TCL_OK) {
		CACHE_STACK_INFO();
		/* Could be list of indices. Let TclLindexList handle it below */
	    } else {
		if (TclObjTypeIndex(interp, valuePtr, index, &objResultPtr) !=
		    TCL_OK) {
		    CACHE_STACK_INFO();
		    TRACE_ERROR(interp);
		    goto gotError;
		}
		CACHE_STACK_INFO();
		if (objResultPtr == NULL) {
		    /* Index is out of range, return empty result. */
		    TclNewObj(objResultPtr);
		}
		Tcl_IncrRefCount(objResultPtr); // reference held here
		goto lindexDone;
	    }
	} else {
	    /* Non-abstract list */
	    Tcl_Size value2Length;
	    Tcl_Obj *indexListPtr = value2Ptr;

	    if ((TclListObjGetElements(interp, valuePtr, &objc, &objv) == TCL_OK)
		    && (!TclHasInternalRep(value2Ptr, &tclListType)
		    || (Tcl_ListObjLength(interp, value2Ptr, &value2Length),
			value2Length == 1
			    ? (indexListPtr = TclListObjGetElement(value2Ptr, 0), 1)
			    : 0))) {
		int code;

		/* increment the refCount of value2Ptr because TclListObjGetElement may
		 * have just extracted it from a list in the condition for this block.
		 */
		Tcl_IncrRefCount(indexListPtr);

		DECACHE_STACK_INFO();
		code = TclGetIntForIndexM(interp, indexListPtr, objc-1, &index);
		TclDecrRefCount(indexListPtr);
		CACHE_STACK_INFO();
		if (code == TCL_OK) {
		    Tcl_DecrRefCount(value2Ptr);
		    tosPtr--;
		    pcAdjustment = 1;
		    goto lindexFastPath;
		}
		Tcl_ResetResult(interp);
	    }
	}

	DECACHE_STACK_INFO();
	objResultPtr = TclLindexList(interp, valuePtr, value2Ptr);
	CACHE_STACK_INFO();

    lindexDone:
	if (!objResultPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Stash the list element on the stack.
	 */

	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 2, -1);	/* Already has the correct refCount */

    case INST_LIST_INDEX_IMM:	/* lindex with objc==3 and index in bytecode
				 * stream */

	/*
	 * Pop the list and get the index.
	 */

	valuePtr = OBJ_AT_TOS;
	opnd = TclGetInt4AtPtr(pc+1);
	TRACE(("\"%.30s\" %d => ", O2S(valuePtr), opnd));

	/*
	 * Get the contents of the list, making sure that it really is a list
	 * in the process.
	 */

	/* special case for AbstractList */
	if (TclObjTypeHasProc(valuePtr, indexProc)) {
	    length = TclObjTypeLength(valuePtr);

	    /* Decode end-offset index values. */
	    index = TclIndexDecode(opnd, length-1);

	    if (index >= 0 && index < length) {
		/* Compute value @ index */
		DECACHE_STACK_INFO();
		if (TclObjTypeIndex(interp, valuePtr, index, &objResultPtr)!=TCL_OK) {
		    CACHE_STACK_INFO();
		    TRACE_ERROR(interp);
		    goto gotError;
		}
		CACHE_STACK_INFO();
	    } else {
		TclNewObj(objResultPtr);
	    }

	    pcAdjustment = 5;
	    goto lindexFastPath2;
	}

	/* List case */
	if (TclListObjGetElements(interp, valuePtr, &objc, &objv) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/* Decode end-offset index values. */

	index = TclIndexDecode(opnd, objc - 1);
	pcAdjustment = 5;

    lindexFastPath:
	if (index >= 0 && index < objc) {
	    objResultPtr = objv[index];
	} else {
	    TclNewObj(objResultPtr);
	}

    lindexFastPath2:

	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(pcAdjustment, 1, 1);

    case INST_LIST_INDEX_MULTI:	/* 'lindex' with multiple index args */
	/*
	 * Determine the count of index args.
	 */

	opnd = TclGetUInt4AtPtr(pc+1);
	numIndices = opnd-1;

	/*
	 * Do the 'lindex' operation.
	 */

	TRACE(("%d => ", opnd));
	objResultPtr = TclLindexFlat(interp, OBJ_AT_DEPTH(numIndices),
		numIndices, &OBJ_AT_DEPTH(numIndices - 1));
	if (!objResultPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Set result.
	 */

	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_V(5, opnd, -1);

    case INST_LSET_FLAT:
	/*
	 * Lset with 3, 5, or more args. Get the number of index args.
	 */

	opnd = TclGetUInt4AtPtr(pc + 1);
	numIndices = opnd - 2;
	TRACE(("%d => ", opnd));

	/*
	 * Get the old value of variable, and remove the stack ref. This is
	 * safe because the variable still references the object; the ref
	 * count will never go zero here - we can use the smaller macro
	 * Tcl_DecrRefCount.
	 */

	valuePtr = POP_OBJECT();
	Tcl_DecrRefCount(valuePtr); /* This one should be done here */

	/*
	 * Compute the new variable value.
	 */

	DECACHE_STACK_INFO();
	if (TclObjTypeHasProc(valuePtr, setElementProc)) {
	    objResultPtr = TclObjTypeSetElement(interp,
		    valuePtr, numIndices,
		    &OBJ_AT_DEPTH(numIndices), OBJ_AT_TOS);
	} else {
	    objResultPtr = TclLsetFlat(interp, valuePtr, numIndices,
		    &OBJ_AT_DEPTH(numIndices), OBJ_AT_TOS);
	}
	if (!objResultPtr) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Set result.
	 */
	CACHE_STACK_INFO();
	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_V(5, numIndices+1, -1);

    case INST_LSET_LIST:	/* 'lset' with 4 args */
	/*
	 * Get the old value of variable, and remove the stack ref. This is
	 * safe because the variable still references the object; the ref
	 * count will never go zero here - we can use the smaller macro
	 * Tcl_DecrRefCount.
	 */

	objPtr = POP_OBJECT();
	Tcl_DecrRefCount(objPtr);	/* This one should be done here. */

	/*
	 * Get the new element value, and the index list.
	 */

	valuePtr = OBJ_AT_TOS;
	value2Ptr = OBJ_UNDER_TOS;
	TRACE(("\"%.30s\" \"%.30s\" \"%.30s\" => ",
		O2S(value2Ptr), O2S(valuePtr), O2S(objPtr)));

	/*
	 * Compute the new variable value.
	 */

	objResultPtr = TclLsetList(interp, objPtr, value2Ptr, valuePtr);
	if (!objResultPtr) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Set result.
	 */

	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 2, -1);

    case INST_LIST_RANGE_IMM:	/* lrange with objc==4 and both indices in
				 * bytecode stream */

	/*
	 * Pop the list and get the indices.
	 */

	valuePtr = OBJ_AT_TOS;
	fromIdx = TclGetInt4AtPtr(pc+1);
	toIdx = TclGetInt4AtPtr(pc+5);
	TRACE(("\"%.30s\" %d %d => ", O2S(valuePtr), TclGetInt4AtPtr(pc+1),
		TclGetInt4AtPtr(pc+5)));

	/*
	 * Get the length of the list, making sure that it really is a list
	 * in the process.
	 */

	if (TclListObjLength(interp, valuePtr, &objc) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Skip a lot of work if we're about to throw the result away (common
	 * with uses of [lassign]).
	 */

#ifndef TCL_COMPILE_DEBUG
	if (pc[9] == INST_POP) {
	    NEXT_INST_F(10, 1, 0);
	}
#endif

	/* Every range of an empty list is an empty list */
	if (objc == 0) {
	    /* avoid return of not canonical list (e. g. spaces in string repr.) */
	    if (!valuePtr->bytes || !valuePtr->length) {
		TRACE_APPEND(("\n"));
		NEXT_INST_F(9, 0, 0);
	    }
	    goto emptyList;
	}

	/* Decode index value operands. */

	if (toIdx == TCL_INDEX_NONE) {
	emptyList:
	    TclNewObj(objResultPtr);
	    TRACE_APPEND(("\"%.30s\"", O2S(objResultPtr)));
	    NEXT_INST_F(9, 1, 1);
	}
	toIdx = TclIndexDecode(toIdx, objc - 1);
	if (toIdx == TCL_INDEX_NONE) {
	    goto emptyList;
	} else if (toIdx >= objc) {
	    toIdx = objc - 1;
	}

	assert (toIdx >= 0 && toIdx < objc);
	/*
	assert ( fromIdx != TCL_INDEX_NONE );
	 *
	 * Extra safety for legacy bytecodes:
	 */
	if (fromIdx == TCL_INDEX_NONE) {
	    fromIdx = TCL_INDEX_START;
	}

	fromIdx = TclIndexDecode(fromIdx, objc - 1);

	DECACHE_STACK_INFO();
	if (TclObjTypeHasProc(valuePtr, sliceProc)) {
	    if (TclObjTypeSlice(interp, valuePtr, fromIdx, toIdx, &objResultPtr) != TCL_OK) {
		objResultPtr = NULL;
	    }
	} else {
	    objResultPtr = TclListObjRange(interp, valuePtr, fromIdx, toIdx);
	}
	if (objResultPtr == NULL) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	CACHE_STACK_INFO();
	TRACE_APPEND(("\"%.30s\"", O2S(objResultPtr)));
	NEXT_INST_F(9, 1, 1);

    case INST_LIST_IN:
    case INST_LIST_NOT_IN:	/* Basic list containment operators. */
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;

	s1 = TclGetStringFromObj(valuePtr, &s1len);
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(valuePtr), O2S(value2Ptr)));

	if (TclObjTypeHasProc(value2Ptr, inOperProc) != NULL) {
	    int status = TclObjTypeInOperator(interp, valuePtr, value2Ptr, &match);
	    if (status != TCL_OK) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	} else {

	    if (TclListObjLength(interp, value2Ptr, &length) != TCL_OK) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    match = 0;
	    if (length > 0) {
		Tcl_Size i = 0;
		Tcl_Obj *o;
		int isAbstractList = TclObjTypeHasProc(value2Ptr, indexProc) != NULL;

		/*
		 * An empty list doesn't match anything.
		 */

		do {
		    if (isAbstractList) {
			DECACHE_STACK_INFO();
			if (TclObjTypeIndex(interp, value2Ptr, i, &o) != TCL_OK) {
			    CACHE_STACK_INFO();
			    TRACE_ERROR(interp);
			    goto gotError;
			}
			CACHE_STACK_INFO();
		    } else {
			Tcl_ListObjIndex(NULL, value2Ptr, i, &o);
		    }
		    if (o != NULL) {
			s2 = TclGetStringFromObj(o, &s2len);
		    } else {
			s2 = "";
			s2len = 0;
		    }
		    if (s1len == s2len) {
			match = (memcmp(s1, s2, s1len) == 0);
		    }

		    /* Could be an ephemeral abstract obj */
		    Tcl_BounceRefCount(o);

		    i++;
		} while (i < length && match == 0);
	    }
	}

	if (*pc == INST_LIST_NOT_IN) {
	    match = !match;
	}

	TRACE_APPEND(("%d\n", match));

	/*
	 * Peep-hole optimisation: if you're about to jump, do jump from here.
	 * We're saving the effort of pushing a boolean value only to pop it
	 * for branching.
	 */

	JUMP_PEEPHOLE_F(match, 1, 2);

    case INST_LIST_CONCAT:
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(valuePtr), O2S(value2Ptr)));
	if (Tcl_IsShared(valuePtr)) {
	    objResultPtr = Tcl_DuplicateObj(valuePtr);
	    if (Tcl_ListObjAppendList(interp, objResultPtr,
		    value2Ptr) != TCL_OK) {
		TRACE_ERROR(interp);
		TclDecrRefCount(objResultPtr);
		goto gotError;
	    }
	    TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 2, 1);
	} else {
	    if (Tcl_ListObjAppendList(interp, valuePtr, value2Ptr) != TCL_OK){
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    TRACE_APPEND(("\"%.30s\"\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 1, 0);
	}

    case INST_LREPLACE4: {
	size_t numToDelete, numNewElems;
	int end_indicator;
	int haveSecondIndex, flags;
	Tcl_Obj *fromIdxObj, *toIdxObj;
	opnd = TclGetInt4AtPtr(pc + 1);
	flags = TclGetInt1AtPtr(pc + 5);

	/* Stack: ... listobj index1 ?index2? new1 ... newN */
	valuePtr = OBJ_AT_DEPTH(opnd-1);

	/* haveSecondIndex==0 => pure insert */
	haveSecondIndex = (flags & TCL_LREPLACE4_SINGLE_INDEX) == 0;
	numNewElems = opnd - 2 - haveSecondIndex;

	/* end_indicator==1 => "end" is last element's index, 0=>index beyond */
	end_indicator = (flags & TCL_LREPLACE4_END_IS_LAST) != 0;
	fromIdxObj = OBJ_AT_DEPTH(opnd - 2);
	toIdxObj = haveSecondIndex ? OBJ_AT_DEPTH(opnd - 3) : NULL;
	if (Tcl_ListObjLength(interp, valuePtr, &length) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	DECACHE_STACK_INFO();

	if (TclGetIntForIndexM(interp, fromIdxObj, length - end_indicator,
		&fromIdx) != TCL_OK) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (fromIdx == TCL_INDEX_NONE) {
	    fromIdx = 0;
	} else if (fromIdx > length) {
	    fromIdx = length;
	}
	numToDelete = 0;
	if (toIdxObj) {
	    if (TclGetIntForIndexM(interp, toIdxObj, length - end_indicator,
		    &toIdx) != TCL_OK) {
		CACHE_STACK_INFO();
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    if (toIdx != TCL_INDEX_NONE) {
		if (toIdx > length) {
		    toIdx = length;
		}
		if (toIdx >= fromIdx) {
		    numToDelete = (size_t)toIdx - (size_t)fromIdx + 1;
		}
	    }
	}

	CACHE_STACK_INFO();

	if (Tcl_IsShared(valuePtr)) {
	    objResultPtr = Tcl_DuplicateObj(valuePtr);
	    if (Tcl_ListObjReplace(interp, objResultPtr, fromIdx, numToDelete,
		    numNewElems, &OBJ_AT_DEPTH(numNewElems - 1)) != TCL_OK) {
		TRACE_ERROR(interp);
		Tcl_DecrRefCount(objResultPtr);
		goto gotError;
	    }
	    TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	    NEXT_INST_V(6, opnd, 1);
	} else {
	    if (Tcl_ListObjReplace(interp, valuePtr, fromIdx, numToDelete,
		    numNewElems, &OBJ_AT_DEPTH(numNewElems - 1)) != TCL_OK) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    TRACE_APPEND(("\"%.30s\"\n", O2S(valuePtr)));
	    NEXT_INST_V(6, opnd - 1, 0);
	}
	}

	/*
	 *	   End of INST_LIST and related instructions.
	 * -----------------------------------------------------------------
	 *	   Start of string-related instructions.
	 */

    case INST_STR_EQ:
    case INST_STR_NEQ:		/* String (in)equality check */
    case INST_STR_CMP:		/* String compare. */
    case INST_STR_LT:
    case INST_STR_GT:
    case INST_STR_LE:
    case INST_STR_GE:
    stringCompare:
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;

	{
	    int checkEq = ((*pc == INST_EQ) || (*pc == INST_NEQ)
		    || (*pc == INST_STR_EQ) || (*pc == INST_STR_NEQ));
	    match = TclStringCmp(valuePtr, value2Ptr, checkEq, 0, -1);
	}

	/*
	 * Make sure only -1,0,1 is returned
	 * TODO: consider peephole opt.
	 */

	if (*pc != INST_STR_CMP) {
	    /*
	     * Take care of the opcodes that goto'ed into here.
	     */

	    switch (*pc) {
	    case INST_STR_EQ:
	    case INST_EQ:
		match = (match == 0);
		break;
	    case INST_STR_NEQ:
	    case INST_NEQ:
		match = (match != 0);
		break;
	    case INST_LT:
	    case INST_STR_LT:
		match = (match < 0);
		break;
	    case INST_GT:
	    case INST_STR_GT:
		match = (match > 0);
		break;
	    case INST_LE:
	    case INST_STR_LE:
		match = (match <= 0);
		break;
	    case INST_GE:
	    case INST_STR_GE:
		match = (match >= 0);
		break;
	    }
	}

	TRACE(("\"%.20s\" \"%.20s\" => %d\n", O2S(valuePtr), O2S(value2Ptr),
		(match < 0 ? -1 : match > 0 ? 1 : 0)));
	JUMP_PEEPHOLE_F(match, 1, 2);

    case INST_STR_LEN:
	valuePtr = OBJ_AT_TOS;
	slength = Tcl_GetCharLength(valuePtr);
	TclNewIntObj(objResultPtr, slength);
	TRACE(("\"%.20s\" => %" TCL_Z_MODIFIER "u\n", O2S(valuePtr), slength));
	NEXT_INST_F(1, 1, 1);

    case INST_STR_UPPER:
	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));
	if (Tcl_IsShared(valuePtr)) {
	    s1 = TclGetStringFromObj(valuePtr, &slength);
	    TclNewStringObj(objResultPtr, s1, slength);
	    slength = Tcl_UtfToUpper(TclGetString(objResultPtr));
	    Tcl_SetObjLength(objResultPtr, slength);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 1, 1);
	} else {
	    slength = Tcl_UtfToUpper(TclGetString(valuePtr));
	    Tcl_SetObjLength(valuePtr, slength);
	    TclFreeInternalRep(valuePtr);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}
    case INST_STR_LOWER:
	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));
	if (Tcl_IsShared(valuePtr)) {
	    s1 = TclGetStringFromObj(valuePtr, &slength);
	    TclNewStringObj(objResultPtr, s1, slength);
	    slength = Tcl_UtfToLower(TclGetString(objResultPtr));
	    Tcl_SetObjLength(objResultPtr, slength);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 1, 1);
	} else {
	    slength = Tcl_UtfToLower(TclGetString(valuePtr));
	    Tcl_SetObjLength(valuePtr, slength);
	    TclFreeInternalRep(valuePtr);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}
    case INST_STR_TITLE:
	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));
	if (Tcl_IsShared(valuePtr)) {
	    s1 = TclGetStringFromObj(valuePtr, &slength);
	    TclNewStringObj(objResultPtr, s1, slength);
	    slength = Tcl_UtfToTitle(TclGetString(objResultPtr));
	    Tcl_SetObjLength(objResultPtr, slength);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 1, 1);
	} else {
	    slength = Tcl_UtfToTitle(TclGetString(valuePtr));
	    Tcl_SetObjLength(valuePtr, slength);
	    TclFreeInternalRep(valuePtr);
	    TRACE_APPEND(("\"%.20s\"\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}

    case INST_STR_INDEX:
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;
	TRACE(("\"%.20s\" %.20s => ", O2S(valuePtr), O2S(value2Ptr)));

	/*
	 * Get char length to calculate what 'end' means.
	 */

	slength = Tcl_GetCharLength(valuePtr);
	DECACHE_STACK_INFO();
	if (TclGetIntForIndexM(interp, value2Ptr, slength-1, &index)!=TCL_OK) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	CACHE_STACK_INFO();

	if (index < 0 || index >= slength) {
	    TclNewObj(objResultPtr);
	} else if (TclIsPureByteArray(valuePtr)) {
	    objResultPtr = Tcl_NewByteArrayObj(
		    Tcl_GetBytesFromObj(NULL, valuePtr, (Tcl_Size *)NULL)+index, 1);
	} else if (valuePtr->bytes && slength == valuePtr->length) {
	    objResultPtr = Tcl_NewStringObj((const char *)
		    valuePtr->bytes+index, 1);
	} else {
	    char buf[4] = "";
	    int ch = Tcl_GetUniChar(valuePtr, index);

	    /*
	     * This could be: Tcl_NewUnicodeObj((const Tcl_UniChar *)&ch, 1)
	     * but creating the object as a string seems to be faster in
	     * practical use.
	     */
	    if (ch == -1) {
		TclNewObj(objResultPtr);
	    } else {
		slength = Tcl_UniCharToUtf(ch, buf);
		objResultPtr = Tcl_NewStringObj(buf, slength);
	    }
	}

	TRACE_APPEND(("\"%s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 2, 1);

    case INST_STR_RANGE:
	TRACE(("\"%.20s\" %.20s %.20s =>",
		O2S(OBJ_AT_DEPTH(2)), O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS)));
	slength = Tcl_GetCharLength(OBJ_AT_DEPTH(2)) - 1;

	DECACHE_STACK_INFO();
	if (TclGetIntForIndexM(interp, OBJ_UNDER_TOS, slength, &fromIdx) != TCL_OK) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (TclGetIntForIndexM(interp, OBJ_AT_TOS, slength, &toIdx) != TCL_OK) {
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	CACHE_STACK_INFO();

	if (toIdx == TCL_INDEX_NONE) {
	    TclNewObj(objResultPtr);
	} else {
	    objResultPtr = Tcl_GetRange(OBJ_AT_DEPTH(2), fromIdx, toIdx);
	}
	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_V(1, 3, 1);

    case INST_STR_RANGE_IMM:
	valuePtr = OBJ_AT_TOS;
	fromIdx = TclGetInt4AtPtr(pc+1);
	toIdx = TclGetInt4AtPtr(pc+5);
	slength = Tcl_GetCharLength(valuePtr);
	TRACE(("\"%.20s\" %d %d => ", O2S(valuePtr), (int)(fromIdx), (int)(toIdx)));

	/* Every range of an empty value is an empty value */
	if (slength == 0) {
	    TRACE_APPEND(("\n"));
	    NEXT_INST_F(9, 0, 0);
	}

	/* Decode index operands. */

	toIdx = TclIndexDecode(toIdx, slength - 1);
	fromIdx = TclIndexDecode(fromIdx, slength - 1);
	if (toIdx == TCL_INDEX_NONE) {
	    TclNewObj(objResultPtr);
	} else {
	    objResultPtr = Tcl_GetRange(valuePtr, fromIdx, toIdx);
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_F(9, 1, 1);

    {
	Tcl_UniChar *ustring1, *ustring2, *ustring3, *end, *p;
	Tcl_Size length3;
	Tcl_Obj *value3Ptr;

    case INST_STR_REPLACE:
	value3Ptr = POP_OBJECT();
	valuePtr = OBJ_AT_DEPTH(2);
	slength = Tcl_GetCharLength(valuePtr) - 1;
	TRACE(("\"%.20s\" %s %s \"%.20s\" => ", O2S(valuePtr),
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS), O2S(value3Ptr)));
	DECACHE_STACK_INFO();
	if (TclGetIntForIndexM(interp, OBJ_UNDER_TOS, slength, &fromIdx) != TCL_OK
		|| TclGetIntForIndexM(interp, OBJ_AT_TOS, slength, &toIdx) != TCL_OK) {
	    CACHE_STACK_INFO();
	    TclDecrRefCount(value3Ptr);
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	CACHE_STACK_INFO();
	TclDecrRefCount(OBJ_AT_TOS);
	(void) POP_OBJECT();
	TclDecrRefCount(OBJ_AT_TOS);
	(void) POP_OBJECT();

	if ((toIdx < 0) || (fromIdx > slength) || (toIdx < fromIdx)) {
	    TRACE_APPEND(("\"%.30s\"\n", O2S(valuePtr)));
	    TclDecrRefCount(value3Ptr);
	    NEXT_INST_F(1, 0, 0);
	}

	if (fromIdx < 0) {
	    fromIdx = 0;
	}

	if (toIdx > slength) {
	    toIdx = slength;
	}

	if ((fromIdx == 0) && (toIdx == slength)) {
	    TclDecrRefCount(OBJ_AT_TOS);
	    OBJ_AT_TOS = value3Ptr;
	    TRACE_APPEND(("\"%.30s\"\n", O2S(value3Ptr)));
	    NEXT_INST_F(1, 0, 0);
	}

	objResultPtr = TclStringReplace(interp, valuePtr, fromIdx,
		toIdx - fromIdx + 1, value3Ptr, TCL_STRING_IN_PLACE);

	if (objResultPtr == value3Ptr) {
	    /* See [Bug 82e7f67325] */
	    TclDecrRefCount(OBJ_AT_TOS);
	    OBJ_AT_TOS = value3Ptr;
	    TRACE_APPEND(("\"%.30s\"\n", O2S(value3Ptr)));
	    NEXT_INST_F(1, 0, 0);
	}
	TclDecrRefCount(value3Ptr);
	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 1, 1);

    case INST_STR_MAP:
	valuePtr = OBJ_AT_TOS;		/* "Main" string. */
	value3Ptr = OBJ_UNDER_TOS;	/* "Target" string. */
	value2Ptr = OBJ_AT_DEPTH(2);	/* "Source" string. */
	if (value3Ptr == value2Ptr) {
	    objResultPtr = valuePtr;
	    goto doneStringMap;
	} else if (valuePtr == value2Ptr) {
	    objResultPtr = value3Ptr;
	    goto doneStringMap;
	}
	ustring1 = Tcl_GetUnicodeFromObj(valuePtr, &slength);
	if (slength == 0) {
	    objResultPtr = valuePtr;
	    goto doneStringMap;
	}
	ustring2 = Tcl_GetUnicodeFromObj(value2Ptr, &length2);
	if (length2 > slength || length2 == 0) {
	    objResultPtr = valuePtr;
	    goto doneStringMap;
	} else if (length2 == slength) {
	    if (memcmp(ustring1, ustring2, sizeof(Tcl_UniChar) * slength)) {
		objResultPtr = valuePtr;
	    } else {
		objResultPtr = value3Ptr;
	    }
	    goto doneStringMap;
	}
	ustring3 = Tcl_GetUnicodeFromObj(value3Ptr, &length3);

	objResultPtr = Tcl_NewUnicodeObj(ustring1, 0);
	p = ustring1;
	end = ustring1 + slength;
	for (; ustring1 < end; ustring1++) {
	    if ((*ustring1 == *ustring2) &&
		    /* Fix bug [69218ab7b]: restrict max compare length. */
		    ((end - ustring1) >= length2) && (length2 == 1 ||
			memcmp(ustring1, ustring2,
				sizeof(Tcl_UniChar) * length2) == 0)) {
		if (p != ustring1) {
		    Tcl_AppendUnicodeToObj(objResultPtr, p, ustring1-p);
		    p = ustring1 + length2;
		} else {
		    p += length2;
		}
		ustring1 = p - 1;

		Tcl_AppendUnicodeToObj(objResultPtr, ustring3, length3);
	    }
	}
	if (p != ustring1) {
	    /*
	     * Put the rest of the unmapped chars onto result.
	     */

	    Tcl_AppendUnicodeToObj(objResultPtr, p, ustring1 - p);
	}
    doneStringMap:
	TRACE_WITH_OBJ(("%.20s %.20s %.20s => ",
		O2S(value2Ptr), O2S(value3Ptr), O2S(valuePtr)), objResultPtr);
	NEXT_INST_V(1, 3, 1);

    case INST_STR_FIND:
	objResultPtr = TclStringFirst(OBJ_UNDER_TOS, OBJ_AT_TOS, 0);

	TRACE(("%.20s %.20s => %s\n",
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS), O2S(objResultPtr)));
	NEXT_INST_F(1, 2, 1);

    case INST_STR_FIND_LAST:
	objResultPtr = TclStringLast(OBJ_UNDER_TOS, OBJ_AT_TOS, TCL_SIZE_MAX - 1);

	TRACE(("%.20s %.20s => %s\n",
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS), O2S(objResultPtr)));
	NEXT_INST_F(1, 2, 1);

    case INST_STR_CLASS:
	opnd = TclGetInt1AtPtr(pc+1);
	valuePtr = OBJ_AT_TOS;
	TRACE(("%s \"%.30s\" => ", tclStringClassTable[opnd].name,
		O2S(valuePtr)));
	ustring1 = Tcl_GetUnicodeFromObj(valuePtr, &slength);
	match = 1;
	if (slength > 0) {
	    int ch;
	    end = ustring1 + slength;
	    for (p=ustring1 ; p<end ; ) {
		ch = *p++;
		if (!tclStringClassTable[opnd].comparator(ch)) {
		    match = 0;
		    break;
		}
	    }
	}
	TRACE_APPEND(("%d\n", match));
	JUMP_PEEPHOLE_F(match, 2, 1);
    }

    case INST_STR_MATCH:
	nocase = TclGetInt1AtPtr(pc+1);
	valuePtr = OBJ_AT_TOS;		/* String */
	value2Ptr = OBJ_UNDER_TOS;	/* Pattern */

	/*
	 * Check that at least one of the objects is Unicode before promoting
	 * both.
	 */

	if (TclHasInternalRep(valuePtr, &tclStringType)
		|| TclHasInternalRep(value2Ptr, &tclStringType)) {
	    Tcl_UniChar *ustring1, *ustring2;

	    ustring1 = Tcl_GetUnicodeFromObj(valuePtr, &slength);
	    ustring2 = Tcl_GetUnicodeFromObj(value2Ptr, &length2);
	    match = TclUniCharMatch(ustring1, slength, ustring2, length2,
		    nocase);
	} else if (TclIsPureByteArray(valuePtr) && TclIsPureByteArray(value2Ptr) && !nocase) {
	    unsigned char *bytes1, *bytes2;
	    Tcl_Size wlen1 = 0, wlen2 = 0;

	    bytes1 = Tcl_GetBytesFromObj(NULL, valuePtr, &wlen1);
	    bytes2 = Tcl_GetBytesFromObj(NULL, value2Ptr, &wlen2);
	    match = TclByteArrayMatch(bytes1, wlen1, bytes2, wlen2, 0);
	} else {
	    match = Tcl_StringCaseMatch(TclGetString(valuePtr),
		    TclGetString(value2Ptr), nocase);
	}

	/*
	 * Reuse value2Ptr object already on stack if possible. Adjustment is
	 * 2 due to the nocase byte
	 */

	TRACE(("%.20s %.20s => %d\n", O2S(valuePtr), O2S(value2Ptr), match));

	/*
	 * Peep-hole optimisation: if you're about to jump, do jump from here.
	 */

	JUMP_PEEPHOLE_F(match, 2, 2);

    {
	const char *string1, *string2;
	Tcl_Size trim1, trim2;

    case INST_STR_TRIM_LEFT:
	valuePtr = OBJ_UNDER_TOS;	/* String */
	value2Ptr = OBJ_AT_TOS;		/* TrimSet */
	string2 = TclGetStringFromObj(value2Ptr, &length2);
	string1 = TclGetStringFromObj(valuePtr, &slength);
	trim1 = TclTrimLeft(string1, slength, string2, length2);
	trim2 = 0;
	goto createTrimmedString;
    case INST_STR_TRIM_RIGHT:
	valuePtr = OBJ_UNDER_TOS;	/* String */
	value2Ptr = OBJ_AT_TOS;		/* TrimSet */
	string2 = TclGetStringFromObj(value2Ptr, &length2);
	string1 = TclGetStringFromObj(valuePtr, &slength);
	trim2 = TclTrimRight(string1, slength, string2, length2);
	trim1 = 0;
	goto createTrimmedString;
    case INST_STR_TRIM:
	valuePtr = OBJ_UNDER_TOS;	/* String */
	value2Ptr = OBJ_AT_TOS;		/* TrimSet */
	string2 = TclGetStringFromObj(value2Ptr, &length2);
	string1 = TclGetStringFromObj(valuePtr, &slength);
	trim1 = TclTrim(string1, slength, string2, length2, &trim2);
    createTrimmedString:
	/*
	 * Careful here; trim set often contains non-ASCII characters so we
	 * take care when printing. [Bug 971cb4f1db]
	 */

#ifdef TCL_COMPILE_DEBUG
	if (traceInstructions) {
	    TRACE(("\"%.30s\" ", O2S(valuePtr)));
	    TclPrintObject(stdout, value2Ptr, 30);
	    printf(" => ");
	}
#endif
	if (trim1 == 0 && trim2 == 0) {
#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		TclPrintObject(stdout, valuePtr, 30);
		printf("\n");
	    }
#endif
	    NEXT_INST_F(1, 1, 0);
	} else {
	    objResultPtr = Tcl_NewStringObj(string1+trim1, slength-trim1-trim2);
#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		TclPrintObject(stdout, objResultPtr, 30);
		printf("\n");
	    }
#endif
	    NEXT_INST_F(1, 2, 1);
	}
    }

    case INST_REGEXP:
	cflags = TclGetInt1AtPtr(pc+1); /* RE compile flages like NOCASE */
	valuePtr = OBJ_AT_TOS;		/* String */
	value2Ptr = OBJ_UNDER_TOS;	/* Pattern */
	TRACE(("\"%.30s\" \"%.30s\" => ", O2S(valuePtr), O2S(value2Ptr)));

	/*
	 * Compile and match the regular expression.
	 */

	{
	    Tcl_RegExp regExpr =
		    Tcl_GetRegExpFromObj(interp, value2Ptr, cflags);

	    if (regExpr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	    match = Tcl_RegExpExecObj(interp, regExpr, valuePtr, 0, 0, 0);
	    if (match < 0) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}

	TRACE_APPEND(("%d\n", match));

	/*
	 * Peep-hole optimisation: if you're about to jump, do jump from here.
	 * Adjustment is 2 due to the nocase byte.
	 */

	JUMP_PEEPHOLE_F(match, 2, 2);
    }

    /*
     *	   End of string-related instructions.
     * -----------------------------------------------------------------
     *	   Start of numeric operator instructions.
     */

    {
	void *ptr1, *ptr2;
	int type1, type2;
	Tcl_WideInt w1, w2, wResult;

    case INST_NUM_TYPE:
	if (GetNumberFromObj(NULL, OBJ_AT_TOS, &ptr1, &type1) != TCL_OK) {
	    type1 = 0;
	}
	TclNewIntObj(objResultPtr, type1);
	TRACE(("\"%.20s\" => %d\n", O2S(OBJ_AT_TOS), type1));
	NEXT_INST_F(1, 1, 1);

    case INST_EQ:
    case INST_NEQ:
    case INST_LT:
    case INST_GT:
    case INST_LE:
    case INST_GE: {
	int iResult = 0, compare = 0;

	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;

	/*
	    Try to determine, without triggering generation of a string
	    representation, whether one value is not a number.
	*/
	if (TclCheckEmptyString(valuePtr) > 0 || TclCheckEmptyString(value2Ptr) > 0) {
	    goto stringCompare;
	}

	if (GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK
		|| GetNumberFromObj(NULL, value2Ptr, &ptr2, &type2) != TCL_OK) {
	    /*
	     * At least one non-numeric argument - compare as strings.
	     */

	    goto stringCompare;
	}
	if (type1 == TCL_NUMBER_NAN || type2 == TCL_NUMBER_NAN) {
	    /*
	     * NaN arg: NaN != to everything, other compares are false.
	     */

	    iResult = (*pc == INST_NEQ);
	    goto foundResult;
	}
	if (valuePtr == value2Ptr) {
	    compare = MP_EQ;
	    goto convertComparison;
	}
	if ((type1 == TCL_NUMBER_INT) && (type2 == TCL_NUMBER_INT)) {
	    w1 = *((const Tcl_WideInt *)ptr1);
	    w2 = *((const Tcl_WideInt *)ptr2);
	    compare = (w1 < w2) ? MP_LT : ((w1 > w2) ? MP_GT : MP_EQ);
	} else {
	    compare = TclCompareTwoNumbers(valuePtr, value2Ptr);
	}

	/*
	 * Turn comparison outcome into appropriate result for opcode.
	 */

    convertComparison:
	switch (*pc) {
	case INST_EQ:
	    iResult = (compare == MP_EQ);
	    break;
	case INST_NEQ:
	    iResult = (compare != MP_EQ);
	    break;
	case INST_LT:
	    iResult = (compare == MP_LT);
	    break;
	case INST_GT:
	    iResult = (compare == MP_GT);
	    break;
	case INST_LE:
	    iResult = (compare != MP_GT);
	    break;
	case INST_GE:
	    iResult = (compare != MP_LT);
	    break;
	}

	/*
	 * Peep-hole optimisation: if you're about to jump, do jump from here.
	 */

    foundResult:
	TRACE(("\"%.20s\" \"%.20s\" => %d\n", O2S(valuePtr), O2S(value2Ptr),
		iResult));
	JUMP_PEEPHOLE_F(iResult, 1, 2);
    }

    case INST_MOD:
    case INST_LSHIFT:
    case INST_RSHIFT:
    case INST_BITOR:
    case INST_BITXOR:
    case INST_BITAND:
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;

	if ((GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK)
		|| (type1==TCL_NUMBER_DOUBLE) || (type1==TCL_NUMBER_NAN)) {
	    TRACE(("%.20s %.20s => ILLEGAL 1st TYPE %s\n", O2S(valuePtr),
		    O2S(value2Ptr), (valuePtr->typePtr?
		    valuePtr->typePtr->name : "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "left ", pc, valuePtr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

	if ((GetNumberFromObj(NULL, value2Ptr, &ptr2, &type2) != TCL_OK)
		|| (type2==TCL_NUMBER_DOUBLE) || (type2==TCL_NUMBER_NAN)) {
	    TRACE(("%.20s %.20s => ILLEGAL 2nd TYPE %s\n", O2S(valuePtr),
		    O2S(value2Ptr), (value2Ptr->typePtr?
		    value2Ptr->typePtr->name : "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "right ", pc, value2Ptr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

	/*
	 * Check for common, simple case.
	 */

	if ((type1 == TCL_NUMBER_INT) && (type2 == TCL_NUMBER_INT)) {
	    w1 = *((const Tcl_WideInt *)ptr1);
	    w2 = *((const Tcl_WideInt *)ptr2);

	    switch (*pc) {
	    case INST_MOD:
		if (w2 == 0) {
		    TRACE(("%s %s => DIVIDE BY ZERO\n", O2S(valuePtr),
			    O2S(value2Ptr)));
		    goto divideByZero;
		} else if ((w2 == 1) || (w2 == -1)) {
		    /*
		     * Div. by |1| always yields remainder of 0.
		     */

		    TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		    objResultPtr = TCONST(0);
		    TRACE(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 2, 1);
		} else if (w1 == 0) {
		    /*
		     * 0 % (non-zero) always yields remainder of 0.
		     */

		    TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		    objResultPtr = TCONST(0);
		    TRACE(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 2, 1);
		} else {
		    wResult = w1 / w2;

		    /*
		     * Force Tcl's integer division rules.
		     * TODO: examine for logic simplification
		     */

		    if ((wResult < 0 || (wResult == 0 &&
			    ((w1 < 0 && w2 > 0) || (w1 > 0 && w2 < 0)))) &&
			    (wResult * w2 != w1)) {
			wResult -= 1;
		    }
		    wResult = (Tcl_WideInt)((Tcl_WideUInt)w1 -
			    (Tcl_WideUInt)w2*(Tcl_WideUInt)wResult);
		    goto wideResultOfArithmetic;
		}
		break;

	    case INST_RSHIFT:
		if (w2 < 0) {
		    Tcl_SetObjResult(interp, Tcl_NewStringObj(
			    "negative shift argument", -1));
#ifdef ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR
		    DECACHE_STACK_INFO();
		    Tcl_SetErrorCode(interp, "ARITH", "DOMAIN",
			    "domain error: argument not in valid range",
			    (char *)NULL);
		    CACHE_STACK_INFO();
#endif /* ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR */
		    goto gotError;
		} else if (w1 == 0) {
		    TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		    objResultPtr = TCONST(0);
		    TRACE(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 2, 1);
		} else {
		    /*
		     * Quickly force large right shifts to 0 or -1.
		     */

		    if (w2 >= (Tcl_WideInt)(CHAR_BIT*sizeof(w1))) {
			/*
			 * We assume that INT_MAX is much larger than the
			 * number of bits in a Tcl_WideInt. This is a pretty safe
			 * assumption, given that the former is usually around
			 * 4e9 and the latter 64...
			 */

			TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
			if (w1 > 0L) {
			    objResultPtr = TCONST(0);
			} else {
			    TclNewIntObj(objResultPtr, -1);
			}
			TRACE(("%s\n", O2S(objResultPtr)));
			NEXT_INST_F(1, 2, 1);
		    }

		    /*
		     * Handle shifts within the native Tcl_WideInt range.
		     */

		    wResult = w1 >> ((int) w2);
		    goto wideResultOfArithmetic;
		}
		break;

	    case INST_LSHIFT:
		if (w2 < 0) {
		    Tcl_SetObjResult(interp, Tcl_NewStringObj(
			    "negative shift argument", -1));
#ifdef ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR
		    DECACHE_STACK_INFO();
		    Tcl_SetErrorCode(interp, "ARITH", "DOMAIN",
			    "domain error: argument not in valid range",
			    (char *)NULL);
		    CACHE_STACK_INFO();
#endif /* ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR */
		    goto gotError;
		} else if (w1 == 0) {
		    TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		    objResultPtr = TCONST(0);
		    TRACE(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 2, 1);
		} else if (w2 > INT_MAX) {
		    /*
		     * Technically, we could hold the value (1 << (INT_MAX+1))
		     * in an mp_int, but since we're using mp_mul_2d() to do
		     * the work, and it takes only an int argument, that's a
		     * good place to draw the line.
		     */

		    Tcl_SetObjResult(interp, Tcl_NewStringObj(
			    "integer value too large to represent", -1));
#ifdef ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR
		    DECACHE_STACK_INFO();
		    Tcl_SetErrorCode(interp, "ARITH", "IOVERFLOW",
			    "integer value too large to represent", (char *)NULL);
		    CACHE_STACK_INFO();
#endif /* ERROR_CODE_FOR_EARLY_DETECTED_ARITH_ERROR */
		    goto gotError;
		} else {
		    int shift = (int) w2;

		    /*
		     * Handle shifts within the native Tcl_WideInt range.
		     */

		    if (((size_t)shift < CHAR_BIT*sizeof(w1))
			    && !((w1>0 ? w1 : ~w1) &
				-((Tcl_WideUInt)1<<(CHAR_BIT*sizeof(w1) - 1 - shift)))) {
			wResult = (Tcl_WideUInt)w1 << shift;
			goto wideResultOfArithmetic;
		    }
		}

		/*
		 * Too large; need to use the broken-out function.
		 */

		TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		break;

	    case INST_BITAND:
		wResult = w1 & w2;
		goto wideResultOfArithmetic;
	    case INST_BITOR:
		wResult = w1 | w2;
		goto wideResultOfArithmetic;
	    case INST_BITXOR:
		wResult = w1 ^ w2;
		goto wideResultOfArithmetic;
	    }
	}

	/*
	 * DO NOT MERGE THIS WITH THE EQUIVALENT SECTION LATER! That would
	 * encourage the compiler to inline ExecuteExtendedBinaryMathOp, which
	 * is highly undesirable due to the overall impact on size.
	 */

	TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
	objResultPtr = ExecuteExtendedBinaryMathOp(interp, *pc, &TCONST(0),
		valuePtr, value2Ptr);
	if (objResultPtr == DIVIDED_BY_ZERO) {
	    TRACE_APPEND(("DIVIDE BY ZERO\n"));
	    goto divideByZero;
	} else if (objResultPtr == GENERAL_ARITHMETIC_ERROR) {
	    TRACE_ERROR(interp);
	    goto gotError;
	} else if (objResultPtr == NULL) {
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 1, 0);
	} else {
	    TRACE_APPEND(("%s\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 2, 1);
	}

    case INST_EXPON:
    case INST_ADD:
    case INST_SUB:
    case INST_DIV:
    case INST_MULT:
	value2Ptr = OBJ_AT_TOS;
	valuePtr = OBJ_UNDER_TOS;

	if ((GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK)
		|| IsErroringNaNType(type1)) {
	    TRACE(("%.20s %.20s => ILLEGAL 1st TYPE %s\n",
		    O2S(value2Ptr), O2S(valuePtr),
		    (valuePtr->typePtr? valuePtr->typePtr->name: "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "left ", pc, valuePtr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

#ifdef ACCEPT_NAN
	if (type1 == TCL_NUMBER_NAN) {
	    /*
	     * NaN first argument -> result is also NaN.
	     */

	    NEXT_INST_F(1, 1, 0);
	}
#endif

	if ((GetNumberFromObj(NULL, value2Ptr, &ptr2, &type2) != TCL_OK)
		|| IsErroringNaNType(type2)) {
	    TRACE(("%.20s %.20s => ILLEGAL 2nd TYPE %s\n",
		    O2S(value2Ptr), O2S(valuePtr),
		    (value2Ptr->typePtr? value2Ptr->typePtr->name: "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "right ", pc, value2Ptr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}

#ifdef ACCEPT_NAN
	if (type2 == TCL_NUMBER_NAN) {
	    /*
	     * NaN second argument -> result is also NaN.
	     */

	    objResultPtr = value2Ptr;
	    NEXT_INST_F(1, 2, 1);
	}
#endif

	/*
	 * Handle Tcl_WideInt arithmetic as best we can without going out to
	 * an external function.
	 */

	if ((type1 == TCL_NUMBER_INT) && (type2 == TCL_NUMBER_INT)) {
	    w1 = *((const Tcl_WideInt *)ptr1);
	    w2 = *((const Tcl_WideInt *)ptr2);

	    switch (*pc) {
	    case INST_ADD:
		wResult = (Tcl_WideInt)((Tcl_WideUInt)w1 + (Tcl_WideUInt)w2);
		/*
		 * Check for overflow.
		 */

		if (Overflowing(w1, w2, wResult)) {
		    goto overflow;
		}
		goto wideResultOfArithmetic;

	    case INST_SUB:
		wResult = (Tcl_WideInt)((Tcl_WideUInt)w1 - (Tcl_WideUInt)w2);
		/*
		 * Must check for overflow. The macro tests for overflows in
		 * sums by looking at the sign bits. As we have a subtraction
		 * here, we are adding -w2. As -w2 could in turn overflow, we
		 * test with ~w2 instead: it has the opposite sign bit to w2
		 * so it does the job. Note that the only "bad" case (w2==0)
		 * is irrelevant for this macro, as in that case w1 and
		 * wResult have the same sign and there is no overflow anyway.
		 */

		if (Overflowing(w1, ~w2, wResult)) {
		    goto overflow;
		}
	    wideResultOfArithmetic:
		TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
		if (Tcl_IsShared(valuePtr)) {
		    TclNewIntObj(objResultPtr, wResult);
		    TRACE(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 2, 1);
		}
		TclSetIntObj(valuePtr, wResult);
		TRACE(("%s\n", O2S(valuePtr)));
		NEXT_INST_F(1, 1, 0);
	    break;

	    case INST_DIV:
		if (w2 == 0) {
		    TRACE(("%s %s => DIVIDE BY ZERO\n",
			    O2S(valuePtr), O2S(value2Ptr)));
		    goto divideByZero;
		} else if ((w1 == WIDE_MIN) && (w2 == -1)) {
		    /*
		     * Can't represent (-WIDE_MIN) as a Tcl_WideInt.
		     */

		    goto overflow;
		}
		wResult = w1 / w2;

		/*
		 * Force Tcl's integer division rules.
		 * TODO: examine for logic simplification
		 */

		if (((wResult < 0) || ((wResult == 0) &&
			((w1 < 0 && w2 > 0) || (w1 > 0 && w2 < 0)))) &&
			((wResult * w2) != w1)) {
		    wResult -= 1;
		}
		goto wideResultOfArithmetic;

	    case INST_MULT:
		if (((sizeof(Tcl_WideInt) >= 2*sizeof(int))
			&& (w1 <= INT_MAX) && (w1 >= INT_MIN)
			&& (w2 <= INT_MAX) && (w2 >= INT_MIN))
			|| ((sizeof(Tcl_WideInt) >= 2*sizeof(short))
			&& (w1 <= SHRT_MAX) && (w1 >= SHRT_MIN)
			&& (w2 <= SHRT_MAX) && (w2 >= SHRT_MIN))) {
		    wResult = w1 * w2;
		    goto wideResultOfArithmetic;
		}
	    }

	    /*
	     * Fall through with INST_EXPON, INST_DIV and large multiplies.
	     */
	}

    overflow:
	TRACE(("%s %s => ", O2S(valuePtr), O2S(value2Ptr)));
	objResultPtr = ExecuteExtendedBinaryMathOp(interp, *pc, &TCONST(0),
		valuePtr, value2Ptr);
	if (objResultPtr == DIVIDED_BY_ZERO) {
	    TRACE_APPEND(("DIVIDE BY ZERO\n"));
	    goto divideByZero;
	} else if (objResultPtr == EXPONENT_OF_ZERO) {
	    TRACE_APPEND(("EXPONENT OF ZERO\n"));
	    goto exponOfZero;
	} else if (objResultPtr == GENERAL_ARITHMETIC_ERROR) {
	    TRACE_ERROR(interp);
	    goto gotError;
	} else if (objResultPtr == OUT_OF_MEMORY) {
	    TRACE_APPEND(("OUT OF MEMORY\n"));
	    goto outOfMemory;
	} else if (objResultPtr == NULL) {
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 1, 0);
	} else {
	    TRACE_APPEND(("%s\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 2, 1);
	}

    case INST_LNOT: {
	int b;

	valuePtr = OBJ_AT_TOS;

	/* TODO - check claim that taking address of b harms performance */
	/* TODO - consider optimization search for constants */
	if (TclGetBooleanFromObj(NULL, valuePtr, &b) != TCL_OK) {
	    TRACE(("\"%.20s\" => ERROR: illegal type %s\n", O2S(valuePtr),
		    (valuePtr->typePtr? valuePtr->typePtr->name : "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "", pc, valuePtr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	/* TODO: Consider peephole opt. */
	objResultPtr = TCONST(!b);
	TRACE_WITH_OBJ(("%s => ", O2S(valuePtr)), objResultPtr);
	NEXT_INST_F(1, 1, 1);
    }

    case INST_BITNOT:
	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));
	if ((GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK)
		|| (type1==TCL_NUMBER_NAN) || (type1==TCL_NUMBER_DOUBLE)) {
	    /*
	     * ... ~$NonInteger => raise an error.
	     */

	    TRACE_APPEND(("ERROR: illegal type %s\n",
		    (valuePtr->typePtr? valuePtr->typePtr->name : "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "", pc, valuePtr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	if (type1 == TCL_NUMBER_INT) {
	    w1 = *((const Tcl_WideInt *) ptr1);
	    if (Tcl_IsShared(valuePtr)) {
		TclNewIntObj(objResultPtr, ~w1);
		TRACE_APPEND(("%s\n", O2S(objResultPtr)));
		NEXT_INST_F(1, 1, 1);
	    }
	    TclSetIntObj(valuePtr, ~w1);
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}
	objResultPtr = ExecuteExtendedUnaryMathOp(*pc, valuePtr);
	if (objResultPtr != NULL) {
	    TRACE_APPEND(("%s\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 1, 1);
	} else {
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}

    case INST_UMINUS:
	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));
	if ((GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK)
		|| IsErroringNaNType(type1)) {
	    TRACE_APPEND(("ERROR: illegal type %s \n",
		    (valuePtr->typePtr? valuePtr->typePtr->name : "null")));
	    DECACHE_STACK_INFO();
	    IllegalExprOperandType(interp, "", pc, valuePtr);
	    CACHE_STACK_INFO();
	    goto gotError;
	}
	switch (type1) {
	case TCL_NUMBER_NAN:
	    /* -NaN => NaN */
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	break;
	case TCL_NUMBER_INT:
	    w1 = *((const Tcl_WideInt *) ptr1);
	    if (w1 != WIDE_MIN) {
		if (Tcl_IsShared(valuePtr)) {
		    TclNewIntObj(objResultPtr, -w1);
		    TRACE_APPEND(("%s\n", O2S(objResultPtr)));
		    NEXT_INST_F(1, 1, 1);
		}
		TclSetIntObj(valuePtr, -w1);
		TRACE_APPEND(("%s\n", O2S(valuePtr)));
		NEXT_INST_F(1, 0, 0);
	    }
	    /* FALLTHROUGH */
	}
	objResultPtr = ExecuteExtendedUnaryMathOp(*pc, valuePtr);
	if (objResultPtr != NULL) {
	    TRACE_APPEND(("%s\n", O2S(objResultPtr)));
	    NEXT_INST_F(1, 1, 1);
	} else {
	    TRACE_APPEND(("%s\n", O2S(valuePtr)));
	    NEXT_INST_F(1, 0, 0);
	}

    case INST_UPLUS:
    case INST_TRY_CVT_TO_NUMERIC:
	/*
	 * Try to convert the topmost stack object to numeric object. This is
	 * done in order to support [expr]'s policy of interpreting operands
	 * if at all possible as numbers first, then strings.
	 */

	valuePtr = OBJ_AT_TOS;
	TRACE(("\"%.20s\" => ", O2S(valuePtr)));

	if (GetNumberFromObj(NULL, valuePtr, &ptr1, &type1) != TCL_OK) {
	    if (*pc == INST_UPLUS) {
		/*
		 * ... +$NonNumeric => raise an error.
		 */

		TRACE_APPEND(("ERROR: illegal type %s\n",
			(valuePtr->typePtr? valuePtr->typePtr->name:"null")));
		DECACHE_STACK_INFO();
		IllegalExprOperandType(interp, "", pc, valuePtr);
		CACHE_STACK_INFO();
		goto gotError;
	    }

	    /* ... TryConvertToNumeric($NonNumeric) is acceptable */
	    TRACE_APPEND(("not numeric\n"));
	    NEXT_INST_F(1, 0, 0);
	}
	if (IsErroringNaNType(type1)) {
	    if (*pc == INST_UPLUS) {
		/*
		 * ... +$NonNumeric => raise an error.
		 */

		TRACE_APPEND(("ERROR: illegal type %s\n",
			(valuePtr->typePtr? valuePtr->typePtr->name:"null")));
		DECACHE_STACK_INFO();
		IllegalExprOperandType(interp, "", pc, valuePtr);
		CACHE_STACK_INFO();
	    } else {
		/*
		 * Numeric conversion of NaN -> error.
		 */

		TRACE_APPEND(("ERROR: IEEE floating pt error\n"));
		DECACHE_STACK_INFO();
		TclExprFloatError(interp, *((const double *) ptr1));
		CACHE_STACK_INFO();
	    }
	    goto gotError;
	}

	/*
	 * Ensure that the numeric value has a string rep the same as the
	 * formatted version of its internal rep. This is used, e.g., to make
	 * sure that "expr {0001}" yields "1", not "0001". We implement this
	 * by _discarding_ the string rep since we know it will be
	 * regenerated, if needed later, by formatting the internal rep's
	 * value.
	 */

	if (valuePtr->bytes == NULL) {
	    TRACE_APPEND(("numeric, same Tcl_Obj\n"));
	    NEXT_INST_F(1, 0, 0);
	}
	if (Tcl_IsShared(valuePtr)) {
	    /*
	     * Here we do some surgery within the Tcl_Obj internals. We want
	     * to copy the internalrep, but not the string, so we temporarily hide
	     * the string so we do not copy it.
	     */

	    char *savedString = valuePtr->bytes;

	    valuePtr->bytes = NULL;
	    objResultPtr = Tcl_DuplicateObj(valuePtr);
	    valuePtr->bytes = savedString;
	    TRACE_APPEND(("numeric, new Tcl_Obj\n"));
	    NEXT_INST_F(1, 1, 1);
	}
	TclInvalidateStringRep(valuePtr);
	TRACE_APPEND(("numeric, same Tcl_Obj\n"));
	NEXT_INST_F(1, 0, 0);
    }
    break;

    /*
     *	   End of numeric operator instructions.
     * -----------------------------------------------------------------
     */

    case INST_TRY_CVT_TO_BOOLEAN:
	valuePtr = OBJ_AT_TOS;
	if (TclHasInternalRep(valuePtr,  &tclBooleanType)) {
	    objResultPtr = TCONST(1);
	} else {
	    int res = (TclSetBooleanFromAny(NULL, valuePtr) == TCL_OK);
	    objResultPtr = TCONST(res);
	}
	TRACE_WITH_OBJ(("\"%.30s\" => ", O2S(valuePtr)), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;

    case INST_BREAK:
	/*
	DECACHE_STACK_INFO();
	Tcl_ResetResult(interp);
	CACHE_STACK_INFO();
	*/
	result = TCL_BREAK;
	cleanup = 0;
	TRACE(("=> BREAK!\n"));
	goto processExceptionReturn;

    case INST_CONTINUE:
	/*
	DECACHE_STACK_INFO();
	Tcl_ResetResult(interp);
	CACHE_STACK_INFO();
	*/
	result = TCL_CONTINUE;
	cleanup = 0;
	TRACE(("=> CONTINUE!\n"));
	goto processExceptionReturn;

    {
	ForeachInfo *infoPtr;
	Tcl_Obj *listPtr, **elements;
	ForeachVarList *varListPtr;
	Tcl_Size numLists, listLen, numVars, listTmpDepth;
	Tcl_Size iterNum, iterMax, iterTmp;
	Tcl_Size varIndex, valIndex, i, j;

    case INST_FOREACH_START:
	/*
	 * Initialize the data for the looping construct, pushing the
	 * corresponding Tcl_Objs to the stack.
	 */

	opnd = TclGetUInt4AtPtr(pc+1);
	infoPtr = (ForeachInfo *)codePtr->auxDataArrayPtr[opnd].clientData;
	numLists = infoPtr->numLists;
	TRACE(("%u => ", opnd));

	/*
	 * Compute the number of iterations that will be run: iterMax
	 */

	iterMax = 0;
	listTmpDepth = numLists-1;
	for (i = 0;  i < numLists;  i++) {
	    varListPtr = infoPtr->varLists[i];
	    numVars = varListPtr->numVars;
	    listPtr = OBJ_AT_DEPTH(listTmpDepth);
	    DECACHE_STACK_INFO();
	    if (TclListObjLength(interp, listPtr, &listLen) != TCL_OK) {
		CACHE_STACK_INFO();
		TRACE_APPEND(("ERROR converting list %" TCL_Z_MODIFIER "d, \"%s\": %s",
			i, O2S(listPtr), O2S(Tcl_GetObjResult(interp))));
		goto gotError;
	    }
	    if (Tcl_IsShared(listPtr)) {
		objPtr = TclListObjCopy(NULL, listPtr);
		Tcl_IncrRefCount(objPtr);
		Tcl_DecrRefCount(listPtr);
		OBJ_AT_DEPTH(listTmpDepth) = objPtr;
	    }
	    iterTmp = (listLen + (numVars - 1))/numVars;
	    if (iterTmp > iterMax) {
		iterMax = iterTmp;
	    }
	    listTmpDepth--;
	}

	/*
	 * Store the iterNum and iterMax in a single Tcl_Obj; we keep a
	 * nul-string obj with the pointer stored in the ptrValue so that the
	 * thing is properly garbage collected. THIS OBJ MAKES NO SENSE, but
	 * it will never leave this scope and is read-only.
	 */

	TclNewObj(tmpPtr);
	tmpPtr->internalRep.twoPtrValue.ptr1 = NULL;
	tmpPtr->internalRep.twoPtrValue.ptr2 = (void *)iterMax;
	PUSH_OBJECT(tmpPtr); /* iterCounts object */

	/*
	 * Store a pointer to the ForeachInfo struct; same dirty trick
	 * as above
	 */

	TclNewObj(tmpPtr);
	tmpPtr->internalRep.twoPtrValue.ptr1 = infoPtr;
	PUSH_OBJECT(tmpPtr); /* infoPtr object */
	TRACE_APPEND(("jump to loop step\n"));

	/*
	 * Jump directly to the INST_FOREACH_STEP instruction; the C code just
	 * falls through.
	 */

	pc += 5 - infoPtr->loopCtTemp;

    case INST_FOREACH_STEP: /* TODO: address abstract list indexing here! */
	/*
	 * "Step" a foreach loop (i.e., begin its next iteration) by assigning
	 * the next value list element to each loop var.
	 */

	tmpPtr = OBJ_AT_TOS;
	infoPtr = (ForeachInfo *)tmpPtr->internalRep.twoPtrValue.ptr1;
	numLists = infoPtr->numLists;
	TRACE(("=> "));

	tmpPtr = OBJ_AT_DEPTH(1);
	iterNum = (size_t)tmpPtr->internalRep.twoPtrValue.ptr1;
	iterMax = (size_t)tmpPtr->internalRep.twoPtrValue.ptr2;

	/*
	 * If some list still has a remaining list element iterate one more
	 * time. Assign to var the next element from its value list.
	 */

	if (iterNum < iterMax) {
	    int status;
	    /*
	     * Set the variables and jump back to run the body
	     */

	    tmpPtr->internalRep.twoPtrValue.ptr1 =(void *)(iterNum + 1);

	    listTmpDepth = numLists + 1;

	    for (i = 0;  i < numLists;  i++) {
		varListPtr = infoPtr->varLists[i];
		numVars = varListPtr->numVars;
		int hasAbstractList;

		listPtr = OBJ_AT_DEPTH(listTmpDepth);
		hasAbstractList = TclObjTypeHasProc(listPtr, indexProc) != 0;
		DECACHE_STACK_INFO();
		if (hasAbstractList) {
		    status = Tcl_ListObjLength(interp, listPtr, &listLen);
		    elements = NULL;
		} else {
		    status = TclListObjGetElements(
			interp, listPtr, &listLen, &elements);
		}
		if (status != TCL_OK) {
		    CACHE_STACK_INFO();
		    goto gotError;
		}
		CACHE_STACK_INFO();

		valIndex = (iterNum * numVars);
		for (j = 0;  j < numVars;  j++) {
		    if (valIndex >= listLen) {
			TclNewObj(valuePtr);
		    } else {
			DECACHE_STACK_INFO();
			if (elements) {
			    valuePtr = elements[valIndex];
			} else {
			    status = Tcl_ListObjIndex(
				interp, listPtr, valIndex, &valuePtr);
			    if (status != TCL_OK) {
				/* Could happen for abstract lists */
				CACHE_STACK_INFO();
				goto gotError;
			    }
			    if (valuePtr == NULL) {
				/* Permitted for Tcl_LOI to return NULL */
				TclNewObj(valuePtr);
			    }
			}
			CACHE_STACK_INFO();
		    }

		    varIndex = varListPtr->varIndexes[j];
		    varPtr = LOCAL(varIndex);
		    while (TclIsVarLink(varPtr)) {
			varPtr = varPtr->value.linkPtr;
		    }
		    if (TclIsVarDirectWritable(varPtr)) {
			value2Ptr = varPtr->value.objPtr;
			if (valuePtr != value2Ptr) {
			    if (value2Ptr != NULL) {
				TclDecrRefCount(value2Ptr);
			    }
			    varPtr->value.objPtr = valuePtr;
			    Tcl_IncrRefCount(valuePtr);
			}
		    } else {
			DECACHE_STACK_INFO();
			if (TclPtrSetVarIdx(interp, varPtr, NULL, NULL, NULL,
				valuePtr, TCL_LEAVE_ERR_MSG, varIndex)==NULL){
			    CACHE_STACK_INFO();
			    TRACE_APPEND(("ERROR init. index temp %" TCL_SIZE_MODIFIER "d: %.30s",
				    varIndex, O2S(Tcl_GetObjResult(interp))));
			    goto gotError;
			}
			CACHE_STACK_INFO();
		    }
		    valIndex++;
		}
		listTmpDepth--;
	    }
	    TRACE_APPEND(("jump to loop start\n"));
	    /* loopCtTemp being 'misused' for storing the jump size */
	    NEXT_INST_F(infoPtr->loopCtTemp, 0, 0);
	}

	TRACE_APPEND(("loop has no more iterations\n"));
#ifdef TCL_COMPILE_DEBUG
	NEXT_INST_F(1, 0, 0);
#else
	/*
	 * FALL THROUGH
	 */
	pc++;
#endif

    case INST_FOREACH_END:
	/* THIS INSTRUCTION IS ONLY CALLED AS A BREAK TARGET */
	tmpPtr = OBJ_AT_TOS;
	infoPtr = (ForeachInfo *)tmpPtr->internalRep.twoPtrValue.ptr1;
	numLists = infoPtr->numLists;
	TRACE(("=> loop terminated\n"));
	NEXT_INST_V(1, numLists+2, 0);

    case INST_LMAP_COLLECT:
	/*
	 * This instruction is only issued by lmap. The stack is:
	 *   - result
	 *   - infoPtr
	 *   - loop counters
	 *   - valLists
	 *   - collecting obj (unshared)
	 * The instruction lappends the result to the collecting obj.
	 */

	tmpPtr = OBJ_AT_DEPTH(1);
	infoPtr = (ForeachInfo *)tmpPtr->internalRep.twoPtrValue.ptr1;
	numLists = infoPtr->numLists;
	TRACE_APPEND(("=> appending to list at depth %" TCL_SIZE_MODIFIER "d\n", 3 + numLists));

	objPtr = OBJ_AT_DEPTH(3 + numLists);
	Tcl_ListObjAppendElement(NULL, objPtr, OBJ_AT_TOS);
	NEXT_INST_F(1, 1, 0);
    }
    break;

    case INST_BEGIN_CATCH4:
	/*
	 * Record start of the catch command with exception range index equal
	 * to the operand. Push the current stack depth onto the special catch
	 * stack.
	 */

	*(++catchTop) = (Tcl_Obj *)INT2PTR(CURR_DEPTH);
	TRACE(("%u => catchTop=%" TCL_T_MODIFIER "d, stackTop=%" TCL_SIZE_MODIFIER "d\n",
		TclGetUInt4AtPtr(pc+1), (catchTop - initCatchTop - 1),
		CURR_DEPTH));
	NEXT_INST_F(5, 0, 0);
    break;

    case INST_END_CATCH:
	catchTop--;
	DECACHE_STACK_INFO();
	Tcl_ResetResult(interp);
	CACHE_STACK_INFO();
	result = TCL_OK;
	TRACE(("=> catchTop=%" TCL_Z_MODIFIER "u\n", (size_t)(catchTop - initCatchTop - 1)));
	NEXT_INST_F(1, 0, 0);
    break;

    case INST_PUSH_RESULT:
	objResultPtr = Tcl_GetObjResult(interp);
	TRACE_WITH_OBJ(("=> "), objResultPtr);

	/*
	 * See the comments at INST_INVOKE_STK
	 */

	TclNewObj(objPtr);
	Tcl_IncrRefCount(objPtr);
	iPtr->objResultPtr = objPtr;
	NEXT_INST_F(1, 0, -1);
    break;

    case INST_PUSH_RETURN_CODE:
	TclNewIntObj(objResultPtr, result);
	TRACE(("=> %u\n", result));
	NEXT_INST_F(1, 0, 1);
    break;

    case INST_PUSH_RETURN_OPTIONS:
	DECACHE_STACK_INFO();
	objResultPtr = Tcl_GetReturnOptions(interp, result);
	CACHE_STACK_INFO();
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(1, 0, 1);
    break;

    case INST_RETURN_CODE_BRANCH: {
	int code;

	if (TclGetIntFromObj(NULL, OBJ_AT_TOS, &code) != TCL_OK) {
	    Tcl_Panic("INST_RETURN_CODE_BRANCH: TOS not a return code!");
	}
	if (code == TCL_OK) {
	    Tcl_Panic("INST_RETURN_CODE_BRANCH: TOS is TCL_OK!");
	}
	if (code < TCL_ERROR || code > TCL_CONTINUE) {
	    code = TCL_CONTINUE + 1;
	}
	TRACE(("\"%s\" => jump offset %d\n", O2S(OBJ_AT_TOS), 2*code-1));
	NEXT_INST_F(2*code-1, 1, 0);
    }

    /*
     * -----------------------------------------------------------------
     *	   Start of dictionary-related instructions.
     */

    {
	int opnd2, allocateDict, done, allocdict;
	Tcl_Size i;
	Tcl_Obj *dictPtr, *statePtr, *keyPtr, *listPtr, *varNamePtr, *keysPtr;
	Tcl_Obj *emptyPtr, **keyPtrPtr;
	Tcl_DictSearch *searchPtr;
	DictUpdateInfo *duiPtr;

    case INST_DICT_VERIFY: {
	Tcl_Size size;
	dictPtr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" => ", O2S(dictPtr)));
	if (Tcl_DictObjSize(interp, dictPtr, &size) != TCL_OK) {
	    TRACE_APPEND(("ERROR verifying dictionary nature of \"%.30s\": %s\n",
		    O2S(dictPtr), O2S(Tcl_GetObjResult(interp))));
	    goto gotError;
	}
	TRACE_APPEND(("OK\n"));
	NEXT_INST_F(1, 1, 0);
    }
    break;

    case INST_DICT_EXISTS: {
	int found;

	opnd = TclGetUInt4AtPtr(pc+1);
	TRACE(("%u => ", opnd));
	dictPtr = OBJ_AT_DEPTH(opnd);
	if (opnd > 1) {
	    dictPtr = TclTraceDictPath(NULL, dictPtr, opnd-1,
		    &OBJ_AT_DEPTH(opnd-1), DICT_PATH_EXISTS);
	    if (dictPtr == NULL || dictPtr == DICT_PATH_NON_EXISTENT) {
		found = 0;
		goto afterDictExists;
	    }
	}
	if (Tcl_DictObjGet(NULL, dictPtr, OBJ_AT_TOS,
		&objResultPtr) == TCL_OK) {
	    found = (objResultPtr ? 1 : 0);
	} else {
	    found = 0;
	}
    afterDictExists:
	TRACE_APPEND(("%d\n", found));

	/*
	 * The INST_DICT_EXISTS instruction is usually followed by a
	 * conditional jump, so we can take advantage of this to do some
	 * peephole optimization (note that we're careful to not close out
	 * someone doing something else).
	 */

	JUMP_PEEPHOLE_V(found, 5, opnd+1);
    }
    case INST_DICT_GET:
	opnd = TclGetUInt4AtPtr(pc+1);
	TRACE(("%u => ", opnd));
	dictPtr = OBJ_AT_DEPTH(opnd);
	if (opnd > 1) {
	    dictPtr = TclTraceDictPath(interp, dictPtr, opnd-1,
		    &OBJ_AT_DEPTH(opnd-1), DICT_PATH_READ);
	    if (dictPtr == NULL) {
		TRACE_WITH_OBJ((
			"ERROR tracing dictionary path into \"%.30s\": ",
			O2S(OBJ_AT_DEPTH(opnd))),
			Tcl_GetObjResult(interp));
		goto gotError;
	    }
	}
	if (Tcl_DictObjGet(interp, dictPtr, OBJ_AT_TOS,
		&objResultPtr) != TCL_OK) {
	    TRACE_APPEND(("ERROR reading leaf dictionary key \"%.30s\": %s",
		    O2S(dictPtr), O2S(Tcl_GetObjResult(interp))));
	    goto gotError;
	}
	if (!objResultPtr) {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "key \"%s\" not known in dictionary",
		    TclGetString(OBJ_AT_TOS)));
	    DECACHE_STACK_INFO();
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "DICT",
		    TclGetString(OBJ_AT_TOS), (char *)NULL);
	    CACHE_STACK_INFO();
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(5, opnd+1, 1);
    case INST_DICT_GET_DEF:
	opnd = TclGetUInt4AtPtr(pc+1);
	TRACE(("%u => ", opnd));
	dictPtr = OBJ_AT_DEPTH(opnd+1);
	if (opnd > 1) {
	    dictPtr = TclTraceDictPath(interp, dictPtr, opnd-1,
		    &OBJ_AT_DEPTH(opnd), DICT_PATH_EXISTS);
	    if (dictPtr == NULL) {
		TRACE_WITH_OBJ((
			"ERROR tracing dictionary path into \"%.30s\": ",
			O2S(OBJ_AT_DEPTH(opnd+1))),
			Tcl_GetObjResult(interp));
		goto gotError;
	    } else if (dictPtr == DICT_PATH_NON_EXISTENT) {
		goto dictGetDefUseDefault;
	    }
	}
	if (Tcl_DictObjGet(interp, dictPtr, OBJ_UNDER_TOS,
		&objResultPtr) != TCL_OK) {
	    TRACE_APPEND(("ERROR reading leaf dictionary key \"%.30s\": %s",
		    O2S(dictPtr), O2S(Tcl_GetObjResult(interp))));
	    goto gotError;
	} else if (!objResultPtr) {
	dictGetDefUseDefault:
	    objResultPtr = OBJ_AT_TOS;
	}
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_V(5, opnd+2, 1);

    case INST_DICT_SET:
    case INST_DICT_UNSET:
    case INST_DICT_INCR_IMM:
	opnd = TclGetUInt4AtPtr(pc+1);
	opnd2 = TclGetUInt4AtPtr(pc+5);

	varPtr = LOCAL(opnd2);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u %u => ", opnd, opnd2));
	if (TclIsVarDirectReadable(varPtr)) {
	    dictPtr = varPtr->value.objPtr;
	} else {
	    DECACHE_STACK_INFO();
	    dictPtr = TclPtrGetVarIdx(interp, varPtr, NULL, NULL, NULL, 0,
		    opnd2);
	    CACHE_STACK_INFO();
	}
	if (dictPtr == NULL) {
	    TclNewObj(dictPtr);
	    allocateDict = 1;
	} else {
	    allocateDict = Tcl_IsShared(dictPtr);
	    if (allocateDict) {
		dictPtr = Tcl_DuplicateObj(dictPtr);
	    }
	}

	switch (*pc) {
	case INST_DICT_SET:
	    cleanup = opnd + 1;
	    result = Tcl_DictObjPutKeyList(interp, dictPtr, opnd,
		    &OBJ_AT_DEPTH(opnd), OBJ_AT_TOS);
	    break;
	case INST_DICT_INCR_IMM:
	    cleanup = 1;
	    opnd = TclGetInt4AtPtr(pc+1);
	    result = Tcl_DictObjGet(interp, dictPtr, OBJ_AT_TOS, &valuePtr);
	    if (result != TCL_OK) {
		break;
	    }
	    if (valuePtr == NULL) {
		Tcl_DictObjPut(NULL, dictPtr, OBJ_AT_TOS, Tcl_NewWideIntObj(opnd));
	    } else {
		TclNewIntObj(value2Ptr, opnd);
		Tcl_IncrRefCount(value2Ptr);
		if (Tcl_IsShared(valuePtr)) {
		    valuePtr = Tcl_DuplicateObj(valuePtr);
		    Tcl_DictObjPut(NULL, dictPtr, OBJ_AT_TOS, valuePtr);
		}
		result = TclIncrObj(interp, valuePtr, value2Ptr);
		if (result == TCL_OK) {
		    TclInvalidateStringRep(dictPtr);
		}
		TclDecrRefCount(value2Ptr);
	    }
	    break;
	case INST_DICT_UNSET:
	    cleanup = opnd;
	    result = Tcl_DictObjRemoveKeyList(interp, dictPtr, opnd,
		    &OBJ_AT_DEPTH(opnd-1));
	    break;
	default:
	    cleanup = 0; /* stop compiler warning */
	    Tcl_Panic("Should not happen!");
	}

	if (result != TCL_OK) {
	    if (allocateDict) {
		TclDecrRefCount(dictPtr);
	    }
	    TRACE_APPEND(("ERROR updating dictionary: %s\n",
		    O2S(Tcl_GetObjResult(interp))));
	    goto checkForCatch;
	}

	if (TclIsVarDirectWritable(varPtr)) {
	    if (allocateDict) {
		value2Ptr = varPtr->value.objPtr;
		Tcl_IncrRefCount(dictPtr);
		if (value2Ptr != NULL) {
		    TclDecrRefCount(value2Ptr);
		}
		varPtr->value.objPtr = dictPtr;
	    }
	    objResultPtr = dictPtr;
	} else {
	    Tcl_IncrRefCount(dictPtr);
	    DECACHE_STACK_INFO();
	    objResultPtr = TclPtrSetVarIdx(interp, varPtr, NULL, NULL, NULL,
		    dictPtr, TCL_LEAVE_ERR_MSG, opnd2);
	    CACHE_STACK_INFO();
	    TclDecrRefCount(dictPtr);
	    if (objResultPtr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
#ifndef TCL_COMPILE_DEBUG
	if (pc[9] == INST_POP) {
	    NEXT_INST_V(10, cleanup, 0);
	}
#endif
	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_V(9, cleanup, 1);

    case INST_DICT_APPEND:
    case INST_DICT_LAPPEND:
	opnd = TclGetUInt4AtPtr(pc+1);
	varPtr = LOCAL(opnd);
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	TRACE(("%u => ", opnd));
	if (TclIsVarDirectReadable(varPtr)) {
	    dictPtr = varPtr->value.objPtr;
	} else {
	    DECACHE_STACK_INFO();
	    dictPtr = TclPtrGetVarIdx(interp, varPtr, NULL, NULL, NULL, 0,
		    opnd);
	    CACHE_STACK_INFO();
	}
	if (dictPtr == NULL) {
	    TclNewObj(dictPtr);
	    allocateDict = 1;
	} else {
	    allocateDict = Tcl_IsShared(dictPtr);
	    if (allocateDict) {
		dictPtr = Tcl_DuplicateObj(dictPtr);
	    }
	}

	if (Tcl_DictObjGet(interp, dictPtr, OBJ_UNDER_TOS,
		&valuePtr) != TCL_OK) {
	    if (allocateDict) {
		TclDecrRefCount(dictPtr);
	    }
	    TRACE_ERROR(interp);
	    goto gotError;
	}

	/*
	 * Note that a non-existent key results in a NULL valuePtr, which is a
	 * case handled separately below. What we *can* say at this point is
	 * that the write-back will always succeed.
	 */

	switch (*pc) {
	case INST_DICT_APPEND:
	    if (valuePtr == NULL) {
		Tcl_DictObjPut(NULL, dictPtr, OBJ_UNDER_TOS, OBJ_AT_TOS);
	    } else if (Tcl_IsShared(valuePtr)) {
		valuePtr = Tcl_DuplicateObj(valuePtr);
		Tcl_AppendObjToObj(valuePtr, OBJ_AT_TOS);
		Tcl_DictObjPut(NULL, dictPtr, OBJ_UNDER_TOS, valuePtr);
	    } else {
		Tcl_AppendObjToObj(valuePtr, OBJ_AT_TOS);

		/*
		 * Must invalidate the string representation of dictionary
		 * here because we have directly updated the internal
		 * representation; if we don't, callers could see the wrong
		 * string rep despite the internal version of the dictionary
		 * having the correct value. [Bug 3079830]
		 */

		TclInvalidateStringRep(dictPtr);
	    }
	    break;
	case INST_DICT_LAPPEND:
	    /*
	     * More complex because list-append can fail.
	     */

	    if (valuePtr == NULL) {
		Tcl_DictObjPut(NULL, dictPtr, OBJ_UNDER_TOS,
			Tcl_NewListObj(1, &OBJ_AT_TOS));
		break;
	    } else if (Tcl_IsShared(valuePtr)) {
		valuePtr = Tcl_DuplicateObj(valuePtr);
		if (Tcl_ListObjAppendElement(interp, valuePtr,
			OBJ_AT_TOS) != TCL_OK) {
		    TclDecrRefCount(valuePtr);
		    if (allocateDict) {
			TclDecrRefCount(dictPtr);
		    }
		    TRACE_ERROR(interp);
		    goto gotError;
		}
		Tcl_DictObjPut(NULL, dictPtr, OBJ_UNDER_TOS, valuePtr);
	    } else {
		if (Tcl_ListObjAppendElement(interp, valuePtr,
			OBJ_AT_TOS) != TCL_OK) {
		    if (allocateDict) {
			TclDecrRefCount(dictPtr);
		    }
		    TRACE_ERROR(interp);
		    goto gotError;
		}

		/*
		 * Must invalidate the string representation of dictionary
		 * here because we have directly updated the internal
		 * representation; if we don't, callers could see the wrong
		 * string rep despite the internal version of the dictionary
		 * having the correct value. [Bug 3079830]
		 */

		TclInvalidateStringRep(dictPtr);
	    }
	    break;
	default:
	    Tcl_Panic("Should not happen!");
	}

	if (TclIsVarDirectWritable(varPtr)) {
	    if (allocateDict) {
		value2Ptr = varPtr->value.objPtr;
		Tcl_IncrRefCount(dictPtr);
		if (value2Ptr != NULL) {
		    TclDecrRefCount(value2Ptr);
		}
		varPtr->value.objPtr = dictPtr;
	    }
	    objResultPtr = dictPtr;
	} else {
	    Tcl_IncrRefCount(dictPtr);
	    DECACHE_STACK_INFO();
	    objResultPtr = TclPtrSetVarIdx(interp, varPtr, NULL, NULL, NULL,
		    dictPtr, TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    TclDecrRefCount(dictPtr);
	    if (objResultPtr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
#ifndef TCL_COMPILE_DEBUG
	if (pc[5] == INST_POP) {
	    NEXT_INST_F(6, 2, 0);
	}
#endif
	TRACE_APPEND(("%.30s\n", O2S(objResultPtr)));
	NEXT_INST_F(5, 2, 1);

    case INST_DICT_FIRST:
	opnd = TclGetUInt4AtPtr(pc+1);
	TRACE(("%u => ", opnd));
	dictPtr = POP_OBJECT();
	searchPtr = (Tcl_DictSearch *)Tcl_Alloc(sizeof(Tcl_DictSearch));
	if (Tcl_DictObjFirst(interp, dictPtr, searchPtr, &keyPtr,
		&valuePtr, &done) != TCL_OK) {
	    /*
	     * dictPtr is no longer on the stack, and we're not
	     * moving it into the internalrep of an iterator.  We need
	     * to drop the refcount [Tcl Bug 9b352768e6].
	     */

	    Tcl_DecrRefCount(dictPtr);
	    Tcl_Free(searchPtr);
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	{
	    Tcl_ObjInternalRep ir;
	    TclNewObj(statePtr);
	    ir.twoPtrValue.ptr1 = searchPtr;
	    ir.twoPtrValue.ptr2 = dictPtr;
	    Tcl_StoreInternalRep(statePtr, &dictIteratorType, &ir);
	}
	varPtr = LOCAL(opnd);
	if (varPtr->value.objPtr) {
	    if (TclHasInternalRep(varPtr->value.objPtr, &dictIteratorType)) {
		Tcl_Panic("mis-issued dictFirst!");
	    }
	    TclDecrRefCount(varPtr->value.objPtr);
	}
	varPtr->value.objPtr = statePtr;
	Tcl_IncrRefCount(statePtr);
	goto pushDictIteratorResult;

    case INST_DICT_NEXT:
	opnd = TclGetUInt4AtPtr(pc+1);
	TRACE(("%u => ", opnd));
	statePtr = (*LOCAL(opnd)).value.objPtr;
	{
	    const Tcl_ObjInternalRep *irPtr;

	    if (statePtr &&
		    (irPtr = TclFetchInternalRep(statePtr, &dictIteratorType))) {
		searchPtr = (Tcl_DictSearch *)irPtr->twoPtrValue.ptr1;
		Tcl_DictObjNext(searchPtr, &keyPtr, &valuePtr, &done);
	    } else {
		Tcl_Panic("mis-issued dictNext!");
	    }
	}
    pushDictIteratorResult:
	if (done) {
	    TclNewObj(emptyPtr);
	    PUSH_OBJECT(emptyPtr);
	    PUSH_OBJECT(emptyPtr);
	} else {
	    PUSH_OBJECT(valuePtr);
	    PUSH_OBJECT(keyPtr);
	}
	TRACE_APPEND(("\"%.30s\" \"%.30s\" %d\n",
		O2S(OBJ_UNDER_TOS), O2S(OBJ_AT_TOS), done));

	/*
	 * The INST_DICT_FIRST and INST_DICT_NEXT instructions are always
	 * followed by a conditional jump, so we can take advantage of this to
	 * do some peephole optimization (note that we're careful to not close
	 * out someone doing something else).
	 */

	JUMP_PEEPHOLE_F(done, 5, 0);

    case INST_DICT_UPDATE_START:
	opnd = TclGetUInt4AtPtr(pc+1);
	opnd2 = TclGetUInt4AtPtr(pc+5);
	TRACE(("%u => ", opnd));
	varPtr = LOCAL(opnd);
	duiPtr = (DictUpdateInfo *)codePtr->auxDataArrayPtr[opnd2].clientData;
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	if (TclIsVarDirectReadable(varPtr)) {
	    dictPtr = varPtr->value.objPtr;
	} else {
	    DECACHE_STACK_INFO();
	    dictPtr = TclPtrGetVarIdx(interp, varPtr, NULL, NULL, NULL,
		    TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    if (dictPtr == NULL) {
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
	Tcl_IncrRefCount(dictPtr);
	if (TclListObjGetElements(interp, OBJ_AT_TOS, &length,
		&keyPtrPtr) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	if (length != duiPtr->length) {
	    Tcl_Panic("dictUpdateStart argument length mismatch");
	}
	for (i=0 ; i<length ; i++) {
	    if (Tcl_DictObjGet(interp, dictPtr, keyPtrPtr[i],
		    &valuePtr) != TCL_OK) {
		TRACE_ERROR(interp);
		Tcl_DecrRefCount(dictPtr);
		goto gotError;
	    }
	    varPtr = LOCAL(duiPtr->varIndices[i]);
	    while (TclIsVarLink(varPtr)) {
		varPtr = varPtr->value.linkPtr;
	    }
	    DECACHE_STACK_INFO();
	    if (valuePtr == NULL) {
		TclObjUnsetVar2(interp,
			localName(iPtr->varFramePtr, duiPtr->varIndices[i]),
			NULL, 0);
	    } else if (TclPtrSetVarIdx(interp, varPtr, NULL, NULL, NULL,
		    valuePtr, TCL_LEAVE_ERR_MSG,
		    duiPtr->varIndices[i]) == NULL) {
		CACHE_STACK_INFO();
		TRACE_ERROR(interp);
		Tcl_DecrRefCount(dictPtr);
		goto gotError;
	    }
	    CACHE_STACK_INFO();
	}
	TclDecrRefCount(dictPtr);
	TRACE_APPEND(("OK\n"));
	NEXT_INST_F(9, 0, 0);

    case INST_DICT_UPDATE_END:
	opnd = TclGetUInt4AtPtr(pc+1);
	opnd2 = TclGetUInt4AtPtr(pc+5);
	TRACE(("%u => ", opnd));
	varPtr = LOCAL(opnd);
	duiPtr = (DictUpdateInfo *)codePtr->auxDataArrayPtr[opnd2].clientData;
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	if (TclIsVarDirectReadable(varPtr)) {
	    dictPtr = varPtr->value.objPtr;
	} else {
	    DECACHE_STACK_INFO();
	    dictPtr = TclPtrGetVarIdx(interp, varPtr, NULL, NULL, NULL, 0,
		    opnd);
	    CACHE_STACK_INFO();
	}
	if (dictPtr == NULL) {
	    TRACE_APPEND(("storage was unset\n"));
	    NEXT_INST_F(9, 1, 0);
	}
	if (Tcl_DictObjSize(interp, dictPtr, &length) != TCL_OK
		|| TclListObjGetElements(interp, OBJ_AT_TOS, &length,
			&keyPtrPtr) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	allocdict = Tcl_IsShared(dictPtr);
	if (allocdict) {
	    dictPtr = Tcl_DuplicateObj(dictPtr);
	}
	if (length > 0) {
	    TclInvalidateStringRep(dictPtr);
	}
	for (i=0 ; i<length ; i++) {
	    Var *var2Ptr = LOCAL(duiPtr->varIndices[i]);

	    while (TclIsVarLink(var2Ptr)) {
		var2Ptr = var2Ptr->value.linkPtr;
	    }
	    if (TclIsVarDirectReadable(var2Ptr)) {
		valuePtr = var2Ptr->value.objPtr;
	    } else {
		DECACHE_STACK_INFO();
		valuePtr = TclPtrGetVarIdx(interp, var2Ptr, NULL, NULL, NULL,
			0, duiPtr->varIndices[i]);
		CACHE_STACK_INFO();
	    }
	    if (valuePtr == NULL) {
		Tcl_DictObjRemove(interp, dictPtr, keyPtrPtr[i]);
	    } else if (dictPtr == valuePtr) {
		Tcl_DictObjPut(interp, dictPtr, keyPtrPtr[i],
			Tcl_DuplicateObj(valuePtr));
	    } else {
		Tcl_DictObjPut(interp, dictPtr, keyPtrPtr[i], valuePtr);
	    }
	}
	if (TclIsVarDirectWritable(varPtr)) {
	    Tcl_IncrRefCount(dictPtr);
	    TclDecrRefCount(varPtr->value.objPtr);
	    varPtr->value.objPtr = dictPtr;
	} else {
	    DECACHE_STACK_INFO();
	    objResultPtr = TclPtrSetVarIdx(interp, varPtr, NULL, NULL, NULL,
		    dictPtr, TCL_LEAVE_ERR_MSG, opnd);
	    CACHE_STACK_INFO();
	    if (objResultPtr == NULL) {
		if (allocdict) {
		    TclDecrRefCount(dictPtr);
		}
		TRACE_ERROR(interp);
		goto gotError;
	    }
	}
	TRACE_APPEND(("written back\n"));
	NEXT_INST_F(9, 1, 0);

    case INST_DICT_EXPAND:
	dictPtr = OBJ_UNDER_TOS;
	listPtr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" \"%.30s\" =>", O2S(dictPtr), O2S(listPtr)));
	if (TclListObjGetElements(interp, listPtr, &objc, &objv) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	objResultPtr = TclDictWithInit(interp, dictPtr, objc, objv);
	if (objResultPtr == NULL) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("\"%.30s\"\n", O2S(objResultPtr)));
	NEXT_INST_F(1, 2, 1);

    case INST_DICT_RECOMBINE_STK:
	keysPtr = POP_OBJECT();
	varNamePtr = OBJ_UNDER_TOS;
	listPtr = OBJ_AT_TOS;
	TRACE(("\"%.30s\" \"%.30s\" \"%.30s\" => ",
		O2S(varNamePtr), O2S(valuePtr), O2S(keysPtr)));
	if (TclListObjGetElements(interp, listPtr, &objc, &objv) != TCL_OK) {
	    TRACE_ERROR(interp);
	    TclDecrRefCount(keysPtr);
	    goto gotError;
	}
	varPtr = TclObjLookupVarEx(interp, varNamePtr, NULL,
		TCL_LEAVE_ERR_MSG, "set", 1, 1, &arrayPtr);
	if (varPtr == NULL) {
	    TRACE_ERROR(interp);
	    TclDecrRefCount(keysPtr);
	    goto gotError;
	}
	DECACHE_STACK_INFO();
	result = TclDictWithFinish(interp, varPtr, arrayPtr, varNamePtr, NULL, -1,
		objc, objv, keysPtr);
	CACHE_STACK_INFO();
	TclDecrRefCount(keysPtr);
	if (result != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("OK\n"));
	NEXT_INST_F(1, 2, 0);

    case INST_DICT_RECOMBINE_IMM:
	opnd = TclGetUInt4AtPtr(pc+1);
	listPtr = OBJ_UNDER_TOS;
	keysPtr = OBJ_AT_TOS;
	varPtr = LOCAL(opnd);
	TRACE(("%u <- \"%.30s\" \"%.30s\" => ", opnd, O2S(valuePtr),
		O2S(keysPtr)));
	if (TclListObjGetElements(interp, listPtr, &objc, &objv) != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	while (TclIsVarLink(varPtr)) {
	    varPtr = varPtr->value.linkPtr;
	}
	DECACHE_STACK_INFO();
	result = TclDictWithFinish(interp, varPtr, NULL, NULL, NULL, opnd,
		objc, objv, keysPtr);
	CACHE_STACK_INFO();
	if (result != TCL_OK) {
	    TRACE_ERROR(interp);
	    goto gotError;
	}
	TRACE_APPEND(("OK\n"));
	NEXT_INST_F(5, 2, 0);
    }
    break;

    /*
     *	   End of dictionary-related instructions.
     * -----------------------------------------------------------------
     */

    case INST_CLOCK_READ: {	/* Read the wall clock */
	Tcl_WideInt wval;
	Tcl_Time now;
	switch (TclGetUInt1AtPtr(pc+1)) {
	case 0:			/* clicks */
#ifdef TCL_WIDE_CLICKS
	    wval = TclpGetWideClicks();
#else
	    wval = (Tcl_WideInt)TclpGetClicks();
#endif
	    break;
	case 1:			/* microseconds */
	    Tcl_GetTime(&now);
	    wval = (Tcl_WideInt)now.sec * 1000000 + now.usec;
	    break;
	case 2:			/* milliseconds */
	    Tcl_GetTime(&now);
	    wval = (Tcl_WideInt)now.sec * 1000 + now.usec / 1000;
	    break;
	case 3:			/* seconds */
	    Tcl_GetTime(&now);
	    wval = (Tcl_WideInt)now.sec;
	    break;
	default:
	    Tcl_Panic("clockRead instruction with unknown clock#");
	    break;
	}
	TclNewIntObj(objResultPtr, wval);
	TRACE_WITH_OBJ(("=> "), objResultPtr);
	NEXT_INST_F(2, 0, 1);
    }
    break;

    default:
	Tcl_Panic("TclNRExecuteByteCode: unrecognized opCode %u", *pc);
    } /* end of switch on opCode */

    /*
     * Block for variables needed to process exception returns.
     */

    {
	ExceptionRange *rangePtr;
				/* Points to closest loop or catch exception
				 * range enclosing the pc. Used by various
				 * instructions and processCatch to process
				 * break, continue, and errors. */
	const char *bytes;

	/*
	 * An external evaluation (INST_INVOKE or INST_EVAL) returned
	 * something different from TCL_OK, or else INST_BREAK or
	 * INST_CONTINUE were called.
	 */

    processExceptionReturn:
#ifdef TCL_COMPILE_DEBUG
	switch (*pc) {
	case INST_INVOKE_STK1:
	    opnd = TclGetUInt1AtPtr(pc+1);
	    TRACE(("%u => ... after \"%.20s\": ", opnd, cmdNameBuf));
	    break;
	case INST_INVOKE_STK4:
	    opnd = TclGetUInt4AtPtr(pc+1);
	    TRACE(("%u => ... after \"%.20s\": ", opnd, cmdNameBuf));
	    break;
	case INST_EVAL_STK:
	    /*
	     * Note that the object at stacktop has to be used before doing
	     * the cleanup.
	     */

	    TRACE(("\"%.30s\" => ", O2S(OBJ_AT_TOS)));
	    break;
	default:
	    TRACE(("=> "));
	}
#endif
	if ((result == TCL_CONTINUE) || (result == TCL_BREAK)) {
	    rangePtr = GetExceptRangeForPc(pc, result, codePtr);
	    if (rangePtr == NULL) {
		TRACE_APPEND(("no encl. loop or catch, returning %s\n",
			StringForResultCode(result)));
		goto abnormalReturn;
	    }
	    if (rangePtr->type == CATCH_EXCEPTION_RANGE) {
		TRACE_APPEND(("%s ...\n", StringForResultCode(result)));
		goto processCatch;
	    }
	    while (cleanup--) {
		valuePtr = POP_OBJECT();
		TclDecrRefCount(valuePtr);
	    }
	    if (result == TCL_BREAK) {
		result = TCL_OK;
		pc = (codePtr->codeStart + rangePtr->breakOffset);
		TRACE_APPEND(("%s, range at %" TCL_SIZE_MODIFIER "d, new pc %" TCL_SIZE_MODIFIER "d\n",
			StringForResultCode(result),
			rangePtr->codeOffset, rangePtr->breakOffset));
		NEXT_INST_F(0, 0, 0);
	    }
	    if (rangePtr->continueOffset == TCL_INDEX_NONE) {
		TRACE_APPEND(("%s, loop w/o continue, checking for catch\n",
			StringForResultCode(result)));
		goto checkForCatch;
	    }
	    result = TCL_OK;
	    pc = (codePtr->codeStart + rangePtr->continueOffset);
	    TRACE_APPEND(("%s, range at %" TCL_SIZE_MODIFIER "d, new pc %" TCL_SIZE_MODIFIER "d\n",
		    StringForResultCode(result),
		    rangePtr->codeOffset, rangePtr->continueOffset));
	    NEXT_INST_F(0, 0, 0);
	}
#ifdef TCL_COMPILE_DEBUG
	if (traceInstructions) {
	    objPtr = Tcl_GetObjResult(interp);
	    if ((result != TCL_ERROR) && (result != TCL_RETURN)) {
		TRACE_APPEND(("OTHER RETURN CODE %d, result=\"%.30s\"\n ",
			result, O2S(objPtr)));
	    } else {
		TRACE_APPEND(("%s, result=\"%.30s\"\n",
			StringForResultCode(result), O2S(objPtr)));
	    }
	}
#endif
	goto checkForCatch;

	/*
	 * Division by zero in an expression. Control only reaches this point
	 * by "goto divideByZero".
	 */

    divideByZero:
	Tcl_SetObjResult(interp, Tcl_NewStringObj("divide by zero", -1));
	DECACHE_STACK_INFO();
	Tcl_SetErrorCode(interp, "ARITH", "DIVZERO", "divide by zero", (char *)NULL);
	CACHE_STACK_INFO();
	goto gotError;

    outOfMemory:
	Tcl_SetObjResult(interp, Tcl_NewStringObj("out of memory", -1));
	DECACHE_STACK_INFO();
	Tcl_SetErrorCode(interp, "ARITH", "OUTOFMEMORY", "out of memory", (char *)NULL);
	CACHE_STACK_INFO();
	goto gotError;

	/*
	 * Exponentiation of zero by negative number in an expression. Control
	 * only reaches this point by "goto exponOfZero".
	 */

    exponOfZero:
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"exponentiation of zero by negative power", -1));
	DECACHE_STACK_INFO();
	Tcl_SetErrorCode(interp, "ARITH", "DOMAIN",
		"exponentiation of zero by negative power", (char *)NULL);
	CACHE_STACK_INFO();

	/*
	 * Almost all error paths feed through here rather than assigning to
	 * result themselves (for a small but consistent saving).
	 */

    gotError:
	result = TCL_ERROR;

	/*
	 * Execution has generated an "exception" such as TCL_ERROR. If the
	 * exception is an error, record information about what was being
	 * executed when the error occurred. Find the closest enclosing catch
	 * range, if any. If no enclosing catch range is found, stop execution
	 * and return the "exception" code.
	 */

    checkForCatch:
	if (iPtr->execEnvPtr->rewind) {
	    goto abnormalReturn;
	}
	if ((result == TCL_ERROR) && !(iPtr->flags & ERR_ALREADY_LOGGED)) {
	    const unsigned char *pcBeg;
	    Tcl_Size xxx1length;

	    bytes = GetSrcInfoForPc(pc, codePtr, &xxx1length, &pcBeg, NULL);
	    DECACHE_STACK_INFO();
	    TclLogCommandInfo(interp, codePtr->source, bytes,
		    bytes ? xxx1length : 0, pcBeg, tosPtr);
	    CACHE_STACK_INFO();
	}
	iPtr->flags &= ~ERR_ALREADY_LOGGED;

	/*
	 * Clear all expansions that may have started after the last
	 * INST_BEGIN_CATCH.
	 */

	while (auxObjList) {
	    if ((catchTop != initCatchTop)
		    && (PTR2INT(*catchTop) >
			PTR2INT(auxObjList->internalRep.twoPtrValue.ptr2))) {
		break;
	    }
	    POP_TAUX_OBJ();
	}

	/*
	 * We must not catch if the script in progress has been canceled with
	 * the TCL_CANCEL_UNWIND flag. Instead, it blows outwards until we
	 * either hit another interpreter (presumably where the script in
	 * progress has not been canceled) or we get to the top-level. We do
	 * NOT modify the interpreter result here because we know it will
	 * already be set prior to vectoring down to this point in the code.
	 */

	if (TclCanceled(iPtr) && (Tcl_Canceled(interp, 0) == TCL_ERROR)) {
#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		fprintf(stdout, "   ... cancel with unwind, returning %s\n",
			StringForResultCode(result));
	    }
#endif
	    goto abnormalReturn;
	}

	/*
	 * We must not catch an exceeded limit. Instead, it blows outwards
	 * until we either hit another interpreter (presumably where the limit
	 * is not exceeded) or we get to the top-level.
	 */

	if (TclLimitExceeded(iPtr->limit)) {
#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		fprintf(stdout, "   ... limit exceeded, returning %s\n",
			StringForResultCode(result));
	    }
#endif
	    goto abnormalReturn;
	}
	if (catchTop == initCatchTop) {
#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		fprintf(stdout, "   ... no enclosing catch, returning %s\n",
			StringForResultCode(result));
	    }
#endif
	    goto abnormalReturn;
	}
	rangePtr = GetExceptRangeForPc(pc, TCL_ERROR, codePtr);
	if (rangePtr == NULL) {
	    /*
	     * This is only possible when compiling a [catch] that sends its
	     * script to INST_EVAL. Cannot correct the compiler without
	     * breaking compat with previous .tbc compiled scripts.
	     */

#ifdef TCL_COMPILE_DEBUG
	    if (traceInstructions) {
		fprintf(stdout, "   ... no enclosing catch, returning %s\n",
			StringForResultCode(result));
	    }
#endif
	    goto abnormalReturn;
	}

	/*
	 * A catch exception range (rangePtr) was found to handle an
	 * "exception". It was found either by checkForCatch just above or by
	 * an instruction during break, continue, or error processing. Jump to
	 * its catchOffset after unwinding the operand stack to the depth it
	 * had when starting to execute the range's catch command.
	 */

    processCatch:
	while (CURR_DEPTH > PTR2INT(*catchTop)) {
	    valuePtr = POP_OBJECT();
	    TclDecrRefCount(valuePtr);
	}
#ifdef TCL_COMPILE_DEBUG
	if (traceInstructions) {
	    fprintf(stdout, "  ... found catch at %" TCL_SIZE_MODIFIER "d, catchTop=%" TCL_T_MODIFIER "d, "
		    "unwound to %" TCL_T_MODIFIER "d, new pc %" TCL_SIZE_MODIFIER "d\n",
		    rangePtr->codeOffset, (catchTop - initCatchTop - 1),
		    PTR2INT(*catchTop), rangePtr->catchOffset);
	}
#endif
	pc = (codePtr->codeStart + rangePtr->catchOffset);
	NEXT_INST_F(0, 0, 0);	/* Restart the execution loop at pc. */

	/*
	 * end of infinite loop dispatching on instructions.
	 */

	/*
	 * Done or abnormal return code. Restore the stack to state it had when
	 * starting to execute the ByteCode. Panic if the stack is below the
	 * initial level.
	 */

    abnormalReturn:
	TCL_DTRACE_INST_LAST();

	/*
	 * Clear all expansions and same-level NR calls.
	 *
	 * Note that expansion markers have a NULL type; avoid removing other
	 * markers.
	 */

	while (auxObjList) {
	    POP_TAUX_OBJ();
	}
	while (tosPtr > initTosPtr) {
	    objPtr = POP_OBJECT();
	    Tcl_DecrRefCount(objPtr);
	}

	if (tosPtr < initTosPtr) {
	    fprintf(stderr,
		    "\nTclNRExecuteByteCode: abnormal return at pc %" TCL_T_MODIFIER "d: "
		    "stack top %" TCL_SIZE_MODIFIER "d < entry stack top %d\n",
		    (pc - codePtr->codeStart),
		    CURR_DEPTH, 0);
	    Tcl_Panic("TclNRExecuteByteCode execution failure: end stack top < start stack top");
	}
	CLANG_ASSERT(bcFramePtr);
    }

    iPtr->cmdFramePtr = bcFramePtr->nextPtr;
    TclReleaseByteCode(codePtr);
    TclStackFree(interp, TD);	/* free my stack */

    return result;

    /*
     * INST_START_CMD failure case removed where it doesn't bother that much
     *
     * Remark that if the interpreter is marked for deletion its
     * compileEpoch is modified, so that the epoch check also verifies
     * that the interp is not deleted. If no outside call has been made
     * since the last check, it is safe to omit the check.

     * case INST_START_CMD:
     */

	instStartCmdFailed:
	{
	    const char *bytes;
	    Tcl_Size xxx1length;

	    xxx1length = 0;

	    if (TclInterpReady(interp) == TCL_ERROR) {
		goto gotError;
	    }

	    /*
	     * We used to switch to direct eval; for NRE-awareness we now
	     * compile and eval the command so that this evaluation does not
	     * add a new TEBC instance. Bug [2910748], bug [fa6bf38d07]
	     *
	     * TODO: recompile, search this command and eval a code starting from,
	     * so that this evaluation does not add a new TEBC instance without
	     * NRE-trampoline.
	     */

	    codePtr->flags |= TCL_BYTECODE_RECOMPILE;
	    bytes = GetSrcInfoForPc(pc, codePtr, &xxx1length, NULL, NULL);
	    opnd = TclGetUInt4AtPtr(pc+1);
	    pc += (opnd-1);
	    assert(bytes);
	    PUSH_OBJECT(Tcl_NewStringObj(bytes, xxx1length));
	    goto instEvalStk;
	}
}

#undef codePtr
#undef iPtr
#undef bcFramePtr
#undef initCatchTop
#undef initTosPtr
#undef auxObjList
#undef catchTop
#undef TCONST
#undef esPtr

static int
FinalizeOONext(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    CallContext *contextPtr = (CallContext *)data[1];

    /*
     * Reset the variable lookup frame.
     */

    iPtr->varFramePtr = (CallFrame *)data[0];

    /*
     * Restore the call chain context index as we've finished the inner invoke
     * and want to operate in the outer context again.
     */

    contextPtr->index = PTR2INT(data[2]);
    contextPtr->skip = PTR2INT(data[3]);
    contextPtr->oPtr->flags &= ~FILTER_HANDLING;
    return result;
}

static int
FinalizeOONextFilter(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Interp *iPtr = (Interp *) interp;
    CallContext *contextPtr = (CallContext *)data[1];

    /*
     * Reset the variable lookup frame.
     */

    iPtr->varFramePtr = (CallFrame *)data[0];

    /*
     * Restore the call chain context index as we've finished the inner invoke
     * and want to operate in the outer context again.
     */

    contextPtr->index = PTR2INT(data[2]);
    contextPtr->skip = PTR2INT(data[3]);
    contextPtr->oPtr->flags |= FILTER_HANDLING;
    return result;
}

/*
 * WidePwrSmallExpon --
 *
 * Helper to calculate small powers of integers whose result is wide.
 */
static inline Tcl_WideInt
WidePwrSmallExpon(
    Tcl_WideInt w1,
    long exponent)
{
    Tcl_WideInt wResult;

    wResult = w1 * w1;		/* b**2 */
    switch (exponent) {
    case 2:
	break;
    case 3:
	wResult *= w1;		/* b**3 */
	break;
    case 4:
	wResult *= wResult;	/* b**4 */
	break;
    case 5:
	wResult *= wResult;	/* b**4 */
	wResult *= w1;		/* b**5 */
	break;
    case 6:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	break;
    case 7:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	wResult *= w1;		/* b**7 */
	break;
    case 8:
	wResult *= wResult;	/* b**4 */
	wResult *= wResult;	/* b**8 */
	break;
    case 9:
	wResult *= wResult;	/* b**4 */
	wResult *= wResult;	/* b**8 */
	wResult *= w1;		/* b**9 */
	break;
    case 10:
	wResult *= wResult;	/* b**4 */
	wResult *= w1;		/* b**5 */
	wResult *= wResult;	/* b**10 */
	break;
    case 11:
	wResult *= wResult;	/* b**4 */
	wResult *= w1;		/* b**5 */
	wResult *= wResult;	/* b**10 */
	wResult *= w1;		/* b**11 */
	break;
    case 12:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	wResult *= wResult;	/* b**12 */
	break;
    case 13:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	wResult *= wResult;	/* b**12 */
	wResult *= w1;		/* b**13 */
	break;
    case 14:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	wResult *= w1;		/* b**7 */
	wResult *= wResult;	/* b**14 */
	break;
    case 15:
	wResult *= w1;		/* b**3 */
	wResult *= wResult;	/* b**6 */
	wResult *= w1;		/* b**7 */
	wResult *= wResult;	/* b**14 */
	wResult *= w1;		/* b**15 */
	break;
    case 16:
	wResult *= wResult;	/* b**4 */
	wResult *= wResult;	/* b**8 */
	wResult *= wResult;	/* b**16 */
	break;
    }
    return wResult;
}
/*
 *----------------------------------------------------------------------
 *
 * ExecuteExtendedBinaryMathOp, ExecuteExtendedUnaryMathOp --
 *
 *	These functions do advanced math for binary and unary operators
 *	respectively, so that the main TEBC code does not bear the cost of
 *	them.
 *
 * Results:
 *	A Tcl_Obj* result, or a NULL (in which case valuePtr is updated to
 *	hold the result value), or one of the special flag values
 *	GENERAL_ARITHMETIC_ERROR, EXPONENT_OF_ZERO or DIVIDED_BY_ZERO. The
 *	latter two signify a zero value raised to a negative power or a value
 *	divided by zero, respectively. With GENERAL_ARITHMETIC_ERROR, all
 *	error information will have already been reported in the interpreter
 *	result.
 *
 * Side effects:
 *	May update the Tcl_Obj indicated valuePtr if it is unshared. Will
 *	return a NULL when that happens.
 *
 *----------------------------------------------------------------------
 */

static Tcl_Obj *
ExecuteExtendedBinaryMathOp(
    Tcl_Interp *interp,		/* Where to report errors. */
    int opcode,			/* What operation to perform. */
    Tcl_Obj **constants,	/* The execution environment's constants. */
    Tcl_Obj *valuePtr,		/* The first operand on the stack. */
    Tcl_Obj *value2Ptr)		/* The second operand on the stack. */
{
#define WIDE_RESULT(w) \
    if (Tcl_IsShared(valuePtr)) {		\
	return Tcl_NewWideIntObj(w);		\
    } else {					\
	TclSetIntObj(valuePtr, (w));		\
	return NULL;				\
    }
#define BIG_RESULT(b) \
    if (Tcl_IsShared(valuePtr)) {		\
	return Tcl_NewBignumObj(b);		\
    } else {					\
	Tcl_SetBignumObj(valuePtr, (b));		\
	return NULL;				\
    }
#define DOUBLE_RESULT(d) \
    if (Tcl_IsShared(valuePtr)) {		\
	TclNewDoubleObj(objResultPtr, (d));	\
	return objResultPtr;			\
    } else {					\
	Tcl_SetDoubleObj(valuePtr, (d));	\
	return NULL;				\
    }

    int type1, type2;
    void *ptr1, *ptr2;
    double d1, d2, dResult;
    Tcl_WideInt w1, w2, wResult;
    mp_int big1, big2, bigResult, bigRemainder;
    Tcl_Obj *objResultPtr;
    int invalid, zero;
    int shift;
    mp_err err;

    (void) GetNumberFromObj(NULL, valuePtr, &ptr1, &type1);
    (void) GetNumberFromObj(NULL, value2Ptr, &ptr2, &type2);

    switch (opcode) {
    case INST_MOD:
	/* TODO: Attempts to re-use unshared operands on stack */

	w2 = 0;			/* silence gcc warning */
	if (type2 == TCL_NUMBER_INT) {
	    w2 = *((const Tcl_WideInt *)ptr2);
	    if (w2 == 0) {
		return DIVIDED_BY_ZERO;
	    }
	    if ((w2 == 1) || (w2 == -1)) {
		/*
		 * Div. by |1| always yields remainder of 0.
		 */

		return constants[0];
	    }
	}
	if (type1 == TCL_NUMBER_INT) {
	    w1 = *((const Tcl_WideInt *)ptr1);

	    if (w1 == 0) {
		/*
		 * 0 % (non-zero) always yields remainder of 0.
		 */

		return constants[0];
	    }
	    if (type2 == TCL_NUMBER_INT) {
		Tcl_WideInt wQuotient, wRemainder;
		w2 = *((const Tcl_WideInt *)ptr2);
		wQuotient = w1 / w2;

		/*
		 * Force Tcl's integer division rules.
		 * TODO: examine for logic simplification
		 */

		if (((wQuotient < 0)
			|| ((wQuotient == 0)
			&& ((w1 < 0 && w2 > 0)
			|| (w1 > 0 && w2 < 0))))
			&& (wQuotient * w2 != w1)) {
		    wQuotient -= 1;
		}
		wRemainder = (Tcl_WideInt)((Tcl_WideUInt)w1 -
			(Tcl_WideUInt)w2*(Tcl_WideUInt)wQuotient);
		WIDE_RESULT(wRemainder);
	    }

	    Tcl_TakeBignumFromObj(NULL, value2Ptr, &big2);

	    /* TODO: internals intrusion */
	    if ((w1 > ((Tcl_WideInt)0)) ^ !mp_isneg(&big2)) {
		/*
		 * Arguments are opposite sign; remainder is sum.
		 */

		err = mp_init_i64(&big1, w1);
		if (err == MP_OKAY) {
		    err = mp_add(&big2, &big1, &big2);
		    mp_clear(&big1);
		}
		if (err != MP_OKAY) {
		    return OUT_OF_MEMORY;
		}
		BIG_RESULT(&big2);
	    }

	    /*
	     * Arguments are same sign; remainder is first operand.
	     */

	    mp_clear(&big2);
	    return NULL;
	}
	Tcl_GetBignumFromObj(NULL, valuePtr, &big1);
	Tcl_GetBignumFromObj(NULL, value2Ptr, &big2);
	err = mp_init_multi(&bigResult, &bigRemainder, (void *)NULL);
	if (err == MP_OKAY) {
	    err = mp_div(&big1, &big2, &bigResult, &bigRemainder);
	}
	if ((err == MP_OKAY) && !mp_iszero(&bigRemainder) && (bigRemainder.sign != big2.sign)) {
	    /*
	     * Convert to Tcl's integer division rules.
	     */

	    if ((mp_sub_d(&bigResult, 1, &bigResult) != MP_OKAY)
		    || (mp_add(&bigRemainder, &big2, &bigRemainder) != MP_OKAY)) {
		return OUT_OF_MEMORY;
	    }
	}
	err = mp_copy(&bigRemainder, &bigResult);
	mp_clear(&bigRemainder);
	mp_clear(&big1);
	mp_clear(&big2);
	if (err != MP_OKAY) {
	    return OUT_OF_MEMORY;
	}
	BIG_RESULT(&bigResult);

    case INST_LSHIFT:
    case INST_RSHIFT: {
	/*
	 * Reject negative shift argument.
	 */

	switch (type2) {
	case TCL_NUMBER_INT:
	    invalid = (*((const Tcl_WideInt *)ptr2) < 0);
	    break;
	case TCL_NUMBER_BIG:
	    Tcl_TakeBignumFromObj(NULL, value2Ptr, &big2);
	    invalid = mp_isneg(&big2);
	    mp_clear(&big2);
	    break;
	default:
	    /* Unused, here to silence compiler warning */
	    invalid = 0;
	}
	if (invalid) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "negative shift argument", -1));
	    return GENERAL_ARITHMETIC_ERROR;
	}

	/*
	 * Zero shifted any number of bits is still zero.
	 */

	if ((type1==TCL_NUMBER_INT) && (*((const Tcl_WideInt *)ptr1) == 0)) {
	    return constants[0];
	}

	if (opcode == INST_LSHIFT) {
	    /*
	     * Large left shifts create integer overflow.
	     *
	     * BEWARE! Can't use Tcl_GetIntFromObj() here because that
	     * converts values in the (unsigned) range to their signed int
	     * counterparts, leading to incorrect results.
	     */

	    if ((type2 != TCL_NUMBER_INT)
		    || (*((const Tcl_WideInt *)ptr2) > INT_MAX)) {
		/*
		 * Technically, we could hold the value (1 << (INT_MAX+1)) in
		 * an mp_int, but since we're using mp_mul_2d() to do the
		 * work, and it takes only an int argument, that's a good
		 * place to draw the line.
		 */

		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"integer value too large to represent", -1));
		return GENERAL_ARITHMETIC_ERROR;
	    }
	    shift = (int)(*((const Tcl_WideInt *)ptr2));

	    /*
	     * Handle shifts within the native wide range.
	     */

	    if ((type1 == TCL_NUMBER_INT)
		    && ((size_t)shift < CHAR_BIT*sizeof(Tcl_WideInt))) {
		w1 = *((const Tcl_WideInt *)ptr1);
		if (!((w1 > 0 ? w1 : ~w1) & -(
			((Tcl_WideUInt)1) << (CHAR_BIT*sizeof(Tcl_WideInt) - 1 - shift)))) {
		    WIDE_RESULT((Tcl_WideUInt)w1 << shift);
		}
	    }
	} else {
	    /*
	     * Quickly force large right shifts to 0 or -1.
	     */

	    if ((type2 != TCL_NUMBER_INT)
		    || (*(const Tcl_WideInt *)ptr2 > INT_MAX)) {
		/*
		 * Again, technically, the value to be shifted could be an
		 * mp_int so huge that a right shift by (INT_MAX+1) bits could
		 * not take us to the result of 0 or -1, but since we're using
		 * mp_div_2d to do the work, and it takes only an int
		 * argument, we draw the line there.
		 */

		switch (type1) {
		case TCL_NUMBER_INT:
		    zero = (*(const Tcl_WideInt *)ptr1 > 0);
		    break;
		case TCL_NUMBER_BIG:
		    Tcl_TakeBignumFromObj(NULL, valuePtr, &big1);
		    zero = !mp_isneg(&big1);
		    mp_clear(&big1);
		    break;
		default:
		    /* Unused, here to silence compiler warning. */
		    zero = 0;
		}
		if (zero) {
		    return constants[0];
		}
		WIDE_RESULT(-1);
	    }
	    shift = (int)(*(const Tcl_WideInt *)ptr2);

	    /*
	     * Handle shifts within the native wide range.
	     */

	    if (type1 == TCL_NUMBER_INT) {
		w1 = *(const Tcl_WideInt *)ptr1;
		if ((size_t)shift >= CHAR_BIT*sizeof(Tcl_WideInt)) {
		    if (w1 >= 0) {
			return constants[0];
		    }
		    WIDE_RESULT(-1);
		}
		WIDE_RESULT(w1 >> shift);
	    }
	}

	Tcl_TakeBignumFromObj(NULL, valuePtr, &big1);

	err = mp_init(&bigResult);
	if (err == MP_OKAY) {
	    if (opcode == INST_LSHIFT) {
		err = mp_mul_2d(&big1, shift, &bigResult);
	    } else {
		err = mp_signed_rsh(&big1, shift, &bigResult);
	    }
	}
	if (err != MP_OKAY) {
	    return OUT_OF_MEMORY;
	}
	mp_clear(&big1);
	BIG_RESULT(&bigResult);
    }

    case INST_BITOR:
    case INST_BITXOR:
    case INST_BITAND:
	if ((type1 != TCL_NUMBER_INT) || (type2 != TCL_NUMBER_INT)) {
	    Tcl_TakeBignumFromObj(NULL, valuePtr, &big1);
	    Tcl_TakeBignumFromObj(NULL, value2Ptr, &big2);

	    err = mp_init(&bigResult);

	    if (err == MP_OKAY) {
		switch (opcode) {
		case INST_BITAND:
		    err = mp_and(&big1, &big2, &bigResult);
		    break;

		case INST_BITOR:
		    err = mp_or(&big1, &big2, &bigResult);
		    break;

		case INST_BITXOR:
		    err = mp_xor(&big1, &big2, &bigResult);
		    break;
		}
	    }
	    if (err != MP_OKAY) {
		return OUT_OF_MEMORY;
	    }

	    mp_clear(&big1);
	    mp_clear(&big2);
	    BIG_RESULT(&bigResult);
	}

	w1 = *((const Tcl_WideInt *)ptr1);
	w2 = *((const Tcl_WideInt *)ptr2);

	switch (opcode) {
	case INST_BITAND:
	    wResult = w1 & w2;
	    break;
	case INST_BITOR:
	    wResult = w1 | w2;
	    break;
	case INST_BITXOR:
	    wResult = w1 ^ w2;
	    break;
	default:
	    /* Unused, here to silence compiler warning. */
	    wResult = 0;
	}
	WIDE_RESULT(wResult);

    case INST_EXPON: {
	int oddExponent = 0, negativeExponent = 0;
	unsigned short base;

	if ((type1 == TCL_NUMBER_DOUBLE) || (type2 == TCL_NUMBER_DOUBLE)) {
	    Tcl_GetDoubleFromObj(NULL, valuePtr, &d1);
	    Tcl_GetDoubleFromObj(NULL, value2Ptr, &d2);

	    if (d1==0.0 && d2<0.0) {
		return EXPONENT_OF_ZERO;
	    }
	    dResult = pow(d1, d2);
	    goto doubleResult;
	}
	w1 = w2 = 0; /* to silence compiler warning (maybe-uninitialized) */
	if (type2 == TCL_NUMBER_INT) {
	    w2 = *((const Tcl_WideInt *) ptr2);
	    if (w2 == 0) {
		/*
		 * Anything to the zero power is 1.
		 */

		return constants[1];
	    } else if (w2 == 1) {
		/*
		 * Anything to the first power is itself
		 */

		return NULL;
	    }

	    negativeExponent = (w2 < 0);
	    oddExponent = (int)w2 & 1;
	} else {
	    Tcl_TakeBignumFromObj(NULL, value2Ptr, &big2);
	    negativeExponent = mp_isneg(&big2);
	    err = mp_mod_2d(&big2, 1, &big2);
	    oddExponent = (err == MP_OKAY) && !mp_iszero(&big2);
	    mp_clear(&big2);
	}

	if (type1 == TCL_NUMBER_INT) {
	    w1 = *((const Tcl_WideInt *)ptr1);

	    if (negativeExponent) {
		switch (w1) {
		case 0:
		    /*
		     * Zero to a negative power is div by zero error.
		     */

		    return EXPONENT_OF_ZERO;
		case -1:
		    if (oddExponent) {
			WIDE_RESULT(-1);
		    }
		    /* fallthrough */
		case 1:
		    /*
		     * 1 to any power is 1.
		     */

		    return constants[1];
		}
	    }
	}
	if (negativeExponent) {

	    /*
	     * Integers with magnitude greater than 1 raise to a negative
	     * power yield the answer zero (see TIP 123).
	     */
	    return constants[0];
	}

	if (type1 != TCL_NUMBER_INT) {
	    goto overflowExpon;
	}

	switch (w1) {
	    case 0:
		/*
		 * Zero to a positive power is zero.
		 */

		return constants[0];
	    case 1:
		/*
		 * 1 to any power is 1.
		 */

		return constants[1];
	    case -1:
		if (!oddExponent) {
		    return constants[1];
		}
		WIDE_RESULT(-1);
	}

	/*
	 * We refuse to accept exponent arguments that exceed one mp_digit
	 * which means the max exponent value is 2**28-1 = 0x0FFFFFFF =
	 * 268435455, which fits into a signed 32 bit int which is within the
	 * range of the Tcl_WideInt type. This means any numeric Tcl_Obj value
	 * not using TCL_NUMBER_INT type must hold a value larger than we
	 * accept.
	 */

	if (type2 != TCL_NUMBER_INT) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "exponent too large", -1));
	    return GENERAL_ARITHMETIC_ERROR;
	}

	/* From here (up to overflowExpon) w1 and exponent w2 are wide-int's. */
	assert(type1 == TCL_NUMBER_INT && type2 == TCL_NUMBER_INT);

	if (w1 == 2) {
	    /*
	     * Reduce small powers of 2 to shifts.
	     */

	    if ((Tcl_WideUInt)w2 < (Tcl_WideUInt)CHAR_BIT*sizeof(Tcl_WideInt) - 1) {
		WIDE_RESULT(((Tcl_WideInt)1) << (int)w2);
	    }
	    goto overflowExpon;
	}
	if (w1 == -2) {
	    int signum = oddExponent ? -1 : 1;

	    /*
	     * Reduce small powers of 2 to shifts.
	     */

	    if ((Tcl_WideUInt)w2 < CHAR_BIT * sizeof(Tcl_WideInt) - 1) {
		WIDE_RESULT(signum * (((Tcl_WideInt)1) << (int) w2));
	    }
	    goto overflowExpon;
	}
	if (w2 - 2 < (long)MaxBase64Size
		&& w1 <=  MaxBase64[w2 - 2]
		&& w1 >= -MaxBase64[w2 - 2]) {
	    /*
	     * Small powers of integers whose result is wide.
	     */
	    wResult = WidePwrSmallExpon(w1, (long)w2);

	    WIDE_RESULT(wResult);
	}

	/*
	 * Handle cases of powers > 16 that still fit in a 64-bit word by
	 * doing table lookup.
	 */

	if (w1 - 3 >= 0 && w1 - 2 < (long)Exp64IndexSize
		&& w2 - 2 < (long)(Exp64ValueSize + MaxBase64Size)) {
	    base = Exp64Index[w1 - 3]
		    + (unsigned short) (w2 - 2 - MaxBase64Size);
	    if (base < Exp64Index[w1 - 2]) {
		/*
		 * 64-bit number raised to intermediate power, done by
		 * table lookup.
		 */

		WIDE_RESULT(Exp64Value[base]);
	    }
	}

	if (-w1 - 3 >= 0 && -w1 - 2 < (long)Exp64IndexSize
		&& w2 - 2 < (long)(Exp64ValueSize + MaxBase64Size)) {
	    base = Exp64Index[-w1 - 3]
		    + (unsigned short) (w2 - 2 - MaxBase64Size);
	    if (base < Exp64Index[-w1 - 2]) {
		/*
		 * 64-bit number raised to intermediate power, done by
		 * table lookup.
		 */

		wResult = oddExponent ? -Exp64Value[base] : Exp64Value[base];
		WIDE_RESULT(wResult);
	    }
	}

    overflowExpon:

	if ((TclGetWideIntFromObj(NULL, value2Ptr, &w2) != TCL_OK)
		|| !TclHasInternalRep(value2Ptr, &tclIntType)
		|| (Tcl_WideUInt)w2 >= (1<<28)) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "exponent too large", -1));
	    return GENERAL_ARITHMETIC_ERROR;
	}
	Tcl_TakeBignumFromObj(NULL, valuePtr, &big1);
	err = mp_init(&bigResult);
	if (err == MP_OKAY) {
	    /* Don't use "mp_expt_n" directly here, it doesn't exist in libtommath 1.2 */
	    err = TclBN_mp_expt_n(&big1, (int)w2, &bigResult);
	}
	if (err != MP_OKAY) {
	    return OUT_OF_MEMORY;
	}
	mp_clear(&big1);
	BIG_RESULT(&bigResult);
    }

    case INST_ADD:
    case INST_SUB:
    case INST_MULT:
    case INST_DIV:
	if ((type1 == TCL_NUMBER_DOUBLE) || (type2 == TCL_NUMBER_DOUBLE)) {
	    /*
	     * At least one of the values is floating-point, so perform
	     * floating point calculations.
	     */

	    Tcl_GetDoubleFromObj(NULL, valuePtr, &d1);
	    Tcl_GetDoubleFromObj(NULL, value2Ptr, &d2);

	    switch (opcode) {
	    case INST_ADD:
		dResult = d1 + d2;
		break;
	    case INST_SUB:
		dResult = d1 - d2;
		break;
	    case INST_MULT:
		dResult = d1 * d2;
		break;
	    case INST_DIV:
#ifndef IEEE_FLOATING_POINT
		if (d2 == 0.0) {
		    return DIVIDED_BY_ZERO;
		}
#endif
		/*
		 * We presume that we are running with zero-divide unmasked if
		 * we're on an IEEE box. Otherwise, this statement might cause
		 * demons to fly out our noses.
		 */

		dResult = d1 / d2;
		break;
	    default:
		/* Unused, here to silence compiler warning. */
		dResult = 0;
	    }

	doubleResult:
#ifndef ACCEPT_NAN
	    /*
	     * Check now for IEEE floating-point error.
	     */

	    if (isnan(dResult)) {
		TclExprFloatError(interp, dResult);
		return GENERAL_ARITHMETIC_ERROR;
	    }
#endif
	    DOUBLE_RESULT(dResult);
	}
	if ((type1 == TCL_NUMBER_INT) && (type2 == TCL_NUMBER_INT)) {
	    w1 = *((const Tcl_WideInt *)ptr1);
	    w2 = *((const Tcl_WideInt *)ptr2);

	    switch (opcode) {
	    case INST_ADD:
		wResult = (Tcl_WideInt)((Tcl_WideUInt)w1 + (Tcl_WideUInt)w2);
		if ((type1 == TCL_NUMBER_INT) || (type2 == TCL_NUMBER_INT)) {
		    /*
		     * Check for overflow.
		     */

		    if (Overflowing(w1, w2, wResult)) {
			goto overflowBasic;
		    }
		}
		break;

	    case INST_SUB:
		wResult = (Tcl_WideInt)((Tcl_WideUInt)w1 - (Tcl_WideUInt)w2);
		if ((type1 == TCL_NUMBER_INT) || (type2 == TCL_NUMBER_INT)) {
		    /*
		     * Must check for overflow. The macro tests for overflows
		     * in sums by looking at the sign bits. As we have a
		     * subtraction here, we are adding -w2. As -w2 could in
		     * turn overflow, we test with ~w2 instead: it has the
		     * opposite sign bit to w2 so it does the job. Note that
		     * the only "bad" case (w2==0) is irrelevant for this
		     * macro, as in that case w1 and wResult have the same
		     * sign and there is no overflow anyway.
		     */

		    if (Overflowing(w1, ~w2, wResult)) {
			goto overflowBasic;
		    }
		}
		break;

	    case INST_MULT:
		if ((w1 < INT_MIN) || (w1 > INT_MAX) || (w2 < INT_MIN) || (w2 > INT_MAX)) {
		    goto overflowBasic;
		}
		wResult = w1 * w2;
		break;

	    case INST_DIV:
		if (w2 == 0) {
		    return DIVIDED_BY_ZERO;
		}

		/*
		 * Need a bignum to represent (WIDE_MIN / -1)
		 */

		if ((w1 == WIDE_MIN) && (w2 == -1)) {
		    goto overflowBasic;
		}
		wResult = w1 / w2;

		/*
		 * Force Tcl's integer division rules.
		 * TODO: examine for logic simplification
		 */

		if (((wResult < 0) || ((wResult == 0) &&
			((w1 < 0 && w2 > 0) || (w1 > 0 && w2 < 0)))) &&
			(wResult*w2 != w1)) {
		    wResult -= 1;
		}
		break;

	    default:
		/*
		 * Unused, here to silence compiler warning.
		 */

		wResult = 0;
	    }

	    WIDE_RESULT(wResult);
	}

    overflowBasic:
	Tcl_TakeBignumFromObj(NULL, valuePtr, &big1);
	Tcl_TakeBignumFromObj(NULL, value2Ptr, &big2);
	err = mp_init(&bigResult);
	if (err == MP_OKAY) {
	    switch (opcode) {
	    case INST_ADD:
		err = mp_add(&big1, &big2, &bigResult);
		break;
	    case INST_SUB:
		err = mp_sub(&big1, &big2, &bigResult);
		break;
	    case INST_MULT:
		err = mp_mul(&big1, &big2, &bigResult);
		break;
	    case INST_DIV:
		if (mp_iszero(&big2)) {
		    mp_clear(&big1);
		    mp_clear(&big2);
		    mp_clear(&bigResult);
		    return DIVIDED_BY_ZERO;
		}
		err = mp_init(&bigRemainder);
		if (err == MP_OKAY) {
		    err = mp_div(&big1, &big2, &bigResult, &bigRemainder);
		}
		/* TODO: internals intrusion */
		if (!mp_iszero(&bigRemainder)
			&& (bigRemainder.sign != big2.sign)) {
		    /*
		     * Convert to Tcl's integer division rules.
		     */

		    err = mp_sub_d(&bigResult, 1, &bigResult);
		    if (err == MP_OKAY) {
			err = mp_add(&bigRemainder, &big2, &bigRemainder);
		    }
		}
		mp_clear(&bigRemainder);
		break;
	    }
	}
	mp_clear(&big1);
	mp_clear(&big2);
	BIG_RESULT(&bigResult);
    }

    Tcl_Panic("unexpected opcode");
    return NULL;
}

static Tcl_Obj *
ExecuteExtendedUnaryMathOp(
    int opcode,			/* What operation to perform. */
    Tcl_Obj *valuePtr)		/* The operand on the stack. */
{
    void *ptr = NULL;
    int type;
    Tcl_WideInt w;
    mp_int big;
    Tcl_Obj *objResultPtr;
    mp_err err = MP_OKAY;

    (void) GetNumberFromObj(NULL, valuePtr, &ptr, &type);

    switch (opcode) {
    case INST_BITNOT:
	if (type == TCL_NUMBER_INT) {
	    w = *((const Tcl_WideInt *) ptr);
	    WIDE_RESULT(~w);
	}
	Tcl_TakeBignumFromObj(NULL, valuePtr, &big);
	/* ~a = - a - 1 */
	err = mp_neg(&big, &big);
	if (err == MP_OKAY) {
	    err = mp_sub_d(&big, 1, &big);
	}
	if (err != MP_OKAY) {
	    return OUT_OF_MEMORY;
	}
	BIG_RESULT(&big);
    case INST_UMINUS:
	switch (type) {
	case TCL_NUMBER_DOUBLE:
	    DOUBLE_RESULT(-(*((const double *) ptr)));
	case TCL_NUMBER_INT:
	    w = *((const Tcl_WideInt *) ptr);
	    if (w != WIDE_MIN) {
		WIDE_RESULT(-w);
	    }
	    err = mp_init_i64(&big, w);
	    if (err != MP_OKAY) {
		return OUT_OF_MEMORY;
	    }
	    break;
	default:
	    Tcl_TakeBignumFromObj(NULL, valuePtr, &big);
	}
	err = mp_neg(&big, &big);
	if (err != MP_OKAY) {
	    return OUT_OF_MEMORY;
	}
	BIG_RESULT(&big);
    }

    Tcl_Panic("unexpected opcode");
    return NULL;
}
#undef WIDE_RESULT
#undef BIG_RESULT
#undef DOUBLE_RESULT

/*
 *----------------------------------------------------------------------
 *
 * CompareTwoNumbers --
 *
 *	This function compares a pair of numbers in Tcl_Objs. Each argument
 *	must already be known to be numeric and not NaN.
 *
 * Results:
 *	One of MP_LT, MP_EQ or MP_GT, depending on whether valuePtr is less
 *	than, equal to, or greater than value2Ptr (respectively).
 *
 * Side effects:
 *	None, provided both values are numeric.
 *
 *----------------------------------------------------------------------
 */

int
TclCompareTwoNumbers(
    Tcl_Obj *valuePtr,
    Tcl_Obj *value2Ptr)
{
    int type1 = TCL_NUMBER_NAN, type2 = TCL_NUMBER_NAN, compare;
    void *ptr1, *ptr2;
    mp_int big1, big2;
    double d1, d2, tmp;
    Tcl_WideInt w1, w2;

    (void) GetNumberFromObj(NULL, valuePtr, &ptr1, &type1);
    (void) GetNumberFromObj(NULL, value2Ptr, &ptr2, &type2);

    switch (type1) {
    case TCL_NUMBER_INT:
	w1 = *((const Tcl_WideInt *)ptr1);
	switch (type2) {
	case TCL_NUMBER_INT:
	    w2 = *((const Tcl_WideInt *)ptr2);
	wideCompare:
	    return (w1 < w2) ? MP_LT : ((w1 > w2) ? MP_GT : MP_EQ);
	case TCL_NUMBER_DOUBLE:
	    d2 = *((const double *)ptr2);
	    d1 = (double) w1;

	    /*
	     * If the double has a fractional part, or if the Tcl_WideInt can be
	     * converted to double without loss of precision, then compare as
	     * doubles.
	     */

	    if (DBL_MANT_DIG > CHAR_BIT*sizeof(Tcl_WideInt) || w1 == (Tcl_WideInt)d1
		    || modf(d2, &tmp) != 0.0) {
		goto doubleCompare;
	    }

	    /*
	     * Otherwise, to make comparision based on full precision, need to
	     * convert the double to a suitably sized integer.
	     *
	     * Need this to get comparsions like
	     *	  expr 20000000000000003 < 20000000000000004.0
	     * right. Converting the first argument to double will yield two
	     * double values that are equivalent within double precision.
	     * Converting the double to an integer gets done exactly, then
	     * integer comparison can tell the difference.
	     */

	    if (d2 < (double)WIDE_MIN) {
		return MP_GT;
	    }
	    if (d2 > (double)WIDE_MAX) {
		return MP_LT;
	    }
	    w2 = (Tcl_WideInt)d2;
	    goto wideCompare;
	case TCL_NUMBER_BIG:
	    Tcl_GetBignumFromObj(NULL, value2Ptr, &big2);
	    if (mp_isneg(&big2)) {
		compare = MP_GT;
	    } else {
		compare = MP_LT;
	    }
	    mp_clear(&big2);
	    return compare;
	}
    break;

    case TCL_NUMBER_DOUBLE:
	d1 = *((const double *)ptr1);
	switch (type2) {
	case TCL_NUMBER_DOUBLE:
	    d2 = *((const double *)ptr2);
	doubleCompare:
	    return (d1 < d2) ? MP_LT : ((d1 > d2) ? MP_GT : MP_EQ);
	case TCL_NUMBER_INT:
	    w2 = *((const Tcl_WideInt *)ptr2);
	    d2 = (double) w2;
	    if (DBL_MANT_DIG > CHAR_BIT*sizeof(Tcl_WideInt)
		    || w2 == (Tcl_WideInt)d2 || modf(d1, &tmp) != 0.0) {
		goto doubleCompare;
	    }
	    if (d1 < (double)WIDE_MIN) {
		return MP_LT;
	    }
	    if (d1 > (double)WIDE_MAX) {
		return MP_GT;
	    }
	    w1 = (Tcl_WideInt)d1;
	    goto wideCompare;
	case TCL_NUMBER_BIG:
	    if (isinf(d1)) {
		return (d1 > 0.0) ? MP_GT : MP_LT;
	    }
	    Tcl_GetBignumFromObj(NULL, value2Ptr, &big2);
	    if ((d1 < (double)WIDE_MAX) && (d1 > (double)WIDE_MIN)) {
		if (mp_isneg(&big2)) {
		    compare = MP_GT;
		} else {
		    compare = MP_LT;
		}
		mp_clear(&big2);
		return compare;
	    }
	    if (DBL_MANT_DIG > CHAR_BIT*sizeof(Tcl_WideInt)
		    && modf(d1, &tmp) != 0.0) {
		d2 = TclBignumToDouble(&big2);
		mp_clear(&big2);
		goto doubleCompare;
	    }
	    Tcl_InitBignumFromDouble(NULL, d1, &big1);
	    goto bigCompare;
	}
    break;

    case TCL_NUMBER_BIG:
	Tcl_GetBignumFromObj(NULL, valuePtr, &big1);
	switch (type2) {
	case TCL_NUMBER_INT:
	    compare = mp_cmp_d(&big1, 0);
	    mp_clear(&big1);
	    return compare;
	case TCL_NUMBER_DOUBLE:
	    d2 = *((const double *)ptr2);
	    if (isinf(d2)) {
		compare = (d2 > 0.0) ? MP_LT : MP_GT;
		mp_clear(&big1);
		return compare;
	    }
	    if ((d2 < (double)WIDE_MAX) && (d2 > (double)WIDE_MIN)) {
		compare = mp_cmp_d(&big1, 0);
		mp_clear(&big1);
		return compare;
	    }
	    if (DBL_MANT_DIG > CHAR_BIT*sizeof(Tcl_WideInt)
		    && modf(d2, &tmp) != 0.0) {
		d1 = TclBignumToDouble(&big1);
		mp_clear(&big1);
		goto doubleCompare;
	    }
	    Tcl_InitBignumFromDouble(NULL, d2, &big2);
	    goto bigCompare;
	case TCL_NUMBER_BIG:
	    Tcl_GetBignumFromObj(NULL, value2Ptr, &big2);
	bigCompare:
	    compare = mp_cmp(&big1, &big2);
	    mp_clear(&big1);
	    mp_clear(&big2);
	    return compare;
	}
    break;
    default:
	Tcl_Panic("unexpected number type");
    }
    return TCL_ERROR;
}

#ifdef TCL_COMPILE_DEBUG
/*
 *----------------------------------------------------------------------
 *
 * PrintByteCodeInfo --
 *
 *	This procedure prints a summary about a bytecode object to stdout. It
 *	is called by TclNRExecuteByteCode when starting to execute the bytecode
 *	object if tclTraceExec has the value 2 or more.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
PrintByteCodeInfo(
    ByteCode *codePtr)		/* The bytecode whose summary is printed to
				 * stdout. */
{
    Proc *procPtr = codePtr->procPtr;
    Interp *iPtr = (Interp *) *codePtr->interpHandle;

    fprintf(stdout,
	    "\nExecuting ByteCode 0x%p, refCt %" TCL_Z_MODIFIER
	    "u, epoch %" TCL_Z_MODIFIER "u, interp 0x%p (epoch %"
	    TCL_Z_MODIFIER "u)\n",
	    codePtr, codePtr->refCount, codePtr->compileEpoch, iPtr,
	    iPtr->compileEpoch);
    fprintf(stdout, "  Source: ");
    TclPrintSource(stdout, codePtr->source, 60);

    fprintf(stdout,
	    "\n  Cmds %" TCL_Z_MODIFIER "u, src %" TCL_Z_MODIFIER
	    "u, inst %" TCL_Z_MODIFIER "u, litObjs %" TCL_Z_MODIFIER
	    "u, aux %" TCL_Z_MODIFIER "u, stkDepth %" TCL_Z_MODIFIER
	    "u, code/src %.2f\n",
	    codePtr->numCommands, codePtr->numSrcBytes,
	    codePtr->numCodeBytes, codePtr->numLitObjects,
	    codePtr->numAuxDataItems, codePtr->maxStackDepth,
#ifdef TCL_COMPILE_STATS
	    codePtr->numSrcBytes?
		    ((float)codePtr->structureSize)/codePtr->numSrcBytes :
#endif
	    0.0);

#ifdef TCL_COMPILE_STATS
    fprintf(stdout,
	    "  Code %" TCL_Z_MODIFIER "u = header %" TCL_Z_MODIFIER
	    "u+inst %" TCL_Z_MODIFIER "u+litObj %" TCL_Z_MODIFIER
	    "u+exc %" TCL_Z_MODIFIER "u+aux %" TCL_Z_MODIFIER
	    "u+cmdMap %" TCL_Z_MODIFIER "u\n",
	    codePtr->structureSize,
	    offsetof(ByteCode, localCachePtr),
	    codePtr->numCodeBytes,
	    codePtr->numLitObjects * sizeof(Tcl_Obj *),
	    codePtr->numExceptRanges*sizeof(ExceptionRange),
	    codePtr->numAuxDataItems * sizeof(AuxData),
	    codePtr->numCmdLocBytes);
#endif /* TCL_COMPILE_STATS */
    if (procPtr != NULL) {
	fprintf(stdout,
		"  Proc 0x%p, refCt %" TCL_Z_MODIFIER "u, args %"
		TCL_Z_MODIFIER "u, compiled locals %" TCL_Z_MODIFIER "u\n",
		procPtr, procPtr->refCount, procPtr->numArgs,
		procPtr->numCompiledLocals);
    }
}
#endif /* TCL_COMPILE_DEBUG */

/*
 *----------------------------------------------------------------------
 *
 * ValidatePcAndStackTop --
 *
 *	This procedure is called by TclNRExecuteByteCode when debugging to
 *	verify that the program counter and stack top are valid during
 *	execution.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Prints a message to stderr and panics if either the pc or stack top
 *	are invalid.
 *
 *----------------------------------------------------------------------
 */

#ifdef TCL_COMPILE_DEBUG
static void
ValidatePcAndStackTop(
    ByteCode *codePtr,		/* The bytecode whose summary is printed to
				 * stdout. */
    const unsigned char *pc,	/* Points to first byte of a bytecode
				 * instruction. The program counter. */
    size_t stackTop,		/* Current stack top. Must be between
				 * stackLowerBound and stackUpperBound
				 * (inclusive). */
    int checkStack)		/* 0 if the stack depth check should be
				 * skipped. */
{
    size_t stackUpperBound = codePtr->maxStackDepth;
				/* Greatest legal value for stackTop. */
    size_t relativePc = (size_t)(pc - codePtr->codeStart);
    size_t codeStart = (size_t)codePtr->codeStart;
    size_t codeEnd = (size_t)
	    (codePtr->codeStart + codePtr->numCodeBytes);
    unsigned char opCode = *pc;

    if ((PTR2UINT(pc) < codeStart) || (PTR2UINT(pc) > codeEnd)) {
	fprintf(stderr, "\nBad instruction pc 0x%p in TclNRExecuteByteCode\n",
		pc);
	Tcl_Panic("TclNRExecuteByteCode execution failure: bad pc");
    }
    if (opCode >= LAST_INST_OPCODE) {
	fprintf(stderr, "\nBad opcode %u at pc %" TCL_Z_MODIFIER "u in TclNRExecuteByteCode\n",
		opCode, relativePc);
	Tcl_Panic("TclNRExecuteByteCode execution failure: bad opcode");
    }
    if (checkStack && (stackTop > stackUpperBound)) {
	Tcl_Size numChars;
	const char *cmd = GetSrcInfoForPc(pc, codePtr, &numChars, NULL, NULL);

	fprintf(stderr, "\nBad stack top %" TCL_Z_MODIFIER "u at pc %" TCL_Z_MODIFIER "u in TclNRExecuteByteCode (min 0, max %" TCL_Z_MODIFIER "u)",
		stackTop, relativePc, stackUpperBound);
	if (cmd != NULL) {
	    Tcl_Obj *message;

	    TclNewLiteralStringObj(message, "\n executing ");
	    Tcl_IncrRefCount(message);
	    Tcl_AppendLimitedToObj(message, cmd, numChars, 100, NULL);
	    fprintf(stderr, "%s\n", TclGetString(message));
	    Tcl_DecrRefCount(message);
	} else {
	    fprintf(stderr, "\n");
	}
	Tcl_Panic("TclNRExecuteByteCode execution failure: bad stack top");
    }
}
#endif /* TCL_COMPILE_DEBUG */

/*
 *----------------------------------------------------------------------
 *
 * IllegalExprOperandType --
 *
 *	Used by TclNRExecuteByteCode to append an error message to the interp
 *	result when an illegal operand type is detected by an expression
 *	instruction. The argument opndPtr holds the operand object in error.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	An error message is appended to the interp result.
 *
 *----------------------------------------------------------------------
 */

static void
IllegalExprOperandType(
    Tcl_Interp *interp,		/* Interpreter to which error information
				 * pertains. */
    const char *ord,		/* "first ", "second " or "" */
    const unsigned char *pc,	/* Points to the instruction being executed
				 * when the illegal type was found. */
    Tcl_Obj *opndPtr)		/* Points to the operand holding the value
				 * with the illegal type. */
{
    void *ptr;
    int type;
    const unsigned char opcode = *pc;
    const char *description, *op = "unknown";

    if (opcode == INST_EXPON) {
	op = "**";
    } else if (opcode <= INST_LNOT) {
	op = operatorStrings[opcode - INST_BITOR];
    }

    if (GetNumberFromObj(NULL, opndPtr, &ptr, &type) != TCL_OK) {
	Tcl_Size length;
	if (TclHasInternalRep(opndPtr, &tclDictType)) {
	    Tcl_DictObjSize(NULL, opndPtr, &length);
	    if (length > 0) {
	    listRep:
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"cannot use a list as %soperand of \"%s\"", ord, op));
		Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", "list", (char *)NULL);
		return;
	    }
	}
	Tcl_ObjTypeLengthProc *lengthProc = TclObjTypeHasProc(opndPtr, lengthProc);
	Tcl_Size objcPtr;
	Tcl_Obj **objvPtr;
	if ((lengthProc && lengthProc(opndPtr) > 1)
		|| ((TclMaxListLength(TclGetString(opndPtr), TCL_INDEX_NONE, NULL) > 1)
		&& (Tcl_ListObjGetElements(NULL, opndPtr, &objcPtr, &objvPtr) == TCL_OK))) {
	    goto listRep;
	}
	description = "non-numeric string";
    } else if (type == TCL_NUMBER_NAN) {
	description = "non-numeric floating-point value";
    } else if (type == TCL_NUMBER_DOUBLE) {
	description = "floating-point value";
    } else {
	/* TODO: No caller needs this. Eliminate? */
	description = "(big) integer";
    }

    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "cannot use %s \"%s\" as %soperand of \"%s\"", description,
	    TclGetString(opndPtr), ord, op));
    Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", description, (char *)NULL);
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetSrcInfoForPc, GetSrcInfoForPc, TclGetSourceFromFrame --
 *
 *	Given a program counter value, finds the closest command in the
 *	bytecode code unit's CmdLocation array and returns information about
 *	that command's source: a pointer to its first byte and the number of
 *	characters.
 *
 * Results:
 *	If a command is found that encloses the program counter value, a
 *	pointer to the command's source is returned and the length of the
 *	source is stored at *lengthPtr. If multiple commands resulted in code
 *	at pc, information about the closest enclosing command is returned. If
 *	no matching command is found, NULL is returned and *lengthPtr is
 *	unchanged.
 *
 * Side effects:
 *	The CmdFrame at *cfPtr is updated.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclGetSourceFromFrame(
    CmdFrame *cfPtr,
    Tcl_Size objc,
    Tcl_Obj *const objv[])
{
    if (cfPtr == NULL) {
	return Tcl_NewListObj(objc, objv);
    }
    if (cfPtr->cmdObj == NULL) {
	if (cfPtr->cmd == NULL) {
	    ByteCode *codePtr = (ByteCode *)cfPtr->data.tebc.codePtr;

	    cfPtr->cmd = GetSrcInfoForPc((unsigned char *)
		    cfPtr->data.tebc.pc, codePtr, &cfPtr->len, NULL, NULL);
	}
	if (cfPtr->cmd) {
	    cfPtr->cmdObj = Tcl_NewStringObj(cfPtr->cmd, cfPtr->len);
	} else {
	    cfPtr->cmdObj = Tcl_NewListObj(objc, objv);
	}
	Tcl_IncrRefCount(cfPtr->cmdObj);
    }
    return cfPtr->cmdObj;
}

void
TclGetSrcInfoForPc(
    CmdFrame *cfPtr)
{
    ByteCode *codePtr = (ByteCode *) cfPtr->data.tebc.codePtr;

    assert(cfPtr->type == TCL_LOCATION_BC);

    if (cfPtr->cmd == NULL) {

	cfPtr->cmd = GetSrcInfoForPc(
		(unsigned char *) cfPtr->data.tebc.pc, codePtr,
		&cfPtr->len, NULL, NULL);
    }

    if (cfPtr->cmd != NULL) {
	/*
	 * We now have the command. We can get the srcOffset back and from
	 * there find the list of word locations for this command.
	 */

	ExtCmdLoc *eclPtr;
	ECL *locPtr = NULL;
	Tcl_Size srcOffset;
	Tcl_Size i;
	Interp *iPtr = (Interp *) *codePtr->interpHandle;
	Tcl_HashEntry *hePtr =
		Tcl_FindHashEntry(iPtr->lineBCPtr, codePtr);

	if (!hePtr) {
	    return;
	}

	srcOffset = cfPtr->cmd - codePtr->source;
	eclPtr = (ExtCmdLoc *)Tcl_GetHashValue(hePtr);

	for (i=0; i < eclPtr->nuloc; i++) {
	    if (eclPtr->loc[i].srcOffset == srcOffset) {
		locPtr = eclPtr->loc+i;
		break;
	    }
	}
	if (locPtr == NULL) {
	    Tcl_Panic("LocSearch failure");
	}

	cfPtr->line = locPtr->line;
	cfPtr->nline = locPtr->nline;
	cfPtr->type = eclPtr->type;

	if (eclPtr->type == TCL_LOCATION_SOURCE) {
	    cfPtr->data.eval.path = eclPtr->path;
	    Tcl_IncrRefCount(cfPtr->data.eval.path);
	}

	/*
	 * Do not set cfPtr->data.eval.path NULL for non-SOURCE. Needed for
	 * cfPtr->data.tebc.codePtr.
	 */
    }
}

static const char *
GetSrcInfoForPc(
    const unsigned char *pc,	/* The program counter value for which to
				 * return the closest command's source info.
				 * This points within a bytecode instruction
				 * in codePtr's code. */
    ByteCode *codePtr,		/* The bytecode sequence in which to look up
				 * the command source for the pc. */
    Tcl_Size *lengthPtr,	/* If non-NULL, the location where the length
				 * of the command's source should be stored.
				 * If NULL, no length is stored. */
    const unsigned char **pcBeg,/* If non-NULL, the bytecode location
				 * where the current instruction starts.
				 * If NULL; no pointer is stored. */
    Tcl_Size *cmdIdxPtr)	/* If non-NULL, the location where the index
				 * of the command containing the pc should
				 * be stored. */
{
    Tcl_Size pcOffset = pc - codePtr->codeStart;
    Tcl_Size numCmds = codePtr->numCommands;
    unsigned char *codeDeltaNext, *codeLengthNext;
    unsigned char *srcDeltaNext, *srcLengthNext;
    Tcl_Size codeOffset, codeLen, codeEnd, srcOffset, srcLen, delta, i;
    Tcl_Size bestDist = TCL_SIZE_MAX; /* Distance of pc to best cmd's start pc. */
    Tcl_Size bestSrcOffset = -1; /* Initialized to avoid compiler warning. */
    Tcl_Size bestSrcLength = -1; /* Initialized to avoid compiler warning. */
    Tcl_Size bestCmdIdx = -1;

    /* The pc must point within the bytecode */
    assert ((pcOffset >= 0) && (pcOffset < codePtr->numCodeBytes));

    /*
     * Decode the code and source offset and length for each command. The
     * closest enclosing command is the last one whose code started before
     * pcOffset.
     */

    codeDeltaNext = codePtr->codeDeltaStart;
    codeLengthNext = codePtr->codeLengthStart;
    srcDeltaNext = codePtr->srcDeltaStart;
    srcLengthNext = codePtr->srcLengthStart;
    codeOffset = srcOffset = 0;
    for (i = 0;  i < numCmds;  i++) {
	if ((unsigned) *codeDeltaNext == (unsigned) 0xFF) {
	    codeDeltaNext++;
	    delta = TclGetInt4AtPtr(codeDeltaNext);
	    codeDeltaNext += 4;
	} else {
	    delta = TclGetInt1AtPtr(codeDeltaNext);
	    codeDeltaNext++;
	}
	codeOffset += delta;

	if ((unsigned) *codeLengthNext == (unsigned) 0xFF) {
	    codeLengthNext++;
	    codeLen = TclGetInt4AtPtr(codeLengthNext);
	    codeLengthNext += 4;
	} else {
	    codeLen = TclGetInt1AtPtr(codeLengthNext);
	    codeLengthNext++;
	}
	codeEnd = (codeOffset + codeLen - 1);

	if ((unsigned) *srcDeltaNext == (unsigned) 0xFF) {
	    srcDeltaNext++;
	    delta = TclGetInt4AtPtr(srcDeltaNext);
	    srcDeltaNext += 4;
	} else {
	    delta = TclGetInt1AtPtr(srcDeltaNext);
	    srcDeltaNext++;
	}
	srcOffset += delta;

	if ((unsigned) *srcLengthNext == (unsigned) 0xFF) {
	    srcLengthNext++;
	    srcLen = TclGetInt4AtPtr(srcLengthNext);
	    srcLengthNext += 4;
	} else {
	    srcLen = TclGetInt1AtPtr(srcLengthNext);
	    srcLengthNext++;
	}

	if (codeOffset > pcOffset) {	/* Best cmd already found */
	    break;
	}
	if (pcOffset <= codeEnd) {	/* This cmd's code encloses pc */
	    int dist = (pcOffset - codeOffset);

	    if (dist <= bestDist) {
		bestDist = dist;
		bestSrcOffset = srcOffset;
		bestSrcLength = srcLen;
		bestCmdIdx = i;
	    }
	}
    }

    if (pcBeg != NULL) {
	const unsigned char *curr, *prev;

	/*
	 * Walk from beginning of command or BC to pc, by complete
	 * instructions. Stop when crossing pc; keep previous.
	 */

	curr = ((bestDist == TCL_SIZE_MAX) ? codePtr->codeStart : pc - bestDist);
	prev = curr;
	while (curr <= pc) {
	    prev = curr;
	    curr += tclInstructionTable[*curr].numBytes;
	}
	*pcBeg = prev;
    }

    if (bestDist == TCL_SIZE_MAX) {
	return NULL;
    }

    if (lengthPtr != NULL) {
	*lengthPtr = bestSrcLength;
    }

    if (cmdIdxPtr != NULL) {
	*cmdIdxPtr = bestCmdIdx;
    }

    return (codePtr->source + bestSrcOffset);
}

/*
 *----------------------------------------------------------------------
 *
 * GetExceptRangeForPc --
 *
 *	Given a program counter value, return the closest enclosing
 *	ExceptionRange.
 *
 * Results:
 *	If the searchMode is TCL_ERROR, this procedure ignores loop exception
 *	ranges and returns a pointer to the closest catch range. If the
 *	searchMode is TCL_BREAK, this procedure returns a pointer to the most
 *	closely enclosing ExceptionRange regardless of whether it is a loop or
 *	catch exception range. If the searchMode is TCL_CONTINUE, this
 *	procedure returns a pointer to the most closely enclosing
 *	ExceptionRange (of any type) skipping only loop exception ranges if
 *	they don't have a sensible continueOffset defined. If no matching
 *	ExceptionRange is found that encloses pc, a NULL is returned.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static ExceptionRange *
GetExceptRangeForPc(
    const unsigned char *pc,	/* The program counter value for which to
				 * search for a closest enclosing exception
				 * range. This points to a bytecode
				 * instruction in codePtr's code. */
    int searchMode,		/* If TCL_BREAK, consider either loop or catch
				 * ExceptionRanges in search. If TCL_ERROR
				 * consider only catch ranges (and ignore any
				 * closer loop ranges). If TCL_CONTINUE, look
				 * for loop ranges that define a continue
				 * point or a catch range. */
    ByteCode *codePtr)		/* Points to the ByteCode in which to search
				 * for the enclosing ExceptionRange. */
{
    ExceptionRange *rangeArrayPtr;
    size_t numRanges = codePtr->numExceptRanges;
    ExceptionRange *rangePtr;
    size_t pcOffset = pc - codePtr->codeStart;
    size_t start;

    if (numRanges == 0) {
	return NULL;
    }

    /*
     * This exploits peculiarities of our compiler: nested ranges are always
     * *after* their containing ranges, so that by scanning backwards we are
     * sure that the first matching range is indeed the deepest.
     */

    rangeArrayPtr = codePtr->exceptArrayPtr;
    rangePtr = rangeArrayPtr + numRanges;
    while (--rangePtr >= rangeArrayPtr) {
	start = rangePtr->codeOffset;
	if ((start <= pcOffset) &&
		(pcOffset < (start + rangePtr->numCodeBytes))) {
	    if (rangePtr->type == CATCH_EXCEPTION_RANGE) {
		return rangePtr;
	    }
	    if (searchMode == TCL_BREAK) {
		return rangePtr;
	    }
	    if (searchMode == TCL_CONTINUE && rangePtr->continueOffset != TCL_INDEX_NONE){
		return rangePtr;
	    }
	}
    }
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * GetOpcodeName --
 *
 *	This procedure is called by the TRACE and TRACE_WITH_OBJ macros used
 *	in TclNRExecuteByteCode when debugging. It returns the name of the
 *	bytecode instruction at a specified instruction pc.
 *
 * Results:
 *	A character string for the instruction.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

#ifdef TCL_COMPILE_DEBUG
static const char *
GetOpcodeName(
    const unsigned char *pc)	/* Points to the instruction whose name should
				 * be returned. */
{
    unsigned char opCode = *pc;

    return tclInstructionTable[opCode].name;
}
#endif /* TCL_COMPILE_DEBUG */

/*
 *----------------------------------------------------------------------
 *
 * TclExprFloatError --
 *
 *	This procedure is called when an error occurs during a floating-point
 *	operation. It reads errno and sets interp->objResultPtr accordingly.
 *
 * Results:
 *	interp->objResultPtr is set to hold an error message.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
TclExprFloatError(
    Tcl_Interp *interp,		/* Where to store error message. */
    double value)		/* Value returned after error; used to
				 * distinguish underflows from overflows. */
{
    const char *s;

    if ((errno == EDOM) || isnan(value)) {
	s = "domain error: argument not in valid range";
	Tcl_SetObjResult(interp, Tcl_NewStringObj(s, -1));
	Tcl_SetErrorCode(interp, "ARITH", "DOMAIN", s, (char *)NULL);
    } else if ((errno == ERANGE) || isinf(value)) {
	if (value == 0.0) {
	    s = "floating-point value too small to represent";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(s, -1));
	    Tcl_SetErrorCode(interp, "ARITH", "UNDERFLOW", s, (char *)NULL);
	} else {
	    s = "floating-point value too large to represent";
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(s, -1));
	    Tcl_SetErrorCode(interp, "ARITH", "OVERFLOW", s, (char *)NULL);
	}
    } else {
	Tcl_Obj *objPtr = Tcl_ObjPrintf(
		"unknown floating-point error, errno = %d", errno);

	Tcl_SetErrorCode(interp, "ARITH", "UNKNOWN",
		TclGetString(objPtr), (char *)NULL);
	Tcl_SetObjResult(interp, objPtr);
    }
}

#ifdef TCL_COMPILE_STATS
/*
 *----------------------------------------------------------------------
 *
 * TclLog2 --
 *
 *	Procedure used while collecting compilation statistics to determine
 *	the log base 2 of an integer.
 *
 * Results:
 *	Returns the log base 2 of the operand. If the argument is less than or
 *	equal to zero, a zero is returned.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclLog2(
    long long value)			/* The integer for which to compute the log
				 * base 2. The maximum output is 31 */
{
   return (value > 0) ?  (
		(value > 0x7FFFFFFF) ?
			31 : TclMSB((unsigned long long) value)
		) : 0;
}

/*
 *----------------------------------------------------------------------
 *
 * EvalStatsCmd --
 *
 *	Implements the "evalstats" command that prints instruction execution
 *	counts to stdout.
 *
 * Results:
 *	Standard Tcl results.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
EvalStatsCmd(
    TCL_UNUSED(void *),		/* Unused. */
    Tcl_Interp *interp,		/* The current interpreter. */
    int objc,			/* The number of arguments. */
    Tcl_Obj *const objv[])	/* The argument strings. */
{
    Interp *iPtr = (Interp *) interp;
    LiteralTable *globalTablePtr = &iPtr->literalTable;
    ByteCodeStats *statsPtr = &iPtr->stats;
    double totalCodeBytes, currentCodeBytes;
    double totalLiteralBytes, currentLiteralBytes;
    double objBytesIfUnshared, strBytesIfUnshared, sharingBytesSaved;
    double strBytesSharedMultX, strBytesSharedOnce;
    double numInstructions, currentHeaderBytes;
    size_t numCurrentByteCodes, numByteCodeLits;
    size_t refCountSum, literalMgmtBytes, sum, decadeHigh;
    size_t numSharedMultX, numSharedOnce, minSizeDecade, maxSizeDecade;
    Tcl_Size i, length;
    size_t ui;
    char *litTableStats;
    LiteralEntry *entryPtr;
    Tcl_Obj *objPtr;

#define Percent(a,b) ((a) * 100.0 / (b))

    TclNewObj(objPtr);
    Tcl_IncrRefCount(objPtr);

    numInstructions = 0.0;
    for (i = 0;  i < 256;  i++) {
	if (statsPtr->instructionCount[i] != 0) {
	    numInstructions += statsPtr->instructionCount[i];
	}
    }

    totalLiteralBytes = sizeof(LiteralTable)
	    + iPtr->literalTable.numBuckets * sizeof(LiteralEntry *)
	    + (statsPtr->numLiteralsCreated * sizeof(LiteralEntry))
	    + (statsPtr->numLiteralsCreated * sizeof(Tcl_Obj))
	    + statsPtr->totalLitStringBytes;
    totalCodeBytes = statsPtr->totalByteCodeBytes + totalLiteralBytes;

    numCurrentByteCodes =
	    statsPtr->numCompilations - statsPtr->numByteCodesFreed;
    currentHeaderBytes = numCurrentByteCodes
	    * offsetof(ByteCode, localCachePtr);
    literalMgmtBytes = sizeof(LiteralTable)
	    + (iPtr->literalTable.numBuckets * sizeof(LiteralEntry *))
	    + (iPtr->literalTable.numEntries * sizeof(LiteralEntry));
    currentLiteralBytes = literalMgmtBytes
	    + iPtr->literalTable.numEntries * sizeof(Tcl_Obj)
	    + statsPtr->currentLitStringBytes;
    currentCodeBytes = statsPtr->currentByteCodeBytes + currentLiteralBytes;

    /*
     * Summary statistics, total and current source and ByteCode sizes.
     */

    Tcl_AppendPrintfToObj(objPtr, "\n----------------------------------------------------------------\n");
    Tcl_AppendPrintfToObj(objPtr,
	    "Compilation and execution statistics for interpreter %p\n",
	    iPtr);

    Tcl_AppendPrintfToObj(objPtr, "\nNumber ByteCodes executed\t%" TCL_Z_MODIFIER "u\n",
	    statsPtr->numExecutions);
    Tcl_AppendPrintfToObj(objPtr, "Number ByteCodes compiled\t%" TCL_Z_MODIFIER "u\n",
	    statsPtr->numCompilations);
    Tcl_AppendPrintfToObj(objPtr, "  Mean executions/compile\t%.1f\n",
	    statsPtr->numExecutions / (float)statsPtr->numCompilations);

    Tcl_AppendPrintfToObj(objPtr, "\nInstructions executed\t\t%.0f\n",
	    numInstructions);
    Tcl_AppendPrintfToObj(objPtr, "  Mean inst/compile\t\t%.0f\n",
	    numInstructions / statsPtr->numCompilations);
    Tcl_AppendPrintfToObj(objPtr, "  Mean inst/execution\t\t%.0f\n",
	    numInstructions / statsPtr->numExecutions);

    Tcl_AppendPrintfToObj(objPtr, "\nTotal ByteCodes\t\t\t%" TCL_Z_MODIFIER "u\n",
	    statsPtr->numCompilations);
    Tcl_AppendPrintfToObj(objPtr, "  Source bytes\t\t\t%.6g\n",
	    statsPtr->totalSrcBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Code bytes\t\t\t%.6g\n",
	    totalCodeBytes);
    Tcl_AppendPrintfToObj(objPtr, "    ByteCode bytes\t\t%.6g\n",
	    statsPtr->totalByteCodeBytes);
    Tcl_AppendPrintfToObj(objPtr, "    Literal bytes\t\t%.6g\n",
	    totalLiteralBytes);
    Tcl_AppendPrintfToObj(objPtr, "      table %" TCL_Z_MODIFIER "u + bkts %" TCL_Z_MODIFIER "u + entries %" TCL_Z_MODIFIER "u + objects %" TCL_Z_MODIFIER "u + strings %.6g\n",
	    sizeof(LiteralTable),
	    iPtr->literalTable.numBuckets * sizeof(LiteralEntry *),
	    statsPtr->numLiteralsCreated * sizeof(LiteralEntry),
	    statsPtr->numLiteralsCreated * sizeof(Tcl_Obj),
	    statsPtr->totalLitStringBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Mean code/compile\t\t%.1f\n",
	    totalCodeBytes / statsPtr->numCompilations);
    Tcl_AppendPrintfToObj(objPtr, "  Mean code/source\t\t%.1f\n",
	    totalCodeBytes / statsPtr->totalSrcBytes);

    Tcl_AppendPrintfToObj(objPtr, "\nCurrent (active) ByteCodes\t%" TCL_Z_MODIFIER "u\n",
	    numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "  Source bytes\t\t\t%.6g\n",
	    statsPtr->currentSrcBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Code bytes\t\t\t%.6g\n",
	    currentCodeBytes);
    Tcl_AppendPrintfToObj(objPtr, "    ByteCode bytes\t\t%.6g\n",
	    statsPtr->currentByteCodeBytes);
    Tcl_AppendPrintfToObj(objPtr, "    Literal bytes\t\t%.6g\n",
	    currentLiteralBytes);
    Tcl_AppendPrintfToObj(objPtr, "      table %" TCL_Z_MODIFIER "u + bkts %" TCL_Z_MODIFIER "u + entries %" TCL_Z_MODIFIER "u + objects %" TCL_Z_MODIFIER "u + strings %.6g\n",
	    sizeof(LiteralTable),
	    iPtr->literalTable.numBuckets * sizeof(LiteralEntry *),
	    iPtr->literalTable.numEntries * sizeof(LiteralEntry),
	    iPtr->literalTable.numEntries * sizeof(Tcl_Obj),
	    statsPtr->currentLitStringBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Mean code/source\t\t%.1f\n",
	    currentCodeBytes / statsPtr->currentSrcBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Code + source bytes\t\t%.6g (%0.1f mean code/src)\n",
	    (currentCodeBytes + statsPtr->currentSrcBytes),
	    (currentCodeBytes / statsPtr->currentSrcBytes) + 1.0);

    /*
     * Tcl_IsShared statistics check
     *
     * This gives the refcount of each obj as Tcl_IsShared was called for it.
     * Shared objects must be duplicated before they can be modified.
     */

    numSharedMultX = 0;
    Tcl_AppendPrintfToObj(objPtr, "\nTcl_IsShared object check (all objects):\n");
    Tcl_AppendPrintfToObj(objPtr, "  Object had refcount <=1 (not shared)\t%" TCL_Z_MODIFIER "u\n",
	    tclObjsShared[1]);
    for (i = 2;  i < TCL_MAX_SHARED_OBJ_STATS;  i++) {
	Tcl_AppendPrintfToObj(objPtr, "  refcount ==%" TCL_Z_MODIFIER "u\t\t%" TCL_Z_MODIFIER "u\n",
		i, tclObjsShared[i]);
	numSharedMultX += tclObjsShared[i];
    }
    Tcl_AppendPrintfToObj(objPtr, "  refcount >=%" TCL_Z_MODIFIER "u\t\t%" TCL_Z_MODIFIER "u\n",
	    i, tclObjsShared[0]);
    numSharedMultX += tclObjsShared[0];
    Tcl_AppendPrintfToObj(objPtr, "  Total shared objects\t\t\t%" TCL_Z_MODIFIER "u\n",
	    numSharedMultX);

    /*
     * Literal table statistics.
     */

    numByteCodeLits = 0;
    refCountSum = 0;
    numSharedMultX = 0;
    numSharedOnce = 0;
    objBytesIfUnshared = 0.0;
    strBytesIfUnshared = 0.0;
    strBytesSharedMultX = 0.0;
    strBytesSharedOnce = 0.0;
    for (ui = 0;  ui < globalTablePtr->numBuckets;  ui++) {
	for (entryPtr = globalTablePtr->buckets[i];  entryPtr != NULL;
		entryPtr = entryPtr->nextPtr) {
	    if (TclHasInternalRep(entryPtr->objPtr, &tclByteCodeType)) {
		numByteCodeLits++;
	    }
	    (void) TclGetStringFromObj(entryPtr->objPtr, &length);
	    refCountSum += entryPtr->refCount;
	    objBytesIfUnshared += (entryPtr->refCount * sizeof(Tcl_Obj));
	    strBytesIfUnshared += (entryPtr->refCount * (length+1));
	    if (entryPtr->refCount > 1) {
		numSharedMultX++;
		strBytesSharedMultX += (length+1);
	    } else {
		numSharedOnce++;
		strBytesSharedOnce += (length+1);
	    }
	}
    }
    sharingBytesSaved = (objBytesIfUnshared + strBytesIfUnshared)
	    - currentLiteralBytes;

    Tcl_AppendPrintfToObj(objPtr, "\nTotal objects (all interps)\t%" TCL_Z_MODIFIER "u\n",
	    tclObjsAlloced);
    Tcl_AppendPrintfToObj(objPtr, "Current objects\t\t\t%" TCL_Z_MODIFIER "u\n",
	    (tclObjsAlloced - tclObjsFreed));
    Tcl_AppendPrintfToObj(objPtr, "Total literal objects\t\t%" TCL_Z_MODIFIER "u\n",
	    statsPtr->numLiteralsCreated);

    Tcl_AppendPrintfToObj(objPtr, "\nCurrent literal objects\t\t%" TCL_SIZE_MODIFIER "d (%0.1f%% of current objects)\n",
	    globalTablePtr->numEntries,
	    Percent(globalTablePtr->numEntries, tclObjsAlloced-tclObjsFreed));
    Tcl_AppendPrintfToObj(objPtr, "  ByteCode literals\t\t%" TCL_Z_MODIFIER "u (%0.1f%% of current literals)\n",
	    numByteCodeLits,
	    Percent(numByteCodeLits, globalTablePtr->numEntries));
    Tcl_AppendPrintfToObj(objPtr, "  Literals reused > 1x\t\t%" TCL_Z_MODIFIER "u\n",
	    numSharedMultX);
    Tcl_AppendPrintfToObj(objPtr, "  Mean reference count\t\t%.2f\n",
	    ((double) refCountSum) / globalTablePtr->numEntries);
    Tcl_AppendPrintfToObj(objPtr, "  Mean len, str reused >1x \t%.2f\n",
	    (numSharedMultX ? strBytesSharedMultX/numSharedMultX : 0.0));
    Tcl_AppendPrintfToObj(objPtr, "  Mean len, str used 1x\t\t%.2f\n",
	    (numSharedOnce ? strBytesSharedOnce/numSharedOnce : 0.0));
    Tcl_AppendPrintfToObj(objPtr, "  Total sharing savings\t\t%.6g (%0.1f%% of bytes if no sharing)\n",
	    sharingBytesSaved,
	    Percent(sharingBytesSaved, objBytesIfUnshared+strBytesIfUnshared));
    Tcl_AppendPrintfToObj(objPtr, "    Bytes with sharing\t\t%.6g\n",
	    currentLiteralBytes);
    Tcl_AppendPrintfToObj(objPtr, "      table %lu + bkts %lu + entries %lu + objects %lu + strings %.6g\n",
	    (unsigned long) sizeof(LiteralTable),
	    (unsigned long) (iPtr->literalTable.numBuckets * sizeof(LiteralEntry *)),
	    (unsigned long) (iPtr->literalTable.numEntries * sizeof(LiteralEntry)),
	    (unsigned long) (iPtr->literalTable.numEntries * sizeof(Tcl_Obj)),
	    statsPtr->currentLitStringBytes);
    Tcl_AppendPrintfToObj(objPtr, "    Bytes if no sharing\t\t%.6g = objects %.6g + strings %.6g\n",
	    (objBytesIfUnshared + strBytesIfUnshared),
	    objBytesIfUnshared, strBytesIfUnshared);
    Tcl_AppendPrintfToObj(objPtr, "  String sharing savings \t%.6g = unshared %.6g - shared %.6g\n",
	    (strBytesIfUnshared - statsPtr->currentLitStringBytes),
	    strBytesIfUnshared, statsPtr->currentLitStringBytes);
    Tcl_AppendPrintfToObj(objPtr, "  Literal mgmt overhead\t\t%" TCL_Z_MODIFIER "u (%0.1f%% of bytes with sharing)\n",
	    literalMgmtBytes,
	    Percent(literalMgmtBytes, currentLiteralBytes));
    Tcl_AppendPrintfToObj(objPtr, "    table %lu + buckets %lu + entries %lu\n",
	    (unsigned long) sizeof(LiteralTable),
	    (unsigned long) (iPtr->literalTable.numBuckets * sizeof(LiteralEntry *)),
	    (unsigned long) (iPtr->literalTable.numEntries * sizeof(LiteralEntry)));

    /*
     * Breakdown of current ByteCode space requirements.
     */

    Tcl_AppendPrintfToObj(objPtr, "\nBreakdown of current ByteCode requirements:\n");
    Tcl_AppendPrintfToObj(objPtr, "                         Bytes      Pct of    Avg per\n");
    Tcl_AppendPrintfToObj(objPtr, "                                     total    ByteCode\n");
    Tcl_AppendPrintfToObj(objPtr, "Total             %12.6g     100.00%%   %8.1f\n",
	    statsPtr->currentByteCodeBytes,
	    statsPtr->currentByteCodeBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Header            %12.6g   %8.1f%%   %8.1f\n",
	    currentHeaderBytes,
	    Percent(currentHeaderBytes, statsPtr->currentByteCodeBytes),
	    currentHeaderBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Instructions      %12.6g   %8.1f%%   %8.1f\n",
	    statsPtr->currentInstBytes,
	    Percent(statsPtr->currentInstBytes, statsPtr->currentByteCodeBytes),
	    statsPtr->currentInstBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Literal ptr array %12.6g   %8.1f%%   %8.1f\n",
	    statsPtr->currentLitBytes,
	    Percent(statsPtr->currentLitBytes, statsPtr->currentByteCodeBytes),
	    statsPtr->currentLitBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Exception table   %12.6g   %8.1f%%   %8.1f\n",
	    statsPtr->currentExceptBytes,
	    Percent(statsPtr->currentExceptBytes, statsPtr->currentByteCodeBytes),
	    statsPtr->currentExceptBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Auxiliary data    %12.6g   %8.1f%%   %8.1f\n",
	    statsPtr->currentAuxBytes,
	    Percent(statsPtr->currentAuxBytes, statsPtr->currentByteCodeBytes),
	    statsPtr->currentAuxBytes / numCurrentByteCodes);
    Tcl_AppendPrintfToObj(objPtr, "Command map       %12.6g   %8.1f%%   %8.1f\n",
	    statsPtr->currentCmdMapBytes,
	    Percent(statsPtr->currentCmdMapBytes, statsPtr->currentByteCodeBytes),
	    statsPtr->currentCmdMapBytes / numCurrentByteCodes);

    /*
     * Detailed literal statistics.
     */

    Tcl_AppendPrintfToObj(objPtr, "\nLiteral string sizes:\n");
    Tcl_AppendPrintfToObj(objPtr, "\t Up to length\t\tPercentage\n");
    maxSizeDecade = 0;
    i = 32;
    while (i-- > 0) {
	if (statsPtr->literalCount[i] > 0) {
	    maxSizeDecade = i;
	    break;
	}
    }
    sum = 0;
    for (ui = 0;  ui <= maxSizeDecade;  ui++) {
	decadeHigh = (1 << (ui+1)) - 1;
	sum += statsPtr->literalCount[ui];
	Tcl_AppendPrintfToObj(objPtr, "\t%10" TCL_SIZE_MODIFIER "d\t\t%8.0f%%\n",
		decadeHigh, Percent(sum, statsPtr->numLiteralsCreated));
    }

    litTableStats = TclLiteralStats(globalTablePtr);
    Tcl_AppendPrintfToObj(objPtr, "\nCurrent literal table statistics:\n%s\n",
	    litTableStats);
    Tcl_Free(litTableStats);

    /*
     * Source and ByteCode size distributions.
     */

    Tcl_AppendPrintfToObj(objPtr, "\nSource sizes:\n");
    Tcl_AppendPrintfToObj(objPtr, "\t Up to size\t\tPercentage\n");
    minSizeDecade = maxSizeDecade = 0;
    for (i = 0;  i < 31;  i++) {
	if (statsPtr->srcCount[i] > 0) {
	    minSizeDecade = i;
	    break;
	}
    }
    for (i = 31;  i != TCL_INDEX_NONE;  i--) {
	if (statsPtr->srcCount[i] > 0) {
	    break;		/* maxSizeDecade to consume 'i' value
				 * below... */
	}
    }
    maxSizeDecade = i;
    sum = 0;
    for (ui = minSizeDecade;  ui <= maxSizeDecade;  ui++) {
	decadeHigh = (1 << (ui+1)) - 1;
	sum += statsPtr->srcCount[ui];
	Tcl_AppendPrintfToObj(objPtr, "\t%10" TCL_SIZE_MODIFIER "d\t\t%8.0f%%\n",
		decadeHigh, Percent(sum, statsPtr->numCompilations));
    }

    Tcl_AppendPrintfToObj(objPtr, "\nByteCode sizes:\n");
    Tcl_AppendPrintfToObj(objPtr, "\t Up to size\t\tPercentage\n");
    minSizeDecade = maxSizeDecade = 0;
    for (i = 0;  i < 31;  i++) {
	if (statsPtr->byteCodeCount[i] > 0) {
	    minSizeDecade = i;
	    break;
	}
    }
    for (i = 31;  i != TCL_INDEX_NONE;  i--) {
	if (statsPtr->byteCodeCount[i] > 0) {
	    break;		/* maxSizeDecade to consume 'i' value
				 * below... */
	}
    }
    maxSizeDecade = i;
    sum = 0;
    for (ui = minSizeDecade;  ui <= maxSizeDecade;  ui++) {
	decadeHigh = (1 << (ui+1)) - 1;
	sum += statsPtr->byteCodeCount[ui];
	Tcl_AppendPrintfToObj(objPtr, "\t%10" TCL_SIZE_MODIFIER "d\t\t%8.0f%%\n",
		decadeHigh, Percent(sum, statsPtr->numCompilations));
    }

    Tcl_AppendPrintfToObj(objPtr, "\nByteCode longevity (excludes Current ByteCodes):\n");
    Tcl_AppendPrintfToObj(objPtr, "\t       Up to ms\t\tPercentage\n");
    minSizeDecade = maxSizeDecade = 0;
    for (i = 0;  i < 31;  i++) {
	if (statsPtr->lifetimeCount[i] > 0) {
	    minSizeDecade = i;
	    break;
	}
    }
    for (i = 31;  i != TCL_INDEX_NONE;  i--) {
	if (statsPtr->lifetimeCount[i] > 0) {
	    break;		/* maxSizeDecade to consume 'i' value
				 * below... */
	}
    }
    maxSizeDecade = i;
    sum = 0;
    for (ui = minSizeDecade;  ui <= maxSizeDecade;  ui++) {
	decadeHigh = (1 << (ui+1)) - 1;
	sum += statsPtr->lifetimeCount[ui];
	Tcl_AppendPrintfToObj(objPtr, "\t%12.3f\t\t%8.0f%%\n",
		decadeHigh/1000.0, Percent(sum, statsPtr->numByteCodesFreed));
    }

    /*
     * Instruction counts.
     */

    Tcl_AppendPrintfToObj(objPtr, "\nInstruction counts:\n");
    for (i = 0;  i < LAST_INST_OPCODE;  i++) {
	Tcl_AppendPrintfToObj(objPtr, "%20s %8" TCL_Z_MODIFIER "u ",
		tclInstructionTable[i].name, statsPtr->instructionCount[i]);
	if (statsPtr->instructionCount[i]) {
	    Tcl_AppendPrintfToObj(objPtr, "%6.1f%%\n",
		    Percent(statsPtr->instructionCount[i], numInstructions));
	} else {
	    Tcl_AppendPrintfToObj(objPtr, "0\n");
	}
    }

#ifdef TCL_MEM_DEBUG
    Tcl_AppendPrintfToObj(objPtr, "\nHeap Statistics:\n");
    TclDumpMemoryInfo(objPtr, 1);
#endif
    Tcl_AppendPrintfToObj(objPtr, "\n----------------------------------------------------------------\n");

    if (objc == 1) {
	Tcl_SetObjResult(interp, objPtr);
    } else {
	Tcl_Channel outChan;
	char *str = TclGetStringFromObj(objv[1], &length);

	if (length) {
	    if (strcmp(str, "stdout") == 0) {
		outChan = Tcl_GetStdChannel(TCL_STDOUT);
	    } else if (strcmp(str, "stderr") == 0) {
		outChan = Tcl_GetStdChannel(TCL_STDERR);
	    } else {
		outChan = Tcl_OpenFileChannel(NULL, str, "w", 0664);
	    }
	} else {
	    outChan = Tcl_GetStdChannel(TCL_STDOUT);
	}
	if (outChan != NULL) {
	    Tcl_WriteObj(outChan, objPtr);
	}
    }
    Tcl_DecrRefCount(objPtr);
    return TCL_OK;
}
#endif /* TCL_COMPILE_STATS */

#ifdef TCL_COMPILE_DEBUG
/*
 *----------------------------------------------------------------------
 *
 * StringForResultCode --
 *
 *	Procedure that returns a human-readable string representing a Tcl
 *	result code such as TCL_ERROR.
 *
 * Results:
 *	If the result code is one of the standard Tcl return codes, the result
 *	is a string representing that code such as "TCL_ERROR". Otherwise, the
 *	result string is that code formatted as a sequence of decimal digit
 *	characters. Note that the resulting string must not be modified by the
 *	caller.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static const char *
StringForResultCode(
    int result)			/* The Tcl result code for which to generate a
				 * string. */
{
    static char buf[TCL_INTEGER_SPACE];

    if ((result >= TCL_OK) && (result <= TCL_CONTINUE)) {
	return resultStrings[result];
    }
    TclFormatInt(buf, result);
    return buf;
}
#endif /* TCL_COMPILE_DEBUG */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
