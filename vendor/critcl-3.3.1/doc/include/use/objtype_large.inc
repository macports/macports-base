[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the end of the previous section.

[enum] Edit the file [file example.tcl].

[enum] Describing each individual change is too complex. The following is easier.

[enum] Save the file, then replace the entire functionality with the following.

[enum] After that use a [syscmd diff] of your choice to compare the files and see the
critical changes.

[example {
    critcl::ccode {
	typedef struct vec2 {
	    unsigned int rc;
	    double x;
	    double y;
	} vec2;

	typedef vec2* vec2ptr;

	/* -- Core vector structure management -- */

	static vec2ptr Vec2New (double x, double y) {
	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
	    vec->rc = 0;
	    vec->x = x;
	    vec->y = y;
	    return vec;
	}

	static vec2ptr Vec2Copy (vec2ptr src) {
	    scr->rc ++;
	    return src;
	}

	static void Vec2Release (vec2ptr vec) {
	    if (vec->rc > 1) {
		vec->rc --;
		return;
	    }
	    
	    Tcl_Free ((char*) vec);
	}

	/* -- Vector obj type -- */

	static void Vec2Free     (Tcl_Obj* obj);
	static void Vec2StringOf (Tcl_Obj* obj);
	static void Vec2Dup      (Tcl_Obj* obj, Tcl_Obj* dst);
	static int  Vec2FromAny  (Tcl_Interp* interp, Tcl_Obj* obj);

	Tcl_ObjType vec2_objtype = {
	    "vec2",
	    Vec2Free,
	    Vec2Dup,
	    Vec2StringOf,
	    Vec2FromAny
	};

	static void Vec2Free (Tcl_Obj* obj) {
	    Vec2Release ((vec2ptr) obj->internalRep.otherValuePtr);
	}

	static void Vec2Dup (Tcl_Obj* obj, Tcl_Obj* dst) {
	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

	    dst->internalRep.otherValuePtr = Vec2Copy (vec);
	    dst->typePtr                   = &vec2_objtype;
	}

	static void Vec2StringOf (Tcl_Obj* obj) {
	    vec2ptr vec = (vec2ptr) obj->internalRep.otherValuePtr;

	    /* Serialize vector data to string (list of two doubles) */
	    Tcl_DString      ds;
	    Tcl_DStringInit (&ds);

	    char buf [TCL_DOUBLE_SPACE];

	    Tcl_PrintDouble (0, vec->x, buf); Tcl_DStringAppendElement (&ds, buf);
	    Tcl_PrintDouble (0, vec->y, buf); Tcl_DStringAppendElement (&ds, buf);

	    int length = Tcl_DStringLength (ds);

	    /* Set string representation */
	    obj->length = length;
	    obj->bytes  = Tcl_Alloc(length+1);
	    memcpy (obj->bytes, Tcl_DStringValue (ds), length);
	    obj->bytes[length] = '\0';
	    /*
	    ** : package require critcl::cutil ;# get C utilities
	    ** : critcl::cutil::alloc          ;# Activate allocation utilities
	    ** : (Internally cheaders, include)
	    ** : Then all of the above can be written as STREP_DS (obj, ds);
	    ** : STREP_DS = STRing REP from DString
	    */

	    Tcl_DStringFree (&ds);
	}

	static int Vec2FromAny (Tcl_Interp* interp, Tcl_Obj* obj) {
	    /* Change internal rep of obj to vector structure.
	    ** A Tcl list of 2 doubles is used as intermediary int rep.
	    */

	    int len;
	    if (Tcl_ListObjLength (interp, obj, &len) != TCL_OK) return TCL_ERROR;
	    if (len != 2) {
		Tcl_SetObjResult (interp, Tcl_ObjPrintf ("Expected 2 elements, got %d", len));
		return TCL_ERROR;
	    }

	    Tcl_Obj* lv[2];
	    if (Tcl_ListObjGetElements (interp, obj, &lv) != TCL_OK) return TCL_ERROR;

	    double x, y;
	    if (Tcl_GetDoubleFromObj (interp, lv[0], &x) != TCL_OK) return TCL_ERROR;
	    if (Tcl_GetDoubleFromObj (interp, lv[1], &y) != TCL_OK) return TCL_ERROR;

	    obj->internalRep.otherValuePtr = (void*) Vec2New (x, y);
	    obj->typePtr                   = &vec2_objtype;

	    return TCL_OK;
	}

	/* (un)packing structures from/into Tcl values -- */

	int GetVecFromObj (Tcl_Interp* interp, Tcl_Obj* obj, vec2ptr* vec)
	{
	    if (obj->typePtr != &vec2_objtype) {
		if (VecFromAny (interp, obj) != TCL_OK) return TCL_ERROR;
	    }

	    *vec = (vec2ptr) obj->internalRep.otherValuePtr;
	    return TCL_OK;
	}

	Tcl_Obj* NewVecObj (vec2ptr vec) {
	    Tcl_Obj* obj = Tcl_NewObj ();

	    Tcl_InvalidateStringRep (obj);

	    obj->internalRep.otherValuePtr = Vec2Copy (vec);
	    obj->typePtr                   = &vec2_objtype;

	    return obj;
	}
    }

    critcl::argtype vec2 {
	if (GetVecFromObj (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    } vec2ptr vec2ptr

    critcl::resulttype vec2 {
	/* rv: result value of function, interp: current Tcl interpreter */
	Tcl_SetObjResult (interp, NewVecObj (rv));
	return TCL_OK;
    } vec2ptr

    critcl::cproc norm {vec2 vector} double {
	double norm = hypot (vector->x, vector->y);
	return norm;
    }

    critcl::cproc add {vec2 a vec2 b} vec2 {
	return Vec2New (a->x + b->x, a->y + b->y);
    }
}]

[enum] The [type vec2] structure is now reference counted.

[enum] The core management functions, i.e. [fun Vec2New], [fun Vec2Copy], and
[fun Vec2Release] are changed to maintain that reference count.

Starting at [const 0] on creation, copies increment, and releases decrement.

A structure is actually only freed when its reference count falls to [const 0] or below.

[enum] [type vec2] results are changed to pointers, easily passed back through the stack.

The modified translation layer just wraps it into a [type Tcl_Obj*] value.

[enum] [emph Attention]. Duplicating such a [type Tcl_Obj*] does not duplicate the
referenced [type vec2] structure anymore, just adds a reference.

[enum] Regarding [syscmd diff] commands, I know of two graphical diffs for Tcl/Tk,
[vset tkdiff], and [vset eskil].

[list_end]

[para] Packages: [term critcl::cutil]
