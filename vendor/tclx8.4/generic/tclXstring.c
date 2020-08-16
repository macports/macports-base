/* 
 * tclXstring.c --
 *
 *      Extended TCL string and character manipulation commands.
 *-----------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXstring.c,v 1.4 2005/11/21 18:38:51 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

/*FIX: Add creplace to overwrite characters in a string. */

#include "tclExtdInt.h"


/*
 * Prototypes of internal functions.
 */
static int
CheckForUniCode _ANSI_ARGS_((Tcl_Interp *interp,
                             char *str,
                             int strLen,
                             char *which));

static unsigned int
ExpandString _ANSI_ARGS_((unsigned char *inStr,
                          int            inLength,
                          unsigned char  outStr [],
                          int           *outLengthPtr));

static int 
TclX_CindexObjCmd _ANSI_ARGS_((ClientData clientData,
                               Tcl_Interp *interp,
                               int         objc,
                               Tcl_Obj   *CONST objv[]));

static int 
TclX_ClengthObjCmd _ANSI_ARGS_((ClientData clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj   *CONST objv[]));

static int
TclX_CconcatObjCmd _ANSI_ARGS_((ClientData clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj   *CONST objv[]));

static int 
TclX_CrangeObjCmd _ANSI_ARGS_((ClientData clientData,
                               Tcl_Interp *interp,
                               int         objc,
                               Tcl_Obj   *CONST objv[]));

static int 
TclX_CcollateObjCmd _ANSI_ARGS_((ClientData clientData,
                                 Tcl_Interp *interp,
                                 int         objc,
                                 Tcl_Obj   *CONST objv[]));

static int 
TclX_ReplicateObjCmd _ANSI_ARGS_((ClientData clientData,
                                  Tcl_Interp *interp,
                                  int         objc,
                                  Tcl_Obj   *CONST objv[]));

static int 
TclX_TranslitObjCmd _ANSI_ARGS_((ClientData clientData,
                                 Tcl_Interp *interp,
                                 int         objc,
                                 Tcl_Obj   *CONST objv[]));

static int 
TclX_CtypeObjCmd _ANSI_ARGS_((ClientData clientData,
                              Tcl_Interp *interp,
                              int         objc,
                              Tcl_Obj   *CONST objv[]));

static int 
TclX_CtokenObjCmd _ANSI_ARGS_((ClientData clientData,
                               Tcl_Interp *interp,
                               int         objc,
                               Tcl_Obj   *CONST objv[]));

static int 
TclX_CequalObjCmd _ANSI_ARGS_((ClientData clientData,
                               Tcl_Interp *interp,
                               int         objc,
                               Tcl_Obj   *CONST objv[]));


/*-----------------------------------------------------------------------------
 * TclX_CindexObjCmd --
 *     Implements the cindex Tcl command:
 *         cindex string indexExpr
 *
 * Results:
 *      Returns the character indexed by  index  (zero  based)  from string. 
 *-----------------------------------------------------------------------------
 */
static int
TclX_CindexObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int strLen, utfLen, idx, numBytes;
    char *str, buf [TCL_UTF_MAX];

    if (objc != 3)
        return TclX_WrongArgs (interp, objv[0], "string indexExpr");
    
    str = Tcl_GetStringFromObj (objv[1], &strLen);
    utfLen = Tcl_NumUtfChars(str, strLen);

    if (TclX_RelativeExpr (interp, objv [2], utfLen, &idx) != TCL_OK) {
        return TCL_ERROR;
    }

    if ((idx < 0) || (idx >= utfLen))
        return TCL_OK;

    numBytes = Tcl_UniCharToUtf(Tcl_UniCharAtIndex(str, idx), buf);
    Tcl_SetStringObj (Tcl_GetObjResult (interp), buf, numBytes);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_ClengthObjCmd --
 *     Implements the clength Tcl command:
 *         clength string
 *
 * Results:
 *      Returns the length of string in characters. 
 *-----------------------------------------------------------------------------
 */
static int
TclX_ClengthObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    char *str;
    int strLen;

    if (objc != 2)
        return TclX_WrongArgs (interp, objv[0], "string");

    str = Tcl_GetStringFromObj (objv[1], &strLen);
    Tcl_SetIntObj (Tcl_GetObjResult (interp), Tcl_NumUtfChars(str, strLen));
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_CconcatObjCmd --
 *     Implements the cconcat TclX command:
 *         cconcat ?string? ?string? ?...?
 *
 * Results:
 *      The arguments concatenated.
 *-----------------------------------------------------------------------------
 */
