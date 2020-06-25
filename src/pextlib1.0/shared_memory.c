#if HAVE_CONFIG_H
#include <config.h>
#endif

#include "darwintrace_share/darwintrace_share.h"
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <tcl.h>

shm_offt tcl_string_obj_to_shm_offt(Tcl_Interp *interp, Tcl_Obj *str_obj)
{
	shm_offt offset;

	errno = 0;
	offset = (shm_offt)strtoumax(Tcl_GetString(str_obj), NULL, 10);

	if (errno != 0) {
		Tcl_SetResult(interp, "strtoumax() failed", TCL_STATIC);
		return (SHM_NULL);
	}

	return (offset);
}

Tcl_Obj *shm_offt_to_tcl_string_obj(Tcl_Interp *interp, shm_offt offset)
{
	char *buf;
	int retval;
	Tcl_Obj *str_obj;

	static int buf_len = -1;

	if (buf_len == -1) {
		/* max chars reqd to store a shm_offt type in a string, +1 for '\0' */
		buf_len = snprintf(NULL, 0, "%ju", (shm_offt)-1) + 1;
		
		if (buf_len < 0) {
			Tcl_SetResult(interp, "snprintf(3) failed for getting max char count of shm_offt\n", TCL_STATIC);
			buf_len = -1;
			return (NULL);
		}
	}
	
	buf = calloc(buf_len, sizeof(char));

	if (buf == NULL) {
		Tcl_SetResult(interp, "calloc(2) failed", TCL_STATIC);
		return (NULL);
	}

	retval = snprintf(buf, buf_len, "%ju", offset);

	if (retval < 0) {
		Tcl_SetResult(interp, "snprintf(3) failed while writing root value to buffer\n", TCL_STATIC);
		return (NULL);
	}
	
	str_obj = Tcl_NewStringObj(buf, buf_len);

	free(buf);

	return (str_obj);
}


int SetSharedMemoryCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	/*
	 * Tcl command has no access and need for arg1 of shm_init().
	 */
	bool retval;
	char *shm_filename;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "<shm_filename>");
		return TCL_ERROR;
	}	

	shm_filename = Tcl_GetString(objv[1]);

	retval = set_shared_memory(shm_filename);
	
	if (retval == false) {
		Tcl_SetResult(interp, "set_shared_memory() failed", TCL_STATIC);
		return TCL_ERROR;
	}

	return (TCL_OK);
}

int UnsetSharedMemoryCmd(ClientData clientData UNUSED, Tcl_Interp *interp UNUSED, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
	unset_shared_memory();
	return TCL_OK;	
}
