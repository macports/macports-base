# -*- tcl -*-
# Convert a doctools document into markdown formatted text
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>

# Note: While markdown is a text format its intended target is HTML,
# making its formatting nearer to that with the ability to set anchors
# and refer to them, linkage in general.

# Notes, Attention
# - A number of characters are special to markdown. Such characters in
#   user input are \-quoted to make them non-special to the markdown
#   processor handling our generated document.
#
# - Exceptions are the special characters in verbatim code-blocks
#   (indent 4), and in `...` sequences (verbatim inline). In such
#   blocks they are not special and must not be quoted.
#
#   The generator currently only used verbatim blocks, for doctools
#   examples. It does not use verbatim inlines.

# # ## ### ##### ######## #############
## Load shared code and modify it to our needs.

dt_source _common.tcl
dt_source _text.tcl
dt_source fmt.text
dt_source _markdown.tcl
dt_source _xref.tcl

# # ## ### ##### ########
## Override crucial parts of the regular text formatter

proc In? {} {
    if {![CAttrHas mdindent]} {
	CAttrSet mdindent ""
    }
    CAttrGet mdindent
}

proc In! {ws} {
    CAttrSet mdindent $ws
}

proc Example {complex} {
    if {![CAttrHas exenv$complex]} {
	ContextPush
	set exenv [NewExample $complex]
	ContextPop
	CAttrSet exenv$complex $exenv
	ContextCommit
    }
    return [CAttrGet exenv$complex]
}

proc NewExample {complex} {
    return [ContextNew Example$complex {
	VerbatimOn
	Example!
	if {$complex} {
	    # Block quote
	    Prefix+ "> "
	} else {
	    # Code block
	    Prefix+ "    "
	}
    }] ; # {}
}

proc NewUnorderedList {} {
    # Itemized list - unordered list - bullet
    # 1. Base context provides indentation.
    # 2. First paragraph in a list item.
    # 3. All other paragraphs.
    ContextPush

    #puts_stderr "UL [CAttrName]"
    #puts_stderr "UL |[string map {{ } _} [In?]]|outer"

    set base [ContextNew Itemized {
	LC
	set bullet "[In?]  [IBullet]"
	set ws     "[BlankM $bullet] "
	In! $ws
    }] ; # {}

    #puts_stderr "UL |[string map {{ } _} $bullet]|[string length $bullet]"
    #puts_stderr "UL |[string map {{ } _} $ws]|[string length $ws]"

    set first [ContextNew First {
	List! bullet $bullet $ws
    }] ; ContextSet $base ; # {}

    set next [ContextNew Next {
	WPrefix! $ws
	Prefix!  $ws
    }] ; ContextSet $base ; # {}

    OUL $first $next
    ContextCommit

    ContextPop
    ContextSet $base
    return
}

proc NewOrderedList {} {
    # Ordered list - enumeration - enum
    # 1. Base context provides indentation.
    # 2. First paragraph in a list item.
    # 3. All other paragraphs.
    ContextPush

    #puts_stderr "OL [CAttrName]"
    #puts_stderr "OL |[string map {{ } _} [In?]]|outer"

    set base [ContextNew Enumerated {
	LC
	set bullet "[In?]  [EBullet]"
	set ws     "[BlankM $bullet] "
	In! $ws
    }] ; # {}

    #puts_stderr "OL |[string map {{ } _} $bullet]|[string length $bullet]"
    #puts_stderr "OL |[string map {{ } _} $ws]|[string length $ws]"

    set first [ContextNew First {
	List! bullet $bullet $ws
    }] ; ContextSet $base ; # {}

    set next [ContextNew Next {
	WPrefix! $ws
	Prefix!  $ws
    }] ; ContextSet $base ; # {}

    OUL $first $next
    ContextCommit

    ContextPop
    ContextSet $base
    return
}

