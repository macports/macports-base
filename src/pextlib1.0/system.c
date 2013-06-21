/* vim: set et sw=4 ts=4 sts=4: */
/*
 * system.c
 * $Id$
 *
 * Copyright (c) 2002 - 2003 Apple, Inc.
 * Copyright (c) 2008 - 2010, 2012 The MacPorts Project
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
 * 3. Neither the name of The MacPorts Project nor the names of its contributors
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

#include <tcl.h>

#if HAVE_PATHS_H
#include <paths.h>
#endif

#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>

#include "system.h"
#include "Pextlib.h"

#if HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

#if !HAVE_FGETLN
char *fgetln(FILE *stream, size_t *len);
#endif

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL "/dev/null"
#endif

#define CBUFSIZ 30

struct linebuf {
    size_t len;
    char *line;
};

static int check_sandboxing(Tcl_Interp *interp, char **sandbox_exec_path, char **profilestr)
{
    Tcl_Obj *tcl_result;
    int active;
    int len;

    tcl_result = Tcl_GetVar2Ex(interp, "portsandbox_active", NULL, TCL_GLOBAL_ONLY);
    if (!tcl_result || Tcl_GetBooleanFromObj(interp, tcl_result, &active) != TCL_OK || !active) {
        return 0;
    }

    tcl_result = Tcl_GetVar2Ex(interp, "portutil::autoconf::sandbox_exec_path", NULL, TCL_GLOBAL_ONLY);
    if (!tcl_result || !(*sandbox_exec_path = Tcl_GetString(tcl_result))) {
        return 0;
    }

    tcl_result = Tcl_GetVar2Ex(interp, "portsandbox_profile", NULL, TCL_GLOBAL_ONLY);
    if (!tcl_result || !(*profilestr = Tcl_GetStringFromObj(tcl_result, &len)) 
        || len == 0) {
        return 0;
    }

    return 1;
}

/* usage: system ?-notty? ?-nice value? ?-W path? command */
int SystemCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    char *buf;
    struct linebuf circbuf[CBUFSIZ];
    size_t linelen;
    char *args[7];
    char *cmdstring;
    int sandbox = 0;
    char *sandbox_exec_path;
    char *profilestr;
    FILE *pdes;
    int fdset[2], nullfd;
    int fline, pos, ret;
    int osetsid = 0;
    int oniceval = INT_MAX; /* magic value indicating no change */
    const char *path = NULL;
    pid_t pid;
    uid_t euid;
    Tcl_Obj *tcl_result;
    int read_failed, status;
    int i;

    if (objc < 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?-notty? ?-nice value? ?-W path? command");
        return TCL_ERROR;
    }

    cmdstring = Tcl_GetString(objv[objc - 1]);

    for (i = 1; i < objc - 1; i++) {
        char *arg = Tcl_GetString(objv[i]);
        if (strcmp(arg, "-notty") == 0) {
            osetsid = 1;
        } else if (strcmp(arg, "-nice") == 0) {
            i++;
            if (Tcl_GetIntFromObj(interp, objv[i], &oniceval) != TCL_OK) {
                Tcl_SetResult(interp, "invalid value for -nice", TCL_STATIC);
                return TCL_ERROR;
            }
        } else if (strcmp(arg, "-W") == 0) {
            i++;
            if ((path = Tcl_GetString(objv[i])) == NULL) {
                Tcl_SetResult(interp, "invalid value for -W", TCL_STATIC);
                return TCL_ERROR;
            }
        } else {
            tcl_result = Tcl_NewStringObj("bad option ", -1);
            Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(arg, -1));
            Tcl_SetObjResult(interp, tcl_result);
            return TCL_ERROR;
        }
    }

    /* check if and how we should use sandbox-exec */
    sandbox = check_sandboxing(interp, &sandbox_exec_path, &profilestr);

    /*
     * Fork a child to run the command, in a popen() like fashion -
     * popen() itself is not used because stderr is also desired.
     */
    if (pipe(fdset) != 0) {
        Tcl_SetResult(interp, strerror(errno), TCL_STATIC);
        return TCL_ERROR;
    }

    pid = fork();
    switch (pid) {
    case -1: /* error */
        Tcl_SetResult(interp, strerror(errno), TCL_STATIC);
        return TCL_ERROR;
        break;
    case 0: /* child */
        close(fdset[0]);

        if ((nullfd = open(_PATH_DEVNULL, O_RDONLY)) == -1)
            _exit(1);
        dup2(nullfd, STDIN_FILENO);
        dup2(fdset[1], STDOUT_FILENO);
        dup2(fdset[1], STDERR_FILENO);
        /* drop the controlling terminal if requested */
        if (osetsid) {
            if (setsid() == -1)
                _exit(1);
        }
        /* change scheduling priority if requested */
        if (oniceval != INT_MAX) {
            if (setpriority(PRIO_PROCESS, getpid(), oniceval) != 0) {
                /* ignore failure, just continue */
            }
        }
        /* drop privileges entirely for child */
        if (getuid() == 0 && (euid = geteuid()) != 0) {
            gid_t egid = getegid();
            if (seteuid(0) || setgid(egid) || setuid(euid)) {
                _exit(1);
            }
        }

        if (path != NULL) {
            if (chdir(path) == -1) {
                printf("chdir: %s: %s\n", path, strerror(errno));
                exit(1);
            }
        }

        /* XXX ugly string constants */
        if (sandbox) {
            args[0] = "sandbox-exec";
            args[1] = "-p";
            args[2] = profilestr;
            args[3] = "sh";
            args[4] = "-c";
            args[5] = cmdstring;
            args[6] = NULL;
            execve(sandbox_exec_path, args, environ);
        } else {
            args[0] = "sh";
            args[1] = "-c";
            args[2] = cmdstring;
            args[3] = NULL;
            execve("/bin/sh", args, environ);
        }
        _exit(1);
        break;
    default: /* parent */
        break;
    }

    close(fdset[1]);

    /* read from simulated popen() pipe */
    read_failed = 0;
    pos = 0;
    memset(circbuf, 0, sizeof(circbuf));
    pdes = fdopen(fdset[0], "r");
    if (pdes) {
        while ((buf = fgetln(pdes, &linelen)) != NULL) {
            char *sbuf;
            int slen;
    
            /*
             * Allocate enough space to insert a terminating
             * '\0' if the line is not terminated with a '\n'
             */
            if (buf[linelen - 1] == '\n')
                slen = linelen;
            else
                slen = linelen + 1;
    
            if (circbuf[pos].len == 0)
                sbuf = malloc(slen);
            else {
                sbuf = realloc(circbuf[pos].line, slen);
            }
    
            if (sbuf == NULL) {
                read_failed = 1;
                break;
            }
    
            memcpy(sbuf, buf, linelen);
            /* terminate line with '\0',replacing '\n' if it exists */
            sbuf[slen - 1] = '\0';
    
            circbuf[pos].line = sbuf;
            circbuf[pos].len = slen;
    
            if (pos++ == CBUFSIZ - 1) {
                pos = 0;
            }
    
            if (ui_info(interp, sbuf) != TCL_OK) {
                read_failed = 1;
                break;
            }
        }
        fclose(pdes);
    } else {
        read_failed = 1;
        Tcl_SetResult(interp, strerror(errno), TCL_STATIC);
    }

    status = TCL_ERROR;

    if (wait(&ret) == pid && WIFEXITED(ret) && !read_failed) {
        /* Normal exit, and reading from the pipe didn't fail. */
        if (WEXITSTATUS(ret) == 0) {
            status = TCL_OK;
        } else {
            char *errorstr;
            size_t errorstrlen;
            Tcl_Obj* errorCode;

            /* print error */
            /* get buffer large enough for additional message or the error code */
            errorstrlen = strlen(cmdstring) + strlen("Command failed: ") + 12;
            errorstr = malloc(errorstrlen);
            if (errorstr) {
                snprintf(errorstr, errorstrlen, "Command failed: %s", cmdstring);
                ui_info(interp, errorstr);
                snprintf(errorstr, errorstrlen, "Exit code: %d", WEXITSTATUS(ret));
                ui_info(interp, errorstr);
                free(errorstr);
            }

            /* set errorCode [list CHILDSTATUS <pid> <code>] */
            errorCode = Tcl_NewListObj(0, NULL);
            Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewStringObj("CHILDSTATUS", -1));
            Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(pid));
            Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(WEXITSTATUS(ret)));
            Tcl_SetObjErrorCode(interp, errorCode);

            Tcl_SetObjResult(interp, Tcl_NewStringObj("command execution failed", -1));
        }
    }

    /* Cleanup. */
    close(fdset[0]);
    for (fline = 0; fline < CBUFSIZ; fline++) {
        if (circbuf[fline].len != 0) {
            free(circbuf[fline].line);
        }
    }

    return status;
}
