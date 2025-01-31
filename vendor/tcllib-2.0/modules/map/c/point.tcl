## -*- tcl -*-
# ### ### ### ######### ######### #########
## Support declarations

# ### ### ### ######### ######### #########
## Type definitions

critcl::resulttype point {
    Tcl_SetObjResult(interp, point_box (interp, &rv));
    return TCL_OK;
} point

critcl::argtype point {
    if (point_unbox (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
} point point

# ### ### ### ######### ######### #########
## Support implementation

critcl::ccode {
    #include <stdio.h>

    typedef struct point {
	double y;
	double x;
    } point;

    static int
    point_unbox (Tcl_Interp* interp, Tcl_Obj* obj, point* p)
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

	double y;
	double x;

	if (Tcl_GetDoubleFromObj (interp, lv[0], &x) != TCL_OK) return TCL_ERROR;
	if (Tcl_GetDoubleFromObj (interp, lv[1], &y) != TCL_OK) return TCL_ERROR;

	p->y = y;
	p->x = x;

	return TCL_OK;
    }

    static Tcl_Obj*
    point_box (Tcl_Interp* interp, point* p)
    {
	Tcl_Obj* cl[2];
	cl [0] = Tcl_NewDoubleObj (p->x);
	cl [1] = Tcl_NewDoubleObj (p->y);
	return Tcl_NewListObj(2, cl); /* OK tcl9 */
    }

    static Tcl_Obj*
    point_box_list (int release, Tcl_Interp* interp, Tcl_Size c, point* points)
    {
	Tcl_Obj** cl = (Tcl_Obj**) ckalloc (c * sizeof(Tcl_Obj*));
	unsigned int k;

	for (k = 0; k < c; k++) \
	    cl[k] = point_box (interp, &points[k]);

	Tcl_Obj* r = Tcl_NewListObj(c, cl); /* OK tcl9 */

	ckfree (cl);
	if (release) { ckfree (points); }
	return r;
    }
}

# ### ### ### ######### ######### #########
return
