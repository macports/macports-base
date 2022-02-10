/*
 * Pextlib.c
 *
 * Copyright (c) 2002-2003 Apple Inc.
 * Copyright (c) 2004-2005 Paul Guyot <pguyot@kallisys.net>
 * Copyright (c) 2004 Landon Fuller <landonf@macports.org>
 * Copyright (c) 2007-2018 The MacPorts Project
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifndef __APPLE__
/* required for strdup(3) on Linux */
#define _XOPEN_SOURCE 600L
/* required for clearenv(3)/setenv(3)/unsetenv(3) on Linux */
#define _BSD_SOURCE
/* required for vasprintf(3) on Linux */
#define _GNU_SOURCE
#endif
/* required for clearenv(3)/setenv(3)/unsetenv(3) on macOS */
#define _DARWIN_C_SOURCE

#include <sys/resource.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <limits.h>
#include <netdb.h>
#include <pwd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <assert.h>

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
#include "adv-flock.h"
#include "system.h"
#include "mktemp.h"
#include "realpath.h"

#if HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

#ifndef HAVE_SETMODE
#include "setmode.h"
#endif

__attribute__((format(printf, 3, 0)))
static void ui_message(Tcl_Interp *interp, const char *severity, const char *format, va_list va) {
    char *tclcmd;
    char *buf;

    if (vasprintf(&buf, format, va) < 0) {
        perror("vasprintf");
        return;
    }
    if (asprintf(&tclcmd, "ui_%s $warn", severity) < 0) {
        perror("asprintf");
        free(buf);
        return;
    }

    Tcl_SetVar(interp, "warn", buf, 0);
    if (TCL_OK != Tcl_EvalEx(interp, tclcmd, -1, 0)) {
        fprintf(stderr, "Error evaluating Tcl statement '%s': %s (message: '%s')\n", tclcmd, Tcl_GetStringResult(interp), buf);
    }
    Tcl_UnsetVar(interp, "warn", 0);
    free(buf);
    free(tclcmd);
}

__attribute__((format(printf, 2, 3)))
void ui_error(Tcl_Interp *interp, const char *format, ...) {
    va_list va;
    va_start(va, format);
    ui_message(interp, "error", format, va);
    va_end(va);
}

__attribute__((format(printf, 2, 3)))
void ui_warn(Tcl_Interp *interp, const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_message(interp, "warn", format, va);
    va_end(va);
}

__attribute__((format(printf, 2, 3)))
void ui_msg(Tcl_Interp *interp, const char *format, ...) {
    va_list va;
    va_start(va, format);
    ui_message(interp, "msg", format, va);
    va_end(va);
}

__attribute__((format(printf, 2, 3)))
void ui_notice(Tcl_Interp *interp, const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_message(interp, "notice", format, va);
    va_end(va);
}

__attribute__((format(printf, 2, 3)))
void ui_info(Tcl_Interp *interp, const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_message(interp, "info", format, va);
    va_end(va);
}

__attribute__((format(printf, 2, 3)))
void ui_debug(Tcl_Interp *interp, const char *format, ...) {
    va_list va;

    va_start(va, format);
    ui_message(interp, "debug", format, va);
    va_end(va);
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
    const char *user;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "user");
        return TCL_ERROR;
    }

    user = Tcl_GetString(objv[1]);
    if (isdigit(*user)) {
        pwent = getpwuid((uid_t) strtol(user, 0, 0));
    } else {
        pwent = getpwnam(user);
    }

    if (pwent == NULL) {
        tcl_result = Tcl_NewIntObj(-1);
    } else {
        tcl_result = Tcl_NewIntObj(pwent->pw_uid);
    }

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

int ExistsgroupCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    Tcl_Obj *tcl_result;
    struct group *grent;
    const char *group;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "groupname");
        return TCL_ERROR;
    }

    group = Tcl_GetString(objv[1]);
    if (isdigit(*group)) {
        grent = getgrgid((gid_t) strtol(group, 0, 0));
    } else {
        grent = getgrnam(group);
    }

    if (grent == NULL) {
        tcl_result = Tcl_NewIntObj(-1);
    } else {
        tcl_result = Tcl_NewIntObj(grent->gr_gid);
    }

    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

