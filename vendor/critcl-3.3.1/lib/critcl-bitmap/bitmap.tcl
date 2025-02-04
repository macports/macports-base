## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# n/a

# CriTcl Utility Package for bitmap en- and decoder.
# Based on i-assoc.

package provide critcl::bitmap 1.1.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9     ; # Min supported version.
package require critcl 3.2
package require critcl::iassoc

namespace eval ::critcl::bitmap {}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

proc critcl::bitmap::def {name dict {exclusions {}}} {
    # dict: Tcl symbolic name -> (C bit-mask (1))
    #
    # (Ad 1) Can be numeric, or symbolic, as long as it is a C int
    #        expression in the end.
    #
    # (Ad exclusions)
    #        Excluded bit-masks cannot be converted back to Tcl
    #        symbols. These are usually masks with multiple bits
    #        set. Conversion back delivers the individual elements
    #        instead of the combined mask.
    #
    #        If no exclusions are specified the generated code is
    #        simpler, i.e. not containing anything for dealing with
    #        exclusions at runtime.

    # For the C level opt array we want the elements sorted alphabetically.
    set symbols [lsort -dict [dict keys $dict]]
    set i 0
    foreach s $symbols {
	set id($s) $i
	incr i
    }
    set last $i

    set hasexcl [llength $exclusions]
    set excl {}
    foreach e $exclusions {
	dict set excl $e .
    }

    dict for {sym mask} $dict {
	set receivable [expr {![dict exists $excl $mask]}]

	set map [list @ID@ $id($sym) @SYM@ $sym @MASK@ $mask @RECV@ $receivable]

	if {$hasexcl} {
	    append init \n[critcl::at::here!][string map $map {
		data->c    [@ID@] = "@SYM@";
		data->mask [@ID@] = @MASK@;
		data->recv [@ID@] = @RECV@;
		data->tcl  [@ID@] = Tcl_NewStringObj ("@SYM@", -1);
		Tcl_IncrRefCount (data->tcl [@ID@]);
	    }]
	} else {
	    append init \n[critcl::at::here!][string map $map {
		data->c    [@ID@] = "@SYM@";
		data->mask [@ID@] = @MASK@;
		data->tcl  [@ID@] = Tcl_NewStringObj ("@SYM@", -1);
		Tcl_IncrRefCount (data->tcl [@ID@]);
	    }]
	}

	append final \n[critcl::at::here!][string map $map {
	    Tcl_DecrRefCount (data->tcl [@ID@]);
	}]
    }
    append init \n "    data->c \[$last\] = NULL;"

    lappend map @NAME@  $name
    lappend map @UNAME@ [string toupper $name]
    lappend map @LAST@  $last

    # I. Generate a header file for inclusion by other parts of the
    #    package, i.e. csources. Include the header here as well, for
    #    the following blocks of code.
    #
    #    Declaration of the en- and decoder functions.

    critcl::include [critcl::make ${name}.h \n[critcl::at::here!][string map $map {
	#ifndef @NAME@_HEADER
	#define @NAME@_HEADER

	/* Encode a flag list into the corresponding bitset */
	extern int
	@NAME@_encode (Tcl_Interp* interp,
		       Tcl_Obj*    flags,
		       int*        result);

	/* Decode a bitset into the corresponding flag list */
	extern Tcl_Obj*
	@NAME@_decode (Tcl_Interp* interp,
		       int         mask);

	#endif
    }]]

    # II: Generate the interp association holding the various
    #     conversion maps.

    if {$hasexcl} {
	critcl::iassoc def ${name}_iassoc {} \n[critcl::at::here!][string map $map {
	    const char*    c    [@LAST@+1]; /* Bit name, C string */
	    Tcl_Obj*       tcl  [@LAST@];   /* Bit name, Tcl_Obj*, sharable */
	    int            mask [@LAST@];   /* Bit mask */
	    int            recv [@LAST@];   /* Flag, true for receivable event */
	}] $init $final
    } else {
	critcl::iassoc def ${name}_iassoc {} \n[critcl::at::here!][string map $map {
	    const char*    c    [@LAST@+1]; /* Bit name, C string */
	    Tcl_Obj*       tcl  [@LAST@];   /* Bit name, Tcl_Obj*, sharable */
	    int            mask [@LAST@];   /* Bit mask */
	}] $init $final
    }

    # III: Generate encoder function: Conversion of list of flag names
    #      into corresponding bitset.

    critcl::ccode \n[critcl::at::here!][string map $map {
	int
	@NAME@_encode (Tcl_Interp* interp,
		       Tcl_Obj*    flags,
		       int*        result)
	{
	    @NAME@_iassoc_data context = @NAME@_iassoc (interp);
	    Tcl_Size lc, i;
	    int mask, id;
	    Tcl_Obj** lv;

	    if (Tcl_ListObjGetElements (interp, flags, &lc, &lv) != TCL_OK) { /* OK tcl9 */
		return TCL_ERROR;
	    }

	    mask = 0;
	    for (i = 0; i < lc; i++)  {
		if (Tcl_GetIndexFromObj (interp, lv[i], context->c, "@NAME@", 0,
					 &id) != TCL_OK) {
		    Tcl_SetErrorCode (interp, "@UNAME@", "FLAG", NULL);
		    return TCL_ERROR;
		}
		mask |= context->mask [id];
	    }

	    *result = mask;
	    return TCL_OK;
	}
    }]

    # IV: Generate decoder function: Convert bitset into the
    #     corresponding list of flag names.

    if {$hasexcl} {
	critcl::ccode \n[critcl::at::here!][string map $map {
	    Tcl_Obj*
	    @NAME@_decode (Tcl_Interp* interp, int mask)
	    {
		int i;
		@NAME@_iassoc_data context = @NAME@_iassoc (interp);
		Tcl_Obj*           res     = Tcl_NewListObj (0, NULL);

		for (i = 0; i < @LAST@; i++)  {
		    if (!context->recv[i])          continue;
		    if (!(mask & context->mask[i])) continue;
		    (void) Tcl_ListObjAppendElement (interp, res, context->tcl [i]);
		}
		return res;
	    }
	}]
    } else {
	critcl::ccode \n[critcl::at::here!][string map $map {
	    Tcl_Obj*
	    @NAME@_decode (Tcl_Interp* interp, int mask)
	    {
		int i;
		@NAME@_iassoc_data context = @NAME@_iassoc (interp);
		Tcl_Obj*           res     = Tcl_NewListObj (0, NULL);

		for (i = 0; i < @LAST@; i++)  {
		    if (!(mask & context->mask[i])) continue;
		    (void) Tcl_ListObjAppendElement (interp, res, context->tcl [i]);
		}
		return res;
	    }
	}]
    }

    # V. Define convenient argument- and result-type definitions
    #    wrapping the de- and encoder functions for use by cprocs.

    critcl::argtype $name \n[critcl::at::here!][string map $map {
	if (@NAME@_encode (interp, @@, &@A) != TCL_OK) return TCL_ERROR;
    }] int int

    critcl::resulttype $name \n[critcl::at::here!][string map $map {
	/* @NAME@_decode result is 0-refcount */
	Tcl_SetObjResult (interp, @NAME@_decode (interp, rv));
	return TCL_OK;
    }] int
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::bitmap {
    namespace export def
    catch { namespace ensemble create }
}

namespace eval ::critcl {
    namespace export bitmap
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
