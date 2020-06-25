#include "darwintrace_share/darwintrace_share.h"
#include <tcl.h>

shm_offt tcl_string_obj_to_shm_offt(Tcl_Interp *interp, Tcl_Obj *str_obj);
Tcl_Obj *shm_offt_to_tcl_string_obj(Tcl_Interp *interp, shm_offt offset);

int SetSharedMemoryCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
int UnsetSharedMemoryCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[]);
