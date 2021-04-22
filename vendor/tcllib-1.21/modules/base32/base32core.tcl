# -*- tcl -*-
# This code is hereby put into the public domain.
# ### ### ### ######### ######### #########
#= Overview

# Fundamental handling of base32 conversion tables. Expansion of a
# basic mapping into a full mapping and its inverse mapping.

# ### ### ### ######### ######### #########
#= Requisites

namespace eval ::base32::core {}

# ### ### ### ######### ######### #########
#= API & Implementation

proc ::base32::core::define {map fv bv iv} {
    variable bits
    upvar 1 $fv forward $bv backward $iv invalid

    # bytes - bits - padding  - tail       | bits - padding  - tail
    # 0     -  0   - ""       - "xxxxxxxx" | 0    - ""       - ""
    # 1     -  8   - "======" - "xx======" | 3    - "======" - "x======"
    # 2     - 16   - "===="   - "xxxx====" | 1    - "===="   - "x===="
    # 3     - 24   - "==="    - "xxxxx===" | 4    - "==="    - "x==="
    # 4     - 32   - "="      - "xxxxxxx=" | 2    - "="      - "x="

    array set _ $bits

    set invalid  "\[^="
    set forward  {}
    set btmp     {}

    foreach {code char} $map {
	set b $_($code)

	append invalid [string tolower $char][string toupper $char]

	# 5 bit remainder
	lappend forward    $b $char
	lappend btmp [list $char $b]

	# 4 bit remainder
	if {$code%2} continue
	set b [string range $b 0 end-1]
	lappend forward    ${b}=/4    ${char}===
	lappend btmp [list ${char}=== $b]

	# 3 bit remainder
	if {$code%4} continue
	set b [string range $b 0 end-1]
	lappend forward    ${b}=/3       ${char}======
	lappend btmp [list ${char}====== $b]

	# 2 bit remainder
	if {$code%8} continue
	set b [string range $b 0 end-1]
	lappend forward    ${b}=/2  ${char}=
	lappend btmp [list ${char}= $b]

	# 1 bit remainder
	if {$code%16} continue
	set b [string range $b 0 end-1]
	lappend forward    ${b}=/1     ${char}====
	lappend btmp [list ${char}==== $b]
    }

    set backward {}
    foreach item [lsort -index 0 -decreasing $btmp] {
	foreach {c b} $item break
	lappend backward $c $b
    }

    append invalid "\]"
    return
}

proc ::base32::core::valid {estring pattern mv} {
    upvar 1 $mv message

    if {[string length $estring] % 8} {
	set message "Length is not a multiple of 8"
	return 0
    } elseif {[regexp -indices $pattern $estring where]} {
	foreach {s e} $where break
	set message "Invalid character at index $s: \"[string index $estring $s]\""
	return 0
    } elseif {[regexp {(=+)$} $estring -> pad]} {
	set padlen [string length $pad]
	if {
	    ($padlen != 6) &&
	    ($padlen != 4) &&
	    ($padlen != 3) &&
	    ($padlen != 1)
	} {
	    set message "Invalid padding of length $padlen"
	    return 0
	}
    }

    # Remove the brackets and ^= from the pattern, to construct the
    # class of valid characters which must not follow the padding.

    set badp "=\[[string range $pattern 3 end-1]\]"
    if {[regexp -indices $badp $estring where]} {
	foreach {s e} $where break
	set message "Invalid character at index $s: \"[string index $estring $s]\" (padding found in the middle of the input)"
	return 0
    }
    return 1
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::base32::core {
    namespace export define valid

    variable bits {
	 0 00000	 1 00001	 2 00010	 3 00011
	 4 00100	 5 00101	 6 00110	 7 00111
	 8 01000	 9 01001	10 01010	11 01011
	12 01100	13 01101	14 01110	15 01111
	16 10000	17 10001	18 10010	19 10011
	20 10100	21 10101	22 10110	23 10111
	24 11000	25 11001	26 11010	27 11011
	28 11100	29 11101	30 11110	31 11111
    }
}

# ### ### ### ######### ######### #########
#= Registration

package provide base32::core 0.1
