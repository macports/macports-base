/*
 * tclCmdMZ.c --
 *
 *	This file contains the top-level command routines for most of the Tcl
 *	built-in commands whose names begin with the letters M to Z. It
 *	contains only commands in the generic core (i.e. those that don't
 *	depend much upon UNIX facilities).
 *
 * Copyright © 1987-1993 The Regents of the University of California.
 * Copyright © 1994-1997 Sun Microsystems, Inc.
 * Copyright © 1998-2000 Scriptics Corporation.
 * Copyright © 2002 ActiveState Corporation.
 * Copyright © 2003-2009 Donal K. Fellows.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#include "tclInt.h"
#include "tclCompile.h"
#include "tclRegexp.h"
#include "tclStringTrim.h"
#include "tclTomMath.h"

static inline Tcl_Obj *	During(Tcl_Interp *interp, int resultCode,
			    Tcl_Obj *oldOptions, Tcl_Obj *errorInfo);
static Tcl_NRPostProc	SwitchPostProc;
static Tcl_NRPostProc	TryPostBody;
static Tcl_NRPostProc	TryPostFinal;
static Tcl_NRPostProc	TryPostHandler;
static int		UniCharIsAscii(int character);
static int		UniCharIsHexDigit(int character);
static int		StringCmpOpts(Tcl_Interp *interp, int objc,
			    Tcl_Obj *const objv[], int *nocase,
			    Tcl_Size *reqlength);

/*
 * Default set of characters to trim in [string trim] and friends. This is a
 * UTF-8 literal string containing all Unicode space characters [TIP #413]
 */

const char tclDefaultTrimSet[] =
	"\x09\x0A\x0B\x0C\x0D " /* ASCII */
	"\xC0\x80" /*     nul (U+0000) */
	"\xC2\x85" /*     next line (U+0085) */
	"\xC2\xA0" /*     non-breaking space (U+00a0) */
	"\xE1\x9A\x80" /* ogham space mark (U+1680) */
	"\xE1\xA0\x8E" /* mongolian vowel separator (U+180e) */
	"\xE2\x80\x80" /* en quad (U+2000) */
	"\xE2\x80\x81" /* em quad (U+2001) */
	"\xE2\x80\x82" /* en space (U+2002) */
	"\xE2\x80\x83" /* em space (U+2003) */
	"\xE2\x80\x84" /* three-per-em space (U+2004) */
	"\xE2\x80\x85" /* four-per-em space (U+2005) */
	"\xE2\x80\x86" /* six-per-em space (U+2006) */
	"\xE2\x80\x87" /* figure space (U+2007) */
	"\xE2\x80\x88" /* punctuation space (U+2008) */
	"\xE2\x80\x89" /* thin space (U+2009) */
	"\xE2\x80\x8A" /* hair space (U+200a) */
	"\xE2\x80\x8B" /* zero width space (U+200b) */
	"\xE2\x80\xA8" /* line separator (U+2028) */
	"\xE2\x80\xA9" /* paragraph separator (U+2029) */
	"\xE2\x80\xAF" /* narrow no-break space (U+202f) */
	"\xE2\x81\x9F" /* medium mathematical space (U+205f) */
	"\xE2\x81\xA0" /* word joiner (U+2060) */
	"\xE3\x80\x80" /* ideographic space (U+3000) */
	"\xEF\xBB\xBF" /* zero width no-break space (U+feff) */
;

/*
 *----------------------------------------------------------------------
 *
 * Tcl_PwdObjCmd --
 *
 *	This procedure is invoked to process the "pwd" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_PwdObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *retVal;

    if (objc != 1) {
	Tcl_WrongNumArgs(interp, 1, objv, NULL);
	return TCL_ERROR;
    }

    retVal = Tcl_FSGetCwd(interp);
    if (retVal == NULL) {
	return TCL_ERROR;
    }
    Tcl_SetObjResult(interp, retVal);
    Tcl_DecrRefCount(retVal);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_RegexpObjCmd --
 *
 *	This procedure is invoked to process the "regexp" Tcl command. See
 *	the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_RegexpObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size offset, stringLength, matchLength, cflags, eflags;
    int i, indices, match, about, all, doinline, numMatchesSaved;
    Tcl_RegExp regExpr;
    Tcl_Obj *objPtr, *startIndex = NULL, *resultPtr = NULL;
    Tcl_RegExpInfo info;
    static const char *const options[] = {
	"-all",		"-about",	"-indices",	"-inline",
	"-expanded",	"-line",	"-linestop",	"-lineanchor",
	"-nocase",	"-start",	"--",		NULL
    };
    enum regexpoptions {
	REGEXP_ALL,	REGEXP_ABOUT,	REGEXP_INDICES,	REGEXP_INLINE,
	REGEXP_EXPANDED,REGEXP_LINE,	REGEXP_LINESTOP,REGEXP_LINEANCHOR,
	REGEXP_NOCASE,	REGEXP_START,	REGEXP_LAST
    } index;

    indices = 0;
    about = 0;
    cflags = TCL_REG_ADVANCED;
    offset = TCL_INDEX_START;
    all = 0;
    doinline = 0;

    for (i = 1; i < objc; i++) {
	const char *name;

	name = TclGetString(objv[i]);
	if (name[0] != '-') {
	    break;
	}
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", TCL_EXACT,
		&index) != TCL_OK) {
	    goto optionError;
	}
	switch (index) {
	case REGEXP_ALL:
	    all = 1;
	    break;
	case REGEXP_INDICES:
	    indices = 1;
	    break;
	case REGEXP_INLINE:
	    doinline = 1;
	    break;
	case REGEXP_NOCASE:
	    cflags |= TCL_REG_NOCASE;
	    break;
	case REGEXP_ABOUT:
	    about = 1;
	    break;
	case REGEXP_EXPANDED:
	    cflags |= TCL_REG_EXPANDED;
	    break;
	case REGEXP_LINE:
	    cflags |= TCL_REG_NEWLINE;
	    break;
	case REGEXP_LINESTOP:
	    cflags |= TCL_REG_NLSTOP;
	    break;
	case REGEXP_LINEANCHOR:
	    cflags |= TCL_REG_NLANCH;
	    break;
	case REGEXP_START: {
	    Tcl_Size temp;
	    if (++i >= objc) {
		goto endOfForLoop;
	    }
	    if (TclGetIntForIndexM(interp, objv[i], TCL_SIZE_MAX - 1, &temp) != TCL_OK) {
		goto optionError;
	    }
	    if (startIndex) {
		Tcl_DecrRefCount(startIndex);
	    }
	    startIndex = objv[i];
	    Tcl_IncrRefCount(startIndex);
	    break;
	}
	case REGEXP_LAST:
	    i++;
	    goto endOfForLoop;
	default:
	    TCL_UNREACHABLE();
	}
    }

  endOfForLoop:
    if ((objc - i) < (2 - about)) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-option ...? exp string ?matchVar? ?subMatchVar ...?");
	goto optionError;
    }
    objc -= i;
    objv += i;

    /*
     * Check if the user requested -inline, but specified match variables; a
     * no-no.
     */

    if (doinline && ((objc - 2) != 0)) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"regexp match variables not allowed when using -inline", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "REGEXP",
		"MIX_VAR_INLINE", (char *)NULL);
	goto optionError;
    }

    /*
     * Handle the odd about case separately.
     */

    if (about) {
	regExpr = Tcl_GetRegExpFromObj(interp, objv[0], cflags);
	if ((regExpr == NULL) || (TclRegAbout(interp, regExpr) < 0)) {
	optionError:
	    if (startIndex) {
		Tcl_DecrRefCount(startIndex);
	    }
	    return TCL_ERROR;
	}
	return TCL_OK;
    }

    /*
     * Get the length of the string that we are matching against so we can do
     * the termination test for -all matches. Do this before getting the
     * regexp to avoid shimmering problems.
     */

    objPtr = objv[1];
    stringLength = Tcl_GetCharLength(objPtr);

    if (startIndex) {
	TclGetIntForIndexM(interp, startIndex, stringLength, &offset);
	Tcl_DecrRefCount(startIndex);
	if (offset < 0) {
	    offset = TCL_INDEX_START;
	}
    }

    regExpr = Tcl_GetRegExpFromObj(interp, objv[0], cflags);
    if (regExpr == NULL) {
	return TCL_ERROR;
    }

    objc -= 2;
    objv += 2;

    if (doinline) {
	/*
	 * Save all the subexpressions, as we will return them as a list
	 */

	numMatchesSaved = -1;
    } else {
	/*
	 * Save only enough subexpressions for matches we want to keep, expect
	 * in the case of -all, where we need to keep at least one to know
	 * where to move the offset.
	 */

	numMatchesSaved = (objc == 0) ? all : objc;
    }

    /*
     * The following loop is to handle multiple matches within the same source
     * string; each iteration handles one match. If "-all" hasn't been
     * specified then the loop body only gets executed once. We terminate the
     * loop when the starting offset is past the end of the string.
     */

    while (1) {
	/*
	 * Pass either 0 or TCL_REG_NOTBOL in the eflags. Passing
	 * TCL_REG_NOTBOL indicates that the character at offset should not be
	 * considered the start of the line. If for example the pattern {^} is
	 * passed and -start is positive, then the pattern will not match the
	 * start of the string unless the previous character is a newline.
	 */

	if (offset == TCL_INDEX_START) {
	    eflags = 0;
	} else if (offset > stringLength) {
	    eflags = TCL_REG_NOTBOL;
	} else if (Tcl_GetUniChar(objPtr, offset-1) == '\n') {
	    eflags = 0;
	} else {
	    eflags = TCL_REG_NOTBOL;
	}

	match = Tcl_RegExpExecObj(interp, regExpr, objPtr, offset,
		numMatchesSaved, eflags);
	if (match < 0) {
	    return TCL_ERROR;
	}

	if (match == 0) {
	    /*
	     * We want to set the value of the interpreter result only when
	     * this is the first time through the loop.
	     */

	    if (all <= 1) {
		/*
		 * If inlining, the interpreter's object result remains an
		 * empty list, otherwise set it to an integer object w/ value
		 * 0.
		 */

		if (!doinline) {
		    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(0));
		}
		return TCL_OK;
	    }
	    break;
	}

	/*
	 * If additional variable names have been specified, return index
	 * information in those variables.
	 */

	Tcl_RegExpGetInfo(regExpr, &info);
	if (doinline) {
	    /*
	     * It's the number of substitutions, plus one for the matchVar at
	     * index 0
	     */

	    objc = info.nsubs + 1;
	    if (all <= 1) {
		TclNewObj(resultPtr);
	    }
	}
	for (i = 0; i < objc; i++) {
	    Tcl_Obj *newPtr;

	    if (indices) {
		Tcl_Size start, end;
		Tcl_Obj *objs[2];

		/*
		 * Only adjust the match area if there was a match for that
		 * area. (Scriptics Bug 4391/SF Bug #219232)
		 */

		if (i <= (int)info.nsubs && info.matches[i].start >= 0) {
		    start = offset + info.matches[i].start;
		    end = offset + info.matches[i].end;

		    /*
		     * Adjust index so it refers to the last character in the
		     * match instead of the first character after the match.
		     */

		    if (end >= offset) {
			end--;
		    }
		} else {
		    start = TCL_INDEX_NONE;
		    end = TCL_INDEX_NONE;
		}

		TclNewIndexObj(objs[0], start);
		TclNewIndexObj(objs[1], end);

		newPtr = Tcl_NewListObj(2, objs);
	    } else {
		if ((i <= (int)info.nsubs) && (info.matches[i].end > 0)) {
		    newPtr = Tcl_GetRange(objPtr,
			    offset + info.matches[i].start,
			    offset + info.matches[i].end - 1);
		} else {
		    TclNewObj(newPtr);
		}
	    }
	    if (doinline) {
		if (Tcl_ListObjAppendElement(interp, resultPtr, newPtr)
			!= TCL_OK) {
		    Tcl_DecrRefCount(newPtr);
		    Tcl_DecrRefCount(resultPtr);
		    return TCL_ERROR;
		}
	    } else {
		if (Tcl_ObjSetVar2(interp, objv[i], NULL, newPtr,
			TCL_LEAVE_ERR_MSG) == NULL) {
		    return TCL_ERROR;
		}
	    }
	}

	if (all == 0) {
	    break;
	}

	/*
	 * Adjust the offset to the character just after the last one in the
	 * matchVar and increment all to count how many times we are making a
	 * match. We always increment the offset by at least one to prevent
	 * endless looping (as in the case: regexp -all {a*} a). Otherwise,
	 * when we match the NULL string at the end of the input string, we
	 * will loop indefinitely (because the length of the match is 0, so
	 * offset never changes).
	 */

	matchLength = (info.matches[0].end - info.matches[0].start);

	offset += info.matches[0].end;

	/*
	 * A match of length zero could happen for {^} {$} or {.*} and in
	 * these cases we always want to bump the index up one.
	 */

	if (matchLength == 0) {
	    offset++;
	}
	all++;
	if (offset >= stringLength) {
	    break;
	}
    }

    /*
     * Set the interpreter's object result to an integer object with value 1
     * if -all wasn't specified, otherwise it's all-1 (the number of times
     * through the while - 1).
     */

    if (doinline) {
	Tcl_SetObjResult(interp, resultPtr);
    } else {
	Tcl_SetObjResult(interp, Tcl_NewWideIntObj(all ? all-1 : 1));
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_RegsubObjCmd --
 *
 *	This procedure is invoked to process the "regsub" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_RegsubObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int result, cflags, all, match, command;
    Tcl_Size idx, wlen, wsublen = 0, offset, numMatches, numParts;
    Tcl_Size start, end, subStart, subEnd;
    Tcl_RegExp regExpr;
    Tcl_RegExpInfo info;
    Tcl_Obj *resultPtr, *subPtr, *objPtr, *startIndex = NULL;
    Tcl_UniChar ch, *wsrc, *wfirstChar, *wstring, *wsubspec = 0, *wend;

    static const char *const options[] = {
	"-all",		"-command",	"-expanded",	"-line",
	"-linestop",	"-lineanchor",	"-nocase",	"-start",
	"--",		NULL
    };
    enum regsubobjoptions {
	REGSUB_ALL,	 REGSUB_COMMAND,    REGSUB_EXPANDED, REGSUB_LINE,
	REGSUB_LINESTOP, REGSUB_LINEANCHOR, REGSUB_NOCASE,   REGSUB_START,
	REGSUB_LAST
    } index;

    cflags = TCL_REG_ADVANCED;
    all = 0;
    offset = TCL_INDEX_START;
    command = 0;
    resultPtr = NULL;

    for (idx = 1; idx < objc; idx++) {
	const char *name;

	name = TclGetString(objv[idx]);
	if (name[0] != '-') {
	    break;
	}
	if (Tcl_GetIndexFromObj(interp, objv[idx], options, "option",
		TCL_EXACT, &index) != TCL_OK) {
	    goto optionError;
	}
	switch (index) {
	case REGSUB_ALL:
	    all = 1;
	    break;
	case REGSUB_NOCASE:
	    cflags |= TCL_REG_NOCASE;
	    break;
	case REGSUB_COMMAND:
	    command = 1;
	    break;
	case REGSUB_EXPANDED:
	    cflags |= TCL_REG_EXPANDED;
	    break;
	case REGSUB_LINE:
	    cflags |= TCL_REG_NEWLINE;
	    break;
	case REGSUB_LINESTOP:
	    cflags |= TCL_REG_NLSTOP;
	    break;
	case REGSUB_LINEANCHOR:
	    cflags |= TCL_REG_NLANCH;
	    break;
	case REGSUB_START: {
	    Tcl_Size temp;
	    if (++idx >= objc) {
		goto endOfForLoop;
	    }
	    if (TclGetIntForIndexM(interp, objv[idx], TCL_SIZE_MAX - 1, &temp) != TCL_OK) {
		goto optionError;
	    }
	    if (startIndex) {
		Tcl_DecrRefCount(startIndex);
	    }
	    startIndex = objv[idx];
	    Tcl_IncrRefCount(startIndex);
	    break;
	}
	case REGSUB_LAST:
	    idx++;
	    goto endOfForLoop;
	default:
	    TCL_UNREACHABLE();
	}
    }

  endOfForLoop:
    if (objc < idx + 3 || objc > idx + 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-option ...? exp string subSpec ?varName?");
    optionError:
	if (startIndex) {
	    Tcl_DecrRefCount(startIndex);
	}
	return TCL_ERROR;
    }

    objc -= idx;
    objv += idx;

    if (startIndex) {
	Tcl_Size stringLength = Tcl_GetCharLength(objv[1]);

	TclGetIntForIndexM(interp, startIndex, stringLength, &offset);
	Tcl_DecrRefCount(startIndex);
	if (offset < 0) {
	    offset = 0;
	}
    }

    if (all && (offset == 0) && (command == 0)
	    && (strpbrk(TclGetString(objv[2]), "&\\") == NULL)
	    && (strpbrk(TclGetString(objv[0]), "*+?{}()[].\\|^$") == NULL)) {
	/*
	 * This is a simple one pair string map situation. We make use of a
	 * slightly modified version of the one pair STR_MAP code.
	 */

	Tcl_Size slen;
	int nocase, wsrclc;
	int (*strCmpFn)(const Tcl_UniChar*,const Tcl_UniChar*,size_t);
	Tcl_UniChar *p;

	numMatches = 0;
	nocase = (cflags & TCL_REG_NOCASE);
	strCmpFn = nocase ? TclUniCharNcasecmp : TclUniCharNcmp;

	wsrc = Tcl_GetUnicodeFromObj(objv[0], &slen);
	wstring = Tcl_GetUnicodeFromObj(objv[1], &wlen);
	wsubspec = Tcl_GetUnicodeFromObj(objv[2], &wsublen);
	wend = wstring + wlen - (slen ? slen - 1 : 0);
	result = TCL_OK;

	if (slen == 0) {
	    /*
	     * regsub behavior for "" matches between each character. 'string
	     * map' skips the "" case.
	     */

	    if (wstring < wend) {
		resultPtr = Tcl_NewUnicodeObj(wstring, 0);
		Tcl_IncrRefCount(resultPtr);
		for (; wstring < wend; wstring++) {
		    Tcl_AppendUnicodeToObj(resultPtr, wsubspec, wsublen);
		    Tcl_AppendUnicodeToObj(resultPtr, wstring, 1);
		    numMatches++;
		}
		wlen = 0;
	    }
	} else {
	    wsrclc = Tcl_UniCharToLower(*wsrc);
	    for (p = wfirstChar = wstring; wstring < wend; wstring++) {
		if ((*wstring == *wsrc ||
			(nocase && Tcl_UniCharToLower(*wstring)==wsrclc)) &&
			(slen==1 || (strCmpFn(wstring, wsrc, slen) == 0))) {
		    if (numMatches == 0) {
			resultPtr = Tcl_NewUnicodeObj(wstring, 0);
			Tcl_IncrRefCount(resultPtr);
		    }
		    if (p != wstring) {
			Tcl_AppendUnicodeToObj(resultPtr, p, wstring - p);
			p = wstring + slen;
		    } else {
			p += slen;
		    }
		    wstring = p - 1;

		    Tcl_AppendUnicodeToObj(resultPtr, wsubspec, wsublen);
		    numMatches++;
		}
	    }
	    if (numMatches) {
		wlen    = wfirstChar + wlen - p;
		wstring = p;
	    }
	}
	objPtr = NULL;
	subPtr = NULL;
	goto regsubDone;
    }

    regExpr = Tcl_GetRegExpFromObj(interp, objv[0], cflags);
    if (regExpr == NULL) {
	return TCL_ERROR;
    }

    if (command) {
	/*
	 * In command-prefix mode, we require that the third non-option
	 * argument be a list, so we enforce that here. Afterwards, we fetch
	 * the RE compilation again in case objv[0] and objv[2] are the same
	 * object. (If they aren't, that's cheap to do.)
	 */

	if (TclListObjLength(interp, objv[2], &numParts) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (numParts < 1) {
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(
		    "command prefix must be a list of at least one element",
		    -1));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "REGSUB",
		    "CMDEMPTY", (char *)NULL);
	    return TCL_ERROR;
	}
	regExpr = Tcl_GetRegExpFromObj(interp, objv[0], cflags);
    }

    /*
     * Make sure to avoid problems where the objects are shared. This can
     * cause RegExpObj <> UnicodeObj shimmering that causes data corruption.
     * [Bug #461322]
     */

    if (objv[1] == objv[0]) {
	objPtr = Tcl_DuplicateObj(objv[1]);
    } else {
	objPtr = objv[1];
    }
    wstring = Tcl_GetUnicodeFromObj(objPtr, &wlen);
    if (objv[2] == objv[0]) {
	subPtr = Tcl_DuplicateObj(objv[2]);
    } else {
	subPtr = objv[2];
    }
    if (!command) {
	wsubspec = Tcl_GetUnicodeFromObj(subPtr, &wsublen);
    }

    result = TCL_OK;

    /*
     * The following loop is to handle multiple matches within the same source
     * string; each iteration handles one match and its corresponding
     * substitution. If "-all" hasn't been specified then the loop body only
     * gets executed once. We must use 'offset <= wlen' in particular for the
     * case where the regexp pattern can match the empty string - this is
     * useful when doing, say, 'regsub -- ^ $str ...' when $str might be
     * empty.
     */

    numMatches = 0;
    for ( ; offset <= wlen; ) {

	/*
	 * The flags argument is set if string is part of a larger string, so
	 * that "^" won't match.
	 */

	match = Tcl_RegExpExecObj(interp, regExpr, objPtr, offset,
		10 /* matches */, ((offset > 0 &&
		(wstring[offset-1] != (Tcl_UniChar)'\n'))
		? TCL_REG_NOTBOL : 0));

	if (match < 0) {
	    result = TCL_ERROR;
	    goto done;
	}
	if (match == 0) {
	    break;
	}
	if (numMatches == 0) {
	    resultPtr = Tcl_NewUnicodeObj(wstring, 0);
	    Tcl_IncrRefCount(resultPtr);
	    if (offset > TCL_INDEX_START) {
		/*
		 * Copy the initial portion of the string in if an offset was
		 * specified.
		 */

		Tcl_AppendUnicodeToObj(resultPtr, wstring, offset);
	    }
	}
	numMatches++;

	/*
	 * Copy the portion of the source string before the match to the
	 * result variable.
	 */

	Tcl_RegExpGetInfo(regExpr, &info);
	start = info.matches[0].start;
	end = info.matches[0].end;
	Tcl_AppendUnicodeToObj(resultPtr, wstring + offset, start);

	/*
	 * In command-prefix mode, the substitutions are added as quoted
	 * arguments to the subSpec to form a command, that is then executed
	 * and the result used as the string to substitute in. Actually,
	 * everything is passed through Tcl_EvalObjv, as that's much faster.
	 */

	if (command) {
	    Tcl_Obj **args = NULL, **parts;
	    Tcl_Size numArgs;

	    TclListObjGetElements(interp, subPtr, &numParts, &parts);
	    numArgs = numParts + info.nsubs + 1;
	    args = (Tcl_Obj **)Tcl_Alloc(sizeof(Tcl_Obj*) * numArgs);
	    memcpy(args, parts, sizeof(Tcl_Obj*) * numParts);

	    for (idx = 0 ; idx <= info.nsubs ; idx++) {
		subStart = info.matches[idx].start;
		subEnd = info.matches[idx].end;
		if ((subStart >= 0) && (subEnd >= 0)) {
		    args[idx + numParts] = Tcl_NewUnicodeObj(
			    wstring + offset + subStart, subEnd - subStart);
		} else {
		    args[idx + numParts] = Tcl_NewObj();
		}
		Tcl_IncrRefCount(args[idx + numParts]);
	    }

	    /*
	     * At this point, we're locally holding the references to the
	     * argument words we added for this time round the loop, and the
	     * subPtr is holding the references to the words that the user
	     * supplied directly. None are zero-refcount, which is important
	     * because Tcl_EvalObjv is "hairy monster" in terms of refcount
	     * handling, being able to optionally add references to any of its
	     * argument words. We'll drop the local refs immediately
	     * afterwards; subPtr is handled in the main exit stanza.
	     */

	    result = Tcl_EvalObjv(interp, numArgs, args, 0);
	    for (idx = 0 ; idx <= info.nsubs ; idx++) {
		TclDecrRefCount(args[idx + numParts]);
	    }
	    Tcl_Free(args);
	    if (result != TCL_OK) {
		if (result == TCL_ERROR) {
		    Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
			    "\n    (%s substitution computation script)",
			    options[REGSUB_COMMAND]));
		}
		goto done;
	    }

	    Tcl_AppendObjToObj(resultPtr, Tcl_GetObjResult(interp));
	    Tcl_ResetResult(interp);

	    /*
	     * Refetch the unicode, in case the representation was smashed by
	     * the user code.
	     */

	    wstring = Tcl_GetUnicodeFromObj(objPtr, &wlen);

	    offset += end;
	    if (end == 0 || start == end) {
		/*
		 * Always consume at least one character of the input string
		 * in order to prevent infinite loops, even when we
		 * technically matched the empty string; we must not match
		 * again at the same spot.
		 */

		if (offset < wlen) {
		    Tcl_AppendUnicodeToObj(resultPtr, wstring + offset, 1);
		}
		offset++;
	    }
	    if (all) {
		continue;
	    } else {
		break;
	    }
	}

	/*
	 * Append the subSpec argument to the variable, making appropriate
	 * substitutions. This code is a bit hairy because of the backslash
	 * conventions and because the code saves up ranges of characters in
	 * subSpec to reduce the number of calls to Tcl_SetVar.
	 */

	wsrc = wfirstChar = wsubspec;
	wend = wsubspec + wsublen;
	for (ch = *wsrc; wsrc != wend; wsrc++, ch = *wsrc) {
	    if (ch == '&') {
		idx = 0;
	    } else if (ch == '\\') {
		ch = wsrc[1];
		if ((ch >= '0') && (ch <= '9')) {
		    idx = ch - '0';
		} else if ((ch == '\\') || (ch == '&')) {
		    *wsrc = ch;
		    Tcl_AppendUnicodeToObj(resultPtr, wfirstChar,
			    wsrc - wfirstChar + 1);
		    *wsrc = '\\';
		    wfirstChar = wsrc + 2;
		    wsrc++;
		    continue;
		} else {
		    continue;
		}
	    } else {
		continue;
	    }

	    if (wfirstChar != wsrc) {
		Tcl_AppendUnicodeToObj(resultPtr, wfirstChar,
			wsrc - wfirstChar);
	    }

	    if (idx <= info.nsubs) {
		subStart = info.matches[idx].start;
		subEnd = info.matches[idx].end;
		if ((subStart >= 0) && (subEnd >= 0)) {
		    Tcl_AppendUnicodeToObj(resultPtr,
			    wstring + offset + subStart, subEnd - subStart);
		}
	    }

	    if (*wsrc == '\\') {
		wsrc++;
	    }
	    wfirstChar = wsrc + 1;
	}

	if (wfirstChar != wsrc) {
	    Tcl_AppendUnicodeToObj(resultPtr, wfirstChar, wsrc - wfirstChar);
	}

	if (end == 0) {
	    /*
	     * Always consume at least one character of the input string in
	     * order to prevent infinite loops.
	     */

	    if (offset < wlen) {
		Tcl_AppendUnicodeToObj(resultPtr, wstring + offset, 1);
	    }
	    offset++;
	} else {
	    offset += end;
	    if (start == end) {
		/*
		 * We matched an empty string, which means we must go forward
		 * one more step so we don't match again at the same spot.
		 */

		if (offset < wlen) {
		    Tcl_AppendUnicodeToObj(resultPtr, wstring + offset, 1);
		}
		offset++;
	    }
	}
	if (!all) {
	    break;
	}
    }

    /*
     * Copy the portion of the source string after the last match to the
     * result variable.
     */

  regsubDone:
    if (numMatches == 0) {
	/*
	 * On zero matches, just ignore the offset, since it shouldn't matter
	 * to us in this case, and the user may have skewed it.
	 */

	resultPtr = objv[1];
	Tcl_IncrRefCount(resultPtr);
    } else if (offset < wlen) {
	Tcl_AppendUnicodeToObj(resultPtr, wstring + offset, wlen - offset);
    }
    if (objc == 4) {
	if (Tcl_ObjSetVar2(interp, objv[3], NULL, resultPtr,
		TCL_LEAVE_ERR_MSG) == NULL) {
	    result = TCL_ERROR;
	} else {
	    /*
	     * Set the interpreter's object result to an integer object
	     * holding the number of matches.
	     */

	    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(numMatches));
	}
    } else {
	/*
	 * No varname supplied, so just return the modified string.
	 */

	Tcl_SetObjResult(interp, resultPtr);
    }

  done:
    if (objPtr && (objv[1] == objv[0])) {
	Tcl_DecrRefCount(objPtr);
    }
    if (subPtr && (objv[2] == objv[0])) {
	Tcl_DecrRefCount(subPtr);
    }
    if (resultPtr) {
	Tcl_DecrRefCount(resultPtr);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_RenameObjCmd --
 *
 *	This procedure is invoked to process the "rename" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_RenameObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *oldName, *newName;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "oldName newName");
	return TCL_ERROR;
    }

    oldName = TclGetString(objv[1]);
    newName = TclGetString(objv[2]);
    return TclRenameCommand(interp, oldName, newName);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ReturnObjCmd --
 *
 *	This object-based procedure is invoked to process the "return" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ReturnObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int code, level;
    Tcl_Obj *returnOpts;

    /*
     * General syntax: [return ?-option value ...? ?result?]
     * An even number of words means an explicit result argument is present.
     */

    int explicitResult = (0 == (objc % 2));
    int numOptionWords = objc - 1 - explicitResult;

    if (TCL_ERROR == TclMergeReturnOptions(interp, numOptionWords, objv+1,
	    &returnOpts, &code, &level)) {
	return TCL_ERROR;
    }

    code = TclProcessReturn(interp, code, level, returnOpts);
    if (explicitResult) {
	Tcl_SetObjResult(interp, objv[objc-1]);
    }
    return code;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SourceObjCmd --
 *
 *	This procedure is invoked to process the "source" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_SourceObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRSourceObjCmd, clientData, objc, objv);
}

