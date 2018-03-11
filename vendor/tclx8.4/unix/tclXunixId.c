/*
 * tclXunixId.c --
 *
 * Tcl commands to access getuid, setuid, getgid, setgid and friends on Unix.
 *-----------------------------------------------------------------------------
 * Copyright 1991-1999 Karl Lehenbauer and Mark Diekhans.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies.  Karl Lehenbauer and
 * Mark Diekhans make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *-----------------------------------------------------------------------------
 * $Id: tclXunixId.c,v 8.1 2001/10/24 23:31:50 hobbs Exp $
 *-----------------------------------------------------------------------------
 */

#include "tclExtdInt.h"

/*
 * Actually configured number of groups (from sysconf if we have it).
 */
#ifndef NO_SYSCONF
static int confNGroups = -1;
#else
#ifndef NGROUPS
#   ifdef NGROUPS_MAX
#       define NGROUPS NGROUPS_MAX
#   else
#       define NGROUPS 32
#   endif
#endif
static int confNGroups = NGROUPS;
#endif

/*
 * Prototypes of internal functions.
 */
static int
UseridToUsernameResult _ANSI_ARGS_((Tcl_Interp *interp,
                                    int         userId));

static int
UsernameToUseridResult _ANSI_ARGS_((Tcl_Interp *interp,
                                    char       *userName));

static int
GroupidToGroupnameResult _ANSI_ARGS_((Tcl_Interp *interp,
                                      int         groupId));

static int
GroupnameToGroupidResult _ANSI_ARGS_((Tcl_Interp *interp,
                                      char       *groupName));

static int
IdConvert _ANSI_ARGS_((Tcl_Interp *interp,
                       int         objc,
                       Tcl_Obj   *CONST objv[]));

static int
IdEffective  _ANSI_ARGS_((Tcl_Interp  *interp,
                          int          objc,
                          Tcl_Obj      *CONST objv[]));

static int
IdProcess  _ANSI_ARGS_((Tcl_Interp    *interp,
                        int            objc,
                        Tcl_Obj      *CONST objv[]));

static int
IdGroupids  _ANSI_ARGS_((Tcl_Interp    *interp,
                         int            objc,
                         Tcl_Obj      *CONST objv[],
                         int         symbolic));

static int
IdHost _ANSI_ARGS_((Tcl_Interp    *interp,
                    int            objc,
                    Tcl_Obj      *CONST objv[]));

static int
GetSetWrongArgs _ANSI_ARGS_((Tcl_Interp    *interp,
                             Tcl_Obj      *CONST objv[]));

static int
IdUser _ANSI_ARGS_((Tcl_Interp    *interp,
                    int            objc,
                    Tcl_Obj      *CONST objv[]));

static int
IdUserId _ANSI_ARGS_((Tcl_Interp    *interp,
                      int            objc,
                      Tcl_Obj      *CONST objv[]));

static int
IdGroup _ANSI_ARGS_((Tcl_Interp    *interp,
                     int            objc,
                     Tcl_Obj      *CONST objv[]));

static int
IdGroupId _ANSI_ARGS_((Tcl_Interp    *interp,
                       int            objc,
                       Tcl_Obj      *CONST objv[]));

static int 
TclX_IdObjCmd _ANSI_ARGS_((ClientData clientData,
                           Tcl_Interp *interp,
                           int objc,
                           Tcl_Obj *CONST objv[]));

/*-----------------------------------------------------------------------------
 * TclX_IdObjCmd --
 *     Implements the TclX id command on Unix.
 *
 *        id user ?name?
 *        id convert user <name>
 *
 *        id userid ?uid?
 *        id convert userid <uid>
 *
 *        id group ?name?
 *        id convert group <name>
 *
 *        id groupid ?gid?
 *        id convert groupid <gid>
 *
 *        id groupids
 *
 *        id host
 *
 *        id process
 *        id process parent
 *        id process group
 *        id process group set
 *
 *        id effective user
 *        id effective userid
 *
 *        id effective group
 *        id effective groupid
 *
 * Results:
 *  Standard TCL results, may return the UNIX system error message.
 *
 *-----------------------------------------------------------------------------
 */

