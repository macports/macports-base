# rcs.tcl --
#
#	Utilities for RCS related operations.
#
# Copyright (c) 2005 by Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: rcs.tcl,v 1.4 2005/09/28 04:51:23 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites.

package require Tcl 8.4

# ### ### ### ######### ######### #########
## API Implementation

namespace eval rcs {}

# ::rcs::text2dict --
#
# Convert a text into a dictionary. The dictionary is keyed by line
# numbers, and the value is the text of the corresponding line. The
# first line has index/number 1.
#
# Arguments
# - text	The text to convert.
#
# Results
#  A dictionary containing the text in split form.
#
# Side effects
#  None

proc ::rcs::text2dict {text} {
    array set lines {}
    set lnum 0
    foreach line [split $text \n] {
	set lines([incr lnum]) $line
    }
    return [array get lines]
}

# ::rcs::file2dict --
#
# Convert a text stored in a file into a dictionary. The dictionary is
# keyed by line numbers, and the value is the text of the
# corresponding line. The first line has index/number 1.
#
# Arguments
# - file	The path of the file containing the text to convert.
#
# Results
#  A dictionary containing the text in split form.
#
# Side effects
#  None

proc ::rcs::file2dict {filename} {
    set chan [open $filename r]
    set text [read $chan]
    close $chan

    return [text2dict $text]
}

# ::rcs::dict2text --
#
# Converts a dictionary as created by the 2dict commands back into a
# text. The dictionary is keyed by line numbers, and the value is the
# text of the corresponding line. The first line has index/number 1.
# The dictionary may have gaps in the line numbers.
#
# Arguments
# - dict	The dictionary to convert.
#
# Results
#  The text stored in the dictionary.
#
# Side effects
#  None

proc ::rcs::dict2text {dict} {
    array set lines $dict
    set result {}
    foreach lnum [lsort -integer [array names lines]] {
	lappend result $lines($lnum)
    }
    return [join $result \n]
}

# ::rcs::dict2file --
#
# Converts a dictionary as created by the 2dict commands back into a
# text and stores it into the specified file. The dictionary is keyed
# by line numbers, and the value is the text of the corresponding
# line. The first line has index/number 1.  The dictionary may have
# gaps in the line numbers.
#
# Arguments
# - filename	The path to the file to store the reconstructed text into.
# - dict	The dictionary to convert.
#
# Results
#  None.
#
# Side effects
#  None

proc ::rcs::dict2file {filename dict} {
    set chan [open $filename w]
    puts -nonewline $chan [dict2text $dict]
    close $chan
}

# ::rcs::decodeRcsPatch --
#
# Converts a text containing a RCS patch (diff -n format) into a list
# of patch commands. Each element of the list is a list containing the
# patch command and its arguments, in this order.
#
# The valid patch commands are 'a' and 'd'. 'a' has two arguments, the
# index of the line where to add the text, and the text itself. The
# 'd' command has two arguments as well, the index of the first line
# to delete, and the number of lines to delete.
#
# Arguments
# - patch	The text in diff -n format, the patch to parse.
#
# Results
#   A list containing the patch as sequence of commands.
#
# Side effects
#  None

proc ::rcs::decodeRcsPatch {patch} {
    set patch [split $patch \n]
    set plen  [llength $patch]
    set at    0
    set res   {}

    while {$at < $plen} {
	# I use an index into the list to avoid shifting the list
	# elements down with each line processed. That is a lot of
	# memcpy's.

	set cmd [string trim [lindex $patch $at]]
	incr at

	switch -glob -- $cmd {
	    "" {}
	    a* {
		foreach {start len} [split [string range $cmd 1 end]] break

		set to [expr {$at + $len - 1}]
		lappend res [list \
				 a \
				 $start \
				 [join [lrange $patch $at $to] \n]]
		incr to
		set at $to
	    }
	    d* {
		foreach {start len} [split [string range $cmd 1 end]] break
		lappend res [list d $start $len]
	    }
	    default {
		return -code error "Unknown patch command: '$cmd'"
	    }
	}
    }

    return $res
}

# ::rcs::encodeRcsPatch --
#
# Converts a list of patch commands into a text containing the same
# command as a RCS patch (i.e. in diff -n format). See decodePatch for
# a description of the input format.
#
# Arguments
# - patch	The patch as list of patch commands.
#
# Results
#   A text containing the patch in diff -n format.
#
# Side effects
#  None

proc ::rcs::encodeRcsPatch {patch} {
    set res {}

    foreach cmd $patch {
	foreach {op a b} $cmd break

	switch -exact -- $op {
	    a {
		# a = index of line where to add
		# b = text to add

		set  lines [llength [split $b \n]]

		lappend res "a$a $lines"
		lappend res $b
	    }
	    d {
		# a = index of first line to delete.
		# b = #lines to delete.

		lappend res "d$a $b"
	    }
	    default {
		return -code error "Unknown patch command: '$op'"
	    }
	}
    }

    return [join $res \n]\n
}

# ::rcs::applyRcsPatch --
#
# Apply a patch in the format returned by decodeRcsPatch to a text in
# the format returned by the xx2dict commands. The result is
# dictionary containing the modified text. Use the dict2xx commands to
# convert this back into a regular text.
#
# Arguments
# - text	The text (as dict) to patch
# - patch	The patch (as cmd list) to apply.
#
# Results
#  The modified text (as dict)
#
# Side effects
#  None

proc ::rcs::applyRcsPatch {text patch} {
    array set lines $text

    foreach cmd $patch {
	foreach {op a b} $cmd break

	switch -exact -- $op {
	    a {
		# a = index of line where to add
		# b = text to add

		if {[info exists lines($a)]} {
		    append lines($a) \n $b
		} else {
		    set lines($a) $b
		}
	    }
	    d {
		# a = index of first line to delete.
		# b = #lines to delete.

		while {$b > 0} {
		    unset lines($a)
		    incr a
		    incr b -1
		}
	    }
	    default {
		return -code error "Unknown patch command: '$op'"
	    }
	}
    }

    return [array get lines]
}

# ### ### ### ######### ######### #########
## Ready for use.

package provide rcs 0.1
