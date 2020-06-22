/*
 * tclXutil.c
 *
 * Utility functions for Extended Tcl.
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
 * $Id: tclXutil.c,v 1.3 2002/09/26 00:19:18 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

#ifndef _tolower
#  define _tolower tolower
#  define _toupper toupper
#endif

/*
 * Prototypes of internal functions.
 */
static int
ParseTranslationOption _ANSI_ARGS_((char *strValue));

static char *
FormatTranslationOption _ANSI_ARGS_((int value));

static char *ERRORINFO = "errorInfo";
static char *ERRORCODE = "errorCode";

/*
 * Used to return argument messages by most commands.
 */
char *tclXWrongArgs = "wrong # args: ";


/*-----------------------------------------------------------------------------
 * TclX_StrToInt --
 *      Convert an Ascii string to an number of the specified base.
 *
 * Parameters:
 *   o string - String containing a number.
 *   o base - The base to use for the number 8, 10 or 16 or zero to decide
 *     based on the leading characters of the number.  Zero to let the number
 *     determine the base.
 *   o intPtr - Place to return the converted number.  Will be 
 *     unchanged if there is an error.
 *
 * Returns:
 *      Returns 1 if the string was a valid number, 0 invalid.
 *-----------------------------------------------------------------------------
 */
int
TclX_StrToInt (string, base, intPtr)
    CONST char *string;
    int         base;
    int        *intPtr;
{
    char *end, *p;
    int   i;

    /*
     * Note: use strtoul instead of strtol for integer conversions
     * to allow full-size unsigned numbers, but don't depend on strtoul
     * to handle sign characters;  it won't in some implementations.
     */

    errno = 0;
    for (p = (char *) string; isspace(UCHAR(*p)); p++) {
        /* Empty loop body. */
    }
    if (*p == '-') {
        p++;
        i = -(int) strtoul(p, &end, base);
    } else if (*p == '+') {
        p++;
        i = strtoul(p, &end, base);
    } else {
        i = strtoul(p, &end, base);
    }
    if (end == p) {
        return FALSE;
    }
    if (errno == ERANGE) {
        return FALSE;
    }
    while ((*end != '\0') && isspace(UCHAR(*end))) {
        end++;
    }
    if (*end != '\0') {
        return FALSE;
    }
    *intPtr = i;
    return TRUE;
}

/*-----------------------------------------------------------------------------
 * TclX_StrToUnsigned --
 *      Convert an Ascii string to an unsigned int of the specified base.
 *
 * Parameters:
 *   o string - String containing a number.
 *   o base - The base to use for the number 8, 10 or 16 or zero to decide
 *     based on the leading characters of the number.  Zero to let the number
 *     determine the base.
 *   o unsignedPtr - Place to return the converted number.  Will be 
 *     unchanged if there is an error.
 *
 * Returns:
 *      Returns 1 if the string was a valid number, 0 invalid.
 *-----------------------------------------------------------------------------
 */
int
TclX_StrToUnsigned (string, base, unsignedPtr)
    CONST char *string;
    int         base;
    unsigned   *unsignedPtr;
{
    char *end, *p;
    unsigned i;

    errno = 0;
    for (p = (char *) string; isspace(UCHAR(*p)); p++) {
        /* Empty loop body. */
    }
    i = strtoul(p, &end, base);
    if (end == p) {
        return FALSE;
    }
    if (errno == ERANGE) {
        return FALSE;
    }
    while ((*end != '\0') && isspace(UCHAR(*end))) {
        end++;
    }
    if (*end != '\0') {
        return FALSE;
    }
    *unsignedPtr = i;
    return TRUE;
}

/*-----------------------------------------------------------------------------
 * TclX_StrToOffset --
 *      Convert an Ascii string to an off_t number of the specified base.
 *
 * Parameters:
 *   o string - String containing a number.
 *   o base - The base to use for the number 8, 10 or 16 or zero to decide
 *     based on the leading characters of the number.  Zero to let the number
 *     determine the base.
 *   o offsetPtr - Place to return the converted number.  Will be 
 *     unchanged if there is an error.
 *
 * Returns:
 *      Returns 1 if the string was a valid number, 0 invalid.
 *-----------------------------------------------------------------------------
 */
