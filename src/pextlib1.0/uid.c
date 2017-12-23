/*
 * uid.c
 *
 * uid handling routines
 * By James D. Berry <jberry@macports.org> 4/6/06
 *
 */
 
#if HAVE_CONFIG_H
#include <config.h>
#endif

/* required for seteuid(2)/setegid(2) */
#define _BSD_SOURCE

#include <sys/types.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

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
        char buffer[128];
        snprintf(buffer, sizeof(buffer), "could not set uid to %ld: %d %s", uid, errno, strerror(errno));
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buffer, -1));
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
        char buffer[128];
        snprintf(buffer, sizeof(buffer), "could not set effective uid to %ld: %d %s", uid, errno, strerror(errno));
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buffer, -1));
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
        char buffer[128];
        snprintf(buffer, sizeof(buffer), "could not set gid to %ld: %d %s", gid, errno, strerror(errno));
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buffer, -1));
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
        char buffer[128];
        snprintf(buffer, sizeof(buffer), "could not set effective gid to %ld: %d %s", gid, errno, strerror(errno));
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buffer, -1));
        return TCL_ERROR;
    }
    
    return TCL_OK;
}

/**
 * wrapper around getpwuid(3)
 *
 * getpwuid <uid> [<field>]
 *
*/
int getpwuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    uid_t uid;
    const char *field = NULL;
    struct passwd *pw;
    Tcl_Obj *result;

    /* Check the arg count */
    if (objc < 2 || objc > 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "getpwuid uid ?field?");
        return TCL_ERROR;
    }

    /* Need to cast uid from int to unsigned int */
    if (Tcl_GetIntFromObj(interp, objv[1], (int *) &uid) != TCL_OK) {
        Tcl_SetResult(interp, "invalid uid", TCL_STATIC);
        return TCL_ERROR;
    }

    if (objc == 3) {
        field = Tcl_GetString(objv[2]);
    }

    pw = getpwuid(uid);
    if (pw == NULL) {
        result = Tcl_NewStringObj("getpwuid failed for ", -1);
        Tcl_AppendObjToObj(result, Tcl_NewIntObj(uid));
        Tcl_SetObjResult(interp, result);
        return TCL_ERROR;
    }

    if (field == NULL) {
        Tcl_Obj *reslist;
        reslist = Tcl_NewListObj(0, NULL);
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("name", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_name, -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("passwd", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_passwd, -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("uid", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewIntObj(pw->pw_uid));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("gid", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewIntObj(pw->pw_gid));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("gecos", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_gecos, -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("dir", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_dir, -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("shell", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_shell, -1));
#ifdef __APPLE__
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("change", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewLongObj(pw->pw_change));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("class", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj(pw->pw_class, -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewStringObj("expire", -1));
        Tcl_ListObjAppendElement(interp, reslist, Tcl_NewLongObj(pw->pw_expire));
#endif
        Tcl_SetObjResult(interp, reslist);
        return TCL_OK;
    }

    if (strcmp(field, "name") == 0) {
        Tcl_SetResult(interp, pw->pw_name, TCL_VOLATILE);
        return TCL_OK;
    } else if (strcmp(field, "passwd") == 0) {
        Tcl_SetResult(interp, pw->pw_passwd, TCL_VOLATILE);
        return TCL_OK;
    } else if (strcmp(field, "uid") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(pw->pw_uid));
        return TCL_OK;
    } else if (strcmp(field, "gid") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewIntObj(pw->pw_gid));
        return TCL_OK;
    } else if (strcmp(field, "gecos") == 0) {
        Tcl_SetResult(interp, pw->pw_gecos, TCL_VOLATILE);
        return TCL_OK;
    } else if (strcmp(field, "dir") == 0) {
        Tcl_SetResult(interp, pw->pw_dir, TCL_VOLATILE);
        return TCL_OK;
    } else if (strcmp(field, "shell") == 0) {
        Tcl_SetResult(interp, pw->pw_shell, TCL_VOLATILE);
        return TCL_OK;
#ifdef __APPLE__
    } else if (strcmp(field, "change") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewLongObj(pw->pw_change));
        return TCL_OK;
    } else if (strcmp(field, "class") == 0) {
        Tcl_SetResult(interp, pw->pw_class, TCL_VOLATILE);
        return TCL_OK;
    } else if (strcmp(field, "expire") == 0) {
        Tcl_SetObjResult(interp, Tcl_NewLongObj(pw->pw_expire));
        return TCL_OK;
#endif
    }

    result = Tcl_NewStringObj("invalid field ", -1);
    Tcl_AppendObjToObj(result, Tcl_NewStringObj(field, -1));
    Tcl_SetObjResult(interp, result);
    return TCL_ERROR;
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
