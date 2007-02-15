/*
 * find.c
 * $Id$
 *
 * Find files and execute arbitrary expressions on them.
 * Author: Jordan K. Hubbard
 *
 * Copyright (c) 2004 Apple Computer, Inc.
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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
#include <string.h>

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#include <tcl.h>

static int do_find(Tcl_Interp *interp, int depth, char *dir, char *match, char *action);

int
FindCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *startdir;
	char *match, *action;
	char *def_match = "1";
	char *def_action = "puts \"$_filename\"";
	int depth = 0;

	/* Adjust arguments */
	++objv, --objc;

	if (objc && !strcmp(Tcl_GetString(*objv), "-depth")) {
		depth = 1;
		++objv, --objc;
	}
	if (!objc)
		startdir = ".";
	else {
		startdir = Tcl_GetString(*objv);
		++objv, --objc;
	}
	if (!objc)
		match = def_match;
	else {
		match = Tcl_GetString(*objv);
		++objv, --objc;
	}
	if (!objc)
		action = def_action;
	else {
		action = Tcl_GetString(*objv);
		++objv, --objc;
	}
	if (objc) {
		Tcl_WrongNumArgs(interp, 1, objv, "[dir] [match] [action]");
		return TCL_ERROR;
	}
	return do_find(interp, depth, startdir, match, action);
}

static int
do_find(Tcl_Interp *interp, int depth, char *dir, char *match, char *action)
{
	DIR *dirp;
	struct dirent *dp;
	int rval, alen;
	struct stat sb;
	
	if ((dirp = opendir(dir)) == NULL)
		return TCL_ERROR;
	/* be optimistic */
	rval = TCL_OK;

	alen = strlen(action);

	while ((dp = readdir(dirp)) != NULL) {
		char tmp_path[PATH_MAX];
		int res;

		if (!strcmp(dp->d_name, ".") || !strcmp(dp->d_name, ".."))
			continue;
		strcpy(tmp_path, dir);
		strcat(tmp_path, "/");
		strcat(tmp_path, dp->d_name);

		/* No permission? */
		if (stat(tmp_path, &sb) != 0)
			continue;
		/* Handle directories specially.  If depth, do it now */
		if (depth && sb.st_mode & S_IFDIR) {
			if (do_find(interp, depth, tmp_path, match, action) != TCL_OK)
				return TCL_ERROR;
		}
		Tcl_SetVar(interp, "_filename", tmp_path, TCL_GLOBAL_ONLY);
		if (Tcl_ExprBoolean(interp, match, &res) == TCL_OK) {
			if (res == 1) {
				/* match */
				if (Tcl_EvalEx(interp, action, alen, TCL_EVAL_GLOBAL) != TCL_OK) {
					rval = TCL_ERROR;
					break;
				}
			}
			else
				continue;
		}
		else {
			rval = TCL_ERROR;
			break;
		}
		/* Handle directories specially.  If !depth, do it now */
		if (!depth && sb.st_mode & S_IFDIR) {
			if (do_find(interp, depth, tmp_path, match, action) != TCL_OK)
				return TCL_ERROR;
		}
	}
	(void)closedir(dirp);
	return rval;
}
