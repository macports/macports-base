/*
 * tclCompile.c --
 *
 *	This file contains procedures that compile Tcl commands or parts of
 *	commands (like quoted strings or nested sub-commands) into a sequence
 *	of instructions ("bytecodes").
 *
 * Copyright (c) 1996-1998 Sun Microsystems, Inc.
 * Copyright (c) 2001 by Kevin B. Kenny. All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclCompile.h"

/*
 * Table of all AuxData types.
 */

static Tcl_HashTable auxDataTypeTable;
static int auxDataTypeTableInitialized; /* 0 means not yet initialized. */

TCL_DECLARE_MUTEX(tableMutex)

/*
 * Variable that controls whether compilation tracing is enabled and, if so,
 * what level of tracing is desired:
 *    0: no compilation tracing
 *    1: summarize compilation of top level cmds and proc bodies
 *    2: display all instructions of each ByteCode compiled
 * This variable is linked to the Tcl variable "tcl_traceCompile".
 */

#ifdef TCL_COMPILE_DEBUG
int tclTraceCompile = 0;
static int traceInitialized = 0;
#endif

/*
 * A table describing the Tcl bytecode instructions. Entries in this table
 * must correspond to the instruction opcode definitions in tclCompile.h. The
 * names "op1" and "op4" refer to an instruction's one or four byte first
 * operand. Similarly, "stktop" and "stknext" refer to the topmost and next to
 * topmost stack elements.
 *
 * Note that the load, store, and incr instructions do not distinguish local
 * from global variables; the bytecode interpreter at runtime uses the
 * existence of a procedure call frame to distinguish these.
 */