int
TclNRSourceObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *encodingName = NULL;
    Tcl_Obj *fileName;
    int result;
    void **pkgFiles = NULL;
    void *names = NULL;

    if (objc < 2 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-encoding encoding? fileName");
	return TCL_ERROR;
    }

    fileName = objv[objc-1];

    if (objc == 4) {
	static const char *const options[] = {
	    "-encoding", NULL
	};
	int index;

	if (TCL_ERROR == Tcl_GetIndexFromObj(interp, objv[1], options,
		"option", TCL_EXACT, &index)) {
	    return TCL_ERROR;
	}
	encodingName = TclGetString(objv[2]);
    } else if (objc == 3) {
	/* Handle undocumented -nopkg option. This should only be
	 * used by the internal ::tcl::Pkg::source utility function. */
	static const char *const nopkgoptions[] = {
	    "-nopkg", NULL
	};
	int index;

	if (TCL_ERROR == Tcl_GetIndexFromObj(interp, objv[1], nopkgoptions,
		"option", TCL_EXACT, &index)) {
	    return TCL_ERROR;
	}
	pkgFiles = (void **)Tcl_GetAssocData(interp, "tclPkgFiles", NULL);
	/* Make sure that during the following TclNREvalFile no filenames
	 * are recorded for inclusion in the "package files" command */
	names = *pkgFiles;
	*pkgFiles = NULL;
    }
    result = TclNREvalFile(interp, fileName, encodingName);
    if (pkgFiles) {
	/* restore "tclPkgFiles" assocdata to how it was. */
	*pkgFiles = names;
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SplitObjCmd --
 *
 *	This procedure is invoked to process the "split" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_SplitObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int ch = 0;
    int len;
    const char *splitChars;
    const char *stringPtr;
    const char *end;
    Tcl_Size splitCharLen, stringLen;
    Tcl_Obj *listPtr, *objPtr;

    if (objc == 2) {
	splitChars = " \n\t\r";
	splitCharLen = 4;
    } else if (objc == 3) {
	splitChars = TclGetStringFromObj(objv[2], &splitCharLen);
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?splitChars?");
	return TCL_ERROR;
    }

    stringPtr = TclGetStringFromObj(objv[1], &stringLen);
    end = stringPtr + stringLen;
    TclNewObj(listPtr);

    if (stringLen == 0) {
	/*
	 * Do nothing.
	 */
    } else if (splitCharLen == 0) {
	Tcl_HashTable charReuseTable;
	Tcl_HashEntry *hPtr;
	int isNew;

	/*
	 * Handle the special case of splitting on every character.
	 *
	 * Uses a hash table to ensure that each kind of character has only
	 * one Tcl_Obj instance (multiply-referenced) in the final list. This
	 * is a *major* win when splitting on a long string (especially in the
	 * megabyte range!) - DKF
	 */

	Tcl_InitHashTable(&charReuseTable, TCL_ONE_WORD_KEYS);

	for ( ; stringPtr < end; stringPtr += len) {
	    len = TclUtfToUniChar(stringPtr, &ch);
	    hPtr = Tcl_CreateHashEntry(&charReuseTable, INT2PTR(ch), &isNew);
	    if (isNew) {
		TclNewStringObj(objPtr, stringPtr, len);

		/*
		 * Don't need to fiddle with refcount...
		 */

		Tcl_SetHashValue(hPtr, objPtr);
	    } else {
		objPtr = (Tcl_Obj *)Tcl_GetHashValue(hPtr);
	    }
	    Tcl_ListObjAppendElement(NULL, listPtr, objPtr);
	}
	Tcl_DeleteHashTable(&charReuseTable);

    } else if (splitCharLen == 1) {
	const char *p;

	/*
	 * Handle the special case of splitting on a single character. This is
	 * only true for the one-char ASCII case, as one Unicode char is > 1
	 * byte in length.
	 */

	while (*stringPtr && (p=strchr(stringPtr,*splitChars)) != NULL) {
	    objPtr = Tcl_NewStringObj(stringPtr, p - stringPtr);
	    Tcl_ListObjAppendElement(NULL, listPtr, objPtr);
	    stringPtr = p + 1;
	}
	TclNewStringObj(objPtr, stringPtr, end - stringPtr);
	Tcl_ListObjAppendElement(NULL, listPtr, objPtr);
    } else {
	const char *element, *p, *splitEnd;
	Tcl_Size splitLen;
	int splitChar;

	/*
	 * Normal case: split on any of a given set of characters. Discard
	 * instances of the split characters.
	 */

	splitEnd = splitChars + splitCharLen;

	for (element = stringPtr; stringPtr < end; stringPtr += len) {
	    len = TclUtfToUniChar(stringPtr, &ch);
	    for (p = splitChars; p < splitEnd; p += splitLen) {
		splitLen = TclUtfToUniChar(p, &splitChar);
		if (ch == splitChar) {
		    TclNewStringObj(objPtr, element, stringPtr - element);
		    Tcl_ListObjAppendElement(NULL, listPtr, objPtr);
		    element = stringPtr + len;
		    break;
		}
	    }
	}

	TclNewStringObj(objPtr, element, stringPtr - element);
	Tcl_ListObjAppendElement(NULL, listPtr, objPtr);
    }
    Tcl_SetObjResult(interp, listPtr);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringFirstCmd --
 *
 *	This procedure is invoked to process the "string first" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringFirstCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size start = TCL_INDEX_START;

    if (objc < 3 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"needleString haystackString ?startIndex?");
	return TCL_ERROR;
    }

    if (objc == 4) {
	Tcl_Size end = Tcl_GetCharLength(objv[2]) - 1;

	if (TCL_OK != TclGetIntForIndexM(interp, objv[3], end, &start)) {
	    return TCL_ERROR;
	}
    }
    Tcl_SetObjResult(interp, TclStringFirst(objv[1], objv[2], start));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringLastCmd --
 *
 *	This procedure is invoked to process the "string last" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringLastCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size last = TCL_SIZE_MAX;

    if (objc < 3 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"needleString haystackString ?lastIndex?");
	return TCL_ERROR;
    }

    if (objc == 4) {
	Tcl_Size end = Tcl_GetCharLength(objv[2]) - 1;

	if (TCL_OK != TclGetIntForIndexM(interp, objv[3], end, &last)) {
	    return TCL_ERROR;
	}
    }
    Tcl_SetObjResult(interp, TclStringLast(objv[1], objv[2], last));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringIndexCmd --
 *
 *	This procedure is invoked to process the "string index" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringIndexCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size index, end;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "string charIndex");
	return TCL_ERROR;
    }

    /*
     * Get the char length to calculate what 'end' means.
     */

    end = Tcl_GetCharLength(objv[1]) - 1;
    if (TclGetIntForIndexM(interp, objv[2], end, &index) != TCL_OK) {
	return TCL_ERROR;
    }

    if ((index >= 0) && (index <= end)) {
	int ch = Tcl_GetUniChar(objv[1], index);

	if (ch == -1) {
	    return TCL_OK;
	}

	/*
	 * If we have a ByteArray object, we're careful to generate a new
	 * bytearray for a result.
	 */

	if (TclIsPureByteArray(objv[1])) {
	    unsigned char uch = UCHAR(ch);

	    Tcl_SetObjResult(interp, Tcl_NewByteArrayObj(&uch, 1));
	} else {
	    char buf[4] = "";

	    end = Tcl_UniCharToUtf(ch, buf);
	    Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, end));
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringInsertCmd --
 *
 *	This procedure is invoked to process the "string insert" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringInsertCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter */
    int objc,			/* Number of arguments */
    Tcl_Obj *const objv[])	/* Argument objects */
{
    Tcl_Size length;		/* String length */
    Tcl_Size index;		/* Insert index */
    Tcl_Obj *outObj;		/* Output object */

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "string index insertString");
	return TCL_ERROR;
    }

    length = Tcl_GetCharLength(objv[1]);
    if (TclGetIntForIndexM(interp, objv[2], length, &index) != TCL_OK) {
	return TCL_ERROR;
    }

    if (index < 0) {
	index = TCL_INDEX_START;
    }
    if (index > length) {
	index = length;
    }

    outObj = TclStringReplace(interp, objv[1], index, 0, objv[3],
	    TCL_STRING_IN_PLACE);

    if (outObj != NULL) {
	Tcl_SetObjResult(interp, outObj);
	return TCL_OK;
    }

    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * StringIsCmd --
 *
 *	This procedure is invoked to process the "string is" Tcl command. See
 *	the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringIsCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *string1, *end, *stop;
    int (*chcomp)(int) = NULL;	/* The UniChar comparison function. */
    int i, result = 1, strict = 0;
    Tcl_Size failat = 0, length1, length2, length3;
    Tcl_Obj *objPtr, *failVarObj = NULL;
    Tcl_WideInt w;

    static const char *const isClasses[] = {
	"alnum",	"alpha",	"ascii",	"control",
	"boolean",	"dict",		"digit",	"double",
	"entier",	"false",	"graph",	"integer",
	"list",		"lower",	"print",	"punct",
	"space",	"true",		"upper",
	"wideinteger", "wordchar",	"xdigit",	NULL
    };
    enum isClassesEnum {
	STR_IS_ALNUM,	STR_IS_ALPHA,	STR_IS_ASCII,	STR_IS_CONTROL,
	STR_IS_BOOL,	STR_IS_DICT,	STR_IS_DIGIT,	STR_IS_DOUBLE,
	STR_IS_ENTIER,	STR_IS_FALSE,	STR_IS_GRAPH,	STR_IS_INT,
	STR_IS_LIST,	STR_IS_LOWER,	STR_IS_PRINT,	STR_IS_PUNCT,
	STR_IS_SPACE,	STR_IS_TRUE,	STR_IS_UPPER,
	STR_IS_WIDE,	STR_IS_WORD,	STR_IS_XDIGIT
    } index;
    static const char *const isOptions[] = {
	"-strict", "-failindex", NULL
    };
    enum isOptionsEnum {
	OPT_STRICT, OPT_FAILIDX
    } idx2;

    if (objc < 3 || objc > 6) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"class ?-strict? ?-failindex var? str");
	return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(interp, objv[1], isClasses, "class", 0,
	    &index) != TCL_OK) {
	return TCL_ERROR;
    }

    if (objc != 3) {
	for (i = 2; i < objc-1; i++) {
	    if (Tcl_GetIndexFromObj(interp, objv[i], isOptions, "option", 0,
		    &idx2) != TCL_OK) {
		return TCL_ERROR;
	    }
	    switch (idx2) {
	    case OPT_STRICT:
		strict = 1;
		break;
	    case OPT_FAILIDX:
		if (i+1 >= objc-1) {
		    Tcl_WrongNumArgs(interp, 2, objv,
			    "?-strict? ?-failindex var? str");
		    return TCL_ERROR;
		}
		failVarObj = objv[++i];
		break;
	    default:
		TCL_UNREACHABLE();
	    }
	}
    }

    /*
     * We get the objPtr so that we can short-cut for some classes by checking
     * the object type (int and double), but we need the string otherwise,
     * because we don't want any conversion of type occurring (as, for example,
     * Tcl_Get*FromObj would do).
     */

    objPtr = objv[objc-1];

    /*
     * When entering here, result == 1 and failat == 0.
     */

    switch (index) {
    case STR_IS_ALNUM:
	chcomp = Tcl_UniCharIsAlnum;
	break;
    case STR_IS_ALPHA:
	chcomp = Tcl_UniCharIsAlpha;
	break;
    case STR_IS_ASCII:
	chcomp = UniCharIsAscii;
	break;
    case STR_IS_BOOL:
    case STR_IS_TRUE:
    case STR_IS_FALSE:
	if (!TclHasInternalRep(objPtr, &tclBooleanType)
		&& (TCL_OK != TclSetBooleanFromAny(NULL, objPtr))) {
	    if (strict) {
		result = 0;
	    } else {
		string1 = TclGetStringFromObj(objPtr, &length1);
		result = length1 == 0;
	    }
	} else if ((objPtr->internalRep.wideValue != 0)
		? (index == STR_IS_FALSE) : (index == STR_IS_TRUE)) {
	    result = 0;
	}
	break;
    case STR_IS_CONTROL:
	chcomp = Tcl_UniCharIsControl;
	break;
    case STR_IS_DICT: {
	int dresult;
	Tcl_Size dsize;

	dresult = Tcl_DictObjSize(interp, objPtr, &dsize);
	Tcl_ResetResult(interp);
	result = (dresult == TCL_OK) ? 1 : 0;
	if (dresult != TCL_OK && failVarObj != NULL) {
	    /*
	     * Need to figure out where the list parsing failed, which is
	     * fairly expensive. This is adapted from the core of
	     * SetDictFromAny().
	     */

	    const char *elemStart, *nextElem;
	    Tcl_Size lenRemain, elemSize;
	    const char *p;

	    string1 = TclGetStringFromObj(objPtr, &length1);
	    end = string1 + length1;
	    failat = -1;
	    for (p=string1, lenRemain=length1; lenRemain > 0;
		    p=nextElem, lenRemain=end-nextElem) {
		if (TCL_ERROR == TclFindElement(NULL, p, lenRemain,
			&elemStart, &nextElem, &elemSize, NULL)) {
		    Tcl_Obj *tmpStr;

		    /*
		     * This is the simplest way of getting the number of
		     * characters parsed. Note that this is not the same as
		     * the number of bytes when parsing strings with non-ASCII
		     * characters in them.
		     *
		     * Skip leading spaces first. This is only really an issue
		     * if it is the first "element" that has the failure.
		     */

		    while (TclIsSpaceProc(*p)) {
			p++;
		    }
		    TclNewStringObj(tmpStr, string1, p-string1);
		    failat = Tcl_GetCharLength(tmpStr);
		    TclDecrRefCount(tmpStr);
		    break;
		}
	    }
	}
	break;
    }
    case STR_IS_DIGIT:
	chcomp = Tcl_UniCharIsDigit;
	break;
    case STR_IS_DOUBLE: {
	if (TclHasInternalRep(objPtr, &tclDoubleType) ||
		TclHasInternalRep(objPtr, &tclIntType) ||
		TclHasInternalRep(objPtr, &tclBignumType)) {
	    break;
	}
	string1 = TclGetStringFromObj(objPtr, &length1);
	if (length1 == 0) {
	    if (strict) {
		result = 0;
	    }
	    goto str_is_done;
	}
	end = string1 + length1;
	if (TclParseNumber(NULL, objPtr, NULL, NULL, TCL_INDEX_NONE,
		(const char **) &stop, 0) != TCL_OK) {
	    result = 0;
	    failat = 0;
	} else {
	    failat = stop - string1;
	    if (stop < end) {
		result = 0;
		TclFreeInternalRep(objPtr);
	    }
	}
	break;
    }
    case STR_IS_GRAPH:
	chcomp = Tcl_UniCharIsGraph;
	break;
    case STR_IS_INT:
    case STR_IS_ENTIER:
	if (TclHasInternalRep(objPtr, &tclIntType) ||
		TclHasInternalRep(objPtr, &tclBignumType)) {
	    break;
	}
	string1 = TclGetStringFromObj(objPtr, &length1);
	if (length1 == 0) {
	    if (strict) {
		result = 0;
	    }
	    goto str_is_done;
	}
	end = string1 + length1;
	if (TclParseNumber(NULL, objPtr, NULL, NULL, TCL_INDEX_NONE,
		(const char **) &stop, TCL_PARSE_INTEGER_ONLY) == TCL_OK) {
	    if (stop == end) {
		/*
		 * Entire string parses as an integer.
		 */

		break;
	    } else {
		/*
		 * Some prefix parsed as an integer, but not the whole string,
		 * so return failure index as the point where parsing stopped.
		 * Clear out the internal rep, since keeping it would leave
		 * *objPtr in an inconsistent state.
		 */

		result = 0;
		failat = stop - string1;
		TclFreeInternalRep(objPtr);
	    }
	} else {
	    /*
	     * No prefix is a valid integer. Fail at beginning.
	     */

	    result = 0;
	    failat = 0;
	}
	break;
    case STR_IS_WIDE:
	if (TCL_OK == TclGetWideIntFromObj(NULL, objPtr, &w)) {
	    break;
	}

	string1 = TclGetStringFromObj(objPtr, &length1);
	if (length1 == 0) {
	    if (strict) {
		result = 0;
	    }
	    goto str_is_done;
	}
	result = 0;
	if (failVarObj == NULL) {
	    /*
	     * Don't bother computing the failure point if we're not going to
	     * return it.
	     */

	    break;
	}
	end = string1 + length1;
	if (TclParseNumber(NULL, objPtr, NULL, NULL, TCL_INDEX_NONE,
		(const char **) &stop, TCL_PARSE_INTEGER_ONLY) == TCL_OK) {
	    if (stop == end) {
		/*
		 * Entire string parses as an integer, but rejected by
		 * Tcl_Get(Wide)IntFromObj() so we must have overflowed the
		 * target type, and our convention is to return failure at
		 * index -1 in that situation.
		 */

		failat = -1;
	    } else {
		/*
		 * Some prefix parsed as an integer, but not the whole string,
		 * so return failure index as the point where parsing stopped.
		 * Clear out the internal rep, since keeping it would leave
		 * *objPtr in an inconsistent state.
		 */

		failat = stop - string1;
		TclFreeInternalRep(objPtr);
	    }
	} else {
	    /*
	     * No prefix is a valid integer. Fail at beginning.
	     */

	    failat = 0;
	}
	break;
    case STR_IS_LIST:
	/*
	 * We ignore the strictness here, since empty strings are always
	 * well-formed lists.
	 */

	if (TCL_OK == TclListObjLength(NULL, objPtr, &length3)) {
	    break;
	}

	if (failVarObj != NULL) {
	    /*
	     * Need to figure out where the list parsing failed, which is
	     * fairly expensive. This is adapted from the core of
	     * SetListFromAny().
	     */

	    const char *elemStart, *nextElem;
	    Tcl_Size lenRemain;
	    Tcl_Size elemSize;
	    const char *p;

	    string1 = TclGetStringFromObj(objPtr, &length1);
	    end = string1 + length1;
	    failat = -1;
	    for (p=string1, lenRemain=length1; lenRemain > 0;
		    p=nextElem, lenRemain=end-nextElem) {
		if (TCL_ERROR == TclFindElement(NULL, p, lenRemain,
			&elemStart, &nextElem, &elemSize, NULL)) {
		    Tcl_Obj *tmpStr;

		    /*
		     * This is the simplest way of getting the number of
		     * characters parsed. Note that this is not the same as
		     * the number of bytes when parsing strings with non-ASCII
		     * characters in them.
		     *
		     * Skip leading spaces first. This is only really an issue
		     * if it is the first "element" that has the failure.
		     */

		    while (TclIsSpaceProcM(*p)) {
			p++;
		    }
		    TclNewStringObj(tmpStr, string1, p-string1);
		    failat = Tcl_GetCharLength(tmpStr);
		    TclDecrRefCount(tmpStr);
		    break;
		}
	    }
	}
	result = 0;
	break;
    case STR_IS_LOWER:
	chcomp = Tcl_UniCharIsLower;
	break;
    case STR_IS_PRINT:
	chcomp = Tcl_UniCharIsPrint;
	break;
    case STR_IS_PUNCT:
	chcomp = Tcl_UniCharIsPunct;
	break;
    case STR_IS_SPACE:
	chcomp = Tcl_UniCharIsSpace;
	break;
    case STR_IS_UPPER:
	chcomp = Tcl_UniCharIsUpper;
	break;
    case STR_IS_WORD:
	chcomp = Tcl_UniCharIsWordChar;
	break;
    case STR_IS_XDIGIT:
	chcomp = UniCharIsHexDigit;
	break;
    default:
	TCL_UNREACHABLE();
    }

    if (chcomp != NULL) {
	string1 = TclGetStringFromObj(objPtr, &length1);
	if (length1 == 0) {
	    if (strict) {
		result = 0;
	    }
	    goto str_is_done;
	}
	end = string1 + length1;
	for (; string1 < end; string1 += length2, failat++) {
	    int ucs4;

	    length2 = TclUtfToUniChar(string1, &ucs4);
	    if (!chcomp(ucs4)) {
		result = 0;
		break;
	    }
	}
    }

    /*
     * Only set the failVarObj when we will return 0 and we have indicated a
     * valid fail index (>= 0).
     */

 str_is_done:
    if ((result == 0) && (failVarObj != NULL)) {
	TclNewIndexObj(objPtr, failat);
	if (Tcl_ObjSetVar2(interp, failVarObj, NULL, objPtr, TCL_LEAVE_ERR_MSG) == NULL) {
	    return TCL_ERROR;
	}
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(result));
    return TCL_OK;
}

