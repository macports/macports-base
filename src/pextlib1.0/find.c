/*
 * Find files and execute arbitrary expressions on them.
 *
 * Author: Jordan K. Hubbard
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/syslimits.h>
#include <dirent.h>

#include <tcl.h>

static int	do_find(Tcl_Interp *interp, char *dir, char *match, char *action);

int
findfunc(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *startdir;
	char *match, *action;
	char *def_match = "expr 1";
	char *def_action = "puts \"$filename\"";

	/* Adjust arguments */
	++objv, --objc;

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
	return do_find(interp, startdir, match, action);
}

static int
do_find(Tcl_Interp *interp, char *dir, char *match, char *action)
{
	DIR *dirp;
	struct dirent *dp;
	Tcl_Obj *result;
	int val, rval, mlen, alen;
	struct stat sb;
	
	if ((dirp = opendir(dir)) == NULL)
		return TCL_ERROR;
	/* be optimistic */
	rval = TCL_OK;

	mlen = strlen(match);
	alen = strlen(action);

	while ((dp = readdir(dirp)) != NULL) {
		char tmp_path[PATH_MAX];

		if (!strcmp(dp->d_name, ".") || !strcmp(dp->d_name, ".."))
			continue;
		strcpy(tmp_path, dir);
		strcat(tmp_path, "/");
		strcat(tmp_path, dp->d_name);

		/* No permission? */
		if (stat(tmp_path, &sb) != 0)
			continue;
		/* Handle directories specially */
		if (sb.st_mode & S_IFDIR) {
			if (do_find(interp, tmp_path, match, action) != TCL_OK)
				return TCL_ERROR;
		}
		else {
			Tcl_SetVar(interp, "filename", tmp_path, TCL_GLOBAL_ONLY);
			if (Tcl_EvalEx(interp, match, mlen, TCL_EVAL_GLOBAL) == TCL_OK) {
				result = Tcl_GetObjResult(interp);
				if (Tcl_GetIntFromObj(interp, result, &val) != TCL_OK) {
					rval = TCL_ERROR;
					break;
				}
				if (!val)
					continue;
				else {	/* match */
					if (Tcl_EvalEx(interp, action, alen, TCL_EVAL_GLOBAL) != TCL_OK) {
						rval = TCL_ERROR;
						break;
					}
				}
			}
			else {
				rval = TCL_ERROR;
				break;
			}
		}
	}
	(void)closedir(dirp);
	return rval;
}

