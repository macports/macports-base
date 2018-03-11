# docidx.tcl --
#
#	The docidx export plugin. Generation of docidx markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_docidx.tcl,v 1.3 2009/08/07 18:53:11 andreas_kupries Exp $

# This package is a plugin for the doctools::idx v2 system.  It takes
# the list serialization of a keyword index and produces text in
# docidx format.

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
package require doctools::idx::structure      ; # Verification that
						# the input is proper.

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
    # * docidx specific entries
    #   - newlines = boolean. tags separated by eol markers
    #   - indented = boolean. tags indented per the index structure.
    #   - aligned  = boolean. reference information tabular aligned within keys.
    #
    # Notes
    # * This format ignores 'map' even if set, as the written docidx
    #   contains the symbolic references and only them.
    # * aligned  => newlines
    # * indented => newlines

    # Combinations of the format specific entries
    # N I A |
    # - - - + ---------------------
    # 0 0 0 | Ultracompact (no whitespace, single line)
    # 1 0 0 | Compact (no whitespace, multiple lines)
    # 1 1 0 | Indented
    # 1 0 1 | Tabular aligned references
    # 1 1 1 | Indented + Tabular aligned references
    # - - - + ---------------------
    # 0 1 0 | Not possible, per the implications above.
    # 0 0 1 | ditto
    # 0 1 1 | ditto
    # - - - + ---------------------

    # Import the configuration and initialize the internal state
    array set config {
	newlines 0
	aligned  0
	indented 0
    }
    array set config $configuration
    array set types {
	manpage {manpage}
	url     {url    }
    }

    # Force the implications mentioned in the notes above.
    if {
	$config(aligned) ||
	$config(indented)
    } {
	set config(newlines) 1
    }

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account.

    TagsBegin

    # First some comments about the provenance of the output.
    Tag+ comment [list "Generated @ [clock format [clock seconds]]"]
    Tag+ comment [list "By          $config(user)"]
    if {[info exists config(file)] && ($config(file) ne {})} {
	Tag+ comment [list "From file   $config(file)"]
    }

    # Unpack the serialization.
    array set idx $serial
    array set idx $idx(doctools::idx)
    unset     idx(doctools::idx)
    array set r $idx(references)

    # Now open the markup

    Tag+ index_begin [list $idx(label) $idx(title)]

    # Iterate over the keys and their references
    foreach {keyword references} $idx(keywords) {
	# Print the key
	if {$config(indented)} {TagPrefix {    }}
	Tag+ key [list $keyword]

	# Print the references in the key
	if {$config(aligned)} { Align $references max }
	if {$config(indented)} {TagPrefix {        }}

	# Iterate over the references
	foreach id $references {
	    foreach {type label} $r($id) break
	    if {$config(aligned)} { 
		set id [FmtR max $id]
		set type $types($type)
	    } else {
		set id [list $id]
	    }
	    Tag+ $type $id [list $label]
	}
    }

    # Close the index
    TagPrefix {}
    Tag+ index_end

    # Last formatting, joining the commands together.
    set sep [expr {$config(newlines) ? "\n" : ""}]
    return [join $lines $sep]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

proc TagPrefix {str} {
    upvar 1 prefix prefix
    set    prefix $str
    return
}

proc TagsBegin {} {
    upvar 1 prefix prefix lines lines
    set prefix {}
    set lines  {}
    return
}

proc Tag {n args} {
    upvar 1 prefix prefix
    set    cmd $prefix
    append cmd \[$n
    if {[llength $args]} { append cmd " [join $args]" }
    append  cmd \]
    return $cmd
}

proc Tag+ {n args} {
    upvar 1 prefix prefix lines lines
    lappend lines [eval [linsert $args 0 Tag $n]]
    return
}

proc Align {references mv} {
    upvar 1 $mv max r r
    # Generate a list of references sortable by name, and also find the
    # max length of all relevant names.
    set max 0
    foreach id $references {
	Max max [list $id]
    }
    return
}

proc Max {v str} {
    upvar 1 $v max
    set x [string length $str]
    if {$x <= $max} return
    set max $x
    return
}

proc FmtR {v str} {
    upvar 1 $v max
    return [list $str][string repeat { } [expr {$max - [string length [list $str]]}]]
}

# ### ### ### ######### ######### #########
## Ready
package provide doctools::idx::export::docidx 0.1
return
