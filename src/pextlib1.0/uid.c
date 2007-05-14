/*
 * uid.c
 *
 * uid handling routines
 * By James D. Berry <jberry@opendarwin.org> 4/6/06
 *
 * $Id$
 *
 */
 
#include "uid.h"

#if HAVE_CONFIG_H
#include <config.h>
#endif

#if HAVE_STDLIB_H
#include <stdlib.h>
#endif

#if HAVE_STRING_H
#include <string.h>
#endif

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_STDIO_H
#include <stdio.h>
#endif

#if HAVE_PWD_H
#include <pwd.h>
#endif

#include <tcl.h>


/*
	getuid
	
	synopsis: getuid
*/
int getuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *tcl_result;
	
	/* Check the arg count */
	if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	tcl_result = Tcl_NewLongObj(getuid());	
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}


/*
	geteuid
	
	synopsis: geteuid
*/
int geteuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *tcl_result;
	
	/* Check the arg count */
	if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	tcl_result = Tcl_NewLongObj(geteuid());	
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}


/*
	setuid
	
	synopsis: setuid uid
*/
int setuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	long uid = 0;
	
	/* Check the arg count */
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "uid");
		return TCL_ERROR;
	}
	
	/* Get the new uid */
	if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &uid))
		return TCL_ERROR;
		
	/* set the uid */
	if (0 != setuid(uid)) {
        Tcl_Obj *result = Tcl_NewStringObj("could not set uid to ", -1);
        Tcl_AppendObjToObj(result, objv[1]);
        Tcl_SetObjResult(interp, result);
        return TCL_ERROR;
    }
		
	return TCL_OK;
}



/*
	seteuid
	
	synopsis: seteuid uid
*/
int seteuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	long uid = 0;

	/* Check the arg count */
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "uid");
		return TCL_ERROR;
	}
	
	/* Get the new euid */
	if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &uid))
		return TCL_ERROR;
		
	/* set the euid */
	if (0 != seteuid(uid)) {
        Tcl_Obj *result = Tcl_NewStringObj("could not set effective uid to ", -1);
        Tcl_AppendObjToObj(result, objv[1]);
        Tcl_SetObjResult(interp, result);
        return TCL_ERROR;
    }
		
	return TCL_OK;
}



/*
	name_to_uid
	
	synopsis: name_to_uid name
*/
int name_to_uidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	struct passwd *pwent;
	char* name = NULL;
	
	/* Check the arg count */
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "name");
		return TCL_ERROR;
	}
	
	/* Get the  name */
	name = Tcl_GetString(objv[1]);
	if (name == NULL || !*name)
		return TCL_ERROR;
	
	/* Map the name --> uid */
	pwent = getpwnam(name);

	if (pwent == NULL)
		Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
	else
		Tcl_SetObjResult(interp, Tcl_NewIntObj(pwent->pw_uid)); 

	return TCL_OK;
}



/*
	uid_to_name
	
	synopsis: uid_to_name uid
*/
int uid_to_nameCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	long uid = 0;
	struct passwd *pwent;
	
	/* Check the arg count */
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "uid");
		return TCL_ERROR;
	}
	
	/* Get the  uid */
	if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &uid))
		return TCL_ERROR;
	
	/* Map the uid --> name, or empty result on error */
	pwent = getpwuid(uid);
	if (pwent != NULL)
		Tcl_SetResult(interp, pwent->pw_name, TCL_STATIC);

	return TCL_OK;
}



