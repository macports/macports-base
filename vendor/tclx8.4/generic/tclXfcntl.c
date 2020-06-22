/*
 * tclXfcntl.c
 *
 * Extended Tcl fcntl command.
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
 * $Id: tclXfcntl.c,v 1.2 2005/01/19 03:20:47 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Attributes sets used by fcntl command.
 */
#define ATTR_ERROR           -1  /* Error parsing attributes.   */

#define ATTR_RDONLY           1  /* Access checks desired.      */
#define ATTR_WRONLY           2
#define ATTR_RDWR             3
#define ATTR_READ             4
#define ATTR_WRITE            5
#define ATTR_APPEND           6
#define ATTR_CLOEXEC          7
#define ATTR_NOBUF            8
#define ATTR_LINEBUF          9
#define ATTR_NONBLOCK        10
#define ATTR_KEEPALIVE       11

/*
 * The maximum length of any attribute name.
 */
#define MAX_ATTR_NAME_LEN  20

/*
 * Table of attribute names and values.
 */
static struct {
    char *name;
    int   id;
    int   modifiable;
} TclXfcntlAttrNames [] = {
    {"RDONLY",    ATTR_RDONLY,    FALSE},
    {"WRONLY",    ATTR_WRONLY,    FALSE},
    {"RDWR",      ATTR_RDWR,      FALSE},
    {"READ",      ATTR_READ,      FALSE},
    {"WRITE",     ATTR_WRITE,     FALSE},
    {"APPEND",    ATTR_APPEND,    TRUE},
    {"CLOEXEC",   ATTR_CLOEXEC,   TRUE},
    {"NONBLOCK",  ATTR_NONBLOCK,  TRUE},
    {"LINEBUF",   ATTR_LINEBUF,   TRUE},
    {"NOBUF",     ATTR_NOBUF,     TRUE},
    {"KEEPALIVE", ATTR_KEEPALIVE, TRUE},
    {NULL,        0,              FALSE}};

/*
 * Prototypes of internal functions.
 */
static int
XlateFcntlAttr  _ANSI_ARGS_((Tcl_Interp  *interp,
                             char        *attrName,
                             int          modify));

static int
GetFcntlAttr _ANSI_ARGS_((Tcl_Interp  *interp,
                          Tcl_Channel  channel,
                          int          mode,
                          int          attrib));

static int
SetFcntlAttrObj _ANSI_ARGS_((Tcl_Interp  *interp,
                             Tcl_Channel  channel,
                             int          attrib,
                             Tcl_Obj     *valueObj));

static int 
TclX_FcntlObjCmd _ANSI_ARGS_((ClientData clientData, 
                              Tcl_Interp *interp,
                              int objc,
                              Tcl_Obj *CONST objv[]));


/*-----------------------------------------------------------------------------
 * XlateFcntlAttr --
 *    Translate an fcntl attribute to an numberic id.
 *
 * Parameters:
 *   o interp - Tcl interp, errors in result
 *   o attrName - The attrbute name to translate, maybe upper or lower case.
 *   o modify - Will the attribute be modified
 * Result:
 *   The number associated with the attirbute, or ATTR_ERROR is an error
 * occures.
 *-----------------------------------------------------------------------------
 */
static int
XlateFcntlAttr (interp, attrName, modify)
    Tcl_Interp  *interp;
    char        *attrName;
    int          modify;
{
    char attrNameUp [MAX_ATTR_NAME_LEN];
    int idx;

    if (strlen (attrName) >= MAX_ATTR_NAME_LEN)
        goto invalidAttrName;
    
    TclX_UpShift (attrNameUp, attrName);
    
    for (idx = 0; TclXfcntlAttrNames [idx].name != NULL; idx++) {
        if (STREQU (attrNameUp, TclXfcntlAttrNames [idx].name)) {
            if (modify && !TclXfcntlAttrNames [idx].modifiable) {
                TclX_AppendObjResult (interp, "Attribute \"", attrName,
                                      "\" may not be altered after open",
                                      (char *) NULL);
                return ATTR_ERROR;
            }
            return TclXfcntlAttrNames [idx].id;
        }
    }

    /*
     * Invalid attribute.
     */
  invalidAttrName:
    TclX_AppendObjResult (interp, "unknown attribute name \"", attrName,
                          "\", expected one of ", (char *) NULL);

    for (idx = 0; TclXfcntlAttrNames [idx + 1].name != NULL; idx++) {
        TclX_AppendObjResult (interp, TclXfcntlAttrNames [idx].name, ", ",
                              (char *) NULL);
    }
    TclX_AppendObjResult (interp, "or ", TclXfcntlAttrNames [idx].name, (char *) NULL);
    return ATTR_ERROR;
}

/*-----------------------------------------------------------------------------
 * GetFcntlAttr --
 *    Return the value of a specified fcntl attribute.
 *
 * Parameters:
 *   o interp - Tcl interpreter, value is returned in the result
 *   o channel - The channel to check.
 *   o mode - Channel access mode.
 *   o attrib - Attribute to get.
 * Result:
 *   TCL_OK or TCL_ERROR
 *-----------------------------------------------------------------------------
 */
