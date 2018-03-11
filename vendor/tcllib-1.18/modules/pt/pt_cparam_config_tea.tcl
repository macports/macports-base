# -*- tcl -*-
# Copyright (c) 2014 Christian Gollwitzer <auriocus@gmx.de>

# TODO: Refactor this and pt::cparam::configuration::critcl to avoid
# TODO: duplication of the supporting code (creation of the RDE
# TODO: amalgamation, basic C template).

# Canned configuration for the converter to C/PARAM representation,
# causing generation of a C-based parser which can be plugged into a
# TEA-based C extension. The supporting files, i.e. configure.in,
# Makefile.in, etc. still have to be written separately, and manually.

# The generated file can easily be compiled with a single
#
#     gcc -dynamiclib -o <parser>.dylib <parser>.c -DUSE_TCL_STUBS -ltclstub8.5
#
# or similar, or included in a larger package, if added to the source
# files and by invoking the <parser>_Init() function within the init
# function of the main package.
#
# TODO: Put the above note/semi-example into the manpage for this generator.

# # ## ### ##### ######## ############# #####################
## Requirements

package require Tcl 8.5              ; # Required runtime.

# # ## ### ##### ######## ############# #####################
##

namespace eval ::pt::cparam::configuration::tea {
    namespace export   def
    namespace ensemble create

    # @mdgen OWNER: rde_critcl/util.*
    # @mdgen OWNER: rde_critcl/stack.*
    # @mdgen OWNER: rde_critcl/tc.*
    # @mdgen OWNER: rde_critcl/param.*
    # Access to the rde_critcl files forming the low-level runtime
    variable selfdir [file dirname [file normalize [info script]]]
}

# # ## ### ##### ######## #############
## Public API

# Check that the proposed serialization of an abstract syntax tree is
# indeed such.