static int
UniCharIsAscii(
    int character)
{
    return (character >= 0) && (character < 0x80);
}

static int
UniCharIsHexDigit(
    int character)
{
    return (character >= 0) && (character < 0x80) && isxdigit(UCHAR(character));
}

/*
 *----------------------------------------------------------------------
 *
 * StringMapCmd --
 *
 *	This procedure is invoked to process the "string map" Tcl command. See
 *	the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringMapCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size length1, length2,  mapElemc, index;
    int nocase = 0, mapWithDict = 0, copySource = 0;
    Tcl_Obj **mapElemv, *sourceObj, *resultPtr;
    Tcl_UniChar *ustring1, *ustring2, *p, *end;
    int (*strCmpFn)(const Tcl_UniChar*, const Tcl_UniChar*, size_t);

    if (objc < 3 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-nocase? charMap string");
	return TCL_ERROR;
    }

    if (objc == 4) {
	const char *string = TclGetStringFromObj(objv[1], &length2);

	if ((length2 > 1) &&
		strncmp(string, "-nocase", length2) == 0) {
	    nocase = 1;
	} else {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad option \"%s\": must be -nocase", string));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "INDEX", "option",
		    string, (char *)NULL);
	    return TCL_ERROR;
	}
    }

    /*
     * This test is tricky, but has to be that way or you get other strange
     * inconsistencies (see test string-10.20.1 for illustration why!)
     */

    if (!TclHasStringRep(objv[objc-2])
	    && TclHasInternalRep(objv[objc-2], &tclDictType)) {
	Tcl_Size i;
	int done;
	Tcl_DictSearch search;

	/*
	 * We know the type exactly, so all dict operations will succeed for
	 * sure. This shortens this code quite a bit.
	 */

	Tcl_DictObjSize(interp, objv[objc-2], &i);
	if (i == 0) {
	    /*
	     * Empty charMap, just return whatever string was given.
	     */

	    Tcl_SetObjResult(interp, objv[objc-1]);
	    return TCL_OK;
	}

	mapElemc = 2 * i;
	mapWithDict = 1;

	/*
	 * Copy the dictionary out into an array; that's the easiest way to
	 * adapt this code...
	 */

	mapElemv = (Tcl_Obj **)TclStackAlloc(interp, sizeof(Tcl_Obj *) * mapElemc);
	Tcl_DictObjFirst(interp, objv[objc-2], &search, mapElemv+0,
		mapElemv+1, &done);
	for (index=2 ; index<mapElemc ; index+=2) {
	    Tcl_DictObjNext(&search, mapElemv+index, mapElemv+index+1, &done);
	}
	Tcl_DictObjDone(&search);
    } else {
	Tcl_Size i;
	if (TclListObjGetElements(interp, objv[objc-2], &i,
		&mapElemv) != TCL_OK) {
	    return TCL_ERROR;
	}
	mapElemc = i;
	if (mapElemc == 0) {
	    /*
	     * empty charMap, just return whatever string was given.
	     */

	    Tcl_SetObjResult(interp, objv[objc-1]);
	    return TCL_OK;
	} else if (mapElemc & 1) {
	    /*
	     * The charMap must be an even number of key/value items.
	     */

	    Tcl_SetObjResult(interp,
		    Tcl_NewStringObj("char map list unbalanced", -1));
	    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "MAP",
		    "UNBALANCED", (char *)NULL);
	    return TCL_ERROR;
	}
    }

    /*
     * Take a copy of the source string object if it is the same as the map
     * string to cut out nasty sharing crashes. [Bug 1018562]
     */

    if (objv[objc-2] == objv[objc-1]) {
	sourceObj = Tcl_DuplicateObj(objv[objc-1]);
	copySource = 1;
    } else {
	sourceObj = objv[objc-1];
    }
    ustring1 = Tcl_GetUnicodeFromObj(sourceObj, &length1);
    if (length1 == 0) {
	/*
	 * Empty input string, just stop now.
	 */

	goto done;
    }
    end = ustring1 + length1;

    strCmpFn = nocase ? TclUniCharNcasecmp : TclUniCharNcmp;

    /*
     * Force result to be Unicode
     */

    resultPtr = Tcl_NewUnicodeObj(ustring1, 0);

    if (mapElemc == 2) {
	/*
	 * Special case for one map pair which avoids the extra for loop and
	 * extra calls to get Unicode data. The algorithm is otherwise
	 * identical to the multi-pair case. This will be >30% faster on
	 * larger strings.
	 */

	Tcl_Size mapLen;
	int u2lc;
	Tcl_UniChar *mapString;

	ustring2 = Tcl_GetUnicodeFromObj(mapElemv[0], &length2);
	p = ustring1;
	if ((length2 > length1) || (length2 == 0)) {
	    /*
	     * Match string is either longer than input or empty.
	     */

	    ustring1 = end;
	} else {
	    mapString = Tcl_GetUnicodeFromObj(mapElemv[1], &mapLen);
	    u2lc = (nocase ? Tcl_UniCharToLower(*ustring2) : 0);
	    for (; ustring1 < end; ustring1++) {
		if (((*ustring1 == *ustring2) ||
			(nocase&&Tcl_UniCharToLower(*ustring1)==u2lc)) &&
			(length2==1 || strCmpFn(ustring1, ustring2,
				length2) == 0)) {
		    if (p != ustring1) {
			Tcl_AppendUnicodeToObj(resultPtr, p, ustring1-p);
			p = ustring1 + length2;
		    } else {
			p += length2;
		    }
		    ustring1 = p - 1;

		    Tcl_AppendUnicodeToObj(resultPtr, mapString, mapLen);
		}
	    }
	}
    } else {
	Tcl_UniChar **mapStrings;
	Tcl_Size *mapLens;
	int *u2lc = 0;

	/*
	 * Precompute pointers to the Unicode string and length. This saves us
	 * repeated function calls later, significantly speeding up the
	 * algorithm. We only need the lowercase first char in the nocase
	 * case.
	 */

	mapStrings = (Tcl_UniChar **)TclStackAlloc(interp, mapElemc*sizeof(Tcl_UniChar *)*2);
	mapLens = (Tcl_Size *)TclStackAlloc(interp, mapElemc * sizeof(Tcl_Size) * 2);
	if (nocase) {
	    u2lc = (int *)TclStackAlloc(interp, mapElemc * sizeof(int));
	}
	for (index = 0; index < mapElemc; index++) {
	    mapStrings[index] = Tcl_GetUnicodeFromObj(mapElemv[index],
		    mapLens+index);
	    if (nocase && ((index % 2) == 0)) {
		u2lc[index/2] = Tcl_UniCharToLower(*mapStrings[index]);
	    }
	}
	for (p = ustring1; ustring1 < end; ustring1++) {
	    for (index = 0; index < mapElemc; index += 2) {
		/*
		 * Get the key string to match on.
		 */

		ustring2 = mapStrings[index];
		length2 = mapLens[index];
		if ((length2 > 0) && ((*ustring1 == *ustring2) || (nocase &&
			(Tcl_UniCharToLower(*ustring1) == u2lc[index/2]))) &&
			/* Restrict max compare length. */
			((end-ustring1) >= length2) && ((length2 == 1) ||
			!strCmpFn(ustring2, ustring1, length2))) {
		    if (p != ustring1) {
			/*
			 * Put the skipped chars onto the result first.
			 */

			Tcl_AppendUnicodeToObj(resultPtr, p, ustring1-p);
			p = ustring1 + length2;
		    } else {
			p += length2;
		    }

		    /*
		     * Adjust len to be full length of matched string.
		     */

		    ustring1 = p - 1;

		    /*
		     * Append the map value to the Unicode string.
		     */

		    Tcl_AppendUnicodeToObj(resultPtr,
			    mapStrings[index+1], mapLens[index+1]);
		    break;
		}
	    }
	}
	if (nocase) {
	    TclStackFree(interp, u2lc);
	}
	TclStackFree(interp, mapLens);
	TclStackFree(interp, mapStrings);
    }
    if (p != ustring1) {
	/*
	 * Put the rest of the unmapped chars onto result.
	 */

	Tcl_AppendUnicodeToObj(resultPtr, p, ustring1 - p);
    }
    Tcl_SetObjResult(interp, resultPtr);
  done:
    if (mapWithDict) {
	TclStackFree(interp, mapElemv);
    }
    if (copySource) {
	Tcl_DecrRefCount(sourceObj);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringMatchCmd --
 *
 *	This procedure is invoked to process the "string match" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringMatchCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int nocase = 0;

    if (objc < 3 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "?-nocase? pattern string");
	return TCL_ERROR;
    }

    if (objc == 4) {
	Tcl_Size length;
	const char *string = TclGetStringFromObj(objv[1], &length);

	if ((length > 1) && strncmp(string, "-nocase", length) == 0) {
	    nocase = TCL_MATCH_NOCASE;
	} else {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad option \"%s\": must be -nocase", string));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "INDEX", "option",
		    string, (char *)NULL);
	    return TCL_ERROR;
	}
    }
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(
		TclStringMatchObj(objv[objc-1], objv[objc-2], nocase)));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringRangeCmd --
 *
 *	This procedure is invoked to process the "string range" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringRangeCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size first, last, end;

    if (objc != 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "string first last");
	return TCL_ERROR;
    }

    /*
     * Get the length in actual characters; Then reduce it by one because
     * 'end' refers to the last character, not one past it.
     */

    end = Tcl_GetCharLength(objv[1]) - 1;

    if (TclGetIntForIndexM(interp, objv[2], end, &first) != TCL_OK ||
	    TclGetIntForIndexM(interp, objv[3], end, &last) != TCL_OK) {
	return TCL_ERROR;
    }

    if (last >= 0) {
	Tcl_SetObjResult(interp, Tcl_GetRange(objv[1], first, last));
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringReptCmd --
 *
 *	This procedure is invoked to process the "string repeat" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringReptCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_WideInt count;
    Tcl_Obj *resultPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "string count");
	return TCL_ERROR;
    }

    if (TclGetWideIntFromObj(interp, objv[2], &count) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * Check for cases that allow us to skip copying stuff.
     */

    if (count == 1) {
	Tcl_SetObjResult(interp, objv[1]);
	return TCL_OK;
    } else if (count < 1) {
	return TCL_OK;
    }

    resultPtr = TclStringRepeat(interp, objv[1], count, TCL_STRING_IN_PLACE);
    if (resultPtr) {
	Tcl_SetObjResult(interp, resultPtr);
	return TCL_OK;
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * StringRplcCmd --
 *
 *	This procedure is invoked to process the "string replace" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringRplcCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size first, last, end;

    if (objc < 4 || objc > 5) {
	Tcl_WrongNumArgs(interp, 1, objv, "string first last ?string?");
	return TCL_ERROR;
    }

    end = Tcl_GetCharLength(objv[1]) - 1;

    if (TclGetIntForIndexM(interp, objv[2], end, &first) != TCL_OK ||
	    TclGetIntForIndexM(interp, objv[3], end, &last) != TCL_OK) {
	return TCL_ERROR;
    }

    /*
     * The following test screens out most empty substrings as candidates for
     * replacement. When they are detected, no replacement is done, and the
     * result is the original string.
     */

    if ((last < 0) ||	/* Range ends before start of string */
	    (first > end) ||	/* Range begins after end of string */
	    (last < first)) {	/* Range begins after it starts */
	/*
	 * BUT!!! when (end < 0) -- an empty original string -- we can
	 * have (first <= end < 0 <= last) and an empty string is permitted
	 * to be replaced.
	 */

	Tcl_SetObjResult(interp, objv[1]);
    } else {
	Tcl_Obj *resultPtr;

	if (first < 0) {
	    first = TCL_INDEX_START;
	}
	if (last > end) {
	    last = end;
	}

	resultPtr = TclStringReplace(interp, objv[1], first,
		last + 1 - first, (objc == 5) ? objv[4] : NULL,
		TCL_STRING_IN_PLACE);

	if (resultPtr == NULL) {
	    return TCL_ERROR;
	}
	Tcl_SetObjResult(interp, resultPtr);
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringRevCmd --
 *
 *	This procedure is invoked to process the "string reverse" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringRevCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "string");
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, TclStringReverse(objv[1], TCL_STRING_IN_PLACE));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringStartCmd --
 *
 *	This procedure is invoked to process the "string wordstart" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringStartCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int ch;
    const Tcl_UniChar *p, *string;
    Tcl_Size cur, index, length;
    Tcl_Obj *obj;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "string index");
	return TCL_ERROR;
    }

    string = Tcl_GetUnicodeFromObj(objv[1], &length);
    if (TclGetIntForIndexM(interp, objv[2], length-1, &index) != TCL_OK) {
	return TCL_ERROR;
    }
    if (index >= length) {
	index = length - 1;
    }
    cur = 0;
    if (index > 0) {
	p = &string[index];

	ch = *p;
	for (cur = index; cur != TCL_INDEX_NONE; cur--) {
	    int delta = 0;
	    const Tcl_UniChar *next;

	    if (!Tcl_UniCharIsWordChar(ch)) {
		break;
	    }

	    next = ((p > string) ? (p - 1) : p);
	    do {
		next += delta;
		ch = *next;
		delta = 1;
	    } while (next + delta < p);
	    p = next;
	}
	if (cur != index) {
	    cur += 1;
	}
    }
    TclNewIndexObj(obj, cur);
    Tcl_SetObjResult(interp, obj);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringEndCmd --
 *
 *	This procedure is invoked to process the "string wordend" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringEndCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int ch;
    const Tcl_UniChar *p, *end, *string;
    Tcl_Size cur, index, length;
    Tcl_Obj *obj;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "string index");
	return TCL_ERROR;
    }

    string = Tcl_GetUnicodeFromObj(objv[1], &length);
    if (TclGetIntForIndexM(interp, objv[2], length-1, &index) != TCL_OK) {
	return TCL_ERROR;
    }
    if (index < 0) {
	index = 0;
    }
    if (index < length) {
	p = &string[index];
	end = string+length;
	for (cur = index; p < end; cur++) {
	    ch = *p++;
	    if (!Tcl_UniCharIsWordChar(ch)) {
		break;
	    }
	}
	if (cur == index) {
	    cur++;
	}
    } else {
	cur = length;
    }
    TclNewIndexObj(obj, cur);
    Tcl_SetObjResult(interp, obj);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringEqualCmd --
 *
 *	This procedure is invoked to process the "string equal" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringEqualCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    /*
     * Remember to keep code here in some sync with the byte-compiled versions
     * in tclExecute.c (INST_STR_EQ, INST_STR_NEQ and INST_STR_CMP as well as
     * the expr string comparison in INST_EQ/INST_NEQ/INST_LT/...).
     */

    const char *string2;
    int i, match, nocase = 0;
    Tcl_Size length;
    Tcl_WideInt reqlength = -1;

    if (objc < 3 || objc > 6) {
    str_cmp_args:
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-nocase? ?-length int? string1 string2");
	return TCL_ERROR;
    }

    for (i = 1; i < objc-2; i++) {
	string2 = TclGetStringFromObj(objv[i], &length);
	if ((length > 1) && !strncmp(string2, "-nocase", length)) {
	    nocase = 1;
	} else if ((length > 1)
		&& !strncmp(string2, "-length", length)) {
	    if (i+1 >= objc-2) {
		goto str_cmp_args;
	    }
	    i++;
	    if (TclGetWideIntFromObj(interp, objv[i], &reqlength) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if ((Tcl_WideUInt)reqlength > TCL_SIZE_MAX) {
		reqlength = -1;
	    }
	} else {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad option \"%s\": must be -nocase or -length",
		    string2));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "INDEX", "option",
		    string2, (char *)NULL);
	    return TCL_ERROR;
	}
    }

    /*
     * From now on, we only access the two objects at the end of the argument
     * array.
     */

    objv += objc-2;
    match = TclStringCmp(objv[0], objv[1], 1, nocase, reqlength);
    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(match ? 0 : 1));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringCmpCmd --
 *
 *	This procedure is invoked to process the "string compare" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringCmpCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    /*
     * Remember to keep code here in some sync with the byte-compiled versions
     * in tclExecute.c (INST_STR_EQ, INST_STR_NEQ and INST_STR_CMP as well as
     * the expr string comparison in INST_EQ/INST_NEQ/INST_LT/...).
     */

    int match, nocase, status;
    Tcl_Size reqlength = -1;

    status = StringCmpOpts(interp, objc, objv, &nocase, &reqlength);
    if (status != TCL_OK) {
	return status;
    }

    objv += objc-2;
    match = TclStringCmp(objv[0], objv[1], 0, nocase, reqlength);
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(match));
    return TCL_OK;
}

