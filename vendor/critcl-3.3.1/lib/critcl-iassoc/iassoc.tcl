## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# @mdgen OWNER: iassoc.h

# CriTcl Utility Commands. Specification of a C function and structure
# associated with an interpreter made easy.

package provide critcl::iassoc 1.2.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9  ; # Min supported version.
package require critcl 3.1.13 ; # Need 'meta?' to get the package name.
                                # Need 'Deline' helper.
package require critcl::util  ; # Use the package's Get/Put commands.

namespace eval ::critcl::iassoc {}

# # ## ### ##### ######## ############# #####################
## API: Generate the declaration and implementation files for the iassoc.

proc ::critcl::iassoc::def {name arguments struct constructor destructor} {
    critcl::at::caller
    critcl::at::incrt $arguments   ; set sloc [critcl::at::get*]
    critcl::at::incrt $struct      ; set cloc [critcl::at::get*]
    critcl::at::incrt $constructor ; set dloc [critcl::at::get]

    set struct      $sloc$struct
    set constructor $cloc$constructor
    set destructor  $dloc$destructor

    # Arguments:
    # - name of the C function which will provide access to the
    #   structure. This name, with a fixed prefix is also used to
    #   identify the association within the interpreter, and for
    #   the structure's type.
    #
    # - C code declaring the structure's contents.
    # - C code executed to initialize the structure.
    # - C code executed to destroy the structure.

    # Note that this is, essentially, a singleton object, without
    # methods.

    # Pull the package we are working on out of the system.

    set package  [critcl::meta? name]
    set qpackage [expr {[string match ::* $package]
			? "$package"
			: "::$package"}]
    lassign [uplevel 1 [list ::critcl::name2c $qpackage]] pns pcns package cpackage

    #puts "%%% pNS  |$pns|"
    #puts "%%% Pkg  |$package|"
    #puts "%%% pCNS |$pcns|"
    #puts "%%% cPkg |$cpackage|"
    #puts "%%% Name |$name|"
    #puts "@@@ <<$data>>"

    set stem  ${pcns}${cpackage}_iassoc_${name}
    set type  ${name}_data
    set label critcl::iassoc/p=$package/a=$name

    set anames {}
    if {[llength $arguments]} {
	foreach {t v} $arguments {
	    lappend alist "$t $v"
	    lappend anames $v
	}
	set arguments ", [join $alist {, }]"
	set anames ", [join $anames {, }]"
    }

    lappend map "\t" {}
    lappend map @package@     $package
    lappend map @name@        $name
    lappend map @stem@        $stem
    lappend map @label@       $label
    lappend map @type@        $type
    lappend map @struct@      $struct
    lappend map @argdecls@    $arguments
    lappend map @argnames@    $anames
    lappend map @constructor@ $constructor
    lappend map @destructor@  $destructor

    #puts T=[string length $template]

    critcl::include [critcl::make ${name}.h \n[critcl::at::here!][string map $map {
	#ifndef @name@_HEADER
	#define @name@_HEADER

	#include <tcl.h>

	typedef struct @type@__ {
	@struct@
	} @type@__;
	typedef struct @type@__* @type@;

	extern @type@
	@name@ (Tcl_Interp* interp@argdecls@);

	#endif
    }]]

    # Note: Making the .c code a `csources` instead of including it
    # directly is a backward incompatible API change (The C code does
    # not see any preceding includes. Which may define things used
    # in/by the user's constructor. Breaks the users of iassoc, like
    # bitmap, emap, etc. -- change defered --
    critcl::include [critcl::make ${name}.c \n[critcl::at::here!][string map $map {
	/*
	 * For package "@package@".
	 * Implementation of Tcl Interpreter Association "@name@".
	 *
	 * Support functions for structure creation and destruction.
	 */

	static void
	@stem@_Release (@type@ data, Tcl_Interp* interp)
	{
	    @destructor@
	    ckfree((char*) data);
	}

	static @type@
	@stem@_Init (Tcl_Interp* interp@argdecls@)
	{
	    @type@ data = (@type@) ckalloc (sizeof (@type@__));

	    @constructor@
	    return data;

	error:
	    ckfree ((char*) data);
	    return NULL;
	}

	/*
	 * Structure accessor, automatically creating it if the
	 * interpreter does not have it already, setting it up for
	 * destruction on interpreter shutdown.
	 */

	@type@
	@name@ (Tcl_Interp* interp@argdecls@)
	{
	    #define KEY "@label@"

	    Tcl_InterpDeleteProc* proc = (Tcl_InterpDeleteProc*) @stem@_Release;
	    @type@ data;

	    data = Tcl_GetAssocData (interp, KEY, &proc);
	    if (data) {
		return data;
	    }

	    data = @stem@_Init (interp@argnames@);

	    if (data) {
		Tcl_SetAssocData (interp, KEY, proc, (ClientData) data);
	    }

	    return data;
	    #undef KEY
	}
    }]]
    return
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::iassoc {
    namespace export def
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
