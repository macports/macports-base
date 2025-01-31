my c_tclproc_raw ::hello {
  Tcl_Obj *pResult=Tcl_NewStringObj("Hello World!",-1);
  Tcl_SetObjResult(pResult);
  return TCL_OK;
}
