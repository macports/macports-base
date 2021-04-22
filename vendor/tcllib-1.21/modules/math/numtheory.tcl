##
## This is the file `numtheory.tcl',
## generated with the SAK utility
## (sak docstrip/regen).
##
## The original source files were:
##
## numtheory.dtx  (with options: `pkg pkg_common')
##
## In other words:
## **************************************
## * This Source is not the True Source *
## **************************************
## the true source is the file from which this one was generated.
##
# Copyright (c) 2010 by Lars Hellstrom.  All rights reserved.
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
package require Tcl 8.5
package provide math::numtheory 1.1.3
namespace eval ::math::numtheory {
   namespace export isprime
}
proc ::math::numtheory::prime_trialdivision {n} {
    if {$n<2}      then {return -code return 0}
    if {$n<4}      then {return -code return 1}
    if {$n%2 == 0} then {return -code return 0}
    if {$n<9}      then {return -code return 1}
    if {$n%3 == 0} then {return -code return 0}
    if {$n%5 == 0} then {return -code return 0}
    if {$n%7 == 0} then {return -code return 0}
    if {$n<121}    then {return -code return 1}
}
proc ::math::numtheory::Miller--Rabin {n s d a} {
    set x 1
    while {$d>1} {
        if {$d & 1} then {set x [expr {$x*$a % $n}]}
        set a [expr {$a*$a % $n}]
        set d [expr {$d >> 1}]
    }
    set x [expr {$x*$a % $n}]
    if {$x == 1} then {return 0}
    for {} {$s>1} {incr s -1} {
        if {$x == $n-1} then {return 0}
        set x [expr {$x*$x % $n}]
        if {$x == 1} then {return 1}
    }
    return [expr {$x != $n-1}]
}
proc ::math::numtheory::isprime {n args} {
    prime_trialdivision $n
    set d [expr {$n-1}]; set s 0
    while {($d&1) == 0} {
        incr s
        set d [expr {$d>>1}]
    }
    if {[Miller--Rabin $n $s $d 2]} then {return 0}
    if {$n < 2047} then {return 1}
    if {[Miller--Rabin $n $s $d 3]} then {return 0}
    if {$n < 1373653} then {return 1}
    if {[Miller--Rabin $n $s $d 5]} then {return 0}
    if {$n < 25326001} then {return 1}
    if {[Miller--Rabin $n $s $d 7] || $n==3215031751} then {return 0}
    if {$n < 118670087467} then {return 1}
    array set O {-randommr 4}
    array set O $args
    for {set i $O(-randommr)} {$i >= 1} {incr i -1} {
        if {[Miller--Rabin $n $s $d [expr {(
           (round(rand()*0x100000000)-1)
           *3 | 1)
           + 10
        }]]} then {return 0}
    }
    return on
}

# Add the additional procedures
#
source [file join [file dirname [info script]] primes.tcl]
##
##
## End of file `numtheory.tcl'.