int
StringCmpOpts(
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[],	/* Argument objects. */
    int *nocase,
    Tcl_Size *reqlength)
{
    int i;
    Tcl_Size length;
    const char *string;
    Tcl_WideInt wreqlength = -1;

    *nocase = 0;
    if (objc < 3 || objc > 6) {
    str_cmp_args:
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-nocase? ?-length int? string1 string2");
	return TCL_ERROR;
    }

    for (i = 1; i < objc-2; i++) {
	string = TclGetStringFromObj(objv[i], &length);
	if ((length > 1) && !strncmp(string, "-nocase", length)) {
	    *nocase = 1;
	} else if ((length > 1)
		&& !strncmp(string, "-length", length)) {
	    if (i+1 >= objc-2) {
		goto str_cmp_args;
	    }
	    i++;
	    if (TclGetWideIntFromObj(interp, objv[i], &wreqlength) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if ((Tcl_WideUInt)wreqlength > TCL_SIZE_MAX) {
		*reqlength = -1;
	    } else {
		*reqlength = wreqlength;
	    }
	} else {
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad option \"%s\": must be -nocase or -length",
		    string));
	    Tcl_SetErrorCode(interp, "TCL", "LOOKUP", "INDEX", "option",
		    string, (char *)NULL);
	    return TCL_ERROR;
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringCatCmd --
 *
 *	This procedure is invoked to process the "string cat" Tcl command.
 *	See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringCatCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *objResultPtr;

    if (objc < 2) {
	/*
	 * If there are no args, the result is an empty object.
	 * Just leave the preset empty interp result.
	 */
	return TCL_OK;
    }

    objResultPtr = TclStringCat(interp, objc-1, objv+1, TCL_STRING_IN_PLACE);

    if (objResultPtr) {
	Tcl_SetObjResult(interp, objResultPtr);
	return TCL_OK;
    }

    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * StringLenCmd --
 *
 *	This procedure is invoked to process the "string length" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringLenCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    if (objc != 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "string");
	return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(Tcl_GetCharLength(objv[1])));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringLowerCmd --
 *
 *	This procedure is invoked to process the "string tolower" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringLowerCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size length1, length2;
    const char *string1;
    char *string2;

    if (objc < 2 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?first? ?last?");
	return TCL_ERROR;
    }

    string1 = TclGetStringFromObj(objv[1], &length1);

    if (objc == 2) {
	Tcl_Obj *resultPtr = Tcl_NewStringObj(string1, length1);

	length1 = Tcl_UtfToLower(TclGetString(resultPtr));
	Tcl_SetObjLength(resultPtr, length1);
	Tcl_SetObjResult(interp, resultPtr);
    } else {
	Tcl_Size first, last;
	const char *start, *end;
	Tcl_Obj *resultPtr;

	length1 = Tcl_NumUtfChars(string1, length1) - 1;
	if (TclGetIntForIndexM(interp,objv[2],length1, &first) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (first < 0) {
	    first = 0;
	}
	last = first;

	if ((objc == 4) && (TclGetIntForIndexM(interp, objv[3], length1,
		&last) != TCL_OK)) {
	    return TCL_ERROR;
	}

	if (last >= length1) {
	    last = length1;
	}
	if (last < first) {
	    Tcl_SetObjResult(interp, objv[1]);
	    return TCL_OK;
	}

	string1 = TclGetStringFromObj(objv[1], &length1);
	start = Tcl_UtfAtIndex(string1, first);
	end = Tcl_UtfAtIndex(start, last - first + 1);
	resultPtr = Tcl_NewStringObj(string1, end - string1);
	string2 = TclGetString(resultPtr) + (start - string1);

	length2 = Tcl_UtfToLower(string2);
	Tcl_SetObjLength(resultPtr, length2 + (start - string1));

	Tcl_AppendToObj(resultPtr, end, -1);
	Tcl_SetObjResult(interp, resultPtr);
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringUpperCmd --
 *
 *	This procedure is invoked to process the "string toupper" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringUpperCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size length1, length2;
    const char *string1;
    char *string2;

    if (objc < 2 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?first? ?last?");
	return TCL_ERROR;
    }

    string1 = TclGetStringFromObj(objv[1], &length1);

    if (objc == 2) {
	Tcl_Obj *resultPtr = Tcl_NewStringObj(string1, length1);

	length1 = Tcl_UtfToUpper(TclGetString(resultPtr));
	Tcl_SetObjLength(resultPtr, length1);
	Tcl_SetObjResult(interp, resultPtr);
    } else {
	Tcl_Size first, last;
	const char *start, *end;
	Tcl_Obj *resultPtr;

	length1 = Tcl_NumUtfChars(string1, length1) - 1;
	if (TclGetIntForIndexM(interp,objv[2],length1, &first) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (first < 0) {
	    first = 0;
	}
	last = first;

	if ((objc == 4) && (TclGetIntForIndexM(interp, objv[3], length1,
		&last) != TCL_OK)) {
	    return TCL_ERROR;
	}

	if (last >= length1) {
	    last = length1;
	}
	if (last < first) {
	    Tcl_SetObjResult(interp, objv[1]);
	    return TCL_OK;
	}

	string1 = TclGetStringFromObj(objv[1], &length1);
	start = Tcl_UtfAtIndex(string1, first);
	end = Tcl_UtfAtIndex(start, last - first + 1);
	resultPtr = Tcl_NewStringObj(string1, end - string1);
	string2 = TclGetString(resultPtr) + (start - string1);

	length2 = Tcl_UtfToUpper(string2);
	Tcl_SetObjLength(resultPtr, length2 + (start - string1));

	Tcl_AppendToObj(resultPtr, end, -1);
	Tcl_SetObjResult(interp, resultPtr);
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringTitleCmd --
 *
 *	This procedure is invoked to process the "string totitle" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringTitleCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Size length1, length2;
    const char *string1;
    char *string2;

    if (objc < 2 || objc > 4) {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?first? ?last?");
	return TCL_ERROR;
    }

    string1 = TclGetStringFromObj(objv[1], &length1);

    if (objc == 2) {
	Tcl_Obj *resultPtr = Tcl_NewStringObj(string1, length1);

	length1 = Tcl_UtfToTitle(TclGetString(resultPtr));
	Tcl_SetObjLength(resultPtr, length1);
	Tcl_SetObjResult(interp, resultPtr);
    } else {
	Tcl_Size first, last;
	const char *start, *end;
	Tcl_Obj *resultPtr;

	length1 = Tcl_NumUtfChars(string1, length1) - 1;
	if (TclGetIntForIndexM(interp,objv[2],length1, &first) != TCL_OK) {
	    return TCL_ERROR;
	}
	if (first < 0) {
	    first = 0;
	}
	last = first;

	if ((objc == 4) && (TclGetIntForIndexM(interp, objv[3], length1,
		&last) != TCL_OK)) {
	    return TCL_ERROR;
	}

	if (last >= length1) {
	    last = length1;
	}
	if (last < first) {
	    Tcl_SetObjResult(interp, objv[1]);
	    return TCL_OK;
	}

	string1 = TclGetStringFromObj(objv[1], &length1);
	start = Tcl_UtfAtIndex(string1, first);
	end = Tcl_UtfAtIndex(start, last - first + 1);
	resultPtr = Tcl_NewStringObj(string1, end - string1);
	string2 = TclGetString(resultPtr) + (start - string1);

	length2 = Tcl_UtfToTitle(string2);
	Tcl_SetObjLength(resultPtr, length2 + (start - string1));

	Tcl_AppendToObj(resultPtr, end, -1);
	Tcl_SetObjResult(interp, resultPtr);
    }

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringTrimCmd --
 *
 *	This procedure is invoked to process the "string trim" Tcl command.
 *	See the user documentation for details on what it does. Note that this
 *	command only functions correctly on properly formed Tcl UTF strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringTrimCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *string1, *string2;
    Tcl_Size triml, trimr, length1, length2;

    if (objc == 3) {
	string2 = TclGetStringFromObj(objv[2], &length2);
    } else if (objc == 2) {
	string2 = tclDefaultTrimSet;
	length2 = strlen(tclDefaultTrimSet);
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?chars?");
	return TCL_ERROR;
    }
    string1 = TclGetStringFromObj(objv[1], &length1);

    triml = TclTrim(string1, length1, string2, length2, &trimr);

    Tcl_SetObjResult(interp,
	    Tcl_NewStringObj(string1 + triml, length1 - triml - trimr));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringTrimLCmd --
 *
 *	This procedure is invoked to process the "string trimleft" Tcl
 *	command. See the user documentation for details on what it does. Note
 *	that this command only functions correctly on properly formed Tcl UTF
 *	strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringTrimLCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *string1, *string2;
    int trim;
    Tcl_Size length1, length2;

    if (objc == 3) {
	string2 = TclGetStringFromObj(objv[2], &length2);
    } else if (objc == 2) {
	string2 = tclDefaultTrimSet;
	length2 = strlen(tclDefaultTrimSet);
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?chars?");
	return TCL_ERROR;
    }
    string1 = TclGetStringFromObj(objv[1], &length1);

    trim = TclTrimLeft(string1, length1, string2, length2);

    Tcl_SetObjResult(interp, Tcl_NewStringObj(string1+trim, length1-trim));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * StringTrimRCmd --
 *
 *	This procedure is invoked to process the "string trimright" Tcl
 *	command. See the user documentation for details on what it does. Note
 *	that this command only functions correctly on properly formed Tcl UTF
 *	strings.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

static int
StringTrimRCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    const char *string1, *string2;
    int trim;
    Tcl_Size length1, length2;

    if (objc == 3) {
	string2 = TclGetStringFromObj(objv[2], &length2);
    } else if (objc == 2) {
	string2 = tclDefaultTrimSet;
	length2 = strlen(tclDefaultTrimSet);
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "string ?chars?");
	return TCL_ERROR;
    }
    string1 = TclGetStringFromObj(objv[1], &length1);

    trim = TclTrimRight(string1, length1, string2, length2);

    Tcl_SetObjResult(interp, Tcl_NewStringObj(string1, length1-trim));
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclInitStringCmd --
 *
 *	This procedure creates the "string" Tcl command. See the user
 *	documentation for details on what it does. Note that this command only
 *	functions correctly on properly formed Tcl UTF strings.
 *
 *	Also note that the primary methods here (equal, compare, match, ...)
 *	have bytecode equivalents. You will find the code for those in
 *	tclExecute.c. The code here will only be used in the non-bc case (like
 *	in an 'eval').
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

Tcl_Command
TclInitStringCmd(
    Tcl_Interp *interp)		/* Current interpreter. */
{
    static const EnsembleImplMap stringImplMap[] = {
	{"cat",		StringCatCmd,	TclCompileStringCatCmd, NULL, NULL, 0},
	{"compare",	StringCmpCmd,	TclCompileStringCmpCmd, NULL, NULL, 0},
	{"equal",	StringEqualCmd,	TclCompileStringEqualCmd, NULL, NULL, 0},
	{"first",	StringFirstCmd,	TclCompileStringFirstCmd, NULL, NULL, 0},
	{"index",	StringIndexCmd,	TclCompileStringIndexCmd, NULL, NULL, 0},
	{"insert",	StringInsertCmd, TclCompileStringInsertCmd, NULL, NULL, 0},
	{"is",		StringIsCmd,	TclCompileStringIsCmd, NULL, NULL, 0},
	{"last",	StringLastCmd,	TclCompileStringLastCmd, NULL, NULL, 0},
	{"length",	StringLenCmd,	TclCompileStringLenCmd, NULL, NULL, 0},
	{"map",		StringMapCmd,	TclCompileStringMapCmd, NULL, NULL, 0},
	{"match",	StringMatchCmd,	TclCompileStringMatchCmd, NULL, NULL, 0},
	{"range",	StringRangeCmd,	TclCompileStringRangeCmd, NULL, NULL, 0},
	{"repeat",	StringReptCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 0},
	{"replace",	StringRplcCmd,	TclCompileStringReplaceCmd, NULL, NULL, 0},
	{"reverse",	StringRevCmd,	TclCompileBasic1ArgCmd, NULL, NULL, 0},
	{"tolower",	StringLowerCmd,	TclCompileStringToLowerCmd, NULL, NULL, 0},
	{"toupper",	StringUpperCmd,	TclCompileStringToUpperCmd, NULL, NULL, 0},
	{"totitle",	StringTitleCmd,	TclCompileStringToTitleCmd, NULL, NULL, 0},
	{"trim",	StringTrimCmd,	TclCompileStringTrimCmd, NULL, NULL, 0},
	{"trimleft",	StringTrimLCmd,	TclCompileStringTrimLCmd, NULL, NULL, 0},
	{"trimright",	StringTrimRCmd,	TclCompileStringTrimRCmd, NULL, NULL, 0},
	{"wordend",	StringEndCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 0},
	{"wordstart",	StringStartCmd,	TclCompileBasic2ArgCmd, NULL, NULL, 0},
	{NULL, NULL, NULL, NULL, NULL, 0}
    };

    return TclMakeEnsemble(interp, "string", stringImplMap);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SubstObjCmd --
 *
 *	This procedure is invoked to process the "subst" Tcl command. See the
 *	user documentation for details on what it does. This command relies on
 *	Tcl_SubstObj() for its implementation.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
TclSubstOptions(
    Tcl_Interp *interp,
    Tcl_Size numOpts,
    Tcl_Obj *const opts[],
    int *flagPtr)
{
    static const char *const substOptions[] = {
	"-nobackslashes", "-nocommands", "-novariables", NULL
    };
    static const int optionFlags[] = {
	TCL_SUBST_BACKSLASHES, TCL_SUBST_COMMANDS, TCL_SUBST_VARIABLES
    };
    int flags = TCL_SUBST_ALL;

    for (Tcl_Size i = 0; i < numOpts; i++) {
	int optionIndex;

	if (Tcl_GetIndexFromObj(interp, opts[i], substOptions, "option", 0,
		&optionIndex) != TCL_OK) {
	    return TCL_ERROR;
	}
	flags &= ~optionFlags[optionIndex];
    }
    *flagPtr = flags;
    return TCL_OK;
}

int
Tcl_SubstObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRSubstObjCmd, clientData, objc, objv);
}

int
TclNRSubstObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int flags;

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-nobackslashes? ?-nocommands? ?-novariables? string");
	return TCL_ERROR;
    }

    if (TclSubstOptions(interp, objc-2, objv+1, &flags) != TCL_OK) {
	return TCL_ERROR;
    }
    return Tcl_NRSubstObj(interp, objv[objc-1], flags);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_SwitchObjCmd --
 *
 *	This object-based procedure is invoked to process the "switch" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_SwitchObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRSwitchObjCmd, clientData, objc, objv);
}
int
TclNRSwitchObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    int i, mode, foundmode, splitObjs, numMatchesSaved;
    int noCase;
    Tcl_Size patternLength, j;
    const char *pattern;
    Tcl_Obj *stringObj, *indexVarObj, *matchVarObj;
    Tcl_Obj *const *savedObjv = objv;
    Tcl_RegExp regExpr = NULL;
    Interp *iPtr = (Interp *) interp;
    int pc = 0;
    int bidx = 0;		/* Index of body argument. */
    Tcl_Obj *blist = NULL;	/* List obj which is the body */
    CmdFrame *ctxPtr;		/* Copy of the topmost cmdframe, to allow us
				 * to mess with the line information */

    /*
     * If you add options that make -e and -g not unique prefixes of -exact or
     * -glob, you *must* fix TclCompileSwitchCmd's option parser as well.
     */

    static const char *const options[] = {
	"-exact", "-glob", "-indexvar", "-matchvar", "-nocase", "-regexp",
	"--", NULL
    };
    enum switchOptionsEnum {
	OPT_EXACT, OPT_GLOB, OPT_INDEXV, OPT_MATCHV, OPT_NOCASE, OPT_REGEXP,
	OPT_LAST
    } index;
    typedef int (*strCmpFn_t)(const char *, const char *);
    strCmpFn_t strCmpFn = TclUtfCmp;

    mode = OPT_EXACT;
    foundmode = 0;
    indexVarObj = NULL;
    matchVarObj = NULL;
    numMatchesSaved = 0;
    noCase = 0;
    for (i = 1; i < objc-2; i++) {
	if (TclGetString(objv[i])[0] != '-') {
	    break;
	}
	if (Tcl_GetIndexFromObj(interp, objv[i], options, "option", 0,
		&index) != TCL_OK) {
	    return TCL_ERROR;
	}
	switch (index) {
	    /*
	     * General options.
	     */

	case OPT_LAST:
	    i++;
	    goto finishedOptions;
	case OPT_NOCASE:
	    strCmpFn = TclUtfCasecmp;
	    noCase = 1;
	    break;

	    /*
	     * Handle the different switch mode options.
	     */

	default:
	    if (foundmode) {
		/*
		 * Mode already set via -exact, -glob, or -regexp.
		 */

		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"bad option \"%s\": %s option already found",
			TclGetString(objv[i]), options[mode]));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
			"DOUBLEOPT", (char *)NULL);
		return TCL_ERROR;
	    }
	    foundmode = 1;
	    mode = index;
	    break;

	    /*
	     * Check for TIP#75 options specifying the variables to write
	     * regexp information into.
	     */

	case OPT_INDEXV:
	    i++;
	    if (i >= objc-2) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"missing variable name argument to %s option",
			"-indexvar"));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
			"NOVAR", (char *)NULL);
		return TCL_ERROR;
	    }
	    indexVarObj = objv[i];
	    numMatchesSaved = -1;
	    break;
	case OPT_MATCHV:
	    i++;
	    if (i >= objc-2) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"missing variable name argument to %s option",
			"-matchvar"));
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
			"NOVAR", (char *)NULL);
		return TCL_ERROR;
	    }
	    matchVarObj = objv[i];
	    numMatchesSaved = -1;
	    break;
	}
    }

  finishedOptions:
    if (objc - i < 2) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-option ...? string ?pattern body ...? ?default body?");
	return TCL_ERROR;
    }
    if (indexVarObj != NULL && mode != OPT_REGEXP) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"%s option requires -regexp option", "-indexvar"));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
		"MODERESTRICTION", (char *)NULL);
	return TCL_ERROR;
    }
    if (matchVarObj != NULL && mode != OPT_REGEXP) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"%s option requires -regexp option", "-matchvar"));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
		"MODERESTRICTION", (char *)NULL);
	return TCL_ERROR;
    }

    stringObj = objv[i];
    objc -= i + 1;
    objv += i + 1;
    bidx = i + 1;		/* First after the match string. */

    /*
     * If all of the pattern/command pairs are lumped into a single argument,
     * split them out again.
     *
     * TIP #280: Determine the lines the words in the list start at, based on
     * the same data for the list word itself. The cmdFramePtr line
     * information is manipulated directly.
     */

    splitObjs = 0;
    if (objc == 1) {
	Tcl_Obj **listv;
	Tcl_Size listc;

	blist = objv[0];
	if (TclListObjLength(interp, objv[0], &listc) != TCL_OK) {
	    return TCL_ERROR;
	}

	/*
	 * Ensure that the list is non-empty.
	 */

	if (listc < 1 || listc > INT_MAX) {
	    Tcl_WrongNumArgs(interp, 1, savedObjv,
		    "?-option ...? string {?pattern body ...? ?default body?}");
	    return TCL_ERROR;
	}
	if (TclListObjGetElements(interp, objv[0], &listc, &listv) != TCL_OK) {
	    return TCL_ERROR;
	}
	objc = listc;
	objv = listv;
	splitObjs = 1;
    }

    /*
     * Complain if there is an odd number of words in the list of patterns and
     * bodies.
     */

    if (objc % 2) {
	Tcl_ResetResult(interp);
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"extra switch pattern with no body", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH", "BADARM",
		(char *)NULL);

	/*
	 * Check if this can be due to a badly placed comment in the switch
	 * block.
	 *
	 * The following is an heuristic to detect the infamous "comment in
	 * switch" error: just check if a pattern begins with '#'.
	 */

	if (splitObjs) {
	    for (i=0 ; i<objc ; i+=2) {
		if (TclGetString(objv[i])[0] == '#') {
		    Tcl_AppendToObj(Tcl_GetObjResult(interp),
			    ", this may be due to a comment incorrectly"
			    " placed outside of a switch body - see the"
			    " \"switch\" documentation", -1);
		    Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH",
			    "BADARM", "COMMENT?", (char *)NULL);
		    break;
		}
	    }
	}

	return TCL_ERROR;
    }

    /*
     * Complain if the last body is a continuation. Note that this check
     * assumes that the list is non-empty!
     */

    if (strcmp(TclGetString(objv[objc-1]), "-") == 0) {
	Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		"no body specified for pattern \"%s\"",
		TclGetString(objv[objc-2])));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "SWITCH", "BADARM",
		"FALLTHROUGH", (char *)NULL);
	return TCL_ERROR;
    }

    for (i = 0; i < objc; i += 2) {
	/*
	 * See if the pattern matches the string.
	 */

	pattern = TclGetStringFromObj(objv[i], &patternLength);

	if ((i == objc - 2) && (*pattern == 'd')
		&& (strcmp(pattern, "default") == 0)) {
	    Tcl_Obj *emptyObj = NULL;

	    /*
	     * If either indexVarObj or matchVarObj are non-NULL, we're in
	     * REGEXP mode but have reached the default clause anyway. TIP#75
	     * specifies that we set the variables to empty lists (== empty
	     * objects) in that case.
	     */

	    if (indexVarObj != NULL) {
		TclNewObj(emptyObj);
		if (Tcl_ObjSetVar2(interp, indexVarObj, NULL, emptyObj,
			TCL_LEAVE_ERR_MSG) == NULL) {
		    return TCL_ERROR;
		}
	    }
	    if (matchVarObj != NULL) {
		if (emptyObj == NULL) {
		    TclNewObj(emptyObj);
		}
		if (Tcl_ObjSetVar2(interp, matchVarObj, NULL, emptyObj,
			TCL_LEAVE_ERR_MSG) == NULL) {
		    return TCL_ERROR;
		}
	    }
	    goto matchFound;
	}

	switch (mode) {
	case OPT_EXACT:
	    if (strCmpFn(TclGetString(stringObj), pattern) == 0) {
		goto matchFound;
	    }
	    break;
	case OPT_GLOB:
	    if (Tcl_StringCaseMatch(TclGetString(stringObj),pattern,noCase)) {
		goto matchFound;
	    }
	    break;
	case OPT_REGEXP:
	    regExpr = Tcl_GetRegExpFromObj(interp, objv[i],
		    TCL_REG_ADVANCED | (noCase ? TCL_REG_NOCASE : 0));
	    if (regExpr == NULL) {
		return TCL_ERROR;
	    } else {
		int matched = Tcl_RegExpExecObj(interp, regExpr, stringObj, 0,
			numMatchesSaved, 0);

		if (matched < 0) {
		    return TCL_ERROR;
		} else if (matched) {
		    goto matchFoundRegexp;
		}
	    }
	    break;
	}
    }
    return TCL_OK;

  matchFoundRegexp:
    /*
     * We are operating in REGEXP mode and we need to store information about
     * what we matched in some user-nominated arrays. So build the lists of
     * values and indices to write here. [TIP#75]
     */

    if (numMatchesSaved) {
	Tcl_RegExpInfo info;
	Tcl_Obj *matchesObj, *indicesObj = NULL;

	Tcl_RegExpGetInfo(regExpr, &info);
	if (matchVarObj != NULL) {
	    TclNewObj(matchesObj);
	} else {
	    matchesObj = NULL;
	}
	if (indexVarObj != NULL) {
	    TclNewObj(indicesObj);
	}

	for (j=0 ; j<=info.nsubs ; j++) {
	    if (indexVarObj != NULL) {
		Tcl_Obj *rangeObjAry[2];

		if (info.matches[j].end > 0) {
		    TclNewIndexObj(rangeObjAry[0], info.matches[j].start);
		    TclNewIndexObj(rangeObjAry[1], info.matches[j].end-1);
		} else {
		    TclNewIntObj(rangeObjAry[1], -1);
		    rangeObjAry[0] = rangeObjAry[1];
		}

		/*
		 * Never fails; the object is always clean at this point.
		 */

		Tcl_ListObjAppendElement(NULL, indicesObj,
			Tcl_NewListObj(2, rangeObjAry));
	    }

	    if (matchVarObj != NULL) {
		Tcl_Obj *substringObj;

		if (info.matches[j].end > 0) {
		    substringObj = Tcl_GetRange(stringObj,
			    info.matches[j].start, info.matches[j].end-1);
		} else {
		    TclNewObj(substringObj);
		}

		/*
		 * Never fails; the object is always clean at this point.
		 */

		Tcl_ListObjAppendElement(NULL, matchesObj, substringObj);
	    }
	}

	if (indexVarObj != NULL) {
	    if (Tcl_ObjSetVar2(interp, indexVarObj, NULL, indicesObj,
		    TCL_LEAVE_ERR_MSG) == NULL) {
		/*
		 * Careful! Check to see if we have allocated the list of
		 * matched strings; if so (but there was an error assigning
		 * the indices list) we have a potential memory leak because
		 * the match list has not been written to a variable. Except
		 * that we'll clean that up right now.
		 */

		if (matchesObj != NULL) {
		    Tcl_DecrRefCount(matchesObj);
		}
		return TCL_ERROR;
	    }
	}
	if (matchVarObj != NULL) {
	    if (Tcl_ObjSetVar2(interp, matchVarObj, NULL, matchesObj,
		    TCL_LEAVE_ERR_MSG) == NULL) {
		/*
		 * Unlike above, if indicesObj is non-NULL at this point, it
		 * will have been written to a variable already and will hence
		 * not be leaked.
		 */

		return TCL_ERROR;
	    }
	}
    }

    /*
     * We've got a match. Find a body to execute, skipping bodies that are
     * "-".
     */

  matchFound:
    ctxPtr = (CmdFrame *)TclStackAlloc(interp, sizeof(CmdFrame));
    *ctxPtr = *iPtr->cmdFramePtr;

    if (splitObjs) {
	/*
	 * We have to perform the GetSrc and other type dependent handling of
	 * the frame here because we are munging with the line numbers,
	 * something the other commands like if, etc. are not doing. Them are
	 * fine with simply passing the CmdFrame through and having the
	 * special handling done in 'info frame', or the bc compiler
	 */

	if (ctxPtr->type == TCL_LOCATION_BC) {
	    /*
	     * Type BC => ctxPtr->data.eval.path    is not used.
	     *		  ctxPtr->data.tebc.codePtr is used instead.
	     */

	    TclGetSrcInfoForPc(ctxPtr);
	    pc = 1;

	    /*
	     * The line information in the cmdFrame is now a copy we do not
	     * own.
	     */
	}

	if (ctxPtr->type == TCL_LOCATION_SOURCE && ctxPtr->line[bidx] >= 0) {
	    int bline = ctxPtr->line[bidx];

	    ctxPtr->line = (Tcl_Size *)Tcl_Alloc(objc * sizeof(Tcl_Size));
	    ctxPtr->nline = objc;
	    TclListLines(blist, bline, objc, ctxPtr->line, objv);
	} else {
	    /*
	     * This is either a dynamic code word, when all elements are
	     * relative to themselves, or something else less expected and
	     * where we have no information. The result is the same in both
	     * cases; tell the code to come that it doesn't know where it is,
	     * which triggers reversion to the old behavior.
	     */

	    int k;

	    ctxPtr->line = (Tcl_Size *)Tcl_Alloc(objc * sizeof(Tcl_Size));
	    ctxPtr->nline = objc;
	    for (k=0; k < objc; k++) {
		ctxPtr->line[k] = -1;
	    }
	}
    }

    for (j = i + 1; ; j += 2) {
	if (j >= objc) {
	    /*
	     * This shouldn't happen since we've checked that the last body is
	     * not a continuation...
	     */

	    Tcl_Panic("fall-out when searching for body to match pattern");
	}
	if (strcmp(TclGetString(objv[j]), "-") != 0) {
	    break;
	}
    }

    /*
     * TIP #280: Make invoking context available to switch branch.
     */

    Tcl_NRAddCallback(interp, SwitchPostProc, INT2PTR(splitObjs), ctxPtr,
	    INT2PTR(pc), (void *)pattern);
    return TclNREvalObjEx(interp, objv[j], 0, ctxPtr, splitObjs ? j : bidx+j);
}

