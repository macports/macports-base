/*
 * Pextlib.c
 * $Id$
 *
 * Copyright (c) 2002 - 2003 Apple Computer, Inc.
 * Copyright (c) 2004 - 2005 Paul Guyot <pguyot@kallisys.net>
 * Copyright (c) 2004 Landon Fuller <landonf@macports.org>
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
 * 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include <grp.h>

#if HAVE_STRING_H
#include <string.h>
#endif

#if HAVE_STRINGS_H
#include <strings.h>
#endif

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#if HAVE_PATHS_H
#include <paths.h>
#endif

#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL   "/dev/null"
#endif

#include <pwd.h>

#if HAVE_SYS_FILE_H
#include <sys/file.h>
#endif

#if HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#if HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif

#if HAVE_FCNTL_H
#include <fcntl.h>
#endif

#if HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#if HAVE_SYS_SOCKET_H
#include <sys/socket.h>
#endif

#if HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#include <tcl.h>

#include "md5cmd.h"
#include "sha1cmd.h"
#include "rmd160cmd.h"
#include "fs-traverse.h"
#include "filemap.h"
#include "curl.h"
#include "xinstall.h"
#include "vercomp.h"
#include "compat.h"
#include "readline.h"
#include "uid.h"
#include "tracelib.h"

#if HAVE_CRT_EXTERNS_H
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char **environ;
#endif

#if !HAVE_BZERO
#if HAVE_MEMSET
#define bzero(b, len) (void)memset(b, 0x00, len)
#endif
#endif

#if !HAVE_FGETLN
char *fgetln(FILE *stream, size_t *len);
#endif

#define CBUFSIZ 30

char *ui_escape(const char *source)
{
	char *d, *dest;
	const char *s;
	int slen, dlen;

	s = source;
	slen = dlen = strlen(source) * 2 + 1;
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

int ui_info(Tcl_Interp *interp, char *mesg)
{
	const char ui_proc_start[] = "ui_info [subst -nocommands -novariables {";
	const char ui_proc_end[] = "}]";
	char *script, *string, *p;
	int scriptlen, len, rval;

	string = ui_escape(mesg);
	if (string == NULL)
		return TCL_ERROR;

	len = strlen(string);
	scriptlen = sizeof(ui_proc_start) + len + sizeof(ui_proc_end) - 1;
	script = malloc(scriptlen);
	if (script == NULL)
		return TCL_ERROR;
	else
		p = script;

	memcpy(script, ui_proc_start, sizeof(ui_proc_start));
	strcat(script, string);
	strcat(script, ui_proc_end);
	free(string);
	rval = Tcl_EvalEx(interp, script, scriptlen - 1, 0);
	free(script);
	return rval;
}

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

	if (objc != 2 && objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		return TCL_ERROR;
	}
	
	if (objc == 3) {
		char *arg = Tcl_GetString(objv[1]);
		cmdstring = Tcl_GetString(objv[2]);

		if (!strcmp(arg, "-notty")) {
			osetsid = 1;
		} else {
			tcl_result = Tcl_NewStringObj("bad option ", -1);
			Tcl_AppendObjToObj(tcl_result, Tcl_NewStringObj(arg, -1));
			Tcl_SetObjResult(interp, tcl_result);
			return TCL_ERROR;
		}
	} else {
		cmdstring = Tcl_GetString(objv[1]);
	}

	if (pipe(fdset) == -1)
		return TCL_ERROR;

	/*
	 * Fork a child to run the command, in a popen() like fashion -
	 * popen() itself is not used because stderr is also desired.
	 */
	pid = fork();
	if (pid == -1)
		return TCL_ERROR;
	if (pid == 0) {
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
	}
	close(fdset[1]);
	pdes = fdopen(fdset[0], "r");

	/* read from simulated popen() pipe */
	pos = 0;
	bzero(circbuf, sizeof(circbuf));
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
			for (fline = pos; pos < fline + CBUFSIZ; pos++) {
				if (circbuf[pos % CBUFSIZ].len != 0)
					free(circbuf[pos % CBUFSIZ].line);
			}
			return TCL_ERROR;
		}

		memcpy(sbuf, buf, linelen);
		/* terminate line with '\0',replacing '\n' if it exists */
		sbuf[slen - 1] = '\0';

		circbuf[pos].line = sbuf;
		circbuf[pos].len = slen;

		if (pos++ == CBUFSIZ - 1)
			pos = 0;
		ret = ui_info(interp, sbuf);
		if (ret != TCL_OK) {
			for (fline = pos; pos < fline + CBUFSIZ; pos++) {
				if (circbuf[pos % CBUFSIZ].len != 0)
					free(circbuf[pos % CBUFSIZ].line);
			}
			return ret;
		}
	}
	fclose(pdes);

	if (wait(&ret) != pid)
		return TCL_ERROR;
	if (WIFEXITED(ret)) {
		if (WEXITSTATUS(ret) == 0)
			return TCL_OK;
		else {
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
				free(circbuf[pos % CBUFSIZ].line);
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
			return TCL_ERROR;
		}
	} else
		return TCL_ERROR;
}

int SudoCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *buf;
	struct linebuf circbuf[CBUFSIZ];
	size_t linelen;
	char *args[4];
	char *cmdstring, *passwd;
	FILE *pdes;
	int fdset[2];
	int fline, pos, ret;
	pid_t pid;
	Tcl_Obj *errbuf;
	Tcl_Obj *tcl_result;

	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "password command");
		return TCL_ERROR;
	}
	passwd = Tcl_GetString(objv[1]);
	cmdstring = Tcl_GetString(objv[2]);

	if (pipe(fdset) == -1)
		return TCL_ERROR;

	/*
	 * Fork a child to run the command, in a popen() like fashion -
	 * popen() itself is not used because stderr is also desired.
	 */
	pid = fork();
	if (pid == -1)
		return TCL_ERROR;
	if (pid == 0) {
		dup2(fdset[0], STDIN_FILENO);
		dup2(fdset[1], STDOUT_FILENO);
		dup2(fdset[1], STDERR_FILENO);
		args[0] = "sudo";
		args[1] = "-S";
		args[2] = cmdstring;
		args[3] = NULL;
		execve("/usr/bin/sudo", args, environ);
		/* Now throw away the privs we just acquired */
		args[1] = "-k";
		args[2] = NULL;
		execve("/usr/bin/sudo", args, environ);
		_exit(1);
	} else {
		write(fdset[1], passwd, strlen(passwd));
		write(fdset[1], "\n", 1);
		close(fdset[1]);
	}
	pdes = fdopen(fdset[0], "r");

	/* read from simulated popen() pipe */
	pos = 0;
	bzero(circbuf, sizeof(circbuf));
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
			for (fline = pos; pos < fline + CBUFSIZ; pos++) {
				if (circbuf[pos % CBUFSIZ].len != 0)
					free(circbuf[pos % CBUFSIZ].line);
			}
			return TCL_ERROR;
		}

		memcpy(sbuf, buf, linelen);
		/* terminate line with '\0',replacing '\n' if it exists */
		sbuf[slen - 1] = '\0';

		circbuf[pos].line = sbuf;
		circbuf[pos].len = slen;

		if (pos++ == CBUFSIZ - 1)
			pos = 0;
		ret = ui_info(interp, sbuf);
		if (ret != TCL_OK) {
			for (fline = pos; pos < fline + CBUFSIZ; pos++) {
				if (circbuf[pos % CBUFSIZ].len != 0)
					free(circbuf[pos % CBUFSIZ].line);
			}
			return ret;
		}
	}
	fclose(pdes);

	if (wait(&ret) != pid)
		return TCL_ERROR;
	if (WIFEXITED(ret)) {
		if (WEXITSTATUS(ret) == 0)
			return TCL_OK;
		else {
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
				free(circbuf[pos % CBUFSIZ].line);
			}

			/* set errorCode [list CHILDSTATUS <pid> <code>] */
			errorCode = Tcl_NewListObj(0, NULL);
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewStringObj("CHILDSTATUS", -1));
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(pid));
			Tcl_ListObjAppendElement(interp, errorCode, Tcl_NewIntObj(WEXITSTATUS(ret)));
			Tcl_SetObjErrorCode(interp, errorCode);

			/* set result */
			tcl_result = Tcl_NewStringObj("sudo command \"", -1);
			Tcl_AppendToObj(tcl_result, cmdstring, -1);
			Tcl_AppendToObj(tcl_result, "\" returned error ", -1);
			Tcl_AppendObjToObj(tcl_result, Tcl_NewIntObj(WEXITSTATUS(ret)));
			Tcl_AppendToObj(tcl_result, "\nCommand output: ", -1);
			Tcl_AppendObjToObj(tcl_result, errbuf);
			Tcl_SetObjResult(interp, tcl_result);
			return TCL_ERROR;
		}
	} else
		return TCL_ERROR;
}

int FlockCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	static const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\", and optionally \"-noblock\"";
	int operation = 0, fd, i, ret;
	int errnoval = 0;
	int oshared = 0, oexclusive = 0, ounlock = 0, onoblock = 0;
#if defined(HAVE_LOCKF) && !defined(HAVE_FLOCK)
	off_t curpos;
#endif
	char *res;
	Tcl_Channel channel;
	ClientData handle;

	if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "channelId switches");
		return TCL_ERROR;
	}

    	if ((channel = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), NULL)) == NULL)
		return TCL_ERROR;

	if (Tcl_GetChannelHandle(channel, TCL_READABLE|TCL_WRITABLE, &handle) != TCL_OK) {
		Tcl_SetResult(interp, "error getting channel handle", TCL_STATIC);
		return TCL_ERROR;
	}
	fd = (int) handle;

	for (i = 2; i < objc; i++) {
		char *arg = Tcl_GetString(objv[i]);
		if (!strcmp(arg, "-shared")) {
		  oshared = 1;
		} else if (!strcmp(arg, "-exclusive")) {
		  oexclusive = 1;
		} else if (!strcmp(arg, "-unlock")) {
		  ounlock = 1;
		} else if (!strcmp(arg, "-noblock")) {
		  onoblock = 1;
		}
	}

	/* verify the arguments */

	if((oshared + oexclusive + ounlock) != 1) {
	  /* only one of the options should have been specified */
	  Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
	  return TCL_ERROR;
	}

	if(onoblock && ounlock) {
	  /* should not be specified together */
	  Tcl_SetResult(interp, "-noblock can not be used with -unlock", TCL_STATIC);
	  return TCL_ERROR;
	}
	  
#if HAVE_FLOCK
	/* prefer flock if present */
	if(oshared) operation |= LOCK_SH;

	if(oexclusive) operation |= LOCK_EX;

	if(ounlock) operation |= LOCK_UN;

	if(onoblock) operation |= LOCK_NB;

	ret = flock(fd, operation);
	if(ret == -1) {
	  errnoval = errno;
	}
#else
#if HAVE_LOCKF
	if(ounlock) operation = F_ULOCK;

	/* lockf semantics don't map to shared locks. */
	if(oshared || oexclusive) {
	  if(onoblock) {
	    operation = F_TLOCK;
	  } else {
	    operation = F_LOCK;
	  }
	}

	curpos = lseek(fd, 0, SEEK_CUR);
	if(curpos == -1) {
		Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
		return TCL_ERROR;
	}

	ret = lockf(fd, operation, 0); /* lock entire file */

	curpos = lseek(fd, curpos, SEEK_SET);
	if(curpos == -1) {
		Tcl_SetResult(interp, (void *) "Seek error", TCL_STATIC);
		return TCL_ERROR;
	}

	if(ret == -1) {
	  errnoval = errno;
	  if((oshared || oexclusive)) {
	    /* map the errno val to what we would expect for flock */
	    if(onoblock && errnoval == EAGAIN) {
	      /* on some systems, EAGAIN=EWOULDBLOCK, but lets be safe */
	      errnoval = EWOULDBLOCK;
	    } else if(errnoval == EINVAL) {
	      errnoval = EOPNOTSUPP;
	    }
	  }
	}
