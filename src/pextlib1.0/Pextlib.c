/*
 * Pextlib.c
 *
 * Copyright (c) 2002 Apple Computer, Inc.
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

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <errno.h>
#include <grp.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>
#include <paths.h>
#include <pwd.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <tcl.h>
#include <unistd.h>
#ifdef __APPLE__
#include <crt_externs.h>
#endif

#define BUFSIZ 1024
#define CBUFSIZ 30

#if !defined(__APPLE__)
extern char **environ;
#endif

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

static int ui_info(Tcl_Interp *interp, char *mesg)
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

int SystemCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char buf[BUFSIZ];
	char circbuf[CBUFSIZ][BUFSIZ];
	char errbuf[CBUFSIZ * BUFSIZ];
	char *args[4];
	char *cmdstring;
	FILE *pdes;
	int fdset[2], nullfd;
	int fline, pos, ret;
	pid_t pid;
	Tcl_Obj *tcl_result;
#if defined(__APPLE__)
	char **environ;
	environ = *_NSGetEnviron();
#endif

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		return TCL_ERROR;
	}
	cmdstring = Tcl_GetString(objv[1]);

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
		/* XXX dropping the controlling terminal */
		if (setsid() == -1)
			_exit(1);
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
	while (fgets(buf, BUFSIZ, pdes) != NULL) {
		memcpy(circbuf[pos], buf, BUFSIZ);
		if (pos++ == CBUFSIZ)
			pos = 0;
		ret = ui_info(interp, buf);
		if (ret != TCL_OK)
			return ret;
	}
	fclose(pdes);

	bzero(errbuf, sizeof(errbuf));
	for (fline = pos; pos < fline + CBUFSIZ; pos++)
		strcat(errbuf, circbuf[pos % CBUFSIZ]);

	if (wait(&ret) != pid)
		return TCL_ERROR;
	if (WIFEXITED(ret)) {
		if (WEXITSTATUS(ret) == 0)
			return TCL_OK;
		else {
			tcl_result = Tcl_NewStringObj("shell command \"", -1);
			Tcl_AppendToObj(tcl_result, cmdstring, -1);
			Tcl_AppendToObj(tcl_result, "\" returned error ", -1);
			Tcl_AppendObjToObj(tcl_result, Tcl_NewIntObj(WEXITSTATUS(ret)));
			Tcl_AppendToObj(tcl_result, "\nCommand output: ", -1);
			Tcl_AppendToObj(tcl_result, errbuf, -1);
			Tcl_SetObjResult(interp, tcl_result);
			return TCL_ERROR;
		}
	} else
		return TCL_ERROR;
}

int FlockCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	static const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\"";
	int operation = 0, fd, i, ret;
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
			if (operation & LOCK_EX || operation & LOCK_UN) {
				Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
				return TCL_ERROR;
			}
			operation |= LOCK_SH;
		} else if (!strcmp(arg, "-exclusive")) {
			if (operation & LOCK_SH || operation & LOCK_UN) {
				Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
				return TCL_ERROR;
			}
			operation |= LOCK_EX;
		} else if (!strcmp(arg, "-unlock")) {
			if (operation & LOCK_SH || operation & LOCK_EX) {
				Tcl_SetResult(interp, (void *) &errorstr, TCL_STATIC);
				return TCL_ERROR;
			}
			operation |= LOCK_UN;
		} else if (!strcmp(arg, "-noblock")) {
			if (operation & LOCK_UN) {
				Tcl_SetResult(interp, "-noblock can not be used with -unlock", TCL_STATIC);
				return TCL_ERROR;
			}
			operation |= LOCK_NB;
		}
	}
	if ((ret = flock(fd, operation)) != 0)
	{
		switch(errno) {
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
	Tcl_SetResult(interp, res, (Tcl_FreeProc *)free);
	return TCL_OK;
}

int MktempCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char *template, *sp;

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

	Tcl_SetResult(interp, sp, (Tcl_FreeProc *)free);
	return TCL_OK;
}

int MkstempCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Channel channel;
	ClientData handle;
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
	channelname = Tcl_GetChannelName(channel);
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

int Pextlib_Init(Tcl_Interp *interp)
{
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
	if(Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
		return TCL_ERROR;
	return TCL_OK;
}
