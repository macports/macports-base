/*
 * Pextlib.c
 * $Id$
 *
 * Copyright (c) 2002 - 2003 Apple Inc.
 * Copyright (c) 2004 - 2005 Paul Guyot <pguyot@kallisys.net>
 * Copyright (c) 2004 Landon Fuller <landonf@macports.org>
 * Copyright (c) 2012 The MacPorts Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of Apple Inc. nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <pwd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

#ifdef __MACH__
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#endif

#include <tcl.h>

#include "Pextlib.h"

#include "md5cmd.h"
#include "sha1cmd.h"
#include "rmd160cmd.h"
#include "sha256cmd.h"
#include "base32cmd.h"
#include "fs-traverse.h"
#include "filemap.h"
#include "curl.h"
#include "xinstall.h"
#include "vercomp.h"
#include "readline.h"
#include "uid.h"
#include "tracelib.h"
#include "tty.h"
#include "strsed.h"
#include "readdir.h"
#include "pipe.h"
#include "flock.h"
#include "system.h"
#include "mktemp.h"
#include "realpath.h"

#if HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

#if !HAVE_SETMODE
#include "setmode.h"
#endif

static char *
ui_escape(const char *source)
{
    char *d, *dest;
    const char *s;
    size_t dlen;

    s = source;
    dlen = strlen(source) * 2 + 1;
    d = dest = malloc(dlen);
    if (dest == NULL) {
        return NULL;
    }
    while(*s != '\0') {
        switch(*s) {
            case '\\':
            case '}':
            case '{':
                *d = '\\';
                d++;
                *d = *s;
                d++;
                s++;
                break;
            case '\n':
                s++;
                break;
            default:
                *d = *s;
                d++;
                s++;
                break;
        }
    }
    *d = '\0';
    return dest;
}

int
ui_info(Tcl_Interp *interp, char *mesg)
{
    const char ui_proc_start[] = "ui_info [subst -nocommands -novariables {";
    const char ui_proc_end[] = "}]";
    char *script, *string;
    size_t scriptlen, len, remaining;
    int rval;

    string = ui_escape(mesg);
    if (string == NULL)
        return TCL_ERROR;

    len = strlen(string);
    scriptlen = sizeof(ui_proc_start) + len + sizeof(ui_proc_end) - 1;
    script = malloc(scriptlen);
    if (script == NULL)
        return TCL_ERROR;

    memcpy(script, ui_proc_start, sizeof(ui_proc_start));
    remaining = scriptlen - sizeof(ui_proc_start);
    strncat(script, string, remaining);
    remaining -= len;
    strncat(script, ui_proc_end, remaining);
    free(string);
    rval = Tcl_EvalEx(interp, script, -1, 0);
    free(script);
    return rval;
}

int StrsedCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *pattern, *string, *res;
    int range[2];
    Tcl_Obj *tcl_result;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "string pattern");
        return TCL_ERROR;
    }

    string = Tcl_GetString(objv[1]);
    pattern = Tcl_GetString(objv[2]);
    res = strsed(string, pattern, range);
    if (!res) {
        Tcl_SetResult(interp, "strsed failed", TCL_STATIC);
        return TCL_ERROR;
    }
    tcl_result = Tcl_NewStringObj(res, -1);
    Tcl_SetObjResult(interp, tcl_result);
    free(res);
    return TCL_OK;
}

int ExistsuserCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *tcl_result;
    struct passwd *pwent;
    char *user;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "user");
        return TCL_ERROR;
    }

    user = strdup(Tcl_GetString(objv[1]));
    if (isdigit(*(user)))
        pwent = getpwuid(strtol(user, 0, 0));
    else
        pwent = getpwnam(user);
    free(user);

    if (pwent == NULL)
        tcl_result = Tcl_NewIntObj(0);
    else
        tcl_result = Tcl_NewIntObj(pwent->pw_uid);

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

int ExistsgroupCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *tcl_result;
    struct group *grent;
    char *group;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "groupname");
        return TCL_ERROR;
    }

    group = strdup(Tcl_GetString(objv[1]));
    if (isdigit(*(group)))
        grent = getgrgid(strtol(group, 0, 0));
    else
        grent = getgrnam(group);
    free(group);

    if (grent == NULL)
        tcl_result = Tcl_NewIntObj(0);
    else
        tcl_result = Tcl_NewIntObj(grent->gr_gid);

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

/* Find the first unused UID > 500
   UIDs > 500 are visible on the login screen of OS X,
   but UIDs < 500 are reserved by Apple */
int NextuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
    Tcl_Obj *tcl_result;
    int cur;

    cur = MIN_USABLE_UID;

    while (getpwuid(cur) != NULL) {
        cur++;
    }

    tcl_result = Tcl_NewIntObj(cur);
    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

/* Just as with NextuidCmd, return the first unused gid > 500 */
int NextgidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
    Tcl_Obj *tcl_result;
    int cur;

    cur = MIN_USABLE_GID;

    while (getgrgid(cur) != NULL) {
        cur++;
    }

    tcl_result = Tcl_NewIntObj(cur);
    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

int UmaskCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
    Tcl_Obj *tcl_result;
    char *tcl_mask, *p;
    const size_t stringlen = 5; /* 4 digits & \0 */
    int i;
    mode_t *set;
    mode_t newmode;
    mode_t oldmode;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "mode");
        return TCL_ERROR;
    }

    tcl_mask = Tcl_GetString(objv[1]);
    if ((set = setmode(tcl_mask)) == NULL) {
        Tcl_SetResult(interp, "Invalid umask mode", TCL_STATIC);
        return TCL_ERROR;
    }

    newmode = getmode(set, 0);
    free(set);

    oldmode = umask(newmode);

    tcl_mask = calloc(1, stringlen); /* 4 digits & \0 */
    if (!tcl_mask) {
        return TCL_ERROR;
    }

    /* Totally gross and cool */
    p = tcl_mask + stringlen - 1;
    for (i = stringlen - 1; i > 0; i--) {
        p--;
        *p = (oldmode & 7) + '0';
        oldmode >>= 3;
    }

    tcl_result = Tcl_NewStringObj(p, -1);
    free(tcl_mask);

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

/**
 * symlink value target
 * Create a symbolic link at target pointing to value
 * See symlink(2) for possible errors
 */
int CreateSymlinkCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *value, *target;

    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "value target");
        return TCL_ERROR;
    }

    value = Tcl_GetString(objv[1]);
    target = Tcl_GetString(objv[2]);

    if (symlink(value, target) != 0) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "symlink: ", target, " -> ", value, ": ", (char *)Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }
    return TCL_OK;
}

/**
 * deletes environment variable
 *
 * Syntax is:
 * unsetenv name (* for all)
 */
int UnsetEnvCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *name;
    char **envp;
    char *equals;
    size_t len;
    Tcl_Obj *tclList;
    int listLength;
    Tcl_Obj **listArray;
    int loopCounter;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "name");
        return TCL_ERROR;
    }

    name = Tcl_GetString(objv[1]);
    if (strchr(name, '=') != NULL) {
        Tcl_SetResult(interp, "only the name should be given", TCL_STATIC);
        return TCL_ERROR;
    }

    if (strcmp(name, "*") == 0) {
#ifndef HAVE_CLEARENV
        /* unset all current environment variables; it'd be best to use
           clearenv() but that is not yet standardized, instead use Tcl's
           list capability to easily build an array of strings for each
           env name, then loop through that list to unsetenv() each one */
        tclList = Tcl_NewListObj( 0, NULL );
        Tcl_IncrRefCount( tclList );
        /* unset all current environment variables */
        for (envp = environ; *envp != NULL; envp++) {
            equals = strchr(*envp, '=');
            if (equals != NULL) {
                len = equals - *envp;
                Tcl_ListObjAppendElement(interp, tclList, Tcl_NewStringObj(*envp, len));
            }
        }
        Tcl_ListObjGetElements(interp, tclList, &listLength, &listArray);
        for (loopCounter = 0; loopCounter < listLength; loopCounter++) {
            unsetenv(Tcl_GetString(listArray[loopCounter]));
        }
        Tcl_DecrRefCount( tclList );
#else
        clearenv();
#endif
#ifndef __APPLE__
        /* Crashes on Linux without this. */
        setenv("MACPORTS_DUMMY", "", 0);
        unsetenv("MACPORTS_DUMMY");
#endif
    } else {
        (void) unsetenv(name);
    }
    /* Tcl appears to become out of sync with the environment when we
       unset things, e.g. 'info exists env(CC)' will succeed where
       'puts $env(CC)' will fail since it doesn't actually exist after
       being unset here.  This forces Tcl to resync to the current state
       (don't care about the actual result, so reset it) */
    Tcl_Eval(interp, "array get env");
    Tcl_ResetResult(interp);

    return TCL_OK;
}

/**
 *
 * Tcl wrapper around lchown() to allow changing ownership of symlinks
 * ('file attributes' follows the symlink).
 *
 * Synopsis: lchown filename user ?group?
 */
int lchownCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    CONST char *path;
    long user;
    long group = -1;

    if (objc != 3 && objc != 4) {
        Tcl_WrongNumArgs(interp, 1, objv, "filename user ?group?");
        return TCL_ERROR;
    }

    path = Tcl_GetString(objv[1]);
    if (Tcl_GetLongFromObj(NULL, objv[2], &user) != TCL_OK) {
        CONST char *userString = Tcl_GetString(objv[2]);
        struct passwd *pwent = getpwnam(userString);
        if (pwent == NULL) {
            Tcl_SetResult(interp, "Unknown user given", TCL_STATIC);
            return TCL_ERROR;
        }
        user = pwent->pw_uid;
    }
    if (objc == 4) {
        if (Tcl_GetLongFromObj(NULL, objv[3], &group) != TCL_OK) {
           CONST char *groupString = Tcl_GetString(objv[3]);
           struct group *grent = getgrnam(groupString);
           if (grent == NULL) {
               Tcl_SetResult(interp, "Unknown group given", TCL_STATIC);
               return TCL_ERROR;
           }
           group = grent->gr_gid;
        }
    }
    if (lchown(path, (uid_t) user, (gid_t) group) != 0) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "lchown: ", path, ": ", (char *)Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }

    return TCL_OK;
}

#ifdef __MACH__
/**
 * Tcl function to determine whether a file given by path is binary (in terms of being Mach-O)
 * Defined on Mac-Systems only, because the necessary headers are only available there.
 *
 * Synopsis: fileIsBinary filename
 */
