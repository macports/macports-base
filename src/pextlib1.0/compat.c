/*
 * compat.c
 * $Id$
 *
 * Copyright (c) 2004 Paul Guyot, MacPorts Team.
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
 * 3. Neither the name of MacPorts Team nor the names of its contributors
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

#include <sys/param.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>

#if HAVE_LIBGEN_H
#include <libgen.h>
#endif

#if HAVE_STRING_H
#include <string.h>
#endif

#include <tcl.h>
#include <tclDecls.h>

#include "compat.h"

/* Avoid a warning with Tcl < 8.4, even if Tcl_GetIndexFromObj's tablePtr
probably isn't modified. */
#if (TCL_MAJOR_VERSION > 8) || (TCL_MINOR_VERSION >= 4)
typedef CONST char* tableEntryString;
#else
typedef char* tableEntryString;
#endif

/* ========================================================================= **
 * Definitions
 * ========================================================================= */
#pragma mark Definitions

/* ------------------------------------------------------------------------- **
 * Prototypes
 * ------------------------------------------------------------------------- */
int CompatFileNormalize(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[]);

/* ========================================================================= **
 * Entry points
 * ========================================================================= */
#pragma mark -
#pragma mark Entry points


/**
 * compat filelinkhard subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CompatFileLinkHard(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		char* theSrcPath;
		char* theDstPath;
		
		/* we only have two parameters. */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "filelinkhard dstpath srcpath");
			theResult = TCL_ERROR;
			break;
		}

		/* retrieve the parameters */
		theDstPath = Tcl_GetString(objv[2]);
		theSrcPath = Tcl_GetString(objv[3]);
		
		/* perform the hard link */
		if (link(theSrcPath, theDstPath) < 0)
		{
			/* some error occurred. Report it. */
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}
    } while (0);
    
	return theResult;
}

/**
 * compat filelinksymbolic subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CompatFileLinkSymbolic(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		char* theSrcPath;
		char* theDstPath;
		
		/* we only have two parameters. */
		if (objc != 4) {
			Tcl_WrongNumArgs(interp, 1, objv, "filelinksymbolic dstpath srcpath");
			theResult = TCL_ERROR;
			break;
		}

		/* retrieve the parameters */
		theDstPath = Tcl_GetString(objv[2]);
		theSrcPath = Tcl_GetString(objv[3]);
		
		/* perform the symbolic link */
		if (symlink(theSrcPath, theDstPath) < 0)
		{
			/* some error occurred. Report it. */
			Tcl_SetResult(interp, strerror(errno), TCL_VOLATILE);
			theResult = TCL_ERROR;
			break;
		}
    } while (0);
    
	return theResult;
}

/**
 * compat filenormalize subcommand entry point.
 *
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CompatFileNormalize(Tcl_Interp* interp, int objc, Tcl_Obj* CONST objv[])
{
	int theResult = TCL_OK;

	do {
		char* thePath;
		char tmpPath[PATH_MAX];
		char* theBaseName;
		char theNormalizedPath[PATH_MAX];
		int pathlength;
		int baselength;
		
		/*	unique (second) parameter is the file path */
		if (objc != 3) {
			Tcl_WrongNumArgs(interp, 1, objv, "filenormalize path");
			theResult = TCL_ERROR;
			break;
		}

		/* retrieve the parameter */
		thePath = Tcl_GetString(objv[2]);
		
		/* Some implementations of dirname(3) modify the memory
			referenced by its argument, so we make a copy of thePath
			just in case. */
		(void) strncpy(tmpPath, (const char*) thePath, sizeof(tmpPath));

		/* normalize the dir name */
		(void) realpath(dirname(tmpPath), theNormalizedPath);
		
		/* append the base name */
		pathlength = strlen(theNormalizedPath);
		theBaseName = basename(thePath);
		baselength = strlen(theBaseName);
		if (pathlength + baselength + 1 >= PATH_MAX)
		{
			Tcl_SetResult(interp, "path is too long", TCL_STATIC);
			theResult = TCL_ERROR;
			break;
		}
		theNormalizedPath[pathlength] = '/';
		/* copy with null terminator */
		(void) memcpy(
					&theNormalizedPath[pathlength + 1],
					theBaseName,
					baselength + 1);
		
		Tcl_SetResult(interp, theNormalizedPath, TCL_VOLATILE);
    } while (0);
    
	return theResult;
}

/**
 * compat command entry point.
 *
 * @param clientData	custom data (ignored)
 * @param interp		current interpreter
 * @param objc			number of parameters
 * @param objv			parameters
 */
int
CompatCmd(
		ClientData clientData UNUSED,
		Tcl_Interp* interp,
		int objc, 
		Tcl_Obj* CONST objv[])
{
    typedef enum {
    	kCompatFileNormalize,
    	kCompatFileLinkHard,
    	kCompatFileLinkSymbolic
    } EOption;
    
	static tableEntryString options[] = {
		"filenormalize", "filelinkhard", "filelinksymbolic", NULL
	};

	int theResult = TCL_OK;
	EOption theOptionIndex;

	if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "option ?arg ...?");
		return TCL_ERROR;
	}

	theResult = Tcl_GetIndexFromObj(
				interp,
				objv[1],
				options,
				"option",
				0,
				(int*) &theOptionIndex);
	if (theResult == TCL_OK) {
		switch (theOptionIndex)
		{
			case kCompatFileNormalize:
				theResult = CompatFileNormalize(interp, objc, objv);
				break;

			case kCompatFileLinkHard:
				theResult = CompatFileLinkHard(interp, objc, objv);
				break;

			case kCompatFileLinkSymbolic:
				theResult = CompatFileLinkSymbolic(interp, objc, objv);
				break;
		}
	}
	
	return theResult;
}

/* ============================================================== **
** As of next Thursday, UNIX will be flushed in favor of TOPS-10. **
** Please update your programs.                                   **
** ============================================================== */
