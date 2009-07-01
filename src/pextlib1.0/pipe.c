#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <tcl.h>

#include <errno.h>
#include <string.h>
#include <unistd.h>

#include "pipe.h"

/**
 * Call pipe(2) to create a pipe.
 * Syntax is:
 * pipe
 *
 * Generate a Tcl error if something goes wrong.
 * Return a list with the file descriptors of the pipe. The first item is the
 * readable fd.
 */
int PipeCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj* result;
	int fildes[2];

	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	if (pipe(fildes) < 0) {
		Tcl_AppendResult(interp, "pipe failed: ", strerror(errno), NULL);
		return TCL_ERROR;
	}
	
	/* build a list out of the couple */
	result = Tcl_NewListObj(0, NULL);
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[0]));
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[1]));
	Tcl_SetObjResult(interp, result);

	return TCL_OK;
}
