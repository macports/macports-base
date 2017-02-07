/*
 * tclXlgets.c
 *
 * Extended Tcl lgets command.
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
 * $Id: tclXlgets.c,v 1.1 2001/10/24 23:31:48 hobbs Exp $
 *-----------------------------------------------------------------------------
 */
/* 
 *-----------------------------------------------------------------------------
 * Note: The list parsing code is from Tcl distribution file tclUtil.c,
 * procedure TclFindElement:
 * Copyright (c) 1987-1993 The Regents of the University of California.
 * Copyright (c) 1994-1997 Sun Microsystems, Inc.
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * State for current list being read.
 */
typedef struct {
    Tcl_Channel channel;   /* Channel to read from */
    Tcl_DString buffer;    /* Buffer for line being read */
    int lineIdx;           /* Index of next line to read. */
} ReadData;


/*
 * Prototypes of internal functions.
 */
static int
ReadListLine _ANSI_ARGS_((Tcl_Interp  *interp,
                          ReadData    *dataPtr));

static int
ReadListInit _ANSI_ARGS_((Tcl_Interp  *interp,
                          Tcl_Channel  channel,
                          ReadData    *dataPtr));

static int
ReadListElement _ANSI_ARGS_((Tcl_Interp  *interp,
                             ReadData    *dataPtr,
                             Tcl_Obj     *elemObjPtr));

static int 
TclX_LgetsObjCmd _ANSI_ARGS_((ClientData  clientData, 
                             Tcl_Interp  *interp, 
                             int          objc,
                             Tcl_Obj     *CONST objv[]));


