# -*- tcl -*-
#
# Copyright (c) 2009-2014 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Grammars / Parsing Expression Grammars / Parser Generator

# ### ### ### ######### ######### #########
## Package description

# A package exporting a parser generator command.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require fileutil
package require pt::peg::from::json    ; # Frontends: json, and PEG text form
package require pt::peg::from::peg     ; #
package require pt::peg::to::container ; # Backends: json, peg, container code,
package require pt::peg::to::json      ; #           param assembler, 
package require pt::peg::to::peg       ; #
package require pt::peg::to::param     ; # PARAM assembly, raw
package require pt::peg::to::tclparam  ; # PARAM assembly, embedded into Tcl
package require pt::peg::to::cparam    ; # PARAM assembly, embedded into C
package require pt::tclparam::configuration::snit  1.0.2 ; # PARAM/Tcl, snit::type
package require pt::tclparam::configuration::tcloo 1.0.4 ; # PARAM/Tcl, TclOO class
package require pt::cparam::configuration::critcl  1.0.2 ; # PARAM/C, in critcl
package require pt::cparam::configuration::tea   ; # PARAM/C, in TEA
package require pt::tclparam::configuration::nx 1.0.0 ; # PARAM/Tcl, NX class

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::pt::pgen {
    namespace export json peg serial
    namespace ensemble create
}

# # ## ### ##### ######## #############
## Public API - Processing the input.

proc ::pt::pgen::serial {input args} {
    #lappend args -file $inputfile
    return [Write {*}$args $input]
}

proc ::pt::pgen::json {input args} {
    #lappend args -file $inputfile
    return [Write {*}$args [pt::peg::from::json convert $input]]
}

proc ::pt::pgen::peg {input args} {
    #lappend args -file $inputfile
    return [Write {*}$args [pt::peg::from::peg convert $input]]
}

# # ## ### ##### ######## #############
## Internals - Generating the parser.

namespace eval ::pt::pgen::Write {
    namespace export json peg container param snit oo critcl c tea nx
    namespace ensemble create
}

proc ::pt::pgen::Write::json {args} {
    # args = (option value)... grammar
    pt::peg::to::json configure {*}[lrange $args 0 end-1]
    return [pt::peg::to::json convert [lindex $args end]]
}

proc ::pt::pgen::Write::peg {args} {
    # args = (option value)... grammar
    pt::peg::to::peg configure {*}[lrange $args 0 end-1]
    return [pt::peg::to::peg convert [lindex $args end]]
}

proc ::pt::pgen::Write::container {args} {
    # args = (option value)... grammar
    pt::peg::to::container configure {*}[lrange $args 0 end-1]
    return [pt::peg::to::container convert [lindex $args end]]
}

proc ::pt::pgen::Write::param {args} {
    # args = (option value)... grammar
    pt::peg::to::param configure {*}[lrange $args 0 end-1]
    return [pt::peg::to::param convert [lindex $args end]]
}

proc ::pt::pgen::Write::snit {args} {
    # args = (option value)... grammar
    pt::peg::to::tclparam configure {*}[Package [Version [Class [lrange $args 0 end-1]]]]
    ClassPackageDefaults

    pt::tclparam::configuration::snit def \
	$class $package $version \
	{pt::peg::to::tclparam configure}

    return [pt::peg::to::tclparam convert [lindex $args end]]
}

proc ::pt::pgen::Write::oo {args} {
    # args = (option value)... grammar
    pt::peg::to::tclparam configure {*}[Package [Version [Class [lrange $args 0 end-1]]]]
    ClassPackageDefaults

    pt::tclparam::configuration::tcloo def \
	$class $package $version \
	{pt::peg::to::tclparam configure}

    return [pt::peg::to::tclparam convert [lindex $args end]]
}

proc ::pt::pgen::Write::nx {args} {
    # args = (option value)... grammar
    pt::peg::to::tclparam configure {*}[Package [Version [Class [lrange $args 0 end-1]]]]
    ClassPackageDefaults

    pt::tclparam::configuration::nx def \
	$class $package $version \
	{pt::peg::to::tclparam configure}

    return [pt::peg::to::tclparam convert [lindex $args end]]
}

proc ::pt::pgen::Write::tea {args} {
    # args = (option value)... grammar
    # Class   -> touches/defines variable 'class'
    # Package -> touches/defines variable 'package'
    # Version -> touches/defines variable 'version'
    pt::peg::to::cparam configure {*}[Package [Version [Class [lrange $args 0 end-1]]]]
    ClassPackageDefaults

    pt::cparam::configuration::tea def \
	$class $package $version \
	{pt::peg::to::cparam configure}

    return [pt::peg::to::cparam convert [lindex $args end]]
}

proc ::pt::pgen::Write::critcl {args} {
    # args = (option value)... grammar
    # Class   -> touches/defines variable 'class'
    # Package -> touches/defines variable 'package'
    # Version -> touches/defines variable 'version'
    pt::peg::to::cparam configure {*}[Package [Version [Class [lrange $args 0 end-1]]]]
    ClassPackageDefaults

    pt::cparam::configuration::critcl def \
	$class $package $version \
	{pt::peg::to::cparam configure}

    return [pt::peg::to::cparam convert [lindex $args end]]
}

proc ::pt::pgen::Write::c {args} {
    # args = (option value)... grammar
    pt::peg::to::cparam configure {*}[lrange $args 0 end-1]
    return [pt::peg::to::cparam convert [lindex $args end]]
}

# ### ### ### ######### ######### #########
## Internals: Special option handling handling.

proc ::pt::pgen::Write::ClassPackageDefaults {} {
    upvar 1 class   class
    upvar 1 package package
    upvar 1 version version

    # Initialize undefined class and package names from each other,
    # i.e. from whichever of the two was specified, or fallback to
    # hardwired defaults if neither was specified.

    if {[info exists class] && ![info exists package]} {
	set package $class
    } elseif {[info exists package] && ![info exists class]} {
	set class $package
    } elseif {![info exists package] && ![info exists class]} {
	set class   CLASS
	set package PACKAGE
    }

    # Initialize undefined version information.

    if {![info exists version]} {
	set version 1
    }
    return
}

# Class, Package, Version - identical modulo option and variable name.
# TODO: Refactor into some common code.

proc ::pt::pgen::Write::Class {optiondict} {
    upvar 1 class class
    set res {}
    foreach {option value} $optiondict {
	if {$option eq "-class"} {
	    set class $value
	    continue
	}
	lappend res $option $value
    }
    return $res
}

proc ::pt::pgen::Write::Package {optiondict} {
    upvar 1 package package
    set res {}
    foreach {option value} $optiondict {
	if {$option eq "-package"} {
	    set package $value
	    continue
	}
	lappend res $option $value
    }
    return $res
}

proc ::pt::pgen::Write::Version {optiondict} {
    upvar 1 version version
    set res {}
    foreach {option value} $optiondict {
	if {$option eq "-version"} {
	    set version $value
	    continue
	}
	lappend res $option $value
    }
    return $res
}

# ### ### ### ######### ######### #########
## Package Management

package provide pt::pgen 1.1
