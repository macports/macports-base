###
# This example implements a "hello world" type
# which is a completely useless Tcl_Obj that only
# stores the content "Hello World"
###

my code define {
#define HELLO_WORLD "Hello World!"
}

my c_function {Tcl_Obj *MyProg_NewHelloWorldObj(void)} {
  Tcl_Obj *objPtr=Tcl_NewObj();
  Tcl_InvalidateStringRep(objPtr);
  objPtr->typePtr=&helloworld_tclobjtype;
  objPtr->internalRep.otherValuePtr=Tcl_Alloc(strlen(HELLO_WORLD));
  strcpy(objPtr->internalRep.otherValuePtr,HELLO_WORLD);
  return objPtr;
}

my c_tclproc_raw ::helloObj {
  Tcl_Obj *pResult=MyProg_NewHelloWorldObj();
  Tcl_SetObjResult(pResult);
  return TCL_OK;
}

my c_tclproc_raw ::is_helloObj {
  int true=objv[1]->typePtr==&helloworld_tclobjtype;
  Tcl_SetObjResult(Tcl_NewBooleanObj(true));
  return TCL_OK;
}

my tcltype helloworld {
  cname helloworld_tclobjtype
 
freeproc {
  Tcl_Free(objPtr->internalRep.otherValuePtr);
  objPtr->internalRep.otherValuePtr=NULL;
  objPtr->typePtr=NULL;
} 
dupproc {
  char *src=srcPtr->internalRep.otherValuePtr;
  int size=sizeof(*src);
  char *copy=(char *)Tcl_Alloc(size);
  memcpy(copy,src,size);
  Tcl_InvalidateStringRep(dupPtr);
  dupPtr->typePtr=&@CNAME@;
  dupPtr->internalRep.otherValuePtr=copy;
} 
updatestringproc {
  /* Update String Rep */
  objptr->length=strlen(HELLO_WORLD);
  objptr->bytes=Tcl_Alloc(objptr->length+1);
  strcpy(objptr->bytes,HELLO_WORLD);
} 

setfromanyproc {
  Tcl_AppentResult(interp,"Hello World is a constant");
  return TCL_ERROR;
}
}