proc NewDefinitionList {} {
    # Definition list - terms & definitions
    # 1. Base context provides indentation.
    # 2. Term context
    # 3. Definition context
    ContextPush

    # Markdown has no native definition lists. We translate them into
    # itemized lists, rendering the term part as the first paragraph
    # of each entry, and the definition as all following.

    #puts_stderr "DL [CAttrName]"
    #puts_stderr "DL |[string map {{ } _} [In?]]|outer"

    set base [ContextNew Definitions {
	LC
	set bullet "[In?]  [IBullet]"
	set ws "[BlankM $bullet] "
	In! $ws
    }] ; # {}

    #puts_stderr "DL |[string map {{ } _} $bullet]|[string length $bullet]"
    #puts_stderr "DL |[string map {{ } _} $ws]|[string length $ws]"

    set term [ContextNew Term {
	List! bullet $bullet $ws
	VerbatimOn
    }] ; ContextSet $base ; # {}

    set def [ContextNew Def {
	WPrefix! $ws
	Prefix!  $ws
    }] ; ContextSet $base ; # {}

    TD $term $def
    ContextCommit

    ContextPop
    ContextSet $base
    return
}

##
# # ## ### ##### ########
##

c_pass 1 fmt_section {name id} { c_newSection $name 1 end $id }
c_pass 2 fmt_section {name id} {
    CloseParagraph
    Section [SetAnchor $name $id]
    return
}

c_pass 1 fmt_subsection {name id} { c_newSection $name 2 end $id }
c_pass 2 fmt_subsection {name id} {
    CloseParagraph
    Subsection [SetAnchor $name $id]
    return
}

proc fmt_sectref {title {id {}}} {
    if {$id == {}} { set id [c_sectionId $title] }
    if {[c_sectionKnown $id]} {
    	return [ALink "[Hash]$id" $title]
    } else {
	return [Strong $title]
    }
}

c_pass 1 fmt_usage {cmd args} {
    set text [join [linsert $args 0 $cmd] " "]
    c_hold synopsis "$text[LB.]"
}

c_pass 1 fmt_call  {cmd args} {
    set text [join [linsert $args 0 $cmd] " "]
    set dest "[Hash][c_cnext]"
    c_hold synopsis "[MakeLink $text $dest][LB.]"
}
c_pass 2 fmt_call {cmd args} {
    set text [join [linsert $args 0 $cmd] " "]
    return [fmt_lst_item [SetAnchor $text [c_cnext]]]
}

c_pass 1 fmt_require {pkg {version {}}} {
    set result "package require $pkg"
    if {$version != {}} {append result " $version"}
    c_hold require "$result  "
    return
}

c_pass 2 fmt_tkoption_def {name dbname dbclass} {
    set    text ""
    append text "Command-Line Switch:\t[fmt_option $name][LB]"
    append text "Database Name:\t[Strong $dbname][LB]"
    append text "Database Class:\t[Strong $dbclass]\n"
    fmt_lst_item $text
}

proc fmt_syscmd  {text} { Strong [XrefMatch $text sa] }
proc fmt_package {text} { Strong [XrefMatch $text sa kw] }
proc fmt_term    {text} { Em     [XrefMatch $text kw sa] }

proc fmt_arg     {text} { Em     $text }
proc fmt_cmd     {text} { Strong [XrefMatch $text sa] }
proc fmt_method  {text} { Strong $text }
proc fmt_option  {text} { Strong $text }

proc fmt_uri {text {label {}}} {
    if {$label == {}} { set label $text }
    ALink $text $label
}

proc fmt_image {text {label {}}} {
    # text = symbolic name of the image.

    # formatting based on the available data ...

    set img [dt_imgdst $text {png gif jpg}]
    if {$img != {}} {
	set img [LinkTo $img [LinkHere]]
	if {$label != {}} {
	    return "[Bang][OBrk][CBrk][OPar]$img \"$label\"[CPar]"
	} else {
	    return "[Bang][OBrk][CBrk][OPar]$img[CPar]"
	}
    }

    set img [dt_imgdata $text {txt}]
    if {$img != {}} {
	# Show ASCII image like an example (code block => fixed font, no reflow)
	# A label is shown as a pseudo-caption (paragraph after image).
	fmt_example $img
	if {$label != {}} {
	    Text [Strong "IMAGE: $label"]
	    CloseCurrent
	}
    }

    return $img
}

