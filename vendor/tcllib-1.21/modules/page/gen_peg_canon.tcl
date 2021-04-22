# -*- tcl -*-
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Parser Generator / Backend - PEG as ... PEG

# ### ### ### ######### ######### #########
## Dumping the input grammar. But not as Tcl or other code. In PEG
## format again, pretty printing.

# ### ### ### ######### ######### #########
## Requisites

package require textutil

namespace eval ::page::gen::peg::canon {}

# ### ### ### ######### ######### #########
## API

proc ::page::gen::peg::canon {t chan} {

    # Generate data for inherited attributes
    # used during synthesis.
    canon::Setup $t

    # Synthesize all text fragments we need.
    canon::Synth $t

    # And write the grammar text.
    puts $chan [$t get root TEXT]
    return
}

# ### ### ### ######### ######### #########
## Internal. Helpers

proc ::page::gen::peg::canon::Setup {t} {
    # Phase 1: Top-down, inherited attributes:
    #
    # - Max length of nonterminal symbols defined by the grammar.
    #
    # - Indentation put on all rules to get enough space for
    #   definition attributes.

    set       max   -1
    array set modes {}

    foreach {sym def} [$t get root definitions] {
	set l [string length $sym]
	if {$l > $max} {set max $l}

	set mode [string index [$t get $def mode] 0]
	set modes($mode) .
    }
    set modeset [join [lsort [array names modes]] ""]
    set mlen    [AttrFieldLength $modeset]
    set heading [expr {$max + $mlen + 4}]
    # The constant 4 is for ' <- ', see
    # SynthNode/Nonterminal

    # Save the computed information for access by the definitions and
    # other operators.

    $t set root SYM_FIELDLEN $max
    $t set root ATT_FIELDLEN $mlen
    $t set root ATT_BASE     $modeset
    $t set root HEADLEN      $heading
    return
}

proc ::page::gen::peg::canon::Synth {t} {
    # Phase 2: Bottom-up, synthesized attributes
    #
    # - Text block per node, length and height.

    $t walk root -order post -type dfs n {
	SynthNode $t $n
    }
    return
}

proc ::page::gen::peg::canon::SynthNode {t n} {
    if {$n eq "root"} {
	set code Root
    } elseif {[$t keyexists $n symbol]} {
	set code Nonterminal
    } elseif {[$t keyexists $n op]} {
	set code [$t get $n op]
    } else {
	return -code error "PANIC. Bad node $n, cannot classify"
    }

    #puts stderr "SynthNode/$code $t $n"

    SynthNode/$code $t $n

    #SHOW [$t get $n TEXT] 1 0
    #catch {puts stderr "\t.[$t get $n W]x[$t get $n H]"}
    return
}

proc ::page::gen::peg::canon::SynthNode/Root {t n} {
    # Root is the grammar itself.

    # Get the data we need from our children, which are start
    # expression and nonterminal definitions.

    set gname  [$t get root name]
    set gstart [$t get root start]
    if {$gstart ne ""} {
	set stext  [$t get $gstart TEXT]
    } else {
	puts stderr "No start expression."
	set stext ""
    }
    set rules  {}
    foreach {sym def} [$t get root definitions] {
	lappend rules [list $sym [$t get $def TEXT]]
    }

    # Combine them into a text for the whole grammar.

    set intro  "PEG $gname \("
    set ispace [::textutil::blank [string length $intro]]

    set    out ""
    append out "# -*- text -*-" \n
    append out "## Parsing Expression Grammar '$gname'." \n
    append out "## Layouted by the PG backend 'PEGwriter'." \n
    append out \n
    append out $intro[::textutil::indent $stext $ispace 1]\)
    append out \n
    append out \n

    foreach e [lsort -dict -index 0 $rules] {
	foreach {sym text} $e break
	append out $text \n
	append out \n
    }

    append out "END\;" \n

    $t set root TEXT $out
    return
}

proc ::page::gen::peg::canon::SynthNode/Nonterminal {t n} {
    # This is the root of a definition. We now
    # have to combine the text block for the
    # expression with nonterminal and attribute
    # data.

    variable ms

    set abase [$t get root ATT_BASE]
    set sfl   [$t get root SYM_FIELDLEN]
    set mode  [$t get $n mode]
    set sym   [$t get $n symbol]
    set etext [$t get [lindex [$t children $n] 0] TEXT]

    set    out ""
    append out $ms($abase,$mode)
    append out $sym
    append out [::textutil::blank [expr {$sfl - [string length $sym]}]]
    append out " <- "

    set ispace [::textutil::blank [string length $out]]

    append out [::textutil::indent $etext $ispace 1]
    append out " ;"

    $t set $n TEXT $out
    return
}

