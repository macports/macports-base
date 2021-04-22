# split.tcl --
#
#	Various ways of splitting a string.
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2000      by Eric Melski <ericm@ajubasolutions.com>
# Copyright (c) 2001      by Reinhard Max <max@suse.de>
# Copyright (c) 2003      by Pat Thoyts <patthoyts@users.sourceforge.net>
# Copyright (c) 2001-2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: split.tcl,v 1.7 2006/04/21 04:42:28 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2

namespace eval ::textutil::split {}

########################################################################
# This one was written by Bob Techentin (RWT in Tcl'ers Wiki):
# http://www.techentin.net
# mailto:techentin.robert@mayo.edu
#
# Later, he send me an email stated that I can use it anywhere, because
# no copyright was added, so the code is defacto in the public domain.
#
# You can found it in the Tcl'ers Wiki here:
# http://mini.net/cgi-bin/wikit/460.html
#
# Bob wrote:
# If you need to split string into list using some more complicated rule
# than builtin split command allows, use following function. It mimics
# Perl split operator which allows regexp as element separator, but,
# like builtin split, it expects string to split as first arg and regexp
# as second (optional) By default, it splits by any amount of whitespace. 
# Note that if you add parenthesis into regexp, parenthesed part of separator
# would be added into list as additional element. Just like in Perl. -- cary 
#
# Speed improvement by Reinhard Max:
# Instead of repeatedly copying around the not yet matched part of the
# string, I use [regexp]'s -start option to restrict the match to that
# part. This reduces the complexity from something like O(n^1.5) to
# O(n). My test case for that was:
# 
# foreach i {1 10 100 1000 10000} {
#     set s [string repeat x $i]
#     puts [time {splitx $s .}]
# }
#

if {[package vsatisfies [package provide Tcl] 8.3]} {

    proc ::textutil::split::splitx {str {regexp {[\t \r\n]+}}} {
        # Bugfix 476988
        if {[string length $str] == 0} {
            return {}
        }
        if {[string length $regexp] == 0} {
            return [::split $str ""]
        }
	if {[regexp $regexp {}]} {
	    return -code error \
		"splitting on regexp \"$regexp\" would cause infinite loop"
	}

        set list  {}
        set start 0
        while {[regexp -start $start -indices -- $regexp $str match submatch]} {
            foreach {subStart subEnd} $submatch break
            foreach {matchStart matchEnd} $match break
            incr matchStart -1
            incr matchEnd
            lappend list [string range $str $start $matchStart]
            if {$subStart >= $start} {
                lappend list [string range $str $subStart $subEnd]
            }
            set start $matchEnd
        }
        lappend list [string range $str $start end]
        return $list
    }

} else {    
    # For tcl <= 8.2 we do not have regexp -start...
    proc ::textutil::split::splitx [list str [list regexp "\[\t \r\n\]+"]] {

        if {[string length $str] == 0} {
            return {}
        }
        if {[string length $regexp] == 0} {
            return [::split $str {}]
        }
	if {[regexp $regexp {}]} {
	    return -code error \
		"splitting on regexp \"$regexp\" would cause infinite loop"
	}

        set list  {}
        while {[regexp -indices -- $regexp $str match submatch]} {
            lappend list [string range $str 0 [expr {[lindex $match 0] -1}]]
            if {[lindex $submatch 0] >= 0} {
                lappend list [string range $str [lindex $submatch 0] \
                                  [lindex $submatch 1]]
            }
            set str [string range $str [expr {[lindex $match 1]+1}] end]
        }
        lappend list $str
        return $list
    }
    
}

#
# splitn --
#
# splitn splits the string $str into chunks of length $len.  These
# chunks are returned as a list.
#
# If $str really contains a ByteArray object (as retrieved from binary
# encoded channels) splitn must honor this by splitting the string
# into chunks of $len bytes.
#
# It is an error to call splitn with a nonpositive $len.
#
# If splitn is called with an empty string, it returns the empty list.
#
# If the length of $str is not an entire multiple of the chunk length,
# the last chunk in the generated list will be shorter than $len.
#
# The implementation presented here was given by Bryan Oakley, as
# part of a ``contest'' I staged on c.l.t in July 2004.  I selected
# this version, as it does not rely on runtime generated code, is
# very fast for chunk size one, not too bad in all the other cases,
# and uses [split] or [string range] which have been around for quite
# some time.
#
# -- Robert Suetterlin (robert@mpe.mpg.de)
#
proc ::textutil::split::splitn {str {len 1}} {

    if {$len <= 0} {
        return -code error "len must be > 0"
    }

    if {$len == 1} {
        return [split $str {}]
    }

    set result [list]
    set max [string length $str]
    set i 0
    set j [expr {$len -1}]
    while {$i < $max} {
        lappend result [string range $str $i $j]
        incr i $len
        incr j $len
    }

    return $result
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::split {
    namespace export splitx splitn
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::split 0.8