c_pass 1 fmt_manpage_begin {title section version} {c_cinit ; c_clrSections ; return}
c_pass 2 fmt_manpage_begin {title section version} {
    Off
    MDCInit
    XrefInit
    c_cinit

    set module      [dt_module]
    set shortdesc   [c_get_module]
    set description [c_get_title]
    set copyright   [c_get_copyright]
    set pagetitle   "$title - $shortdesc"

    MDComment  "$title - $shortdesc"
    MDComment  [c_provenance]
    if {$copyright != {}} {
	# Note, multiple copyright clauses => multiple lines, comments
	# are single-line => split for generation, strip MD markup for
	# linebreaks, will be re-added when committing the complete
	# comment block.
	foreach line [split $copyright \n] {
	    MDComment [string trimright $line " \t\1"]
	}
    }
    MDComment  "[string trimleft $title :]($section) $version $module \"$shortdesc\""
    MDCDone

    Text [GetT header @TITLE@ $pagetitle]
    CloseParagraph

    Section NAME
    Text "$title - $description"
    CloseParagraph
    return
}

c_pass 2 fmt_description {id} {
    On
    set syn [c_held synopsis]
    set req [c_held require]

    # Create the TOC.

    # Pass 1: We have a number of special sections which were not
    #         listed explicitly in the document sources. Add them
    #         now. Note the inverse order for the sections added
    #         at the beginning.

    c_newSection Description 1 0 $id
    if {$syn != {} || $req != {}} {c_newSection Synopsis 1 0 synopsis}
    c_newSection {Table Of Contents} 1 0 toc

    if {[llength [c_xref_seealso]]  > 0} {c_newSection {See Also} 1 end seealso}
    if {[llength [c_xref_keywords]] > 0} {c_newSection Keywords   1 end keywords}
    if {[c_xref_category]         ne ""} {c_newSection Category   1 end category}
    if {[c_get_copyright]         != {}} {c_newSection Copyright  1 end copyright}

    # Pass 2: Generate the markup for the TOC, indenting the
    #         links according to the level of each section.

    TOC

    # Implicit sections coming after the TOC (Synopsis, then the
    # description which starts the actual document). The other
    # implicit sections are added at the end of the document and are
    # generated by 'fmt_manpage_end' in the second pass.
    
    if {$syn != {} || $req != {}} {
	Section [SetAnchor SYNOPSIS synopsis]
	if {($req != {}) && ($syn != {})} {
	    Text $req\n\n$syn
	} else {
	    if {$req != {}} {Text $req}
	    if {$syn != {}} {Text $syn}
	}
	CloseParagraph [Verbatim]
    }

    Section [SetAnchor DESCRIPTION description]
    return
}

c_pass 2 fmt_manpage_end {} {
    set sa [c_xref_seealso]
    set kw [c_xref_keywords]
    set ca [c_xref_category]
    set ct [c_get_copyright]

    CloseParagraph
    if {[llength $sa]} { Special {SEE ALSO} seealso   [join [XrefList [lsort $sa] sa] ", "] }
    if {[llength $kw]} { Special KEYWORDS   keywords  [join [XrefList [lsort $kw] kw] ", "] }
    if {$ca ne ""}     { Special CATEGORY   category  $ca            }
    if {$ct != {}}     { Special COPYRIGHT  copyright $ct [Verbatim] }
    return
}

proc Breaks {lines} {
    set r {}
    foreach line $lines { lappend r $line[LB] }
    return $r
}

proc LeadSpaces {lines} {
    set r {}
    foreach line $lines { lappend r [LeadSpace $line] }
    return $r
}

