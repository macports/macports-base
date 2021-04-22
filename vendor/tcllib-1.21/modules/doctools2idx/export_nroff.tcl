# text.tcl --
#
#	The NROFF export plugin. Generation of man.macros based nroff markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_nroff.tcl,v 1.4 2009/08/07 18:53:11 andreas_kupries Exp $

# This package is a plugin for the doctools::idx v2 system.  It takes
# the list serialization of a keyword index and produces text in nroff
# format, man.macros based.

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
package require doctools::idx::structure    ; # Verification that the
					      # input is proper.
package require doctools::text              ; # Text assembly package
package require doctools::nroff::man_macros ; # Macro definitions for result.

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
    #   - map    = maps symbolic references to actual file path. Ignored
    #
    # Specific
    #   - inline = boolean. if set (default) man.macros is inlined in
    #              the output. other a .so reference to the file is
    #              generated.

    # Import the configuration and initialize the internal state

    array set config {
	inline 1
    }
    array set config $configuration

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account.

    # Unpack the serialization.
    array set idx $serial
    array set idx $idx(doctools::idx)
    unset     idx(doctools::idx)
    array set r $idx(references)

    text::begin
    text::indenting 0 ; # Just in case someone tries to.

    Provenance
    if {$config(inline)} {
	text::newline?
	text::+ [doctools::nroff::man_macros::contents]
    } else {
	.so man.macros
    }
    .TH $idx(label)
    .SH index
    if {$idx(title) ne {}} {
	text::+ $idx(title)
    }
    .RS

    # Iterate over the keys and their references
    foreach {keyword references} $idx(keywords) {
	# Print the key
	text::+ $keyword
	text::newline
	# Iterate over the references
	.RS
	foreach id $references {
	    foreach {type label} $r($id) break
	    .TP [BOLD $id]
	    text::newline
	    text::+ $label
	    text::newline
	}
	.RE
	if {[llength $references]} {
	    .PP
	}
    }

    return [text::done]
}

# ### ### ### ######### ######### #########

proc Provenance {} {
    upvar 1 config config
    COMMENT  "Generated @ [clock format [clock seconds]]"
    COMMENT  "By          $config(user)"
    if {[info exists config(file)] && ($config(file) ne {})} {
	COMMENT "From file   $config(file)"
    }
    return
}

proc .so {file} {
    text::newline?
    text::+ ".so $file"
    text::newline
    return
}

proc .TP {text} {
    text::newline?
    text::+ .TP
    text::newline
    text::+ $text
    return
}

proc COMMENT {text} {
    set pfx "'\\\" " ;#
    text::newline?

    foreach line [split $text \n] {
	text::+ $pfx
	text::+ $line
	text::newline
    }
    #text::+ $pfx[join [split $text \n] \n$pfx]
    return
}

proc BOLD {text} {
    return \\fB$text\\fR
}

proc .RS {} {
    text::newline?
    text::+ .RS
    text::newline
    return
}

proc .RE {} {
    text::newline?
    text::+ .RE
    text::newline
    return
}

proc .PP {} {
    text::newline?
    text::+ .PP
    text::newline
    return
}

proc .SH {name} {
    text::newline?
    text::+ ".SH "
    set hasspaces [regexp {[ 	]} $name]
    set name [string toupper $name]

    if {$hasspaces} { text::+ \" }
    text::+ $name
    if {$hasspaces} { text::+ \" }
    text::newline
    return
}

proc .TH {name} {
    text::newline?
    text::+ ".TH "
    set hasspaces [regexp {[ 	]} $name]
    set name [string toupper $name]

    if {$hasspaces} { text::+ \" }
    text::+ $name
    if {$hasspaces} { text::+ \" }
    text::newline
    return
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::idx::export::nroff 0.3
return