static int
GetFcntlAttr (interp, channel, mode, attrib)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int          mode;
    int          attrib;
{
    int value, optValue;

    switch (attrib) {
      case ATTR_RDONLY:
        value = (mode & TCL_READABLE) && !(mode & TCL_WRITABLE);
        break;
      case ATTR_WRONLY:
        value = (mode & TCL_WRITABLE) && !(mode & TCL_READABLE);
        break;
      case ATTR_RDWR:
        value = (mode & TCL_READABLE) && (mode & TCL_WRITABLE);
        break;
      case ATTR_READ:
        value =  (mode & TCL_READABLE);
        break;
      case ATTR_WRITE:
        value = (mode & TCL_WRITABLE);
        break;
      case ATTR_APPEND:
        if (TclXOSGetAppend (interp, channel, &value) != TCL_OK)
            return TCL_ERROR;
        break;
      case ATTR_CLOEXEC:
        if (TclXOSGetCloseOnExec (interp, channel, &value) != TCL_OK)
            return TCL_ERROR;
        break;
      case ATTR_NONBLOCK:
        if (TclX_GetChannelOption (interp, channel, TCLX_COPT_BLOCKING,
                                   &optValue) != TCL_OK)
            return TCL_ERROR;
        value = (optValue == TCLX_MODE_NONBLOCKING);
        break;
      case ATTR_NOBUF:
        if (TclX_GetChannelOption (interp, channel, TCLX_COPT_BUFFERING,
                                   &optValue) != TCL_OK)
            return TCL_ERROR;
        value = (optValue == TCLX_BUFFERING_NONE);
        break;
      case ATTR_LINEBUF:
        if (TclX_GetChannelOption (interp, channel, TCLX_COPT_BUFFERING,
                                   &optValue) != TCL_OK)
            return TCL_ERROR;
        value = (optValue == TCLX_BUFFERING_LINE);
        break;
      case ATTR_KEEPALIVE:
        if (TclXOSgetsockopt (interp, channel, SO_KEEPALIVE, &value) != TCL_OK)
            return TCL_ERROR;
        break;
      default:
        Tcl_Panic ("bug in fcntl get attrib");
    }

    Tcl_SetIntObj (Tcl_GetObjResult (interp), value != 0);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * SetFcntlAttrObj --
 *    Set the the attributes on a channel.
 *
 * Parameters:
 *   o interp - Tcl interpreter, value is returned in the result
 *   o channel - The channel to check.
 *   o attrib - Atrribute to set.
 *   o valueStr - Object value (all are boolean now).
 * Result:
 *   TCL_OK or TCL_ERROR.
 *-----------------------------------------------------------------------------
 */
static int
SetFcntlAttrObj (interp, channel, attrib, valueObj)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    int          attrib;
    Tcl_Obj     *valueObj;
{
    int value;

    if (Tcl_GetBooleanFromObj (interp, valueObj, &value) != TCL_OK)
        return TCL_ERROR;

    switch (attrib) {
      case ATTR_APPEND:
        if (TclXOSSetAppend (interp, channel, value) != TCL_OK)
            return TCL_ERROR;
        return TCL_OK;
      case ATTR_CLOEXEC:
        if (TclXOSSetCloseOnExec (interp, channel, value) != TCL_OK)
            return TCL_ERROR;
        return TCL_OK;
      case ATTR_NONBLOCK:
        return TclX_SetChannelOption (interp, channel, TCLX_COPT_BLOCKING,
                                      value ? TCLX_MODE_NONBLOCKING :
                                              TCLX_MODE_BLOCKING);
      case ATTR_NOBUF:
        return TclX_SetChannelOption (interp, channel, TCLX_COPT_BUFFERING,
                                      value ? TCLX_BUFFERING_NONE :
                                              TCLX_BUFFERING_FULL);
      case ATTR_LINEBUF:
        return TclX_SetChannelOption (interp, channel, TCLX_COPT_BUFFERING,
                                      value ? TCLX_BUFFERING_LINE :
                                              TCLX_BUFFERING_FULL);
      case ATTR_KEEPALIVE:
        return TclXOSsetsockopt (interp, channel, SO_KEEPALIVE, value);
      default:
        Tcl_Panic ("buf in fcntl set attrib");
    }
    return TCL_ERROR;  /* Should never be reached */
}

/*-----------------------------------------------------------------------------
 * TclX_FcntlObjCmd --
 *     Implements the fcntl TCL command:
 *         fcntl handle attribute ?value?
 *-----------------------------------------------------------------------------
 */
static int
TclX_FcntlObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Channel  channel;
    int          mode;
    int          attrib;
    char        *channelString;
    char        *fcntlAttributes;

    if ((objc < 3) || (objc > 4))
	return TclX_WrongArgs (interp, objv [0],
                               "handle attribute ?value?");

    channelString = Tcl_GetStringFromObj (objv[1], NULL);

    channel = Tcl_GetChannel (interp, channelString, &mode);
    if (channel == NULL) {
	return TCL_ERROR;
    }

    fcntlAttributes = Tcl_GetStringFromObj (objv[2], NULL);
    attrib = XlateFcntlAttr (interp, fcntlAttributes, (objc == 4));
    if (attrib == ATTR_ERROR)
        return TCL_ERROR;

    if (objc == 3) {    
        if (GetFcntlAttr (interp, channel, mode, attrib) != TCL_OK)
            return TCL_ERROR;
    } else {
        if (SetFcntlAttrObj (interp, channel, attrib, objv[3]) != TCL_OK)
            return TCL_ERROR;
    }
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * TclX_FcntlInit --
 *     Initialize the fcntl command.
 *-----------------------------------------------------------------------------
 */
void
TclX_FcntlInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp, 
			  "fcntl",
			  TclX_FcntlObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}

