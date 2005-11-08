/*
 * readline.h
 * $Id: readline.h,v 1.1.2.1 2005/11/08 05:42:59 jberry Exp $
 *
 */

int ReadlineCmd(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST objv[]);
int HistoryCmd(ClientData, Tcl_Interp *, int, Tcl_Obj *CONST objv[]);
