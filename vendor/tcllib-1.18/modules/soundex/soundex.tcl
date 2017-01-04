# soundex.tcl --
#
#	Implementation of soundex in Tcl
#
# Copyright (c) 2003 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: soundex.tcl,v 1.3 2004/01/15 06:36:14 andreas_kupries Exp $

package require Tcl 8.2

namespace eval ::soundex {}

## ------------------------------------------------------------
##
## I. Soundex by Knuth.

# This implementation of the Soundex algorithm is released to the public
# domain: anyone may use it for any purpose.  See if I care.

# N. Dean Pentcheff 1/13/89 Dept. of Zoology University of California Berkeley,
#    CA  94720 dean@violet.berkeley.edu
# TCL port by Evan Rempel 2/10/98 Dept Comp Services University of Victoria.
# erempel@uvic.ca

# proc ::soundex::knuth ( string )
#
#   Given as argument: a character string. Returns: a static string, 4 characters long
#   This string is the Soundex key for the argument string.
#   Side effects and limitations:
#   Does not clobber the string passed in as the argument. No limit on
#   argument string length. Assumes a character set with continuously
#   ascending and contiguous letters within each case and within the digits
#   (e.g. this works for ASCII and bombs in EBCDIC. But then, most things
#   do.). Reference: Adapted from Knuth, D.E. (1973) The art of computer
#   programming; Volume 3: Sorting and searching.  Addison-Wesley Publishing
#   Company: Reading, Mass. Page 392.
#   Special cases: Leading or embedded spaces, numerals, or punctuation are squeezed
#   out before encoding begins.
#
#   Null strings or those with no encodable letters return the code 'Z000'.
#
#   Test data from Knuth (1973):
#   Euler   Gauss   Hilbert Knuth   Lloyd   Lukasiewicz
#   E460    G200    H416    K530    L300    L222

namespace eval ::soundex {
    variable  soundexKnuthCode
    array set soundexKnuthCode {
	a 0 b 1 c 2 d 3 e 0 f 1 g 2 h 0 i 0 j 2 k 2 l 4 m 5
	n 5 o 0 p 1 q 2 r 6 s 2 t 3 u 0 v 1 w 0 x 2 y 0 z 2
    }
}
proc ::soundex::knuth {in} {
    variable soundexKnuthCode
    set key ""

    # Remove the leading/trailing white space punctuation etc.

    set TempIn [string trim $in "\t\n\r .,'-"]

    # Only use alphabetic characters, so strip out all others
    # also, soundex index uses only lower case chars, so force to lower

    regsub -all {[^a-z]} [string tolower $TempIn] {} TempIn
    if {[string length $TempIn] == 0} {
	return Z000
    }
    set last [string index $TempIn 0]
    set key  [string toupper $last]
    set last $soundexKnuthCode($last)

    # Scan rest of string, stop at end of string or when the key is
    # full

    set count    1
    set MaxIndex [string length $TempIn]

    for {set index 1} {(($count < 4) && ($index < $MaxIndex))} {incr index } {
	set chcode $soundexKnuthCode([string index $TempIn $index])
	# Fold together adjacent letters sharing the same code
	if {![string equal $last $chcode]} {
	    set last $chcode
	    # Ignore code==0 letters except as separators
	    if {$last != 0} then {
		set key $key$last
		incr count
	    }
	}
    }
    return [string range ${key}0000 0 3]
}

package provide soundex 1.0