static int fileIsBinaryCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    const char *path;
    FILE *file;
    uint32_t magic;
    struct stat st;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "filename");
        return TCL_ERROR;
    }

    path = Tcl_GetString(objv[1]);
    if (-1 == lstat(path, &st)) {
        /* an error occured */
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "lstat(", path, "):", (char *)Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }
    if (!S_ISREG(st.st_mode)) {
        /* not a regular file, haven't seen directories which are binaries yet */
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(false));
        return TCL_OK;
    }
    if (NULL == (file = fopen(path, "r"))) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "fopen(", path, "): ", (char *)Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    }
    if (1 != fread(&magic, sizeof(uint32_t), 1, file)) {
        if (feof(file)) {
            fclose(file);
            /* file is shorter than 4 byte, probably not a binary */
            Tcl_SetObjResult(interp, Tcl_NewBooleanObj(false));
            return TCL_OK;
        }
        /* error while reading */
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "fread(&magic, 4, 1, ", path, "): ", (char *)Tcl_PosixError(interp), NULL);
        fclose(file);
        return TCL_ERROR;
    }
    if (magic == MH_MAGIC || magic == MH_MAGIC_64) {
        fclose(file);
        /* this is a mach-o file */
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(true));
        return TCL_OK;
    }
    if (magic == htonl(FAT_MAGIC)) {
        uint32_t archcount;
        /* either universal binary or java class (FAT_MAGIC == 0xcafebabe)
           see /use/share/file/magic/cafebabe for an explanation of what I'm doing here */
        if (1 != fread(&archcount, sizeof(uint32_t), 1, file)) {
            if (feof(file)) {
                fclose(file);
                /* file shorter than 8 byte, probably not a binary either */
                Tcl_SetObjResult(interp, Tcl_NewBooleanObj(false));
                return TCL_OK;
            }
            /* error while reading */
            Tcl_SetErrno(errno);
            Tcl_ResetResult(interp);
            Tcl_AppendResult(interp, "fread(&archcount, 4, 1, ", path, "): ", (char *)Tcl_PosixError(interp), NULL);
            fclose(file);
            return TCL_ERROR;
        }

        /* universal binary header is always big endian */
        archcount = ntohl(archcount);
        if (archcount > 0 && archcount < 20) {
            fclose(file);
            /* universal binary */
            Tcl_SetObjResult(interp, Tcl_NewBooleanObj(true));
            return TCL_OK;
        }

        fclose(file);
        /* probably java class */
        Tcl_SetObjResult(interp, Tcl_NewBooleanObj(false));
        return TCL_OK;
    }
    fclose(file);

    Tcl_SetObjResult(interp, Tcl_NewBooleanObj(false));
    return TCL_OK;
}
#endif

int Pextlib_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, "8.4", 0) == NULL)
        return TCL_ERROR;

	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "flock", FlockCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "readdir", ReaddirCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "strsed", StrsedCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mkstemp", MkstempCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mktemp", MktempCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mkdtemp", MkdtempCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "existsuser", ExistsuserCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "existsgroup", ExistsgroupCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "nextuid", NextuidCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "nextgid", NextgidCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "md5", MD5Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "xinstall", InstallCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "fs-traverse", FsTraverseCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "filemap", FilemapCmd, NULL, NULL);
#if 1
	/* the name "rpm-vercomp" is deprecated, use "vercmp" instead */
	Tcl_CreateObjCommand(interp, "rpm-vercomp", VercompCmd, NULL, NULL);
#endif
	Tcl_CreateObjCommand(interp, "vercmp", VercompCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "rmd160", RMD160Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "sha256", SHA256Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "base32encode", Base32EncodeCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "base32decode", Base32DecodeCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "sha1", SHA1Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "umask", UmaskCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "pipe", PipeCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "curl", CurlCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "symlink", CreateSymlinkCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "unsetenv", UnsetEnvCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "lchown", lchownCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "realpath", RealpathCmd, NULL, NULL);
#ifdef __MACH__
    Tcl_CreateObjCommand(interp, "fileIsBinary", fileIsBinaryCmd, NULL, NULL);
#endif

    Tcl_CreateObjCommand(interp, "readline", ReadlineCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "rl_history", RLHistoryCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "getuid", getuidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "geteuid", geteuidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "getgid", getgidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "getegid", getegidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "setuid", setuidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "seteuid", seteuidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "setgid", setgidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "setegid", setegidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "name_to_uid", name_to_uidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "uid_to_name", uid_to_nameCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "uname_to_gid", uname_to_gidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "name_to_gid", name_to_gidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "gid_to_name", gid_to_nameCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "tracelib", TracelibCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "isatty", IsattyCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "term_get_size", TermGetSizeCmd, NULL, NULL);

    if (Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
        return TCL_ERROR;

    return TCL_OK;
}
