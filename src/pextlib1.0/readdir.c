#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <tcl.h>

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#include "readdir.h"

/**
 *
 * Return the list of elements in a directory.
 * Since 1.60.4.2, the list doesn't include . and ..
 *
 * Synopsis: readdir directory
 */
int ReaddirCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	DIR *dirp;
	struct dirent *mp;
	Tcl_Obj *tcl_result;
	char *path;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "directory");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);
	dirp = opendir(path);
	if (!dirp) {
		Tcl_SetResult(interp, "Cannot read directory", TCL_STATIC);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewListObj(0, NULL);
	while ((mp = readdir(dirp))) {
		/* Skip . and .. */
		if ((mp->d_name[0] != '.') ||
			((mp->d_name[1] != 0)	/* "." */
				&&
			((mp->d_name[1] != '.') || (mp->d_name[2] != 0)))) /* ".." */ {
			Tcl_ListObjAppendElement(interp, tcl_result, Tcl_NewStringObj(mp->d_name, -1));
		}
	}
	closedir(dirp);
	Tcl_SetObjResult(interp, tcl_result);
	
	return TCL_OK;
}
