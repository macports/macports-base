# -*- tcl -*-
# This code is hereby put into the public domain.
# ### ### ### ######### ######### #########
## Overview
# Base32 encoding and decoding of small strings.

# ### ### ### ######### ######### #########
## Notes

# A binary string is split into groups of 5 bits (2^5 == 32), and each
# group is converted into a printable character as is specified in RFC
# 3548 for the extended hex encoding.

# ### ### ### ######### ######### #########
## Requisites

package require  base32::core
namespace eval ::base32::hex {}

# ### ### ### ######### ######### #########
## API & Implementation

proc ::base32::hex::tcl_encode {bitstring} {
    variable forward

    binary scan $bitstring B* bits
    set len [string length $bits]
    set rem [expr {$len % 5}]
    if {$rem} {append bits =/$rem}
    #puts "($bitstring) => <$bits>"

    return [string map $forward $bits]
}

proc ::base32::hex::tcl_decode {estring} {
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

namespace eval ::base32::hex {
    namespace eval core {
	namespace import ::base32::core::define
	namespace import ::base32::core::valid
    }

    namespace export encode decode
    # Initialize the maps
    variable forward
    variable backward
    variable invalid

    core::define {
	0 0    9 9        18 I   27 R
	1 1   10 A        19 J   28 S
	2 2   11 B        20 K   29 T
	3 3   12 C        21 L   30 U
	4 4   13 D        22 M   31 V
	5 5   14 E        23 N
	6 6   15 F        24 O
	7 7        16 G   25 P
	8 8        17 H   26 Q
    } forward backward invalid ; # {}
    # puts ///$forward///
    # puts ///$backward///
}

# ### ### ### ######### ######### #########
## Ok