static int
TclX_CconcatObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *resultPtr = Tcl_GetObjResult(interp);
    int idx, strLen;
    char *str;

    for (idx = 1; idx < objc; idx++) {
	str = Tcl_GetStringFromObj(objv[idx], &strLen);
	Tcl_AppendToObj(resultPtr, str, strLen);
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_CrangeObjCmd --
 *     Implements the crange and csubstr Tcl commands:
 *         crange string firstExpr lastExpr
 *         csubstr string firstExpr lengthExpr
 *
 * Results:
 *      Standard Tcl result.
 * Notes:
 *   If clientData is TRUE its the range command, if its FALSE its csubstr.
 *-----------------------------------------------------------------------------
 */
static int
TclX_CrangeObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int strLen, utfLen, first, subLen;
    size_t isRange = (size_t) clientData;
    char *str;
    CONST84 char *start, *end;

    if (objc != 4) {
        if (isRange)
            return TclX_WrongArgs (interp, objv[0], 
                                   "string firstExpr lastExpr");
        else
            return TclX_WrongArgs (interp, objv[0], 
                                   "string firstExpr lengthExpr");
    }

    str = Tcl_GetStringFromObj (objv [1], &strLen);
    utfLen = Tcl_NumUtfChars(str, strLen);

    if (TclX_RelativeExpr (interp, objv [2], utfLen, &first) != TCL_OK) {
        return TCL_ERROR;
    }

    if ((first < 0) || (first >= utfLen))
        return TCL_OK;

    if (TclX_RelativeExpr (interp, objv [3], utfLen, &subLen) != TCL_OK) {
        return TCL_ERROR;
    }

    if (isRange) {
        if (subLen < first)
            return TCL_OK;
        subLen = subLen - first +1;
    }

    if (first + subLen > utfLen)
        subLen = utfLen - first;

    start = Tcl_UtfAtIndex(str, first);
    end = Tcl_UtfAtIndex(start, subLen);
    Tcl_SetStringObj(Tcl_GetObjResult(interp), start, end - start);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_CcollateObjCmd --
 *     Implements ccollate Tcl commands:
 *         ccollate [-local] string1 string2
 *
 * Results:
 *      Standard Tcl result.
 *-----------------------------------------------------------------------------
 */
static int
TclX_CcollateObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int argIndex, result, local = FALSE;
    char *optionString;
    char *string1;
    int string1Len;
    char *string2;
    int string2Len;

    /*FIX: Not utf clean (FIXUTF), can it ever be... */
    if ((objc < 3) || (objc > 4))
        return TclX_WrongArgs (interp, objv[0], "?options? string1 string2");

    if (objc == 4) {
        optionString = Tcl_GetStringFromObj (objv [1], NULL);
        if (!STREQU (optionString, "-local")) {
            TclX_AppendObjResult (interp, "Invalid option \"", optionString,
                                  "\", expected \"-local\"", (char *) NULL);
            return TCL_ERROR;
        }
        local = TRUE;
    }
    argIndex = objc - 2;
    
    string1 = Tcl_GetStringFromObj (objv [argIndex], &string1Len);
    string2 = Tcl_GetStringFromObj (objv [argIndex + 1], &string2Len);
    if ((strlen (string1) != (size_t) string1Len) ||
	(strlen (string1) != (size_t) string1Len)) {
        TclX_AppendObjResult (interp, "The " ,
                              Tcl_GetStringFromObj (objv [0], NULL),
                              " command does not support binary data",
                              (char *) NULL);
        return TCL_ERROR;
    }
    if (local) {
#ifndef NO_STRCOLL
        result = strcoll (string1, string2);
#else
        result = strcmp (string1, string2);
#endif
    } else {
        result = strcmp (string1, string2);
    }
    Tcl_SetIntObj (Tcl_GetObjResult (interp),
                   ((result == 0) ? 0 : ((result < 0) ? -1 : 1)));
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_ReplicateObjCmd --
 *     Implements the replicate Tcl command:
 *         replicate string countExpr
 *
 * Results:
 *      Returns string replicated count times.
 *-----------------------------------------------------------------------------
 */
static int
TclX_ReplicateObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    Tcl_Obj     *resultPtr = Tcl_GetObjResult (interp);
    long         count;
    long         repCount;
    char        *stringPtr;
    int          stringLength;

    if (objc != 3)
        return TclX_WrongArgs (interp, objv[0], "string countExpr");

    if (Tcl_GetLongFromObj (interp, objv [2], &repCount) != TCL_OK)
        return TCL_ERROR;

    stringPtr = Tcl_GetStringFromObj (objv [1], &stringLength);
    for (count = 0; count < repCount; count++) {
        Tcl_AppendToObj (resultPtr, stringPtr, stringLength);
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_CtokenObjCmd --
 *     Implements the clength Tcl command:
 *         ctoken strvar separators
 *
 * Results:
 *      Returns the first token and removes it from the string variable.
 * FIX: Add command to make a list.  Better yet, a new cparse command thats
 * more flexable and includes this functionality.
 *-----------------------------------------------------------------------------
 */
static int
TclX_CtokenObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj* stringVarObj;
    char* string;
    int strByteLen;
    int strByteIdx;
    char* separators;
    int separatorsLen;
    int tokenByteIdx;
    int tokenByteLen;
    Tcl_DString token;
    Tcl_UniChar uniChar;
    int utfBytes;
    Tcl_Obj *newVarValueObj;

    if (objc != 3) {
        return TclX_WrongArgs(interp, objv[0], "strvar separators");
    }
    
    stringVarObj = Tcl_ObjGetVar2(interp, objv[1], NULL,
                                  TCL_LEAVE_ERR_MSG|TCL_PARSE_PART1);
    if (stringVarObj == NULL) {
        return TCL_ERROR;
    }
    string = Tcl_GetStringFromObj(stringVarObj, &strByteLen);
    separators = Tcl_GetStringFromObj(objv[2], &separatorsLen);

    /* Find the start of the token */
    strByteIdx = 0;
    while (strByteIdx < strByteLen) {
        utfBytes = Tcl_UtfToUniChar(string+strByteIdx, &uniChar);
        if (Tcl_UtfFindFirst(separators, uniChar) == NULL) {
            break;  /* Reached a separator */
        }
        strByteIdx += utfBytes;
    }
    tokenByteIdx = strByteIdx;

    /* Find end of the token */
    while (strByteIdx < strByteLen) {
        utfBytes = Tcl_UtfToUniChar(string+strByteIdx, &uniChar);
        if (Tcl_UtfFindFirst(separators, uniChar) != NULL) {
            break;  /* Reached a separator */
        }
        strByteIdx += utfBytes;
    }
    tokenByteLen = strByteIdx-tokenByteIdx;

    /* Copy token, before replacing variable, as its coming from old var */
    Tcl_DStringInit(&token);
    Tcl_DStringAppend(&token, string+tokenByteIdx, tokenByteLen);

    /* Set variable argument to new string. */
    newVarValueObj = Tcl_NewStringObj(string+strByteIdx,
                                      strByteLen-strByteIdx);
    if (Tcl_SetVar2Ex(interp, Tcl_GetStringFromObj(objv[1], NULL), NULL,
                      newVarValueObj,
                      TCL_LEAVE_ERR_MSG|TCL_PARSE_PART1) == NULL) {
        Tcl_DStringFree (&token);
        Tcl_DecrRefCount (newVarValueObj);
        return TCL_ERROR;
    }

    Tcl_DStringResult(interp, &token);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_CequalObjCmd --
 *     Implements the cexpand Tcl command:
 *         cequal string1 string2
 *
 * Results:
 *   "0" or "1".
 *-----------------------------------------------------------------------------
 */
static int
TclX_CequalObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    char *string1Ptr;
    int string1Len;
    char *string2Ptr;
    int string2Len;

    if (objc != 3)
        return TclX_WrongArgs (interp, objv[0], "string1 string2");

    string1Ptr = Tcl_GetStringFromObj (objv[1], &string1Len);
    string2Ptr = Tcl_GetStringFromObj (objv[2], &string2Len);

    Tcl_SetBooleanObj (Tcl_GetObjResult (interp),
                       ((string1Len == string2Len) &&
                        (*string1Ptr == *string2Ptr) &&
                        (memcmp (string1Ptr, string2Ptr, string1Len) == 0)));
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Check for non-ascii characters in a translit string until we actually
 * make it work for UniCode.
 *-----------------------------------------------------------------------------
 */
static int CheckForUniCode(interp, str, strLen, which)
    Tcl_Interp  *interp;
    char *str;
    int strLen;
    char *which;
{
    int idx, nbytes;
    Tcl_UniChar uc;

    for (idx = 0; idx < strLen; idx++) {
        nbytes = Tcl_UtfToUniChar(&str[idx], &uc);
        if (nbytes != 1) {
            Tcl_AppendResult(interp, "Unicode character found in ", which,
                             ", the translit command does not yet support Unicode",
                             (char*)NULL);
            return TCL_ERROR;
        }
    }
    return TCL_OK;
}



/*-----------------------------------------------------------------------------
 * ExpandString --
 *  Build an expand version of a translit range specification.
 *
 * Results:
 *  The number of characters in the expansion buffer or < 0 if the maximum
 * expansion has been exceeded.
 *-----------------------------------------------------------------------------
 */
#define MAX_EXPANSION 255

static unsigned int
ExpandString(inStr, inLength, outStr, outLengthPtr)
    unsigned char *inStr;
    int            inLength;
    unsigned char  outStr [];
    int           *outLengthPtr;
{
    int i, j;
    unsigned char *s = inStr;
    unsigned char *inStrLimit = inStr + inLength;

    i = 0;
    while((s < inStrLimit) && (i < MAX_EXPANSION)) {
        if ((s [1] == '-') && (s [2] > s [0])) {
            for (j = s [0]; j <= s [2]; j++) {
                outStr [i++] = j;
            }
            s += 3;
        } else {
            outStr [i++] = *s++;
        }
    }
    *outLengthPtr = i;
    return (i < MAX_EXPANSION);
}

/*-----------------------------------------------------------------------------
 * TclX_TranslitObjCmd --
 *     Implements the Tcl translit command:
 *     translit inrange outrange string
 *
 * Results:
 *  Standard Tcl results.
 * FIXME:  Does not currently support non-ascii characters.
 *-----------------------------------------------------------------------------
 */
static int
TclX_TranslitObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj     *CONST objv[];
{
    unsigned char from [MAX_EXPANSION+1];
    int           fromLen;
    unsigned char to   [MAX_EXPANSION+1];
    int           toLen;
    short         map [MAX_EXPANSION+1];
    unsigned char *s;
    char          *fromString;
    int            fromStringLen;
    char          *toString;
    int            toStringLen;
    Tcl_Obj       *transStringObj;
    char          *transString;
    int            transStringLen;
    int            idx;
    int            stringIndex;

    /*FIX: Not UTF-safe.(FIXUTF) */

    if (objc != 4)
        return TclX_WrongArgs (interp, objv[0], "from to string");

    /*
     * Expand ranges into descrete values.
     */
    fromString = Tcl_GetStringFromObj (objv[1], &fromStringLen);
    if (CheckForUniCode(interp, fromString, fromStringLen,
                        "in-range") != TCL_OK) {
        return TCL_ERROR;
    }
    if (!ExpandString ((unsigned char *) fromString, fromStringLen,
                       from, &fromLen)) {
        TclX_AppendObjResult (interp, "inrange expansion too long",
                              (char *) NULL);
        return TCL_ERROR;
    }

    toString = Tcl_GetStringFromObj (objv [2], &toStringLen);
    if (CheckForUniCode(interp, toString, toStringLen,
                        "out-range") != TCL_OK) {
        return TCL_ERROR;
    }
    if (!ExpandString ((unsigned char *) toString, toStringLen,
                       to, &toLen)) {
        TclX_AppendObjResult (interp, "outrange expansion too long",
                              (char *) NULL);
        return TCL_ERROR;
    }

    if (fromLen > toLen) {
        TclX_AppendObjResult (interp, "inrange longer than outrange", 
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Build map.  Entries of -1 discard the char.  All other values are
     * positive (hence its a short).
     */
    for (idx = 0; idx <= MAX_EXPANSION; idx++) {
        map [idx] = idx;
    }
    for (idx = 0; (idx < toLen) && (idx < fromLen); idx++) {
        map [from [idx]] = to [idx];
    }
    for (; idx < fromLen; idx++)
        map [from [idx]] = -1;

    /*
     * Get a string object to transform.
     */
    transString = Tcl_GetStringFromObj (objv[3], &transStringLen);
    if (CheckForUniCode(interp, transString, transStringLen,
                        "string to translate") != TCL_OK) {
        return TCL_ERROR;
    }


    transStringObj = Tcl_NewStringObj (transString, transStringLen);
    transString = Tcl_GetStringFromObj (transStringObj, &transStringLen);

    for (s = (unsigned char *) transString, stringIndex = 0; 
         stringIndex < transStringLen; stringIndex++) {
        if (map [*s] >= 0) {
            *s = (unsigned char) map [*s];
            s++;
        }
    }

    Tcl_SetObjResult (interp, transStringObj);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_CtypeObjCmd --
 *
 *      This function implements the 'ctype' command:
 *      ctype ?-failindex? class string ?failIndexVar?
 *
 *      Where class is one of the following:
 *        digit, xdigit, lower, upper, alpha, alnum,
 *        space, cntrl,  punct, print, graph, ascii, char or ord.
 *
 * Results:
 *       One or zero: Depending if all the characters in the string are of
 *       the desired class.  Char and ord provide conversions and return the
 *       converted value.
 * FIX: Add check for legal number (can be negative, hex, etc).
 *-----------------------------------------------------------------------------
 */
static int
TclX_CtypeObjCmd (dummy, interp, objc, objv)
    ClientData   dummy;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int failIndex = FALSE;
    char *optStr, *class, *charStr;
    int charStrLen, cnt, idx;
    char *failVar = NULL;
    Tcl_Obj *classObj, *stringObj;
    int number;
    char charBuf[TCL_UTF_MAX];
    Tcl_UniChar uniChar;

#define IS_8BIT_UNICHAR(c) (c <= 255)

    if (TCL_UTF_MAX > sizeof(number)) {
        Tcl_Panic("TclX_CtypeObjCmd: UTF character longer than a int");
    }

    /*FIX: Split into multiple procs */
    /*FIX: Should use UtfNext to walk string */

    if (objc < 3) {
        goto wrongNumArgs;
    }

    optStr = Tcl_GetStringFromObj(objv[1], NULL);
    if (*optStr == '-') {
        if (STREQU(optStr, "-failindex")) {
            failIndex = TRUE;
        } else {
            TclX_AppendObjResult(interp, "invalid option \"",
                                 Tcl_GetStringFromObj (objv [1], NULL),
                                 "\", must be -failindex", (char *) NULL);
            return TCL_ERROR;
        }
    }
    if (failIndex) {
        if (objc != 5) {
            goto wrongNumArgs;
        }
        failVar = Tcl_GetStringFromObj(objv[2], NULL);
        classObj = objv[3];
        stringObj = objv[4];
    } else {
        if (objc != 3) {
            goto wrongNumArgs;
        }
        classObj = objv[1];
        stringObj = objv[2];
    }
    charStr = Tcl_GetStringFromObj(stringObj, &charStrLen);
    charStrLen = Tcl_NumUtfChars(charStr, charStrLen);
    class = Tcl_GetStringFromObj(classObj, NULL);

    /*
     * Handle conversion requests.
     */
    if (STREQU(class, "char")) {
        if (failIndex) {
          goto failInvalid;
        }
        if (Tcl_GetIntFromObj(interp, stringObj, &number) != TCL_OK) {
            return TCL_ERROR;
        }
        cnt = Tcl_UniCharToUtf(number, charBuf);
        charBuf[cnt] = '\0';
        Tcl_SetStringObj(Tcl_GetObjResult(interp), charBuf, cnt);
        return TCL_OK;
    }

    if (STREQU(class, "ord")) {
        if (failIndex) {
          goto failInvalid;
        }
        Tcl_UtfToUniChar(charStr, &uniChar);
        Tcl_SetIntObj(Tcl_GetObjResult(interp), (int)uniChar);
        return TCL_OK;
    }

    /*
     * The remainder of cases scan the string, stoping when their test case
     * fails.  The value of `index' after the loops indicating if it succeeds
     * or fails and where it fails.
     */
    if (STREQU(class, "alnum")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsAlnum(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "alpha")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsAlpha(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "ascii")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            if (!IS_8BIT_UNICHAR(uniChar)
                || !isascii(UCHAR(uniChar))) {
                break;
            }
        }
    } else if (STREQU(class, "cntrl")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            /* Only accepts ascii controls */
            if (!IS_8BIT_UNICHAR(uniChar)
                || !iscntrl(UCHAR(uniChar))) {
                break;
            }
        }
    } else if (STREQU(class, "digit")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsDigit(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "graph")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            if (!IS_8BIT_UNICHAR(uniChar)) {
                goto notSupportedUni;
            }
            if (!isgraph(UCHAR(uniChar))) {
                break;
            }
        }
    } else if (STREQU(class, "lower")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsLower(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "print")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            if (!IS_8BIT_UNICHAR(uniChar)) {
                goto notSupportedUni;
            }
            if (!isprint(UCHAR(uniChar))) {
                break;
            }
        }
    } else if (STREQU(class, "punct")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            if (!IS_8BIT_UNICHAR(uniChar)) {
                goto notSupportedUni;
            }
            if (!ispunct(UCHAR(uniChar))) {
                break;
            }
        }
    } else if (STREQU(class, "space")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsSpace(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "upper")) {
        for (idx = 0; idx < charStrLen; idx++) {
            if (!Tcl_UniCharIsUpper(Tcl_UniCharAtIndex(charStr, idx))) {
                break;
            }
        }
    } else if (STREQU(class, "xdigit")) {
        for (idx = 0; idx < charStrLen; idx++) {
            uniChar = Tcl_UniCharAtIndex(charStr, idx);
            if (!IS_8BIT_UNICHAR(uniChar)) {
                goto notSupportedUni;
            }
            if (!isxdigit(UCHAR(uniChar))) {
                break;
            }
        }
    } else {
        TclX_AppendObjResult (interp, "unrecognized class specification: \"",
                              class,
                              "\", expected one of: alnum, alpha, ascii, ",
                              "char, cntrl, digit, graph, lower, ord, ",
                              "print, punct, space, upper or xdigit",
                              (char *) NULL);
        return TCL_ERROR;
    }
    
    /*
     * Return true or false, depending if the end was reached.  Always return 
     * false for a null string.  Optionally return the failed index if there
     * is no match.
     */
    if ((idx != 0) && (idx == charStrLen)) {
        Tcl_SetBooleanObj (Tcl_GetObjResult (interp), TRUE);
    } else {
        /*
         * If the fail index was requested, set the variable here.
         */
        if (failIndex) {
            Tcl_Obj *iObj = Tcl_NewIntObj (idx);

            if (Tcl_SetVar2Ex(interp, failVar, NULL, 
                              iObj, TCL_LEAVE_ERR_MSG|TCL_PARSE_PART1) == NULL) {
                Tcl_DecrRefCount (iObj);
                return TCL_ERROR;
            }
        }
        Tcl_SetBooleanObj (Tcl_GetObjResult (interp), FALSE);
    }
    return TCL_OK;

  wrongNumArgs:
    return TclX_WrongArgs (interp, objv[0], "?-failindex var? class string");
    
  failInvalid:
    TclX_AppendObjResult (interp, "-failindex option is invalid for class \"",
                          class, "\"", (char *) NULL);
    return TCL_ERROR;

 notSupportedUni:
    TclX_AppendObjResult (interp, "unicode characters not supported for class \"",
                          class, "\"", (char *) NULL);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_StringInit --
 *   Initialize the list commands in an interpreter.
 *
 * Parameters:
 *   o interp - Interpreter to add commands to.
 *-----------------------------------------------------------------------------
 */
void
TclX_StringInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
			  "cindex",
                          TclX_CindexObjCmd, 
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "clength",
                          TclX_ClengthObjCmd, 
			  (ClientData) 0,
                          (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand (interp, 
			  "cconcat",
                          TclX_CconcatObjCmd, 
			  (ClientData) 0,
                          (Tcl_CmdDeleteProc *)NULL);

    Tcl_CreateObjCommand (interp, 
			  "crange",
                          TclX_CrangeObjCmd, 
			  (ClientData) TRUE, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "csubstr",
                          TclX_CrangeObjCmd,
			  (ClientData) FALSE, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "ccollate",
                          TclX_CcollateObjCmd,
			  (ClientData) 0,
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
			  "replicate",
                          TclX_ReplicateObjCmd, 
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "translit",
                          TclX_TranslitObjCmd,
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "ctype",
                          TclX_CtypeObjCmd,
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "ctoken",
                          TclX_CtokenObjCmd,
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "cequal",
			  TclX_CequalObjCmd,
			  (ClientData) 0, 
                          (Tcl_CmdDeleteProc*) NULL);

}


