/*
 * uid.c
 *
 * uid handling routines
 * By James D. Berry <jberry@macports.org> 4/6/06
 *
 * $Id$
 *
 */
 
#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/types.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <tcl.h>

#include "uid.h"

/*
	getuid
	
	synopsis: getuid
*/
int getuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	/* Check the arg count */
	if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	Tcl_SetObjResult(interp, Tcl_NewLongObj(getuid()));
	return TCL_OK;
}

/*
	geteuid
	
	synopsis: geteuid
*/
int geteuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	/* Check the arg count */
	if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	Tcl_SetObjResult(interp, Tcl_NewLongObj(geteuid()));
	return TCL_OK;
}

/*
    getgid
*/
int getgidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
        return TCL_ERROR;
    }
    
    Tcl_SetObjResult(interp, Tcl_NewLongObj(getgid()));
    return TCL_OK;
}

/*
    getegid
*/
int getegidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    if (objc != 1) {
        Tcl_WrongNumArgs(interp, 1, objv, NULL);
        return TCL_ERROR;
    }
    
    Tcl_SetObjResult(interp, Tcl_NewLongObj(getegid()));
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
    setgid
*/
int setgidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    long gid;
    
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "gid");
        return TCL_ERROR;
    }
    
    if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &gid)) {
        return TCL_ERROR;
    }
    
    if (0 != setgid(gid)) {
        Tcl_Obj *result = Tcl_NewStringObj("could not set gid to ", -1);
        Tcl_AppendObjToObj(result, objv[1]);
        Tcl_SetObjResult(interp, result);
        return TCL_ERROR;
    }
    
    return TCL_OK;
}

/*
    setegid
*/
int setegidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    long gid;
    
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "gid");
        return TCL_ERROR;
    }
    
    if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &gid)) {
        return TCL_ERROR;
    }
    
    if (0 != setegid(gid)) {
        Tcl_Obj *result = Tcl_NewStringObj("could not set effective gid to ", -1);
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

/*
	uname_to_gid
	
	synopsis: uname_to_gid name
	this function takes a *user* name
*/
int uname_to_gidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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
	
	/* Map the name --> user gid */
	pwent = getpwnam(name);

	if (pwent == NULL)
		Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
	else
		Tcl_SetObjResult(interp, Tcl_NewIntObj(pwent->pw_gid)); 

	return TCL_OK;
}

/*
    name_to_gid

	synopsis: name_to_gid name
    this function takes a *group* name
*/
int name_to_gidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct group *grent;
    char *name;
    
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "name");
        return TCL_ERROR;
    }
    
    name = Tcl_GetString(objv[1]);
    if (name == NULL || !*name)
        return TCL_ERROR;
    
    grent = getgrnam(name);
    
    if (grent == NULL)
        Tcl_SetObjResult(interp, Tcl_NewIntObj(-1));
    else
        Tcl_SetObjResult(interp, Tcl_NewIntObj(grent->gr_gid)); 
    
    return TCL_OK;
}

/*
    gid_to_name
*/
int gid_to_nameCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    long gid;
    struct group *grent;
    
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "gid");
        return TCL_ERROR;
    }
    
    if (TCL_OK != Tcl_GetLongFromObj(interp, objv[1], &gid))
        return TCL_ERROR;
    
    grent = getgrgid(gid);
    if (grent != NULL)
        Tcl_SetResult(interp, grent->gr_name, TCL_STATIC);
    
    return TCL_OK;
}
