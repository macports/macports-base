## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# n/a

# CriTcl Utility Package for Shared Tcl_Obj* literals of a package.
# Based on critcl::iassoc.
#
# Copyright (c) 20??-2023 Andreas Kupries <andreas_kupries@users.sourceforge.net>

package provide critcl::literals 1.4.1

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9   ; # Min supported version.
package require critcl 3.1.11  ; # make, include -- dict portability
package require critcl::iassoc

namespace eval ::critcl::literals {}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

proc critcl::literals::def {name dict {use tcl}} {
    # dict :: map (C symbolic name -> string)
    Use $use
    Header             $name $dict

    C ConstStringTable $name $dict
    C AccessorC        $name

    Tcl Iassoc         $name $dict
    Tcl AccessorTcl    $name
    Tcl ResultType     $name

    +List AccessorTcl+List $name
    return
}

# # ## ### ##### ######## ############# #####################
## Internals

proc critcl::literals::Use {use} {
    # Use cases: tcl, c, both, +list-mode
    upvar 1 mode mode
    set uses 0
    foreach u {c tcl +list} { set mode($u) 0 }
    foreach u $use    { set mode($u) 1 ; incr uses }
    # +list-mode is an extension of tcl mode, thus implies it
    if {$mode(+list)} { set mode(tcl) 1 }
    if {$uses} return
    return -code error "Need at least one use case (c, +list, or tcl)"
}

proc critcl::literals::ConstStringTable {name dict} {
    # C level table initialization (constant data)
    dict for {sym string} $dict {
	append ctable "\n\t\"${string}\","
    }
    append ctable "\n\t0"

    lappend map @NAME@    $name
    lappend map @STRINGS@ $ctable
    critcl::ccode [critcl::at::here!][string map $map {
	static const char* @NAME@_literal[] = {
	    @STRINGS@
	};
    }]
    return
}

proc critcl::literals::Iassoc {name dict} {
    upvar 1 mode mode
    lappend map @NAME@  $name
    critcl::iassoc def ${name}_iassoc {} \n[critcl::at::here!][string map $map {
	/* Array of the string literals, indexed by the symbolic names */
	Tcl_Obj* literal [@NAME@_name_LAST];
    }] [IassocInit $name $dict] [IassocFinal $dict]
    return
}

proc critcl::literals::IassocFinal {dict} {
    # Finalization code for iassoc structures
    dict for {sym string} $dict {
	append final "\n[critcl::at::here!]\n\tTcl_DecrRefCount (data->literal \[$sym\]);"
    }
    return $final
}

proc critcl::literals::IassocInit {name dict} {
    # Initialization code for iassoc structures.
    # Details dependent on if C is supported together with Tcl, or not.
    upvar 1 mode mode
    return [C IassocInitWithC $name $dict][!C IassocInitTcl $dict]
}

proc critcl::literals::IassocInitWithC {name dict} {
    dict for {sym string} $dict {
	set map [list @SYM@ $sym @NAME@ $name]
	append init \n[critcl::at::here!][string map $map {
	    data->literal [@SYM@] = Tcl_NewStringObj (@NAME@_literal[@SYM@], -1);
	    Tcl_IncrRefCount (data->literal [@SYM@]);
	}]
    }
    return $init
}

proc critcl::literals::IassocInitTcl {dict} {
    dict for {sym string} $dict {
	set map [list @SYM@ $sym @STR@ $string]
	append init \n[critcl::at::here!][string map $map {
	    data->literal [@SYM@] = Tcl_NewStringObj ("@STR@", -1);
	    Tcl_IncrRefCount (data->literal [@SYM@]);
	}]
    }
    return $init
}

proc critcl::literals::Header {name dict} {
    # I. Generate a header file for inclusion by other parts of the
    #    package, i.e. csources. Include the header here as well, for
    #    the following blocks of code.
    #
    #    Declarations of an enum of the symbolic names, plus the
    #    accessor function.
    upvar 1 mode mode
    append h [HeaderIntro          $name $dict]
    append h [Tcl HeaderTcl        $name]
    append h [+List HeaderTcl+List $name]
    append h [C HeaderC            $name]
    append h [HeaderEnd            $name]
    critcl::include [critcl::make ${name}.h $h]
    return
}

proc critcl::literals::HeaderIntro {name dict} {
    lappend map @NAME@  $name
    lappend map @CODES@ [join [dict keys $dict] {, }]
    return \n[critcl::at::here!][string map $map {
	#ifndef @NAME@_LITERALS_HEADER
	#define @NAME@_LITERALS_HEADER

	#include <tcl.h>

	/* Symbolic names for the literals */
	typedef enum @NAME@_names {
	    @CODES@
	    , @NAME@_name_LAST
	} @NAME@_names;
    }]
}

