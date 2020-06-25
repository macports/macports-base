#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "darwintrace_share/darwintrace_share.h"
#include <errno.h>
#include <inttypes.h>
#include "shared_memory.h"
#include <stdio.h>
#include <stdlib.h>
#include <tcl.h>

/*
 * It just calls new_trace_sandbox().
 * The shm_offt type returned from it is converted into a string without any
 * modifications and returned.
 */
int TraceSandboxNewCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
	shm_offt root;
	Tcl_Obj *tcl_result;

	root = new_trace_sandbox();

	if (root == SHM_NULL) {
		Tcl_SetResult(interp, "new_trace_sandbox() failed", TCL_STATIC);
		return TCL_ERROR;
	}

	tcl_result = shm_offt_to_tcl_string_obj(interp, root);
	
	if (tcl_result == NULL) {
		Tcl_SetResult(interp, "shm_offt_to_tcl_string_obj() failed", TCL_STATIC);
		return (TCL_ERROR);
	}

	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}

int TraceSandboxAddCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	shm_offt root;
	bool retval;
	char *path;
	char *tmpstr;
	uint8_t permission;
	char char_permission;

	if (objc != 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "<sandbox> <path_prefix> <permission>");
		return (TCL_ERROR);
	}

	root = tcl_string_obj_to_shm_offt(interp, objv[1]);
	path = Tcl_GetString(objv[2]);
	tmpstr = Tcl_GetString(objv[3]);
	char_permission = tmpstr[0];

	switch(char_permission) {
		case '+':
			permission = TRACE_SANDBOX_ALLOW;
			break;
		case '-':
			permission = TRACE_SANDBOX_DENY;
			break;
		case '?':
			permission = TRACE_SANDBOX_ASK_SERVER;
			break;
		default:
			Tcl_SetResult(interp, "unknown permission character, should be '+', '-' or '?'", TCL_STATIC);
			return (TCL_ERROR);
	}

	retval = add_to_trace_sandbox(root, path, permission);

	if (retval == false) {
		Tcl_SetResult(interp, "add_to_trace_sandbox() failed", TCL_STATIC);
		return (TCL_ERROR);
	}

	return (TCL_OK);
}

int TraceSandboxSetFenceCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	shm_offt root;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "<sandbox>");
		return (TCL_ERROR);
	}

	root = tcl_string_obj_to_shm_offt(interp, objv[1]);

	trace_sandbox_set_fence(root);

	return (TCL_OK);
}

int TraceSandboxUnsetFenceCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	shm_offt root;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "<sandbox>");
		return (TCL_ERROR);
	}

	root = tcl_string_obj_to_shm_offt(interp, objv[1]);

	trace_sandbox_unset_fence(root);

	return (TCL_OK);
}