static int
SwitchPostProc(
    void *data[],		/* Data passed from Tcl_NRAddCallback above */
    Tcl_Interp *interp,		/* Tcl interpreter */
    int result)			/* Result to return*/
{
    /* Unpack the preserved data */

    int splitObjs = PTR2INT(data[0]);
    CmdFrame *ctxPtr = (CmdFrame *)data[1];
    int pc = PTR2INT(data[2]);
    const char *pattern = (const char *)data[3];
    Tcl_Size patternLength = strlen(pattern);

    /*
     * Clean up TIP 280 context information
     */

    if (splitObjs) {
	Tcl_Free(ctxPtr->line);
	if (pc && (ctxPtr->type == TCL_LOCATION_SOURCE)) {
	    /*
	     * Death of SrcInfo reference.
	     */

	    Tcl_DecrRefCount(ctxPtr->data.eval.path);
	}
    }

    /*
     * Generate an error message if necessary.
     */

    if (result == TCL_ERROR) {
	int limit = 50;
	int overflow = (patternLength > limit);

	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"%.*s%s\" arm line %d)",
		(int) (overflow ? limit : patternLength), pattern,
		(overflow ? "..." : ""), Tcl_GetErrorLine(interp)));
    }
    TclStackFree(interp, ctxPtr);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_ThrowObjCmd --
 *
 *	This procedure is invoked to process the "throw" Tcl command. See the
 *	user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_ThrowObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *options;
    Tcl_Size len;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "type message");
	return TCL_ERROR;
    }

    /*
     * The type must be a list of at least length 1.
     */

    if (TclListObjLength(interp, objv[1], &len) != TCL_OK) {
	return TCL_ERROR;
    } else if (len < 1) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"type must be non-empty list", -1));
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "THROW", "BADEXCEPTION",
		(char *)NULL);
	return TCL_ERROR;
    }

    /*
     * Now prepare the result options dictionary. We use the list API as it is
     * slightly more convenient.
     */

    TclNewLiteralStringObj(options, "-code error -level 0 -errorcode");
    Tcl_ListObjAppendElement(NULL, options, objv[1]);

    /*
     * We're ready to go. Fire things into the low-level result machinery.
     */

    Tcl_SetObjResult(interp, objv[2]);
    return Tcl_SetReturnOptions(interp, options);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_TimeObjCmd --
 *
 *	This object-based procedure is invoked to process the "time" Tcl
 *	command. See the user documentation for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_TimeObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *objPtr;
    Tcl_Obj *objs[4];
    int i, result;
    int count;
    double totalMicroSec;
