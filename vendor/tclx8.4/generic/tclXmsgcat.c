/* 
 * tclXmsgcat.c --
 *
 *      Contains commands for accessing XPG/3 message catalogs.  If real XPG/3
 * message catalogs are not available, the default string is returned.
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
 * $Id: tclXmsgcat.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

#ifndef NO_CATGETS

#include <nl_types.h>

#else

typedef int nl_catd;

#endif /* NO_CATGETS */

static int
ParseFailOptionObj _ANSI_ARGS_((Tcl_Interp *interp,
                                Tcl_Obj    *optionObj,
                                int        *failPtr));

static int
CatOpFailedObj _ANSI_ARGS_((Tcl_Interp *interp,
                            CONST char *errorMsg));

static int
TclX_CatopenObjCmd _ANSI_ARGS_((ClientData  clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj   *CONST objv[]));

static int
TclX_CatgetsObjCmd _ANSI_ARGS_((ClientData  clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj   *CONST objv[]));

static int
TclX_CatcloseObjCmd _ANSI_ARGS_((ClientData  clientData,
                                Tcl_Interp *interp,
                                int         objc,
                                Tcl_Obj   *CONST objv[]));

static void
MsgCatCleanUp _ANSI_ARGS_((ClientData  clientData,
                           Tcl_Interp *interp));


/*
 * Message catalog table is global, so it is shared between all interpreters
 * in the same process.
 */
static void_pt msgCatTblPtr = NULL;

#ifdef NO_CATGETS

/*-----------------------------------------------------------------------------
 * catopen --
 *
 *   A stub to use when message catalogs are not available.   Always returns
 * -1.
 *-----------------------------------------------------------------------------
 */
static nl_catd
catopen (name, oflag)
    char *name;
    int   oflag;
{
    return (nl_catd) -1;
}

/*-----------------------------------------------------------------------------
 * catgets --
 *
 *   A stub to use when message catalogs are not available.  Always returns
 * the default string.
 *-----------------------------------------------------------------------------
 */
static char *
catgets (catd, set_num, msg_num, defaultStr)
    nl_catd catd;
    int     set_num, msg_num;
    char   *defaultStr;
{
    return defaultStr;
}

/*-----------------------------------------------------------------------------
 * catclose --
 *
 *   A stub to use when message catalogs are not available. Always returns -1.
 *-----------------------------------------------------------------------------
 */
static int
catclose (catd)
    nl_catd catd;
{
    return -1;
}
#endif /* NO_CATGETS */

/*-----------------------------------------------------------------------------
 * ParseFailOptionObj --
 *
 *   Parse the -fail/-nofail option, if specified.
 *-----------------------------------------------------------------------------
 */