int
TclX_StrToOffset (string, base, offsetPtr)
    CONST char *string;
    int         base;
    off_t      *offsetPtr;
{
    char *end, *p;
    off_t i;

    /*
     * Note: use strtoul instead of strtol for integer conversions
     * to allow full-size unsigned numbers, but don't depend on strtoul
     * to handle sign characters;  it won't in some implementations.
     */

    errno = 0;
    for (p = (char *) string; isspace(UCHAR(*p)); p++) {
        /* Empty loop body. */
    }
    if (*p == '-') {
        p++;
        i = -(off_t) strtoul(p, &end, base);
    } else if (*p == '+') {
        p++;
        i = strtoul(p, &end, base);
    } else {
        i = strtoul(p, &end, base);
    }
    if (end == p) {
        return FALSE;
    }
    if (errno == ERANGE) {
        return FALSE;
    }
    while ((*end != '\0') && isspace(UCHAR(*end))) {
        end++;
    }
    if (*end != '\0') {
        return FALSE;
    }
    *offsetPtr = i;
    return TRUE;
}

/*-----------------------------------------------------------------------------
 * TclX_DownShift --
 *     Utility procedure to down-shift a string.  It is written in such
 *     a way as that the target string maybe the same as the source string.
 *
 * Parameters:
 *   o targetStr - String to store the down-shifted string in.  Must
 *     have enough space allocated to store the string.  If NULL is specified,
 *     then the string will be dynamicly allocated and returned as the
 *     result of the function. May also be the same as the source string to
 *     shift in place.
 *   o sourceStr - The string to down-shift.
 *
 * Returns:
 *   A pointer to the down-shifted string
 * FIX: Make object based interface.
 *-----------------------------------------------------------------------------
 */
char *
TclX_DownShift (targetStr, sourceStr)
    char       *targetStr;
    CONST char *sourceStr;
{
    register char theChar;

    if (targetStr == NULL)
        targetStr = ckalloc (strlen ((char *) sourceStr) + 1);

    for (; (theChar = *sourceStr) != '\0'; sourceStr++) {
        if (isupper (theChar))
            theChar = _tolower (theChar);
        *targetStr++ = theChar;
    }
    *targetStr = '\0';
    return targetStr;
}

/*-----------------------------------------------------------------------------
 * TclX_UpShift --
 *     Utility procedure to up-shift a string.
 *
 * Parameters:
 *   o targetStr - String to store the up-shifted string in.  Must
 *     have enough space allocated to store the string.  If NULL is specified,
 *     then the string will be dynamicly allocated and returned as the
 *     result of the function. May also be the same as the source string to
 *     shift in place.
 *   o sourceStr - The string to up-shift.
 *
 * Returns:
 *   A pointer to the up-shifted string.
 * FIX: Get strcasecmp and replace this with it.
 * FIX: Make object based interface
 *-----------------------------------------------------------------------------
 */
char *
TclX_UpShift (targetStr, sourceStr)
    char       *targetStr;
    CONST char *sourceStr;
{
    register char theChar;

    if (targetStr == NULL)
        targetStr = ckalloc (strlen ((char *) sourceStr) + 1);

    for (; (theChar = *sourceStr) != '\0'; sourceStr++) {
        if (ISLOWER (theChar))
            theChar = _toupper (theChar);
        *targetStr++ = theChar;
    }
    *targetStr = '\0';
    return targetStr;
}

/*-----------------------------------------------------------------------------
 * TclX_GetOffsetFromObj --
 *   Get the value of an integer objects as an unsigned.
 *-----------------------------------------------------------------------------
 */
