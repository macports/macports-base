## -*- tcl -*-
# ### ### ### ######### ######### #########
## Support declarations

# ### ### ### ######### ######### #########
## Type definitions

critcl::resulttype geo {
    Tcl_SetObjResult(interp, geo_box (interp, &rv));
    return TCL_OK;
} geo

critcl::argtype geo {
    if (geo_unbox (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
} geo geo

# ### ### ### ######### ######### #########
## Support implementation

critcl::ccode {
    #include <stdio.h>

    typedef struct geo {
	double lat;
	double lon;
    } geo;

    static int
    geo_unbox (Tcl_Interp* interp, Tcl_Obj* obj, geo* p)
    {
	Tcl_Size  lc;
	Tcl_Obj** lv;

	if (Tcl_ListObjGetElements (interp, obj, &lc, &lv) != TCL_OK) /* OK tcl9 */
	    return TCL_ERROR;
	if (lc != 2) {
	    Tcl_SetErrorCode (interp, "MAP", "SLIPPY", "INVALID", "POINT", NULL);
	    Tcl_AppendResult (interp, "Bad point, expected list of 2", NULL);
	    return TCL_ERROR;
	}

	double lat;
	double lon;

	if (Tcl_GetDoubleFromObj (interp, lv[0], &lat) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[1], &lon) != TCL_OK) return TCL_ERROR;

	p->lat = lat;
	p->lon = lon;

	return TCL_OK;
    }

    static Tcl_Obj*
    geo_box (Tcl_Interp* interp, geo* p)
    {
	Tcl_Obj* cl[2];
	cl [0] = Tcl_NewDoubleObj (p->lat);
	cl [1] = Tcl_NewDoubleObj (p->lon);
	return Tcl_NewListObj(2, cl); /* OK tcl9 */
    }

    static Tcl_Obj*
    geo_box_list (int release, Tcl_Interp* interp, Tcl_Size c, geo* geos)
    {
	Tcl_Obj** cl = (Tcl_Obj**) ckalloc (c * sizeof(Tcl_Obj*));
	unsigned int k;

	for (k = 0; k < c; k++) \
	    cl[k] = geo_box (interp, &geos[k]);

	Tcl_Obj* r = Tcl_NewListObj(c, cl); /* OK tcl9 */

	ckfree (cl);
	if (release) { ckfree (geos); }
	return r;
    }
}

# ### ### ### ######### ######### #########
return
