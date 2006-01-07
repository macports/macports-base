/*
 * readline.h
 * $Id: readline.h,v 1.2 2006/01/07 23:08:58 jberry Exp $
 *
 */

int ReadlineCmd(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST objv[]);
int RLHistoryCmd(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST objv[]);