int
TclX_GetUnsignedFromObj (interp, objPtr, valuePtr)
    Tcl_Interp *interp;
    Tcl_Obj    *objPtr;
    unsigned   *valuePtr;
{
    int intValue;
    
    if (Tcl_GetIntFromObj (interp, objPtr, &intValue) != TCL_OK)
        return TCL_ERROR;
    if (intValue < 0) {
        TclX_AppendObjResult (interp, "expected unsigned integer, got \"",
                              Tcl_GetStringFromObj (objPtr, NULL),
                              "\"", (char *) NULL);
        return TCL_ERROR;
    }
    *valuePtr = intValue;
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_GetOffsetFromObj --
 *   Get the value of an integer objects as an off_t.
 *-----------------------------------------------------------------------------
 */
int
TclX_GetOffsetFromObj (interp, objPtr, offsetPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *objPtr;
    off_t      *offsetPtr;
{
    int intOff;
    
    if (Tcl_GetIntFromObj (interp, objPtr, &intOff) != TCL_OK)
        return TCL_ERROR;
    *offsetPtr = intOff;
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_RelativeExpr --
 *
 *    Evaluate an expression that may start with the magic words "end" or
 * "len".  These strings are replaced with either the end offset or the
 * length that is passed in.
 *
 * Parameters:
 *   o interp - A pointer to the interpreter.
 *   o exprPtr - Object with expression to evaluate.
 *   o stringLen - The length of the string or list.
 *   o exprResultPtr - The result of the expression is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
int
TclX_RelativeExpr (interp, exprPtr, stringLen, exprResultPtr)
    Tcl_Interp  *interp;
    Tcl_Obj     *exprPtr;
    int          stringLen;
    int         *exprResultPtr;
{
    char *exprStr, *buf;
    int exprLen, exprStrLen, result;
    long longResult;
    char staticBuf [32];

    if (exprPtr->typePtr == Tcl_GetObjType ("int")) {
        if (Tcl_GetIntFromObj (interp, exprPtr, exprResultPtr) != TCL_OK)
            return TCL_ERROR;
        return TCL_OK;
    }

    exprStr = Tcl_GetStringFromObj (exprPtr, &exprStrLen);

    if (!(STRNEQU (exprStr, "end", 3) ||
          STRNEQU (exprStr, "len", 3))) {
        if (Tcl_ExprLong (interp, exprStr, &longResult) != TCL_OK) {
            return TCL_ERROR;
        }
        *exprResultPtr = longResult;
        return TCL_OK;
    }

    sprintf (staticBuf, "%d",
             stringLen - ((exprStr [0] == 'e') ? 1 : 0));
    exprLen = strlen (staticBuf) + exprStrLen - 2;

    buf = staticBuf;
    if (exprLen > sizeof (staticBuf)) {
        buf = (char *) ckalloc (exprLen);
        strcpy (buf, staticBuf);
    }
    strcat (buf, exprStr + 3);

    result = Tcl_ExprLong (interp, buf, &longResult);

    if (buf != staticBuf)
        ckfree (buf);
    if (result == TCL_OK)
        *exprResultPtr = longResult;
    return result;
}

/*-----------------------------------------------------------------------------
 * TclX_GetOpenChannel --
 *
 *    Convert a file handle to a channel with error checking.
 *
 * Parameters:
 *   o interp - Current interpreter.
 *   o handle - The file handle to convert.
 *   o chanAccess - TCL_READABLE and/or TCL_WRITABLE, both or zero for no
 *     checking.
 * Returns:
 *   A the channel or NULL if an error occured.
 *-----------------------------------------------------------------------------
 */
Tcl_Channel
TclX_GetOpenChannel (interp, handle, chanAccess)
    Tcl_Interp *interp;
    char       *handle;
    int         chanAccess;
{
    Tcl_Channel chan;
    int mode;

    /*FIX: Delete when all converted to GetOpenChanelObj */
    chan = Tcl_GetChannel (interp, handle, &mode);
    if (chan == (Tcl_Channel) NULL) {
        return NULL;
    }
    if ((chanAccess & TCL_READABLE) && ((mode & TCL_READABLE) == 0)) {
        TclX_AppendObjResult(interp, "channel \"", handle,
                             "\" wasn't opened for reading", (char *) NULL);
        return NULL;
    }
    if ((chanAccess & TCL_WRITABLE) && ((mode & TCL_WRITABLE) == 0)) {
        TclX_AppendObjResult(interp, "channel \"", handle,
                             "\" wasn't opened for writing", (char *) NULL);
        return NULL;
    }

    return chan;
}

/*-----------------------------------------------------------------------------
 * TclX_GetOpenChannelObj --
 *
 *    Convert a file handle to a channel with error checking.
 *
 * Parameters:
 *   o interp    - Current interpreter.
 *   o handleObj - The file handle object to convert.
 *   o chanAccess - TCL_READABLE and/or TCL_WRITABLE, both or zero for no
 *     checking.
 * Returns:
 *   A the channel or NULL if an error occured.
 *-----------------------------------------------------------------------------
 */
Tcl_Channel
TclX_GetOpenChannelObj (interp, handleObj, chanAccess)
    Tcl_Interp *interp;
    Tcl_Obj    *handleObj;
    int         chanAccess;
{
    Tcl_Channel  chan;
    int          mode;
    char        *handle;

    handle = Tcl_GetStringFromObj (handleObj, NULL);
    chan = Tcl_GetChannel (interp, handle, &mode);
    if (chan == (Tcl_Channel) NULL) {
        return NULL;
    }
    if ((chanAccess & TCL_READABLE) && ((mode & TCL_READABLE) == 0)) {
        TclX_AppendObjResult (interp, "channel \"", handle,
                              "\" wasn't opened for reading", (char *) NULL);
        return NULL;
    }
    if ((chanAccess & TCL_WRITABLE) && ((mode & TCL_WRITABLE) == 0)) {
        TclX_AppendObjResult (interp, "channel \"", handle,
                              "\" wasn't opened for writing", (char *) NULL);
        return NULL;
    }

    return chan;
}

/*-----------------------------------------------------------------------------
 * ParseTranslationOption --
 *
 *   Parse the string that represents the translation value for one channel
 * direction.
 *
 * Parameters:
 *   o strValue - Channel translation value.
 * Returns:
 *   The integer option value.
 *----------------------------------------------------------------------------- */
static int
ParseTranslationOption (strValue)
    char *strValue;
{
    if (STREQU (strValue, "auto")) {
        return TCLX_TRANSLATE_AUTO;
    } else if (STREQU (strValue, "lf")) {
        return TCLX_TRANSLATE_LF;
    } else if (STREQU (strValue, "binary")) {
        return TCLX_TRANSLATE_BINARY;
    } else if (STREQU (strValue, "cr")) {
        return TCLX_TRANSLATE_CR;
    } else if (STREQU (strValue, "crlf")) {
        return TCLX_TRANSLATE_CRLF;
    } else if (STREQU (strValue, "platform")) {
        return TCLX_TRANSLATE_PLATFORM;
    }
    Tcl_Panic ("ParseTranslationOption bug");
    return TCL_ERROR;  /* Not reached */
}

/*-----------------------------------------------------------------------------
 * FormatTranslationOption --
 *
 *   Format the string that represents the translation value for one channel
 * direction.
 *
 * Parameters:
 *   o value - Integer channel translation value.
 * Returns:
 *   The string option value.
 *----------------------------------------------------------------------------
 */
static char *
FormatTranslationOption (value)
    int value;
{
    switch (value) {
      case TCLX_TRANSLATE_AUTO:
        return "auto";
      case TCLX_TRANSLATE_LF:  /* Also binary */
        return "lf";
      case TCLX_TRANSLATE_CR:
        return "cr";
      case TCLX_TRANSLATE_CRLF:
        return "crlf";
      case TCLX_TRANSLATE_PLATFORM:
        return "platform";
      default:
        Tcl_Panic ("FormatTranslationOption bug");
    }
    return NULL;  /* Not reached */
}


/*-----------------------------------------------------------------------------
 * TclX_GetChannelOption --
 *
 *   C-friendly front end to Tcl_GetChannelOption.
 *
 * Parameters:
 *   o interp - Error message are returned in result
 *   o channel - Channel to get the option for.
 *   o optionName - One of the TCLX_COPT_* defines.
 *   o valuePtr - Value is returned here.
 * Returns:
 *   TCL_OK or TCL_ERROR.
 * FIX: Maybe drop these.
 *-----------------------------------------------------------------------------
 */
int
TclX_GetChannelOption (interp, channel, option, valuePtr)
    Tcl_Interp *interp;
    Tcl_Channel channel;
    int         option;
    int        *valuePtr;
{
    char          *strOption;
    Tcl_DString    strValue;
    int            value = 0;

    Tcl_DStringInit (&strValue);

    switch (option) {
      case TCLX_COPT_BLOCKING:
        strOption = "-blocking";
        break;

      case TCLX_COPT_BUFFERING:
        strOption = "-buffering";
        break;

      case TCLX_COPT_TRANSLATION:
        strOption = "-translation";
        break;

      default:
        goto fatalError;
    }

    if (Tcl_GetChannelOption (interp, channel, strOption,
                              &strValue) != TCL_OK) {
        Tcl_DStringFree (&strValue);
        return TCL_ERROR;
    }

    switch (option) {
      case TCLX_COPT_BLOCKING:
        if (strValue.string [0] == '0') {
            value = TCLX_MODE_NONBLOCKING;
        } else {
            value = TCLX_MODE_BLOCKING;
        }
        break;

      case TCLX_COPT_BUFFERING:
        if (STREQU (strValue.string, "full")) {
            value = TCLX_BUFFERING_FULL;
        } else if (STREQU (strValue.string, "line")) {
            value = TCLX_BUFFERING_LINE;
        } else if (STREQU (strValue.string, "none")) {
            value = TCLX_BUFFERING_NONE;
        } else {
            goto fatalError;
        }
        break;

      case TCLX_COPT_TRANSLATION: {
        /*
         * The value returned is strange.  Its either a single word, or
         * a list with a word for each file in the channel.  However, in
         * Tcl 7.5, its actually retuned a list of a list, which is a bug.
         * Handle this and code for working with a fixed version.  Hack
         * the list rather than doing, since we know the possible values
         * and this is much faster and easy to support both formats.
         * FIX: ???Clean up once Tcl fixes the return.???
         */
        char *strValue1, *strValue2, *strScan;
          
        strValue1 = strValue.string;
        if (strValue1 [0] == '{')
            strValue1++;  /* Skip { if list of list */
        strValue2 = strchr (strValue1, ' ');
        if (strValue2 != NULL) {
            strValue2 [0] = '\0';  /* Split into two strings. */
            strValue2++;
            strScan = strchr (strValue2, '}');
            if (strScan != NULL)
                *strScan = '\0';
        } else {
            strValue2 = strValue1;
        }
        value =
          (ParseTranslationOption (strValue1) << TCLX_TRANSLATE_READ_SHIFT) |
            ParseTranslationOption (strValue2);
        break;
      }
    }
    Tcl_DStringFree (&strValue);
    *valuePtr = value;
    return TCL_OK;

  fatalError:
    Tcl_Panic ("TclX_GetChannelOption bug");  /* FIX: return error. */
    return 0;  /* Not reached */
}

/*-----------------------------------------------------------------------------
 * TclX_SetChannelOption --
 *
 *   C-friendly front end to Tcl_SetChannelOption.
 *
 * Parameters:
 *   o interp - Errors returned in result.
 *   o channel - Channel to set the option for.
 *   o option - One of the TCLX_COPT_* defines.
 *   o value - Value to set the option to (integer define).  Note, if
 *     this is translation, it can either be the read and write directions
 *     masked together or a single value.
 * Result:
 *   TCL_OK or TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
int
TclX_SetChannelOption (interp, channel, option, value)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int          option;
    int          value;
{
    char *strOption, *strValue;
    int readValue, writeValue;
    char valueList [64];

    switch (option) {
      case TCLX_COPT_BLOCKING:
        strOption = "-blocking";
        switch (value) {
          case TCLX_MODE_BLOCKING:
            strValue = "1";
            break;
          case TCLX_MODE_NONBLOCKING:
            strValue = "0";
            break;
          default:
            goto fatalError;
        }
        break;

      case TCLX_COPT_BUFFERING:
        strOption = "-buffering";
        switch (value) {
          case TCLX_BUFFERING_FULL:
            strValue = "full";
            break;
          case TCLX_BUFFERING_LINE:
            strValue = "line";
            break;
          case TCLX_BUFFERING_NONE:
            strValue = "none";
            break;
          default:
            goto fatalError;
        }
        break;

      case TCLX_COPT_TRANSLATION:
        /*
         * Hack a list together rather than allocate memory.  If values for
         * read or write were not specified, specify both the same.
         */
        readValue = (value & TCLX_TRANSLATE_READ_MASK) >>
            TCLX_TRANSLATE_READ_SHIFT;
        writeValue = (value & TCLX_TRANSLATE_WRITE_MASK);
        if (readValue == TCLX_TRANSLATE_UNSPECIFIED)
            readValue = writeValue;
        if (writeValue == TCLX_TRANSLATE_UNSPECIFIED)
            writeValue = readValue;

        strOption = "-translation";

        valueList [0] = '\0';
        valueList [sizeof (valueList) - 1] = '\0';  /* Overflow check */
        strValue = valueList;

        strcat (valueList, FormatTranslationOption (readValue));
        strcat (valueList, " ");
        strcat (valueList, FormatTranslationOption (writeValue));
        if (valueList [sizeof (valueList) - 1] != '\0')
            goto fatalError;
        break;

      default:
        goto fatalError;
    }

    return Tcl_SetChannelOption (interp, channel, strOption, strValue);

  fatalError:
    Tcl_Panic ("TclX_SetChannelOption bug");
    return TCL_ERROR;  /* Not reached */
}

/*-----------------------------------------------------------------------------
 * TclX_JoinPath --
 *
 *   Interface to Tcl_Join path to join only two files.
 *
 * Parameters:
 *   o path1, path2 - File paths to join.
 *   o joinedPath - DString buffere that joined path is returned in.
 *     must be initialized.
 * Returns:
 *   A pointer to joinedPath->string.
 *-----------------------------------------------------------------------------
 */
char *
TclX_JoinPath (path1, path2, joinedPath)
    char        *path1;
    char        *path2;
    Tcl_DString *joinedPath;
{
    CONST84 char *joinArgv [2];

    joinArgv [0] = path1;
    joinArgv [1] = path2;
    Tcl_JoinPath (2, joinArgv, joinedPath);

    return joinedPath->string;
}


/*-----------------------------------------------------------------------------
 * TclX_WrongArgs --
 *
 *   Easily create "wrong # args" error messages.
 *
 * Parameters:
 *   o commandNameObj - Object containing name of command (objv[0])
 *   o string - Text message to append.
 * Returns:
 *   TCL_ERROR
 *-----------------------------------------------------------------------------
 */
int
TclX_WrongArgs (interp, commandNameObj, string)
    Tcl_Interp  *interp;
    Tcl_Obj     *commandNameObj;
    char        *string;
{
    char    *commandName;
    Tcl_Obj *resultPtr = Tcl_GetObjResult (interp);
    int      commandLength;

    commandName = Tcl_GetStringFromObj (commandNameObj, &commandLength);

    Tcl_AppendStringsToObj (resultPtr,
			    tclXWrongArgs,
			    commandName,
			    (char *)NULL);

    if (*string != '\0') {
	Tcl_AppendStringsToObj (resultPtr, " ", string, (char *)NULL);
    }
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_AppendObjResult --
 *
 *   Append a variable number of strings onto the object result already
 * present for an interpreter.  If the object is shared, the current contents
 * are discarded.
 *
 * Parameters:
 *   o interp - Interpreter to set the result in.
 *   o args - Strings to append, terminated by a NULL.
 *-----------------------------------------------------------------------------
 */
void
TclX_AppendObjResult TCL_VARARGS_DEF (Tcl_Interp *, arg1)
{
    Tcl_Interp *interp;
    Tcl_Obj *resultPtr;
    va_list argList;
    char *string;

    interp = TCL_VARARGS_START (Tcl_Interp *, arg1, argList);
    resultPtr = Tcl_GetObjResult (interp);

    if (Tcl_IsShared(resultPtr)) {
        resultPtr = Tcl_NewStringObj((char *)NULL, 0);
        Tcl_SetObjResult(interp, resultPtr);
    }

    TCL_VARARGS_START(Tcl_Interp *,arg1,argList);
    while (1) {
        string = va_arg(argList, char *);
        if (string == NULL) {
            break;
        }
        Tcl_AppendToObj (resultPtr, string, -1);
    }
    va_end(argList);
}


/*-----------------------------------------------------------------------------
 * TclX_IsNullObj --
 *
 *   Check if an object is {}, either in list or zero-lemngth string form, with
 * out forcing a conversion.
 *
 * Parameters:
 *   o objPtr - Object to check.
 * Returns:
 *   True if NULL, FALSE if not.
 *-----------------------------------------------------------------------------
 */
int
TclX_IsNullObj (objPtr)
    Tcl_Obj *objPtr;
{
    static Tcl_ObjType *listType = NULL, *stringType = NULL;
    int length;
    
    /*
     * Only get types once, as they must be static.
     */
    if (listType == NULL) {
        listType = Tcl_GetObjType ("list");
        stringType = Tcl_GetObjType ("string");
    }

    if (objPtr->typePtr == NULL) {
        return (objPtr->length == 0);
    } else {
        if (objPtr->typePtr == listType) {
            Tcl_ListObjLength (NULL, objPtr, &length);
            return (length == 0);
        } else if (objPtr->typePtr == stringType) {
            Tcl_GetStringFromObj (objPtr, &length);
            return (length == 0);
        }
    }
    Tcl_GetStringFromObj (objPtr, &length);
    return (length == 0);
}


/*-----------------------------------------------------------------------------
 * TclX_SaveResultErrorInfo --
 *
 *   Saves the Tcl interp result plus errorInfo and errorCode in a structure.
 *
 * Parameters:
 *   o interp - Interpreter to save state for.
 * Returns:
 *   A list object containing the state.
 *-----------------------------------------------------------------------------
 */
Tcl_Obj *
TclX_SaveResultErrorInfo (interp)
    Tcl_Interp  *interp;
{
    Tcl_Obj *saveObjv [4];
    Tcl_Obj *listObj;

    long flags = ((Interp *)interp)->flags &
	(ERR_ALREADY_LOGGED | ERR_IN_PROGRESS | ERROR_CODE_SET);

    saveObjv [0] = Tcl_DuplicateObj (Tcl_GetObjResult (interp));
    
    saveObjv [1] = Tcl_GetVar2Ex(interp, ERRORINFO, NULL, TCL_GLOBAL_ONLY);
    if (saveObjv [1] == NULL) {
        saveObjv [1] = Tcl_NewObj ();
    }

    saveObjv [2] = Tcl_GetVar2Ex(interp, ERRORCODE, NULL, TCL_GLOBAL_ONLY);
    if (saveObjv [2] == NULL) {
        saveObjv [2] = Tcl_NewObj ();
    }

    saveObjv [3] = Tcl_NewLongObj(flags);

    Tcl_IncrRefCount(listObj = Tcl_NewListObj (4, saveObjv));

    return listObj;
}


/*-----------------------------------------------------------------------------
 * TclX_RestoreResultErrorInfo --
 *
 *   Restores the Tcl interp state from TclX_SaveResultErrorInfo.
 *
 * Parameters:
 *   o interp - Interpreter to save state for.
 *   o saveObjPtr - Object returned from TclX_SaveResultErrorInfo.  Ref count
 *     will be decremented.
 *-----------------------------------------------------------------------------
 */
void
TclX_RestoreResultErrorInfo (interp, saveObjPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *saveObjPtr;
{
    Tcl_Obj **saveObjv;
    int saveObjc;
    long flags;

    if ((Tcl_ListObjGetElements (NULL, saveObjPtr, &saveObjc,
                                 &saveObjv) != TCL_OK) ||
        (saveObjc != 4) ||
        (Tcl_GetLongFromObj (NULL, saveObjv[3], &flags) != TCL_OK)) {
	/*
	 * This should never happen
	 */
        Tcl_Panic ("invalid TclX result save object");
    }

    Tcl_SetVar2Ex(interp, ERRORCODE, NULL, saveObjv[2], TCL_GLOBAL_ONLY);
    Tcl_SetVar2Ex(interp, ERRORINFO, NULL, saveObjv[1], TCL_GLOBAL_ONLY);

    Tcl_SetObjResult (interp, saveObjv[0]);

    ((Interp *)interp)->flags |= flags;

    Tcl_DecrRefCount (saveObjPtr);
}

/*--------------------------------------------------------------------------
 * TclX_CreateObjCommand --
 *
 * Handles the creation of TclX commands. Used for commands who come
 * in conflict with other extensions.
 *
 * Parameters:
 *   o Like Tcl_CreateObjCommand
 *   o flags - Additional flags to control the behaviour of the procedure.
 *--------------------------------------------------------------------------
 */

int
TclX_CreateObjCommand (interp, cmdName, proc, clientData, deleteProc, flags)
    Tcl_Interp*        interp;
    char*              cmdName;
    Tcl_ObjCmdProc*    proc;
    ClientData         clientData;
    Tcl_CmdDeleteProc* deleteProc;
    int                flags;
{
    Namespace *globalNsPtr = (Namespace *) Tcl_GetGlobalNamespace(interp);
    Namespace *currNsPtr   = (Namespace *) Tcl_GetCurrentNamespace(interp);
    Tcl_HashTable *gTblPtr, *cTblPtr;
    static size_t offset = TclX_Offset(Namespace, cmdTable);

    gTblPtr = (Tcl_HashTable *) TclX_StructOffset(globalNsPtr, offset, 0);
    cTblPtr = (Tcl_HashTable *) TclX_StructOffset(currNsPtr, offset, 0);
    if ((flags & TCLX_CMD_REDEFINE) ||
	    !(Tcl_FindHashEntry(gTblPtr, cmdName) ||
		    Tcl_FindHashEntry(cTblPtr, cmdName))) {
	Tcl_CreateObjCommand(interp, cmdName, proc, clientData, deleteProc);
    }
    if (!(cmdName[0] == 't' && cmdName[1] == 'c' && cmdName[2] == 'l' &&
	    cmdName[3] == 'x') && !(flags & TCLX_CMD_NOPREFIX)) {
	char cmdnamebuf[80];
	sprintf(cmdnamebuf, "tclx_%s", cmdName);
	Tcl_CreateObjCommand(interp, cmdnamebuf, proc, clientData, deleteProc);
    }

    return TCL_OK;
}

/*--------------------------------------------------------------------------
 * TclX_NSOffset --
 *
 * Handles offsets into a private structure, which has changed in size from
 * 8.3 to 8.4.  Currently only for Namespace, but others could be added.
 *--------------------------------------------------------------------------
 */

void *
TclX_StructOffset(nsPtr, offset, offType)
    void *nsPtr;
    size_t offset;
    unsigned int offType;
{
    int major, minor, i;
    /*
     * These size_t pairs indicate the element at which we will have a
     * shift in size and the size by which it will shift.
     */
    static size_t nsOffs[] = {
	TclX_Offset(Namespace, varTable), sizeof(void *),
	TclX_Offset(Namespace, cmdTable), sizeof(void *),
	TclX_Offset(Namespace, childTable), sizeof(void *),
	0, 0
    };

    /*
     * Get the version so we can runtime switch on available functionality.
     * 8.0 is the lowest we compile with, so use that assumption.
     */
    Tcl_GetVersion(&major, &minor, NULL, NULL);

#if TCL_MAJOR_VERSION == 8 && TCL_MINOR_VERSION < 4
    /*
     * Headers are <= 8.3 for offset calculations, so we only need to
     * adjust for 8.4+ interpreters.
     */
    if ((major > 8) || (minor > 3)) {
	for (i = 0; nsOffs[i] != 0; i += 2) {
	    if (offset > nsOffs[i]) {
		offset += nsOffs[i+1];
	    }
	}
    }
#else
    /*
     * Headers are >= 8.4 for offset calculations, so we only need to
     * adjust for 8.3- interpreters.
     */
    if ((major == 8) && (minor < 4)) {
	for (i = 0; nsOffs[i] != 0; i += 2) {
	    if (offset > nsOffs[i]) {
		offset -= nsOffs[i+1];
	    }
	}
    }
#endif
    return (void *)((size_t) nsPtr + offset);
}
