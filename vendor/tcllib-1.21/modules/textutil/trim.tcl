# trim.tcl --
#
#	Various ways of trimming a string.
#
# Copyright (c) 2000      by Ajuba Solutions.
# Copyright (c) 2000      by Eric Melski <ericm@ajubasolutions.com>
# Copyright (c) 2001-2006 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: trim.tcl,v 1.5 2006/04/21 04:42:28 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.2

namespace eval ::textutil::trim {}

# ### ### ### ######### ######### #########
## API implementation

proc ::textutil::trim::trimleft {text {trim "[ \t]+"}} {
    regsub -line -all -- [MakeStr $trim left] $text {} text
    return $text
}

proc ::textutil::trim::trimright {text {trim "[ \t]+"}} {
    regsub -line -all -- [MakeStr $trim right] $text {} text
    return $text
}

proc ::textutil::trim::trim {text {trim "[ \t]+"}} {
    regsub -line -all -- [MakeStr $trim left]  $text {} text
    regsub -line -all -- [MakeStr $trim right] $text {} text
    return $text
}



# @c Strips <a prefix> from <a text>, if found at its start.
#
# @a text: The string to check for <a prefix>.
# @a prefix: The string to remove from <a text>.
#
# @r The <a text>, but without <a prefix>.
#
# @i remove, prefix

proc ::textutil::trim::trimPrefix {text prefix} {
    if {[string first $prefix $text] == 0} {
	return [string range $text [string length $prefix] end]
    } else {
	return $text
    }
}


# @c Removes the Heading Empty Lines of <a text>.
#
# @a text: The text block to manipulate.
#
# @r The <a text>, but without heading empty lines.
#
# @i remove, empty lines

proc ::textutil::trim::trimEmptyHeading {text} {
    regsub -- "^(\[ \t\]*\n)*" $text {} text
    return $text
}

# ### ### ### ######### ######### #########
## Helper commands. Internal

proc ::textutil::trim::MakeStr { string pos }  {
    variable StrU
    variable StrR
    variable StrL

    if { "$string" != "$StrU" } {
        set StrU $string
        set StrR "(${StrU})\$"
        set StrL "^(${StrU})"
    }
    if { "$pos" == "left" } {
        return $StrL
    }
    if { "$pos" == "right" } {
        return $StrR
    }

    return -code error "Panic, illegal position key \"$pos\""
}

# ### ### ### ######### ######### #########
## Data structures

namespace eval ::textutil::trim {	    
    variable StrU "\[ \t\]+"
    variable StrR "(${StrU})\$"
    variable StrL "^(${StrU})"

    namespace export \
	    trim trimright trimleft \
	    trimPrefix trimEmptyHeading
}

# ### ### ### ######### ######### #########
## Ready

package provide textutil::trim 0.7
