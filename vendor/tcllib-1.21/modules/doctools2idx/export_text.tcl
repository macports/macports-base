# text.tcl --
#
#	The text export plugin. Generation of plain text (ReST -
#	re-structured text).
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_text.tcl,v 1.3 2009/08/07 18:53:11 andreas_kupries Exp $

# This package is a plugin for the the doctools::idx v2 system.  It
# takes the list serialization of a keyword index and produces text in
# text format.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: doctools::idx::export::plugin

package require Tcl 8.4
package require doctools::idx::export::plugin ; # Presence of this
						# pseudo package
						# indicates execution
						# inside of a properly
						# initialized plugin
						# interpreter.
package require doctools::idx::structure ; # Verification that the
					   # input is proper.
package require doctools::text           ; # Text assembly package

doctools::text::import ;# -> ::text::*

# ### ### ### ######### ######### #########
## API. 

proc export {serial configuration} {

    # Phase I. Check that we got a canonical index serialization. That
    #          makes the unpacking easier, as we can mix it with the
    #          generation of the output, knowing that everything is
    #          already sorted as it should be.

    ::doctools::idx::structure verify-as-canonical $serial

    # ### ### ### ######### ######### #########
    # Configuration ...
    # * Standard entries
    #   - user   = person running the application doing the formatting
    #   - format = name of this format
    #   - file   = name of the file the index came from. Optional.
    #   - map    = maps symbolic references to actual file path. Optional.

    # //possible parameters to influence the output.
    # //* symbolic mapping off/on

    # Import the configuration and initialize the internal state

    array set config $configuration
    array set map    {}
    if {[info exists config(map)]} {
	array set map $config(map)
    }

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account.

    # Unpack the serialization.
    array set idx $serial
    array set idx $idx(doctools::idx)
    unset     idx(doctools::idx)
    array set r $idx(references)

    text::begin
    text::+ [Header]
    text::underline =

    # Iterate over the keys and their references
    foreach {keyword references} $idx(keywords) {
	# Print the key
	text::newline
	text::+ $keyword
	text::underline -

	# Print the references in the key
	set tmp {}
	foreach id $references { lappend tmp [lindex $r($id) end] }
	text::field lwidth $tmp
	unset tmp

	# Iterate over the references
	foreach id $references {
	    foreach {type label} $r($id) break
	    text::indented 4 {
		# maybe special field/tabulation commands.
		text::+ [text::left lwidth $label]
		text::+ { }
		text::+ ([Map $type $id])
		text::newline
	    }
	}
    }

    # Return final assembled text
    return [text::done]
}

# ### ### ### ######### ######### #########

proc Header {} {
    upvar 1 idx(label) label idx(title) title
    if {($label ne {}) && ($title ne {})} {
	return "$label -- $title"
    } elseif {$label ne {}} {
	return $label
    } elseif {$title ne {}} {
	return $title
    }
    return -code error {Reached the unreachable}
}

proc Map {type id} {
    if {$type eq "url"} { return $id }
    upvar 1 map map
    if {![info exists map($id)]} { return $id }
    return $map($id)
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::idx::export::text 0.2
return