static int
UseridToUsernameResult (interp, userId)
    Tcl_Interp *interp;
    int         userId;
{
    uid_t          uid = (uid_t) userId;
    struct passwd *pw = getpwuid (userId);
    Tcl_Obj       *resultObj = Tcl_GetObjResult (interp);
    char          userIdString[16];

    if ((pw == NULL) || ((int) uid != userId)) {
	sprintf (userIdString, "%d", uid);
	Tcl_AppendStringsToObj (resultObj, 
	    "unknown user id: ", 
	    userIdString,
	    NULL);
        endpwent ();
        return TCL_ERROR;
    }
    Tcl_AppendToObj (resultObj, pw->pw_name, -1);
    endpwent ();
    return TCL_OK;
}

static int
UsernameToUseridResult (interp, userName)
    Tcl_Interp *interp;
    char       *userName;
{
    struct passwd *pw = getpwnam (userName);
    Tcl_Obj       *resultObj = Tcl_GetObjResult (interp);

    if (pw == NULL) {
	Tcl_AppendStringsToObj (resultObj,
				"unknown user id: ", 
				userName, 
				 (char *) NULL);
        endpwent ();
        return TCL_ERROR;
    }
    Tcl_SetObjResult (interp, Tcl_NewIntObj (pw->pw_uid));
    endpwent ();
    return TCL_OK;
}

static int
GroupidToGroupnameResult (interp, groupId)
    Tcl_Interp *interp;
    int         groupId;
{
    gid_t          gid = (gid_t) groupId;
    struct group  *grp = getgrgid (groupId);
    Tcl_Obj       *resultObj = Tcl_GetObjResult (interp);
    char          groupIdString[16];

    sprintf (groupIdString, "%d", gid);

    if ((grp == NULL) || ((int) gid != groupId)) {
	Tcl_AppendStringsToObj (resultObj, 
				"unknown group id: ", 
				groupIdString,
				(char *)NULL);
        endgrent ();
        return TCL_ERROR;
    }
    Tcl_AppendToObj (resultObj, grp->gr_name, -1);
    endgrent ();
    return TCL_OK;
}

static int
GroupnameToGroupidResult (interp, groupName)
    Tcl_Interp *interp;
    char       *groupName;
{
    struct group  *grp = getgrnam (groupName);
    Tcl_Obj       *resultObj = Tcl_GetObjResult (interp);
    if (grp == NULL) {
        Tcl_AppendStringsToObj (resultObj, 
				"unknown group id: ",
				groupName,
				(char *) NULL);
        return TCL_ERROR;
    }
    Tcl_SetIntObj (resultObj, grp->gr_gid);
    return TCL_OK;
}

/*
 * id convert type value
 */
static int
IdConvert (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    long           uid;
    long           gid;
    char          *subCommand;
    char          *valueString;

    if (objc != 4)
        return TclX_WrongArgs (interp, objv [0], "convert type value");

    subCommand = Tcl_GetStringFromObj (objv[2], NULL);
    valueString = Tcl_GetStringFromObj (objv[3], NULL);

    if (STREQU (subCommand, "user"))
        return UsernameToUseridResult (interp, valueString);
    
    if (STREQU (subCommand, "userid")) {
        if (Tcl_GetLongFromObj (interp, objv[3], &uid) != TCL_OK) 
            return TCL_ERROR;
        return UseridToUsernameResult (interp, uid);
    }
    
    if (STREQU (subCommand, "group"))
        return GroupnameToGroupidResult (interp, valueString);
    
    if (STREQU (subCommand, "groupid")) {
        if (Tcl_GetLongFromObj (interp, objv[3], &gid) != TCL_OK)
            return TCL_ERROR;
        return GroupidToGroupnameResult (interp, gid);
        
    }
    TclX_AppendObjResult (interp, "third arg must be \"user\", \"userid\", ",
                          "\"group\" or \"groupid\", got \"", subCommand, "\"",
                          (char *) NULL);
    return TCL_ERROR;
}

