# text.tcl --
#
#	The HTML export plugin. Generation of HTML markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_html.tcl,v 1.3 2009/11/15 05:50:03 andreas_kupries Exp $

# This package is a plugin for the doctools::toc v2 system.  It takes
# the list serialization of a table of contents and produces text in
# HTML format.

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
package require doctools::html
package require doctools::html::cssdefaults

doctools::html::import ;# -> ::html::*

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

    # * HTML specific entries
    #   - newlines = boolean. tags separated by eol markers
    #   - indented = boolean. tags indented per their nesting structure.
    #   //layout   = string in { list, table }.
    #
    #   - meta   = HTML fragment for use within the document <meta> section.
    #   - header = HTML fragment used immediately after <body>
    #   - footer = HTML fragment used immediately before </body>
    #
    #   - rid   = dictionary mapping element labels to link anchor names.
    #     <=> Reference IDentifier
    # 
    # Notes
    # * indented => newlines

    # Import the configuration and initialize the internal state
    #// layout    list
    array set config {
	newlines  0
	indented  0
	meta      {}
	header    {}
	footer    {}
	rid      {}
	map       {}
	sepline   ------------------------------------------------------------
	class.main     doctools
	class.header   toc-header
	class.title    toc-title
	class.navsep   toc-navsep
	class.contents toc-contents
	class.ref      toc-ref
	class.div      toc-div
	class.footer   toc-footer
    }
    array set config $configuration
    array set map    $config(map)
    array set rid    $config(rid)

    # Force the implications mentioned in the notes above.
    if {$config(indented)} {
	set config(newlines) 1
    }

    # Allow structuring comments iff structure is present.
    set config(comments) [expr {$config(indented) || $config(newlines)}]

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account.

    # Unpack the serialization.
    array set toc $serial
    array set toc $toc(doctools::toc)
    unset     toc(doctools::toc)

    html::begin
    # Configure the layouting
    if {!$config(indented)} { html::indenting 0 }
    if {!$config(newlines)} { html::newlines  0 }

    html::tag* html {
	html::newline ; html::indented 4 {
	    Header
	    Provenance
	    Body
	}
    }

    return [html::done]
}

# ### ### ### ######### ######### #########

proc Header {} {
    upvar 1 config config toc toc
    html::tag* head {
	html::newline ; html::indented 4 {
	    html::tag= title [Title] ; html::newline
	    if {![Extend meta]} {
		html::tag* style {
		    DefaultStyle
		} ; html::newline
	    }
	}
    } ; html::newline
    return
}

proc Provenance {} {
    upvar 1 config config
    if {!$config(comments)} return
    html::comment [html::collect {
	html::indented 4 {
	    html::+  "Generated @ [clock format [clock seconds]]" ; html::newline
	    html::+  "By          $config(user)"                  ; html::newline
	    if {[info exists config(file)] && ($config(file) ne {})} {
		html::+ "From file   $config(file)" ; html::newline
	    }
	}
    }] ; html::newline
    return
}

proc Body {} {
    upvar 1 config config rid rid toc toc
    html::tag* body {
	html::newline ; html::indented 4 {
	    html::tag* div class $config(class.main) {
		html::newline ; html::indented 4 {
		    html::tag* div class $config(class.header) {
			html::newline ; html::indented 4 {
			    BodyTitle
			    UserHeader
			    html::tag1 hr class $config(class.navsep) ; html::newline
			}
		    } ;	html::newline
		    Division $toc(items) {} {Table Of Contents}
		    html::tag* div class $config(class.footer) {
			html::newline ; html::indented 4 {
			    html::tag1 hr class $config(class.navsep) ; html::newline
			    UserFooter
			}
		    } ; html::newline
		}
	    } ; html::newline
	}
    } ; html::newline
    return
}

# ### ### ### ######### ######### #########

proc BodyTitle {} {
    upvar 1 toc toc config config
    html::tag= h1 class $config(class.title) [Title] ; html::newline
    return
}

proc UserHeader {} {
    upvar 1 config config
    Extend header
    html::newline
    return
}

proc UserFooter {} {
    upvar 1 config config
    Extend footer
    html::newline
    return
}

# ### ### ### ######### ######### #########

proc Title {} {
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

proc DefaultStyle {} {
    html::comment \n[doctools::html::cssdefaults::contents]
    return
}

# ### ### ### ######### ######### #########

proc Division {items path seplabel} {
    upvar 1 config config rid rid map map

    # No content for an empty division
    if {![llength $items]} return

    # Process the elements in a division.

    Separator "Start $seplabel"

    html::tag* dl class $config(class.contents) {
	html::newline ; html::indented 4 {
	    foreach element $items {
		foreach {etype edata} $element break
		array set e $edata
		switch -exact -- $etype {
		    reference {
			html::tag* dt class $config(class.ref) {
			    RMap $e(label)
			    html::tag= a href [Map $e(id)] $e(label)
			}
			html::newline
			html::tag= dd class $config(class.ref) $e(desc)
			html::newline
		    }
		    division {
			html::tag* dt class $config(class.div) {
			    RMap $e(label)
			    if {[info exists e(id)]} {
				html::tag= a href [Map $e(id)] $e(label)
			    } else {
				html::+ $e(label)
			    }
			}
			html::newline
			html::tag* dd class $config(class.div) {
			    html::newline ; html::indented 4 {
				Division $e(items) [linsert $path end $e(label)] "Division ($e(label))"
			    }
			} ; html::newline
		    }
		}
		unset e
	    }
	}
    } ; html::newline
    Separator "Stop  $seplabel"
}

# ### ### ### ######### ######### #########

proc Separator {{text {}}} {
    upvar config config
    if {!$config(comments)} return
    set str $config(sepline)
    if {$text ne {}} {
	set new " $text "
	set str [string replace $str 1 [string length $new] $new]
    }
    html::comment $str
    html::newline
    return
}

proc Map {id} {
    upvar 1 map map
    if {![info exists map($id)]} { return $id }
    return $map($id)
}

proc RMap {label} {
    upvar 1 rid rid path path
    set k [linsert $path end $label]
    if {![info exists rid($k)]} return
    html::tag/ a name $rid($k)
}

proc Extend {varname} {
    upvar 1 config config
    if {$config($varname) eq {}} {
	if {$config(comments)} {
	    html::comment "Customization Point: $varname"
	}
	return 0
    }
    html::+++ $config($varname)
    return 1
}

# ### ### ### ######### ######### #########
## Ready

package provide doctools::toc::export::html 0.1
return
