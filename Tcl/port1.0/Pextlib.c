#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <dirent.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <tcl.h>
#include <unistd.h>

#define BUFSIZ 1024

static int ui_info(Tcl_Interp *interp, char *mesg) {
	const char ui_proc[] = "ui_info {";
	char *script, *p;
	int scriptlen, ret;

	scriptlen = sizeof(ui_proc) + strlen(mesg);
	script = malloc(scriptlen);
	if (script == NULL)
		return TCL_ERROR;
	else
		p = script;

	memcpy(script, ui_proc, sizeof(ui_proc));
	strcat(script, mesg);
	p += scriptlen - 2;
	*p = '}';
	return (Tcl_EvalEx(interp, script, scriptlen - 1, 0));
}

int SystemCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	char buf[BUFSIZ];
	char *args[4];
	char *cmdstring, *p;
	FILE *pdes;
	int fdset[2];
	int i, cmdlen, cmdlenavail, ret;
	pid_t pid;
	cmdlen = cmdlenavail = BUFSIZ;
	p = cmdstring = NULL;

	if(Tcl_PkgRequire(interp, "portui", "1.0", 0) == NULL) {
		return TCL_ERROR;
	}

	if (objc < 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		return TCL_ERROR;
	} else if (objc == 2) {
		cmdstring = Tcl_GetString(objv[1]);
	} else if (objc > 2) {
		cmdstring = malloc(cmdlen);
		if (cmdstring == NULL)
			return TCL_ERROR;
		p = cmdstring;
		/*
		 * Rather than realloc for every iteration
		 * through the argument vector, malloc a
		 * sizable chunk of memory first.
		 * If we extend beyond what is available,
		 * then realloc
		 */
		for (i = 1; i < objc; i++) {
			char *arg;
			int len;

			arg = Tcl_GetString(objv[i]);
			/* Add 1 for trailing \0 or ' ' */
			len = strlen(arg) + 1;

			if (len > cmdlenavail) {
				char *sptr;
				cmdlen += cmdlenavail + len;
				/*
				 * puma does not have reallocf.
				 * Change when we rev past puma
				 */
				sptr = cmdstring;
				cmdstring = realloc(cmdstring, cmdlen);
				if (cmdstring == NULL) {
					free(sptr);
					return TCL_ERROR;
				}
			}
			/* Subtract 1 to not copy trailing \0 */
			memcpy(p, arg, len - 1);
			p += len;

			if (i == objc - 1) {
				*(p - 1) = '\0';
			} else {
				*(p - 1) = ' ';
			}
			cmdlenavail -= len;
			cmdlen += len;
		}
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
		dup2(fdset[1], STDOUT_FILENO);
		dup2(fdset[1], STDERR_FILENO);
		/* XXX ugly string constants */
		args[0] = "sh";
		args[1] = "-c";
		args[2] = cmdstring;
		args[3] = NULL;
		execve("/bin/sh", args, NULL);
	}
	close(fdset[1]);
	pdes = fdopen(fdset[0], "r");
	if (p != NULL)
		free(cmdstring);

	/* read from simulated popen() pipe */
	while (fgets(buf, BUFSIZ, pdes) != NULL) {
		int ret = ui_info(interp, buf);
		if (ret != TCL_OK)
			return ret;
		Tcl_AppendResult(interp, buf, NULL);
	}
	fclose(pdes);
	wait(&ret);
	if (ret == 0)
		return TCL_OK;
	else
		return TCL_ERROR;
}

int FlockCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	static const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\"";
	int operation = 0, fd, i;
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
	if (flock(fd, operation) != 0)
	{
		Tcl_SetResult(interp, (void *) strerror(errno), TCL_STATIC);
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
	while (dp = readdir(dirp)) {
		Tcl_ListObjAppendElement(interp, tcl_result, Tcl_NewStringObj(dp->d_name, -1));
	}
	closedir(dirp);
	Tcl_SetObjResult(interp, tcl_result);
	
	return TCL_OK;
}

int Pextlib_Init(Tcl_Interp *interp)
{
	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "flock", FlockCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "readdir", ReaddirCmd, NULL, NULL);
	if(Tcl_PkgProvide(interp, "Pextlib", "1.0") != TCL_OK)
		return TCL_ERROR;
	return TCL_OK;
}
