# -*- tcl -*-
# This code is hereby put into the public domain.
# ### ### ### ######### ######### #########
## Overview
# Base32 encoding and decoding of small strings.

# ### ### ### ######### ######### #########
## Notes

# A binary string is split into groups of 5 bits (2^5 == 32), and each
# group is converted into a printable character as is specified in RFC
# 3548.

# ### ### ### ######### ######### #########
## Requisites

package require  base32::core
namespace eval ::base32 {}

# ### ### ### ######### ######### #########
## API & Implementation

proc ::base32::tcl_encode {bitstring} {
    variable forward

    binary scan $bitstring B* bits
    set len [string length $bits]
    set rem [expr {$len % 5}]
    if {$rem} {append bits =/$rem}
    #puts "($bitstring) => <$bits>"

    return [string map $forward $bits]
}

proc ::base32::tcl_decode {estring} {
    variable backward
    variable invalid

    if {![core::valid $estring $invalid msg]} {
	return -code error $msg
    }
    #puts "I<$estring>"
    #puts "M<[string map $backward $estring]>"

    return [binary format B* [string map $backward [string toupper $estring]]]
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::base32 {
    # Initialize the maps
    variable forward
    variable backward
    variable invalid

    core::define {
	0 A    9 J   18 S   27 3
	1 B   10 K   19 T   28 4
	2 C   11 L   20 U   29 5
	3 D   12 M   21 V   30 6
	4 E   13 N   22 W   31 7
	5 F   14 O   23 X
	6 G   15 P   24 Y
	7 H   16 Q   25 Z
	8 I   17 R   26 2
    } forward backward invalid ; # {}
    # puts ///$forward///
    # puts ///$backward///
}

# ### ### ### ######### ######### #########
## Ok
