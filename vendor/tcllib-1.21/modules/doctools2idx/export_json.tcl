# json.tcl --
#
#	The JSON export plugin. Generation of Java Script Object Notation.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_json.tcl,v 1.2 2009/08/07 18:53:11 andreas_kupries Exp $

# This package is a plugin for the doctools::idx v2 system.  It takes
# the list serialization of a keyword index and produces text in JSON
# format.

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
package require textutil::adjust

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
    # * json/format specific entries
    #   - indented = boolean. objects indented per the index structure.
    #   - aligned  = boolean. object keys tabular aligned vertically.
    #
    # Notes
    # * This format ignores 'map' even if set, as the written json
    #   contains the symbolic references and only them.
    # * aligned  => indented

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
	indented 0
	aligned  0
    }
    array set config $configuration

    # Force the implications mentioned in the notes above.
    if {$config(aligned)} {
	set config(indented) 1
    }

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account. We construct this from the inside out.

    # Unpack the serialization.
    array set idx $serial
    array set idx $idx(doctools::idx)
    unset     idx(doctools::idx)

    set keywords {}
    foreach {kw references} $idx(keywords) {
	set tmp {}
	foreach id $references { lappend tmp [JsonString $id] }
	lappend keywords $kw [JsonArrayList $tmp]
    }

    if {$config(aligned)} { set max 9 }

    set references {}
    foreach {id decl} $idx(references) {
	foreach {type label} $decl break
	set type  [JsonString $type]
	set label [JsonString $label]
	if {$config(aligned)} {
	    set type [FmtR max $type]
	}
	lappend references $id [JsonArray $type $label]
    }

    return [JsonObject doctools::idx \
		[JsonObject \
		     label      [JsonString $idx(label)] \
		     keywords   [JsonObjectDict $keywords] \
		     references [JsonObjectDict $references] \
		     title      [JsonString $idx(title)]]]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

proc JsonQuotes {} {
    return [list "\"" "\\\"" / \\/ \\ \\\\ \b \\b \f \\f \n \\n \r \\r \t \\t]
}

proc JsonString {s} {
    return "\"[string map [JsonQuotes] $s]\""
}

proc JsonArray {args} {
    upvar 1 config config
    return [JsonArrayList $args]
}

proc JsonArrayList {list} {
    # compact form.
    return "\[[join $list ,]\]"
}

proc JsonObject {args} {
    upvar 1 config config
    return [JsonObjectDict $args]
}

proc JsonObjectDict {dict} {
    # The dict maps string keys to json-formatted data. I.e. we have
    # to quote the keys, but not the values, as the latter are already
    # in the proper format.
    upvar 1 config config

    set tmp {}
    foreach {k v} $dict { lappend tmp [JsonString $k] $v }
    set dict $tmp

    if {$config(aligned)} { Align $dict max }

    if {$config(indented)} {
	set content {}
	foreach {k v} $dict {
	    if {$config(aligned)} { set k [FmtR max $k] }
	    if {[string match *\n* $v]} {
		# multi-line value
		lappend content "    $k : [textutil::adjust::indent $v {    } 1]"
	    } else {
		# single line value.
		lappend content "    $k : $v"
	    }
	}
	if {[llength $content]} {
	    return "\{\n[join $content ,\n]\n\}"
	} else {
	    return "\{\}"
	}
    } else {
	# ultra compact form.
	set tmp {}
	foreach {k v} $dict { lappend tmp "$k:$v" }
	return "\{[join $tmp ,]\}"
    }
}

proc Align {dict mv} {
    upvar 1 $mv max
    # Generate a list of references sortable by name, and also find the
    # max length of all relevant names.
    set max 0
    foreach {str _} $dict { Max max $str }
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
    return $str[string repeat { } [expr {$max - [string length $str]}]]
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::idx::export::json 0.1
return
