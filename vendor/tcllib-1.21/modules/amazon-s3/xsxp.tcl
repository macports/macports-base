# xsxp.tcl --
#
###Abstract
# Extremely Simple XML Parser
#
# This is pretty lame, but I needed something like this for S3,
# and at the time, TclDOM would not work with the new 8.5 Tcl
# due to version number problems.
#
# In addition, this is a pure-value implementation. There is no
# garbage to clean up in the event of a thrown error, for example.
# This simplifies the code for sufficiently small XML documents,
# which is what Amazon's S3 guarantees.
#
###Copyright
# Copyright (c) 2006 Darren New.
# All Rights Reserved.
# NO WARRANTIES OF ANY TYPE ARE PROVIDED.
# COPYING OR USE INDEMNIFIES THE AUTHOR IN ALL WAYS.
# See the license terms in LICENSE.txt
#
###Revision String
# SCCS: %Z% %M% %I% %E% %U%

# xsxp::parse $xml
# Returns a parsed XML, or PXML. A pxml is a list.
# The first element is the name of the tag.
# The second element is a list of name/value pairs of the
# associated attribues, if any.
# The third thru final values are recursively PXML values.
# If the first element (element zero, that is) is "%PCDATA",
# then the attributes will be emtpy and the third element
# will be the text of the element.

# xsxp::fetch $pxml $path ?$part?
# $pxml is a parsed XML, as returned from xsxp::parse.
# $path is a list of elements. Each element is the name of
# a child to look up, optionally followed by a hash ("#")
# and a string of digits. An emtpy list or an initial empty
# element selects $pxml. If no hash sign is present, the
# behavior is as if "#0" had been appended to that element.
# An element of $path scans the children at the indicated
# level for the n'th instance of a child whose tag matches
# the part of the element before the hash sign. If an element
# is simply "#" followed by digits, that indexed child is
# selected, regardless of the tags in the children. So
# an element of #3 will always select the fourth child
# of the node under consideration.
# $part defaults to %ALL. It can be one of the following:
# %ALL - returns the entire selected element.
# %TAGNAME - returns lindex 0 of the selected element.
# %ATTRIBUTES - returns lindex 1 of the selected element.
# %CHILDREN - returns lrange 2 through end of the selected element,
#   resulting in a list of elements being returned.
# %PCDATA - returns a concatenation of all the bodies of
#   direct children of this node whose tag is %PCDATA.
#   Throws an error if no such children are found. That
#   is, part=%PCDATA means return the textual content found
#   in that node but not its children nodes.
# %PCDATA? - like %PCDATA, but returns an empty string if
#   no PCDATA is found.

# xsxp::fetchall $pxml_list $path ?$part?
# Iterates over each PXML in $pxml_list, selecting the indicated
# path from it, building a new list with the selected data, and
# returning that new list. For example, $pxml_list might be
# the %CHILDREN of a particular element, and the $path and $part
# might select from each child a sub-element in which we're interested.

# xsxp::only $pxml $tagname
# Iterates over the direct children of $pxml and selects  only
# those with $tagname as their tag. Returns a list of matching
# elements.

# xsxp::prettyprint $pxml
# Outputs to stdout a nested-list notation of the parsed XML.

package require xml
package provide xsxp 1.0

namespace eval xsxp {

    variable Stack
    variable Cur

    proc Characterdatacommand {characterdata} {
	variable Cur
	# puts "characterdatacommand $characterdata"
	set x [list %PCDATA {} $characterdata]
	lappend Cur $x
    }

    proc Elementstartcommand {name attlist args} {
	# puts "elementstart $name {$attlist} $args"
	variable Stack
	variable Cur
	lappend Stack $Cur
	set Cur [list $name $attlist]
    }

    proc Elementendcommand {args} {
	# puts "elementend $args"
	variable Stack
	variable Cur
	set x [lindex $Stack end]
	lappend x $Cur
	set Cur $x
	set Stack [lrange $Stack 0 end-1]
    }

    proc parse {xml} {
	variable Cur
	variable Stack
	set Cur {}
	set Stack {}
	set parser [::xml::parser \
	    -characterdatacommand [namespace code Characterdatacommand] \
	    -elementstartcommand [namespace code Elementstartcommand] \
	    -elementendcommand [namespace code Elementendcommand] \
	    -ignorewhitespace 1 -final 1
        ]
	$parser parse $xml
	$parser free
	# The following line is needed because the close of the last element
	# appends the outermost element to the item on the top of the stack.
	# Since there's nothing on the top of the stack at the close of the
	# last element, we append the current element to an empty list.
	# In essence, since we don't really have a terminating condition
	# on the recursion, an empty stack is still treated like an element.
	set Cur [lindex $Cur 0]
        set Cur [Normalize $Cur]
        return $Cur
    }

