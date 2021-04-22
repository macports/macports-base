# -*- tcl -*-
#
# Copyright (c) 2019 Andreas Kupries <andreas_kupries@sourceforge.net>
# Freely redistributable.
#
# _text_dlist.tcl -- Display list variables and accessors

#
# The engine maintains several data structures per document and pass.
# Most important is an internal representation of the text better
# suited to perform the final layouting, the display list. Elements of
# the display list are lists containing 2 elements, an operation, and
# its arguments, in this order. The arguments are a list again, its
# contents are specific to the operation.
#
# The operations are:
#
# - SECT	Section.    Title.
# - SUBSECT     Subsection. Title.
# - PARA	Paragraph.  Context reference and text.
#
# The PARA operation is the workhorse of the engine, dooing all the
# formatting, using the information in an "context" as the guide
# for doing so. The contexts themselves are generated during the
# second pass through the contents. They contain the information about
# nesting (i.e. indentation), bulleting and the like.
#

# # ## ### ##### ########
## State: Display list

global __dlist

# # ## ### ##### ########
## Internal: Extend

proc Store {op args} { global __dlist ; lappend __dlist [list $op $args] ; return}

# Debugging ...
#proc Store {op args} {puts_stderr "STO $op $args"; global __dlist; lappend __dlist [list $op $args]; return}

# # ## ### ##### ########
## API
#
# API Section		Add section
# API Subsection	Add subsection
# API CloseParagraph	Add paragraph using text and (current) env
#                       Boolean result indicates if something was added, or not

proc DListClear {} { global __dlist ; unset -nocomplain __dlist ; set __dlist {} }

proc Section    {name} {Store SECT    $name ; return}
proc Subsection {name} {Store SUBSECT $name ; return}

proc CloseParagraph {{id {}}} {
    set para [Text?]
    if {$para == {}} { return 0 }
    if {$id == {}} { set id [CAttrCurrent] }
    if {![ContextExists $id]} {
	error "Unknown context $id for paragraph"
    }
    Store PARA $id $para
    #puts_stderr "CloseParagraph $id [CAttrName $id]"
    #puts_stderr "  (($para))"
    TextClear
    return 1
} 

proc PostProcess {text} {
    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    #puts_stderr <<$text>>
    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    global __dlist
    # The argument is not relevant. Access the display list, perform
    # the final layouting and return its result.

    set lines {}
    array set state {lmargin 0 rmargin 0}
    foreach cmd $__dlist {
	lappend lines ""
	foreach {op arguments} $cmd break
	$op $arguments
    }

    #puts_stderr XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    return [Compose lines]\n
}

# # ## ### ##### ########
## PARA attributes
#
# Attributes
# - bullet      = bullet (template) to use for (un)ordered lists.
# - counter     = if present, item counter for enumeration list.
# - listtype    = type of list, if any.
# - lmargin     = left-indent, location of left margin for text.
# - prefix      = prefix to use for all lines of the parapgraph.
# - wspfx       = whitespace prefix for all but the first line of the paragraph.

proc BulletReset  {} { CAttrSet bullet {} }
proc ListNone     {} { CAttrSet listtype {} }
proc MarginIn     {} { CAttrIncr lmargin [LMI] }
proc MarginReset  {} { CAttrSet lmargin 0 }
proc PrefixReset  {} { CAttrSet prefix {} }
proc WPrefixReset {} { CAttrSet wspfx {} }

proc Prefix!   {p} { CAttrSet prefix $p }
proc Prefix+   {p} { CAttrAppend prefix $p }
proc WPrefix!  {p} { CAttrSet wspfx  $p }

proc Bullet?   {} { CAttrGet bullet }
proc ListType? {} { CAttrGet listtype }
proc Margin?   {} { CAttrGet lmargin }
proc Prefix?   {} { CAttrGet prefix }
proc WPrefix?  {} { CAttrGet wspfx }

proc List! {type bullet wprefix} {

    #puts_stderr L!(($type))
    #puts_stderr L!(($bullet))[string length $bullet],[string length [DeIce $bullet]]
    #puts_stderr L!(([Dots $wprefix]))
    
    CAttrSet listtype $type
    CAttrSet bullet   $bullet
    CAttrSet wspfx    $wprefix
}