InstructionDesc tclInstructionTable[] = {
    /* Name	      Bytes stackEffect #Opnds  Operand types */
    {"done",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Finish ByteCode execution and return stktop (top stack item) */
    {"push1",		  2,   +1,         1,	{OPERAND_UINT1}},
	/* Push object at ByteCode objArray[op1] */
    {"push4",		  5,   +1,         1,	{OPERAND_UINT4}},
	/* Push object at ByteCode objArray[op4] */
    {"pop",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Pop the topmost stack object */
    {"dup",		  1,   +1,         0,	{OPERAND_NONE}},
	/* Duplicate the topmost stack object and push the result */
    {"concat1",		  2,   INT_MIN,    1,	{OPERAND_UINT1}},
	/* Concatenate the top op1 items and push result */
    {"invokeStk1",	  2,   INT_MIN,    1,	{OPERAND_UINT1}},
	/* Invoke command named objv[0]; <objc,objv> = <op1,top op1> */
    {"invokeStk4",	  5,   INT_MIN,    1,	{OPERAND_UINT4}},
	/* Invoke command named objv[0]; <objc,objv> = <op4,top op4> */
    {"evalStk",		  1,   0,          0,	{OPERAND_NONE}},
	/* Evaluate command in stktop using Tcl_EvalObj. */
    {"exprStk",		  1,   0,          0,	{OPERAND_NONE}},
	/* Execute expression in stktop using Tcl_ExprStringObj. */

    {"loadScalar1",	  2,   1,          1,	{OPERAND_LVT1}},
	/* Load scalar variable at index op1 <= 255 in call frame */
    {"loadScalar4",	  5,   1,          1,	{OPERAND_LVT4}},
	/* Load scalar variable at index op1 >= 256 in call frame */
    {"loadScalarStk",	  1,   0,          0,	{OPERAND_NONE}},
	/* Load scalar variable; scalar's name is stktop */
    {"loadArray1",	  2,   0,          1,	{OPERAND_LVT1}},
	/* Load array element; array at slot op1<=255, element is stktop */
    {"loadArray4",	  5,   0,          1,	{OPERAND_LVT4}},
	/* Load array element; array at slot op1 > 255, element is stktop */
    {"loadArrayStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Load array element; element is stktop, array name is stknext */
    {"loadStk",		  1,   0,          0,	{OPERAND_NONE}},
	/* Load general variable; unparsed variable name is stktop */
    {"storeScalar1",	  2,   0,          1,	{OPERAND_LVT1}},
	/* Store scalar variable at op1<=255 in frame; value is stktop */
    {"storeScalar4",	  5,   0,          1,	{OPERAND_LVT4}},
	/* Store scalar variable at op1 > 255 in frame; value is stktop */
    {"storeScalarStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Store scalar; value is stktop, scalar name is stknext */
    {"storeArray1",	  2,   -1,         1,	{OPERAND_LVT1}},
	/* Store array element; array at op1<=255, value is top then elem */
    {"storeArray4",	  5,   -1,         1,	{OPERAND_LVT4}},
	/* Store array element; array at op1>=256, value is top then elem */
    {"storeArrayStk",	  1,   -2,         0,	{OPERAND_NONE}},
	/* Store array element; value is stktop, then elem, array names */
    {"storeStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Store general variable; value is stktop, then unparsed name */

    {"incrScalar1",	  2,   0,          1,	{OPERAND_LVT1}},
	/* Incr scalar at index op1<=255 in frame; incr amount is stktop */
    {"incrScalarStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Incr scalar; incr amount is stktop, scalar's name is stknext */
    {"incrArray1",	  2,   -1,         1,	{OPERAND_LVT1}},
	/* Incr array elem; arr at slot op1<=255, amount is top then elem */
    {"incrArrayStk",	  1,   -2,         0,	{OPERAND_NONE}},
	/* Incr array element; amount is top then elem then array names */
    {"incrStk",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Incr general variable; amount is stktop then unparsed var name */
    {"incrScalar1Imm",	  3,   +1,         2,	{OPERAND_LVT1, OPERAND_INT1}},
	/* Incr scalar at slot op1 <= 255; amount is 2nd operand byte */
    {"incrScalarStkImm",  2,   0,          1,	{OPERAND_INT1}},
	/* Incr scalar; scalar name is stktop; incr amount is op1 */
    {"incrArray1Imm",	  3,   0,          2,	{OPERAND_LVT1, OPERAND_INT1}},
	/* Incr array elem; array at slot op1 <= 255, elem is stktop,
	 * amount is 2nd operand byte */
    {"incrArrayStkImm",	  2,   -1,         1,	{OPERAND_INT1}},
	/* Incr array element; elem is top then array name, amount is op1 */
    {"incrStkImm",	  2,   0,	   1,	{OPERAND_INT1}},
	/* Incr general variable; unparsed name is top, amount is op1 */

    {"jump1",		  2,   0,          1,	{OPERAND_INT1}},
	/* Jump relative to (pc + op1) */
    {"jump4",		  5,   0,          1,	{OPERAND_INT4}},
	/* Jump relative to (pc + op4) */
    {"jumpTrue1",	  2,   -1,         1,	{OPERAND_INT1}},
	/* Jump relative to (pc + op1) if stktop expr object is true */
    {"jumpTrue4",	  5,   -1,         1,	{OPERAND_INT4}},
	/* Jump relative to (pc + op4) if stktop expr object is true */
    {"jumpFalse1",	  2,   -1,         1,	{OPERAND_INT1}},
	/* Jump relative to (pc + op1) if stktop expr object is false */
    {"jumpFalse4",	  5,   -1,         1,	{OPERAND_INT4}},
	/* Jump relative to (pc + op4) if stktop expr object is false */

    {"lor",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Logical or:	push (stknext || stktop) */
    {"land",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Logical and:	push (stknext && stktop) */
    {"bitor",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Bitwise or:	push (stknext | stktop) */
    {"bitxor",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Bitwise xor	push (stknext ^ stktop) */
    {"bitand",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Bitwise and:	push (stknext & stktop) */
    {"eq",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Equal:	push (stknext == stktop) */
    {"neq",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Not equal:	push (stknext != stktop) */
    {"lt",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Less:	push (stknext < stktop) */
    {"gt",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Greater:	push (stknext || stktop) */
    {"le",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Less or equal: push (stknext || stktop) */
    {"ge",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Greater or equal: push (stknext || stktop) */
    {"lshift",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Left shift:	push (stknext << stktop) */
    {"rshift",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Right shift:	push (stknext >> stktop) */
    {"add",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Add:		push (stknext + stktop) */
    {"sub",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Sub:		push (stkext - stktop) */
    {"mult",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Multiply:	push (stknext * stktop) */
    {"div",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Divide:	push (stknext / stktop) */
    {"mod",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Mod:		push (stknext % stktop) */
    {"uplus",		  1,   0,          0,	{OPERAND_NONE}},
	/* Unary plus:	push +stktop */
    {"uminus",		  1,   0,          0,	{OPERAND_NONE}},
	/* Unary minus:	push -stktop */
    {"bitnot",		  1,   0,          0,	{OPERAND_NONE}},
	/* Bitwise not:	push ~stktop */
    {"not",		  1,   0,          0,	{OPERAND_NONE}},
	/* Logical not:	push !stktop */
    {"callBuiltinFunc1",  2,   1,          1,	{OPERAND_UINT1}},
	/* Call builtin math function with index op1; any args are on stk */
    {"callFunc1",	  2,   INT_MIN,    1,	{OPERAND_UINT1}},
	/* Call non-builtin func objv[0]; <objc,objv>=<op1,top op1> */
    {"tryCvtToNumeric",	  1,   0,          0,	{OPERAND_NONE}},
	/* Try converting stktop to first int then double if possible. */

    {"break",		  1,   0,          0,	{OPERAND_NONE}},
	/* Abort closest enclosing loop; if none, return TCL_BREAK code. */
    {"continue",	  1,   0,          0,	{OPERAND_NONE}},
	/* Skip to next iteration of closest enclosing loop; if none, return
	 * TCL_CONTINUE code. */

    {"foreach_start4",	  5,   0,          1,	{OPERAND_AUX4}},
	/* Initialize execution of a foreach loop. Operand is aux data index
	 * of the ForeachInfo structure for the foreach command. */
    {"foreach_step4",	  5,   +1,         1,	{OPERAND_AUX4}},
	/* "Step" or begin next iteration of foreach loop. Push 0 if to
	 * terminate loop, else push 1. */

    {"beginCatch4",	  5,   0,          1,	{OPERAND_UINT4}},
	/* Record start of catch with the operand's exception index. Push the
	 * current stack depth onto a special catch stack. */
    {"endCatch",	  1,   0,          0,	{OPERAND_NONE}},
	/* End of last catch. Pop the bytecode interpreter's catch stack. */
    {"pushResult",	  1,   +1,         0,	{OPERAND_NONE}},
	/* Push the interpreter's object result onto the stack. */
    {"pushReturnCode",	  1,   +1,         0,	{OPERAND_NONE}},
	/* Push interpreter's return code (e.g. TCL_OK or TCL_ERROR) as a new
	 * object onto the stack. */

    {"streq",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Str Equal:	push (stknext eq stktop) */
    {"strneq",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Str !Equal:	push (stknext neq stktop) */
    {"strcmp",		  1,   -1,         0,	{OPERAND_NONE}},
	/* Str Compare:	push (stknext cmp stktop) */
    {"strlen",		  1,   0,          0,	{OPERAND_NONE}},
	/* Str Length:	push (strlen stktop) */
    {"strindex",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Str Index:	push (strindex stknext stktop) */
    {"strmatch",	  2,   -1,         1,	{OPERAND_INT1}},
	/* Str Match:	push (strmatch stknext stktop) opnd == nocase */

    {"list",		  5,   INT_MIN,    1,	{OPERAND_UINT4}},
	/* List:	push (stk1 stk2 ... stktop) */
    {"listIndex",	  1,   -1,         0,	{OPERAND_NONE}},
	/* List Index:	push (listindex stknext stktop) */
    {"listLength",	  1,   0,          0,	{OPERAND_NONE}},
	/* List Len:	push (listlength stktop) */

    {"appendScalar1",	  2,   0,          1,	{OPERAND_LVT1}},
	/* Append scalar variable at op1<=255 in frame; value is stktop */
    {"appendScalar4",	  5,   0,          1,	{OPERAND_LVT4}},
	/* Append scalar variable at op1 > 255 in frame; value is stktop */
    {"appendArray1",	  2,   -1,         1,	{OPERAND_LVT1}},
	/* Append array element; array at op1<=255, value is top then elem */
    {"appendArray4",	  5,   -1,         1,	{OPERAND_LVT4}},
	/* Append array element; array at op1>=256, value is top then elem */
    {"appendArrayStk",	  1,   -2,         0,	{OPERAND_NONE}},
	/* Append array element; value is stktop, then elem, array names */
    {"appendStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Append general variable; value is stktop, then unparsed name */
    {"lappendScalar1",	  2,   0,          1,	{OPERAND_LVT1}},
	/* Lappend scalar variable at op1<=255 in frame; value is stktop */
    {"lappendScalar4",	  5,   0,          1,	{OPERAND_LVT4}},
	/* Lappend scalar variable at op1 > 255 in frame; value is stktop */
    {"lappendArray1",	  2,   -1,         1,	{OPERAND_LVT1}},
	/* Lappend array element; array at op1<=255, value is top then elem */
    {"lappendArray4",	  5,   -1,         1,	{OPERAND_LVT4}},
	/* Lappend array element; array at op1>=256, value is top then elem */
    {"lappendArrayStk",	  1,   -2,         0,	{OPERAND_NONE}},
	/* Lappend array element; value is stktop, then elem, array names */
    {"lappendStk",	  1,   -1,         0,	{OPERAND_NONE}},
	/* Lappend general variable; value is stktop, then unparsed name */

    {"lindexMulti",	  5,   INT_MIN,    1,	{OPERAND_UINT4}},
	/* Lindex with generalized args, operand is number of stacked objs
	 * used: (operand-1) entries from stktop are the indices; then list to
	 * process. */
    {"over",		  5,   +1,         1,	{OPERAND_UINT4}},
	/* Duplicate the arg-th element from top of stack (TOS=0) */
    {"lsetList",          1,   -2,         0,	{OPERAND_NONE}},
	/* Four-arg version of 'lset'. stktop is old value; next is new
	 * element value, next is the index list; pushes new value */
    {"lsetFlat",          5,   INT_MIN,    1,	{OPERAND_UINT4}},
	/* Three- or >=5-arg version of 'lset', operand is number of stacked
	 * objs: stktop is old value, next is new element value, next come
	 * (operand-2) indices; pushes the new value.
	 */

    {"returnImm",	  9,   -1,         2,	{OPERAND_INT4, OPERAND_UINT4}},
	/* Compiled [return], code, level are operands; options and result
	 * are on the stack. */
    {"expon",		  1,   -1,	   0,	{OPERAND_NONE}},
	/* Binary exponentiation operator: push (stknext ** stktop) */

    /*
     * NOTE: the stack effects of expandStkTop and invokeExpanded are wrong -
     * but it cannot be done right at compile time, the stack effect is only
     * known at run time. The value for invokeExpanded is estimated better at
     * compile time.
     * See the comments further down in this file, where INST_INVOKE_EXPANDED
     * is emitted.
     */
    {"expandStart",       1,    0,          0,	{OPERAND_NONE}},
	/* Start of command with {*} (expanded) arguments */
    {"expandStkTop",      5,    0,          1,	{OPERAND_UINT4}},
	/* Expand the list at stacktop: push its elements on the stack */
    {"invokeExpanded",    1,    0,          0,	{OPERAND_NONE}},
	/* Invoke the command marked by the last 'expandStart' */

    {"listIndexImm",	  5,	0,	   1,	{OPERAND_IDX4}},
	/* List Index:	push (lindex stktop op4) */
    {"listRangeImm",	  9,	0,	   2,	{OPERAND_IDX4, OPERAND_IDX4}},
	/* List Range:	push (lrange stktop op4 op4) */
    {"startCommand",	  9,	0,	   2,	{OPERAND_INT4,OPERAND_UINT4}},
	/* Start of bytecoded command: op is the length of the cmd's code, op2
	 * is number of commands here */

    {"listIn",		  1,	-1,	   0,	{OPERAND_NONE}},
	/* List containment: push [lsearch stktop stknext]>=0) */
    {"listNotIn",	  1,	-1,	   0,	{OPERAND_NONE}},
	/* List negated containment: push [lsearch stktop stknext]<0) */

    {"pushReturnOpts",	  1,	+1,	   0,	{OPERAND_NONE}},
	/* Push the interpreter's return option dictionary as an object on the
	 * stack. */
    {"returnStk",	  1,	-2,	   0,	{OPERAND_NONE}},
	/* Compiled [return]; options and result are on the stack, code and
	 * level are in the options. */

    {"dictGet",		  5,	INT_MIN,   1,	{OPERAND_UINT4}},
	/* The top op4 words (min 1) are a key path into the dictionary just
	 * below the keys on the stack, and all those values are replaced by
	 * the value read out of that key-path (like [dict get]).
	 * Stack:  ... dict key1 ... keyN => ... value */
    {"dictSet",		  9,	INT_MIN,   2,	{OPERAND_UINT4, OPERAND_LVT4}},
	/* Update a dictionary value such that the keys are a path pointing to
	 * the value. op4#1 = numKeys, op4#2 = LVTindex
	 * Stack:  ... key1 ... keyN value => ... newDict */
    {"dictUnset",	  9,	INT_MIN,   2,	{OPERAND_UINT4, OPERAND_LVT4}},
	/* Update a dictionary value such that the keys are not a path pointing
	 * to any value. op4#1 = numKeys, op4#2 = LVTindex
	 * Stack:  ... key1 ... keyN => ... newDict */
    {"dictIncrImm",	  9,	0,	   2,	{OPERAND_INT4, OPERAND_LVT4}},
	/* Update a dictionary value such that the value pointed to by key is
	 * incremented by some value (or set to it if the key isn't in the
	 * dictionary at all). op4#1 = incrAmount, op4#2 = LVTindex
	 * Stack:  ... key => ... newDict */
    {"dictAppend",	  5,	-1,	   1,	{OPERAND_LVT4}},
	/* Update a dictionary value such that the value pointed to by key has
	 * some value string-concatenated onto it. op4 = LVTindex
	 * Stack:  ... key valueToAppend => ... newDict */
    {"dictLappend",	  5,	-1,	   1,	{OPERAND_LVT4}},
	/* Update a dictionary value such that the value pointed to by key has
	 * some value list-appended onto it. op4 = LVTindex
	 * Stack:  ... key valueToAppend => ... newDict */
    {"dictFirst",	  5,	+2,	   1,	{OPERAND_LVT4}},
	/* Begin iterating over the dictionary, using the local scalar
	 * indicated by op4 to hold the iterator state. If doneBool is true,
	 * dictDone *must* be called later on.
	 * Stack:  ... dict => ... value key doneBool */
    {"dictNext",	  5,	+3,	   1,	{OPERAND_LVT4}},
	/* Get the next iteration from the iterator in op4's local scalar.
	 * Stack:  ... => ... value key doneBool */
    {"dictDone",	  5,	0,	   1,	{OPERAND_LVT4}},
	/* Terminate the iterator in op4's local scalar. */
    {"dictUpdateStart",   9,    0,	   2,	{OPERAND_LVT4, OPERAND_AUX4}},
	/* Create the variables (described in the aux data referred to by the
	 * second immediate argument) to mirror the state of the dictionary in
	 * the variable referred to by the first immediate argument. The list
	 * of keys (popped from the stack) must be the same length as the list
	 * of variables.
	 * Stack:  ... keyList => ... */
    {"dictUpdateEnd",	  9,    -1,	   2,	{OPERAND_LVT4, OPERAND_AUX4}},
	/* Reflect the state of local variables (described in the aux data
	 * referred to by the second immediate argument) back to the state of
	 * the dictionary in the variable referred to by the first immediate
	 * argument. The list of keys (popped from the stack) must be the same
	 * length as the list of variables.
	 * Stack:  ... keyList => ... */
    {"jumpTable",	  5,	-1,	   1,	{OPERAND_AUX4}},
	/* Jump according to the jump-table (in AuxData as indicated by the
	 * operand) and the argument popped from the list. Always executes the
	 * next instruction if no match against the table's entries was found.
	 * Stack:  ... value => ...
	 * Note that the jump table contains offsets relative to the PC when
	 * it points to this instruction; the code is relocatable. */
    {"upvar",            5,     0,        1,   {OPERAND_LVT4}},
         /* finds level and otherName in stack, links to local variable at
	  * index op1. Leaves the level on stack. */
    {"nsupvar",          5,     0,        1,   {OPERAND_LVT4}},
         /* finds namespace and otherName in stack, links to local variable at
	  * index op1. Leaves the namespace on stack. */
    {"variable",         5,     0,        1,   {OPERAND_LVT4}},
         /* finds namespace and otherName in stack, links to local variable at
	  * index op1. Leaves the namespace on stack. */
    {"syntax",	 	 9,   -1,         2,	{OPERAND_INT4, OPERAND_UINT4}},
	/* Compiled bytecodes to signal syntax error. */
    {"reverse",		 5,    0,         1,	{OPERAND_UINT4}},
	/* Reverse the order of the arg elements at the top of stack */

    {"regexp",		 2,   -1,         1,	{OPERAND_INT1}},
	/* Regexp:	push (regexp stknext stktop) opnd == nocase */

    {"existScalar",	 5,    1,         1,	{OPERAND_LVT4}},
	/* Test if scalar variable at index op1 in call frame exists */
    {"existArray",	 5,    0,         1,	{OPERAND_LVT4}},
	/* Test if array element exists; array at slot op1, element is
	 * stktop */
    {"existArrayStk",	 1,    -1,        0,	{OPERAND_NONE}},
	/* Test if array element exists; element is stktop, array name is
	 * stknext */
    {"existStk",	 1,    0,         0,	{OPERAND_NONE}},
	/* Test if general variable exists; unparsed variable name is stktop*/
    {0, 0, 0, 0, {0}}
};

/*
 * Prototypes for procedures defined later in this file:
 */

static void		DupByteCodeInternalRep(Tcl_Obj *srcPtr,
			    Tcl_Obj *copyPtr);
static unsigned char *	EncodeCmdLocMap(CompileEnv *envPtr,
			    ByteCode *codePtr, unsigned char *startPtr);
static void		EnterCmdExtentData(CompileEnv *envPtr,
			    int cmdNumber, int numSrcBytes, int numCodeBytes);
static void		EnterCmdStartData(CompileEnv *envPtr,
			    int cmdNumber, int srcOffset, int codeOffset);
static void		FreeByteCodeInternalRep(Tcl_Obj *objPtr);
static int		GetCmdLocEncodingSize(CompileEnv *envPtr);
#ifdef TCL_COMPILE_STATS
static void		RecordByteCodeStats(ByteCode *codePtr);
#endif /* TCL_COMPILE_STATS */
static void		RegisterAuxDataType(AuxDataType *typePtr);
static int		SetByteCodeFromAny(Tcl_Interp *interp,
			    Tcl_Obj *objPtr);
static int		FormatInstruction(ByteCode *codePtr,
			    unsigned char *pc, Tcl_Obj *bufferObj);
static void		PrintSourceToObj(Tcl_Obj *appendObj,
			    const char *stringPtr, int maxChars);
/*
 * TIP #280: Helper for building the per-word line information of all compiled
 * commands.
 */
static void		EnterCmdWordData(ExtCmdLoc *eclPtr, int srcOffset,
			    Tcl_Token *tokenPtr, const char *cmd, int len,
			    int numWords, int line, int* clNext, int **lines,
			    CompileEnv* envPtr);
static void		ReleaseCmdWordData(ExtCmdLoc *eclPtr);

/*
 * The structure below defines the bytecode Tcl object type by means of
 * procedures that can be invoked by generic object code.
 */

Tcl_ObjType tclByteCodeType = {
    "bytecode",			/* name */
    FreeByteCodeInternalRep,	/* freeIntRepProc */
    DupByteCodeInternalRep,	/* dupIntRepProc */
    NULL,			/* updateStringProc */
    SetByteCodeFromAny		/* setFromAnyProc */
};

/*
 *----------------------------------------------------------------------
 *
 * TclSetByteCodeFromAny --
 *
 *	Part of the bytecode Tcl object type implementation. Attempts to
 *	generate an byte code internal form for the Tcl object "objPtr" by
 *	compiling its string representation. This function also takes a hook
 *	procedure that will be invoked to perform any needed post processing
 *	on the compilation results before generating byte codes. interp is
 *	compilation context and may not be NULL.
 *
 * Results:
 *	The return value is a standard Tcl object result. If an error occurs
 *	during compilation, an error message is left in the interpreter's
 *	result.
 *
 * Side effects:
 *	Frees the old internal representation. If no error occurs, then the
 *	compiled code is stored as "objPtr"s bytecode representation. Also, if
 *	debugging, initializes the "tcl_traceCompile" Tcl variable used to
 *	trace compilations.
 *
 *----------------------------------------------------------------------
 */

int
TclSetByteCodeFromAny(
    Tcl_Interp *interp,		/* The interpreter for which the code is being
				 * compiled. Must not be NULL. */
    Tcl_Obj *objPtr,		/* The object to make a ByteCode object. */
    CompileHookProc *hookProc,	/* Procedure to invoke after compilation. */
    ClientData clientData)	/* Hook procedure private data. */
{
    Interp *iPtr = (Interp *) interp;
    CompileEnv compEnv;		/* Compilation environment structure allocated
				 * in frame. */
    int length, result = TCL_OK;
    const char *stringPtr;
    ContLineLoc* clLocPtr;

#ifdef TCL_COMPILE_DEBUG
    if (!traceInitialized) {
	if (Tcl_LinkVar(interp, "tcl_traceCompile",
		(char *) &tclTraceCompile, TCL_LINK_INT) != TCL_OK) {
	    Tcl_Panic("SetByteCodeFromAny: unable to create link for tcl_traceCompile variable");
	}
	traceInitialized = 1;
    }
#endif

    stringPtr = TclGetStringFromObj(objPtr, &length);

    /*
     * TIP #280: Pick up the CmdFrame in which the BC compiler was invoked and
     * use to initialize the tracking in the compiler. This information was
     * stored by TclCompEvalObj and ProcCompileProc.
     */

    TclInitCompileEnv(interp, &compEnv, stringPtr, length,
	    iPtr->invokeCmdFramePtr, iPtr->invokeWord);
    /*
     * Now we check if we have data about invisible continuation lines for the
     * script, and make it available to the compile environment, if so.
     *
     * It is not clear if the script Tcl_Obj* can be free'd while the compiler
     * is using it, leading to the release of the associated ContLineLoc
     * structure as well. To ensure that the latter doesn't happen we set a
     * lock on it. We release this lock in the function TclFreeCompileEnv (),
     * found in this file. The "lineCLPtr" hashtable is managed in the file
     * "tclObj.c".
     */

    clLocPtr = TclContinuationsGet (objPtr);
    if (clLocPtr) {
	compEnv.clLoc  = clLocPtr;
	compEnv.clNext = &compEnv.clLoc->loc[0];
	Tcl_Preserve (compEnv.clLoc);
    }

    TclCompileScript(interp, stringPtr, length, &compEnv);

    /*
     * Successful compilation. Add a "done" instruction at the end.
     */

    TclEmitOpcode(INST_DONE, &compEnv);

    /*
     * Invoke the compilation hook procedure if one exists.
     */

    if (hookProc) {
	result = (*hookProc)(interp, &compEnv, clientData);
    }

    /*
     * Change the object into a ByteCode object. Ownership of the literal
     * objects and aux data items is given to the ByteCode object.
     */

#ifdef TCL_COMPILE_DEBUG
    TclVerifyLocalLiteralTable(&compEnv);
#endif /*TCL_COMPILE_DEBUG*/

    if (result == TCL_OK) {
	TclInitByteCodeObj(objPtr, &compEnv);
#ifdef TCL_COMPILE_DEBUG
	if (tclTraceCompile >= 2) {
	    TclPrintByteCodeObj(interp, objPtr);
	    fflush(stdout);
	}
#endif /* TCL_COMPILE_DEBUG */
    }

    TclFreeCompileEnv(&compEnv);
    return result;
}

/*
 *-----------------------------------------------------------------------
 *
 * SetByteCodeFromAny --
 *
 *	Part of the bytecode Tcl object type implementation. Attempts to
 *	generate an byte code internal form for the Tcl object "objPtr" by
 *	compiling its string representation.
 *
 * Results:
 *	The return value is a standard Tcl object result. If an error occurs
 *	during compilation, an error message is left in the interpreter's
 *	result unless "interp" is NULL.
 *
 * Side effects:
 *	Frees the old internal representation. If no error occurs, then the
 *	compiled code is stored as "objPtr"s bytecode representation. Also, if
 *	debugging, initializes the "tcl_traceCompile" Tcl variable used to
 *	trace compilations.
 *
 *----------------------------------------------------------------------
 */

static int
SetByteCodeFromAny(
    Tcl_Interp *interp,		/* The interpreter for which the code is being
				 * compiled. Must not be NULL. */
    Tcl_Obj *objPtr)		/* The object to make a ByteCode object. */
{
    if (interp == NULL) {
	return TCL_ERROR;
    }
    (void) TclSetByteCodeFromAny(interp, objPtr, NULL, (ClientData) NULL);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * DupByteCodeInternalRep --
 *
 *	Part of the bytecode Tcl object type implementation. However, it does
 *	not copy the internal representation of a bytecode Tcl_Obj, but
 *	instead leaves the new object untyped (with a NULL type pointer).
 *	Code will be compiled for the new object only if necessary.
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
DupByteCodeInternalRep(
    Tcl_Obj *srcPtr,		/* Object with internal rep to copy. */
    Tcl_Obj *copyPtr)		/* Object with internal rep to set. */
{
    return;
}

/*
 *----------------------------------------------------------------------
 *
 * FreeByteCodeInternalRep --
 *
 *	Part of the bytecode Tcl object type implementation. Frees the storage
 *	associated with a bytecode object's internal representation unless its
 *	code is actively being executed.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The bytecode object's internal rep is marked invalid and its code gets
 *	freed unless the code is actively being executed. In that case the
 *	cleanup is delayed until the last execution of the code completes.
 *
 *----------------------------------------------------------------------
 */

static void
FreeByteCodeInternalRep(
    register Tcl_Obj *objPtr)	/* Object whose internal rep to free. */
{
    register ByteCode *codePtr = (ByteCode *)
	    objPtr->internalRep.twoPtrValue.ptr1;

    codePtr->refCount--;
    if (codePtr->refCount <= 0) {
	TclCleanupByteCode(codePtr);
    }
    objPtr->typePtr = NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCleanupByteCode --
 *
 *	This procedure does all the real work of freeing up a bytecode
 *	object's ByteCode structure. It's called only when the structure's
 *	reference count becomes zero.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Frees objPtr's bytecode internal representation and sets its type NULL
 *	Also releases its literals and frees its auxiliary data items.
 *
 *----------------------------------------------------------------------
 */

void
TclCleanupByteCode(
    register ByteCode *codePtr)	/* Points to the ByteCode to free. */
{
    Tcl_Interp *interp = (Tcl_Interp *) *codePtr->interpHandle;
    Interp *iPtr = (Interp *) interp;
    int numLitObjects = codePtr->numLitObjects;
    int numAuxDataItems = codePtr->numAuxDataItems;
    register Tcl_Obj **objArrayPtr, *objPtr;
    register AuxData *auxDataPtr;
    int i;
#ifdef TCL_COMPILE_STATS

    if (interp != NULL) {
	ByteCodeStats *statsPtr;
	Tcl_Time destroyTime;
	int lifetimeSec, lifetimeMicroSec, log2;

	statsPtr = &((Interp *) interp)->stats;

	statsPtr->numByteCodesFreed++;
	statsPtr->currentSrcBytes -= (double) codePtr->numSrcBytes;
	statsPtr->currentByteCodeBytes -= (double) codePtr->structureSize;

	statsPtr->currentInstBytes -= (double) codePtr->numCodeBytes;
	statsPtr->currentLitBytes -= (double)
		codePtr->numLitObjects * sizeof(Tcl_Obj *);
	statsPtr->currentExceptBytes -= (double)
		codePtr->numExceptRanges * sizeof(ExceptionRange);
	statsPtr->currentAuxBytes -= (double)
		codePtr->numAuxDataItems * sizeof(AuxData);
	statsPtr->currentCmdMapBytes -= (double) codePtr->numCmdLocBytes;

	Tcl_GetTime(&destroyTime);
	lifetimeSec = destroyTime.sec - codePtr->createTime.sec;
	if (lifetimeSec > 2000) {	/* avoid overflow */
	    lifetimeSec = 2000;
	}
	lifetimeMicroSec = 1000000 * lifetimeSec +
		(destroyTime.usec - codePtr->createTime.usec);

	log2 = TclLog2(lifetimeMicroSec);
	if (log2 > 31) {
	    log2 = 31;
	}
	statsPtr->lifetimeCount[log2]++;
    }
#endif /* TCL_COMPILE_STATS */

    /*
     * A single heap object holds the ByteCode structure and its code, object,
     * command location, and auxiliary data arrays. This means we only need to
     * 1) decrement the ref counts of the LiteralEntry's in its literal array,
     * 2) call the free procs for the auxiliary data items, 3) free the
     * localCache if it is unused, and finally 4) free the ByteCode
     * structure's heap object.
     *
     * The case for TCL_BYTECODE_PRECOMPILED (precompiled ByteCodes, like
     * those generated from tbcload) is special, as they doesn't make use of
     * the global literal table. They instead maintain private references to
     * their literals which must be decremented.
     *
     * In order to insure a proper and efficient cleanup of the literal array
     * when it contains non-shared literals [Bug 983660], we also distinguish
     * the case of an interpreter being deleted (signaled by interp == NULL).
     * Also, as the interp deletion will remove the global literal table
     * anyway, we avoid the extra cost of updating it for each literal being
     * released.
     */

    if ((codePtr->flags & TCL_BYTECODE_PRECOMPILED) || (interp == NULL)) {

	objArrayPtr = codePtr->objArrayPtr;
	for (i = 0;  i < numLitObjects;  i++) {
	    objPtr = *objArrayPtr;
	    if (objPtr) {
		Tcl_DecrRefCount(objPtr);
	    }
	    objArrayPtr++;
	}
	codePtr->numLitObjects = 0;
    } else {
	objArrayPtr = codePtr->objArrayPtr;
	for (i = 0;  i < numLitObjects;  i++) {
	    /*
	     * TclReleaseLiteral sets a ByteCode's object array entry NULL to
	     * indicate that it has already freed the literal.
	     */

	    objPtr = *objArrayPtr;
	    if (objPtr != NULL) {
		TclReleaseLiteral(interp, objPtr);
	    }
	    objArrayPtr++;
	}
    }

    auxDataPtr = codePtr->auxDataArrayPtr;
    for (i = 0;  i < numAuxDataItems;  i++) {
	if (auxDataPtr->type->freeProc != NULL) {
	    (auxDataPtr->type->freeProc)(auxDataPtr->clientData);
	}
	auxDataPtr++;
    }

    /*
     * TIP #280. Release the location data associated with this byte code
     * structure, if any. NOTE: The interp we belong to may be gone already,
     * and the data with it.
     *
     * See also tclBasic.c, DeleteInterpProc
     */

    if (iPtr) {
	Tcl_HashEntry *hePtr = Tcl_FindHashEntry(iPtr->lineBCPtr,
		(char *) codePtr);
	if (hePtr) {
	    ReleaseCmdWordData(Tcl_GetHashValue(hePtr));
	    Tcl_DeleteHashEntry(hePtr);
	}
    }

    if (codePtr->localCachePtr && (--codePtr->localCachePtr->refCount == 0)) {
	TclFreeLocalCache(interp, codePtr->localCachePtr);
    }

    TclHandleRelease(codePtr->interpHandle);
    ckfree((char *) codePtr);
}

static void
ReleaseCmdWordData(
    ExtCmdLoc *eclPtr)
{
    int i;

    if (eclPtr->type == TCL_LOCATION_SOURCE) {
	Tcl_DecrRefCount(eclPtr->path);
    }
    for (i=0 ; i<eclPtr->nuloc ; i++) {
	ckfree((char *) eclPtr->loc[i].line);
    }

    if (eclPtr->loc != NULL) {
	ckfree((char *) eclPtr->loc);
    }

    Tcl_DeleteHashTable (&eclPtr->litInfo);

    ckfree((char *) eclPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitCompileEnv --
 *
 *	Initializes a CompileEnv compilation environment structure for the
 *	compilation of a string in an interpreter.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The CompileEnv structure is initialized.
 *
 *----------------------------------------------------------------------
 */

void
TclInitCompileEnv(
    Tcl_Interp *interp,		/* The interpreter for which a CompileEnv
				 * structure is initialized. */
    register CompileEnv *envPtr,/* Points to the CompileEnv structure to
				 * initialize. */
    const char *stringPtr,	/* The source string to be compiled. */
    int numBytes,		/* Number of bytes in source string. */
    const CmdFrame *invoker,	/* Location context invoking the bcc */
    int word)			/* Index of the word in that context getting
				 * compiled */
{
    Interp *iPtr = (Interp *) interp;

    envPtr->iPtr = iPtr;
    envPtr->source = stringPtr;
    envPtr->numSrcBytes = numBytes;
    envPtr->procPtr = iPtr->compiledProcPtr;
    iPtr->compiledProcPtr = NULL;
    envPtr->numCommands = 0;
    envPtr->exceptDepth = 0;
    envPtr->maxExceptDepth = 0;
    envPtr->maxStackDepth = 0;
    envPtr->currStackDepth = 0;
    TclInitLiteralTable(&(envPtr->localLitTable));

    envPtr->codeStart = envPtr->staticCodeSpace;
    envPtr->codeNext = envPtr->codeStart;
    envPtr->codeEnd = (envPtr->codeStart + COMPILEENV_INIT_CODE_BYTES);
    envPtr->mallocedCodeArray = 0;

    envPtr->literalArrayPtr = envPtr->staticLiteralSpace;
    envPtr->literalArrayNext = 0;
    envPtr->literalArrayEnd = COMPILEENV_INIT_NUM_OBJECTS;
    envPtr->mallocedLiteralArray = 0;

    envPtr->exceptArrayPtr = envPtr->staticExceptArraySpace;
    envPtr->exceptArrayNext = 0;
    envPtr->exceptArrayEnd = COMPILEENV_INIT_EXCEPT_RANGES;
    envPtr->mallocedExceptArray = 0;

    envPtr->cmdMapPtr = envPtr->staticCmdMapSpace;
    envPtr->cmdMapEnd = COMPILEENV_INIT_CMD_MAP_SIZE;
    envPtr->mallocedCmdMap = 0;
    envPtr->atCmdStart = 1;

    /*
     * TIP #280: Set up the extended command location information, based on
     * the context invoking the byte code compiler. This structure is used to
     * keep the per-word line information for all compiled commands.
     *
     * See also tclBasic.c, TclEvalObjEx, for the equivalent code in the
     * non-compiling evaluator
     */

    envPtr->extCmdMapPtr = (ExtCmdLoc *) ckalloc(sizeof(ExtCmdLoc));
    envPtr->extCmdMapPtr->loc = NULL;
    envPtr->extCmdMapPtr->nloc = 0;
    envPtr->extCmdMapPtr->nuloc = 0;
    envPtr->extCmdMapPtr->path = NULL;
    Tcl_InitHashTable(&envPtr->extCmdMapPtr->litInfo, TCL_ONE_WORD_KEYS);

    if (invoker == NULL ||
	(invoker->type == TCL_LOCATION_EVAL_LIST)) {
        /*
	 * Initialize the compiler for relative counting in case of a
	 * dynamic context.
	 */

	envPtr->line = 1;
	envPtr->extCmdMapPtr->type =
		(envPtr->procPtr ? TCL_LOCATION_PROC : TCL_LOCATION_BC);
    } else {
        /*
	 * Initialize the compiler using the context, making counting absolute
	 * to that context. Note that the context can be byte code execution.
	 * In that case we have to fill out the missing pieces (line, path,
	 * ...) which may make change the type as well.
	 */

	CmdFrame* ctxPtr = (CmdFrame *) TclStackAlloc(interp, sizeof(CmdFrame));
	int pc = 0;

	*ctxPtr = *invoker;

	if (invoker->type == TCL_LOCATION_BC) {
	    /*
	     * Note: Type BC => ctx.data.eval.path    is not used.
	     *                  ctx.data.tebc.codePtr is used instead.
	     */

	    TclGetSrcInfoForPc(ctxPtr);
	    pc = 1;
	}

	if ((ctxPtr->nline <= word) || (ctxPtr->line[word] < 0)) {
	    /*
	     * Word is not a literal, relative counting.
	     */

	    envPtr->line = 1;
	    envPtr->extCmdMapPtr->type =
		    (envPtr->procPtr ? TCL_LOCATION_PROC : TCL_LOCATION_BC);

	    if (pc && (ctxPtr->type == TCL_LOCATION_SOURCE)) {
		/*
		 * The reference made by 'TclGetSrcInfoForPc' is dead.
		 */
		Tcl_DecrRefCount(ctxPtr->data.eval.path);
	    }
	} else {
	    envPtr->line = ctxPtr->line[word];
	    envPtr->extCmdMapPtr->type = ctxPtr->type;

	    if (ctxPtr->type == TCL_LOCATION_SOURCE) {
		envPtr->extCmdMapPtr->path = ctxPtr->data.eval.path;

		if (pc) {
		    /*
		     * The reference 'TclGetSrcInfoForPc' made is transfered.
		     */

		    ctxPtr->data.eval.path = NULL;
		} else {
		    /*
		     * We have a new reference here.
		     */

		    Tcl_IncrRefCount(ctxPtr->data.eval.path);
		}
	    }
	}

	TclStackFree(interp, ctxPtr);
    }

    envPtr->extCmdMapPtr->start = envPtr->line;

    /*
     * Initialize the data about invisible continuation lines as empty,
     * i.e. not used. The caller (TclSetByteCodeFromAny) will set this up, if
     * such data is available.
     */

    envPtr->clLoc  = NULL;
    envPtr->clNext = NULL;

    envPtr->auxDataArrayPtr = envPtr->staticAuxDataArraySpace;
    envPtr->auxDataArrayNext = 0;
    envPtr->auxDataArrayEnd = COMPILEENV_INIT_AUX_DATA_SIZE;
    envPtr->mallocedAuxDataArray = 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFreeCompileEnv --
 *
 *	Free the storage allocated in a CompileEnv compilation environment
 *	structure.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Allocated storage in the CompileEnv structure is freed. Note that its
 *	local literal table is not deleted and its literal objects are not
 *	released. In addition, storage referenced by its auxiliary data items
 *	is not freed. This is done so that, when compilation is successful,
 *	"ownership" of these objects and aux data items is handed over to the
 *	corresponding ByteCode structure.
 *
 *----------------------------------------------------------------------
 */

void
TclFreeCompileEnv(
    register CompileEnv *envPtr)/* Points to the CompileEnv structure. */
{
    if (envPtr->localLitTable.buckets != envPtr->localLitTable.staticBuckets) {
	ckfree((char *) envPtr->localLitTable.buckets);
	envPtr->localLitTable.buckets = envPtr->localLitTable.staticBuckets;
    }
    if (envPtr->iPtr) {
	/* 
	 * We never converted to Bytecode, so free the things we would
	 * have transferred to it.
	 */

	int i;
	LiteralEntry *entryPtr = envPtr->literalArrayPtr;
	AuxData *auxDataPtr = envPtr->auxDataArrayPtr;

	for (i = 0;  i < envPtr->literalArrayNext;  i++) {
	    TclReleaseLiteral((Tcl_Interp *)envPtr->iPtr, entryPtr->objPtr);
	    entryPtr++;
	}

#ifdef TCL_COMPILE_DEBUG
	TclVerifyGlobalLiteralTable(envPtr->iPtr);
#endif /*TCL_COMPILE_DEBUG*/

	for (i = 0;  i < envPtr->auxDataArrayNext;  i++) {
	    if (auxDataPtr->type->freeProc != NULL) {
		auxDataPtr->type->freeProc(auxDataPtr->clientData);
	    }
	    auxDataPtr++;
	}
    }
    if (envPtr->mallocedCodeArray) {
	ckfree((char *) envPtr->codeStart);
    }
    if (envPtr->mallocedLiteralArray) {
	ckfree((char *) envPtr->literalArrayPtr);
    }
    if (envPtr->mallocedExceptArray) {
	ckfree((char *) envPtr->exceptArrayPtr);
    }
    if (envPtr->mallocedCmdMap) {
	ckfree((char *) envPtr->cmdMapPtr);
    }
    if (envPtr->mallocedAuxDataArray) {
	ckfree((char *) envPtr->auxDataArrayPtr);
    }
    if (envPtr->extCmdMapPtr) {
	ReleaseCmdWordData(envPtr->extCmdMapPtr);
	envPtr->extCmdMapPtr = NULL;
    }

    /*
     * If we used data about invisible continuation lines, then now is the
     * time to release on our hold on it. The lock was set in function
     * TclSetByteCodeFromAny(), found in this file.
     */

    if (envPtr->clLoc) {
	Tcl_Release (envPtr->clLoc);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclWordKnownAtCompileTime --
 *
 *	Test whether the value of a token is completely known at compile time.
 *
 * Results:
 *	Returns true if the tokenPtr argument points to a word value that is
 *	completely known at compile time. Generally, values that are known at
 *	compile time can be compiled to their values, while values that cannot
 *	be known until substitution at runtime must be compiled to bytecode
 *	instructions that perform that substitution. For several commands,
 *	whether or not arguments are known at compile time determine whether
 *	it is worthwhile to compile at all.
 *
 * Side effects:
 *	When returning true, appends the known value of the word to the
 *	unshared Tcl_Obj (*valuePtr), unless valuePtr is NULL.
 *
 *----------------------------------------------------------------------
 */

int
TclWordKnownAtCompileTime(
    Tcl_Token *tokenPtr,	/* Points to Tcl_Token we should check */
    Tcl_Obj *valuePtr)		/* If not NULL, points to an unshared Tcl_Obj
				 * to which we should append the known value
				 * of the word. */
{
    int numComponents = tokenPtr->numComponents;
    Tcl_Obj *tempPtr = NULL;

    if (tokenPtr->type == TCL_TOKEN_SIMPLE_WORD) {
	if (valuePtr != NULL) {
	    Tcl_AppendToObj(valuePtr, tokenPtr[1].start, tokenPtr[1].size);
	}
	return 1;
    }
    if (tokenPtr->type != TCL_TOKEN_WORD) {
	return 0;
    }
    tokenPtr++;
    if (valuePtr != NULL) {
	tempPtr = Tcl_NewObj();
	Tcl_IncrRefCount(tempPtr);
    }
    while (numComponents--) {
	switch (tokenPtr->type) {
	case TCL_TOKEN_TEXT:
	    if (tempPtr != NULL) {
		Tcl_AppendToObj(tempPtr, tokenPtr->start, tokenPtr->size);
	    }
	    break;

	case TCL_TOKEN_BS:
	    if (tempPtr != NULL) {
		char utfBuf[TCL_UTF_MAX];
		int length = TclParseBackslash(tokenPtr->start,
			tokenPtr->size, NULL, utfBuf);
		Tcl_AppendToObj(tempPtr, utfBuf, length);
	    }
	    break;

	default:
	    if (tempPtr != NULL) {
		Tcl_DecrRefCount(tempPtr);
	    }
	    return 0;
	}
	tokenPtr++;
    }
    if (valuePtr != NULL) {
	Tcl_AppendObjToObj(valuePtr, tempPtr);
	Tcl_DecrRefCount(tempPtr);
    }
    return 1;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileScript --
 *
 *	Compile a Tcl script in a string.
 *
 * Results:
 *	The return value is TCL_OK on a successful compilation and TCL_ERROR
 *	on failure. If TCL_ERROR is returned, then the interpreter's result
 *	contains an error message.
 *
 * Side effects:
 *	Adds instructions to envPtr to evaluate the script at runtime.
 *
 *----------------------------------------------------------------------
 */

void
TclCompileScript(
    Tcl_Interp *interp,		/* Used for error and status reporting. Also
				 * serves as context for finding and compiling
				 * commands. May not be NULL. */
    const char *script,		/* The source script to compile. */
    int numBytes,		/* Number of bytes in script. If < 0, the
				 * script consists of all bytes up to the
				 * first null character. */
    CompileEnv *envPtr)		/* Holds resulting instructions. */
{
    Interp *iPtr = (Interp *) interp;
    int lastTopLevelCmdIndex = -1;
    				/* Index of most recent toplevel command in
 				 * the command location table. Initialized to
 				 * avoid compiler warning. */
    int startCodeOffset = -1;	/* Offset of first byte of current command's
				 * code. Init. to avoid compiler warning. */
    unsigned char *entryCodeNext = envPtr->codeNext;
    const char *p, *next;
    Namespace *cmdNsPtr;
    Command *cmdPtr;
    Tcl_Token *tokenPtr;
    int bytesLeft, isFirstCmd, wordIdx, currCmdIndex;
    int commandLength, objIndex;
    Tcl_DString ds;
    /* TIP #280 */
    ExtCmdLoc *eclPtr = envPtr->extCmdMapPtr;
    int *wlines, wlineat, cmdLine;
    int* clNext;
    Tcl_Parse *parsePtr = (Tcl_Parse *)
	    TclStackAlloc(interp, sizeof(Tcl_Parse));

    if (envPtr->iPtr == NULL) {
	Tcl_Panic("TclCompileScript() called on uninitialized CompileEnv");
    }

    Tcl_DStringInit(&ds);

    if (numBytes < 0) {
	numBytes = strlen(script);
    }
    Tcl_ResetResult(interp);
    isFirstCmd = 1;

    if (envPtr->procPtr != NULL) {
	cmdNsPtr = envPtr->procPtr->cmdPtr->nsPtr;
    } else {
	cmdNsPtr = NULL;	/* use current NS */
    }

    /*
     * Each iteration through the following loop compiles the next command
     * from the script.
     */

    p = script;
    bytesLeft = numBytes;
    cmdLine = envPtr->line;
    clNext = envPtr->clNext;
    do {
	if (Tcl_ParseCommand(interp, p, bytesLeft, 0, parsePtr) != TCL_OK) {
	    /*
	     * Compile bytecodes to report the parse error at runtime.
	     */

	    Tcl_LogCommandInfo(interp, script, parsePtr->commandStart,
		    /* Drop the command terminator (";","]") if appropriate */
		    (parsePtr->term ==
		    parsePtr->commandStart + parsePtr->commandSize - 1)?
		    parsePtr->commandSize - 1 : parsePtr->commandSize);
	    TclCompileSyntaxError(interp, envPtr);
	    break;
	}
	if (parsePtr->numWords > 0) {
	    int expand = 0;	/* Set if there are dynamic expansions to
				 * handle */

	    /*
	     * If not the first command, pop the previous command's result
	     * and, if we're compiling a top level command, update the last
	     * command's code size to account for the pop instruction.
	     */

	    if (!isFirstCmd) {
		TclEmitOpcode(INST_POP, envPtr);
		envPtr->cmdMapPtr[lastTopLevelCmdIndex].numCodeBytes =
			(envPtr->codeNext - envPtr->codeStart)
			- startCodeOffset;
	    }

	    /*
	     * Determine the actual length of the command.
	     */

	    commandLength = parsePtr->commandSize;
	    if (parsePtr->term == parsePtr->commandStart + commandLength - 1) {
		/*
		 * The command terminator character (such as ; or ]) is the
		 * last character in the parsed command. Reduce the length by
		 * one so that the trace message doesn't include the
		 * terminator character.
		 */

		commandLength -= 1;
	    }

#ifdef TCL_COMPILE_DEBUG
	    /*
	     * If tracing, print a line for each top level command compiled.
	     */

	    if ((tclTraceCompile >= 1) && (envPtr->procPtr == NULL)) {
		fprintf(stdout, "  Compiling: ");
		TclPrintSource(stdout, parsePtr->commandStart,
			TclMin(commandLength, 55));
		fprintf(stdout, "\n");
	    }
#endif

	    /*
	     * Check whether expansion has been requested for any of the
	     * words.
	     */

	    for (wordIdx = 0, tokenPtr = parsePtr->tokenPtr;
		    wordIdx < parsePtr->numWords;
		    wordIdx++, tokenPtr += (tokenPtr->numComponents + 1)) {
		if (tokenPtr->type == TCL_TOKEN_EXPAND_WORD) {
		    expand = 1;
		    break;
		}
	    }

	    envPtr->numCommands++;
	    currCmdIndex = (envPtr->numCommands - 1);
	    lastTopLevelCmdIndex = currCmdIndex;
	    startCodeOffset = (envPtr->codeNext - envPtr->codeStart);
	    EnterCmdStartData(envPtr, currCmdIndex,
		    parsePtr->commandStart - envPtr->source, startCodeOffset);

	    /*
	     * Should only start issuing instructions after the "command has
	     * started" so that the command range is correct in the bytecode.
	     */

	    if (expand) {
		TclEmitOpcode(INST_EXPAND_START, envPtr);
	    }

	    /*
	     * TIP #280. Scan the words and compute the extended location
	     * information. The map first contain full per-word line
	     * information for use by the compiler. This is later replaced by
	     * a reduced form which signals non-literal words, stored in
	     * 'wlines'.
	     */

	    TclAdvanceLines(&cmdLine, p, parsePtr->commandStart);
	    TclAdvanceContinuations (&cmdLine, &clNext,
				     parsePtr->commandStart - envPtr->source);
	    EnterCmdWordData(eclPtr, parsePtr->commandStart - envPtr->source,
			     parsePtr->tokenPtr, parsePtr->commandStart,
			     parsePtr->commandSize, parsePtr->numWords, cmdLine,
			     clNext, &wlines, envPtr);
	    wlineat = eclPtr->nuloc - 1;

	    /*
	     * Each iteration of the following loop compiles one word from the
	     * command.
	     */

	    for (wordIdx = 0, tokenPtr = parsePtr->tokenPtr;
		    wordIdx < parsePtr->numWords; wordIdx++,
		    tokenPtr += (tokenPtr->numComponents + 1)) {

		envPtr->line = eclPtr->loc[wlineat].line[wordIdx];
		envPtr->clNext = eclPtr->loc [wlineat].next [wordIdx];

		if (tokenPtr->type != TCL_TOKEN_SIMPLE_WORD) {
		    /*
		     * The word is not a simple string of characters.
		     */

		    TclCompileTokens(interp, tokenPtr+1,
			    tokenPtr->numComponents, envPtr);
		    if (tokenPtr->type == TCL_TOKEN_EXPAND_WORD) {
			TclEmitInstInt4(INST_EXPAND_STKTOP,
				envPtr->currStackDepth, envPtr);
		    }
		    continue;
		}

		/*
		 * This is a simple string of literal characters (i.e. we know
		 * it absolutely and can use it directly). If this is the
		 * first word and the command has a compile procedure, let it
		 * compile the command.
		 */

		if ((wordIdx == 0) && !expand) {
		    /*
		     * We copy the string before trying to find the command by
		     * name. We used to modify the string in place, but this
		     * is not safe because the name resolution handlers could
		     * have side effects that rely on the unmodified string.
		     */

		    Tcl_DStringSetLength(&ds, 0);
		    Tcl_DStringAppend(&ds, tokenPtr[1].start,tokenPtr[1].size);

		    cmdPtr = (Command *) Tcl_FindCommand(interp,
			    Tcl_DStringValue(&ds),
			    (Tcl_Namespace *) cmdNsPtr, /*flags*/ 0);

		    if ((cmdPtr != NULL)
			    && (cmdPtr->compileProc != NULL)
			    && !(cmdPtr->flags & CMD_HAS_EXEC_TRACES)
			    && !(iPtr->flags & DONT_COMPILE_CMDS_INLINE)) {
			int savedNumCmds = envPtr->numCommands;
			unsigned savedCodeNext =
				envPtr->codeNext - envPtr->codeStart;
			int update = 0, code;

			/*
			 * Mark the start of the command; the proper bytecode
			 * length will be updated later. There is no need to
			 * do this for the first bytecode in the compile env,
			 * as the check is done before calling
			 * TclExecuteByteCode(). Do emit an INST_START_CMD in
			 * special cases where the first bytecode is in a
			 * loop, to insure that the corresponding command is
			 * counted properly. Compilers for commands able to
			 * produce such a beast (currently 'while 1' only) set
			 * envPtr->atCmdStart to 0 in order to signal this
			 * case. [Bug 1752146]
			 *
			 * Note that the environment is initialised with
			 * atCmdStart=1 to avoid emitting ISC for the first
			 * command.
			 */

			if (envPtr->atCmdStart) {
			    if (savedCodeNext != 0) {
				/*
				 * Increase the number of commands being
				 * started at the current point. Note that
				 * this depends on the exact layout of the
				 * INST_START_CMD's operands, so be careful!
				 */

				unsigned char *fixPtr = envPtr->codeNext - 4;

				TclStoreInt4AtPtr(TclGetUInt4AtPtr(fixPtr)+1,
					fixPtr);
			    }
			} else {
			    TclEmitInstInt4(INST_START_CMD, 0, envPtr);
			    TclEmitInt4(1, envPtr);
			    update = 1;
			}

			code = (cmdPtr->compileProc)(interp, parsePtr,
				cmdPtr, envPtr);

			if (code == TCL_OK) {
			    if (update) {
				/*
				 * Fix the bytecode length.
				 */

				unsigned char *fixPtr = envPtr->codeStart
					+ savedCodeNext + 1;
				unsigned fixLen = envPtr->codeNext
					- envPtr->codeStart - savedCodeNext;

				TclStoreInt4AtPtr(fixLen, fixPtr);
			    }
			    goto finishCommand;
			} else {
			    if (envPtr->atCmdStart && savedCodeNext != 0) {
				/*
				 * Decrease the number of commands being
				 * started at the current point. Note that
				 * this depends on the exact layout of the
				 * INST_START_CMD's operands, so be careful!
				 */

				unsigned char *fixPtr = envPtr->codeNext - 4;

				TclStoreInt4AtPtr(TclGetUInt4AtPtr(fixPtr)-1,
					fixPtr);
			    }

			    /*
			     * Restore numCommands and codeNext to their
			     * correct values, removing any commands compiled
			     * before the failure to produce bytecode got
			     * reported. [Bugs 705406 and 735055]
			     */

			    envPtr->numCommands = savedNumCmds;
			    envPtr->codeNext = envPtr->codeStart+savedCodeNext;
			}
		    }

		    /*
		     * No compile procedure so push the word. If the command
		     * was found, push a CmdName object to reduce runtime
		     * lookups. Avoid sharing this literal among different
		     * namespaces to reduce shimmering.
		     */

		    objIndex = TclRegisterNewNSLiteral(envPtr,
			    tokenPtr[1].start, tokenPtr[1].size);
		    if (cmdPtr != NULL) {
			TclSetCmdNameObj(interp,
			      envPtr->literalArrayPtr[objIndex].objPtr,cmdPtr);
		    }
		    if ((wordIdx == 0) && (parsePtr->numWords == 1)) {
			/*
			 * Single word script: unshare the command name to
			 * avoid shimmering between bytecode and cmdName
			 * representations [Bug 458361]
			 */

			TclHideLiteral(interp, envPtr, objIndex);
		    }
		} else {
		    /*
		     * Simple argument word of a command. We reach this if and
		     * only if the command word was not compiled for whatever
		     * reason. Register the literal's location for use by
		     * uplevel, etc. commands, should they encounter it
		     * unmodified. We care only if the we are in a context
		     * which already allows absolute counting.
		     */
		    objIndex = TclRegisterNewLiteral(envPtr,
			    tokenPtr[1].start, tokenPtr[1].size);

		    if (envPtr->clNext) {
			TclContinuationsEnterDerived (envPtr->literalArrayPtr[objIndex].objPtr,
						      tokenPtr[1].start - envPtr->source,
						      eclPtr->loc [wlineat].next [wordIdx]);
		    }
		}
		TclEmitPush(objIndex, envPtr);
	    } /* for loop */

	    /*
	     * Emit an invoke instruction for the command. We skip this if a
	     * compile procedure was found for the command.
	     */

	    if (expand) {
		/*
		 * The stack depth during argument expansion can only be
		 * managed at runtime, as the number of elements in the
		 * expanded lists is not known at compile time. We adjust here
		 * the stack depth estimate so that it is correct after the
		 * command with expanded arguments returns.
		 *
		 * The end effect of this command's invocation is that all the
		 * words of the command are popped from the stack, and the
		 * result is pushed: the stack top changes by (1-wordIdx).
		 *
		 * Note that the estimates are not correct while the command
		 * is being prepared and run, INST_EXPAND_STKTOP is not
		 * stack-neutral in general.
		 */

		TclEmitOpcode(INST_INVOKE_EXPANDED, envPtr);
		TclAdjustStackDepth((1-wordIdx), envPtr);
	    } else if (wordIdx > 0) {
		/*
		 * Save PC -> command map for the TclArgumentBC* functions.
		 */

		int isnew;
		Tcl_HashEntry* hePtr = Tcl_CreateHashEntry(&eclPtr->litInfo,
			   (char*) (envPtr->codeNext - envPtr->codeStart), &isnew);
		Tcl_SetHashValue(hePtr, INT2PTR(wlineat));

		if (wordIdx <= 255) {
		    TclEmitInstInt1(INST_INVOKE_STK1, wordIdx, envPtr);
		} else {
		    TclEmitInstInt4(INST_INVOKE_STK4, wordIdx, envPtr);
		}
	    }

	    /*
	     * Update the compilation environment structure and record the
	     * offsets of the source and code for the command.
	     */

	finishCommand:
	    EnterCmdExtentData(envPtr, currCmdIndex, commandLength,
		    (envPtr->codeNext-envPtr->codeStart) - startCodeOffset);
	    isFirstCmd = 0;

	    /*
	     * TIP #280: Free full form of per-word line data and insert the
	     * reduced form now
	     */

	    ckfree((char *) eclPtr->loc[wlineat].line);
	    ckfree((char *) eclPtr->loc[wlineat].next);
	    eclPtr->loc[wlineat].line = wlines;
	    eclPtr->loc[wlineat].next = NULL;
	} /* end if parsePtr->numWords > 0 */

	/*
	 * Advance to the next command in the script.
	 */

	next = parsePtr->commandStart + parsePtr->commandSize;
	bytesLeft -= next - p;
	p = next;

	/*
	 * TIP #280: Track lines in the just compiled command.
	 */

	TclAdvanceLines(&cmdLine, parsePtr->commandStart, p);
	TclAdvanceContinuations (&cmdLine, &clNext, p - envPtr->source);
	Tcl_FreeParse(parsePtr);
    } while (bytesLeft > 0);

    /*
     * If the source script yielded no instructions (e.g., if it was empty),
     * push an empty string as the command's result.
     *
     * WARNING: push an unshared object! If the script being compiled is a
     * shared empty string, it will otherwise be self-referential and cause
     * difficulties with literal management [Bugs 467523, 983660]. We used to
     * have special code in TclReleaseLiteral to handle this particular
     * self-reference, but now opt for avoiding its creation altogether.
     */

    if (envPtr->codeNext == entryCodeNext) {
	TclEmitPush(TclAddLiteralObj(envPtr, Tcl_NewObj(), NULL), envPtr);
    }

    TclStackFree(interp, parsePtr);
    Tcl_DStringFree(&ds);
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileTokens --
 *
 *	Given an array of tokens parsed from a Tcl command (e.g., the tokens
 *	that make up a word) this procedure emits instructions to evaluate the
 *	tokens and concatenate their values to form a single result value on
 *	the interpreter's runtime evaluation stack.
 *
 * Results:
 *	The return value is a standard Tcl result. If an error occurs, an
 *	error message is left in the interpreter's result.
 *
 * Side effects:
 *	Instructions are added to envPtr to push and evaluate the tokens at
 *	runtime.
 *
 *----------------------------------------------------------------------
 */

void
TclCompileTokens(
    Tcl_Interp *interp,		/* Used for error and status reporting. */
    Tcl_Token *tokenPtr,	/* Pointer to first in an array of tokens to
				 * compile. */
    int count,			/* Number of tokens to consider at tokenPtr.
				 * Must be at least 1. */
    CompileEnv *envPtr)		/* Holds the resulting instructions. */
{
    Tcl_DString textBuffer;	/* Holds concatenated chars from adjacent
				 * TCL_TOKEN_TEXT, TCL_TOKEN_BS tokens. */
    char buffer[TCL_UTF_MAX];
    const char *name, *p;
    int numObjsToConcat, nameBytes, localVarName, localVar;
    int length, i;
    unsigned char *entryCodeNext = envPtr->codeNext;
#define NUM_STATIC_POS 20
    int isLiteral, maxNumCL, numCL;
    int* clPosition = NULL;

    /*
     * For the handling of continuation lines in literals we first check if
     * this is actually a literal. For if not we can forego the additional
     * processing. Otherwise we pre-allocate a small table to store the
     * locations of all continuation lines we find in this literal, if
     * any. The table is extended if needed.
     *
     * Note: Different to the equivalent code in function
     * 'TclSubstTokens()' (see file "tclParse.c") we do not seem to need
     * the 'adjust' variable. We also do not seem to need code which merges
     * continuation line information of multiple words which concat'd at
     * runtime. Either that or I have not managed to find a test case for
     * these two possibilities yet. It might be a difference between compile-
     * versus runtime processing.
     */

    numCL     = 0;
    maxNumCL  = 0;
    isLiteral = 1;
    for (i=0 ; i < count; i++) {
	if ((tokenPtr[i].type != TCL_TOKEN_TEXT) &&
	    (tokenPtr[i].type != TCL_TOKEN_BS)) {
	    isLiteral = 0;
	    break;
	}
    }

    if (isLiteral) {
	maxNumCL   = NUM_STATIC_POS;
	clPosition = (int*) ckalloc (maxNumCL*sizeof(int));
    }

    Tcl_DStringInit(&textBuffer);
    numObjsToConcat = 0;
    for ( ;  count > 0;  count--, tokenPtr++) {
	switch (tokenPtr->type) {
	case TCL_TOKEN_TEXT:
	    Tcl_DStringAppend(&textBuffer, tokenPtr->start, tokenPtr->size);
	    break;

	case TCL_TOKEN_BS:
	    length = TclParseBackslash(tokenPtr->start, tokenPtr->size,
		    NULL, buffer);
	    Tcl_DStringAppend(&textBuffer, buffer, length);

	    /*
	     * If the backslash sequence we found is in a literal, and
	     * represented a continuation line, we compute and store its
	     * location (as char offset to the beginning of the _result_
	     * script). We may have to extend the table of locations.
	     *
	     * Note that the continuation line information is relevant even if
	     * the word we are processing is not a literal, as it can affect
	     * nested commands. See the branch for TCL_TOKEN_COMMAND below,
	     * where the adjustment we are tracking here is taken into
	     * account. The good thing is that we do not need a table of
	     * everything, just the number of lines we have to add as
	     * correction.
	     */

	    if ((length == 1) && (buffer[0] == ' ') &&
		(tokenPtr->start[1] == '\n')) {
		if (isLiteral) {
		    int clPos = Tcl_DStringLength (&textBuffer);

		    if (numCL >= maxNumCL) {
			maxNumCL *= 2;
			clPosition = (int*) ckrealloc ((char*)clPosition,
						       maxNumCL*sizeof(int));
		    }
		    clPosition[numCL] = clPos;
		    numCL ++;
		}
	    }
	    break;

	case TCL_TOKEN_COMMAND:
	    /*
	     * Push any accumulated chars appearing before the command.
	     */

	    if (Tcl_DStringLength(&textBuffer) > 0) {
		int literal = TclRegisterNewLiteral(envPtr,
			Tcl_DStringValue(&textBuffer),
			Tcl_DStringLength(&textBuffer));

		TclEmitPush(literal, envPtr);
		numObjsToConcat++;
		Tcl_DStringFree(&textBuffer);

		if (numCL) {
		    TclContinuationsEnter(envPtr->literalArrayPtr[literal].objPtr,
					  numCL, clPosition);
		}
		numCL = 0;
	    }

	    TclCompileScript(interp, tokenPtr->start+1,
		    tokenPtr->size-2, envPtr);
	    numObjsToConcat++;
	    break;

	case TCL_TOKEN_VARIABLE:
	    /*
	     * Push any accumulated chars appearing before the $<var>.
	     */

	    if (Tcl_DStringLength(&textBuffer) > 0) {
		int literal;

		literal = TclRegisterNewLiteral(envPtr,
			Tcl_DStringValue(&textBuffer),
			Tcl_DStringLength(&textBuffer));
		TclEmitPush(literal, envPtr);
		numObjsToConcat++;
		Tcl_DStringFree(&textBuffer);
	    }

	    /*
	     * Determine how the variable name should be handled: if it
	     * contains any namespace qualifiers it is not a local variable
	     * (localVarName=-1); if it looks like an array element and the
	     * token has a single component, it should not be created here
	     * [Bug 569438] (localVarName=0); otherwise, the local variable
	     * can safely be created (localVarName=1).
	     */

	    name = tokenPtr[1].start;
	    nameBytes = tokenPtr[1].size;
	    localVarName = -1;
	    if (envPtr->procPtr != NULL) {
		localVarName = 1;
		for (i = 0, p = name;  i < nameBytes;  i++, p++) {
		    if ((*p == ':') && (i < nameBytes-1) && (*(p+1) == ':')) {
			localVarName = -1;
			break;
		    } else if ((*p == '(')
			    && (tokenPtr->numComponents == 1)
			    && (*(name + nameBytes - 1) == ')')) {
			localVarName = 0;
			break;
		    }
		}
	    }

	    /*
	     * Either push the variable's name, or find its index in the array
	     * of local variables in a procedure frame.
	     */

	    localVar = -1;
	    if (localVarName != -1) {
		localVar = TclFindCompiledLocal(name, nameBytes, localVarName,
			envPtr->procPtr);
	    }
	    if (localVar < 0) {
		TclEmitPush(TclRegisterNewLiteral(envPtr, name, nameBytes),
			envPtr);
	    }

	    /*
	     * Emit instructions to load the variable.
	     */

	    if (tokenPtr->numComponents == 1) {
		if (localVar < 0) {
		    TclEmitOpcode(INST_LOAD_SCALAR_STK, envPtr);
		} else if (localVar <= 255) {
		    TclEmitInstInt1(INST_LOAD_SCALAR1, localVar, envPtr);
		} else {
		    TclEmitInstInt4(INST_LOAD_SCALAR4, localVar, envPtr);
		}
	    } else {
		TclCompileTokens(interp, tokenPtr+2,
			tokenPtr->numComponents-1, envPtr);
		if (localVar < 0) {
		    TclEmitOpcode(INST_LOAD_ARRAY_STK, envPtr);
		} else if (localVar <= 255) {
		    TclEmitInstInt1(INST_LOAD_ARRAY1, localVar, envPtr);
		} else {
		    TclEmitInstInt4(INST_LOAD_ARRAY4, localVar, envPtr);
		}
	    }
	    numObjsToConcat++;
	    count -= tokenPtr->numComponents;
	    tokenPtr += tokenPtr->numComponents;
	    break;

	default:
	    Tcl_Panic("Unexpected token type in TclCompileTokens: %d; %.*s",
		    tokenPtr->type, tokenPtr->size, tokenPtr->start);
	}
    }

    /*
     * Push any accumulated characters appearing at the end.
     */

    if (Tcl_DStringLength(&textBuffer) > 0) {
	int literal;

	literal = TclRegisterNewLiteral(envPtr, Tcl_DStringValue(&textBuffer),
		Tcl_DStringLength(&textBuffer));
	TclEmitPush(literal, envPtr);
	numObjsToConcat++;

	if (numCL) {
	    TclContinuationsEnter(envPtr->literalArrayPtr[literal].objPtr,
				  numCL, clPosition);
	}
	numCL = 0;
    }

    /*
     * If necessary, concatenate the parts of the word.
     */

    while (numObjsToConcat > 255) {
	TclEmitInstInt1(INST_CONCAT1, 255, envPtr);
	numObjsToConcat -= 254;	/* concat pushes 1 obj, the result */
    }
    if (numObjsToConcat > 1) {
	TclEmitInstInt1(INST_CONCAT1, numObjsToConcat, envPtr);
    }

    /*
     * If the tokens yielded no instructions, push an empty string.
     */

    if (envPtr->codeNext == entryCodeNext) {
	TclEmitPush(TclRegisterNewLiteral(envPtr, "", 0), envPtr);
    }
    Tcl_DStringFree(&textBuffer);

    /*
     * Release the temp table we used to collect the locations of
     * continuation lines, if any.
     */

    if (maxNumCL) {
	ckfree ((char*) clPosition);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileCmdWord --
 *
 *	Given an array of parse tokens for a word containing one or more Tcl
 *	commands, emit inline instructions to execute them. This procedure
 *	differs from TclCompileTokens in that a simple word such as a loop
 *	body enclosed in braces is not just pushed as a string, but is itself
 *	parsed into tokens and compiled.
 *
 * Results:
 *	The return value is a standard Tcl result. If an error occurs, an
 *	error message is left in the interpreter's result.
 *
 * Side effects:
 *	Instructions are added to envPtr to execute the tokens at runtime.
 *
 *----------------------------------------------------------------------
 */

void
TclCompileCmdWord(
    Tcl_Interp *interp,		/* Used for error and status reporting. */
    Tcl_Token *tokenPtr,	/* Pointer to first in an array of tokens for
				 * a command word to compile inline. */
    int count,			/* Number of tokens to consider at tokenPtr.
				 * Must be at least 1. */
    CompileEnv *envPtr)		/* Holds the resulting instructions. */
{
    if ((count == 1) && (tokenPtr->type == TCL_TOKEN_TEXT)) {
	/*
	 * Handle the common case: if there is a single text token, compile it
	 * into an inline sequence of instructions.
	 */

	TclCompileScript(interp, tokenPtr->start, tokenPtr->size, envPtr);
    } else {
	/*
	 * Multiple tokens or the single token involves substitutions. Emit
	 * instructions to invoke the eval command procedure at runtime on the
	 * result of evaluating the tokens.
	 */

	TclCompileTokens(interp, tokenPtr, count, envPtr);
	TclEmitOpcode(INST_EVAL_STK, envPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileExprWords --
 *
 *	Given an array of parse tokens representing one or more words that
 *	contain a Tcl expression, emit inline instructions to execute the
 *	expression. This procedure differs from TclCompileExpr in that it
 *	supports Tcl's two-level substitution semantics for expressions that
 *	appear as command words.
 *
 * Results:
 *	The return value is a standard Tcl result. If an error occurs, an
 *	error message is left in the interpreter's result.
 *
 * Side effects:
 *	Instructions are added to envPtr to execute the expression.
 *
 *----------------------------------------------------------------------
 */

void
TclCompileExprWords(
    Tcl_Interp *interp,		/* Used for error and status reporting. */
    Tcl_Token *tokenPtr,	/* Points to first in an array of word tokens
				 * tokens for the expression to compile
				 * inline. */
    int numWords,		/* Number of word tokens starting at tokenPtr.
				 * Must be at least 1. Each word token
				 * contains one or more subtokens. */
    CompileEnv *envPtr)		/* Holds the resulting instructions. */
{
    Tcl_Token *wordPtr;
    int i, concatItems;

    /*
     * If the expression is a single word that doesn't require substitutions,
     * just compile its string into inline instructions.
     */

    if ((numWords == 1) && (tokenPtr->type == TCL_TOKEN_SIMPLE_WORD)) {
	TclCompileExpr(interp, tokenPtr[1].start, tokenPtr[1].size, envPtr, 1);
	return;
    }

    /*
     * Emit code to call the expr command proc at runtime. Concatenate the
     * (already substituted once) expr tokens with a space between each.
     */

    wordPtr = tokenPtr;
    for (i = 0;  i < numWords;  i++) {
	TclCompileTokens(interp, wordPtr+1, wordPtr->numComponents, envPtr);
	if (i < (numWords - 1)) {
	    TclEmitPush(TclRegisterNewLiteral(envPtr, " ", 1), envPtr);
	}
	wordPtr += (wordPtr->numComponents + 1);
    }
    concatItems = 2*numWords - 1;
    while (concatItems > 255) {
	TclEmitInstInt1(INST_CONCAT1, 255, envPtr);
	concatItems -= 254;
    }
    if (concatItems > 1) {
	TclEmitInstInt1(INST_CONCAT1, concatItems, envPtr);
    }
    TclEmitOpcode(INST_EXPR_STK, envPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclCompileNoOp --
 *
 *	Function called to compile no-op's
 *
 * Results:
 *	The return value is TCL_OK, indicating successful compilation.
 *
 * Side effects:
 *	Instructions are added to envPtr to execute a no-op at runtime. No
 *      result is pushed onto the stack: the compiler has to take care of this
 *      itself if the last compiled command is a NoOp.
 *
 *----------------------------------------------------------------------
 */

int
TclCompileNoOp(
    Tcl_Interp *interp,		/* Used for error reporting. */
    Tcl_Parse *parsePtr,	/* Points to a parse structure for the command
				 * created by Tcl_ParseCommand. */
    Command *cmdPtr,		/* Points to defintion of command being
				 * compiled. */
    CompileEnv *envPtr)		/* Holds resulting instructions. */
{
    Tcl_Token *tokenPtr;
    int i;
    int savedStackDepth = envPtr->currStackDepth;

    tokenPtr = parsePtr->tokenPtr;
    for(i = 1; i < parsePtr->numWords; i++) {
	tokenPtr = tokenPtr + tokenPtr->numComponents + 1;
	envPtr->currStackDepth = savedStackDepth;

	if (tokenPtr->type != TCL_TOKEN_SIMPLE_WORD) {
	    TclCompileTokens(interp, tokenPtr+1, tokenPtr->numComponents,
		    envPtr);
	    TclEmitOpcode(INST_POP, envPtr);
	}
    }
    envPtr->currStackDepth = savedStackDepth;
    TclEmitPush(TclRegisterNewLiteral(envPtr, "", 0), envPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitByteCodeObj --
 *
 *	Create a ByteCode structure and initialize it from a CompileEnv
 *	compilation environment structure. The ByteCode structure is smaller
 *	and contains just that information needed to execute the bytecode
 *	instructions resulting from compiling a Tcl script. The resulting
 *	structure is placed in the specified object.
 *
 * Results:
 *	A newly constructed ByteCode object is stored in the internal
 *	representation of the objPtr.
 *
 * Side effects:
 *	A single heap object is allocated to hold the new ByteCode structure
 *	and its code, object, command location, and aux data arrays. Note that
 *	"ownership" (i.e., the pointers to) the Tcl objects and aux data items
 *	will be handed over to the new ByteCode structure from the CompileEnv
 *	structure.
 *
 *----------------------------------------------------------------------
 */

void
TclInitByteCodeObj(
    Tcl_Obj *objPtr,		/* Points object that should be initialized,
				 * and whose string rep contains the source
				 * code. */
    register CompileEnv *envPtr)/* Points to the CompileEnv structure from
				 * which to create a ByteCode structure. */
{
    register ByteCode *codePtr;
    size_t codeBytes, objArrayBytes, exceptArrayBytes, cmdLocBytes;
    size_t auxDataArrayBytes, structureSize;
    register unsigned char *p;
#ifdef TCL_COMPILE_DEBUG
    unsigned char *nextPtr;
#endif
    int numLitObjects = envPtr->literalArrayNext;
    Namespace *namespacePtr;
    int i, isNew;
    Interp *iPtr;

    if (envPtr->iPtr == NULL) {
	Tcl_Panic("TclInitByteCodeObj() called on uninitialized CompileEnv");
    }

    iPtr = envPtr->iPtr;

    codeBytes = (envPtr->codeNext - envPtr->codeStart);
    objArrayBytes = (envPtr->literalArrayNext * sizeof(Tcl_Obj *));
    exceptArrayBytes = (envPtr->exceptArrayNext * sizeof(ExceptionRange));
    auxDataArrayBytes = (envPtr->auxDataArrayNext * sizeof(AuxData));
    cmdLocBytes = GetCmdLocEncodingSize(envPtr);

    /*
     * Compute the total number of bytes needed for this bytecode.
     */

    structureSize = sizeof(ByteCode);
    structureSize += TCL_ALIGN(codeBytes);	  /* align object array */
    structureSize += TCL_ALIGN(objArrayBytes);	  /* align exc range arr */
    structureSize += TCL_ALIGN(exceptArrayBytes); /* align AuxData array */
    structureSize += auxDataArrayBytes;
    structureSize += cmdLocBytes;

    if (envPtr->iPtr->varFramePtr != NULL) {
	namespacePtr = envPtr->iPtr->varFramePtr->nsPtr;
    } else {
	namespacePtr = envPtr->iPtr->globalNsPtr;
    }

    p = (unsigned char *) ckalloc((size_t) structureSize);
    codePtr = (ByteCode *) p;
    codePtr->interpHandle = TclHandlePreserve(iPtr->handle);
    codePtr->compileEpoch = iPtr->compileEpoch;
    codePtr->nsPtr = namespacePtr;
    codePtr->nsEpoch = namespacePtr->resolverEpoch;
    codePtr->refCount = 1;
    if (namespacePtr->compiledVarResProc || iPtr->resolverPtr) {
	codePtr->flags = TCL_BYTECODE_RESOLVE_VARS;
    } else {
	codePtr->flags = 0;
    }
    codePtr->source = envPtr->source;
    codePtr->procPtr = envPtr->procPtr;

    codePtr->numCommands = envPtr->numCommands;
    codePtr->numSrcBytes = envPtr->numSrcBytes;
    codePtr->numCodeBytes = codeBytes;
    codePtr->numLitObjects = numLitObjects;
    codePtr->numExceptRanges = envPtr->exceptArrayNext;
    codePtr->numAuxDataItems = envPtr->auxDataArrayNext;
    codePtr->numCmdLocBytes = cmdLocBytes;
    codePtr->maxExceptDepth = envPtr->maxExceptDepth;
    codePtr->maxStackDepth = envPtr->maxStackDepth;

    p += sizeof(ByteCode);
    codePtr->codeStart = p;
    memcpy(p, envPtr->codeStart, (size_t) codeBytes);

    p += TCL_ALIGN(codeBytes);		/* align object array */
    codePtr->objArrayPtr = (Tcl_Obj **) p;
    for (i = 0;  i < numLitObjects;  i++) {
	codePtr->objArrayPtr[i] = envPtr->literalArrayPtr[i].objPtr;
    }

    p += TCL_ALIGN(objArrayBytes);	/* align exception range array */
    if (exceptArrayBytes > 0) {
	codePtr->exceptArrayPtr = (ExceptionRange *) p;
	memcpy(p, envPtr->exceptArrayPtr, (size_t) exceptArrayBytes);
    } else {
	codePtr->exceptArrayPtr = NULL;
    }

    p += TCL_ALIGN(exceptArrayBytes);	/* align AuxData array */
    if (auxDataArrayBytes > 0) {
	codePtr->auxDataArrayPtr = (AuxData *) p;
	memcpy(p, envPtr->auxDataArrayPtr, (size_t) auxDataArrayBytes);
    } else {
	codePtr->auxDataArrayPtr = NULL;
    }

    p += auxDataArrayBytes;
#ifndef TCL_COMPILE_DEBUG
    EncodeCmdLocMap(envPtr, codePtr, (unsigned char *) p);
#else
    nextPtr = EncodeCmdLocMap(envPtr, codePtr, (unsigned char *) p);
    if (((size_t)(nextPtr - p)) != cmdLocBytes) {
	Tcl_Panic("TclInitByteCodeObj: encoded cmd location bytes %d != expected size %d", (nextPtr - p), cmdLocBytes);
    }
#endif

    /*
     * Record various compilation-related statistics about the new ByteCode
     * structure. Don't include overhead for statistics-related fields.
     */

#ifdef TCL_COMPILE_STATS
    codePtr->structureSize = structureSize
	    - (sizeof(size_t) + sizeof(Tcl_Time));
    Tcl_GetTime(&(codePtr->createTime));

    RecordByteCodeStats(codePtr);
#endif /* TCL_COMPILE_STATS */

    /*
     * Free the old internal rep then convert the object to a bytecode object
     * by making its internal rep point to the just compiled ByteCode.
     */

    TclFreeIntRep(objPtr);
    objPtr->internalRep.twoPtrValue.ptr1 = (void *) codePtr;
    objPtr->typePtr = &tclByteCodeType;

    /*
     * TIP #280. Associate the extended per-word line information with the
     * byte code object (internal rep), for use with the bc compiler.
     */

    Tcl_SetHashValue(Tcl_CreateHashEntry(iPtr->lineBCPtr, (char *) codePtr,
	    &isNew), envPtr->extCmdMapPtr);
    envPtr->extCmdMapPtr = NULL;

    /* We've used up the CompileEnv.  Mark as uninitialized. */
    envPtr->iPtr = NULL;

    codePtr->localCachePtr = NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFindCompiledLocal --
 *
 *	This procedure is called at compile time to look up and optionally
 *	allocate an entry ("slot") for a variable in a procedure's array of
 *	local variables. If the variable's name is NULL, a new temporary
 *	variable is always created. (Such temporary variables can only be
 *	referenced using their slot index.)
 *
 * Results:
 *	If create is 0 and the name is non-NULL, then if the variable is
 *	found, the index of its entry in the procedure's array of local
 *	variables is returned; otherwise -1 is returned. If name is NULL, the
 *	index of a new temporary variable is returned. Finally, if create is 1
 *	and name is non-NULL, the index of a new entry is returned.
 *
 * Side effects:
 *	Creates and registers a new local variable if create is 1 and the
 *	variable is unknown, or if the name is NULL.
 *
 *----------------------------------------------------------------------
 */

int
TclFindCompiledLocal(
    register const char *name,	/* Points to first character of the name of a
				 * scalar or array variable. If NULL, a
				 * temporary var should be created. */
    int nameBytes,		/* Number of bytes in the name. */
    int create,			/* If non-zero, allocate a local frame entry
				 * for the variable if it is new. */
    register Proc *procPtr)	/* Points to structure describing procedure
				 * containing the variable reference. */
{
    register CompiledLocal *localPtr;
    int localVar = -1;
    register int i;

    /*
     * If not creating a temporary, does a local variable of the specified
     * name already exist?
     */

    if (name != NULL) {
	int localCt = procPtr->numCompiledLocals;

	localPtr = procPtr->firstLocalPtr;
	for (i = 0;  i < localCt;  i++) {
	    if (!TclIsVarTemporary(localPtr)) {
		char *localName = localPtr->name;

		if ((nameBytes == localPtr->nameLength) &&
			(strncmp(name,localName,(unsigned)nameBytes) == 0)) {
		    return i;
		}
	    }
	    localPtr = localPtr->nextPtr;
	}
    }

    /*
     * Create a new variable if appropriate.
     */

    if (create || (name == NULL)) {
	localVar = procPtr->numCompiledLocals;
	localPtr = (CompiledLocal *) ckalloc((unsigned)
		(sizeof(CompiledLocal) - sizeof(localPtr->name)
		+ nameBytes + 1));
	if (procPtr->firstLocalPtr == NULL) {
	    procPtr->firstLocalPtr = procPtr->lastLocalPtr = localPtr;
	} else {
	    procPtr->lastLocalPtr->nextPtr = localPtr;
	    procPtr->lastLocalPtr = localPtr;
	}
	localPtr->nextPtr = NULL;
	localPtr->nameLength = nameBytes;
	localPtr->frameIndex = localVar;
	localPtr->flags = 0;
	if (name == NULL) {
	    localPtr->flags |= VAR_TEMPORARY;
	}
	localPtr->defValuePtr = NULL;
	localPtr->resolveInfo = NULL;

	if (name != NULL) {
	    memcpy(localPtr->name, name, (size_t) nameBytes);
	}
	localPtr->name[nameBytes] = '\0';
	procPtr->numCompiledLocals++;
    }
    return localVar;
}

/*
 *----------------------------------------------------------------------
 *
 * TclExpandCodeArray --
 *
 *	Procedure that uses malloc to allocate more storage for a CompileEnv's
 *	code array.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The byte code array in *envPtr is reallocated to a new array of double
 *	the size, and if envPtr->mallocedCodeArray is non-zero the old array
 *	is freed. Byte codes are copied from the old array to the new one.
 *
 *----------------------------------------------------------------------
 */

void
TclExpandCodeArray(
    void *envArgPtr)		/* Points to the CompileEnv whose code array
				 * must be enlarged. */
{
    CompileEnv *envPtr = (CompileEnv *) envArgPtr;
				/* The CompileEnv containing the code array to
				 * be doubled in size. */

    /*
     * envPtr->codeNext is equal to envPtr->codeEnd. The currently defined
     * code bytes are stored between envPtr->codeStart and envPtr->codeNext-1
     * [inclusive].
     */

    size_t currBytes = (envPtr->codeNext - envPtr->codeStart);
    size_t newBytes = 2*(envPtr->codeEnd - envPtr->codeStart);

    if (envPtr->mallocedCodeArray) {
	envPtr->codeStart = (unsigned char *)
		ckrealloc((char *)envPtr->codeStart, newBytes);
    } else {
	/*
	 * envPtr->codeStart isn't a ckalloc'd pointer, so we must
	 * code a ckrealloc equivalent for ourselves.
	 */
	unsigned char *newPtr = (unsigned char *) ckalloc((unsigned) newBytes);
	memcpy(newPtr, envPtr->codeStart, currBytes);
	envPtr->codeStart = newPtr;
	envPtr->mallocedCodeArray = 1;
    }

    envPtr->codeNext = (envPtr->codeStart + currBytes);
    envPtr->codeEnd = (envPtr->codeStart + newBytes);
}

/*
 *----------------------------------------------------------------------
 *
 * EnterCmdStartData --
 *
 *	Registers the starting source and bytecode location of a command. This
 *	information is used at runtime to map between instruction pc and
 *	source locations.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Inserts source and code location information into the compilation
 *	environment envPtr for the command at index cmdIndex. The compilation
 *	environment's CmdLocation array is grown if necessary.
 *
 *----------------------------------------------------------------------
 */

static void
EnterCmdStartData(
    CompileEnv *envPtr,		/* Points to the compilation environment
				 * structure in which to enter command
				 * location information. */
    int cmdIndex,		/* Index of the command whose start data is
				 * being set. */
    int srcOffset,		/* Offset of first char of the command. */
    int codeOffset)		/* Offset of first byte of command code. */
{
    CmdLocation *cmdLocPtr;

    if ((cmdIndex < 0) || (cmdIndex >= envPtr->numCommands)) {
	Tcl_Panic("EnterCmdStartData: bad command index %d", cmdIndex);
    }

    if (cmdIndex >= envPtr->cmdMapEnd) {
	/*
	 * Expand the command location array by allocating more storage from
	 * the heap. The currently allocated CmdLocation entries are stored
	 * from cmdMapPtr[0] up to cmdMapPtr[envPtr->cmdMapEnd] (inclusive).
	 */

	size_t currElems = envPtr->cmdMapEnd;
	size_t newElems = 2*currElems;
	size_t currBytes = currElems * sizeof(CmdLocation);
	size_t newBytes = newElems * sizeof(CmdLocation);

	if (envPtr->mallocedCmdMap) {
	    envPtr->cmdMapPtr = (CmdLocation *)
		    ckrealloc((char *) envPtr->cmdMapPtr, newBytes);
	} else {
	    /*
	     * envPtr->cmdMapPtr isn't a ckalloc'd pointer, so we must
	     * code a ckrealloc equivalent for ourselves.
	     */
	    CmdLocation *newPtr = (CmdLocation *) ckalloc((unsigned) newBytes);
	    memcpy(newPtr, envPtr->cmdMapPtr, currBytes);
	    envPtr->cmdMapPtr = newPtr;
	    envPtr->mallocedCmdMap = 1;
	}
	envPtr->cmdMapEnd = newElems;
    }

    if (cmdIndex > 0) {
	if (codeOffset < envPtr->cmdMapPtr[cmdIndex-1].codeOffset) {
	    Tcl_Panic("EnterCmdStartData: cmd map not sorted by code offset");
	}
    }

    cmdLocPtr = &(envPtr->cmdMapPtr[cmdIndex]);
    cmdLocPtr->codeOffset = codeOffset;
    cmdLocPtr->srcOffset = srcOffset;
    cmdLocPtr->numSrcBytes = -1;
    cmdLocPtr->numCodeBytes = -1;
}

/*
 *----------------------------------------------------------------------
 *
 * EnterCmdExtentData --
 *
 *	Registers the source and bytecode length for a command. This
 *	information is used at runtime to map between instruction pc and
 *	source locations.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Inserts source and code length information into the compilation
 *	environment envPtr for the command at index cmdIndex. Starting source
 *	and bytecode information for the command must already have been
 *	registered.
 *
 *----------------------------------------------------------------------
 */

static void
EnterCmdExtentData(
    CompileEnv *envPtr,		/* Points to the compilation environment
				 * structure in which to enter command
				 * location information. */
    int cmdIndex,		/* Index of the command whose source and code
				 * length data is being set. */
    int numSrcBytes,		/* Number of command source chars. */
    int numCodeBytes)		/* Offset of last byte of command code. */
{
    CmdLocation *cmdLocPtr;

    if ((cmdIndex < 0) || (cmdIndex >= envPtr->numCommands)) {
	Tcl_Panic("EnterCmdExtentData: bad command index %d", cmdIndex);
    }

    if (cmdIndex > envPtr->cmdMapEnd) {
	Tcl_Panic("EnterCmdExtentData: missing start data for command %d",
		cmdIndex);
    }

    cmdLocPtr = &(envPtr->cmdMapPtr[cmdIndex]);
    cmdLocPtr->numSrcBytes = numSrcBytes;
    cmdLocPtr->numCodeBytes = numCodeBytes;
}

/*
 *----------------------------------------------------------------------
 * TIP #280
 *
 * EnterCmdWordData --
 *
 *	Registers the lines for the words of a command. This information is
 *	used at runtime by 'info frame'.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Inserts word location information into the compilation environment
 *	envPtr for the command at index cmdIndex. The compilation
 *	environment's ExtCmdLoc.ECL array is grown if necessary.
 *
 *----------------------------------------------------------------------
 */

static void
EnterCmdWordData(
    ExtCmdLoc *eclPtr,		/* Points to the map environment structure in
				 * which to enter command location
				 * information. */
    int srcOffset,		/* Offset of first char of the command. */
    Tcl_Token *tokenPtr,
    const char *cmd,
    int len,
    int numWords,
    int line,
    int* clNext,
    int **wlines,
    CompileEnv* envPtr)
{
    ECL *ePtr;
    const char *last;
    int wordIdx, wordLine, *wwlines;
    int* wordNext;

    if (eclPtr->nuloc >= eclPtr->nloc) {
	/*
	 * Expand the ECL array by allocating more storage from the heap. The
	 * currently allocated ECL entries are stored from eclPtr->loc[0] up
	 * to eclPtr->loc[eclPtr->nuloc-1] (inclusive).
	 */

	size_t currElems = eclPtr->nloc;
	size_t newElems = (currElems ? 2*currElems : 1);
	size_t newBytes = newElems * sizeof(ECL);

	eclPtr->loc = (ECL *) ckrealloc((char *)(eclPtr->loc), newBytes);
	eclPtr->nloc = newElems;
    }

    ePtr = &eclPtr->loc[eclPtr->nuloc];
    ePtr->srcOffset = srcOffset;
    ePtr->line = (int *) ckalloc(numWords * sizeof(int));
    ePtr->next = (int**) ckalloc (numWords * sizeof (int*));
    ePtr->nline = numWords;
    wwlines = (int *) ckalloc(numWords * sizeof(int));

    last = cmd;
    wordLine = line;
    wordNext = clNext;
    for (wordIdx=0 ; wordIdx<numWords;
	    wordIdx++, tokenPtr += tokenPtr->numComponents + 1) {
        TclAdvanceLines         (&wordLine, last, tokenPtr->start);
	TclAdvanceContinuations (&wordLine, &wordNext,
				 tokenPtr->start - envPtr->source);
	wwlines[wordIdx] =
		(TclWordKnownAtCompileTime(tokenPtr, NULL) ? wordLine : -1);
	ePtr->line[wordIdx] = wordLine;
	ePtr->next[wordIdx] = wordNext;
	last = tokenPtr->start;
    }

    *wlines = wwlines;
    eclPtr->nuloc ++;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCreateExceptRange --
 *
 *	Procedure that allocates and initializes a new ExceptionRange
 *	structure of the specified kind in a CompileEnv.
 *
 * Results:
 *	Returns the index for the newly created ExceptionRange.
 *
 * Side effects:
 *	If there is not enough room in the CompileEnv's ExceptionRange array,
 *	the array in expanded: a new array of double the size is allocated, if
 *	envPtr->mallocedExceptArray is non-zero the old array is freed, and
 *	ExceptionRange entries are copied from the old array to the new one.
 *
 *----------------------------------------------------------------------
 */

int
TclCreateExceptRange(
    ExceptionRangeType type,	/* The kind of ExceptionRange desired. */
    register CompileEnv *envPtr)/* Points to CompileEnv for which to create a
				 * new ExceptionRange structure. */
{
    register ExceptionRange *rangePtr;
    int index = envPtr->exceptArrayNext;

    if (index >= envPtr->exceptArrayEnd) {
	/*
	 * Expand the ExceptionRange array. The currently allocated entries
	 * are stored between elements 0 and (envPtr->exceptArrayNext - 1)
	 * [inclusive].
	 */

	size_t currBytes =
		envPtr->exceptArrayNext * sizeof(ExceptionRange);
	int newElems = 2*envPtr->exceptArrayEnd;
	size_t newBytes = newElems * sizeof(ExceptionRange);

	if (envPtr->mallocedExceptArray) {
	    envPtr->exceptArrayPtr = (ExceptionRange *)
		    ckrealloc((char *)(envPtr->exceptArrayPtr), newBytes);
	} else {
	    /*
	     * envPtr->exceptArrayPtr isn't a ckalloc'd pointer, so we must
	     * code a ckrealloc equivalent for ourselves.
	     */
	    ExceptionRange *newPtr = (ExceptionRange *)
		    ckalloc((unsigned) newBytes);
	    memcpy(newPtr, envPtr->exceptArrayPtr, currBytes);
	    envPtr->exceptArrayPtr = newPtr;
	    envPtr->mallocedExceptArray = 1;
	}
	envPtr->exceptArrayEnd = newElems;
    }
    envPtr->exceptArrayNext++;

    rangePtr = &(envPtr->exceptArrayPtr[index]);
    rangePtr->type = type;
    rangePtr->nestingLevel = envPtr->exceptDepth;
    rangePtr->codeOffset = -1;
    rangePtr->numCodeBytes = -1;
    rangePtr->breakOffset = -1;
    rangePtr->continueOffset = -1;
    rangePtr->catchOffset = -1;
    return index;
}

/*
 *----------------------------------------------------------------------
 *
 * TclCreateAuxData --
 *
 *	Procedure that allocates and initializes a new AuxData structure in a
 *	CompileEnv's array of compilation auxiliary data records. These
 *	AuxData records hold information created during compilation by
 *	CompileProcs and used by instructions during execution.
 *
 * Results:
 *	Returns the index for the newly created AuxData structure.
 *
 * Side effects:
 *	If there is not enough room in the CompileEnv's AuxData array, the
 *	AuxData array in expanded: a new array of double the size is
 *	allocated, if envPtr->mallocedAuxDataArray is non-zero the old array
 *	is freed, and AuxData entries are copied from the old array to the new
 *	one.
 *
 *----------------------------------------------------------------------
 */

int
TclCreateAuxData(
    ClientData clientData,	/* The compilation auxiliary data to store in
				 * the new aux data record. */
    AuxDataType *typePtr,	/* Pointer to the type to attach to this
				 * AuxData */
    register CompileEnv *envPtr)/* Points to the CompileEnv for which a new
				 * aux data structure is to be allocated. */
{
    int index;			/* Index for the new AuxData structure. */
    register AuxData *auxDataPtr;
    				/* Points to the new AuxData structure */

    index = envPtr->auxDataArrayNext;
    if (index >= envPtr->auxDataArrayEnd) {
	/*
	 * Expand the AuxData array. The currently allocated entries are
	 * stored between elements 0 and (envPtr->auxDataArrayNext - 1)
	 * [inclusive].
	 */

	size_t currBytes = envPtr->auxDataArrayNext * sizeof(AuxData);
	int newElems = 2*envPtr->auxDataArrayEnd;
	size_t newBytes = newElems * sizeof(AuxData);

	if (envPtr->mallocedAuxDataArray) {
	    envPtr->auxDataArrayPtr = (AuxData *)
		    ckrealloc((char *)(envPtr->auxDataArrayPtr), newBytes);
	} else {
	    /*
	     * envPtr->auxDataArrayPtr isn't a ckalloc'd pointer, so we must
	     * code a ckrealloc equivalent for ourselves.
	     */
	    AuxData *newPtr = (AuxData *) ckalloc((unsigned) newBytes);
	    memcpy(newPtr, envPtr->auxDataArrayPtr, currBytes);
	    envPtr->auxDataArrayPtr = newPtr;
	    envPtr->mallocedAuxDataArray = 1;
	}
	envPtr->auxDataArrayEnd = newElems;
    }
    envPtr->auxDataArrayNext++;

    auxDataPtr = &(envPtr->auxDataArrayPtr[index]);
    auxDataPtr->clientData = clientData;
    auxDataPtr->type = typePtr;
    return index;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitJumpFixupArray --
 *
 *	Initializes a JumpFixupArray structure to hold some number of jump
 *	fixup entries.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The JumpFixupArray structure is initialized.
 *
 *----------------------------------------------------------------------
 */

void
TclInitJumpFixupArray(
    register JumpFixupArray *fixupArrayPtr)
				/* Points to the JumpFixupArray structure to
				 * initialize. */
{
    fixupArrayPtr->fixup = fixupArrayPtr->staticFixupSpace;
    fixupArrayPtr->next = 0;
    fixupArrayPtr->end = (JUMPFIXUP_INIT_ENTRIES - 1);
    fixupArrayPtr->mallocedArray = 0;
}

/*
 *----------------------------------------------------------------------
 *
 * TclExpandJumpFixupArray --
 *
 *	Procedure that uses malloc to allocate more storage for a jump fixup
 *	array.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The jump fixup array in *fixupArrayPtr is reallocated to a new array
 *	of double the size, and if fixupArrayPtr->mallocedArray is non-zero
 *	the old array is freed. Jump fixup structures are copied from the old
 *	array to the new one.
 *
 *----------------------------------------------------------------------
 */

void
TclExpandJumpFixupArray(
    register JumpFixupArray *fixupArrayPtr)
				/* Points to the JumpFixupArray structure
				 * to enlarge. */
{
    /*
     * The currently allocated jump fixup entries are stored from fixup[0] up
     * to fixup[fixupArrayPtr->fixupNext] (*not* inclusive). We assume
     * fixupArrayPtr->fixupNext is equal to fixupArrayPtr->fixupEnd.
     */

    size_t currBytes = fixupArrayPtr->next * sizeof(JumpFixup);
    int newElems = 2*(fixupArrayPtr->end + 1);
    size_t newBytes = newElems * sizeof(JumpFixup);

    if (fixupArrayPtr->mallocedArray) {
	fixupArrayPtr->fixup = (JumpFixup *)
		ckrealloc((char *)(fixupArrayPtr->fixup), newBytes);
    } else {
	/*
	 * fixupArrayPtr->fixup isn't a ckalloc'd pointer, so we must
	 * code a ckrealloc equivalent for ourselves.
	 */
	JumpFixup *newPtr = (JumpFixup *) ckalloc((unsigned) newBytes);
	memcpy(newPtr, fixupArrayPtr->fixup, currBytes);
	fixupArrayPtr->fixup = newPtr;
	fixupArrayPtr->mallocedArray = 1;
    }
    fixupArrayPtr->end = newElems;
}

/*
 *----------------------------------------------------------------------
 *
 * TclFreeJumpFixupArray --
 *
 *	Free any storage allocated in a jump fixup array structure.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Allocated storage in the JumpFixupArray structure is freed.
 *
 *----------------------------------------------------------------------
 */

void
TclFreeJumpFixupArray(
    register JumpFixupArray *fixupArrayPtr)
				/* Points to the JumpFixupArray structure to
				 * free. */
{
    if (fixupArrayPtr->mallocedArray) {
	ckfree((char *) fixupArrayPtr->fixup);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclEmitForwardJump --
 *
 *	Procedure to emit a two-byte forward jump of kind "jumpType". Since
 *	the jump may later have to be grown to five bytes if the jump target
 *	is more than, say, 127 bytes away, this procedure also initializes a
 *	JumpFixup record with information about the jump.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The JumpFixup record pointed to by "jumpFixupPtr" is initialized with
 *	information needed later if the jump is to be grown. Also, a two byte
 *	jump of the designated type is emitted at the current point in the
 *	bytecode stream.
 *
 *----------------------------------------------------------------------
 */

void
TclEmitForwardJump(
    CompileEnv *envPtr,		/* Points to the CompileEnv structure that
				 * holds the resulting instruction. */
    TclJumpType jumpType,	/* Indicates the kind of jump: if true or
				 * false or unconditional. */
    JumpFixup *jumpFixupPtr)	/* Points to the JumpFixup structure to
				 * initialize with information about this
				 * forward jump. */
{
    /*
     * Initialize the JumpFixup structure:
     *    - codeOffset is offset of first byte of jump below
     *    - cmdIndex is index of the command after the current one
     *    - exceptIndex is the index of the first ExceptionRange after the
     *	    current one.
     */

    jumpFixupPtr->jumpType = jumpType;
    jumpFixupPtr->codeOffset = (envPtr->codeNext - envPtr->codeStart);
    jumpFixupPtr->cmdIndex = envPtr->numCommands;
    jumpFixupPtr->exceptIndex = envPtr->exceptArrayNext;

    switch (jumpType) {
    case TCL_UNCONDITIONAL_JUMP:
	TclEmitInstInt1(INST_JUMP1, 0, envPtr);
	break;
    case TCL_TRUE_JUMP:
	TclEmitInstInt1(INST_JUMP_TRUE1, 0, envPtr);
	break;
    default:
	TclEmitInstInt1(INST_JUMP_FALSE1, 0, envPtr);
	break;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TclFixupForwardJump --
 *
 *	Procedure that updates a previously-emitted forward jump to jump a
 *	specified number of bytes, "jumpDist". If necessary, the jump is grown
 *	from two to five bytes; this is done if the jump distance is greater
 *	than "distThreshold" (normally 127 bytes). The jump is described by a
 *	JumpFixup record previously initialized by TclEmitForwardJump.
 *
 * Results:
 *	1 if the jump was grown and subsequent instructions had to be moved;
 *	otherwise 0. This result is returned to allow callers to update any
 *	additional code offsets they may hold.
 *
 * Side effects:
 *	The jump may be grown and subsequent instructions moved. If this
 *	happens, the code offsets for any commands and any ExceptionRange
 *	records between the jump and the current code address will be updated
 *	to reflect the moved code. Also, the bytecode instruction array in the
 *	CompileEnv structure may be grown and reallocated.
 *
 *----------------------------------------------------------------------
 */

int
TclFixupForwardJump(
    CompileEnv *envPtr,		/* Points to the CompileEnv structure that
				 * holds the resulting instruction. */
    JumpFixup *jumpFixupPtr,	/* Points to the JumpFixup structure that
				 * describes the forward jump. */
    int jumpDist,		/* Jump distance to set in jump instr. */
    int distThreshold)		/* Maximum distance before the two byte jump
				 * is grown to five bytes. */
{
    unsigned char *jumpPc, *p;
    int firstCmd, lastCmd, firstRange, lastRange, k;
    unsigned numBytes;

    if (jumpDist <= distThreshold) {
	jumpPc = (envPtr->codeStart + jumpFixupPtr->codeOffset);
	switch (jumpFixupPtr->jumpType) {
	case TCL_UNCONDITIONAL_JUMP:
	    TclUpdateInstInt1AtPc(INST_JUMP1, jumpDist, jumpPc);
	    break;
	case TCL_TRUE_JUMP:
	    TclUpdateInstInt1AtPc(INST_JUMP_TRUE1, jumpDist, jumpPc);
	    break;
	default:
	    TclUpdateInstInt1AtPc(INST_JUMP_FALSE1, jumpDist, jumpPc);
	    break;
	}
	return 0;
    }

    /*
     * We must grow the jump then move subsequent instructions down. Note that
     * if we expand the space for generated instructions, code addresses might
     * change; be careful about updating any of these addresses held in
     * variables.
     */

    if ((envPtr->codeNext + 3) > envPtr->codeEnd) {
	TclExpandCodeArray(envPtr);
    }
    jumpPc = (envPtr->codeStart + jumpFixupPtr->codeOffset);
    numBytes = envPtr->codeNext-jumpPc-2;
    p = jumpPc+2;
    memmove(p+3, p, numBytes);

    envPtr->codeNext += 3;
    jumpDist += 3;
    switch (jumpFixupPtr->jumpType) {
    case TCL_UNCONDITIONAL_JUMP:
	TclUpdateInstInt4AtPc(INST_JUMP4, jumpDist, jumpPc);
	break;
    case TCL_TRUE_JUMP:
	TclUpdateInstInt4AtPc(INST_JUMP_TRUE4, jumpDist, jumpPc);
	break;
    default:
	TclUpdateInstInt4AtPc(INST_JUMP_FALSE4, jumpDist, jumpPc);
	break;
    }

    /*
     * Adjust the code offsets for any commands and any ExceptionRange records
     * between the jump and the current code address.
     */

    firstCmd = jumpFixupPtr->cmdIndex;
    lastCmd = (envPtr->numCommands - 1);
    if (firstCmd < lastCmd) {
	for (k = firstCmd;  k <= lastCmd;  k++) {
	    (envPtr->cmdMapPtr[k]).codeOffset += 3;
	}
    }

    firstRange = jumpFixupPtr->exceptIndex;
    lastRange = (envPtr->exceptArrayNext - 1);
    for (k = firstRange;  k <= lastRange;  k++) {
	ExceptionRange *rangePtr = &(envPtr->exceptArrayPtr[k]);
	rangePtr->codeOffset += 3;

	switch (rangePtr->type) {
	case LOOP_EXCEPTION_RANGE:
	    rangePtr->breakOffset += 3;
	    if (rangePtr->continueOffset != -1) {
		rangePtr->continueOffset += 3;
	    }
	    break;
	case CATCH_EXCEPTION_RANGE:
	    rangePtr->catchOffset += 3;
	    break;
	default:
	    Tcl_Panic("TclFixupForwardJump: bad ExceptionRange type %d",
		    rangePtr->type);
	}
    }

    /*
     * TIP #280: Adjust the mapping from PC values to the per-command
     * information about arguments and their line numbers.
     *
     * Note: We cannot simply remove an out-of-date entry and then reinsert
     * with the proper PC, because then we might overwrite another entry which
     * was at that location. Therefore we pull (copy + delete) all effected
     * entries (beyond the fixed PC) into an array, update them there, and at
     * last reinsert them all.
     */

    {
	ExtCmdLoc* eclPtr = envPtr->extCmdMapPtr;

	/* A helper structure */

	typedef struct {
	    int pc;
	    int cmd;
	} MAP;

	/*
	 * And the helper array. At most the whole hashtable is placed into
	 * this.
	 */

	MAP *map = (MAP*) ckalloc (sizeof(MAP) * eclPtr->litInfo.numEntries);

	Tcl_HashSearch hSearch;
	Tcl_HashEntry* hPtr;
	int n, k, isnew;

	/*
	 * Phase I: Locate the affected entries, and save them in adjusted
	 * form to the array. This removes them from the hash.
	 */

	for (n = 0, hPtr = Tcl_FirstHashEntry(&eclPtr->litInfo, &hSearch);
	     hPtr != NULL;
	     hPtr = Tcl_NextHashEntry(&hSearch)) {

	    map [n].cmd = PTR2INT(Tcl_GetHashValue(hPtr));
	    map [n].pc  = PTR2INT(Tcl_GetHashKey (&eclPtr->litInfo,hPtr));

	    if (map[n].pc >= (jumpFixupPtr->codeOffset + 2)) {
		Tcl_DeleteHashEntry(hPtr);
		map [n].pc += 3;
		n++;
	    }
	}

	/*
	 * Phase II: Re-insert the modified entries into the hash.
	 */

	for (k=0;k<n;k++) {
	    hPtr = Tcl_CreateHashEntry(&eclPtr->litInfo, INT2PTR(map[k].pc), &isnew);
	    Tcl_SetHashValue(hPtr, INT2PTR(map[k].cmd));
	}

	ckfree ((char *) map);
    }

    return 1;			/* the jump was grown */
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetInstructionTable --
 *
 *	Returns a pointer to the table describing Tcl bytecode instructions.
 *	This procedure is defined so that clients can access the pointer from
 *	outside the TCL DLLs.
 *
 * Results:
 *	Returns a pointer to the global instruction table, same as the
 *	expression (&tclInstructionTable[0]).
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void * /* == InstructionDesc* == */
TclGetInstructionTable(void)
{
    return &tclInstructionTable[0];
}

/*
 *--------------------------------------------------------------
 *
 * RegisterAuxDataType --
 *
 *	This procedure is called to register a new AuxData type in the table
 *	of all AuxData types supported by Tcl.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	The type is registered in the AuxData type table. If there was already
 *	a type with the same name as in typePtr, it is replaced with the new
 *	type.
 *
 *--------------------------------------------------------------
 */

static void
RegisterAuxDataType(
    AuxDataType *typePtr)	/* Information about object type; storage must
				 * be statically allocated (must live forever;
				 * will not be deallocated). */
{
    register Tcl_HashEntry *hPtr;
    int isNew;

    Tcl_MutexLock(&tableMutex);
    if (!auxDataTypeTableInitialized) {
	TclInitAuxDataTypeTable();
    }

    /*
     * If there's already a type with the given name, remove it.
     */

    hPtr = Tcl_FindHashEntry(&auxDataTypeTable, typePtr->name);
    if (hPtr != NULL) {
	Tcl_DeleteHashEntry(hPtr);
    }

    /*
     * Now insert the new object type.
     */

    hPtr = Tcl_CreateHashEntry(&auxDataTypeTable, typePtr->name, &isNew);
    if (isNew) {
	Tcl_SetHashValue(hPtr, typePtr);
    }
    Tcl_MutexUnlock(&tableMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * TclGetAuxDataType --
 *
 *	This procedure looks up an Auxdata type by name.
 *
 * Results:
 *	If an AuxData type with name matching "typeName" is found, a pointer
 *	to its AuxDataType structure is returned; otherwise, NULL is returned.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

AuxDataType *
TclGetAuxDataType(
    char *typeName)		/* Name of AuxData type to look up. */
{
    register Tcl_HashEntry *hPtr;
    AuxDataType *typePtr = NULL;

    Tcl_MutexLock(&tableMutex);
    if (!auxDataTypeTableInitialized) {
	TclInitAuxDataTypeTable();
    }

    hPtr = Tcl_FindHashEntry(&auxDataTypeTable, typeName);
    if (hPtr != NULL) {
	typePtr = (AuxDataType *) Tcl_GetHashValue(hPtr);
    }
    Tcl_MutexUnlock(&tableMutex);

    return typePtr;
}

/*
 *--------------------------------------------------------------
 *
 * TclInitAuxDataTypeTable --
 *
 *	This procedure is invoked to perform once-only initialization of the
 *	AuxData type table. It also registers the AuxData types defined in
 *	this file.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Initializes the table of defined AuxData types "auxDataTypeTable" with
 *	builtin AuxData types defined in this file.
 *
 *--------------------------------------------------------------
 */

void
TclInitAuxDataTypeTable(void)
{
    /*
     * The table mutex must already be held before this routine is invoked.
     */

    auxDataTypeTableInitialized = 1;
    Tcl_InitHashTable(&auxDataTypeTable, TCL_STRING_KEYS);

    /*
     * There are only two AuxData type at this time, so register them here.
     */

    RegisterAuxDataType(&tclForeachInfoType);
    RegisterAuxDataType(&tclJumptableInfoType);
}

/*
 *----------------------------------------------------------------------
 *
 * TclFinalizeAuxDataTypeTable --
 *
 *	This procedure is called by Tcl_Finalize after all exit handlers have
 *	been run to free up storage associated with the table of AuxData
 *	types. This procedure is called by TclFinalizeExecution() which is
 *	called by Tcl_Finalize().
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Deletes all entries in the hash table of AuxData types.
 *
 *----------------------------------------------------------------------
 */

void
TclFinalizeAuxDataTypeTable(void)
{
    Tcl_MutexLock(&tableMutex);
    if (auxDataTypeTableInitialized) {
	Tcl_DeleteHashTable(&auxDataTypeTable);
	auxDataTypeTableInitialized = 0;
    }
    Tcl_MutexUnlock(&tableMutex);
}

/*
 *----------------------------------------------------------------------
 *
 * GetCmdLocEncodingSize --
 *
 *	Computes the total number of bytes needed to encode the command
 *	location information for some compiled code.
 *
 * Results:
 *	The byte count needed to encode the compiled location information.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static int
GetCmdLocEncodingSize(
    CompileEnv *envPtr)		/* Points to compilation environment structure
				 * containing the CmdLocation structure to
				 * encode. */
{
    register CmdLocation *mapPtr = envPtr->cmdMapPtr;
    int numCmds = envPtr->numCommands;
    int codeDelta, codeLen, srcDelta, srcLen;
    int codeDeltaNext, codeLengthNext, srcDeltaNext, srcLengthNext;
				/* The offsets in their respective byte
				 * sequences where the next encoded offset or
				 * length should go. */
    int prevCodeOffset, prevSrcOffset, i;

    codeDeltaNext = codeLengthNext = srcDeltaNext = srcLengthNext = 0;
    prevCodeOffset = prevSrcOffset = 0;
    for (i = 0;  i < numCmds;  i++) {
	codeDelta = (mapPtr[i].codeOffset - prevCodeOffset);
	if (codeDelta < 0) {
	    Tcl_Panic("GetCmdLocEncodingSize: bad code offset");
	} else if (codeDelta <= 127) {
	    codeDeltaNext++;
	} else {
	    codeDeltaNext += 5;	 /* 1 byte for 0xFF, 4 for positive delta */
	}
	prevCodeOffset = mapPtr[i].codeOffset;

	codeLen = mapPtr[i].numCodeBytes;
	if (codeLen < 0) {
	    Tcl_Panic("GetCmdLocEncodingSize: bad code length");
	} else if (codeLen <= 127) {
	    codeLengthNext++;
	} else {
	    codeLengthNext += 5; /* 1 byte for 0xFF, 4 for length */
	}

	srcDelta = (mapPtr[i].srcOffset - prevSrcOffset);
	if ((-127 <= srcDelta) && (srcDelta <= 127)) {
	    srcDeltaNext++;
	} else {
	    srcDeltaNext += 5;	 /* 1 byte for 0xFF, 4 for delta */
	}
	prevSrcOffset = mapPtr[i].srcOffset;

	srcLen = mapPtr[i].numSrcBytes;
	if (srcLen < 0) {
	    Tcl_Panic("GetCmdLocEncodingSize: bad source length");
	} else if (srcLen <= 127) {
	    srcLengthNext++;
	} else {
	    srcLengthNext += 5;	 /* 1 byte for 0xFF, 4 for length */
	}
    }

    return (codeDeltaNext + codeLengthNext + srcDeltaNext + srcLengthNext);
}

/*
 *----------------------------------------------------------------------
 *
 * EncodeCmdLocMap --
 *
 *	Encode the command location information for some compiled code into a
 *	ByteCode structure. The encoded command location map is stored as
 *	three adjacent byte sequences.
 *
 * Results:
 *	Pointer to the first byte after the encoded command location
 *	information.
 *
 * Side effects:
 *	The encoded information is stored into the block of memory headed by
 *	codePtr. Also records pointers to the start of the four byte sequences
 *	in fields in codePtr's ByteCode header structure.
 *
 *----------------------------------------------------------------------
 */

static unsigned char *
EncodeCmdLocMap(
    CompileEnv *envPtr,		/* Points to compilation environment structure
				 * containing the CmdLocation structure to
				 * encode. */
    ByteCode *codePtr,		/* ByteCode in which to encode envPtr's
				 * command location information. */
    unsigned char *startPtr)	/* Points to the first byte in codePtr's
				 * memory block where the location information
				 * is to be stored. */
{
    register CmdLocation *mapPtr = envPtr->cmdMapPtr;
    int numCmds = envPtr->numCommands;
    register unsigned char *p = startPtr;
    int codeDelta, codeLen, srcDelta, srcLen, prevOffset;
    register int i;

    /*
     * Encode the code offset for each command as a sequence of deltas.
     */

    codePtr->codeDeltaStart = p;
    prevOffset = 0;
    for (i = 0;  i < numCmds;  i++) {
	codeDelta = (mapPtr[i].codeOffset - prevOffset);
	if (codeDelta < 0) {
	    Tcl_Panic("EncodeCmdLocMap: bad code offset");
	} else if (codeDelta <= 127) {
	    TclStoreInt1AtPtr(codeDelta, p);
	    p++;
	} else {
	    TclStoreInt1AtPtr(0xFF, p);
	    p++;
	    TclStoreInt4AtPtr(codeDelta, p);
	    p += 4;
	}
	prevOffset = mapPtr[i].codeOffset;
    }

    /*
     * Encode the code length for each command.
     */

    codePtr->codeLengthStart = p;
    for (i = 0;  i < numCmds;  i++) {
	codeLen = mapPtr[i].numCodeBytes;
	if (codeLen < 0) {
	    Tcl_Panic("EncodeCmdLocMap: bad code length");
	} else if (codeLen <= 127) {
	    TclStoreInt1AtPtr(codeLen, p);
	    p++;
	} else {
	    TclStoreInt1AtPtr(0xFF, p);
	    p++;
	    TclStoreInt4AtPtr(codeLen, p);
	    p += 4;
	}
    }

    /*
     * Encode the source offset for each command as a sequence of deltas.
     */

    codePtr->srcDeltaStart = p;
    prevOffset = 0;
    for (i = 0;  i < numCmds;  i++) {
	srcDelta = (mapPtr[i].srcOffset - prevOffset);
	if ((-127 <= srcDelta) && (srcDelta <= 127)) {
	    TclStoreInt1AtPtr(srcDelta, p);
	    p++;
	} else {
	    TclStoreInt1AtPtr(0xFF, p);
	    p++;
	    TclStoreInt4AtPtr(srcDelta, p);
	    p += 4;
	}
	prevOffset = mapPtr[i].srcOffset;
    }

    /*
     * Encode the source length for each command.
     */

    codePtr->srcLengthStart = p;
    for (i = 0;  i < numCmds;  i++) {
	srcLen = mapPtr[i].numSrcBytes;
	if (srcLen < 0) {
	    Tcl_Panic("EncodeCmdLocMap: bad source length");
	} else if (srcLen <= 127) {
	    TclStoreInt1AtPtr(srcLen, p);
	    p++;
	} else {
	    TclStoreInt1AtPtr(0xFF, p);
	    p++;
	    TclStoreInt4AtPtr(srcLen, p);
	    p += 4;
	}
    }

    return p;
}

#ifdef TCL_COMPILE_DEBUG
/*
 *----------------------------------------------------------------------
 *
 * TclPrintByteCodeObj --
 *
 *	This procedure prints ("disassembles") the instructions of a bytecode
 *	object to stdout.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
TclPrintByteCodeObj(
    Tcl_Interp *interp,		/* Used only for Tcl_GetStringFromObj. */
    Tcl_Obj *objPtr)		/* The bytecode object to disassemble. */
{
    Tcl_Obj *bufPtr = TclDisassembleByteCodeObj(objPtr);

    fprintf(stdout, "\n%s", TclGetString(bufPtr));
    Tcl_DecrRefCount(bufPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * TclPrintInstruction --
 *
 *	This procedure prints ("disassembles") one instruction from a bytecode
 *	object to stdout.
 *
 * Results:
 *	Returns the length in bytes of the current instruiction.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

int
TclPrintInstruction(
    ByteCode *codePtr,		/* Bytecode containing the instruction. */
    unsigned char *pc)		/* Points to first byte of instruction. */
{
    Tcl_Obj *bufferObj;
    int numBytes;

    TclNewObj(bufferObj);
    numBytes = FormatInstruction(codePtr, pc, bufferObj);
    fprintf(stdout, "%s", TclGetString(bufferObj));
    Tcl_DecrRefCount(bufferObj);
    return numBytes;
}

/*
 *----------------------------------------------------------------------
 *
 * TclPrintObject --
 *
 *	This procedure prints up to a specified number of characters from the
 *	argument Tcl object's string representation to a specified file.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Outputs characters to the specified file.
 *
 *----------------------------------------------------------------------
 */

void
TclPrintObject(
    FILE *outFile,		/* The file to print the source to. */
    Tcl_Obj *objPtr,		/* Points to the Tcl object whose string
				 * representation should be printed. */
    int maxChars)		/* Maximum number of chars to print. */
{
    char *bytes;
    int length;

    bytes = Tcl_GetStringFromObj(objPtr, &length);
    TclPrintSource(outFile, bytes, TclMin(length, maxChars));
}

/*
 *----------------------------------------------------------------------
 *
 * TclPrintSource --
 *
 *	This procedure prints up to a specified number of characters from the
 *	argument string to a specified file. It tries to produce legible
 *	output by adding backslashes as necessary.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Outputs characters to the specified file.
 *
 *----------------------------------------------------------------------
 */

void
TclPrintSource(
    FILE *outFile,		/* The file to print the source to. */
    const char *stringPtr,	/* The string to print. */
    int maxChars)		/* Maximum number of chars to print. */
{
    Tcl_Obj *bufferObj;

    TclNewObj(bufferObj);
    PrintSourceToObj(bufferObj, stringPtr, maxChars);
    fprintf(outFile, "%s", TclGetString(bufferObj));
    Tcl_DecrRefCount(bufferObj);
}
#endif /* TCL_COMPILE_DEBUG */

/*
 *----------------------------------------------------------------------
 *
 * TclDisassembleByteCodeObj --
 *
 *	Given an object which is of bytecode type, return a disassembled
 *	version of the bytecode (in a new refcount 0 object). No guarantees
 *	are made about the details of the contents of the result.
 *
 *----------------------------------------------------------------------
 */

Tcl_Obj *
TclDisassembleByteCodeObj(
    Tcl_Obj *objPtr)		/* The bytecode object to disassemble. */
{
    ByteCode *codePtr = objPtr->internalRep.twoPtrValue.ptr1;
    unsigned char *codeStart, *codeLimit, *pc;
    unsigned char *codeDeltaNext, *codeLengthNext;
    unsigned char *srcDeltaNext, *srcLengthNext;
    int codeOffset, codeLen, srcOffset, srcLen, numCmds, delta, i;
    Interp *iPtr = (Interp *) *codePtr->interpHandle;
    Tcl_Obj *bufferObj;
    char ptrBuf1[20], ptrBuf2[20];

    TclNewObj(bufferObj);
    if (codePtr->refCount <= 0) {
	return bufferObj;	/* Already freed. */
    }

    codeStart = codePtr->codeStart;
    codeLimit = (codeStart + codePtr->numCodeBytes);
    numCmds = codePtr->numCommands;

    /*
     * Print header lines describing the ByteCode.
     */

    sprintf(ptrBuf1, "%p", codePtr);
    sprintf(ptrBuf2, "%p", iPtr);
    Tcl_AppendPrintfToObj(bufferObj,
	    "ByteCode 0x%s, refCt %u, epoch %u, interp 0x%s (epoch %u)\n",
	    ptrBuf1, codePtr->refCount, codePtr->compileEpoch, ptrBuf2,
	    iPtr->compileEpoch);
    Tcl_AppendToObj(bufferObj, "  Source ", -1);
    PrintSourceToObj(bufferObj, codePtr->source,
	    TclMin(codePtr->numSrcBytes, 55));
    Tcl_AppendPrintfToObj(bufferObj,
	    "\n  Cmds %d, src %d, inst %d, litObjs %u, aux %d, stkDepth %u, code/src %.2f\n",
	    numCmds, codePtr->numSrcBytes, codePtr->numCodeBytes,
	    codePtr->numLitObjects, codePtr->numAuxDataItems,
	    codePtr->maxStackDepth,
#ifdef TCL_COMPILE_STATS
	    codePtr->numSrcBytes?
		    codePtr->structureSize/(float)codePtr->numSrcBytes :
#endif
	    0.0);

#ifdef TCL_COMPILE_STATS
    Tcl_AppendPrintfToObj(bufferObj,
	    "  Code %lu = header %lu+inst %d+litObj %lu+exc %lu+aux %lu+cmdMap %d\n",
	    (unsigned long) codePtr->structureSize,
	    (unsigned long) (sizeof(ByteCode) - sizeof(size_t) - sizeof(Tcl_Time)),
	    codePtr->numCodeBytes,
	    (unsigned long) (codePtr->numLitObjects * sizeof(Tcl_Obj *)),
	    (unsigned long) (codePtr->numExceptRanges*sizeof(ExceptionRange)),
	    (unsigned long) (codePtr->numAuxDataItems * sizeof(AuxData)),
	    codePtr->numCmdLocBytes);
#endif /* TCL_COMPILE_STATS */

    /*
     * If the ByteCode is the compiled body of a Tcl procedure, print
     * information about that procedure. Note that we don't know the
     * procedure's name since ByteCode's can be shared among procedures.
     */

    if (codePtr->procPtr != NULL) {
	Proc *procPtr = codePtr->procPtr;
	int numCompiledLocals = procPtr->numCompiledLocals;

	sprintf(ptrBuf1, "%p", procPtr);
	Tcl_AppendPrintfToObj(bufferObj,
		"  Proc 0x%s, refCt %d, args %d, compiled locals %d\n",
		ptrBuf1, procPtr->refCount, procPtr->numArgs,
		numCompiledLocals);
	if (numCompiledLocals > 0) {
	    CompiledLocal *localPtr = procPtr->firstLocalPtr;

	    for (i = 0;  i < numCompiledLocals;  i++) {
		Tcl_AppendPrintfToObj(bufferObj,
			"      slot %d%s%s%s%s%s%s", i,
			(localPtr->flags & (VAR_ARRAY|VAR_LINK)) ? "" : ", scalar",
			(localPtr->flags & VAR_ARRAY) ? ", array" : "",
			(localPtr->flags & VAR_LINK) ? ", link" : "",
			(localPtr->flags & VAR_ARGUMENT) ? ", arg" : "",
			(localPtr->flags & VAR_TEMPORARY) ? ", temp" : "",
			(localPtr->flags & VAR_RESOLVED) ? ", resolved" : "");
		if (TclIsVarTemporary(localPtr)) {
		    Tcl_AppendToObj(bufferObj, "\n", -1);
		} else {
		    Tcl_AppendPrintfToObj(bufferObj, ", \"%s\"\n",
			    localPtr->name);
		}
		localPtr = localPtr->nextPtr;
	    }
	}
    }

    /*
     * Print the ExceptionRange array.
     */

    if (codePtr->numExceptRanges > 0) {
	Tcl_AppendPrintfToObj(bufferObj, "  Exception ranges %d, depth %d:\n",
		codePtr->numExceptRanges, codePtr->maxExceptDepth);
	for (i = 0;  i < codePtr->numExceptRanges;  i++) {
	    ExceptionRange *rangePtr = &(codePtr->exceptArrayPtr[i]);

	    Tcl_AppendPrintfToObj(bufferObj,
		    "      %d: level %d, %s, pc %d-%d, ",
		    i, rangePtr->nestingLevel,
		    (rangePtr->type==LOOP_EXCEPTION_RANGE ? "loop" : "catch"),
		    rangePtr->codeOffset,
		    (rangePtr->codeOffset + rangePtr->numCodeBytes - 1));
	    switch (rangePtr->type) {
	    case LOOP_EXCEPTION_RANGE:
		Tcl_AppendPrintfToObj(bufferObj, "continue %d, break %d\n",
			rangePtr->continueOffset, rangePtr->breakOffset);
		break;
	    case CATCH_EXCEPTION_RANGE:
		Tcl_AppendPrintfToObj(bufferObj, "catch %d\n",
			rangePtr->catchOffset);
		break;
	    default:
		Tcl_Panic("TclDisassembleByteCodeObj: bad ExceptionRange type %d",
			rangePtr->type);
	    }
	}
    }

    /*
     * If there were no commands (e.g., an expression or an empty string was
     * compiled), just print all instructions and return.
     */

    if (numCmds == 0) {
	pc = codeStart;
	while (pc < codeLimit) {
	    Tcl_AppendToObj(bufferObj, "    ", -1);
	    pc += FormatInstruction(codePtr, pc, bufferObj);
	}
	return bufferObj;
    }

    /*
     * Print table showing the code offset, source offset, and source length
     * for each command. These are encoded as a sequence of bytes.
     */

    Tcl_AppendPrintfToObj(bufferObj, "  Commands %d:", numCmds);
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

	Tcl_AppendPrintfToObj(bufferObj, "%s%4d: pc %d-%d, src %d-%d",
		((i % 2)? "   	" : "\n   "),
		(i+1), codeOffset, (codeOffset + codeLen - 1),
		srcOffset, (srcOffset + srcLen - 1));
    }
    if (numCmds > 0) {
	Tcl_AppendToObj(bufferObj, "\n", -1);
    }

    /*
     * Print each instruction. If the instruction corresponds to the start of
     * a command, print the command's source. Note that we don't need the code
     * length here.
     */

    codeDeltaNext = codePtr->codeDeltaStart;
    srcDeltaNext = codePtr->srcDeltaStart;
    srcLengthNext = codePtr->srcLengthStart;
    codeOffset = srcOffset = 0;
    pc = codeStart;
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

	/*
	 * Print instructions before command i.
	 */

	while ((pc-codeStart) < codeOffset) {
	    Tcl_AppendToObj(bufferObj, "    ", -1);
	    pc += FormatInstruction(codePtr, pc, bufferObj);
	}

	Tcl_AppendPrintfToObj(bufferObj, "  Command %d: ", i+1);
	PrintSourceToObj(bufferObj, (codePtr->source + srcOffset),
		TclMin(srcLen, 55));
	Tcl_AppendToObj(bufferObj, "\n", -1);
    }
    if (pc < codeLimit) {
	/*
	 * Print instructions after the last command.
	 */

	while (pc < codeLimit) {
	    Tcl_AppendToObj(bufferObj, "    ", -1);
	    pc += FormatInstruction(codePtr, pc, bufferObj);
	}
    }
    return bufferObj;
}

/*
 *----------------------------------------------------------------------
 *
 * FormatInstruction --
 *
 *	Appends a representation of a bytecode instruction to a Tcl_Obj.
 *
 *----------------------------------------------------------------------
 */

static int
FormatInstruction(
    ByteCode *codePtr,		/* Bytecode containing the instruction. */
    unsigned char *pc,		/* Points to first byte of instruction. */
    Tcl_Obj *bufferObj)		/* Object to append instruction info to. */
{
    Proc *procPtr = codePtr->procPtr;
    unsigned char opCode = *pc;
    register InstructionDesc *instDesc = &tclInstructionTable[opCode];
    unsigned char *codeStart = codePtr->codeStart;
    unsigned pcOffset = pc - codeStart;
    int opnd = 0, i, j, numBytes = 1;
    int localCt = procPtr ? procPtr->numCompiledLocals : 0;
    CompiledLocal *localPtr = procPtr ? procPtr->firstLocalPtr : NULL;
    char suffixBuffer[128];	/* Additional info to print after main opcode
				 * and immediates. */
    char *suffixSrc = NULL;
    Tcl_Obj *suffixObj = NULL;
    AuxData *auxPtr = NULL;

    suffixBuffer[0] = '\0';
    Tcl_AppendPrintfToObj(bufferObj, "(%u) %s ", pcOffset, instDesc->name);
    for (i = 0;  i < instDesc->numOperands;  i++) {
	switch (instDesc->opTypes[i]) {
	case OPERAND_INT1:
	    opnd = TclGetInt1AtPtr(pc+numBytes); numBytes++;
	    if (opCode == INST_JUMP1 || opCode == INST_JUMP_TRUE1
		    || opCode == INST_JUMP_FALSE1) {
		sprintf(suffixBuffer, "pc %u", pcOffset+opnd);
	    }
	    Tcl_AppendPrintfToObj(bufferObj, "%+d ", opnd);
	    break;
	case OPERAND_INT4:
	    opnd = TclGetInt4AtPtr(pc+numBytes); numBytes += 4;
	    if (opCode == INST_JUMP4 || opCode == INST_JUMP_TRUE4
		    || opCode == INST_JUMP_FALSE4) {
		sprintf(suffixBuffer, "pc %u", pcOffset+opnd);
	    } else if (opCode == INST_START_CMD) {
		sprintf(suffixBuffer, "next cmd at pc %u", pcOffset+opnd);
	    }
	    Tcl_AppendPrintfToObj(bufferObj, "%+d ", opnd);
	    break;
	case OPERAND_UINT1:
	    opnd = TclGetUInt1AtPtr(pc+numBytes); numBytes++;
	    if (opCode == INST_PUSH1) {
		suffixObj = codePtr->objArrayPtr[opnd];
	    }
	    Tcl_AppendPrintfToObj(bufferObj, "%u ", (unsigned) opnd);
	    break;
	case OPERAND_AUX4:
	case OPERAND_UINT4:
	    opnd = TclGetUInt4AtPtr(pc+numBytes); numBytes += 4;
	    if (opCode == INST_PUSH4) {
		suffixObj = codePtr->objArrayPtr[opnd];
	    } else if (opCode == INST_START_CMD && opnd != 1) {
		sprintf(suffixBuffer+strlen(suffixBuffer),
			", %u cmds start here", opnd);
	    }
	    Tcl_AppendPrintfToObj(bufferObj, "%u ", (unsigned) opnd);
	    if (instDesc->opTypes[i] == OPERAND_AUX4) {
		auxPtr = &codePtr->auxDataArrayPtr[opnd];
	    }
	    break;
	case OPERAND_IDX4:
	    opnd = TclGetInt4AtPtr(pc+numBytes); numBytes += 4;
	    if (opnd >= -1) {
		Tcl_AppendPrintfToObj(bufferObj, "%d ", opnd);
	    } else if (opnd == -2) {
		Tcl_AppendPrintfToObj(bufferObj, "end ");
	    } else {
		Tcl_AppendPrintfToObj(bufferObj, "end-%d ", -2-opnd);
	    }
	    break;
	case OPERAND_LVT1:
	    opnd = TclGetUInt1AtPtr(pc+numBytes);
	    numBytes++;
	    goto printLVTindex;
	case OPERAND_LVT4:
	    opnd = TclGetUInt4AtPtr(pc+numBytes);
	    numBytes += 4;
	printLVTindex:
	    if (localPtr != NULL) {
		if (opnd >= localCt) {
		    Tcl_Panic("FormatInstruction: bad local var index %u (%u locals)",
			    (unsigned) opnd, localCt);
		}
		for (j = 0;  j < opnd;  j++) {
		    localPtr = localPtr->nextPtr;
		}
		if (TclIsVarTemporary(localPtr)) {
		    sprintf(suffixBuffer, "temp var %u", (unsigned) opnd);
		} else {
		    sprintf(suffixBuffer, "var ");
		    suffixSrc = localPtr->name;
		}
	    }
	    Tcl_AppendPrintfToObj(bufferObj, "%%v%u ", (unsigned) opnd);
	    break;
	case OPERAND_NONE:
	default:
	    break;
	}
    }
    if (suffixObj) {
	char *bytes;
	int length;

	Tcl_AppendToObj(bufferObj, "\t# ", -1);
	bytes = Tcl_GetStringFromObj(codePtr->objArrayPtr[opnd], &length);
	PrintSourceToObj(bufferObj, bytes, TclMin(length, 40));
    } else if (suffixBuffer[0]) {
	Tcl_AppendPrintfToObj(bufferObj, "\t# %s", suffixBuffer);
	if (suffixSrc) {
	    PrintSourceToObj(bufferObj, suffixSrc, 40);
	}
    }
    Tcl_AppendToObj(bufferObj, "\n", -1);
    if (auxPtr && auxPtr->type->printProc) {
	Tcl_AppendToObj(bufferObj, "\t\t[", -1);
	auxPtr->type->printProc(auxPtr->clientData, bufferObj, codePtr,
		pcOffset);
	Tcl_AppendToObj(bufferObj, "]\n", -1);
    }
    return numBytes;
}

/*
 *----------------------------------------------------------------------
 *
 * PrintSourceToObj --
 *
 *	Appends a quoted representation of a string to a Tcl_Obj.
 *
 *----------------------------------------------------------------------
 */

static void
PrintSourceToObj(
    Tcl_Obj *appendObj,		/* The object to print the source to. */
    const char *stringPtr,	/* The string to print. */
    int maxChars)		/* Maximum number of chars to print. */
{
    register const char *p;
    register int i = 0;

    if (stringPtr == NULL) {
	Tcl_AppendToObj(appendObj, "\"\"", -1);
	return;
    }

    Tcl_AppendToObj(appendObj, "\"", -1);
    p = stringPtr;
    for (;  (*p != '\0') && (i < maxChars);  p++, i++) {
	switch (*p) {
	case '"':
	    Tcl_AppendToObj(appendObj, "\\\"", -1);
	    continue;
	case '\f':
	    Tcl_AppendToObj(appendObj, "\\f", -1);
	    continue;
	case '\n':
	    Tcl_AppendToObj(appendObj, "\\n", -1);
	    continue;
	case '\r':
	    Tcl_AppendToObj(appendObj, "\\r", -1);
	    continue;
	case '\t':
	    Tcl_AppendToObj(appendObj, "\\t", -1);
	    continue;
	case '\v':
	    Tcl_AppendToObj(appendObj, "\\v", -1);
	    continue;
	default:
	    Tcl_AppendPrintfToObj(appendObj, "%c", *p);
	    continue;
	}
    }
    Tcl_AppendToObj(appendObj, "\"", -1);
}

#ifdef TCL_COMPILE_STATS
/*
 *----------------------------------------------------------------------
 *
 * RecordByteCodeStats --
 *
 *	Accumulates various compilation-related statistics for each newly
 *	compiled ByteCode. Called by the TclInitByteCodeObj when Tcl is
 *	compiled with the -DTCL_COMPILE_STATS flag
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Accumulates aggregate code-related statistics in the interpreter's
 *	ByteCodeStats structure. Records statistics specific to a ByteCode in
 *	its ByteCode structure.
 *
 *----------------------------------------------------------------------
 */

void
RecordByteCodeStats(
    ByteCode *codePtr)		/* Points to ByteCode structure with info
				 * to add to accumulated statistics. */
{
    Interp *iPtr = (Interp *) *codePtr->interpHandle;
    register ByteCodeStats *statsPtr;

    if (iPtr == NULL) {
	/* Avoid segfaulting in case we're called in a deleted interp */
	return;
    }
    statsPtr = &(iPtr->stats);

    statsPtr->numCompilations++;
    statsPtr->totalSrcBytes += (double) codePtr->numSrcBytes;
    statsPtr->totalByteCodeBytes += (double) codePtr->structureSize;
    statsPtr->currentSrcBytes += (double) codePtr->numSrcBytes;
    statsPtr->currentByteCodeBytes += (double) codePtr->structureSize;

    statsPtr->srcCount[TclLog2(codePtr->numSrcBytes)]++;
    statsPtr->byteCodeCount[TclLog2((int)(codePtr->structureSize))]++;

    statsPtr->currentInstBytes += (double) codePtr->numCodeBytes;
    statsPtr->currentLitBytes += (double)
	    codePtr->numLitObjects * sizeof(Tcl_Obj *);
    statsPtr->currentExceptBytes += (double)
	    codePtr->numExceptRanges * sizeof(ExceptionRange);
    statsPtr->currentAuxBytes += (double)
	    codePtr->numAuxDataItems * sizeof(AuxData);
    statsPtr->currentCmdMapBytes += (double) codePtr->numCmdLocBytes;
}
#endif /* TCL_COMPILE_STATS */

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