proc ::page::gen::peg::canon::SynthNode/t {t n} {
    # Terminal node. Primitive layout.
    # Put the char into single or double quotes.

    set ch [$t get $n char]
    if {$ch eq "'"} {set q "\""} else {set q '}

    set text $q$ch$q

    SetBlock $t $n $text
    return
}

proc ::page::gen::peg::canon::SynthNode/n {t n} {
    # Nonterminal node. Primitive layout. Text is the name of smybol
    # itself.

    SetBlock $t $n [$t get $n sym]
    return
}

proc ::page::gen::peg::canon::SynthNode/.. {t n} {
    # Range is [x-y]
    set b [$t get $n begin]
    set e [$t get $n end]
    SetBlock $t $n "\[${b}-${e}\]"
    return
}

proc ::page::gen::peg::canon::SynthNode/alnum   {t n} {SetBlock $t $n <alnum>}
proc ::page::gen::peg::canon::SynthNode/alpha   {t n} {SetBlock $t $n <alpha>}
proc ::page::gen::peg::canon::SynthNode/dot     {t n} {SetBlock $t $n .}
proc ::page::gen::peg::canon::SynthNode/epsilon {t n} {SetBlock $t $n ""}

proc ::page::gen::peg::canon::SynthNode/? {t n} {SynthSuffix $t $n ?}
proc ::page::gen::peg::canon::SynthNode/* {t n} {SynthSuffix $t $n *}
proc ::page::gen::peg::canon::SynthNode/+ {t n} {SynthSuffix $t $n +}

proc ::page::gen::peg::canon::SynthNode/! {t n} {SynthPrefix $t $n !}
proc ::page::gen::peg::canon::SynthNode/& {t n} {SynthPrefix $t $n &}

proc ::page::gen::peg::canon::SynthSuffix {t n op} {

    set sub   [lindex [$t children $n] 0]
    set sop   [$t get $sub op]
    set etext [$t get $sub TEXT]

    WrapParens $op $sop etext
    SetBlock $t $n $etext$op
    return
}

proc ::page::gen::peg::canon::SynthPrefix {t n op} {

    set sub   [lindex [$t children $n] 0]
    set sop   [$t get $sub op]
    set etext [$t get $sub TEXT]

    WrapParens $op $sop etext
    SetBlock $t $n $op$etext
    return
}

proc ::page::gen::peg::canon::SynthNode/x {t n} {
    variable llen

    # Space given to us for an expression.
    set lend [expr {$llen - [$t get root HEADLEN]}]

    set clist [$t children $n]
    if {[llength $clist] == 1} {
	# Implicit cutting out of chains.

	CopyBlock $t $n [lindex $clist 0]

	#puts stderr <<implicit>>
	return
    }

    set out ""

    # We are not tracking the total width of the block, but only the
    # width of the current line, as that is where we may have to
    # wrap. The height however is the total height.

    #puts stderr <<$clist>>
    #puts stderr \t___________________________________

    set w 0
    set h 0
    foreach c $clist {
	set sop   [$t get $c op]
	set sub   [$t get $c TEXT]
	set sw    [$t get $c W]
	set slw   [$t get $c Wlast]
	set sh    [$t get $c H]

	#puts stderr \t<$sop/$sw/$slw/$sh>___________________________________
	#SHOW $sub $slw $sh

	if {[Paren x $sop]} {
	    set sub "([::textutil::indent $sub " " 1])"
	    incr slw 2
	    incr sw  2

	    #puts stderr /paren/
	    #SHOW $sub $slw $sh
	}

	# Empty buffer ... Put element, and extend dimensions

	#puts stderr \t.=============================
	#SHOW $out $w $h

	if {$w == 0} {
	    #puts stderr /init
	    append out $sub
	    set w $slw
	    set h $sh
	} elseif {($w + $sw + 1) > $lend} {
	    #puts stderr /wrap/[expr {($w + $sw + 1)}]/$lend
	    # To large, wrap into next line.
	    append out \n $sub
	    incr h $sh
	    set  w $slw
	} else {
	    # We have still space to put the block in. Either by
	    # simply appending, or by indenting a multiline block
	    # properly so that its parts stay aligned with each other.
	    if {$sh == 1} {
		#puts stderr /add/line
		append out " " $sub
		incr w ; incr w $slw
	    } else {
		append out " "  ; incr w
		#puts stderr /add/block/$w
		append out [::textutil::indent $sub [::textutil::blank $w] 1]
		incr w $slw
		incr h $sh ; incr h -1
	    }
	}

	#puts stderr \t.~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	#SHOW $out $w $h
    }

    SetBlock $t $n $out
    return
}

proc ::page::gen::peg::canon::SynthNode// {t n} {
    # We take all branches and put them together, nicely aligned under
    # each other.

    set clist [$t children $n]
    if {[llength $clist] == 1} {
	# Implicit cutting out of chains.

	CopyBlock $t $n [lindex $clist 0]
	return
    }

    set out ""
    foreach c $clist {
	set sop   [$t get $c op]
	set sub   [$t get $c TEXT]
	WrapParens / $sop sub
	append out "/ [::textutil::indent $sub "  " 1]" \n
    }

    SetBlock $t $n " [string range $out 1 end]"
    return
}

proc ::page::gen::peg::canon::WrapParens {op sop tvar} {
    if {[Paren $op $sop]} {
	upvar 1 $tvar text
	set text "([::textutil::indent $text " " 1])"
    }
}

proc ::page::gen::peg::canon::Paren {op sop} {
    # sop is nested under op.
    # Parens are required if sop has a lower priority than op.

    return [expr {[Priority $sop] < [Priority $op]}]
}

proc ::page::gen::peg::canon::Priority {op} {
    switch -exact -- $op {
	t        -
	n        -
	..       -
	alnum    -
	alpha    -
	dot      -
	epsilon  {return 4}
	? -
	* -
	+        {return 3}
	! -
	&        {return 2}
	x        {return 1}
	/        {return 0}
    }
    return -code error "Internal error, bad operator \"$op\""
}

proc ::page::gen::peg::canon::CopyBlock {t n src} {
    $t set $n TEXT  [$t get $src TEXT]
    $t set $n W     [$t get $src W]
    $t set $n Wlast [$t get $src Wlast]
    $t set $n H     [$t get $src H]
    return
}

proc ::page::gen::peg::canon::SetBlock {t n text} {
    set text   [string trimright $text]
    set lines  [split $text \n]
    set height [llength $lines]

    if {$height > 1} {
	set max -1
	set ntext {}

	foreach line $lines {
	    set line [string trimright $line]
	    set l [string length $line]
	    if {$l > $max} {set max $l}
	    lappend ntext $line
	    set wlast $l
	}
	set text  [join $ntext \n]
	set width $max
    } else {
	set width [string length $text]
	set wlast $width
    }

    $t set $n TEXT $text
    $t set $n W     $width
    $t set $n Wlast $wlast
    $t set $n H     $height
    return
}

proc ::page::gen::peg::canon::AttrFieldLength {modeset} {
    variable ms
    return  $ms($modeset,*)
}

if {0} {
    proc ::page::gen::peg::canon::SHOW {text w h} {
	set wl $w ; incr wl -1
	puts stderr "\t/$h"
	puts stderr "[textutil::indent $text \t|]"
	puts stderr "\t\\[string repeat "-" $wl]^ ($w)"
	return
    }
}

# ### ### ### ######### ######### #########
## Internal. Strings.

namespace eval ::page::gen::peg::canon {
    variable llen 80
    variable ms ; array set ms {
	dlmv,discard {void:  }
	dlmv,leaf    {leaf:  }
	dlmv,match   {match: }
	dlmv,value   {       }
	dlmv,*       7

	dlm,discard  {void:  }		dlv,discard  {void: }
	dlm,leaf     {leaf:  }		dlv,leaf     {leaf: }
	dlm,match    {match: }		dlv,value    {      }
	dlm,*        7			dlv,*        6

	dmv,discard  {void:  }		lmv,leaf     {leaf:  }
	dmv,match    {match: }		lmv,match    {match: }
	dmv,value    {       }		lmv,value    {       }
	dmv,*        7			lmv,*        7

	dl,discard   {void: }		dm,discard   {void:  }
	dl,leaf      {leaf: }		dm,match     {match: }
	dl,*         6			dm,*         7

	lm,leaf      {leaf:  }		dv,discard   {void: }
	lm,match     {match: }		dv,value     {      }
	lm,*         7			dv,*         6

	lv,leaf      {leaf: }		mv,match     {match: }
	lv,value     {      }		mv,value     {       }
	lv,*         6			mv,*         7

	d,discard    {void: }		d,*       6
	l,leaf       {leaf: }		l,*       6
	m,match      {match: }		m,*       7
	v,value      {}			v,*       0
    }
}

# ### ### ### ######### ######### #########
## Ready

package provide page::gen::peg::canon 0.1
