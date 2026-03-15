[comment {-*- mode: tcl ; fill-column: 90 -*-}]

[list_begin enumerated]

[enum] Starting from the end of the previous section.

[enum] Edit the file [file example.tcl].

[enum] Remove the entire functionality (type definitions, related C code, and cprocs).

Replace it with [example {
    critcl::ccode {
	typedef struct vec2 {
	    double x;
	    double y;
	} vec2;

	typedef vec2* vec2ptr;

	/* -- Core vector structure management -- */

	static vec2ptr Vec2New (double x, double y) {
	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
	    vec->x = x;
	    vec->y = y;
	    return vec;
	}

	static vec2ptr Vec2Copy (vec2ptr src) {
	    vec2ptr vec = Tcl_Alloc (sizeof (vec2));
	    *vec = *src
	    return vec;
	}

	static void Vec2Release (vec2ptr vec) {
	    Tcl_Free ((char*) vec);
	}

	/* -- Tcl value type for vec2 -- Tcl_ObjType -- */

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
	    /* Change intrep of obj to vec2 structure.
	    ** A Tcl list of 2 doubles is used as an intermediary intrep.
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

	/* -- (un)packing structures from/into Tcl values -- */

	int GetVecFromObj (Tcl_Interp* interp, Tcl_Obj* obj, vec2ptr* vec)
	{
	    if (obj->typePtr != &vec2_objtype) {
		if (Vec2FromAny (interp, obj) != TCL_OK) return TCL_ERROR;
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
	Tcl_SetObjResult (interp, NewVecObj (&rv));
	return TCL_OK;
    } vec2

    critcl::cproc norm {vec2 vector} double {
	double norm = hypot (vector->x, vector->y);
	return norm;
    }

    critcl::cproc add {vec2 a vec2 b} vec2 {
	vec2 z;

	z.x = a->x + b->x;
	z.y = a->y + b->y;

	return z;
    }
}][vset rebuild]

[enum] This implements a new [type Tcl_ObjType] to handle [type vec2] structures. With it
[type vec2] structures are become usable as internal representation ([term intrep] of
[type Tcl_Obj*] values.

[para] The two functions [fun NewVecObj] and [fun GetVecFromObj] pack and unpack the
structures from and into [type Tcl_Obj*] values.

The latter performs the complex deserialization into a structure if and only if needed,
i.e. when the [type TclObj*] value has no intrep, or the intrep for a different type.

This process of changing the intrep of a Tcl value is called [term shimmering].

[para] Intreps cache the interpretation of [type Tcl_Obj*] values as a specific kind of
type. Here [type vec2]. This reduces conversion effort and memory churn, as intreps are
kept by the Tcl interpreter as long as possible and needed.

[enum] The arguments of [cmd norm] and [cmd add] are now converted once on entry, if not
yet in the proper type, or not at all, if so.

[enum] [emph Attention]. This example has the issue of passing result structures by value
through the stack, and then packing a copy into a [type Tcl_Obj*] value.

While this is no trouble for structures as small as [type vec2] larger structures may pose
a problem.

[para] We will address this in the next section.

[list_end]

[para] Packages: [term critcl::cutil]
