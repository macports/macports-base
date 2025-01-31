## -*- tcl -*-
# ### ### ### ######### ######### #########
## Support declarations

# ### ### ### ######### ######### #########
## Type definitions

critcl::resulttype wxh {
    Tcl_SetObjResult(interp, wxh_box (interp, &rv));
    return TCL_OK;
} wxh

critcl::argtype wxh {
    if (wxh_unbox (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
} wxh wxh

# ### ### ### ######### ######### #########
## Support implementation

critcl::ccode {
    typedef struct wxh {
	double w;
	double h;
    } wxh;

    static int
    wxh_unbox (Tcl_Interp* interp, Tcl_Obj* obj, wxh* p)
    {
	Tcl_Size  lc;
	Tcl_Obj** lv;

	if (Tcl_ListObjGetElements (interp, obj, &lc, &lv) != TCL_OK)  /* OK tcl9 */
	    return TCL_ERROR;
	if (lc != 2) {
	    Tcl_SetErrorCode (interp, "MAP", "SLIPPY", "INVALID", "WXH", NULL);
	    Tcl_AppendResult (interp, "Bad WxH, expected list of 2", NULL);
	    return TCL_ERROR;
	}

	double h;
	double w;

	if (Tcl_GetDoubleFromObj (interp, lv[0], &w) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[1], &h) != TCL_OK) return TCL_ERROR;

	p->h = h;
	p->w = w;

	return TCL_OK;
    }

    static Tcl_Obj*
    wxh_box (Tcl_Interp* interp, wxh* p)
    {
	Tcl_Obj* cl[2];
	cl [0] = Tcl_NewDoubleObj (p->w);
	cl [1] = Tcl_NewDoubleObj (p->h);
	return Tcl_NewListObj(2, cl); /* OK tcl9 */
    }
}

# ### ### ### ######### ######### #########
return
