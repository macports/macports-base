# jsonc.tcl --
#
#       Implementation of a JSON parser in C.
#	Binding to a yacc/bison parser by Mikhail.
#
# Copyright (c) 2013,2015 - critcl wrapper - Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Copyright (c) 2013      - C binding      - mi+tcl.tk-2013@aldan.algebra.com

package require critcl
# @sak notprovided jsonc
package provide jsonc 1.1.2
package require Tcl 8.4

#critcl::cheaders -g
#critcl::debug memory symbols
critcl::cheaders -Ic c/*.h
critcl::csources c/*.c

# # ## ### Import base declarations, forwards ### ## # #

critcl::ccode {
    #include <json_y.h>
}

# # ## ### Main Conversion ### ## # #

namespace eval ::json {
    critcl::ccommand json2dict_critcl {dummy I objc objv} {
	struct context context = { NULL };

	if (objc != 2) {
	    Tcl_WrongNumArgs(I, 1, objv, "json");
	    return TCL_ERROR;
	}

	context.text   = Tcl_GetStringFromObj(objv[1], &context.remaining);
	context.I      = I;
	context.has_error = 0;
	context.result = TCL_ERROR;

	jsonparse (&context);
	return context.result;
    }

    # Issue with critcl 2 used here. Cannot use '-', incomplete distinction of C and Tcl names.
    # The json.tcl file making use of this code has a wrapper fixing the issue.
    critcl::ccommand many_json2dict_critcl {dummy I objc objv} {
	struct context context = { NULL };

	int                      max;
	int                      found;

	Tcl_Obj* result = Tcl_NewListObj (0, NULL);

	if ((objc < 2) || (objc > 3)) {
	    Tcl_WrongNumArgs(I, 1, objv, "jsonText ?max?");
	    return TCL_ERROR;
	}

	if (objc == 3) {
	    if (Tcl_GetIntFromObj(I, objv[2], &max) != TCL_OK) {
		return TCL_ERROR;
	    }
	    if (max <= 0) {
		Tcl_AppendResult (I, "Bad limit ",
				  Tcl_GetString (objv[2]),
				  " of json entities to extract.",
				  NULL);
		Tcl_SetErrorCode (I, "JSON", "BAD-LIMIT", NULL);
		return TCL_ERROR;
	    }

	} else {
	    max = -1;
	}

	context.text   = Tcl_GetStringFromObj(objv[1], &context.remaining);
	context.I      = I;
	context.has_error = 0;
	found  = 0;

	/* Iterate over the input until
	 * - we have gotten all requested values.
	 * - we have run out of input
	 * - we have run into an error
	 */

	while ((max < 0) || max) {
	    context.result = TCL_ERROR;
	    jsonparse (&context);

	    /* parse error, abort */
	    if (context.result != TCL_OK) {
		Tcl_DecrRefCount (result);
		return TCL_ERROR;
	    }

	    /* Proper value extracted, extend result */
	    found ++;
	    Tcl_ListObjAppendElement(I, result,
				     Tcl_GetObjResult (I));

	    /* Count down on the number of still missing
	     * values, if not asking for all (-1)
	     */
	    if (max > 0) max --;

	    /* Jump over trailing whitespace for proper end-detection */
	    jsonskip (&context);

	    /* Abort if we have consumed all input */
	    if (!context.remaining) break;

	    /* Clear scratch pad before continuing */
	    context.obj = NULL;
	}

	/* While all parses were ok we reached end of
	 * input without getting all requested values,
	 * this is an error
	 */
	if (max > 0) {
	    char buf [30];
	    sprintf (buf, "%d", found);
            Tcl_ResetResult (I);
	    Tcl_AppendResult (I, "Bad limit ",
			      Tcl_GetString (objv[2]),
			      " of json entities to extract, found only ",
			      buf,
			      ".",
			      NULL);
	    Tcl_SetErrorCode (I, "JSON", "BAD-LIMIT", "TOO", "LARGE", NULL);
	    Tcl_DecrRefCount (result);
	    return TCL_ERROR;
	}

	/* We are good and done */
	Tcl_SetObjResult(I, result);
	return TCL_OK;
    }

    if 0 {critcl::ccommand validate_critcl {dummy I objc objv} {
	struct context context = { NULL };

	if (objc != 2) {
	    Tcl_WrongNumArgs(I, 1, objv, "jsonText");
	    return TCL_ERROR;
	}

	context.text   = Tcl_GetStringFromObj(objv[1], &context.remaining);
	context.I      = I;
	context.result = TCL_ERROR;

	/* Iterate over the input until we have run
	 * out of text, or encountered an error. We
	 * use only the lexer here, and told it to not
	* create superfluous token values.
	 */

	while (context.remaining) {
	    if (jsonlex (&context) == -1) {
		Tcl_SetObjResult(I, Tcl_NewBooleanObj (0));
		return TCL_OK;
	    }
	}

	/* We are good and done */
	Tcl_SetObjResult(I, Tcl_NewBooleanObj (1));
	return TCL_OK;
    }}
}
