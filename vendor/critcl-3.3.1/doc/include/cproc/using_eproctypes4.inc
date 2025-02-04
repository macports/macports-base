[subsection {Custom Types, Results}]

All of the previous sections dealt with argument conversions,
i.e. going from Tcl into C.

Custom result types are for the reverse direction, from C to Tcl.

This is usually easier, as most of the time errors should not be
possible. Supporting structures, or allocating them on the heap are
not really required and therefore not supported.

[para] The example of a result type shown below was pulled from
[package KineTcl]. It is a variant of the builtin result type
[type Tcl_Obj*], aka [type object]. The builtin conversion assumes
that the object returned by the function has a refcount of 1 (or
higher), with the function having held the reference, and releases
that reference after placing the value into the interp result. The
conversion below on the other hand assumes that the value has a
refcount of 0 and thus that decrementing it is forbidden, lest it be
released much to early, and crashing the system.

[example {
    critcl::resulttype KTcl_Obj* {
        if (rv == NULL) { return TCL_ERROR; }
        Tcl_SetObjResult(interp, rv);
        /* No refcount adjustment */
        return TCL_OK;
    } Tcl_Obj*
}]

This type of definition is also found in [package Marpa] and recent
hacking hacking on [package CRIMP] introduced it there as well. Which
is why this definition became a builtin type starting with version
3.1.16, under the names [type Tcl_Obj*0] and [type object0].

[para] Going back to errors and their handling, of course, if a
function we are wrapping signals them in-band, then the conversion of
such results has to deal with that. This happens for example in
[package KineTcl], where we find

[example {
    critcl::resulttype XnStatus {
        if (rv != XN_STATUS_OK) {
            Tcl_AppendResult (interp, xnGetStatusString (rv), NULL);
            return TCL_ERROR;
        }
        return TCL_OK;
    }

    critcl::resulttype XnDepthPixel {
        if (rv == ((XnDepthPixel) -1)) {
            Tcl_AppendResult (interp,
                              "Inheritance error: Not a depth generator",
                              NULL);
            return TCL_ERROR;
        }
        Tcl_SetObjResult (interp, Tcl_NewIntObj (rv));
        return TCL_OK;
    }
}]