/*
 * id effective type
 */
static int
IdEffective (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    char          *subCommand;

    if (objc != 3)
        return TclX_WrongArgs (interp, objv [0], "effective type");
    
    subCommand = Tcl_GetStringFromObj (objv[2], NULL);

    if (STREQU (subCommand, "user"))
        return UseridToUsernameResult (interp, geteuid ());
    
    if (STREQU (subCommand, "userid")) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (geteuid ()));
        return TCL_OK;
    }
    
    if (STREQU (subCommand, "group"))
        return GroupidToGroupnameResult (interp, getegid ());
    
    if (STREQU (subCommand, "groupid")) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (getegid ()));
        return TCL_OK;
    }

    TclX_AppendObjResult (interp, "third arg must be \"user\", \"userid\", ",
                          "\"group\" or \"groupid\", got \"", 
                          subCommand, "\"", (char *) NULL);
    return TCL_ERROR;
}

/*
 * id process ?parent|group? ?set?
 */
static int
IdProcess (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    pid_t          pid;
    char          *subCommand;
    char          *trailerCommand;

    if (objc > 4)
        return TclX_WrongArgs (interp, 
			       objv [0], 
			       "process ?parent|group? ?set?");

    if (objc == 2) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (getpid ()));
        return TCL_OK;
    }

    subCommand = Tcl_GetStringFromObj (objv[2], NULL);

    if (STREQU (subCommand, "parent")) {
        if (objc != 3)
            return TclX_WrongArgs (interp, objv [0], 
                              " process parent");

	Tcl_SetObjResult (interp, Tcl_NewIntObj (getppid ()));
        return TCL_OK;
    }
    if (STREQU (subCommand, "group")) {
        if (objc == 3) {
	    Tcl_SetObjResult (interp, Tcl_NewIntObj (getpgrp ()));
            return TCL_OK;
        }
	trailerCommand = Tcl_GetStringFromObj (objv[3], NULL);
        if ((objc != 4) || !STREQU (trailerCommand, "set"))
            return TclX_WrongArgs (interp, objv [0], 
                              " process group ?set?");

        if (Tcl_IsSafe (interp)) {
            TclX_AppendObjResult (interp,  "can't set process group from a ",
                                  "safe interpeter", (char *) NULL);
            return TCL_ERROR;
        }
                        
#ifndef NO_SETPGID
        pid = getpid ();
        setpgid (pid, pid);
#else
        setpgrp ();
#endif
        return TCL_OK;
    }

    TclX_AppendObjResult (interp, "expected one of \"parent\" or \"group\" ",
                          "got\"", subCommand, "\"", (char *) NULL);
    return TCL_ERROR;
}

/*
 * id groupids
 * id groups
 */