proc ::pt::cparam::configuration::tea::def {class pkg version cmd} {
    # TODO :: See if we can consolidate the API for converters,
    # TODO :: plugins, export manager, and container in some way.
    # TODO :: Container may make exporter manager available through
    # TODO :: public method.

    # class   = The namespace/prefix for the generated commands.
    # pkg     = The name of the generated package / parser.
    # version = The version of the generated package / parser.

    if {[string first :: $class] < 0} {
	set cheader  $class
	set ctrailer $class
    } else {
	set cheader  [namespace qualifier $class]
	set ctrailer [namespace tail      $class]
    }

    set pkghead [string range $pkg 0 0]
    set pkgtail [string range $pkg 1 end]
    set pkglowcase "[string toupper $pkghead][string tolower $pkgtail]"

    lappend map	@@RUNTIME@@ [GetRuntime]
    lappend map	@@PKG@@     $pkg
    lappend map	@@PKGLOWCASE@@     $pkglowcase
    lappend map	@@VERSION@@ $version
    lappend map	@@CLASS@@   $class
    lappend map	@@CHEAD@@   $cheader
    lappend map	@@CTAIL@@   $ctrailer
    lappend map	\n\t        \n ;# undent the template

    {*}$cmd -main      MAIN
    {*}$cmd -indent    8
    {*}$cmd -template  [string trim \
			    [string map $map {
	/************************************************************
	**
	** TEA-based C/PARAM implementation of the parsing
	** expression grammar
	**
	**	@name@
	**
	** Generated from file	@file@
	**            for user  @user@
	**
	* * ** *** ***** ******** ************* *********************/
		#include <string.h>
		#include <tcl.h>
		#include <stdlib.h>
		#include <ctype.h>
		#define SCOPE static

@@RUNTIME@@
@code@
		/* -*- c -*- */

		typedef struct PARSERg {
		    long int counter;
		    char     buf [50];
		} PARSERg;

		static void
		PARSERgRelease (ClientData cd, Tcl_Interp* interp)
		{
		    ckfree((char*) cd);
		}

		static const char*
		PARSERnewName (Tcl_Interp* interp)
		{
#define KEY "tcllib/parser/@@PKG@@/TEA"

		    Tcl_InterpDeleteProc* proc = PARSERgRelease;
		    PARSERg*                  parserg;

		    parserg = Tcl_GetAssocData (interp, KEY, &proc);
		    if (parserg  == NULL) {
			parserg = (PARSERg*) ckalloc (sizeof (PARSERg));
			parserg->counter = 0;

			Tcl_SetAssocData (interp, KEY, proc,
					  (ClientData) parserg);
		    }

		    parserg->counter ++;
		    sprintf (parserg->buf, "@@CTAIL@@%ld", parserg->counter);
		    return parserg->buf;
#undef  KEY
		}

		static void
		PARSERdeleteCmd (ClientData clientData)
		{
		    /*
		     * Release the whole PARSER
		     * (Low-level engine only actually).
		     */
		    rde_param_del ((RDE_PARAM) clientData);
		}
	    

	    /* * ** *** ***** ******** *************
	    ** Functions implementing the object methods, and helper.
	    */

		static int  COMPLETE (RDE_PARAM p, Tcl_Interp* interp);

		static int parser_PARSE  (RDE_PARAM p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
		{
		    int mode;
		    Tcl_Channel chan;

		    if (objc != 3) {
			Tcl_WrongNumArgs (interp, 2, objv, "chan");
			return TCL_ERROR;
		    }

		    chan = Tcl_GetChannel(interp,
					  Tcl_GetString (objv[2]),
					  &mode);

		    if (!chan) {
			return TCL_ERROR;
		    }

		    rde_param_reset (p, chan);
		    MAIN (p) ; /* Entrypoint for the generated code. */
		    return COMPLETE (p, interp);
		}

		static int parser_PARSET (RDE_PARAM p, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
		{
		    char* buf;
		    int   len;

		    if (objc != 3) {
			Tcl_WrongNumArgs (interp, 2, objv, "text");
			return TCL_ERROR;
		    }

		    buf = Tcl_GetStringFromObj (objv[2], &len);

		    rde_param_reset (p, NULL);
		    rde_param_data  (p, buf, len);
		    MAIN (p) ; /* Entrypoint for the generated code. */
		    return COMPLETE (p, interp);
		}

		/* See also rde_critcl/m.c, param_COMPLETE() */
		static int COMPLETE (RDE_PARAM p, Tcl_Interp* interp)
		{
		    if (rde_param_query_st (p)) {
			long int  ac;
			Tcl_Obj** av;

			rde_param_query_ast (p, &ac, &av);

			if (ac > 1) {
			    Tcl_Obj** lv = NALLOC (3+ac, Tcl_Obj*);

			    memcpy(lv + 3, av, ac * sizeof (Tcl_Obj*));
			    lv [0] = Tcl_NewObj ();
			    lv [1] = Tcl_NewIntObj (1 + rde_param_query_lstop (p));
			    lv [2] = Tcl_NewIntObj (rde_param_query_cl (p));

			    Tcl_SetObjResult (interp, Tcl_NewListObj (3, lv));
			    ckfree ((char*) lv);

			} else if (ac == 0) {
			    /*
			     * Match, but no AST. This is possible if the grammar
			     * consists of only the start expression.
			     */
			    Tcl_SetObjResult (interp, Tcl_NewStringObj ("",-1));
			} else {
			    Tcl_SetObjResult (interp, av [0]);
			}

			return TCL_OK;
		    } else {
			Tcl_Obj* xv [1];
			const ERROR_STATE* er = rde_param_query_er (p);
			Tcl_Obj* res = rde_param_query_er_tcl (p, er);
			/* res = list (location, list(msg)) */

			/* Stick the exception type-tag before the existing elements */
			xv [0] = Tcl_NewStringObj ("pt::rde",-1);
			Tcl_ListObjReplace(interp, res, 0, 0, 1, xv);

			Tcl_SetErrorCode (interp, "PT", "RDE", "SYNTAX", NULL);
			Tcl_SetObjResult (interp, res);
			return TCL_ERROR;
		    }
		}
	    

	    /* * ** *** ***** ******** *************
	    ** Object command, method dispatch.
	    */
		static int parser_objcmd (ClientData cd, Tcl_Interp* interp, int objc, Tcl_Obj* CONST* objv)
		{
		    RDE_PARAM p = (RDE_PARAM) cd;
		    int m, res;

		    static CONST char* methods [] = {
			"destroy", "parse", "parset", NULL
		    };
		    enum methods {
			M_DESTROY, M_PARSE, M_PARSET
		    };

		    if (objc < 2) {
			Tcl_WrongNumArgs (interp, objc, objv, "option ?arg arg ...?");
			return TCL_ERROR;
		    } else if (Tcl_GetIndexFromObj (interp, objv [1], methods, "option",
						    0, &m) != TCL_OK) {
			return TCL_ERROR;
		    }

		    /* Dispatch to methods. They check the #args in
		     * detail before performing the requested
		     * functionality
		     */

		    switch (m) {
			case M_DESTROY:
			    if (objc != 2) {
				Tcl_WrongNumArgs (interp, 2, objv, NULL);
				return TCL_ERROR;
			    }

			Tcl_DeleteCommandFromToken(interp, (Tcl_Command) rde_param_query_clientdata (p));
			return TCL_OK;

			case M_PARSE:	res = parser_PARSE  (p, interp, objc, objv); break;
			case M_PARSET:	res = parser_PARSET (p, interp, objc, objv); break;
			default:
			/* Not coming to this place */
			ASSERT (0,"Reached unreachable location");
		    }

		    return res;
		}

	    /** * ** *** ***** ******** *************
	    * Class command, i.e. object construction.
	    */
	    static int ParserClassCmd (ClientData dummy, Tcl_Interp *interp, int objc, Tcl_Obj * const*objv) {
		/*
		 * Syntax: No arguments beyond the name
		 */

		RDE_PARAM   parser;
		CONST char* name;
		Tcl_Obj*    fqn;
		Tcl_CmdInfo ci;
		Tcl_Command c;

#define USAGE "?name?"

		if ((objc != 2) && (objc != 1)) {
		    Tcl_WrongNumArgs (interp, 1, objv, USAGE);
		    return TCL_ERROR;
		}

		if (objc < 2) {
		    name = PARSERnewName (interp);
		} else {
		    name = Tcl_GetString (objv [1]);
		}

		if (!Tcl_StringMatch (name, "::*")) {
		    /* Relative name. Prefix with current namespace */

		    Tcl_Eval (interp, "namespace current");
		    fqn = Tcl_GetObjResult (interp);
		    fqn = Tcl_DuplicateObj (fqn);
		    Tcl_IncrRefCount (fqn);

		    if (!Tcl_StringMatch (Tcl_GetString (fqn), "::")) {
			Tcl_AppendToObj (fqn, "::", -1);
		    }
		    Tcl_AppendToObj (fqn, name, -1);
		} else {
		    fqn = Tcl_NewStringObj (name, -1);
		    Tcl_IncrRefCount (fqn);
		}
		Tcl_ResetResult (interp);

		if (Tcl_GetCommandInfo (interp,
					Tcl_GetString (fqn),
					&ci)) {
		    Tcl_Obj* err;

		    err = Tcl_NewObj ();
		    Tcl_AppendToObj    (err, "command \"", -1);
		    Tcl_AppendObjToObj (err, fqn);
		    Tcl_AppendToObj    (err, "\" already exists", -1);

		    Tcl_DecrRefCount (fqn);
		    Tcl_SetObjResult (interp, err);
		    return TCL_ERROR;
		}

		parser = rde_param_new (sizeof(p_string)/sizeof(char*), (char**) p_string);
		c = Tcl_CreateObjCommand (interp, Tcl_GetString (fqn),
					  parser_objcmd, (ClientData) parser,
					  PARSERdeleteCmd);
		rde_param_clientdata (parser, (ClientData) c);
		Tcl_SetObjResult (interp, fqn);
		Tcl_DecrRefCount (fqn);
		return TCL_OK;
	    }
    
	int @@PKGLOWCASE@@_Init(Tcl_Interp* interp) {
	    if (interp == 0) return TCL_ERROR;

	    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
		    return TCL_ERROR;
	    }

	    if (Tcl_CreateObjCommand(interp, "@@CLASS@@", ParserClassCmd , NULL, NULL) == NULL) {
		    Tcl_SetResult(interp, "Can't create constructor", NULL);
		    return TCL_ERROR;
	    }
	    
	    
	    Tcl_PkgProvide(interp, "@@PKG@@", "0.1");
	    
	    return TCL_OK;
	}

    }]]

    return
}

proc ::pt::cparam::configuration::tea::GetRuntime {} {
    # This is the C code for the RDE, i.e. the implementation of
    # pt::rde. Only the low-level engine is imported, the Tcl
    # interface layer is ignored.  This generated parser provides its
    # own layer for that.

    # We are inlining the code (making the functions static) to
    # prevent any conflict with the support for pt::rde, should both
    # be put into the same shared library.

    variable selfdir

    set code {}

    foreach f {
	rde_critcl/util.h
	rde_critcl/stack.h
	rde_critcl/tc.h
	rde_critcl/param.h
	rde_critcl/util.c
	rde_critcl/stack.c
	rde_critcl/tc.c
	rde_critcl/param.c
    } {
	# Load C code.
	set c [open $selfdir/$f]
	set d [read $c]
	close $c

	# Strip include directives and anything explicitly excluded.
	set skip 0
	set n {}
	foreach l [split $d \n] {
	    if {[string match {*#include*} $l]} {
		continue
	    }
	    if {[string match {*SKIP START*} $l]} {
		set skip 1
		continue
	    }
	    if {[string match {*SKIP END*} $l]} {
		set skip 0
		continue
	    }
	    if {$skip} continue
	    lappend n $l
	}
	set d [join $n \n]

	# Strip comments, trailing whitespace, empty lines.
	set d [regsub -all {/\*.*?\*/} $d {}]
	set d [regsub -all {//.*?\n}   $d {}]
	set d [regsub -all {[ 	]+$}   $d {}]
	while {1} {
	    set n [string map [list \n\n \n] $d]
	    if {$n eq $d} break
	    set d $n
	}

	# Indent code.
	lappend code "#line 1 \"$f\""
	foreach l [split $d \n] {
	    if {$l ne ""} { set l \t$l }
	    lappend code $l
	}
    }

    #lappend code "#line x \"X\""
    return [join $code \n]
}

# # ## ### ##### ######## #############

namespace eval ::pt::cparam::configuration::tea {}

# # ## ### ##### ######## ############# #####################
## Ready

package provide pt::cparam::configuration::tea 0.1
return
