  static char script\[$count] = {
    $inittext
  };
  Tcl_SetByteArrayObj(Tcl_GetObjResult(ip), (unsigned char*) script, $count);
  return TCL_OK;
