# -*- tcl -*-
# STUBS handling -- Reader.
#
# (c) 2011,2022-2023 Andreas Kupries http://wiki.tcl.tk/andreas%20kupries

# # ## ### ##### ######## #############
## Requisites

package require Tcl 8.6 9
package require stubs::container

# A stubs table is represented by a dictionary value.
# A container is a variable holding a stubs table value.

namespace eval ::stubs::reader::c {
    namespace import ::stubs::container::*
}

# # ## ### ##### ######## #############
## Implementation.

proc ::stubs::reader::file {tablevar path} {
    upvar 1 $tablevar table

    set chan [open $path r]
    set text [read $chan]
    close $chan

    text table $text
    return
}

proc ::stubs::reader::text {tablevar text} {
    variable current
    variable table

    upvar 1 $tablevar t

    set sandbox [interp create -safe]

    interp alias $sandbox library   {} ::stubs::reader::P_library
    interp alias $sandbox interface {} ::stubs::reader::P_interface
    interp alias $sandbox scspec    {} ::stubs::reader::P_scspec
    interp alias $sandbox epoch     {} ::stubs::reader::P_epoch
    interp alias $sandbox hooks     {} ::stubs::reader::P_hooks
    interp alias $sandbox declare   {} ::stubs::reader::P_declare
    interp alias $sandbox export    {} ::stubs::reader::P_export

    set current UNKNOWN
    set table $t

    set ::errorCode {}
    set ::errorInfo {}

    if {![set code [catch {
	$sandbox eval $text
    } res]]} {
	set t $table
    }

    interp delete $sandbox
    unset table

    return -code $code -errorcode $::errorCode -errorinfo $::errorInfo \
	$res
}

# READER API methods. These are called when sourcing a .decls
# file, or evaluating a .decls string. They forward to the
# attached container after pre-processing arguments and merging in
# state information (current interface).

proc ::stubs::reader::P_library {name} {
    variable table
    c::library table $name
    return
}

proc ::stubs::reader::P_interface {name} {
    variable table
    variable current

    set current $name
    c::interface table $name
    return
}

proc ::stubs::reader::P_scspec {value} {
    variable table
    c::scspec table $value
    return
}

proc ::stubs::reader::P_epoch {value} {
    variable table
    c::epoch table $value
    return
}

proc ::stubs::reader::P_hooks {names} {
    variable table
    variable current

    c::hooks table $current $names
    return
}

proc ::stubs::reader::P_declare {index args} {
    variable table
    variable current

    switch -exact [llength $args] {
	1 {
	    # syntax: declare AT DECL
	    set platforms [list generic]
	    set decl [lindex $args 0]
	}
	2 {
	    # syntax: declare AT PLATFORMS DECL
	    lassign $args platforms decl
	}
	default {
	    return -code error \
		"wrong \# args: expected 'index ?platforms? decl"
	}
    }

    c::declare table $current $index $platforms [ParseDecl $decl]
    return
}

proc ::stubs::reader::P_export {decl} {
    variable table
    variable current

    # Ignore.
    return
}

# Support methods for parsing a C declaration into its constituent
# pieces.

# ParseDecl --
#
#	Parse a C function declaration into its component parts.
#
# Arguments:
#	decl	The function declaration.
#
# Results:
#	Returns a list of the form {returnType name arguments}.  The arguments
#	element consists of a list of type/name pairs, or a single
#	element "void".  If the function declaration is malformed
#	then an error is displayed and the return value is {}.

proc ::stubs::reader::ParseDecl {decl} {
    #checker exclude warnArgWrite
    regsub -all "\[ \t\n\]+" [string trim $decl] " " decl
    #puts "PARSE ($decl)"

    if {![regexp {^(.*)\((.*)\)$} $decl --> prefix arguments]} {
	set prefix    $decl
	set arguments {}
    }

    set prefix [string trim $prefix]
    if {![regexp {^(.+[ ][*]*)([^ *]+)$} $prefix --> rtype fname]} {
	return -code error "Bad return type: $decl"
    }

    set rtype [string trim $rtype]
    if {$arguments eq ""} {
	return [list $rtype $fname {void}]
    }

    foreach arg [split $arguments ,] {
	lappend argumentList [string trim $arg]
    }

    if {[lindex $argumentList end] eq "..."} {
	set arguments TCL_VARARGS
	foreach arg [lrange $argumentList 0 end-1] {
	    set argInfo [ParseArg $arg]
	    set arity [llength $argInfo]
	    if {(2 <= $arity) && ($arity <= 3)} {
		lappend arguments $argInfo
	    } else {
		return -code error "Bad argument: '$arg' in '$decl'"
	    }
	}
    } else {
	set arguments {}
	foreach arg $argumentList {
	    set argInfo [ParseArg $arg]
	    if {$argInfo eq "void"} {
		lappend arguments "void"
		break
	    }
	    set arity [llength $argInfo]
	    if {(2 <= $arity) && ($arity <= 3)} {
		lappend arguments $argInfo
	    } else {
		return -code error "Bad argument: '$arg' in '$decl'"
	    }
	}
    }
    return [list $rtype $fname $arguments]
}

# ParseArg --
#
#	This function parses a function argument into a type and name.
#
# Arguments:
#	arg	The argument to parse.
#
# Results:
#	Returns a list of type and name with an optional third array
#	indicator.  If the argument is malformed, returns "".

proc ::stubs::reader::ParseArg {arg} {
    if {![regexp {^(.+[ ][*]*)([^][ *]+)(\[\])?$} $arg all type name array]} {
	if {$arg eq "void"} {
	    return $arg
	} else {
	    return
	}
    }
    set result [list [string trim $type] $name]
    if {$array ne ""} {
	lappend result $array
    }
    return $result
}

# # ## ### ##### ######## #############
## API

namespace eval ::stubs::reader {
    namespace export file text
}

# # ## ### #####
package provide stubs::reader 1.1.1
return
