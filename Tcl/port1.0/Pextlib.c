#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/file.h>
#include <tcl.h>

int SystemCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *resultPtr;
	char buf[1024];
	FILE *pipe;

	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		return TCL_ERROR;
	}

	pipe = popen(Tcl_GetString(objv[1]), "r");
	resultPtr = Tcl_GetObjResult(interp);
	while (fgets(buf, 1024, pipe) != NULL) {
		Tcl_AppendToObj(resultPtr, (void *) &buf, strlen(buf));
	}
	switch (pclose(pipe)) {
		case 0:
			return TCL_OK;
		default:
			return TCL_ERROR;
	}
}

int FlockCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *resultPtr;
	const char errorstr[] = "use one of \"-shared\", \"-exclusive\", or \"-unlock\"";
	int operation = 0, fd, i;
	Tcl_Channel channel;
	ClientData handle;
	char buf[1024];

	if (objc < 3 || objc > 4) {
		Tcl_WrongNumArgs(interp, 1, objv, "channelId switches");
		return TCL_ERROR;
	}

	resultPtr = Tcl_GetObjResult(interp);

    	if ((channel = Tcl_GetChannel(interp, Tcl_GetString(objv[1]), NULL)) == NULL)
		return TCL_ERROR;

	if (Tcl_GetChannelHandle(channel, TCL_READABLE, &handle) != TCL_OK) {
		Tcl_SetStringObj(resultPtr, "error getting channel handle", -1);
		return TCL_ERROR;
	}
	fd = (int) handle;

	for (i = 2; i < objc; i++) {
		char *arg = Tcl_GetString(objv[i]);
		if (!strcmp(arg, "-shared")) {
			if (operation & LOCK_EX || operation & LOCK_UN) {
				Tcl_SetStringObj(resultPtr, (void *) &errorstr, -1);
				return TCL_ERROR;
			}
			operation |= LOCK_SH;
		} else if (!strcmp(arg, "-exclusive")) {
			if (operation & LOCK_SH || operation & LOCK_UN) {
				Tcl_SetStringObj(resultPtr, (void *) &errorstr, -1);
				return TCL_ERROR;
			}
			operation |= LOCK_EX;
		} else if (!strcmp(arg, "-unlock")) {
			if (operation & LOCK_SH || operation & LOCK_EX) {
				Tcl_SetStringObj(resultPtr, (void *) &errorstr, -1);
				return TCL_ERROR;
			}
			operation |= LOCK_UN;
		} else if (!strcmp(arg, "-noblock")) {
			if (operation & LOCK_UN) {
				Tcl_SetStringObj(resultPtr, "-noblock can not be used with -unlock", -1);
				return TCL_ERROR;
			}
			operation |= LOCK_NB;
		}
	}
	if (flock(fd, operation) != 0)
	{
		Tcl_SetStringObj(resultPtr, (void *) strerror(errno), -1);
		return TCL_ERROR;
	}
	return TCL_OK;
}

int Pextlib_Init(Tcl_Interp *interp)
{
	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_CreateObjCommand(interp, "flock", FlockCmd, NULL, NULL);
	Tcl_PkgProvide(interp, "Pextlib", "1.0");
	return TCL_OK;
}
