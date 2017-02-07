# string.tcl --
#
#	Utilities for manipulating strings, words, single lines,
#	paragraphs, ...
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2000      by Eric Melski <ericm@ajubasolutions.com>
# Copyright (c) 2002      by Joe English <jenglish@users.sourceforge.net>
# Copyright (c) 2001-2014 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: string.tcl,v 1.2 2008/03/22 16:03:11 mic42 Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2

namespace eval ::textutil::string {}

# ### ### ### ######### ######### #########
## API implementation

# @c Removes the last character from the given <a string>.
#
# @a string: The string to manipulate.
#
# @r The <a string> without its last character.
#
# @i chopping

proc ::textutil::string::chop {string} {
    return [string range $string 0 [expr {[string length $string]-2}]]
}

# @c Removes the first character from the given <a string>.
# @c Convenience procedure.
#
# @a string: string to manipulate.
#
# @r The <a string> without its first character.
#
# @i tail

proc ::textutil::string::tail {string} {
    return [string range $string 1 end]
}

# @c Capitalizes first character of the given <a string>.
# @c Complementary procedure to <p ::textutil::uncap>.
#
# @a string: string to manipulate.
#
# @r The <a string> with its first character capitalized.
#
# @i capitalize

proc ::textutil::string::cap {string} {
    return [string toupper [string index $string 0]][string range $string 1 end]
}

# @c unCapitalizes first character of the given <a string>.
# @c Complementary procedure to <p ::textutil::cap>.
#
# @a string: string to manipulate.
#
# @r The <a string> with its first character uncapitalized.
#
# @i uncapitalize

proc ::textutil::string::uncap {string} {
    return [string tolower [string index $string 0]][string range $string 1 end]
}

# @c Capitalizes first character of each word of the given <a sentence>.
#
# @a sentence: string to manipulate.
#
# @r The <a sentence> with the first character of each word capitalized.
#
# @i capitalize

proc ::textutil::string::capEachWord {sentence} {
    regsub -all {\S+} [string map {\\ \\\\ \$ \\$} $sentence] {[string toupper [string index & 0]][string range & 1 end]} cmd
    return [subst -nobackslashes -novariables $cmd]
}

# Compute the longest string which is common to all strings given to
# the command, and at the beginning of said strings, i.e. a prefix. If
# only one argument is specified it is treated as a list of the
# strings to look at. If more than one argument is specified these
# arguments are the strings to be looked at. If only one string is
# given, in either form, the string is returned, as it is its own
# longest common prefix.

proc ::textutil::string::longestCommonPrefix {args} {
    return [longestCommonPrefixList $args]
}

proc ::textutil::string::longestCommonPrefixList {list} {
    if {[llength $list] <= 1} {
	return [lindex $list 0]
    }

    set list [lsort $list]
    set min [lindex $list 0]
    set max [lindex $list end]

    # Min and max are the two strings which are most different. If
    # they have a common prefix, it will also be the common prefix for
    # all of them.

    # Fast bailouts for common cases.

    set n [string length $min]
    if {$n == 0} {return ""}
    if {0 == [string compare $min $max]} {return $min}

    set prefix ""
    set i 0
    while {[string index $min $i] == [string index $max $i]} {
	append prefix [string index $min $i]
	if {[incr i] > $n} {break}
    }
    set prefix
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::string {
    # Export the imported commands

    namespace export chop tail cap uncap capEachWord
    namespace export longestCommonPrefix
    namespace export longestCommonPrefixList
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::string 0.8