proc LeadSpace {line} {
    # Split into leading and trailing whitespace, plus content
    regexp {^([ \t]*)(.*)([ \t]*)$} $line -> lead content _
    # Drop trailing spaces, make leading non-breaking, keep content (and inner spaces).
    return [RepeatM "&nbsp;" $lead]$content
}

c_pass 2 fmt_example_end {} {
    #puts_stderr "AAA/fmt_example_end"
    # Flush markup from preceding commands into the text buffer.
    TextPlain ""

    TextTrimLeadingSpace

    # Check for protected markdown markup in the input. If present
    # this is a complex example with highlighted parts.
    set complex [string match *\1* [Text?]]

    #puts_stderr "AAA/fmt_example_end/$complex"
    
    # In examples (verbatim markup) markdown's special characters are
    # no such by default, thus must not be quoted. Mark them as
    # protected from quoting. Further look for and convert
    # continuation lines protected from Tcl substitution into a
    # regular continuation line.
    set t [Text?]
    set t [string map [list \\\\\n \\\n] $t]
    if {$complex} {
	# Process for block quote
	# - make leading spaces non-breaking
	# - force linebreaks
	set t [join [Breaks [LeadSpaces [split $t \n]]] {}]
    } else {
	# Process for code block (verbatim)
	set t [Mark $t]
    }
    TextClear
    Text $t
    TextTrimTrailingSpace
    
    set penv [GetCurrent]
    if {$penv != {}} {
	# In a list we save the current list context, activate the
	# proper paragraph context and create its example
	# variant. After closing the paragraph using the example we
	# restore and reactivate the list context.
	ContextPush
	ContextSet $penv
	CloseParagraph [Example $complex]
	ContextPop
    } else {
	# In a regular paragraph we simple close the example
	CloseParagraph [Example $complex]
    }

    #puts_stderr "AAA/fmt_example_end/Done"
    return
}

proc c_get_copyright {} {
    return [join [c_get_copyright_r] [LB]]
}

##
# # ## ### ##### ########
##

proc Special {title id text {p {}}} {
    Section [SetAnchor $title $id]
    Text $text
    CloseParagraph $p
}

proc TOC {} {
    # While we could go through (fmt_list_begin itemized, item ...,
    # fmt_list_end) it looks to be easier to directly emit paragraphs
    # into the display list. No need to track anything. Just map entry
    # level directly to the proper context.
    Section [SetAnchor {Table Of Contents} toc]

    ContextPush
    lappend toc _bogus_
    lappend toc [ContextNew TOC/Section { List! bullet "  [Dash]"     "    "     }]
    lappend toc [ContextNew TOC/SubSect { List! bullet "      [Dash]" "        " }]
    ContextPop

    foreach {name id level} [c_sections] {
	# level in {1,2}, 1 = section, 2 = subsection
	Text [ALink "[Hash]$id" $name]
	CloseParagraph [lindex $toc $level]
    }

    return
}

# # ## ### ##### ########
## Engine Parameters
## - xref	cross-reference data
## - header	HTML or MD to place at the top of the document, before the title.

proc GetXref {} { Get xref } ;# xref access to engine parameters

global    __var
array set __var {
    xref   {}
    header {}
}
proc Get               {varname}      {global __var ; return $__var($varname)}
proc fmt_listvariables {}             {global __var ; return [array names __var]}
proc fmt_varset        {varname text} {
    global __var
    if {![info exists __var($varname)]} {
	return -code error "Unknown engine variable \"$varname\""
    }
    set __var($varname) $text
    return
}

# Extended `Get`, templating.
proc GetT {varname args} {
    set content [Get $varname]
    if {$content == {}} { return "" }
    if {[llength $args]} {
	set content [string map $args $content]
    }

    # The content is specified by the user. It is expected to be valid
    # markdown. That means that any special characters are only quoted
    # when they are not special. Internally this is inverted.

    return "[Mark $content]\n"
}

##
# # ## ### ##### ########
return
