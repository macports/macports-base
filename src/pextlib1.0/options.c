/*
 * options.c
 * $Id: options.c,v 1.1.2.2 2004/05/29 08:07:13 pguyot Exp $
 *
 * Copyright (c) 2004 Paul Guyot, Darwinports Team.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of Darwinports Team nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include <grp.h>

#if HAVE_STRING_H
#include <string.h>
#endif

#if HAVE_STRINGS_H
#include <strings.h>
#endif

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#if HAVE_PATHS_H
#include <paths.h>
#endif

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL   "/dev/null"
#endif

#include <pwd.h>

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif

#if HAVE_FCNTL_H
#include <fcntl.h>
#endif

#if HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <tcl.h>
#include <tclDecls.h>

#include "options.h"

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
int OptionSetCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[]);
int OptionDeleteCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[]);
int OptionAppendCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[]);
void OptionDeleteProc(ClientData clientData);

/**
 * Create ${name}, ${name}-delete and ${name}-append functions.
 * When these functions are invoked, we call option_set, option_delete and option_create.
 *
 * @param clientData	custom data (NULL here)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
OptionsCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[])
{
#pragma unused (clientData)
	/* Iterate on every parameter. Treat them all as strings. */
	int indexArg;
	for (indexArg = 1; indexArg < objc; indexArg++) {
		/* the name of the option (the current parameter) */
		char* theOptionName;
		/* the size of the name of the option */
		size_t theNameLength;
		/* the Tcl_Obj for the name of the option */
		Tcl_Obj* theOptionNameObject;
		/* the name of the delete and append procedures */
		char* theProcName;

		/* get the option and compute its size */		
		theOptionName = Tcl_GetString(objv[indexArg]);
		theNameLength = strlen(theOptionName);
		
		/* create the Tcl object with this name */
		theOptionNameObject = Tcl_NewStringObj(theOptionName, -1);

		/* create the option command */
		Tcl_IncrRefCount(theOptionNameObject);
		Tcl_CreateObjCommand(
				interp,
				theOptionName,
				OptionSetCmd,
				theOptionNameObject,
				OptionDeleteProc);
				
		/* create the delete string */
		/* 8 = strlen("-delete") + 1 [NULL terminator] */
		theProcName = (char*) malloc( theNameLength + 8 );
		(void) memcpy(theProcName, (const char*) theOptionName, theNameLength);
		(void) memcpy(&theProcName[theNameLength], (const char*) "-delete", 8);
	
		/* create the option-delete command */
		Tcl_IncrRefCount(theOptionNameObject);
		Tcl_CreateObjCommand(
				interp,
				theProcName,
				OptionDeleteCmd,
				theOptionNameObject,
				OptionDeleteProc);
		
		/* create the append string */
		memcpy(&theProcName[theNameLength], (const char*) "-append", 8);
		
		/* create the option-append command */
		Tcl_IncrRefCount(theOptionNameObject);
		Tcl_CreateObjCommand(
				interp,
				theProcName,
				OptionAppendCmd,
				theOptionNameObject,
				OptionDeleteProc);
		
		/* free the procedure name */
		free(theProcName);
	}

	Tcl_SetResult(interp, "", TCL_STATIC);
	return TCL_OK;
}

/**
 * Set the value of an option, unless it was specified by the user
 * (i.e. unless it's in user_options).
 * The name of the option is passed in clientData.
 *
 * @param clientData	custom data (here, the name of the option as a string)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
OptionSetCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc, 
		Tcl_Obj* CONST objv[])
{
	/* Was the variable set by user? */
	if (!Tcl_ObjGetVar2(
				interp,
				Tcl_NewStringObj("user_options", -1),
				clientData,
				TCL_GLOBAL_ONLY))
	{
		if (objc == 1)
		{
			/* Remove the variable. */
			(void) Tcl_UnsetVar(
						interp,
						Tcl_GetString(clientData),
						TCL_GLOBAL_ONLY);
		} else {
			int indexArg;
	
			/* Set the var to be the first parameter. */
			(void) Tcl_ObjSetVar2(
						interp,
						clientData,
						NULL,
						objv[1],
						TCL_GLOBAL_ONLY);
					
			/* Iterate on the other parameters and append them. */
			for (indexArg = 2; indexArg < objc; indexArg++) {
				(void) Tcl_ObjSetVar2(
							interp,
							clientData,
							NULL,
							objv[indexArg],
							TCL_GLOBAL_ONLY | TCL_APPEND_VALUE | TCL_LIST_ELEMENT);
			}
		}
	}
	
	Tcl_SetResult(interp, "", TCL_STATIC);
	return TCL_OK;
}

