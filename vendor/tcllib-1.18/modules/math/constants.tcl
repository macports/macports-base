# constants.tcl --
#    Module defining common mathematical and numerical constants
#
# Copyright (c) 2004 by Arjen Markus.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: constants.tcl,v 1.9 2011/01/18 07:49:53 arjenmarkus Exp $
#
#----------------------------------------------------------------------

package require Tcl 8.2

package provide math::constants 1.0.2

# namespace constants
#    Create a convenient namespace for the constants
#
namespace eval ::math::constants {
    #
    # List of constants and their description
    #
    variable constants {
        pi        3.14159265358979323846   "ratio of circle circumference and diameter"
        e         2.71828182845904523536   "base for natural logarithm"
        ln10      2.30258509299404568402   "natural logarithm of 10"
        phi       1.61803398874989484820   "golden ratio"
        gamma     0.57721566490153286061   "Euler's constant"
        sqrt2     1.41421356237309504880   "Square root of 2"
        thirdrt2  1.25992104989487316477   "One-third power of 2"
        sqrt3     1.73205080756887729533   "Square root of 3"
        radtodeg  57.2957795131            "Conversion from radians to degrees"
        degtorad  0.017453292519943        "Conversion from degrees to radians"
        onethird  1.0/3.0                  "One third (0.3333....)"
        twothirds 2.0/3.0                  "Two thirds (0.6666....)"
        onesixth  1.0/6.0                  "One sixth (0.1666....)"
        huge      [find_huge]              "(Approximately) largest number"
        tiny      [find_tiny]              "(Approximately) smallest number not equal zero"
        eps       [find_eps]               "Smallest number such that 1+eps != 1"
    }
    namespace export constants print-constants
}

# constants --
#    Expose the constants in the caller's routine or namespace
#
# Arguments:
#    args         List of constants to be exposed
# Result:
#    None
#
proc ::math::constants::constants {args} {

    foreach const $args {
        uplevel 1 [list variable $const [set ::math::constants::$const]]
    }
}

# print-constants --
#    Print the selected or all constants to the screen
#
# Arguments:
#    args         List of constants to be exposed
# Result:
#    None
#
proc ::math::constants::print-constants {args} {
    variable constants

    if { [llength $args] != 0 } {
        foreach const $args {
            set idx [lsearch $constants $const]
            if { $idx >= 0 } {
                set descr [lindex $constants [expr {$idx+2}]]
                puts "$const = [set ::math::constants::$const] = $descr"
            } else {
                puts "*** $const unknown ***"
            }
        }
    } else {
        foreach {const value descr} $constants {
            puts "$const = [set ::math::constants::$const] = $descr"
        }
    }
}

# find_huge --
#    Find the largest possible number
#
# Arguments:
#    None
# Result:
#    Estimate of the largest possible number
#
proc ::math::constants::find_huge {} {

    set result 1.0
    set Inf Inf
    while {1} {
	if {[catch {expr {2.0 * $result}} result]} {
	    break
	}
	if { $result == $Inf } {
	    break
	}
	set prev_result $result
    }
    set result $prev_result
    set adder [expr { $result / 2. }]
    while { $adder != 0.0 } {
	if {![catch {expr {$adder + $prev_result}} result]} {
	    if { $result == $prev_result } break
	    if { $result != $Inf } {
		set prev_result $result
	    }
	}
	set adder [expr { $adder / 2. }]
    }
    return $prev_result

}

# find_tiny --
#    Find the smallest possible number
#
# Arguments:
#    None
# Result:
#    Estimate of the smallest possible number
#
proc ::math::constants::find_tiny {} {

    set result 1.0

    while { ! [catch {set result [expr {$result/2.0}]}] && $result > 0.0 } {
        set prev_result $result
    }
    return $prev_result
}

# find_eps --
#    Find the smallest number eps such that 1+eps != 1
#
# Arguments:
#    None
# Result:
#    Estimate of the machine epsilon
#
proc ::math::constants::find_eps { } {
    set eps 1.0
    while { [expr {1.0+$eps}] != 1.0 } {
        set prev_eps $eps
        set eps  [expr {0.5*$eps}]
    }
    return $prev_eps
}

# Create the variables from the list:
# - By using expr we ensure that the best double precision
#   approximation is assigned to the variable, rather than
#   just the string
# - It also allows us to rely on IEEE arithmetic if available,
#   so that for instance 3.0*(1.0/3.0) is exactly 1.0
#
namespace eval ::math::constants {
    foreach {const value descr} $constants {
        # FRINK: nocheck
        set [namespace current]::$const [expr 0.0+$value]
    }
    unset value
    unset const
    unset descr

    rename find_eps  {}
    rename find_tiny {}
    rename find_huge {}
}

# some tests --
#
if { [info exists ::argv0]
     && [string equal $::argv0 [info script]] } {
    ::math::constants::constants pi e ln10 onethird eps
    set prec $::tcl_precision
    if {![package vsatisfies [package provide Tcl] 8.5]} {
        set ::tcl_precision 17
    } else {
        set ::tcl_precision 0
    }
    puts "$pi - [expr {1.0/$pi}]"
    puts $e
    puts $ln10
    puts "onethird: [expr {3.0*$onethird}]"
    ::math::constants::print-constants onethird pi e
    puts "All defined constants:"
    ::math::constants::print-constants

    if { 1.0+$eps == 1.0 } {
        puts "Something went wrong with eps!"
    } else {
        puts "Difference: [set ee [expr {1.0+$eps}]] - 1.0 = [expr {$ee-1.0}]"
    }
    set ::tcl_precision $prec
}
