#include <stdlib.h>
#include <tcl.h>

int SystemCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	Tcl_Obj *resultPtr;
	char buf[1024];
	FILE *pipe;
	int ret;

	if (objc < 2) {
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

int Pextlib_Init(Tcl_Interp *interp)
{
	Tcl_CreateObjCommand(interp, "system", SystemCmd, NULL, NULL);
	Tcl_PkgProvide(interp, "Pextlib", "1.0");
	return TCL_OK;
}