/* Find the first unused UID > 500
   UIDs > 500 are visible on the macOS login screen,
   but UIDs < 500 are reserved by Apple */
int NextuidCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
    Tcl_Obj *tcl_result;
    int cur;

    cur = MIN_USABLE_UID;

    while (getpwuid((uid_t)cur) != NULL) {
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

    while (getgrgid((gid_t)cur) != NULL) {
        cur++;
    }

    tcl_result = Tcl_NewIntObj(cur);
    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

int UmaskCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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
        Tcl_Obj *tclList = Tcl_NewListObj( 0, NULL );
        Tcl_IncrRefCount( tclList );
        /* unset all current environment variables */
        for (char **envp = environ; *envp != NULL; envp++) {
            char *equals = strchr(*envp, '=');
            if (equals != NULL) {
				size_t len = (size_t)(equals - *envp);
                Tcl_ListObjAppendElement(interp, tclList, Tcl_NewStringObj(*envp, len));
            }
        }

		int listLength;
		Tcl_Obj **listArray;
        Tcl_ListObjGetElements(interp, tclList, &listLength, &listArray);
        for (int loopCounter = 0; loopCounter < listLength; loopCounter++) {
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

/* Check if the configured DNS server(s) incorrectly return a result for
   a nonexistent hostname. Returns true if broken, false if OK. */
int CheckBrokenDNSCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
    static int already_checked = 0;
    Tcl_Obj *tcl_result;
    int broken = 0;
    struct addrinfo *res = NULL;
    int error;

    /* Only do the actual test once per run. */
    if (!already_checked) {
        error = getaddrinfo("invalid-host.macports.org", NULL, NULL, &res);
        if (!error) {
            broken = 1;
        }
        if (res) {
            freeaddrinfo(res);
        }
    
        already_checked = 1;
    }

    tcl_result = Tcl_NewBooleanObj(broken);
    Tcl_SetObjResult(interp, tcl_result);
    return TCL_OK;
}

/*
	set_max_open_files

	synopsis: set_max_open_files

	raises the limit of open files to the maximum
*/
int SetMaxOpenFilesCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc UNUSED, Tcl_Obj *CONST objv[] UNUSED)
{
	struct rlimit rl;

    if (getrlimit(RLIMIT_NOFILE, &rl) == -1) {
        Tcl_SetErrno(errno);
        Tcl_ResetResult(interp);
        Tcl_AppendResult(interp, "set_max_open_files: getrlimit failed: ", (char *)Tcl_PosixError(interp), NULL);
        return TCL_ERROR;
    } else {
#ifdef OPEN_MAX
        if (rl.rlim_max > OPEN_MAX) {
            rl.rlim_max = OPEN_MAX;
        }
#endif
        rl.rlim_cur = rl.rlim_max;
        if (setrlimit(RLIMIT_NOFILE, &rl) == -1) {
            Tcl_SetErrno(errno);
            Tcl_ResetResult(interp);
            Tcl_AppendResult(interp, "set_max_open_files: setrlimit failed: ", (char *)Tcl_PosixError(interp), NULL);
            return TCL_ERROR;
        }
    }

	return TCL_OK;
}

/* Mount point file system case-sensitivity caching infrastructure. */
typedef struct _mount_cs_cache_entry {
    char *mountpoint;
    int case_sensitive;
} mount_cs_cache_entry_t, *mount_cs_cache_entry_list_t;

struct _mount_cs_cache {
    size_t count;
    mount_cs_cache_entry_t **entries;
};

/**
 * Returns a new pre-allocated mount_cs_cache_t object.
 */
mount_cs_cache_t* new_mount_cs_cache(void) {
    mount_cs_cache_t *ret = malloc(sizeof(mount_cs_cache_t));

    if (ret) {
        ret->count = 0;
        ret->entries = NULL;
    }

    return ret;
}

/**
 * Resets a mount cache object.
 */
