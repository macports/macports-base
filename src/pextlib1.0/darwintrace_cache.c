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
 * It just calls new_cache_tree().
 * The shm_offt type returned from it is converted into a string without any
 * modifications and returned
 */
int NewCacheTreeCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
	shm_offt root;
	Tcl_Obj *tcl_result;

	root = new_cache_tree();

	if (root == SHM_NULL) {
		Tcl_SetResult(interp, "new_cache_tree() failed", TCL_STATIC);
		return (TCL_ERROR);
	}

	tcl_result = shm_offt_to_tcl_string_obj(interp, root);

	if (tcl_result == NULL) {
		Tcl_SetResult(interp, "shm_offt_to_tcl_string_obj() failed", TCL_STATIC);
		return (TCL_ERROR);
	}

	Tcl_SetObjResult(interp, tcl_result);
	return (TCL_OK);
}
