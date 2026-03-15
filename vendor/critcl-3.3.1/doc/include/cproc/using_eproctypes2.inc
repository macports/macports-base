[subsection {Custom Types, Semi-trivial}]

A more involved custom argument type would be to map from Tcl strings
to some internal representation, like an integer code.

[para] The first example is taken from the [package tclyaml] package,
a binding to the [package libyaml] library. In a few places we have to
map readable names for block styles, scalar styles, etc. to the
internal enumeration.

[example {
    critcl::argtype yaml_sequence_style_t {
        if (!encode_sequence_style (interp, @@, &@A)) return TCL_ERROR;
    }

    ...

    critcl::ccode {
        static const char* ty_block_style_names [] = {
            "any", "block", "flow", NULL
        };

        static int
        encode_sequence_style (Tcl_Interp* interp, Tcl_Obj* style,
                               yaml_sequence_style_t* estyle)
        {
            int value;
            if (Tcl_GetIndexFromObj (interp, style, ty_block_style_names,
                                     "sequence style", 0, &value) != TCL_OK) {
                return 0;
            }
            *estyle = value;
            return 1;
        }
    }

    ...

    method sequence_start proc {
        pstring anchor
        pstring tag
        int implicit
        yaml_sequence_style_t style
    } ok {
        /* Syntax: <instance> seq_start <anchor> <tag> <implicit> <style> */
        ...
    }

    ...
}]

It should be noted that this code precedes the advent of the
supporting generator package [package critcl::emap]. using the
generator the definition of the mapping becomes much simpler:

[example {
    critcl::emap::def yaml_sequence_style_t {
        any   0
        block 1
        flow  2
    }
}]

Note that the generator will not only provide the conversions, but
also define the argument and result types needed for their use by
[cmd critcl::cproc].

Another example of such a semi-trivial argument type can be found in
the [package CRIMP] package, which defines a [type Tcl_ObjType] for
[term image] values. This not only provides a basic argument type for
any image, but also derived types which check that the image has a
specific format. Here we see for the first time non-integer arguments,
and the need to define the C types used for variables holding the C
level value, and the type of function parameters (Due to C promotion
rules we may need different types).

[example {
    critcl::argtype image {
        if (crimp_get_image_from_obj (interp, @@, &@A) != TCL_OK) {
            return TCL_ERROR;
        }
    } crimp_image* crimp_image*

    ...

        set map [list <<type>> $type]
        critcl::argtype image_$type [string map $map {
            if (crimp_get_image_from_obj (interp, @@, &@A) != TCL_OK) {
                return TCL_ERROR;
            }
            if (@A->itype != crimp_imagetype_find ("crimp::image::<<type>>")) {
                Tcl_SetObjResult (interp,
                                  Tcl_NewStringObj ("expected image type <<type>>",
                                                    -1));
                return TCL_ERROR;
            }
        }] crimp_image* crimp_image*

    ...
}]
