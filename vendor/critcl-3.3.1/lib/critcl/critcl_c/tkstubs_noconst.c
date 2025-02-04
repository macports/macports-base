
#if USE_TK_STUBS
    /* Pre 8.6 two of the variables are not declared const.
     * Prevent mismatch with tkDecls.h
     */

          TkStubs *tkStubsPtr;
    const struct TkPlatStubs *tkPlatStubsPtr;
    const struct TkIntStubs *tkIntStubsPtr;
    const struct TkIntPlatStubs *tkIntPlatStubsPtr;
          struct TkIntXlibStubs *tkIntXlibStubsPtr;

  static int
  MyInitTkStubs (Tcl_Interp *ip)
  {
    if (Tcl_PkgRequireEx(ip, "Tk", "8.1", 0, (ClientData*) &tkStubsPtr) == NULL)      return 0;
    if (tkStubsPtr == NULL || tkStubsPtr->hooks == NULL) {
      Tcl_SetResult(ip, "This extension requires Tk stubs-support.", TCL_STATIC);
      return 0;
    }
    tkPlatStubsPtr = tkStubsPtr->hooks->tkPlatStubs;
    tkIntStubsPtr = tkStubsPtr->hooks->tkIntStubs;
    tkIntPlatStubsPtr = tkStubsPtr->hooks->tkIntPlatStubs;
    tkIntXlibStubsPtr = tkStubsPtr->hooks->tkIntXlibStubs;
    return 1;
  }
#endif