/*-----------------------------------------------------------------------------
 * ReadLineList --
 *
 *   Read a list line from a channel.
 *
 * Paramaters:
 *   o interp - Errors are returned in result.
 *   o dataPtr - Data for list read.
 * Returns:
 *   o TCL_OK if read succeeded..
 *   o TCL_BREAK if EOF without reading any data.
 *   o TCL_ERROR if an error occured, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
ReadListLine (interp, dataPtr)
    Tcl_Interp  *interp;
    ReadData    *dataPtr;
{
    /*
     * Read the first line of the list. 
     */
    if (Tcl_Gets (dataPtr->channel, &dataPtr->buffer) < 0) {
        if (Tcl_Eof (dataPtr->channel)) {
            /*
             * If not first read, then we have failed in the middle of a list.
             */
            if (dataPtr->lineIdx > 0) {
                TclX_AppendObjResult (interp, "EOF in list element",
                                      (char *) NULL);
                return TCL_ERROR;
            }
            return TCL_BREAK;  /* EOF with no data */
        }
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }
    
    /*
     * If data was read, but the read terminate with an EOF rather than a
     * newline, its an error.
     */
    if (Tcl_Eof (dataPtr->channel)) {
        TclX_AppendObjResult (interp,
                              "EOF encountered before newline while reading ",
                              "list from channel", (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Add back in the newline.
     */
    Tcl_DStringAppend (&dataPtr->buffer, "\n", 1);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * ReadListInit --
 *
 *    Initialize for reading list elements from a file.
 *
 * Paramaters:
 *   o interp - Errors are returned in result.
 *   o channel - The channel to read from.
 *   o dataPtr - Data for list read.
 * Returns:
 *   o TCL_OK if read to read.
 *   o TCL_BREAK if EOF without reading any data.
 *   o TCL_ERROR if an error occured, with error message in interp.
 *-----------------------------------------------------------------------------
 */
static int
ReadListInit (interp, channel, dataPtr)
    Tcl_Interp  *interp;
    Tcl_Channel  channel;
    ReadData    *dataPtr;
{
    int rstat;
    char *p, *limit;

    dataPtr->channel = channel;
    Tcl_DStringInit (&dataPtr->buffer);
    dataPtr->lineIdx = 0;

    rstat = ReadListLine (interp, dataPtr);
    if (rstat != TCL_OK)
        return rstat;

    /*
     * Advance to the first non-whitespace.
     */
    p =  Tcl_DStringValue (&dataPtr->buffer);
    limit = p + Tcl_DStringLength (&dataPtr->buffer);
    while ((p < limit) && (isspace(UCHAR(*p)))) {
        p++;
    }
    dataPtr->lineIdx = p - Tcl_DStringValue (&dataPtr->buffer);
    return TCL_OK;
}


/*-----------------------------------------------------------------------------
 * ReadListElement --
 *
 *    Read the next element of the list.  If the end of the string is reached
 * while still in the list element, read another line.
 *
 * Paramaters:
 *   o interp - Errors are returned in result.
 *   o dataPtr - Data for list read.  As initialized by ReadListInit.
 *   o elemObjPtr - An object to copy the list element to.
 * Returns:
 *   o TCL_OK if an element was read.
 *   o TCL_BREAK if the end of the list was reached.
 *   o TCL_ERROR if an error occured.
 * Notes:
 *   Code is a modified version of UCB procedure tclUtil.c:TclFindElement
 *-----------------------------------------------------------------------------
 */
static int
ReadListElement (interp, dataPtr, elemObjPtr)
    Tcl_Interp  *interp;
    ReadData    *dataPtr;
    Tcl_Obj     *elemObjPtr;
{
    register char *p;
    char *cpStart;		/* Points to next byte to copy. */
    char *limit;		/* Points just after list's last byte. */
    int openBraces = 0;		/* Brace nesting level during parse. */
    int inQuotes = 0;
    int numChars;
    char *p2;
    int rstat, cpIdx;

    p = Tcl_DStringValue (&dataPtr->buffer) + dataPtr->lineIdx;
    limit = Tcl_DStringValue (&dataPtr->buffer) +
        Tcl_DStringLength (&dataPtr->buffer);

    /*
     * If we are at the end of the string, there are no more elements.
     */
    if (p == limit) {		/* no element found */
        return TCL_BREAK;
    }

    /*
     * Check for an opening brace or quote. We treat embedded NULLs in the
     * list as bytes belonging to a list element.
     */

    if (*p == '{') {
	openBraces = 1;
	p++;
    } else if (*p == '"') {
	inQuotes = 1;
	p++;
    }
    cpStart = p;

    /*
     * Find element's end (a space, close brace, or the end of the string).
     */

    while (1) {
	switch (*p) {

	    /*
	     * Open brace: don't treat specially unless the element is in
	     * braces. In this case, keep a nesting count.
	     */

	    case '{':
		if (openBraces != 0) {
		    openBraces++;
		}
		break;

	    /*
	     * Close brace: if element is in braces, keep nesting count and
	     * quit when the last close brace is seen.
	     */

	    case '}':
		if (openBraces > 1) {
		    openBraces--;
		} else if (openBraces == 1) {
                    Tcl_AppendToObj (elemObjPtr, cpStart, (p - cpStart));
		    p++;
		    if ((p >= limit) || isspace(UCHAR(*p))) {
			goto done;
		    }

		    /*
		     * Garbage after the closing brace; return an error.
		     */
		    
		    if (interp != NULL) {
			char buf[100];
			
			p2 = p;
			while ((p2 < limit) && (!isspace(UCHAR(*p2)))
			        && (p2 < p+20)) {
			    p2++;
			}
			sprintf(buf,
				"list element in braces followed by \"%.*s\" instead of space",
				(int) (p2-p), p);
                        Tcl_ResetResult (interp);
                        TclX_AppendObjResult (interp, buf, (char *) NULL);
		    }
		    return TCL_ERROR;
		}
		break;

	    /*
	     * Backslash:  skip over everything up to the end of the
	     * backslash sequence.  Copy the character to the output obj
             * and reset the location of the rest of the string to copy.
             * If in braces, include backslash and character as-is, otherwise
             * drop it.
	     */

	    case '\\': {
		char bsChar;

                bsChar = Tcl_Backslash(p, &numChars);
                if (openBraces > 0) {
                    p += (numChars - 1);  /* Advanced again at end of loop */
                } else {
                    Tcl_AppendToObj (elemObjPtr, cpStart, (p - cpStart));
                    Tcl_AppendToObj (elemObjPtr, &bsChar, 1);
                    p += (numChars - 1);
                    cpStart = p + 1;  /* already stored character */
                }
		break;
	    }

	    /*
	     * Space: ignore if element is in braces or quotes; otherwise
	     * terminate element.
	     */

	    case ' ':
	    case '\f':
	    case '\n':
	    case '\r':
	    case '\t':
	    case '\v':
		if ((openBraces == 0) && !inQuotes) {
                    Tcl_AppendToObj (elemObjPtr, cpStart, (p - cpStart));
		    goto done;
		}
		break;

	    /*
	     * Double-quote: if element is in quotes then terminate it.
	     */

	    case '"':
		if (inQuotes) {
                    Tcl_AppendToObj (elemObjPtr, cpStart, (p - cpStart));
		    p++;
		    if ((p >= limit) || isspace(UCHAR(*p))) {
			goto done;
		    }

		    /*
		     * Garbage after the closing quote; return an error.
		     */
		    
		    if (interp != NULL) {
			char buf[100];
			
			p2 = p;
			while ((p2 < limit) && (!isspace(UCHAR(*p2)))
				 && (p2 < p+20)) {
			    p2++;
			}
			sprintf(buf,
				"list element in quotes followed by \"%.*s\" %s",
				(int) (p2-p), p, "instead of space");
                        Tcl_ResetResult (interp);
                        TclX_AppendObjResult (interp, buf, (char *) NULL);
		    }
		    return TCL_ERROR;
		}
		break;

	    /*
	     * Zero byte.
	     */

	    case 0: {
                /*
                 * If we are not at the end of the string, this is just
                 * binary data in the list..
                 */
                if (p != limit)
                    break;  /* Byte of zero */

                if ((openBraces == 0) && (inQuotes == 0)) {
                    Tcl_AppendToObj (elemObjPtr, cpStart, (p - cpStart));
                    goto done;
                }
                
                /*
                 * Need new line.  Buffer might be realloc-ed, so recalculate
                 * pointers.  Note we set `p' to one back, since we don't want
                 * the p++ below to miss the next character.
                 */
                dataPtr->lineIdx = p - Tcl_DStringValue (&dataPtr->buffer);
                cpIdx = cpStart - Tcl_DStringValue (&dataPtr->buffer);

                rstat = ReadListLine (interp, dataPtr);
                if (rstat != TCL_OK)
                    return rstat;

                p = Tcl_DStringValue (&dataPtr->buffer) + dataPtr->lineIdx - 1;
                limit = Tcl_DStringValue (&dataPtr->buffer) +
                    Tcl_DStringLength (&dataPtr->buffer);
                cpStart = Tcl_DStringValue (&dataPtr->buffer) + cpIdx;
            }
        }
	p++;
    }

    done:
    while ((p < limit) && (isspace(UCHAR(*p)))) {
	p++;
    }
    dataPtr->lineIdx = p - Tcl_DStringValue (&dataPtr->buffer);
    return TCL_OK;
}

/*-----------------------------------------------------------------------------
 * Tcl_LgetsObjCmd --
 *
 * Implements the `lgets' Tcl command:
 *    lgets fileId ?varName?
 *
 * Results:
 *      A standard Tcl result.
 *
 * Side effects:
 *      See the user documentation.
 *-----------------------------------------------------------------------------
 */
static int
TclX_LgetsObjCmd (clientData, interp, objc, objv)
    ClientData   clientData;
    Tcl_Interp  *interp;
    int          objc;
    Tcl_Obj    *CONST objv[];
{
    Tcl_Channel channel;
    ReadData readData;
    int rstat, optValue;
    Tcl_Obj *elemObj, *dataObj;

    if ((objc < 2) || (objc > 3)) {
        return TclX_WrongArgs (interp, objv [0], "fileId ?varName?");
    }

    channel = TclX_GetOpenChannelObj (interp, objv [1], TCL_READABLE);
    if (channel == NULL)
        return TCL_ERROR;

    /*
     * If the channel is non-blocking, its an error, we don't support it
     * yet.
     * FIX: Make callback driven for non-blocking.
     */
    if (TclX_GetChannelOption (interp, channel, TCLX_COPT_BLOCKING,
                               &optValue) != TCL_OK)
        return TCL_ERROR;
    if (optValue == TCLX_MODE_NONBLOCKING) {
        TclX_AppendObjResult (interp, "channel is non-blocking; not ",
                              "currently supported by the lgets command",
                              (char *) NULL);
        return TCL_ERROR;
    }

    /*
     * Read the list, parsing off each element until the list is read.
     * More lines are read if newlines are encountered in the middle of
     * a list.
     */
    rstat = ReadListInit (interp, channel, &readData);

    dataObj = Tcl_NewListObj (0, NULL);
    Tcl_IncrRefCount (dataObj);

    while (rstat == TCL_OK) {
        elemObj = Tcl_NewStringObj ("", 0);
        rstat = ReadListElement (interp, &readData, elemObj);
        if (rstat == TCL_OK) {
            Tcl_ListObjAppendElement (NULL, dataObj, elemObj);
        } else {
            Tcl_DecrRefCount (elemObj);
        }
    }
    if (rstat == TCL_ERROR)
        goto errorExit;

    /*
     * Return the string as a result or in a variable.
     */
    if (objc == 2) {
        Tcl_SetObjResult (interp, dataObj);
    } else {
        int resultLen;

        if (Tcl_ObjSetVar2(interp, objv[2], NULL, dataObj,
                           TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) == NULL) {
            goto errorExit;
        }

        if (Tcl_Eof (channel) || Tcl_InputBlocked (channel)) {
            resultLen = -1;
        } else {
            /* Adjust length for extra newlines that are inserted */
            resultLen = Tcl_DStringLength (&readData.buffer) - 1;
        }
        Tcl_SetIntObj (Tcl_GetObjResult (interp), resultLen);
    }
    Tcl_DecrRefCount (dataObj);
    Tcl_DStringFree (&readData.buffer);
    return TCL_OK;
    
  errorExit:
    /* 
     * If a variable is supplied, return whatever data we have in buffer
     * that has not been processed.  The last bit of data is save as
     * the last element.  This is mostly good for debugging.
     */
    if (objc > 2) {
        Tcl_Obj *saveResult;
        int len = Tcl_DStringLength (&readData.buffer) - readData.lineIdx;

        if (len > 0) {
            Tcl_ListObjAppendElement (
                NULL, dataObj,
                Tcl_NewStringObj (Tcl_DStringValue (&readData.buffer),
                                  len));
        }
        
        saveResult = Tcl_GetObjResult (interp);
        Tcl_IncrRefCount (saveResult);

        /*
         * Save data in variable, if an error occures, let it be reported
         * instead of original error.
         * FIX: Need functions to save/restore error state.
         */
        if (Tcl_ObjSetVar2(interp, objv[2], NULL, dataObj,
                           TCL_PARSE_PART1|TCL_LEAVE_ERR_MSG) != NULL) {
            Tcl_SetObjResult (interp, saveResult);  /* Restore old message */
        }
        Tcl_DecrRefCount (saveResult);
    }

    Tcl_DecrRefCount (dataObj);
    Tcl_DStringFree (&readData.buffer);

    return TCL_ERROR;
}
    

/*-----------------------------------------------------------------------------
 * TclX_LgetsInit --
 *     Initialize the lgets command.
 *-----------------------------------------------------------------------------
 */
void
TclX_LgetsInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
                          "lgets",
                          TclX_LgetsObjCmd,
                          (ClientData) NULL,
                          (Tcl_CmdDeleteProc*) NULL);
}