#else
#error no available locking implementation
#endif /* HAVE_LOCKF */
#endif /* HAVE_FLOCK */

	if (ret != 0)
	{
		switch(errnoval) {
			case EAGAIN:
				res = "EAGAIN";
				break;
			case EBADF:
				res = "EBADF";
				break;
			case EINVAL:
				res = "EINVAL";
				break;
			case EOPNOTSUPP:
				res = "EOPNOTSUPP";
				break;
			default:
				res = strerror(errno);
				break;
		}
		Tcl_SetResult(interp, (void *) res, TCL_STATIC);
		return TCL_ERROR;
	}
	return TCL_OK;
}

/**
 *
 * Return the list of elements in a directory.
 * Since 1.60.4.2, the list doesn't include . and ..
 *
 * Synopsis: readdir directory
 */
int ReaddirCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	DIR *dirp;
	struct dirent *mp;
	Tcl_Obj *tcl_result;
	char *path;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "directory");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);
	dirp = opendir(path);
	if (!dirp) {
		Tcl_SetResult(interp, "Cannot read directory", TCL_STATIC);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewListObj(0, NULL);
	while ((mp = readdir(dirp))) {
		/* Skip . and .. */
		if ((mp->d_name[0] != '.') ||
			((mp->d_name[1] != 0)	/* "." */
				&&
			((mp->d_name[1] != '.') || (mp->d_name[2] != 0)))) /* ".." */ {
			Tcl_ListObjAppendElement(interp, tcl_result, Tcl_NewStringObj(mp->d_name, -1));
		}
	}
	closedir(dirp);
	Tcl_SetObjResult(interp, tcl_result);
	
	return TCL_OK;
}

int StrsedCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *pattern, *string, *res;
	int range[2];
	extern char *strsed(char *str, char *pat, int *range);
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

/**
 * Take a file descriptor and generate a Tcl channel out of it.
 * Syntax is:
 * mkchannelfromfd fd [r|w|rw]
 * Use r to generate a read-only channel, w for a write only channel or rw
 * for a read/write channel (the default).
 */
int MkChannelFromFdCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Channel theChannel;
	int fd;
	int readOrWrite = TCL_READABLE | TCL_WRITABLE;

	if ((objc != 2) && (objc != 3)) {
		Tcl_WrongNumArgs(interp, 1, objv, "fd [r|w|rw]");
		return TCL_ERROR;
	}
	
	if (objc == 3) {
		char* readOrWrite_as_char_star;
		readOrWrite_as_char_star = strdup(Tcl_GetString(objv[2]));
		if (readOrWrite_as_char_star == NULL) {
			return TCL_ERROR;
		}

		if ((readOrWrite_as_char_star[0] == 'r')
			&& (readOrWrite_as_char_star[1] == '\0')) {
			readOrWrite = TCL_READABLE;
		} else if ((readOrWrite_as_char_star[0] == 'w')
			&& (readOrWrite_as_char_star[1] == '\0')) {
			readOrWrite = TCL_WRITABLE;
		} else if ((readOrWrite_as_char_star[0] == 'r')
			&& (readOrWrite_as_char_star[1] == 'w')
			&& (readOrWrite_as_char_star[2] == '\0')) {
			readOrWrite = TCL_READABLE | TCL_WRITABLE;
		} else {
			Tcl_AppendResult(interp, "Bad mode. Use r, w or rw", NULL);
			free(readOrWrite_as_char_star);
			return TCL_ERROR;
		}

		free(readOrWrite_as_char_star);
	}

	{
		char* fd_as_char_star;
		fd_as_char_star = strdup(Tcl_GetString(objv[1]));
		if (fd_as_char_star == NULL) {
			return TCL_ERROR;
		}

		if (Tcl_GetInt(interp, fd_as_char_star, &fd) != TCL_OK) {
			free(fd_as_char_star);
			return TCL_ERROR;
		}
		free(fd_as_char_star);
	}

	theChannel = Tcl_MakeFileChannel((ClientData) fd, readOrWrite);
	if (theChannel == NULL) {
		return TCL_ERROR;
	}
	
	/* register the channel in the current interpreter */
	Tcl_RegisterChannel(interp, theChannel);
	Tcl_AppendResult(interp, Tcl_GetChannelName(theChannel), (char *) NULL);

	return TCL_OK;
}

int MktempCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *template, *sp;
	Tcl_Obj *tcl_result;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "template");
		return TCL_ERROR;
	}

	template = strdup(Tcl_GetString(objv[1]));
	if (template == NULL)
		return TCL_ERROR;

	if ((sp = mktemp(template)) == NULL) {
		Tcl_AppendResult(interp, "mktemp failed: ", strerror(errno), NULL);
		free(template);
		return TCL_ERROR;
	}

	tcl_result = Tcl_NewStringObj(sp, -1);
	Tcl_SetObjResult(interp, tcl_result);
	free(template);
	return TCL_OK;
}

int MkstempCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Channel channel;
	char *template, *channelname;
	int fd;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "template");
		return TCL_ERROR;
	}

	template = strdup(Tcl_GetString(objv[1]));
	if (template == NULL)
		return TCL_ERROR;

	if ((fd = mkstemp(template)) < 0) {
		Tcl_AppendResult(interp, "mkstemp failed: ", strerror(errno), NULL);
		free(template);
		return TCL_ERROR;
	}

	channel = Tcl_MakeFileChannel((ClientData) fd, TCL_READABLE|TCL_WRITABLE);
	Tcl_RegisterChannel(interp, channel);
	channelname = (char *)Tcl_GetChannelName(channel);
	Tcl_AppendResult(interp, channelname, " ", template, NULL);
	free(template);
	return TCL_OK;
}

/**
 * Call mkfifo(2).
 * Generate a Tcl error if something wrong occurred.
 *
 * Syntax is:
 * mkfifo path mode
 */
int MkfifoCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char* path;
	mode_t mode;

	if (objc != 3) {
		Tcl_WrongNumArgs(interp, 1, objv, "path mode");
		return TCL_ERROR;
	}
	
	{
		char* mode_as_char_star;
		int mode_as_int;
		mode_as_char_star = strdup(Tcl_GetString(objv[2]));
		if (mode_as_char_star == NULL) {
			return TCL_ERROR;
		}

		if (Tcl_GetInt(interp, mode_as_char_star, &mode_as_int) != TCL_OK) {
			free(mode_as_char_star);
			return TCL_ERROR;
		}
		free(mode_as_char_star);
		mode = (mode_t) mode_as_int;
	}

	path = strdup(Tcl_GetString(objv[1]));
	if (path == NULL) {
		return TCL_ERROR;
	}

	if (mkfifo(path, mode) != 0) {
		Tcl_AppendResult(interp, "mkfifo failed: ", strerror(errno), NULL);
		free(path);
		return TCL_ERROR;
	}

	free(path);
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

/* Find the first unused UID > 100
   previously this would find the highest used UID and add 1
   but UIDs > 500 are visible on the login screen of OS X */
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

