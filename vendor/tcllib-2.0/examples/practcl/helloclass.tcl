my define set class ::world
my define set cclass World

my code tcl {
oo::class create ::world {}
}

my cmethod hello {
  Tcl_Obj *pResult=Tcl_NewStringObj("Hello World!",-1);
  Tcl_SetObjResult(pResult);
  return TCL_OK;
}