#ifndef TCL_WIDE_CLICKS
    Tcl_Time start, stop;
#else
    Tcl_WideInt start, stop;
#endif

    if (objc == 2) {
	count = 1;
    } else if (objc == 3) {
	result = TclGetIntFromObj(interp, objv[2], &count);
	if (result != TCL_OK) {
	    return result;
	}
    } else {
	Tcl_WrongNumArgs(interp, 1, objv, "command ?count?");
	return TCL_ERROR;
    }

    objPtr = objv[1];
    i = count;
#ifndef TCL_WIDE_CLICKS
    Tcl_GetTime(&start);
#else
    start = TclpGetWideClicks();
#endif
    while (i-- > 0) {
	result = TclEvalObjEx(interp, objPtr, 0, NULL, 0);
	if (result != TCL_OK) {
	    return result;
	}
    }
#ifndef TCL_WIDE_CLICKS
    Tcl_GetTime(&stop);
    totalMicroSec = ((double) (stop.sec - start.sec)) * 1.0e6
	    + (stop.usec - start.usec);
#else
    stop = TclpGetWideClicks();
    totalMicroSec = ((double) TclpWideClicksToNanoseconds(stop - start))/1.0e3;
#endif

    if (count <= 1) {
	/*
	 * Use int obj since we know time is not fractional. [Bug 1202178]
	 */

	TclNewIntObj(objs[0], (count <= 0) ? 0 : (Tcl_WideInt)totalMicroSec);
    } else {
	TclNewDoubleObj(objs[0], totalMicroSec/count);
    }

    /*
     * Construct the result as a list because many programs have always parsed
     * as such (extracting the first element, typically).
     */

    TclNewLiteralStringObj(objs[1], "microseconds");
    TclNewLiteralStringObj(objs[2], "per");
    TclNewLiteralStringObj(objs[3], "iteration");
    Tcl_SetObjResult(interp, Tcl_NewListObj(4, objs));

    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_TimeRateObjCmd --
 *
 *	This object-based procedure is invoked to process the "timerate" Tcl
 *	command.
 *
 *	This is similar to command "time", except the execution limited by
 *	given time (in milliseconds) instead of repetition count.
 *
 * Example:
 *	timerate {after 5} 1000; # equivalent to: time {after 5} [expr 1000/5]
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_TimeRateObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    static double measureOverhead = 0;
				/* global measure-overhead */
    double overhead = -1;	/* given measure-overhead */
    Tcl_Obj *objPtr;
    int result, i;
    Tcl_Obj *calibrate = NULL, *direct = NULL;
    Tcl_WideUInt count = 0;	/* Holds repetition count */
    Tcl_WideUInt lastCount = 0;	/* Repetition count since last calculation. */
    Tcl_WideInt maxms = WIDE_MIN;
				/* Maximal running time (in milliseconds) */
    Tcl_WideUInt maxcnt = UWIDE_MAX;
				/* Maximal count of iterations. */
    Tcl_WideUInt threshold = 1;	/* Current threshold for check time (faster
				 * repeat count without time check) */
    Tcl_WideUInt avgIterTm = 1;	/* Average time of all processed iterations. */
    Tcl_WideUInt lastIterTm = 1;/* Average time of last block of iterations. */
    double estIterTm = 1.0;	/* Estimated time of next iteration,
				 * considering the growth of lastIterTm. */
#ifdef TCL_WIDE_CLICKS
#   define TR_SCALE 10		/* Fraction is 10ns (from wide click 100ns). */
#else
#   define TR_SCALE 100		/* Fraction is 10ns (from 1us = 1000ns). */
#endif
#define TR_MIN_FACTOR 2		/* Min allowed factor calculating threshold. */
#define TR_MAX_FACTOR 50	/* Max allowed factor calculating threshold. */
#define TR_FACT_SINGLE_ITER 25  /* This or larger factor value will force the
				 * threshold 1, to avoid drastic growth of
				 * execution time by quadratic O() complexity. */
    unsigned short factor = 16;	/* Factor (2..50) limiting threshold to avoid
				 * growth of execution time. */
    Tcl_WideInt start, last, middle, stop;
