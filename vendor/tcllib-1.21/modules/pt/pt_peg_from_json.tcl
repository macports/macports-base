# peg_from_json.tcl --
#
#	Conversion to PEG from JSON (Java Script Object Notation).
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: pt_peg_from_json.tcl,v 1.1 2010/03/26 05:07:24 andreas_kupries Exp $

# This package takes text in JSON format (Java Script data transfer
# format) and produces the canonical serialization of a parsing
# expression grammar.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require pt::peg ; # Verification that the input is proper.
package require json

# ### ### ### ######### ######### #########
##

namespace eval ::pt::peg::from::json {
    namespace export convert
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API.

proc ::pt::peg::from::json::convert {text} {
    # Note: We cannot fail here on duplicate keys in the input, as we
    # do for Tcl-based canonical PEG serializations, because our
    # underlying JSON parser automatically merges them, by taking only
    # the last found definition. I.e. of two or more definitions for
    # some key X the last overwrites all previous occurences.

    return [pt::peg canonicalize [json::json2dict $text]]
}

# ### ### ### ######### ######### #########
## Ready

package provide pt::peg::from::json 1
return
