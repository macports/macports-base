/*
 * Pextlib.c
 *
 * Copyright (c) 2002 - 2003 Apple Computer, Inc.
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

#if HAVE_DIRENT_H
#include <dirent.h>
#endif

#if HAVE_LIMITS_H
#include <limits.h>
#endif

#if HAVE_PATHS_H
#include <paths.h>
#else
#ifndef _PATH_DEVNULL
#define _PATH_DEVNULL "/dev/null"
#endif
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

#if HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

#if HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <tcl.h>

#include "md5cmd.h"

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

int SystemCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int FlockCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int ReaddirCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	DIR *dirp;
	struct dirent *dp;
	Tcl_Obj *tcl_result;
	char *path;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "directory");
		return TCL_ERROR;
	}

	path = Tcl_GetString(objv[1]);
	dirp = opendir(path);
	if (!dirp) {
		Tcl_SetResult(interp, "Directory not found", TCL_STATIC);
		return TCL_ERROR;
	}
	tcl_result = Tcl_NewListObj(0, NULL);
	while ((dp = readdir(dirp))) {
		Tcl_ListObjAppendElement(interp, tcl_result, Tcl_NewStringObj(dp->d_name, -1));
	}
	closedir(dirp);
	Tcl_SetObjResult(interp, tcl_result);
	
	return TCL_OK;
}

int StrsedCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int MktempCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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
	free(sp);
	return TCL_OK;
}

int MkstempCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int ExistsuserCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int ExistsgroupCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
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

int NextuidCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *tcl_result;
	struct passwd *pwent;
	int max;

	max = 0;

	while ((pwent = getpwent()) != NULL)
		if ((int)pwent->pw_uid > max)
			max = (int)pwent->pw_uid;
	
	tcl_result = Tcl_NewIntObj(max + 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}

int NextgidCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *tcl_result;
	struct group *grent;
	int max;

	max = 0;

	while ((grent = getgrent()) != NULL)
		if ((int)grent->gr_gid > max)
			max = (int)grent->gr_gid;
	
	tcl_result = Tcl_NewIntObj(max + 1);
	Tcl_SetObjResult(interp, tcl_result);
	return TCL_OK;
}

int InstallCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	extern int doinstall(Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);

	return doinstall(interp, objc, objv);
}

int Pextlib_Init(Tcl_Interp *interp)
{
	if(Tcl_InitStubs(interp, "8.3", 0) == NULL)
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
	Tcl_CreateObjCommand(interp, "doinstall", InstallCmd, NULL, NULL);
	if(Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
		return TCL_ERROR;
	return TCL_OK;
}