proc EnumCounter {} {
    if {![CAttrHas counter]} {
	CAttrSet counter 1
    } else {
	CAttrIncr counter
    }
    ContextCommit	
    #puts_stderr "Counter ... [CAttrName] => [CAttrGet counter]"
    return [CAttrGet counter]
}

proc EnumId {} {
    # Handling the enumeration counter.
    #
    # Special case: An example as first paragraph in an item has to
    # use the counter in the context it is derived from to prevent
    # miscounting.

    #puts_stderr "EnumId: [CAttrName] | [CAttrName [Parent?]]"
    
    if {[Example?]} {
	ContextPush
	ContextSet [Parent?]
	set n [EnumCounter]
	ContextPop
    } else {
	set n [EnumCounter]
    }
    return $n
}

# # ## ### ##### ########
## Hooks

proc SECT {text} {
    #puts_stderr "SECT $text"
    #puts_stderr ""
    # text is actually the list of arguments, having one element, the text.
    upvar 1 lines lines
    set text [lindex $text 0]
    SectTitle lines $text
    return
}

proc SUBSECT {text} {
    #puts_stderr "SUBSECT $text"
    #puts_stderr ""
    # text is actually the list of arguments, having one element, the text.
    upvar 1 lines lines
    set text [lindex $text 0]
    SubsectTitle lines $text
    return
}

proc PARA {arguments} {
    upvar lines lines

    # Note. As the display list is processed at the very end we can
    # reuse the current context and accessors to hold and query the
    # context of each paragraph.
    
    foreach {env text} $arguments break
    ContextSet $env

    #puts_stderr "PARA $env [CAttrName $env]"
    #parray_stderr ::currentContext ;# consider capsulation
    #puts_stderr "    (($text))"
    #puts_stderr ""

    # Use the information in the referenced context to format the
    # paragraph.

    set lm    [Margin?]
    set lt    [ListType?]
    set blank [WPrefix?]
    
    if {[Verbatim?]} {
	set text [Undent $text]
	#puts_stderr "UN  (($text))"
    } else {
	set  plm $lm
	incr plm [string length $blank]
	set text [Reflow $text [RMargin $plm]]
    }

    # Now apply prefixes, (ws prefixes bulleting), at last indentation.

    set p [Prefix?]
    if {[string length $p]} {
	set text [Indent $text $p]
	#puts_stderr "IN  (($text))"
    }

    if {$lt != {}} {
	switch -exact $lt {
	    bullet {
		# Indent for bullet, but not the first line. This is
		# prefixed by the bullet itself.
		set thebullet [Bullet?]
	    }
	    enum {
		#puts_stderr EB

		set n [EnumId]
		set thebullet [string map [list % $n] [Bullet?]]

		#puts_stderr "E $n | $thebullet |"
	    }
	}

	set blank [WPrefix?]

	#puts_stderr B.(($lt))
	#puts_stderr B.(($thebullet))[string length $thebullet],[string length [DeIce $thebullet]]
	#puts_stderr B.(([Dots $blank]))

	if {[string length [DeIce $thebullet]] >= [string length $blank]} {
	    # The item's bullet is longer than the space for indenting.
	    # Put bullet and text on separate lines, indent text in full.

	    #puts_stderr B.DROP

	    set text "$thebullet\n[Indent $text $blank]"
	} else {
	    # The item's bullet fits into the space for
	    # indenting. Make hanging indent of text and place the
	    # bullet in front of the first line, with suitable partial
	    # spacing.

	    #puts_stderr B.SAME
	    #puts_stderr B.(([Dots [ReHead $blank $thebullet]]))

	    set text [Indent1 $text [ReHead $blank $thebullet] $blank]
	}
    }

    if {$lm} {
	#puts_stderr "LMA $lm"
	set text [Indent $text [Blank $lm]]
    }

    #puts_stderr "FIN (($text))"
    
    lappend lines $text
    return
}

# # ## ### ##### ########
return
