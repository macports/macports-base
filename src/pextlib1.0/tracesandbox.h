#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <tcl.h>

int TraceSandboxNewCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
int TraceSandboxAddCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
int TraceSandboxSetFenceCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
int TraceSandboxUnsetFenceCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