#ifndef TCL_WIDE_CLICKS
    Tcl_Time now;
#endif /* !TCL_WIDE_CLICKS */
    static const char *const options[] = {
	"-direct",	"-overhead",	"-calibrate",	"--",	NULL
    };
    enum timeRateOptionsEnum {
	TMRT_EV_DIRECT,	TMRT_OVERHEAD,	TMRT_CALIBRATE,	TMRT_LAST
    };
    NRE_callback *rootPtr;
    ByteCode *codePtr = NULL;

    for (i = 1; i < objc - 1; i++) {
	enum timeRateOptionsEnum index;

	if (Tcl_GetIndexFromObj(NULL, objv[i], options, "option", TCL_EXACT,
		&index) != TCL_OK) {
	    break;
	}
	if (index == TMRT_LAST) {
	    i++;
	    break;
	}
	switch (index) {
	case TMRT_EV_DIRECT:
	    direct = objv[i];
	    break;
	case TMRT_OVERHEAD:
	    if (++i >= objc - 1) {
		goto usage;
	    }
	    if (Tcl_GetDoubleFromObj(interp, objv[i], &overhead) != TCL_OK) {
		return TCL_ERROR;
	    }
	    break;
	case TMRT_CALIBRATE:
	    calibrate = objv[i];
	    break;
	case TMRT_LAST:
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }

    if (i >= objc || i < objc - 3) {
    usage:
	Tcl_WrongNumArgs(interp, 1, objv,
		"?-direct? ?-calibrate? ?-overhead double? "
		"command ?time ?max-count??");
	return TCL_ERROR;
    }
    objPtr = objv[i++];
    if (i < objc) {	/* max-time */
	result = TclGetWideIntFromObj(interp, objv[i], &maxms);
	i++; // Keep this separate from TclGetWideIntFromObj macro above!
	if (result != TCL_OK) {
	    return result;
	}
	if (i < objc) {	/* max-count*/
	    Tcl_WideInt v;

	    result = TclGetWideIntFromObj(interp, objv[i], &v);
	    if (result != TCL_OK) {
		return result;
	    }
	    maxcnt = (v > 0) ? v : 0;
	}
    }

    /*
     * If we are doing calibration.
     */

    if (calibrate) {
	/*
	 * If no time specified for the calibration.
	 */

	if (maxms == WIDE_MIN) {
	    Tcl_Obj *clobjv[6];
	    Tcl_WideInt maxCalTime = 5000;
	    double lastMeasureOverhead = measureOverhead;

	    clobjv[0] = objv[0];
	    i = 1;
	    if (direct) {
		clobjv[i++] = direct;
	    }
	    clobjv[i++] = objPtr;

	    /*
	     * Reset last measurement overhead.
	     */

	    measureOverhead = (double) 0;

	    /*
	     * Self-call with 100 milliseconds to warm-up, before entering the
	     * calibration cycle.
	     */

	    TclNewIntObj(clobjv[i], 100);
	    Tcl_IncrRefCount(clobjv[i]);
	    result = Tcl_TimeRateObjCmd(NULL, interp, i + 1, clobjv);
	    Tcl_DecrRefCount(clobjv[i]);
	    if (result != TCL_OK) {
		return result;
	    }

	    i--;
	    clobjv[i++] = calibrate;
	    clobjv[i++] = objPtr;

	    /*
	     * Set last measurement overhead to max.
	     */

	    measureOverhead = (double) UWIDE_MAX;

	    /*
	     * Run the calibration cycle until it is more precise.
	     */

	    maxms = -1000;
	    do {
		lastMeasureOverhead = measureOverhead;
		TclNewIntObj(clobjv[i], (int) maxms);
		Tcl_IncrRefCount(clobjv[i]);
		result = Tcl_TimeRateObjCmd(NULL, interp, i + 1, clobjv);
		Tcl_DecrRefCount(clobjv[i]);
		if (result != TCL_OK) {
		    return result;
		}
		maxCalTime += maxms;

		/*
		 * Increase maxms for more precise calibration.
		 */

		maxms -= -maxms / 4;

		/*
		 * As long as new value more as 0.05% better
		 */
	    } while ((measureOverhead >= lastMeasureOverhead
		    || measureOverhead / lastMeasureOverhead <= 0.9995)
		    && maxCalTime > 0);

	    return result;
	}
	if (maxms == 0) {
	    /*
	     * Reset last measurement overhead
	     */

	    measureOverhead = 0;
	    Tcl_SetObjResult(interp, Tcl_NewWideIntObj(0));
	    return TCL_OK;
	}

	/*
	 * If time is negative, make current overhead more precise.
	 */

	if (maxms > 0) {
	    /*
	     * Set last measurement overhead to max.
	     */

	    measureOverhead = (double) UWIDE_MAX;
	} else {
	    maxms = -maxms;
	}
    }

    if (maxms == WIDE_MIN) {
	maxms = 1000;
    }
    if (overhead == -1) {
	overhead = measureOverhead;
    }

    /*
     * Ensure that resetting of result will not smudge the further
     * measurement.
     */

    Tcl_ResetResult(interp);

    /*
     * Compile object if needed.
     */

    if (!direct) {
	if (TclInterpReady(interp) != TCL_OK) {
	    return TCL_ERROR;
	}
	codePtr = TclCompileObj(interp, objPtr, NULL, 0);
	TclPreserveByteCode(codePtr);
    }

    /*
     * Get start and stop time.
     */

#ifdef TCL_WIDE_CLICKS
    start = last = middle = TclpGetWideClicks();

    /*
     * Time to stop execution (in wide clicks).
     */

    stop = start + (maxms * 1000 / TclpWideClickInMicrosec());
#else
    Tcl_GetTime(&now);
    start = now.sec;
    start *= 1000000;
    start += now.usec;
    last = middle = start;

    /*
     * Time to stop execution (in microsecs).
     */

    stop = start + maxms * 1000;
#endif /* TCL_WIDE_CLICKS */

    /*
     * Start measurement.
     */

    if (maxcnt > 0) {
	while (1) {
	    /*
	     * Evaluate a single iteration.
	     */

	    count++;
	    if (!direct) {		/* precompiled */
		rootPtr = TOP_CB(interp);
		/*
		 * Use loop optimized TEBC call (TCL_EVAL_DISCARD_RESULT): it's a part of
		 * iteration, this way evaluation will be more similar to a cycle (also
		 * avoids extra overhead to set result to interp, etc.)
		 */
		((Interp *)interp)->evalFlags |= TCL_EVAL_DISCARD_RESULT;
		result = TclNRExecuteByteCode(interp, codePtr);
		result = TclNRRunCallbacks(interp, result, rootPtr);
	    } else {			/* eval */
		result = TclEvalObjEx(interp, objPtr, 0, NULL, 0);
	    }
	    /*
	     * Allow break and continue from measurement cycle (used for
	     * conditional stop and flow control of iterations).
	     */

	    switch (result) {
		case TCL_OK:
		    break;
		case TCL_BREAK:
		    /*
		     * Force stop immediately.
		     */
		    threshold = 1;
		    maxcnt = 0;
		    TCL_FALLTHROUGH();
		case TCL_CONTINUE:
		    result = TCL_OK;
		    break;
		default:
		    goto done;
	    }

	    /*
	     * Don't check time up to threshold.
	     */

	    if (--threshold > 0) {
		continue;
	    }

	    /*
	     * Check stop time reached, estimate new threshold.
	     */

#ifdef TCL_WIDE_CLICKS
	    middle = TclpGetWideClicks();
#else
	    Tcl_GetTime(&now);
	    middle = now.sec;
	    middle *= 1000000;
	    middle += now.usec;
#endif /* TCL_WIDE_CLICKS */

	    if (middle >= stop || count >= maxcnt) {
		break;
	    }

	    /*
	     * Average iteration time (scaled) in fractions of wide clicks
	     * or microseconds.
	     */

	    threshold = (Tcl_WideUInt)(middle - start) * TR_SCALE / count;
	    if (threshold > avgIterTm) {

		/*
		 * Iterations seem to be longer.
		 */

		if (threshold > avgIterTm * 2) {
		    factor *= 2;
		} else {
		    factor++;
		}
		if (factor > TR_MAX_FACTOR) {
		    factor = TR_MAX_FACTOR;
		}
	    } else if (factor > TR_MIN_FACTOR) {
		/*
		 * Iterations seem to be shorter.
		 */

		if (threshold < (avgIterTm / 2)) {
		    factor /= 2;
		    if (factor < TR_MIN_FACTOR) {
			factor = TR_MIN_FACTOR;
		    }
		} else {
		    factor--;
		}
	    }

	    if (!threshold) {
		/* too short and too few iterations */
		threshold = 1;
		continue;
	    }
	    avgIterTm = threshold;

	    /*
	     * Estimate last iteration time growth and time of next iteration.
	     */
	    lastCount = count - lastCount;
	    if (last != start && lastCount) {
		Tcl_WideUInt lastTm;

		lastTm = (Tcl_WideUInt)(middle - last) * TR_SCALE / lastCount;
		estIterTm = (double)lastTm / (lastIterTm ? lastIterTm : avgIterTm);
		lastIterTm = lastTm > avgIterTm ? lastTm : avgIterTm;
	    } else {
		lastIterTm = avgIterTm;
	    }
	    estIterTm *= lastIterTm;
	    last = middle;
	    lastCount = count;

	    /*
	     * Calculate next threshold to check.
	     * Firstly check iteration time is not larger than remaining time,
	     * considering last known iteration growth factor.
	     */
	    threshold = (Tcl_WideUInt)(stop - middle) * TR_SCALE;
	     /*
	      * Estimated count of iteration til the end of execution.
	      * Thereby 2.5% longer execution time would be OK.
	      */
	    if (threshold / estIterTm < 0.975) {
		/* estimated time for next iteration is too large */
		break;
	    }
	    threshold /= estIterTm;
	    /*
	     * Don't use threshold by few iterations, because sometimes
	     * first iteration(s) can be too fast or slow (cached, delayed
	     * clean up, etc). Also avoid unexpected execution time growth,
	     * so if iterations continuously grow, stay by single iteration.
	     */
	    if (count < 10 || factor >= TR_FACT_SINGLE_ITER) {
		threshold = 1;
		continue;
	    }
	    /*
	     * Reduce it by last known factor, to avoid unexpected execution
	     * time growth if iterations are not consistent (may be longer).
	     */
	    threshold = threshold / factor + 1;
	    if (threshold > 100000) {	/* fix for too large threshold */
		threshold = 100000;
	    }

	    /*
	     * Consider max-count
	     */

	    if (threshold > maxcnt - count) {
		threshold = maxcnt - count;
	    }
	}
    }

    {
	Tcl_Obj *objarr[8], **objs = objarr;
	Tcl_WideUInt usec, val;
	int digits;

	/*
	 * Absolute execution time in microseconds or in wide clicks.
	 */
	usec = (Tcl_WideUInt)(middle - start);

#ifdef TCL_WIDE_CLICKS
	/*
	 * convert execution time (in wide clicks) to microsecs.
	 */

	usec *= TclpWideClickInMicrosec();
#endif /* TCL_WIDE_CLICKS */

	if (!count) {		/* no iterations - avoid divide by zero */
	    TclNewIntObj(objs[4], 0);
	    objs[0] = objs[2] = objs[4];
	    goto retRes;
	}

	/*
	 * If not calibrating...
	 */

	if (!calibrate) {
	    /*
	     * Minimize influence of measurement overhead.
	     */

	    if (overhead > 0) {
		/*
		 * Estimate the time of overhead (microsecs).
		 */

		Tcl_WideUInt curOverhead = overhead * count;

		if (usec > curOverhead) {
		    usec -= curOverhead;
		} else {
		    usec = 0;
		}
	    }
	} else {
	    /*
	     * Calibration: obtaining new measurement overhead.
	     */

	    if (measureOverhead > ((double) usec) / count) {
		measureOverhead = ((double) usec) / count;
	    }
	    TclNewDoubleObj(objs[0], measureOverhead);
	    TclNewLiteralStringObj(objs[1], "\xC2\xB5s/#-overhead"); /* mics */
	    objs += 2;
	}

	val = usec / count;		/* microsecs per iteration */
	if (val >= 1000000) {
	    TclNewIntObj(objs[0], val);
	} else {
	    if (val < 10) {
		digits = 6;
	    } else if (val < 100) {
		digits = 4;
	    } else if (val < 1000) {
		digits = 3;
	    } else if (val < 10000) {
		digits = 2;
	    } else {
		digits = 1;
	    }
	    objs[0] = Tcl_ObjPrintf("%.*f", digits, ((double) usec)/count);
	}

	TclNewIntObj(objs[2], count); /* iterations */

	/*
	 * Calculate speed as rate (count) per sec
	 */

	if (!usec) {
	    usec++;			/* Avoid divide by zero. */
	}
	if (count < (WIDE_MAX / 1000000)) {
	    val = (count * 1000000) / usec;
	    if (val < 100000) {
		if (val < 100) {
		    digits = 3;
		} else if (val < 1000) {
		    digits = 2;
		} else {
		    digits = 1;
		}
		objs[4] = Tcl_ObjPrintf("%.*f",
			digits, ((double) (count * 1000000)) / usec);
	    } else {
		TclNewIntObj(objs[4], val);
	    }
	} else {
	    objs[4] = Tcl_NewWideIntObj((count / usec) * 1000000);
	}

    retRes:
	/*
	 * Estimated net execution time (in millisecs).
	 */

	if (!calibrate) {
	    if (usec >= 1) {
		objs[6] = Tcl_ObjPrintf("%.3f", (double)usec / 1000);
	    } else {
		TclNewIntObj(objs[6], 0);
	    }
	    TclNewLiteralStringObj(objs[7], "net-ms");
	}

	/*
	 * Construct the result as a list because many programs have always
	 * parsed as such (extracting the first element, typically).
	 */

	TclNewLiteralStringObj(objs[1], "\xC2\xB5s/#"); /* mics/# */
	TclNewLiteralStringObj(objs[3], "#");
	TclNewLiteralStringObj(objs[5], "#/sec");
	Tcl_SetObjResult(interp, Tcl_NewListObj(8, objarr));
    }

  done:
    if (codePtr != NULL) {
	TclReleaseByteCode(codePtr);
    }
    return result;
#undef TR_SCALE
#undef TR_MIN_FACTOR
#undef TR_MAX_FACTOR
#undef TR_FACT_SINGLE_ITER
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_TryObjCmd, TclNRTryObjCmd --
 *
 *	This procedure is invoked to process the "try" Tcl command. See the
 *	user documentation (or TIP #329) for details on what it does.
 *
 * Results:
 *	A standard Tcl object result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_TryObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRTryObjCmd, clientData, objc, objv);
}

