/* 
 * tclXlist.c --
 *
 *  Extended Tcl list commands.
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
 * $Id: tclXlist.c,v 1.2 2005/11/17 23:56:21 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/* FIX: Need way to get lvarpush to append to end, or even fill in empty
   entries
*/

static int
TclX_LvarcatObjCmd _ANSI_ARGS_((ClientData   clientData,
                                Tcl_Interp  *interp,
                                int          objc,
                                Tcl_Obj     *CONST objv[]));

static int
TclX_LvarpopObjCmd _ANSI_ARGS_((ClientData   clientData,
                                Tcl_Interp  *interp,
                                int          objc,
                                Tcl_Obj    *CONST objv[]));

static int
TclX_LvarpushObjCmd _ANSI_ARGS_((ClientData   clientData,
                                 Tcl_Interp  *interp,
                                 int          objc,
                                 Tcl_Obj    *CONST objv[]));

static int
TclX_LemptyObjCmd _ANSI_ARGS_((ClientData   clientData,
                               Tcl_Interp  *interp,
                               int          objc,
                               Tcl_Obj    *CONST objv[]));

static int
TclX_LassignObjCmd _ANSI_ARGS_((ClientData   clientData,
                                Tcl_Interp  *interp,
                                int          objc,
                                Tcl_Obj    *CONST objv[]));

static int
TclX_LmatchObjCmd _ANSI_ARGS_((ClientData   clientData,
                               Tcl_Interp  *interp,
                               int          objc,
                               Tcl_Obj    *CONST objv[]));

static int
TclX_LcontainObjCmd _ANSI_ARGS_((ClientData   clientData,
                                 Tcl_Interp  *interp,
                                 int          objc,
                                 Tcl_Obj    *CONST objv[]));


/*-----------------------------------------------------------------------------
 * TclX_LvarcatObjCmd --
 *   Implements the TclX lvarcat command:
 *      lvarcat var string ?string...?
 *-----------------------------------------------------------------------------
 */