void reset_mount_cs_cache(mount_cs_cache_t *cache) {
    if (cache) {
        /*
         * Assume that if the count of cached entries is zero,
         * the entries handle is set to NULL as well. Likewise,
         * if the count is non-zero, the entries pointer should
         * be non-NULL. Any other combination probably means
         * something is very, very wrong.
         */
        assert((!cache->count && !cache->entries) || (cache->count && cache->entries));

        for (size_t i = 0; i < cache->count; ++i) {
            free(cache->entries[i]->mountpoint);
            cache->entries[i]->mountpoint = NULL;

            free(cache->entries[i]);
            cache->entries[i] = NULL;
        }

        free(cache->entries);
        cache->entries = NULL;
    }
}

/**
 * Rollback mount cache object.
 */
static void rollback_mount_cs_cache(Tcl_Interp *interp, mount_cs_cache_t *cache) {
    if (cache) {
        mount_cs_cache_entry_t **rollback_data = realloc(cache->entries, (cache->count) * sizeof(mount_cs_cache_entry_list_t));

        if (!rollback_data) {
            ui_info(interp, "pextlib: unable to roll changes to FS cache back.");
            cache->entries[cache->count++] = NULL;
        }
        else {
            cache->entries = rollback_data;
        }
    }
}

/**
 * Adds a new entry to a mount cache object.
 * Returns zero on success, -1 on failure.
 */
static int add_to_mount_cs_cache(Tcl_Interp *interp, mount_cs_cache_t *cache, const char *mountpoint, int case_sensitive) {
    int ret = -1;

    if ((cache) && (mountpoint)) {
        /*
         * Go the greedy road and resize as needed. Good enough probably, since
         * systems normally don't have a huge amount of mounts to start with.
         */
        mount_cs_cache_entry_t **new_data = realloc(cache->entries, (cache->count + 1) * sizeof(mount_cs_cache_entry_list_t));

        if (!new_data) {
            ui_info(interp, "pextlib: unable to reallocate FS cache entries list, leaving untouched.");
            return ret;
        }

        cache->entries = new_data;

        mount_cs_cache_entry_t *new_entry = malloc(sizeof(mount_cs_cache_entry_t));

        if (!new_entry) {
            ui_info(interp, "pextlib: unable to create new FS cache entry, leaving untouched and rolling back.");

            rollback_mount_cs_cache(interp, cache);

            return ret;
        }

        new_entry->mountpoint = strdup(mountpoint);

        if (!new_entry->mountpoint) {
            ui_info(interp, "pextlib: unable to copy mountpoint value to new FS cache entry, leaving untouched and rolling back.");

            rollback_mount_cs_cache(interp, cache);

            free(new_entry);

            return ret;
        }

        new_entry->case_sensitive = case_sensitive;

        cache->entries[cache->count++] = new_entry;

        ret = 0;
    }

    return ret;
}

/**
 * Looks up a cached mountpoint case-sensitivity value.
 *
 * Returns 1 if the mountpoint's FS is case-sensitive,
 * 0 if it's case-insensitive and -1 on error or if
 * no such entry was found.
 */
static int lookup_mount_cs_cache(mount_cs_cache_t *cache, const char *mountpoint) {
    int ret = -1;

    /* No specified mount point doesn't make sense, so assert it. */
    assert(mountpoint);

    if (cache && mountpoint) {
        for (size_t i = 0; i < cache->count; ++i) {
            if ((cache->entries[i]) && (cache->entries[i]->mountpoint)) {
                if (0 == strcmp(cache->entries[i]->mountpoint, mountpoint)) {
                    return cache->entries[i]->case_sensitive;
                }
            }
        }
    }

    return ret;
}


/**
 * Gets the corresponding mount point for a file.
 * Returns NULL if looking up the mount point was not possible.
 */
static char* get_mntpoint(const char *path) {
    char *ret = NULL;

#if defined(__APPLE__) || defined(__OpenBSD__) || defined(__FreeBSD__) || defined(__NetBSD__)
    struct statfs f;

    if (-1 != statfs(path, &f)) {
        ret = strdup(f.f_mntonname);
    }
#else
    /*
     * Systems like Solaris, IRIX, True64, AIX and others have no way to get this information easily.
     *
     * Neither does Linux. We could go ahead and try to "compute" the mount point
     * using a series of stat calls and the like, but it doesn't make any sense.
     * Running our three lstat() calls should be less resource hungry than getting
     * the mount point on this system, so disable caching there as well.
     */
    ret = NULL;
#endif

    return ret;
}

