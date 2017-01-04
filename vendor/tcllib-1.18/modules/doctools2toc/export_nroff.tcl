# text.tcl --
#
#	The NROFF export plugin. Generation of man.macros based nroff markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_nroff.tcl,v 1.4 2009/11/15 05:50:03 andreas_kupries Exp $

# This package is a plugin for the doctools::toc v2 system.  It takes
# the list serialization of a table of contents and produces text in
# nroff format, man.macros based.

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
package require doctools::toc::structure    ; # Verification that the
					      # input is proper.
package require doctools::text              ; # Text assembly package
package require doctools::nroff::man_macros ; # Macro definitions for result.

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
    array set toc $serial
    array set toc $toc(doctools::toc)
    unset     toc(doctools::toc)

    text::begin
    text::indenting 0 ; # Just in case someone tries to.

    Provenance
    if {$config(inline)} {
	text::newline?
	text::+ [doctools::nroff::man_macros::contents]
    } else {
	.so man.macros
    }
    .TH $toc(label)
    .SH {table of contents}
    if {$toc(title) ne {}} {
	text::+ $toc(title)
    }

    Division $toc(items)
    return [text::done]
}

proc Division {items} {
    if {![llength $items]} return
    .RS

    foreach element $items {
	foreach {etype edata} $element break
	array set e $edata
	switch -exact -- $etype {
	    reference {
		.TP [BOLD $e(label)]
		text::newline
		text::+ $e(desc)
		text::newline
	    }
	    division {
		.TP [BOLD $e(label)]
		text::newline
		Division $e(items)
	    }
	}
	unset e
    }
    .RE
    return
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

package provide doctools::toc::export::nroff 0.2
return
