## -*- tcl -*-
# ### ### ### ######### ######### #########
## Support declarations

# ### ### ### ######### ######### #########
## Type definitions

critcl::resulttype pointbox {
    Tcl_SetObjResult(interp, pointbox_box (interp, &rv));
    return TCL_OK;
} pointbox

critcl::argtype pointbox {
    if (pointbox_unbox (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
} pointbox pointbox

# ### ### ### ######### ######### #########
## Support implementation

critcl::ccode {
    typedef struct pointbox {
	double x0;
	double y0;
	double x1;
	double y1;
    } pointbox;

    static int
    pointbox_unbox (Tcl_Interp* interp, Tcl_Obj* obj, pointbox* p)
    {
	Tcl_Size  lc;
	Tcl_Obj** lv;

	if (Tcl_ListObjGetElements (interp, obj, &lc, &lv) != TCL_OK) /* OK tcl9 */
	    return TCL_ERROR;
	if (lc != 4) {
	    Tcl_SetErrorCode (interp, "MAP", "SLIPPY", "INVALID", "POINTBOX", NULL);
	    Tcl_AppendResult (interp, "Bad pointbox, expected list of 4", NULL);
	    return TCL_ERROR;
	}

	double x0, y0, x1, y1;

	if (Tcl_GetDoubleFromObj (interp, lv[0], &x0) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[1], &y0) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[2], &x1) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[3], &y1) != TCL_OK) return TCL_ERROR;

	p->x0 = x0;
	p->y0 = y0;
	p->x1 = x1;
	p->y1 = y1;

	return TCL_OK;
    }

    static Tcl_Obj*
    pointbox_box (Tcl_Interp* interp, pointbox* p)
    {
	Tcl_Obj* cl[4];
	cl [0] = Tcl_NewDoubleObj (p->x0);
	cl [1] = Tcl_NewDoubleObj (p->y0);
	cl [2] = Tcl_NewDoubleObj (p->x1);
	cl [3] = Tcl_NewDoubleObj (p->y1);
	return Tcl_NewListObj(4, cl); /* OK tcl9 */
    }
}

# ### ### ### ######### ######### #########
return
