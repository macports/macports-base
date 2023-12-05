/*
 * system.c
 * $Id$
 *
 * Copyright (c) 2009 The MacPorts Project
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

#include <sys/wait.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "system.h"
#include "Pextlib.h"

#if HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL "/dev/null"
#endif

#define CBUFSIZ 30

struct linebuf {
	size_t len;
	char *line;
};

int SystemCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *buf;
	struct linebuf circbuf[CBUFSIZ];
	size_t linelen;
	char *args[4];
	char *cmdstring;
	FILE *pdes;
	int fdset[2], nullfd;
	int fline, pos, ret;
	int osetsid = 0;
	pid_t pid;
	Tcl_Obj *errbuf;
	Tcl_Obj *tcl_result;
	int read_failed, status;

	/* usage: system [-notty] command */
	if (objc == 2) {
		cmdstring = Tcl_GetString(objv[1]);
	} else if (objc == 3) {
		char *arg = Tcl_GetString(objv[1]);
		cmdstring = Tcl_GetString(objv[2]);

		if (strcmp(arg, "-notty") == 0) {
			osetsid = 1;
		} else {
			tcl_result = Tcl_NewStringObj("bad option ", -1);
			Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(arg, -1));
			Tcl_SetObjResult(interp, tcl_result);
			return TCL_ERROR;
		}
	} else {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		return TCL_ERROR;
	}

	/*
	 * Fork a child to run the command, in a popen() like fashion -
	 * popen() itself is not used because stderr is also desired.
	 */
	if (pipe(fdset) != 0) {
		return TCL_ERROR;
	}

	pid = fork();
	switch (pid) {
	case -1: /* error */
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
		/* XXX ugly string constants */
		args[0] = "sh";
		args[1] = "-c";
		args[2] = cmdstring;
		args[3] = NULL;
		execve("/bin/sh", args, environ);
		_exit(1);
		break;
	default: /* parent */
		break;
	}

	close(fdset[1]);

	/* read from simulated popen() pipe */
	read_failed = 0;
	pos = 0;
	bzero(circbuf, sizeof(circbuf));
	pdes = fdopen(fdset[0], "r");
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

	status = TCL_ERROR;

	if (wait(&ret) == pid && WIFEXITED(ret) && !read_failed) {
		/* Normal exit, and reading from the pipe didn't fail. */
		if (WEXITSTATUS(ret) == 0) {
			status = TCL_OK;
		} else {
			/* Copy the contents of the circular buffer to errbuf */
		  	Tcl_Obj* errorCode;
			errbuf = Tcl_NewStringObj(NULL, 0);
			for (fline = pos; pos < fline + CBUFSIZ; pos++) {
				if (circbuf[pos % CBUFSIZ].len == 0)
				continue; /* skip empty lines */

				/* Append line, minus trailing NULL */
				Tcl_AppendToObj(errbuf, circbuf[pos % CBUFSIZ].line,
						circbuf[pos % CBUFSIZ].len - 1);

				/* Re-add previously stripped newline */
				Tcl_AppendToObj(errbuf, "\n", 1);
			}

			/* set errorCode [list CHILDSTATUS <pid> <code>] */
			errorCode = Tcl_NewListObj(0, NULL);
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewStringObj("CHILDSTATUS", -1));
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(pid));
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(WEXITSTATUS(ret)));
			Tcl_SetObjErrorCode(interp, errorCode);

			/* set result */
			tcl_result = Tcl_NewStringObj("shell command \"", -1);
			Tcl_AppendToObj(tcl_result, cmdstring, -1);
			Tcl_AppendToObj(tcl_result, "\" returned error ", -1);
			Tcl_AppendObjToObj(tcl_result, Tcl_NewIntObj(WEXITSTATUS(ret)));
			Tcl_AppendToObj(tcl_result, "\nCommand output: ", -1);
			Tcl_AppendObjToObj(tcl_result, errbuf);
			Tcl_SetObjResult(interp, tcl_result);
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
