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
# RCS: @(#) $Id: export_text.tcl,v 1.3 2009/11/15 05:50:03 andreas_kupries Exp $

# This package is a plugin for the the doctools::toc v2 system.  It
# takes the list serialization of a table of contents and produces
# text in text format.

# ### ### ### ######### ######### #########
## Requisites

# @mdgen NODEP: doctools::toc::export::plugin

package require Tcl 8.4
package require doctools::toc::export::plugin ; # Presence of this
						# pseudo package
						# indicates execution
						# inside of a properly
						# initialized plugin
						# interpreter.
package require doctools::toc::structure ; # Verification that the
					   # input is proper.
package require doctools::text           ; # Text assembly package

doctools::text::import ;# -> ::text::*

# ### ### ### ######### ######### #########
## API. 

proc export {serial configuration} {

    # Phase I. Check that we got a canonical toc serialization. That
    #          makes the unpacking easier, as we can mix it with the
    #          generation of the output, knowing that everything is
    #          already sorted as it should be.

    ::doctools::toc::structure verify-as-canonical $serial

    # ### ### ### ######### ######### #########
    # Configuration ...
    # * Standard entries
    #   - user   = person running the application doing the formatting
    #   - format = name of this format
    #   - file   = name of the file the toc came from. Optional.
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
    array set toc $serial
    array set toc $toc(doctools::toc)
    unset     toc(doctools::toc)

    text::begin
    text::+ [Header]
    text::underline =

    # Iterate over the keys and their references
    PrintDivision $toc(items)

    # Return final assembled text
    return [text::done]
}

proc PrintDivision {items} {
    foreach element $items {
	foreach {etype edata} $element break
	array set toc $edata

	switch -exact -- $etype {
	    reference {
		text::newline
		text::+ "[Map $toc(id)] : $toc(label)"
		text::newline
		text::indented 4 { text::+ $toc(desc) }
		text::newline
	    }
	    division {
		text::newline
		if {[info exists toc(id)]} {
		    text::+ "[Map $toc(id)] : $toc(label)"
		} else {
		    text::+ "$toc(label)"
		}
		text::underline -
		text::indented 4 {
		    PrintDivision $toc(items)
		}
		text::newline
	    }
	}
    }
    return
}

# ### ### ### ######### ######### #########

proc Header {} {
    upvar 1 toc(label) label toc(title) title
    if {($label ne {}) && ($title ne {})} {
	return "$label -- $title"
    } elseif {$label ne {}} {
	return $label
    } elseif {$title ne {}} {
	return $title
    }
    return -code error {Reached the unreachable}
}

proc Map {id} {
    upvar 1 map map
    if {![info exists map($id)]} { return $id }
    return $map($id)
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc::export::text 0.1
return