static int
TclX_LvarcatObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *varObjPtr, *newObjPtr;
    int catObjc, idx, argIdx;
    Tcl_Obj **catObjv, *staticObjv [32];
    char *varName;

    if (objc < 3) {
        return TclX_WrongArgs (interp, objv [0], "var string ?string...?");
    }
    varName = Tcl_GetStringFromObj (objv [1], NULL);
    catObjv = staticObjv;

    /*
     * Get the variable that we are going to update.  Include it if it
     * exists.
     */
    varObjPtr = Tcl_GetVar2Ex(interp, varName, NULL, TCL_PARSE_PART1);

    if (varObjPtr != NULL) {
        catObjc = objc - 1;
    } else {
        catObjc = objc - 2;
    }

    if (catObjc >= (sizeof (staticObjv) / sizeof (char *))) {
        catObjv = (Tcl_Obj **) ckalloc (catObjc * sizeof (Tcl_Obj *));
    }
    
    if (varObjPtr != NULL) {
        catObjv [0] = varObjPtr;
        argIdx = 1;
    } else {
        argIdx = 0;
    }
    for (idx = 2; idx < objc; idx++, argIdx++) {
        catObjv [argIdx] = objv [idx];
    }

    newObjPtr = Tcl_ConcatObj (catObjc, catObjv);

    if (catObjv != staticObjv)
        ckfree ((char *) catObjv);

    if (Tcl_SetVar2Ex(interp, varName, NULL, newObjPtr,
                      TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL) {
        Tcl_DecrRefCount (newObjPtr);
        return TCL_ERROR;
    }
    Tcl_SetObjResult (interp, newObjPtr);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_LvarpopObjCmd --
 *   Implements the TclX lvarpop command:
 *      lvarpop var ?indexExpr? ?string?
 *-----------------------------------------------------------------------------
 */
static int
TclX_LvarpopObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *listVarPtr, *newVarObj, *returnElemPtr = NULL;
    int listIdx, listLen;
    char *varName;

    if ((objc < 2) || (objc > 4)) {
        return TclX_WrongArgs (interp, objv [0], "var ?indexExpr? ?string?");
    }
    varName = Tcl_GetStringFromObj (objv [1], NULL);

    listVarPtr = Tcl_GetVar2Ex(interp, varName, NULL, 
                               TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG);
    if (listVarPtr == NULL) {
        return TCL_ERROR;
    }
    if (Tcl_IsShared (listVarPtr)) {
        listVarPtr = newVarObj = Tcl_DuplicateObj (listVarPtr);
    } else {
        newVarObj = NULL;
    }

    /*
     * Get the index of the entry in the list we are doing to replace/delete.
     * Just ignore out-of bounds requests, like standard Tcl.
     */
    if (Tcl_ListObjLength (interp, listVarPtr, &listLen) != TCL_OK)
        goto errorExit;

    if (objc == 2) {
        listIdx = 0;
    } else if (TclX_RelativeExpr (interp, objv [2],
                                  listLen, &listIdx) != TCL_OK) {
        goto errorExit;
    }
    if ((listIdx < 0) || (listIdx >= listLen)) {
        goto okExit;
    }

    /*
     * Get the element that is doing to be deleted/replaced.
     */
    if (Tcl_ListObjIndex (interp, listVarPtr, listIdx, &returnElemPtr) != TCL_OK)
        goto errorExit;
    Tcl_IncrRefCount (returnElemPtr);

    /*
     * Either replace or delete the element.
     */
    if (objc == 4) {
        if (Tcl_ListObjReplace (interp, listVarPtr, listIdx, 1,
                                1, &(objv [3])) != TCL_OK)
            goto errorExit;
    } else {
        if (Tcl_ListObjReplace (interp, listVarPtr, listIdx, 1,
                                0, NULL) != TCL_OK)
            goto errorExit;
    }

    /*
     * Update variable.
     */
    if (Tcl_SetVar2Ex(interp, varName, NULL, listVarPtr,
                      TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL) {
        goto errorExit;
    }

    Tcl_SetObjResult (interp, returnElemPtr);

  okExit:
    if (returnElemPtr != NULL)
        Tcl_DecrRefCount (returnElemPtr);
    return TCL_OK;

  errorExit:
    if (newVarObj != NULL) {
        Tcl_DecrRefCount (newVarObj);
        return TCL_ERROR;
    }
    if (returnElemPtr != NULL) {
        Tcl_DecrRefCount (returnElemPtr);
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_LvarpushObjCmd --
 *   Implements the TclX lvarpush command:
 *      lvarpush var string ?indexExpr?
 *-----------------------------------------------------------------------------
 */
static int
TclX_LvarpushObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Obj *listVarPtr, *newVarObj;
    int listIdx, listLen;
    char *varName;

    if ((objc < 3) || (objc > 4)) {
        return TclX_WrongArgs (interp, objv [0], "var string ?indexExpr?");
    }
    varName = Tcl_GetStringFromObj (objv [1], NULL);

    listVarPtr = Tcl_GetVar2Ex(interp, varName, NULL, TCL_PARSE_PART1);
    if ((listVarPtr == NULL) || (Tcl_IsShared (listVarPtr))) {
        if (listVarPtr == NULL) {
            listVarPtr = Tcl_NewListObj (0, NULL);
        } else {
            listVarPtr = Tcl_DuplicateObj (listVarPtr);
        }
        newVarObj = listVarPtr;
    } else {
        newVarObj = NULL;
    }

    /*
     * Get the index of the entry in the list we are doing to replace/delete.
     * Out-of-bounds request go to the start or end, as with most of Tcl
     * commands.
     */
    if (Tcl_ListObjLength (interp, listVarPtr, &listLen) != TCL_OK)
        goto errorExit;

    if (objc == 3) {
        listIdx = 0;
    } else if (TclX_RelativeExpr (interp, objv [3],
                                  listLen, &listIdx) != TCL_OK) {
        goto errorExit;
    }
    if (listIdx < 0) {
        listIdx = 0;
    } else {
        if (listIdx > listLen)
            listIdx = listLen;
    }

    if (Tcl_ListObjReplace (interp, listVarPtr, listIdx, 0,
                            1, &(objv [2])) != TCL_OK)
        goto errorExit;

    if (Tcl_SetVar2Ex(interp, varName, NULL, listVarPtr,
                      TCL_PARSE_PART1| TCL_LEAVE_ERR_MSG) == NULL) {
        goto errorExit;
    }
    return TCL_OK;

  errorExit:
    if (newVarObj != NULL) {
        Tcl_DecrRefCount (newVarObj);
    }
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_LemptyObjCmd --
 *    Implements the TclX lempty command:
 *        lempty list
 *-----------------------------------------------------------------------------
 */
static int
TclX_LemptyObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int length;

    if (objc != 2) {
        return TclX_WrongArgs (interp, objv [0], "list");
    }

    /*
     * A null object.
     */
    if ((objv[1]->typePtr == NULL) && (objv[1]->bytes == NULL)) {
        Tcl_SetBooleanObj(Tcl_GetObjResult(interp), TRUE);
        return TCL_OK;
    }

    /*
     * This is a little tricky, because the pre-object lempty never checked
     * for a valid list, it just checked for a string of all white spaces.
     * Pass a NULL interp and ignore errors - any thrown are for invalid list
     * formats, which we accept to be !empty.
     */
    length = 1;
    Tcl_ListObjLength(NULL, objv[1], &length);

    Tcl_SetBooleanObj (Tcl_GetObjResult (interp), (0 == length));
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_LassignObjCmd --
 *    Implements the TclX assign_fields command:
 *       lassign list varname ?varname...?
 *-----------------------------------------------------------------------------
 */
static int
TclX_LassignObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int listObjc, listIdx, idx, remaining;
    Tcl_Obj **listObjv, *elemPtr, *remainingObjPtr;
    Tcl_Obj *nullObjPtr = NULL;

    if (objc < 3) {
        return TclX_WrongArgs (interp, objv [0],
                               "list varname ?varname..?");
    }
    if (Tcl_ListObjGetElements (interp, objv [1],
                                &listObjc, &listObjv) != TCL_OK)
        return TCL_ERROR;

    /*
     * Assign elements to specified variables.  If there are not enough
     * elements, set the variables to a NULL object.
     */
    for (idx = 2, listIdx = 0; idx < objc; idx++, listIdx++) {
        if (listIdx < listObjc) {
            elemPtr = listObjv [listIdx];
        } else {
            if (nullObjPtr == NULL) {
                nullObjPtr = Tcl_NewObj ();
                Tcl_IncrRefCount (nullObjPtr);
            }
            elemPtr = nullObjPtr;
        }
        if (Tcl_SetVar2Ex(interp, Tcl_GetStringFromObj(objv [idx], NULL), NULL,
                          elemPtr, TCL_PARSE_PART1 | TCL_LEAVE_ERR_MSG) == NULL)
            goto error_exit;
    }

    /*
     * Return remaining elements as a list.
     */
    remaining = listObjc - objc + 2;
    if (remaining > 0) {
        remainingObjPtr = Tcl_NewListObj (remaining, &(listObjv [objc - 2]));
        Tcl_SetObjResult (interp, remainingObjPtr);
    }

    if (nullObjPtr != NULL)
        Tcl_DecrRefCount (nullObjPtr);
    return TCL_OK;

  error_exit:
    if (nullObjPtr != NULL)
        Tcl_DecrRefCount (nullObjPtr);
    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_LmatchObjCmd --
 *   Implements the TclX lmatch command:
 *       lmatch ?-exact|-glob|-regexp? list pattern
 *-----------------------------------------------------------------------------
 */
static int
TclX_LmatchObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
#define EXACT   0
#define GLOB    1
#define REGEXP  2
    int listObjc, idx, match, mode, patternLen, valueLen;
    char *modeStr, *patternStr, *valueStr;
    Tcl_Obj **listObjv, *matchedListPtr = NULL;

    mode = GLOB;
    if (objc == 4) {
        modeStr = Tcl_GetStringFromObj (objv [1], NULL);
        if (STREQU (modeStr, "-exact")) {
            mode = EXACT;
        } else if (STREQU (modeStr, "-glob")) {
            mode = GLOB;
        } else if (STREQU (modeStr, "-regexp")) {
            mode = REGEXP;
        } else {
            TclX_AppendObjResult (interp, "bad search mode \"", modeStr,
                                  "\": must be -exact, -glob, or -regexp",
                                  (char *) NULL);
            return TCL_ERROR;
        }
    } else if (objc != 3) {
        return TclX_WrongArgs (interp, objv [0], "?mode? list pattern");
    }

    if (Tcl_ListObjGetElements (interp, objv [objc - 2],
                                &listObjc, &listObjv) != TCL_OK)
        return TCL_ERROR;

    patternStr = Tcl_GetStringFromObj (objv [objc - 1], &patternLen);
    if ((mode != EXACT) && (strlen (patternStr) != (size_t) patternLen)) {
        goto binData;
    }

    for (idx = 0; idx < listObjc; idx++) {
        match = 0;
        valueStr = Tcl_GetStringFromObj (listObjv [idx], &valueLen);
        switch (mode) {
          case EXACT:
            match = (valueLen == patternLen) &&
                (memcmp (valueStr, patternStr, valueLen) == 0);
            break;

          case GLOB:
            if (strlen (valueStr) != (size_t) valueLen) {
                goto binData;
            }
            match = Tcl_StringMatch (valueStr, patternStr);
            break;

          case REGEXP:
            if (strlen (valueStr) != (size_t) valueLen) {
                goto binData;
            }
            match = Tcl_RegExpMatch (interp, valueStr, patternStr);
            if (match < 0) {
                goto errorExit;
            }
            break;
        }
        if (match) {
            if (matchedListPtr == NULL)
                matchedListPtr = Tcl_NewListObj (0, NULL);
            if (Tcl_ListObjAppendElement (interp, matchedListPtr,
                                          listObjv [idx]) != TCL_OK)
                goto errorExit;
        }
    }
    if (matchedListPtr != NULL) {
        Tcl_SetObjResult (interp, matchedListPtr);
    }
    return TCL_OK;
    
  errorExit:
    if (matchedListPtr != NULL)
        Tcl_DecrRefCount (matchedListPtr);
    return TCL_ERROR;

  binData:
    TclX_AppendObjResult (interp, "The ", mode, " option does not support ",
                          "binary data", (char *) NULL);
    return TCL_ERROR;
}

/*----------------------------------------------------------------------
 * TclX_LcontainObjCmd --
 *   Implements the TclX lcontain command:
 *       lcontain list element
 *----------------------------------------------------------------------
 */
static int
TclX_LcontainObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    int listObjc, idx;
    Tcl_Obj **listObjv;
    char *elementStr, *checkStr;
    int elementLen, checkLen;

    if (objc != 3) {
        return TclX_WrongArgs (interp, objv [0], "list element");
    }

    if (Tcl_ListObjGetElements (interp, objv [1],
                                &listObjc, &listObjv) != TCL_OK)
        return TCL_ERROR;

    checkStr = Tcl_GetStringFromObj (objv [2], &checkLen);
    
    for (idx = 0; idx < listObjc; idx++) {
        elementStr = Tcl_GetStringFromObj (listObjv [idx], &elementLen);
        if ((elementLen == checkLen) &&
            (memcmp (elementStr, checkStr, elementLen) == 0))
            break;
    }
    Tcl_SetBooleanObj (Tcl_GetObjResult (interp), (idx < listObjc));
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_ListInit --
 *   Initialize the list commands in an interpreter.
 *
 * Parameters:
 *   o interp - Interpreter to add commands to.
 *-----------------------------------------------------------------------------
 */
void
TclX_ListInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand(interp, 
			 "lvarcat", 
			 TclX_LvarcatObjCmd, 
                         (ClientData) NULL, 
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
			 "lvarpop", 
			 TclX_LvarpopObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
			 "lvarpush",
			 TclX_LvarpushObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp,
                         "lempty",
			 TclX_LemptyObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
			 "lassign",
			 TclX_LassignObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp,
			 "lmatch",
			 TclX_LmatchObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand(interp, 
			 "lcontain",
			 TclX_LcontainObjCmd, 
                         (ClientData) NULL,
			 (Tcl_CmdDeleteProc*) NULL);
}