    proc Normalize {pxml} {
	# This iterates over pxml recursively, finding entries that
	# start with multiple %PCDATA elements, and coalesces their
	# content, so if an element contains only %PCDATA, it is
	# guaranteed to have only one child.
	# Not really necessary, given definition of part=%PCDATA
	# However, it makes pretty-prints nicer (for AWS at least)
	# and ends up with smaller lists. I have no idea why they
	# would put quotes around an MD5 hash in hex, tho.
	set dupl 1
	while {$dupl} {
	    set first [lindex $pxml 2]
	    set second [lindex $pxml 3]
	    if {[lindex $first 0] eq "%PCDATA" && [lindex $second 0] eq "%PCDATA"} {
		set repl [list %PCDATA {} [lindex $first 2][lindex $second 2]]
		set pxml [lreplace $pxml 2 3 $repl]
	    } else {
		set dupl 0
		for {set i 2} {$i < [llength $pxml]} {incr i} {
		    set pxml [lreplace $pxml $i $i [Normalize [lindex $pxml $i]]]
		}
	    }
	}
	return $pxml
    }

    proc prettyprint {pxml {chan stdout} {indent 0}} {
	puts -nonewline $chan [string repeat "  " $indent]
	if {[lindex $pxml 0] eq "%PCDATA"} {
	    puts $chan "%PCDATA: [lindex $pxml 2]"
	    return
	}
	puts -nonewline $chan "[lindex $pxml 0]"
	foreach {name val} [lindex $pxml 1] {
	    puts -nonewline $chan " $name='$val'"
	}
	puts $chan ""
	foreach node [lrange $pxml 2 end] {
	    prettyprint $node $chan [expr $indent+1]
	}
    }

    proc fetch {pxml path {part %ALL}} {
	set path [string trim $path /]
	if {-1 != [string first / $path]} {
	    set path [split $path /]
	}
	foreach element $path {
	    if {$pxml eq ""} {return ""}
	    foreach {tag count} [split $element #] {
		if {$tag ne ""} {
		    if {$count eq ""} {set count 0}
		    set pxml [lrange $pxml 2 end]
		    while {0 <= $count && 0 != [llength $pxml]} {
			if {$tag eq [lindex $pxml 0 0]} {
			    incr count -1
			    if {$count < 0} {
				# We're done. Go on to next element.
				set pxml [lindex $pxml 0]
			    } else {
				# Not done yet. Throw this away.
				set pxml [lrange $pxml 1 end]
			    }
			} else {
			    # Not what we want.
			    set pxml [lrange $pxml 1 end]
			}
		    }
		} else { # tag eq ""
		    if {$count eq ""} {
			# Just select whole $pxml
		    } else {
			set pxml [lindex $pxml [expr {2+$count}]]
		    }
		}
		break
	    } ; # done the foreach [split] loop
	} ; # done all the elements.
	if {$part eq "%ALL"} {return $pxml}
	if {$part eq "%ATTRIBUTES"} {return [lindex $pxml 1]}
	if {$part eq "%TAGNAME"} {return [lindex $pxml 0]}
	if {$part eq "%CHILDREN"} {return [lrange $pxml 2 end]}
	if {$part eq "%PCDATA" || $part eq "%PCDATA?"} {
	    set res "" ; set found 0
	    foreach elem [lrange $pxml 2 end] {
		if {"%PCDATA" eq [lindex $elem 0]} {
		    append res [lindex $elem 2]
		    set found 1
		}
	    }
	    if {$found || $part eq "%PCDATA?"} {
		return $res
	    } else {
		error "xsxp::fetch did not find requested PCDATA"
	    }
	}
	return $pxml ; # Don't know what he's after
    }

    proc only {pxml tag} {
	set res {}
	foreach element [lrange $pxml 2 end] {
	    if {[lindex $element 0] eq $tag} {
		lappend res $element
	    }
	}
	return $res
    }

    proc fetchall {pxml_list path {part %ALL}} {
	set res [list]
	foreach pxml $pxml_list {
	    lappend res [fetch $pxml $path $part]
	}
	return $res
    }
}

namespace export xsxp parse prettyprint fetch