/* Just as with NextuidCmd, return the first unused gid > 100
   groups aren't visible on the login screen, but I see no reason
   to create group 502 when I can create group 100 */
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
	const size_t stringlen = 4; /* 3 digits & \0 */
	int i;
	mode_t *set;
	mode_t newmode;
	mode_t oldmode;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "numask");
		return TCL_ERROR;
	}

	tcl_mask = Tcl_GetString(objv[1]);
	if ((set = setmode(tcl_mask)) == NULL) {
		Tcl_SetResult(interp, "Invalid umask mode", TCL_STATIC);
		return TCL_ERROR;
	}

	newmode = getmode(set, 0);

	oldmode = umask(newmode);

	tcl_mask = malloc(stringlen); /* 3 digits & \0 */
	if (!tcl_mask) {
		return TCL_ERROR;
	}

	/* Totally gross and cool */
	p = tcl_mask + stringlen;
	*p = '\0';
	for (i = stringlen - 1; i > 0; i--) {
		p--;
		*p = (oldmode & 7) + '0';
		oldmode >>= 3;
	}
	if (*p != '0') {
		p--;
		*p = '0';
	}

	tcl_result = Tcl_NewStringObj(p, -1);
	free(tcl_mask);

	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}

/**
 * Call pipe(2) to create a pipe.
 * Syntax is:
 * pipe
 *
 * Generate a Tcl error if something goes wrong.
 * Return a list with the file descriptors of the pipe. The first item is the
 * readable fd.
 */
int PipeCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj* result;
	int fildes[2];

	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	if (pipe(fildes) < 0) {
		Tcl_AppendResult(interp, "pipe failed: ", strerror(errno), NULL);
		return TCL_ERROR;
	}
	
	/* build a list out of the couple */
	result = Tcl_NewListObj(0, NULL);
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[0]));
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(fildes[1]));
	Tcl_SetObjResult(interp, result);

	return TCL_OK;
}

/**
 * Call socketpair to generate a socket pair in the Unix domain.
 * Syntax is:
 * unixsocketpair
 *
 * Generate a Tcl error if something goes wrong.
 * Return a list with the file descriptors of the pair.
 */
int UnixSocketPairCmd(ClientData clientData UNUSED, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj* result;
	int pair[2];

	if (objc != 1) {
		Tcl_WrongNumArgs(interp, 1, objv, NULL);
		return TCL_ERROR;
	}
	
	if (socketpair(AF_UNIX, SOCK_STREAM, 0, pair) < 0) {
		Tcl_AppendResult(interp, "socketpair failed: ", strerror(errno), NULL);
		return TCL_ERROR;
	}
	
	/* build a list out of the pair */
	result = Tcl_NewListObj(0, NULL);
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(pair[0]));
	Tcl_ListObjAppendElement(interp, result, Tcl_NewIntObj(pair[1]));
	Tcl_SetObjResult(interp, result);

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
        Tcl_SetResult(interp, (char *)Tcl_PosixError(interp), TCL_STATIC);
        return TCL_ERROR;
    }
    return TCL_OK;
}

int Pextlib_Init(Tcl_Interp *interp)
{
	if (Tcl_InitStubs(interp, "8.3", 0) == NULL)
		return TCL_ERROR;

	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "flock", FlockCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "readdir", ReaddirCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "strsed", StrsedCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mkstemp", MkstempCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mktemp", MktempCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "existsuser", ExistsuserCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "existsgroup", ExistsgroupCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "nextuid", NextuidCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "nextgid", NextgidCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "md5", MD5Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "xinstall", InstallCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "fs-traverse", FsTraverseCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "filemap", FilemapCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "rpm-vercomp", RPMVercompCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "rmd160", RMD160Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "sha1", SHA1Cmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "compat", CompatCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "umask", UmaskCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "sudo", SudoCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mkfifo", MkfifoCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "unixsocketpair", UnixSocketPairCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "mkchannelfromfd", MkChannelFromFdCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "pipe", PipeCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "curl", CurlCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "symlink", CreateSymlinkCmd, NULL, NULL);
	
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
	Tcl_CreateObjCommand(interp, "name_to_gid", name_to_gidCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "gid_to_name", gid_to_nameCmd, NULL, NULL);
	
	Tcl_CreateObjCommand(interp, "tracelib", TracelibCmd, NULL, NULL);

	if (Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
		return TCL_ERROR;

	/* init libcurl */
	CurlInit(interp);

	return TCL_OK;
}
