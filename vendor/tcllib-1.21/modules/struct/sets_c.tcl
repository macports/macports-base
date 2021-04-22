#----------------------------------------------------------------------
#
# sets_tcl.tcl --
#
#       Definitions for the processing of sets. C implementation.
#
# Copyright (c) 2007 by Andreas Kupries.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: sets_c.tcl,v 1.3 2008/03/25 07:15:34 andreas_kupries Exp $
#
#----------------------------------------------------------------------

package require critcl
# @sak notprovided struct_setc
package provide struct_setc 2.1.1
package require Tcl 8.4

namespace eval ::struct {
    # Supporting code for the main command.

    catch {
        #critcl::cheaders -g
        #critcl::debug memory symbols
    }

    critcl::cheaders sets/*.h
    critcl::csources sets/*.c

    critcl::ccode {
        /* -*- c -*- */

        #include <m.h>
    }

    # Main command, set creation.

    critcl::ccommand set_critcl {dummy interp objc objv} {
	/* Syntax - dispatcher to the sub commands.
	 */

        static CONST char* methods [] = {
            "add",      "contains",     "difference",   "empty",
            "equal","exclude",  "include",      "intersect",
            "intersect3",       "size", "subsetof",     "subtract",
            "symdiff",  "union",
            NULL
        };
        enum methods {
            S_add,      S_contains,     S_difference,   S_empty,
            S_equal,S_exclude,  S_include,      S_intersect,
            S_intersect3,       S_size, S_subsetof,     S_subtract,
            S_symdiff,  S_union
        };

	int m;

        if (objc < 2) {
            Tcl_WrongNumArgs (interp, objc, objv, "cmd ?arg ...?");
            return TCL_ERROR;
        } else if (Tcl_GetIndexFromObj (interp, objv [1], methods, "option",
            0, &m) != TCL_OK) {
            return TCL_ERROR;
        }

        /* Dispatch to methods. They check the #args in detail before performing
         * the requested functionality
         */

        switch (m) {
            case S_add:        return sm_ADD        (NULL, interp, objc, objv);
            case S_contains:   return sm_CONTAINS   (NULL, interp, objc, objv);
            case S_difference: return sm_DIFFERENCE (NULL, interp, objc, objv);
            case S_empty:      return sm_EMPTY      (NULL, interp, objc, objv);
            case S_equal:      return sm_EQUAL      (NULL, interp, objc, objv);
            case S_exclude:    return sm_EXCLUDE    (NULL, interp, objc, objv);
            case S_include:    return sm_INCLUDE    (NULL, interp, objc, objv);
            case S_intersect:  return sm_INTERSECT  (NULL, interp, objc, objv);
            case S_intersect3: return sm_INTERSECT3 (NULL, interp, objc, objv);
            case S_size:       return sm_SIZE       (NULL, interp, objc, objv);
            case S_subsetof:   return sm_SUBSETOF   (NULL, interp, objc, objv);
            case S_subtract:   return sm_SUBTRACT   (NULL, interp, objc, objv);
            case S_symdiff:    return sm_SYMDIFF    (NULL, interp, objc, objv);
            case S_union:      return sm_UNION      (NULL, interp, objc, objv);
        }
        /* Not coming to this place */
    }
}

# ### ### ### ######### ######### #########
## Ready
