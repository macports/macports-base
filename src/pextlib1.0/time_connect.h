#ifndef _TIME_CONNECT_H
#define _TIME_CONNECT_H

#include <tcl.h>

/**
 * Command to time how long it takes to connect() to a host.
 * time_connect hostname service
 */
int TimeConnectCmd(ClientData clientData, Tcl_Interp* interp, int objc, Tcl_Obj* const objv[]);

#endif
/* _TIME_CONNECT_H */