static int
ParseFailOptionObj (interp, optionObj, failPtr)
    Tcl_Interp *interp;
    Tcl_Obj    *optionObj;
    int        *failPtr;
{
    char *optionStr;

    optionStr = Tcl_GetStringFromObj (optionObj, NULL);
    if (STREQU ("-fail", optionStr))
        *failPtr = TRUE;
    else if (STREQU ("-nofail", optionStr))
        *failPtr = FALSE;
    else {
        TclX_AppendObjResult (interp, "Expected option of `-fail' or ",
                              "`-nofail', got: `", optionStr, "'",
                              (char *) NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * CatOpFailedObj --
 *
 *    Handles failures of catopen and catclose.  If message catalogs are
 * available, if returns the supplied message.  If message are not
 * available, it returns a message indicating that message stubs are used.
 * It is not specified by XPG/3 how to get the details of a message catalog
 * open or close failure. Always returns TCL_ERROR;
 *-----------------------------------------------------------------------------
 */
static int
CatOpFailedObj (interp, errorMsg)
    Tcl_Interp *interp;
    CONST char *errorMsg;
{
#ifndef NO_CATGETS
    TclX_AppendObjResult (interp, errorMsg, (char *) NULL);

#else
    TclX_AppendObjResult (interp, "the message catalog facility is not",
                          " available, default string is always returned",
                          (char *) NULL);
#endif /* NO_CATGETS */

    return TCL_ERROR;
}

/*-----------------------------------------------------------------------------
 * TclX_CatopenObjCmd --
 *
 *    Implements the TCLX catopen command:
 *        catopen ?-fail|-nofail? catname
 *-----------------------------------------------------------------------------
 */
static int
TclX_CatopenObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    int      fail;
    nl_catd  catDesc;
    nl_catd *catDescPtr;
    char    handleName[16];
    char    *catFileName;

    if ((objc < 2) || (objc > 3))
        return TclX_WrongArgs (interp, objv [0], "?-fail|-nofail? catname");

    if (objc == 3) {
        if (ParseFailOptionObj (interp, objv [1], &fail) == TCL_ERROR)
            return TCL_ERROR;
    } else
        fail = FALSE;

    catFileName = Tcl_GetStringFromObj (objv [objc - 1], NULL);
    catDesc = catopen (catFileName, 0);
    if ((catDesc == (nl_catd) -1) && fail)
        return CatOpFailedObj (interp, "open of message catalog failed");

    catDescPtr = (nl_catd *) TclX_HandleAlloc (msgCatTblPtr, handleName);
    *catDescPtr = catDesc;

    Tcl_SetObjResult (interp, Tcl_NewStringObj (handleName, -1));
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * TclX_CatgetsObjCmd --
 *
 *    Implements the TCLX catgets command:
 *        catgets catHandle setnum msgnum defaultstr
 *-----------------------------------------------------------------------------
 */
static int
TclX_CatgetsObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    nl_catd   *catDescPtr;
    int       msgSetNum, msgNum;
    char      *localMsg;
    char      *defaultStr;

    if (objc != 5)
	return TclX_WrongArgs (interp, 
			       objv [0],
                               "catHandle setnum msgnum defaultstr");

    catDescPtr = (nl_catd *) TclX_HandleXlateObj (interp, 
						 msgCatTblPtr,
						 objv [1]);
    if (catDescPtr == NULL)
        return TCL_ERROR;

    if (Tcl_GetIntFromObj (interp, objv [2], &msgSetNum) == TCL_ERROR)
        return TCL_ERROR;

    if (Tcl_GetIntFromObj (interp, objv [3], &msgNum) == TCL_ERROR)
        return TCL_ERROR;

    /*
     * if the integer value of the handle is -1, the catopen actually
     * failed (softly, i.e. the caller did not specify "-fail")
     * so we detect that and merely return the default string.
     */

    if (*catDescPtr == (nl_catd)-1) {
        Tcl_SetObjResult (interp, objv [4]);
	Tcl_IncrRefCount (objv [4]);
	return TCL_OK;
    }

    defaultStr = Tcl_GetStringFromObj (objv [4], NULL);
    localMsg = catgets (*catDescPtr, (int)msgSetNum, (int)msgNum, defaultStr);

    Tcl_SetObjResult (interp, Tcl_NewStringObj (localMsg, -1));
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_CatcloseObjCmd --
 *
 *    Implements the TCLX catclose command:
 *        catclose ?-fail|-nofail? catHandle
 *-----------------------------------------------------------------------------
 */
static int
TclX_CatcloseObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    int          fail;
    nl_catd     *catDescPtr;
    int          result = 0;

    if ((objc < 2) || (objc > 3))
	return TclX_WrongArgs (interp, objv [0],
			       "?-fail|-nofail? catHandle");

    if (objc == 3) {
        if (ParseFailOptionObj (interp, objv [1], &fail) != TCL_OK)
            return TCL_ERROR;
    } else
        fail = FALSE;

    catDescPtr = (nl_catd *) TclX_HandleXlateObj (interp, msgCatTblPtr,
                                                  objv [objc - 1]);
    if (catDescPtr == NULL)
        return TCL_ERROR;

    /* If the integer returned by catopen is -1, signifying that the
     * open failed but "-fail" was not specified to actually force
     * the failure, we don't close the catalog, but we do delete
     * the handle. */

    if (*catDescPtr == (nl_catd)-1) {
	result = -1;
    } else {
    /*
     * NetBSD has catclose of return type void, which is non-standard.
     */
#ifdef BAD_CATCLOSE
	catclose (*catDescPtr);
#else
	result = catclose (*catDescPtr);
#endif
    }

    TclX_HandleFree (msgCatTblPtr, catDescPtr);

    if ((result < 0) && fail)
	return CatOpFailedObj (interp, "close of message catalog failed");

    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * MsgCatCleanUp --
 *
 *    Called at interpreter deletion.  Releases all resources when no more
 * interpreters are using the message catalog table.
 *-----------------------------------------------------------------------------
 */
static void
MsgCatCleanUp (clientData, interp)
    ClientData  clientData;
    Tcl_Interp *interp;
{
    nl_catd *catDescPtr;
    int      walkKey;
    
    if (TclX_HandleTblUseCount (msgCatTblPtr, -1) > 0)
        return;

    walkKey = -1;
    while (TRUE) {
        catDescPtr = (nl_catd *) TclX_HandleWalk (msgCatTblPtr, &walkKey);
        if (catDescPtr == NULL)
            break;
	if (*catDescPtr != (nl_catd)-1)
	    catclose (*catDescPtr);
    }
    TclX_HandleTblRelease (msgCatTblPtr);
    msgCatTblPtr = NULL;
}

/*-----------------------------------------------------------------------------
 * TclX_MsgCatInit --
 *
 *   Initialize the Tcl XPG/3 message catalog support faility.
 *-----------------------------------------------------------------------------
 */
void
TclX_MsgCatInit (interp)
    Tcl_Interp *interp;
{
    /*
     * Set up the table.  It is shared between all interpreters, so the use
     * count reflects the number of interpreters.
     */
    if (msgCatTblPtr == NULL) {
        msgCatTblPtr = TclX_HandleTblInit ("msgcat", sizeof (nl_catd), 6);
    } else {
        (void) TclX_HandleTblUseCount (msgCatTblPtr, 1);
    }

    Tcl_CallWhenDeleted (interp, MsgCatCleanUp, (ClientData) NULL);

    /*
     * Initialize the commands.
     */

    Tcl_CreateObjCommand (interp, 
			  "catopen",
			  TclX_CatopenObjCmd, 
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp,
		          "catgets", 
			  TclX_CatgetsObjCmd, 
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);

    Tcl_CreateObjCommand (interp, 
			  "catclose",
			  TclX_CatcloseObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}



