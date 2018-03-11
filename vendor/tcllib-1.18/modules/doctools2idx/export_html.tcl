# text.tcl --
#
#	The HTML export plugin. Generation of HTML markup.
#
# Copyright (c) 2009 Andreas Kupries <andreas_kupries@sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: export_html.tcl,v 1.3 2009/08/07 18:53:11 andreas_kupries Exp $

# This package is a plugin for the doctools::idx v2 system.  It takes
# the list serialization of a keyword index and produces text in HTML
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
package require doctools::idx::structure ; # Verification that the
					   # input is proper.
package require doctools::html
package require doctools::html::cssdefaults

doctools::html::import ;# -> ::html::*

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

    # * HTML specific entries
    #   - newlines = boolean. tags separated by eol markers
    #   - indented = boolean. tags indented per their nesting structure.
    #   //layout   = string in { list, table }.
    #
    #   - meta   = HTML fragment for use within the document <meta> section.
    #   - header = HTML fragment used immediately after <body>
    #   - footer = HTML fragment used immediately before </body>
    #
    #   - kwid   = dictionary mapping keywords to link anchor names.
    #     <=> KeyWord IDentifier
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
	kwid      {}
	map       {}
	sepline   ------------------------------------------------------------
	kwidth         35
	dot            {&#183;}
	class.main     doctools
	class.header   idx-header
	class.title    idx-title
	class.navsep   idx-navsep
	class.navbar   idx-kwnav
	class.contents idx-contents
	class.leader   idx-leader
	class.row0     idx-even
	class.row1     idx-odd
	class.keyword  idx-keyword
	class.refs     idx-refs
	class.footer   idx-footer
    }
    array set config $configuration
    array set map    $config(map)
    array set kwid   $config(kwid)

    if {($config(kwidth) < 1) || ($config(kwidth) > 99)} {
	set config(kwidth) 35
    }
    set config(rwidth) [expr {100 - $config(kwidth)}]


    # Force the implications mentioned in the notes above.
    if {$config(indented)} {
	set config(newlines) 1
    }

    # Allow structuring comments iff structure is present.
    set config(comments) [expr {$config(indented) || $config(newlines)}]

    array set anchor {}
    set dot {&#183;}

    # ### ### ### ######### ######### #########

    # Phase II. Generate the output, taking the configuration into
    #           account.

    # Unpack the serialization.
    array set idx $serial
    array set idx $idx(doctools::idx)
    unset     idx(doctools::idx)
    array set r $idx(references)
    array set k $idx(keywords)

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
    upvar 1 config config idx idx
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
    upvar 1 config config idx idx dot dot anchor anchor kwid kwid k k r r
    html::tag* body {
	html::newline ; html::indented 4 {
	    html::tag* div class $config(class.main) {
		html::newline ; html::indented 4 {
		    html::tag* div class $config(class.header) {
			html::newline ; html::indented 4 {
			    BodyTitle
			    UserHeader
			    html::tag1 hr class $config(class.navsep) ; html::newline
			    NavigationBar
			}
		    } ;	html::newline
		    Keywords
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
    upvar 1 idx idx config config
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

proc DefaultStyle {} {
    html::comment \n[doctools::html::cssdefaults::contents]
    return
}

# ### ### ### ######### ######### #########

proc NavigationBar {} {
    upvar 1 config config idx idx anchor anchor kwid kwid char char

    # No navigation bar for an empty index.

    if {![llength $idx(keywords)]} return

    # Name each keyword, if that was not done already. And sort them
    # into bins based on their first character (always taken as upper
    # case, i.e. X and x are the same).

    foreach {keyword references} $idx(keywords) {
	if {![info exists kwid($keyword)]} {
	    set kwid($keyword) KW-$keyword
	}
	lappend char([string toupper [string index $keyword 0]]) $keyword
    }

    # Now name each character

    set counter 0
    foreach c [lsort -dict [array names char]] {
	set anchor($c) KEYWORDS-$c
	incr counter
    }

    # Now we have the information we can construct the nav bar from.

    # NOTE: Should I do this as ul/ ?  Then the CSS can select the
    # location of the navbar, its orientation, and how the elements
    # are joined. Right ?!

    Separator {Navigation Bar}
    html::newline
    set sep 0
    html::tag* div class $config(class.navbar) {
	html::newline ; html::indented 4 {
	    foreach c [lsort -dict [array names char]] {
		if {$sep} {
		    html::++ " $config(dot)"
		    if {![html::newline]} { html::++ " " }
		}
		html::tag= a href #$anchor($c) $c
		set sep 1
	    }
	    html::newline
	}
    } ; html::newline
    return
}

proc Keywords {} {
    upvar 1 config config idx idx anchor anchor dot dot kwid kwid char char k k r r

    # No content for an empty index.

    if {![llength $idx(keywords)]} return

    # Process the characters and associated keywords.

    set rows [list $config(class.row0) $config(class.row1)]

    Separator Contents
    html::newline
    html::tag* table class $config(class.contents) width 100% {
	html::newline ; html::indented 4 {
	    foreach c [lsort -dict [array names char]] {
		Separator "($c)"
		html::newline
		Leader $c
		foreach kw $char($c) {
		    Keyword $kw
		}
	    }
	    Separator
	    html::newline
	}
    } ; html::newline
    return
}

proc Leader {char} {
    upvar 1 anchor anchor config config

    html::tag* tr class $config(class.leader) {
	html::tag* th colspan 2 {
	    html::tag= a name $anchor($char) "Keywords: $char"
	}
    } ; html::newline
    return
}

proc Keyword {kw} {
    upvar 1 config config rows rows kwid kwid k k r r

    html::tag* tr class [Row] {
	html::newline ; html::indented 4 {
	    html::tag* td width $config(kwidth)% class $config(class.keyword) {
		html::tag= a name $kwid($kw) $kw
	    } ; html::newline
	    html::tag* td width $config(rwidth)% class $config(class.refs) {
		if {[llength $k($kw)]} {
		    html::newline ; html::indented 4 {
			References $kw
		    }
		}
	    } ; html::newline
	}
    } ; html::newline
    return
}

proc References {kw} {
    upvar 1 config config k k r r
    # Iterate over the references of the key
    set sep 0
    foreach id $k($kw) {
	foreach {type label} $r($id) break
	if {$sep} {
	    html::++ " $config(dot)"
	    if {![html::newline]} { html::++ " " }
	}
	html::tag= a href [Map $type $id] $label
	set sep 1
    }
    html::newline
    return
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
    return
}

proc Row {} {
    upvar 1 rows rows
    foreach {a b} $rows break
    set rows [list $b $a]
    return $a
}

proc Map {type id} {
    if {$type eq "url"} { return $id }
    upvar 1 map map
    if {![info exists map($id)]} { return $id }
    return $map($id)
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

package provide doctools::idx::export::html 0.2
return