static int
IdGroupids (interp, objc, objv, symbolic)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
    int            symbolic;
{
#ifndef NO_GETGROUPS
    gid_t         *groups;
    int            nGroups, groupIndex;
    struct group  *grp;
    Tcl_Obj       *resultObj = Tcl_GetObjResult (interp);
    Tcl_Obj	  *newObj;

    if (objc != 2)
        return TclX_WrongArgs (interp, objv [0], "arg");

#ifndef NO_SYSCONF
    if (confNGroups < 0)
        confNGroups = sysconf (_SC_NGROUPS_MAX);
#endif
    groups = (gid_t *) ckalloc (confNGroups * sizeof (gid_t));


    nGroups = getgroups (confNGroups, groups);
    if (nGroups < 0) {
        Tcl_AppendStringsToObj (Tcl_GetObjResult (interp),
                                Tcl_PosixError (interp), (char *) NULL);
        ckfree ((char *) groups);
        return TCL_ERROR;
    }

    for (groupIndex = 0; groupIndex < nGroups; groupIndex++) {
        if (symbolic) {
	    int    groupId = groups [groupIndex];
            grp = getgrgid (groupId);
            if (grp == NULL) {
		char    groupIdString[16];

		sprintf (groupIdString, "%d", groupId);
		Tcl_AppendStringsToObj (resultObj,
		    "unknown group id: ",
		    groupIdString,
		    (char *)NULL);
                endgrent ();
                return TCL_ERROR;
            }
	    newObj = Tcl_NewStringObj (grp->gr_name, -1);
            Tcl_ListObjAppendElement (interp, 
				      resultObj,
				      newObj);
        } else {
	    newObj = Tcl_NewIntObj(groups[groupIndex]);
            Tcl_ListObjAppendElement (interp, 
				      resultObj,
				      newObj);
        }
    }
    if (symbolic)
        endgrent ();
    ckfree ((char *) groups);
    return TCL_OK;
#else
    TclX_AppendObjResult (interp, "group id lists unavailable on this system ",
                          "(no getgroups function)", (char *) NULL);
    return TCL_ERROR;
#endif
}

/*
 * id host
 */
static int
IdHost (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
#ifndef NO_GETHOSTNAME
#ifndef MAXHOSTNAMELEN
#  define MAXHOSTNAMELEN 256
#endif
    char hostNameBuf[MAXHOSTNAMELEN];

    if (objc != 2)
        return TclX_WrongArgs (interp, objv [0], "host");

	if (gethostname (hostNameBuf, MAXHOSTNAMELEN) < 0) {
            TclX_AppendObjResult (interp, Tcl_PosixError (interp),
                                  (char *) NULL);
	    return TCL_ERROR;
	}
	hostNameBuf[MAXHOSTNAMELEN-1] = '\0';
	Tcl_SetObjResult (interp, Tcl_NewStringObj (hostNameBuf, -1));
	return TCL_OK;
#else
        TclX_AppendObjResult (interp, "host name unavailable on this system ",
                              "(no gethostname function)", (char *) NULL);
        return TCL_ERROR;
#endif
}

/*
 * Return error when a get set function has too many args (2 or 3 expected).
 */
static int
GetSetWrongArgs (interp, objv)
    Tcl_Interp    *interp;
    Tcl_Obj      *CONST objv[];
{
    return TclX_WrongArgs (interp, objv [0], "arg ?value?");
}

/*
 * id user
 */
static int
IdUser (interp, objc, objv)
    Tcl_Interp *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    struct passwd *pw;
    char          *user;

    if (objc > 3)
        return GetSetWrongArgs (interp, objv);

    if (objc == 2) {
        return UseridToUsernameResult (interp, getuid ());
    }

    user = Tcl_GetStringFromObj (objv[2], NULL);

    pw = getpwnam (user);
    if (pw == NULL) {
        TclX_AppendObjResult (interp, "user \"",user, "\" does not exist",
                              (char *) NULL);
        goto errorExit;
    }
    if (setuid (pw->pw_uid) < 0) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }
    endpwent ();
    return TCL_OK;

  errorExit:
    endpwent ();
    return TCL_ERROR;
}

/*
 * id userid
 */
static int
IdUserId (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    int uid;

    if (objc > 3)
        return GetSetWrongArgs (interp, objv);

    if (objc == 2) {
	Tcl_SetObjResult (interp, Tcl_NewIntObj (getuid()));
        return TCL_OK;
    }

    if (Tcl_GetIntFromObj (interp, objv[2], &uid) != TCL_OK)
        return TCL_ERROR;

    if (setuid ((uid_t) uid) < 0) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    return TCL_OK;
}

/*
 * id group
 */
