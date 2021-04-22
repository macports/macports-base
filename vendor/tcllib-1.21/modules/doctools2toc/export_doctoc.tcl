# doctoc.tcl --
#
#	The doctoc export plugin. Generation of doctoc markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_doctoc.tcl,v 1.3 2009/11/15 05:50:03 andreas_kupries Exp $

# This package is a plugin for the doctools::toc v2 system.  It takes
# the list serialization of a table of contents and produces text in
# doctoc format.

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
package require doctools::toc::structure      ; # Verification that
						# the input is proper.

# ### ### ### ######### ######### #########
## API.

proc export {serial configuration} {

    # Phase I. Check that we got a canonical ToC serialization. That
    #          makes the unpacking easier, as we can mix it with the
    #          generation of the output, knowing that everything is
    #          already sorted as it should be.

    ::doctools::toc::structure verify-as-canonical $serial

    # ### ### ### ######### ######### #########
    # Configuration ...
    # * Standard entries
    #   - user   = person running the application doing the formatting
    #   - format = name of this format
    #   - file   = name of the file the ToC came from. Optional.
    #   - map    = maps symbolic document ids to actual file path or url. Optional.
    # * doctoc specific entries
    #   - newlines = boolean. tags separated by eol markers
    #   - indented = boolean. tags indented per the toc structure.
    #   - aligned  = boolean. reference information tabular aligned within keys.
    #
    # Notes
    # * This format ignores 'map' even if set, as the written doctoc
    #   contains the symbolic document ids and only them.
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
    array set toc $serial
    array set toc $toc(doctools::toc)
    unset     toc(doctools::toc)

    # Now open the markup

    Tag+ toc_begin [list $toc(label) $toc(title)]
    PrintItems $toc(items) {    } {    }
    TagPrefix {}
    Tag+ toc_end

    # Last formatting, joining the commands together.
    set sep [expr {$config(newlines) ? "\n" : ""}]
    return [join $lines $sep]

    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########

proc PrintItems {items indentation increment} {
    upvar 1 config config prefix prefix lines lines

    if {$config(aligned)} {
	set imax 0
	set lmax 0
	foreach element $items {
	    foreach {etype edata} $element break
	    if {$etype eq "division"} { continue }
	    array set toc $edata
	    Max imax [list $toc(id)]
	    Max lmax [list $toc(label)]
	    unset toc
	}
    }

    foreach element $items {
	if {$config(indented)} {TagPrefix $indentation}
	foreach {etype edata} $element break
	array set toc $edata
	switch -exact -- $etype {
	    reference {
		if {$config(aligned)} {
		    Tag+ item [FmtR imax $toc(id)] [FmtR lmax $toc(label)] [list $toc(desc)]
		} else {
		    Tag+ item [list $toc(id) $toc(label) $toc(desc)]
		}
	    }
	    division {
		if {[info exists toc(id)]} {
		    Tag+ division_start [list $toc(label) $toc(id)]
		} else {
		    Tag+ division_start [list $toc(label)]
		}
		PrintItems $toc(items) $indentation$increment $increment
		if {$config(indented)} {TagPrefix $indentation}
		Tag+ division_end
	    }
	}
	unset toc
    }
    return
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

package provide doctools::toc::export::doctoc 0.1
return