/**
 * Remove values from the an option, unless it was specified by the user
 * (i.e. unless it's in user_options).
 * The name of the option is passed in clientData.
 *
 * @param clientData	custom data (here, the name of the option as a string)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
OptionDeleteCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[])
{
	if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "args");
		return TCL_ERROR;
	}

	/* Was the variable set by user? */
	if (!Tcl_ObjGetVar2(
				interp,
				Tcl_NewStringObj("user_options", -1),
				clientData,
				TCL_GLOBAL_ONLY))
	{
		int indexElement;
		Tcl_Obj* theValue;
		int nbElements;
		int theResult;
		
		/* Retrieve the current value */
		theValue = Tcl_ObjGetVar2(
					interp,
					clientData,
					NULL,
					TCL_GLOBAL_ONLY);
		
		/* Count the current elements. */
		theResult = Tcl_ListObjLength(
					interp,
					theValue,
					&nbElements);
		if (theResult != TCL_OK) {
			/* It probably couldn't be converted to a list */
			return theResult;
		}
		
		/* Iterate on the elements */
		for (indexElement = 0; indexElement < nbElements; indexElement++)
		{
			int indexArg;
			Tcl_Obj* theElement;
			const char* theElementAsStr;
			theResult = Tcl_ListObjIndex(
						interp, theValue, indexElement, &theElement);
			if (theResult != TCL_OK) {
				/* Some problem occurred. Let's exit. */
				return theResult;
			}
			
			theElementAsStr = Tcl_GetString(theElement);
			
			/* Iterate on the arguments */
			for (indexArg = 1; indexArg < objc; indexArg++)
			{
				const char* theArgumentAsStr = Tcl_GetString(objv[indexArg]);

				/* Is it equal to the element? */
				if (strcmp(theElementAsStr, theArgumentAsStr) == 0)
				{
					/* Remove it from the value */
					theResult = Tcl_ListObjReplace(
									interp,
									theValue,
									indexElement,
									1,
									0 /* objc */,
									NULL /* objv */);
					nbElements--;
					indexElement--;

					/* Remark: user may store several times the same value,
					they will all be deleted */
					break;
				}
			}
		}

		if (nbElements == 0)
		{
			/* Remove the variable. */
			(void) Tcl_UnsetVar(
						interp,
						Tcl_GetString(clientData),
						TCL_GLOBAL_ONLY);
		}
	} /* if [!info exists $user_options($name)] */
	
	Tcl_SetResult(interp, "", TCL_STATIC);
	return TCL_OK;
}


/**
 * The name of the option is passed in clientData.
 *
 * @param clientData	custom data (here, the name of the option as a string)
 * @param interp		current interpreter
 * @param objv			parameters
 */
int
OptionAppendCmd(
		ClientData clientData,
		Tcl_Interp* interp,
		int objc,
		Tcl_Obj* CONST objv[])
{
	if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "args");
		return TCL_ERROR;
	}

	/* Was the variable set by user? */
	if (!Tcl_ObjGetVar2(
				interp,
				Tcl_NewStringObj("user_options", -1),
				clientData,
				TCL_GLOBAL_ONLY))
	{
		int indexArg;

		/* Iterate on the parameters and append them. */
		for (indexArg = 1; indexArg < objc; indexArg++) {
			(void) Tcl_ObjSetVar2(
						interp,
						clientData,
						NULL,
						objv[indexArg],
						TCL_GLOBAL_ONLY | TCL_APPEND_VALUE | TCL_LIST_ELEMENT);
		}
	}
	
	Tcl_SetResult(interp, "", TCL_STATIC);
	return TCL_OK;
}

/**
 * Clean up the clientData.
 *
 * @param clientData	data to clean up.
 */
void
OptionDeleteProc( ClientData clientData )
{
	Tcl_DecrRefCount((Tcl_Obj*) clientData);
}

/* =============================================================================== **
** I am a computer. I am dumber than any human and smarter than any administrator. **
** =============================================================================== */
