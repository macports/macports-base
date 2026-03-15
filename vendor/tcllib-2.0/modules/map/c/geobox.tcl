## -*- tcl -*-
# ### ### ### ######### ######### #########
## Support declarations

# ### ### ### ######### ######### #########
## Type definitions

critcl::resulttype geobox {
    Tcl_SetObjResult(interp, geobox_box (interp, &rv));
    return TCL_OK;
} geobox

critcl::argtype geobox {
    if (geobox_unbox (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
} geobox geobox

# ### ### ### ######### ######### #########
## Support implementation

critcl::ccode {
    typedef struct geobox {
	double lat0;
	double lon0;
	double lat1;
	double lon1;
    } geobox;

    static int
    geobox_unbox (Tcl_Interp* interp, Tcl_Obj* obj, geobox* g)
    {
	Tcl_Size  lc;
	Tcl_Obj** lv;

	if (Tcl_ListObjGetElements (interp, obj, &lc, &lv) != TCL_OK) /* OK tcl9 */
	    return TCL_ERROR;
	if (lc != 4) {
	    Tcl_SetErrorCode (interp, "MAP", "SLIPPY", "INVALID", "GEOBOX", NULL);
	    Tcl_AppendResult (interp, "Bad geobox, expected list of 4", NULL);
	    return TCL_ERROR;
	}

	double lat0;
	double lon0;
	double lat1;
	double lon1;

	if (Tcl_GetDoubleFromObj (interp, lv[0], &lat0) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[1], &lon0) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[2], &lat1) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[3], &lon1) != TCL_OK) return TCL_ERROR;

	g->lat0 = lat0;
	g->lon0 = lon0;
	g->lat1 = lat1;
	g->lon1 = lon1;

	return TCL_OK;
    }

    static Tcl_Obj*
    geobox_box (Tcl_Interp* interp, geobox* g)
    {
	Tcl_Obj* cl[4];
	cl [0] = Tcl_NewDoubleObj (g->lat0);
	cl [1] = Tcl_NewDoubleObj (g->lon0);
	cl [2] = Tcl_NewDoubleObj (g->lat1);
	cl [3] = Tcl_NewDoubleObj (g->lon1);
	return Tcl_NewListObj(4, cl); /* OK tcl9 */
    }
}

# ### ### ### ######### ######### #########
return