proc critcl::literals::HeaderEnd {name} {
    lappend map @NAME@ $name
    return [string map $map {
	#endif /* @NAME@_LITERALS_HEADER */
    }]
}

proc critcl::literals::HeaderTcl {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* Tcl Accessor function for the literals */
	extern Tcl_Obj*
	@NAME@ (Tcl_Interp* interp, @NAME@_names literal);
    }]
}

proc critcl::literals::HeaderTcl+List {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* Tcl "+list" Accessor function for the literals */
	extern Tcl_Obj*
	@NAME@_list (Tcl_Interp* interp, int c, @NAME@_names* literal);
    }]
}

proc critcl::literals::HeaderC {name} {
    lappend map @NAME@ $name
    return \n[critcl::at::here!][string map $map {
	/* C Accessor function for the literals */
	extern const char* @NAME@_cstr (@NAME@_names literal);
    }]
}

proc critcl::literals::ResultType {name} {
    lappend map @NAME@ $name
    critcl::resulttype $name \n[critcl::at::here!][string map $map {
	/* @NAME@ result is effectively 0-refcount */
	Tcl_SetObjResult (interp, @NAME@ (interp, rv));
	return TCL_OK;
    }] int
}

proc critcl::literals::AccessorTcl {name} {
    lappend map @NAME@ $name
    critcl::ccode [critcl::at::here!][string map $map {
	Tcl_Obj*
	@NAME@ (Tcl_Interp* interp, @NAME@_names literal)
	{
	    if ((literal < 0) || (literal >= @NAME@_name_LAST)) {
		Tcl_Panic ("Bad @NAME@ literal index %d outside [0...%d]",
			   literal, @NAME@_name_LAST-1);
	    }
	    return @NAME@_iassoc (interp)->literal [literal];
	}
    }]
    return
}

proc critcl::literals::AccessorTcl+List {name} {
    lappend map @NAME@ $name
    critcl::ccode [critcl::at::here!][string map $map {
	Tcl_Obj*
	@NAME@_list (Tcl_Interp* interp, int c, @NAME@_names* literal)
	{
	    int k;
	    for (k=0; k < c; k++) {
		if ((literal[k] < 0) || (literal[k] >= @NAME@_name_LAST)) {
		    Tcl_Panic ("Bad @NAME@ literal index %d outside [0...%d]",
			       literal[k], @NAME@_name_LAST-1);
		}
	    }

	    Tcl_Obj* result = Tcl_NewListObj (0, 0);
	    if (!result) return result;

	    for (k=0; k < c; k++) {
		if (TCL_OK == Tcl_ListObjAppendElement (interp, result, @NAME@_iassoc (interp)->literal [literal [k]]))
		    continue;
		/* Failed to append, release and abort */
		Tcl_DecrRefCount (result);
		return 0;
	    }

	    return result;
	}
    }]
    return
}

proc critcl::literals::AccessorC {name} {
    upvar 1 mode mode
    return [Tcl AccessorCWithTcl $name][!Tcl AccessorCRaw $name]
}

proc critcl::literals::AccessorCWithTcl {name} {
    # C accessor can use Tcl API
    lappend map @NAME@ $name
    critcl::ccode [critcl::at::here!][string map $map {
	const char*
	@NAME@_cstr (@NAME@_names literal)
	{
	    if ((literal < 0) || (literal >= @NAME@_name_LAST)) {
		Tcl_Panic ("Bad @NAME@ literal");
	    }
	    return @NAME@_literal [literal];
	}
    }]
    return
}

proc critcl::literals::AccessorCRaw {name} {
    # C accessor has only basics
    lappend map @NAME@ $name
    critcl::ccode [critcl::at::here!][string map $map {
	#include <assert.h>
	const char*
	@NAME@_cstr (@NAME@_names literal)
	{
	    assert ((0 <= literal) && (literal < @NAME@_name_LAST));
	    return @NAME@_literal [literal];
	}
    }]
    return
}

proc critcl::literals::C {args} {
    upvar 1 mode mode
    if {!$mode(c)} return
    return [uplevel 1 $args]
}

proc critcl::literals::!C {args} {
    upvar 1 mode mode
    if {$mode(c)} return
    return [uplevel 1 $args]
}

proc critcl::literals::Tcl {args} {
    upvar 1 mode mode
    if {!$mode(tcl)} return
    return [uplevel 1 $args]
}

proc critcl::literals::!Tcl {args} {
    upvar 1 mode mode
    if {$mode(tcl)} return
    return [uplevel 1 $args]
}

proc critcl::literals::+List {args} {
    upvar 1 mode mode
    if {!$mode(+list)} return
    return [uplevel 1 $args]
}

proc critcl::literals::!+List {args} {
    upvar 1 mode mode
    if {$mode(+list)} return
    return [uplevel 1 $args]
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::literals {
    namespace export def
    catch { namespace ensemble create }
}

namespace eval ::critcl {
    namespace export literals
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