#ifdef __APPLE__

#include <sys/attr.h>

typedef struct volcaps {
      u_int32_t size;
      vol_capabilities_attr_t volcaps;
} volcaps_t;

/**
 * Default function for determining the FS case sensitivity on Darwin.
 * Using getattrlist().
 */
int fs_case_sensitive_darwin(Tcl_Interp *interp, const char *path, mount_cs_cache_t *cache) {
    int ret = -1;

    if (!path) {
        return ret;
    }

    char *mntpoint = get_mntpoint(path);

    if (!mntpoint) {
        return ret;
    }

    if (cache) {
        ret = lookup_mount_cs_cache(cache, mntpoint);

        if (-1 != ret) {
            free(mntpoint);
            return ret;
        }
    }

    struct attrlist attrlist;
    volcaps_t volcaps;

    memset(&attrlist, 0, sizeof(attrlist));
    attrlist.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrlist.volattr = ATTR_VOL_CAPABILITIES;

    if (-1 == getattrlist(mntpoint, &attrlist, &volcaps, sizeof(volcaps), 0)) {
        free(mntpoint);
        return ret;
    }

    if (-1 == ret) {
        if ((attrlist.volattr & ATTR_VOL_CAPABILITIES) == 0) {
            free(mntpoint);
            return ret;
        }

        /* In case entry is not cached, fetch value, if possible. */
        if ((volcaps.volcaps.valid[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CASE_SENSITIVE)) {
            /* capabilities bit for case-sensitivity valid */
            ret = (volcaps.volcaps.capabilities[VOL_CAPABILITIES_FORMAT] & VOL_CAP_FMT_CASE_SENSITIVE) != 0;

            /*
             * Note that we only add a new entry if the case-sensitivity value could be determined.
             * In case of errors, let the code try again - the failure might have been temporary.
             */
            add_to_mount_cs_cache(interp, cache, mntpoint, ret);
        }
    }

    free(mntpoint);
    return ret;
}

#endif /* __APPLE__ */

/**
 * Fallback function to determine FS case sensitivity.
 * lstat()'s the given path, its lowercase and uppercase versions.
 * If all three versions exist and are the same file (as determined
 * by their inode numbers), then the FS is case-insensitive and
 * 0 is returned.
 * Otherwise, the FS is case-sensitive and 1 is returned.
 * In case of errors (e.g., if the original file does not exist),
 * -1 is returned.
 */
int fs_case_sensitive_fallback(Tcl_Interp *interp, const char *path, mount_cs_cache_t *cache) {
    int ret = -1;
    char *mntpoint = NULL;

    if (!path) {
        return ret;
    }

    if (cache) {
        mntpoint = get_mntpoint(path);

        if (mntpoint) {
            ret = lookup_mount_cs_cache(cache, mntpoint);

            if (-1 != ret) {
                free(mntpoint);
                return ret;
            }
        }
    }

    char *lowercase_path = strdup(path);
    char *uppercase_path = strdup(path);

    if ((!lowercase_path) || (!uppercase_path)) {
        free(lowercase_path);
        free(uppercase_path);

        free(mntpoint);

        return ret;
    }

    for (char *tmp_ptr_low = lowercase_path,
              *tmp_ptr_up  = uppercase_path;
         *tmp_ptr_low && *tmp_ptr_up; /* Since both are copies of the same string,
                                         should be the same anyway. */
         ++tmp_ptr_low, ++tmp_ptr_up) {
        *tmp_ptr_low = tolower(*tmp_ptr_low);
        *tmp_ptr_up  = toupper(*tmp_ptr_up);
    }

    struct stat path_stat,
           lowercase_path_stat,
           uppercase_path_stat;

    if (-1 == lstat(path, &path_stat)) {
        free(lowercase_path);
        free(uppercase_path);

        free(mntpoint);

        return ret;
    }

    if ((0 == strcmp(path, lowercase_path)) &&
        (0 == strcmp(path, uppercase_path))) {
        /*
         * All three strings are equal. We can't check for
         * FS case-sensitivity in this case.
         * And it doesn't matter either way!
         */
        ret = 1;
    }
    else {
        if (-1 == lstat(lowercase_path, &lowercase_path_stat)) {
            /* Lowercased version doesn't exist, CS. */
            ret = 1;
        }
        else if (-1 == lstat(uppercase_path, &uppercase_path_stat)) {
            /* Uppercased version doesn't exist, CS. */
            ret = 1;
        }
        else {
            /*
             * All three files exists, but we must make sure they
             * are really the same file.
             */
            if (path_stat.st_ino == lowercase_path_stat.st_ino) {
                /*
                 * Lowercase and original path files are the same,
                 * but that's not too surprising since most passed
                 * values will already be in lowercased form.
                 * Also check the uppercase variant.
                 *
                 * The special case that all three versions are
                 * actually the same (can happen if a path consists
                 * of case-agnostic Unicode characters only) is
                 * already handled above.
                 */
                if (path_stat.st_ino == uppercase_path_stat.st_ino) {
                    /* Truly case-insensitive! */
                    ret = 0;
                }
                else {
                    /*
                     * Bummer, lowercased version matches the original
                     * file's inode number, but the uppercased one
                     * doesn't. CS.
                     */
                    ret = 1;
                }
            }
            else {
                /* Just similar-named, still a case-sensitive FS. */
                ret = 1;
            }
        }
    }

    if (-1 != ret) {
        /* No error if cache or mntpoint are NULL, the called function shall catch that. */
        add_to_mount_cs_cache(interp, cache, mntpoint, ret);
    }

    free(lowercase_path);
    free(uppercase_path);

    free(mntpoint);

    return ret;
}

/**
 * Determines FS case-sensitivity for a specific path.
 * Returns 1 if the FS is case-sensitive, 0 otherwise.
 * Errors out if the case-sensitivity could not be determined.
 */
int FSCaseSensitiveCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]) {
    Tcl_Obj *tcl_result;
    int ret = -1;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "path");
        return TCL_ERROR;
    }

    char *path = Tcl_GetString(objv[1]);