static int
IdGroup (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    struct group *grp;
    char         *groupName;

    if (objc > 3)
        return GetSetWrongArgs (interp, objv);

    if (objc == 2) {
        return GroupidToGroupnameResult (interp, getgid ());
    }

    groupName = Tcl_GetStringFromObj (objv[2], NULL);
     
    grp = getgrnam (groupName);
    if (grp == NULL) {
        TclX_AppendObjResult (interp, "group \"", groupName,
                              "\" does not exist", (char *) NULL);
        goto errorExit;
    }
    if (setgid (grp->gr_gid) < 0) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        goto errorExit;
    }
    endgrent ();
    return TCL_OK;

  errorExit:
    endgrent ();
    return TCL_ERROR;
}

/*
 * id groupid
 */
static int
IdGroupId (interp, objc, objv)
    Tcl_Interp    *interp;
    int            objc;
    Tcl_Obj      *CONST objv[];
{
    int gid;
    
    if (objc > 3)
        return GetSetWrongArgs (interp, objv);

    if (objc == 2) {
	Tcl_SetIntObj (Tcl_GetObjResult (interp), getgid());
        return TCL_OK;
    }

    if (Tcl_GetIntFromObj (interp, objv[2], &gid) != TCL_OK)
        return TCL_ERROR;

    if (setgid ((gid_t) gid) < 0) {
        TclX_AppendObjResult (interp, Tcl_PosixError (interp), (char *) NULL);
        return TCL_ERROR;
    }

    return TCL_OK;
}

static int
TclX_IdObjCmd (clientData, interp, objc, objv)
    ClientData  clientData;
    Tcl_Interp *interp;
    int         objc;
    Tcl_Obj   *CONST objv[];
{
    char       *subCommand;

    if (objc < 2)
	return TclX_WrongArgs (interp, objv [0], "arg ?arg...?");

    subCommand = Tcl_GetStringFromObj (objv [1], NULL);
    /*
     * If the first argument is "convert", handle the conversion.
     */
    if (STREQU (subCommand, "convert")) {
        return IdConvert (interp, objc, objv);
    }

    /*
     * If the first argument is "effective", return the effective user ID,
     * name, group ID or name.
     */
    if (STREQU (subCommand, "effective")) {
        return IdEffective (interp, objc, objv);
    }

    /*
     * If the first argument is "process", return the process ID, parent's
     * process ID, process group or set the process group depending on args.
     */
    if (STREQU (subCommand, "process")) {
        return IdProcess (interp, objc, objv);
    }

    /*
     * Handle getting list of groups the user is a member of.
     */
    if (STREQU (subCommand, "groups")) {
        return IdGroupids (interp, objc, objv, TRUE);
    }

    if (STREQU (subCommand, "groupids")) {
        return IdGroupids (interp, objc, objv, FALSE);
    }

    /*
     * Handle returning the host name if its available.
     */
    if (STREQU (subCommand, "host")) {
        return IdHost (interp, objc, objv);
    }

    /*
     * Handle setting or returning the user ID or group ID (by name or number).
     */
    if (STREQU (subCommand, "user")) {
        return IdUser (interp, objc, objv);
    }

    if (STREQU (subCommand, "userid")) {
        return IdUserId (interp, objc, objv);
    }

    if (STREQU (subCommand, "group")) {
        return IdGroup (interp, objc, objv);
    }

    if (STREQU (subCommand, "groupid")) {
        return IdGroupId (interp, objc, objv);
    }

    TclX_AppendObjResult (interp, "second arg must be one of \"convert\", ",
                          "\"effective\", \"process\", ",
                          "\"user\", \"userid\", \"group\", \"groupid\", ",
                          "\"groups\", \"groupids\", ",
                          "or \"host\"", (char *) NULL);
    return TCL_ERROR;
}


/*-----------------------------------------------------------------------------
 * TclX_IdInit --
 *     Initialize the id command.
 *-----------------------------------------------------------------------------
 */
void
TclX_IdInit (interp)
    Tcl_Interp *interp;
{
    Tcl_CreateObjCommand (interp,
			  "id",
			  TclX_IdObjCmd,
                          (ClientData) NULL,
			  (Tcl_CmdDeleteProc*) NULL);
}