int
TclNRTryObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    Tcl_Obj *bodyObj, *handlersObj, *finallyObj = NULL;
    int i, bodyShared, haveHandlers, code;
    Tcl_Size dummy;
    static const char *const handlerNames[] = {
	"finally", "on", "trap", NULL
    };
    enum Handlers {
	TryFinally, TryOn, TryTrap
    };

    /*
     * Parse the arguments. The handlers are passed to subsequent callbacks as
     * a Tcl_Obj list of the 5-tuples like (type, returnCode, errorCodePrefix,
     * bindVariables, script), and the finally script is just passed as it is.
     */

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv,
		"body ?handler ...? ?finally script?");
	return TCL_ERROR;
    }
    bodyObj = objv[1];
    TclNewObj(handlersObj);
    bodyShared = 0;
    haveHandlers = 0;
    for (i=2 ; i<objc ; i++) {
	enum Handlers type;
	Tcl_Obj *info[5];

	if (Tcl_GetIndexFromObj(interp, objv[i], handlerNames, "handler type",
		0, &type) != TCL_OK) {
	    Tcl_DecrRefCount(handlersObj);
	    return TCL_ERROR;
	}
	switch (type) {
	case TryFinally:	/* finally script */
	    if (i < objc-2) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"finally clause must be last", -1));
		Tcl_DecrRefCount(handlersObj);
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "FINALLY",
			"NONTERMINAL", (char *)NULL);
		return TCL_ERROR;
	    } else if (i == objc-1) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"wrong # args to finally clause: must be"
			" \"... finally script\"", -1));
		Tcl_DecrRefCount(handlersObj);
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "FINALLY",
			"ARGUMENT", (char *)NULL);
		return TCL_ERROR;
	    }
	    finallyObj = objv[++i];
	    break;

	case TryOn:		/* on code variableList script */
	    if (i > objc-4) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"wrong # args to on clause: must be \"... on code"
			" variableList script\"", -1));
		Tcl_DecrRefCount(handlersObj);
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "ON",
			"ARGUMENT", (char *)NULL);
		return TCL_ERROR;
	    }
	    if (TclGetCompletionCodeFromObj(interp, objv[i+1],
		    &code) != TCL_OK) {
		Tcl_DecrRefCount(handlersObj);
		return TCL_ERROR;
	    }
	    info[2] = NULL;
	    goto commonHandler;

	case TryTrap:		/* trap pattern variableList script */
	    if (i > objc-4) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj(
			"wrong # args to trap clause: "
			"must be \"... trap pattern variableList script\"",
			-1));
		Tcl_DecrRefCount(handlersObj);
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "TRAP",
			"ARGUMENT", (char *)NULL);
		return TCL_ERROR;
	    }
	    code = 1;
	    if (TclListObjLength(NULL, objv[i+1], &dummy) != TCL_OK) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"bad prefix '%s': must be a list",
			TclGetString(objv[i+1])));
		Tcl_DecrRefCount(handlersObj);
		Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "TRAP",
			"EXNFORMAT", (char *)NULL);
		return TCL_ERROR;
	    }
	    info[2] = objv[i+1];

	commonHandler:
	    if (TclListObjLength(interp, objv[i+2], &dummy) != TCL_OK) {
		Tcl_DecrRefCount(handlersObj);
		return TCL_ERROR;
	    }

	    info[0] = objv[i];			/* type */
	    TclNewIntObj(info[1], code);	/* returnCode */
	    if (info[2] == NULL) {		/* errorCodePrefix */
		TclNewObj(info[2]);
	    }
	    info[3] = objv[i+2];		/* bindVariables */
	    info[4] = objv[i+3];		/* script */

	    bodyShared = !strcmp(TclGetString(objv[i+3]), "-");
	    Tcl_ListObjAppendElement(NULL, handlersObj,
		    Tcl_NewListObj(5, info));
	    haveHandlers = 1;
	    i += 3;
	    break;
	default:
	    TCL_UNREACHABLE();
	}
    }
    if (bodyShared) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(
		"last non-finally clause must not have a body of \"-\"", -1));
	Tcl_DecrRefCount(handlersObj);
	Tcl_SetErrorCode(interp, "TCL", "OPERATION", "TRY", "BADFALLTHROUGH",
		(char *)NULL);
	return TCL_ERROR;
    }
    if (!haveHandlers) {
	Tcl_DecrRefCount(handlersObj);
	handlersObj = NULL;
    }

    /*
     * Execute the body.
     */

    Tcl_NRAddCallback(interp, TryPostBody, handlersObj, finallyObj,
	    (void *)objv, INT2PTR(objc));
    return TclNREvalObjEx(interp, bodyObj, 0,
	    ((Interp *) interp)->cmdFramePtr, 1);
}

/*
 *----------------------------------------------------------------------
 *
 * During --
 *
 *	This helper function patches together the updates to the interpreter's
 *	return options that are needed when things fail during the processing
 *	of a handler or finally script for the [try] command.
 *
 * Returns:
 *	The new option dictionary.
 *
 *----------------------------------------------------------------------
 */

static inline Tcl_Obj *
During(
    Tcl_Interp *interp,
    int resultCode,		/* The result code from the just-evaluated
				 * script. */
    Tcl_Obj *oldOptions,	/* The old option dictionary. */
    Tcl_Obj *errorInfo)		/* An object to append to the errorinfo and
				 * release, or NULL if nothing is to be added.
				 * Designed to be used with Tcl_ObjPrintf. */
{
    Tcl_Obj *options;

    if (errorInfo != NULL) {
	Tcl_AppendObjToErrorInfo(interp, errorInfo);
    }
    options = Tcl_GetReturnOptions(interp, resultCode);
    TclDictPut(interp, options, "-during", oldOptions);
    Tcl_IncrRefCount(options);
    Tcl_DecrRefCount(oldOptions);
    return options;
}

/*
 *----------------------------------------------------------------------
 *
 * TryPostBody --
 *
 *	Callback to handle the outcome of the execution of the body of a 'try'
 *	command.
 *
 *----------------------------------------------------------------------
 */

static int
TryPostBody(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Tcl_Obj *resultObj, *options, *handlersObj, *finallyObj, *cmdObj, **objv;
    int code, objc;
    Tcl_Size i, numHandlers = 0;

    handlersObj = (Tcl_Obj *)data[0];
    finallyObj = (Tcl_Obj *)data[1];
    objv = (Tcl_Obj **)data[2];
    objc = PTR2INT(data[3]);

    cmdObj = objv[0];

    /*
     * Check for limits/rewinding, which override normal trapping behaviour.
     */

    if (((Interp*) interp)->execEnvPtr->rewind || Tcl_LimitExceeded(interp)) {
	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"%s\" body line %d)", TclGetString(cmdObj),
		Tcl_GetErrorLine(interp)));
	if (handlersObj != NULL) {
	    Tcl_DecrRefCount(handlersObj);
	}
	return TCL_ERROR;
    }

    /*
     * Basic processing of the outcome of the script, including adding of
     * errorinfo trace.
     */

    if (result == TCL_ERROR) {
	Tcl_AppendObjToErrorInfo(interp, Tcl_ObjPrintf(
		"\n    (\"%s\" body line %d)", TclGetString(cmdObj),
		Tcl_GetErrorLine(interp)));
    }
    resultObj = Tcl_GetObjResult(interp);
    Tcl_IncrRefCount(resultObj);
    options = Tcl_GetReturnOptions(interp, result);
    Tcl_IncrRefCount(options);
    Tcl_ResetResult(interp);

    /*
     * Handle the results.
     */

    if (handlersObj != NULL) {
	int found = 0;
	Tcl_Obj **handlers, **info;

	TclListObjGetElements(NULL, handlersObj, &numHandlers, &handlers);
	for (i=0 ; i<numHandlers ; i++) {
	    Tcl_Obj *handlerBodyObj;
	    Tcl_Size numElems = 0;

	    TclListObjGetElements(NULL, handlers[i], &numElems, &info);
	    if (!found) {
		Tcl_GetIntFromObj(NULL, info[1], &code);
		if (code != result) {
		    continue;
		}

		/*
		 * When processing an error, we must also perform list-prefix
		 * matching of the errorcode list. However, if this was an
		 * 'on' handler, the list that we are matching against will be
		 * empty.
		 */

		if (code == TCL_ERROR) {
		    Tcl_Obj *errcode, **bits1, **bits2;
		    Tcl_Size len1, len2, j;

		    TclDictGet(NULL, options, "-errorcode", &errcode);
		    TclListObjGetElements(NULL, info[2], &len1, &bits1);
		    if (TclListObjGetElements(NULL, errcode, &len2,
			    &bits2) != TCL_OK) {
			continue;
		    }
		    if (len2 < len1) {
			continue;
		    }
		    for (j=0 ; j<len1 ; j++) {
			if (TclStringCmp(bits1[j], bits2[j], 1, 0,
				TCL_INDEX_NONE) != 0) {
			    /*
			     * Really want 'continue outerloop;', but C does
			     * not give us that.
			     */

			    goto didNotMatch;
			}
		    }
		}

		found = 1;
	    }

	    /*
	     * Now we need to scan forward over "-" bodies. Note that we've
	     * already checked that the last body is not a "-", so this search
	     * will terminate successfully.
	     */

	    if (!strcmp(TclGetString(info[4]), "-")) {
		continue;
	    }

	    /*
	     * Bind the variables. We already know this is a list of variable
	     * names, but it might be empty.
	     */

	    Tcl_ResetResult(interp);
	    result = TCL_ERROR;
	    TclListObjLength(NULL, info[3], &numElems);
	    if (numElems> 0) {
		Tcl_Obj *varName;

		Tcl_ListObjIndex(NULL, info[3], 0, &varName);
		if (Tcl_ObjSetVar2(interp, varName, NULL, resultObj,
			TCL_LEAVE_ERR_MSG) == NULL) {
		    Tcl_DecrRefCount(resultObj);
		    goto handlerFailed;
		}
		Tcl_DecrRefCount(resultObj);
		if (numElems> 1) {
		    Tcl_ListObjIndex(NULL, info[3], 1, &varName);
		    if (Tcl_ObjSetVar2(interp, varName, NULL, options,
			    TCL_LEAVE_ERR_MSG) == NULL) {
			goto handlerFailed;
		    }
		}
	    } else {
		/*
		 * Dispose of the result to prevent a memleak. [Bug 2910044]
		 */

		Tcl_DecrRefCount(resultObj);
	    }

	    /*
	     * Evaluate the handler body and process the outcome. Note that we
	     * need to keep the kind of handler for debugging purposes, and in
	     * any case anything we want from info[] must be extracted right
	     * now because the info[] array is about to become invalid. There
	     * is very little refcount handling here however, since we know
	     * that the objects that we still want to refer to now were input
	     * arguments to [try] and so are still on the Tcl value stack.
	     */

	    handlerBodyObj = info[4];
	    Tcl_NRAddCallback(interp, TryPostHandler, objv, options, info[0],
		    INT2PTR((finallyObj == NULL) ? 0 : objc - 1));
	    Tcl_DecrRefCount(handlersObj);
	    return TclNREvalObjEx(interp, handlerBodyObj, 0,
		    ((Interp *) interp)->cmdFramePtr, 4*i + 5);

	handlerFailed:
	    resultObj = Tcl_GetObjResult(interp);
	    Tcl_IncrRefCount(resultObj);
	    options = During(interp, result, options, NULL);
	    break;

	didNotMatch:
	    continue;
	}

	/*
	 * No handler matched; get rid of the list of handlers.
	 */

	Tcl_DecrRefCount(handlersObj);
    }

    /*
     * Process the finally clause.
     */

    if (finallyObj != NULL) {
	Tcl_NRAddCallback(interp, TryPostFinal, resultObj, options, cmdObj,
		NULL);
	return TclNREvalObjEx(interp, finallyObj, 0,
		((Interp *) interp)->cmdFramePtr, objc - 1);
    }

    /*
     * Install the correct result/options into the interpreter and clean up
     * any temporary storage.
     */

    result = Tcl_SetReturnOptions(interp, options);
    Tcl_DecrRefCount(options);
    Tcl_SetObjResult(interp, resultObj);
    Tcl_DecrRefCount(resultObj);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * TryPostHandler --
 *
 *	Callback to handle the outcome of the execution of a handler of a
 *	'try' command.
 *
 *----------------------------------------------------------------------
 */

static int
TryPostHandler(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Tcl_Obj *resultObj, *cmdObj, *options, *handlerKindObj, **objv;
    Tcl_Obj *finallyObj;
    int finallyIndex;

    objv = (Tcl_Obj **)data[0];
    options = (Tcl_Obj *)data[1];
    handlerKindObj = (Tcl_Obj *)data[2];
    finallyIndex = PTR2INT(data[3]);

    cmdObj = objv[0];
    finallyObj = finallyIndex ? objv[finallyIndex] : 0;

    /*
     * Check for limits/rewinding, which override normal trapping behaviour.
     */

    if (((Interp*) interp)->execEnvPtr->rewind || Tcl_LimitExceeded(interp)) {
	options = During(interp, result, options, Tcl_ObjPrintf(
		"\n    (\"%s ... %s\" handler line %d)",
		TclGetString(cmdObj), TclGetString(handlerKindObj),
		Tcl_GetErrorLine(interp)));
	Tcl_DecrRefCount(options);
	return TCL_ERROR;
    }

    /*
     * The handler result completely substitutes for the result of the body.
     */

    resultObj = Tcl_GetObjResult(interp);
    Tcl_IncrRefCount(resultObj);
    if (result == TCL_ERROR) {
	options = During(interp, result, options, Tcl_ObjPrintf(
		"\n    (\"%s ... %s\" handler line %d)",
		TclGetString(cmdObj), TclGetString(handlerKindObj),
		Tcl_GetErrorLine(interp)));
    } else {
	Tcl_DecrRefCount(options);
	options = Tcl_GetReturnOptions(interp, result);
	Tcl_IncrRefCount(options);
    }

    /*
     * Process the finally clause if it is present.
     */

    if (finallyObj != NULL) {
	Interp *iPtr = (Interp *) interp;

	Tcl_NRAddCallback(interp, TryPostFinal, resultObj, options, cmdObj,
		NULL);

	/* The 'finally' script is always the last argument word. */
	return TclNREvalObjEx(interp, finallyObj, 0, iPtr->cmdFramePtr,
		finallyIndex);
    }

    /*
     * Install the correct result/options into the interpreter and clean up
     * any temporary storage.
     */

    result = Tcl_SetReturnOptions(interp, options);
    Tcl_DecrRefCount(options);
    Tcl_SetObjResult(interp, resultObj);
    Tcl_DecrRefCount(resultObj);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * TryPostFinal --
 *
 *	Callback to handle the outcome of the execution of the finally script
 *	of a 'try' command.
 *
 *----------------------------------------------------------------------
 */

static int
TryPostFinal(
    void *data[],
    Tcl_Interp *interp,
    int result)
{
    Tcl_Obj *resultObj, *options, *cmdObj;

    resultObj = (Tcl_Obj *)data[0];
    options = (Tcl_Obj *)data[1];
    cmdObj = (Tcl_Obj *)data[2];

    /*
     * If the result wasn't OK, we need to adjust the result options.
     */

    if (result != TCL_OK) {
	Tcl_DecrRefCount(resultObj);
	resultObj = NULL;
	if (result == TCL_ERROR) {
	    options = During(interp, result, options, Tcl_ObjPrintf(
		    "\n    (\"%s ... finally\" body line %d)",
		    TclGetString(cmdObj), Tcl_GetErrorLine(interp)));
	} else {
	    Tcl_Obj *origOptions = options;

	    options = Tcl_GetReturnOptions(interp, result);
	    Tcl_IncrRefCount(options);
	    Tcl_DecrRefCount(origOptions);
	}
    }

    /*
     * Install the correct result/options into the interpreter and clean up
     * any temporary storage.
     */

    result = Tcl_SetReturnOptions(interp, options);
    Tcl_DecrRefCount(options);
    if (resultObj != NULL) {
	Tcl_SetObjResult(interp, resultObj);
	Tcl_DecrRefCount(resultObj);
    }
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_WhileObjCmd --
 *
 *	This procedure is invoked to process the "while" Tcl command. See the
 *	user documentation for details on what it does.
 *
 *	With the bytecode compiler, this procedure is only called when a
 *	command name is computed at runtime, and is "while" or the name to
 *	which "while" was renamed: e.g., "set z while; $z {$i<100} {}"
 *
 * Results:
 *	A standard Tcl result.
 *
 * Side effects:
 *	See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_WhileObjCmd(
    void *clientData,
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    return Tcl_NRCallObjProc(interp, TclNRWhileObjCmd, clientData, objc, objv);
}

int
TclNRWhileObjCmd(
    TCL_UNUSED(void *),
    Tcl_Interp *interp,		/* Current interpreter. */
    int objc,			/* Number of arguments. */
    Tcl_Obj *const objv[])	/* Argument objects. */
{
    ForIterData *iterPtr;

    if (objc != 3) {
	Tcl_WrongNumArgs(interp, 1, objv, "test command");
	return TCL_ERROR;
    }

    /*
     * We reuse [for]'s callback, passing a NULL for the 'next' script.
     */

    TclSmallAllocEx(interp, sizeof(ForIterData), iterPtr);
    iterPtr->cond = objv[1];
    iterPtr->body = objv[2];
    iterPtr->next = NULL;
    iterPtr->msg  = "\n    (\"while\" body line %d)";
    iterPtr->word = 2;

    TclNRAddCallback(interp, TclNRForIterCallback, iterPtr, NULL,
	    NULL, NULL);
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * TclListLines --
 *
 *	???
 *
 * Results:
 *	Filled in array of line numbers?
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

void
TclListLines(
    Tcl_Obj *listObj,		/* Pointer to obj holding a string with list
				 * structure. Assumed to be valid. Assumed to
				 * contain n elements. */
    Tcl_Size line,		/* Line the list as a whole starts on. */
    Tcl_Size n,			/* #elements in lines */
    Tcl_Size *lines,		/* Array of line numbers, to fill. */
    Tcl_Obj *const *elems)      /* The list elems as Tcl_Obj*, in need of
				 * derived continuation data */
{
    const char *listStr = TclGetString(listObj);
    const char *listHead = listStr;
    Tcl_Size i, length = strlen(listStr);
    const char *element = NULL, *next = NULL;
    ContLineLoc *clLocPtr = TclContinuationsGet(listObj);
    Tcl_Size *clNext = (clLocPtr ? &clLocPtr->loc[0] : NULL);

    for (i = 0; i < n; i++) {
	TclFindElement(NULL, listStr, length, &element, &next, NULL, NULL);

	TclAdvanceLines(&line, listStr, element);
				/* Leading whitespace */
	TclAdvanceContinuations(&line, &clNext, element - listHead);
	if (elems && clNext) {
	    TclContinuationsEnterDerived(elems[i], element-listHead, clNext);
	}
	lines[i] = line;
	length -= (next - listStr);
	TclAdvanceLines(&line, element, next);
				/* Element */
	listStr = next;

	if (*element == 0) {
	    /* ASSERT i == n */
	    break;
	}
    }
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