#ifdef __APPLE__
    ret = fs_case_sensitive_darwin(interp, path, NULL);
#endif /* __APPLE__ */

    if (-1 == ret) {
        ret = fs_case_sensitive_fallback(interp, path, NULL);
    }

    if (-1 == ret) {
        Tcl_SetResult(interp, "unable to determine FS case-sensitivity", TCL_STATIC);
        return TCL_ERROR;
    }
    else {
        tcl_result = Tcl_NewBooleanObj(ret);
        Tcl_SetObjResult(interp, tcl_result);
        return TCL_OK;
    }
}

int Pextlib_Init(Tcl_Interp *interp)
{
    if (Tcl_InitStubs(interp, "8.4", 0) == NULL)
        return TCL_ERROR;

	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "adv-flock", AdvFlockCmd, NULL, NULL);
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
	Tcl_CreateObjCommand(interp, "vercmp", VercompCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "rmd160", RMD160Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "sha256", SHA256Cmd, NULL, NULL);
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
    Tcl_CreateObjCommand(interp, "getpwuid", getpwuidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "name_to_uid", name_to_uidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "uid_to_name", uid_to_nameCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "uname_to_gid", uname_to_gidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "name_to_gid", name_to_gidCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "gid_to_name", gid_to_nameCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "tracelib", TracelibCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "isatty", IsattyCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "term_get_size", TermGetSizeCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "check_broken_dns", CheckBrokenDNSCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "set_max_open_files", SetMaxOpenFilesCmd, NULL, NULL);

    Tcl_CreateObjCommand(interp, "fs_case_sensitive", FSCaseSensitiveCmd, NULL, NULL);

    if (Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
        return TCL_ERROR;

    return TCL_OK;
}
