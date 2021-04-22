# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - string -> action mappings
## (menu objects). For use with 'receive listen'.
## In essence a DFA with tree structure.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require textutil::repeat
package require textutil::tabify
package require term::ansi::send
package require term::receive::bind
package require term::ansi::code::ctrl

namespace eval ::term::receive::menu {}

# ### ### ### ######### ######### #########

snit::type ::term::interact::menu {

    option -in          -default stdin
    option -out         -default stdout
    option -column      -default 0
    option -line        -default 0
    option -height      -default 25
    option -actions     -default {}
    option -hilitleft   -default 0
    option -hilitright  -default end
    option -framed      -default 0 -readonly 1

    # ### ### ### ######### ######### #########
    ##

    constructor {dict args} {
	$self configurelist $args
	Save $dict

	install bind using ::term::receive::bind \
	    ${selfns}::bind $options(-actions)

	$bind map [cd::cu] [mymethod Up]
	$bind map [cd::cd] [mymethod Down]
	$bind map \n       [mymethod Select]
	#$bind default [mymethod DEF]

	return
    }

    # ### ### ### ######### ######### #########
    ##

    method interact {} {
	Show
	$bind listen   $options(-in)
	vwait [myvar done]
	$bind unlisten $options(-in)
	return $map($done)
    }

    method done  {} {set done $at ; return}
    method clear {} {Clear        ; return}

    # ### ### ### ######### ######### #########
    ##

    component bind

    # ### ### ### ######### ######### #########
    ##

    variable map -array {}
    variable header
    variable labels
    variable footer
    variable empty

    proc Save {dict} {
	upvar 1 header header labels labels footer footer
	upvar 1 empty empty at at map map top top
	upvar 1 options(-height) height

	set max 0
	foreach {l code} $dict {
	    if {[set len [string length $l]] > $max} {set max $len}
	}

	set header [cd::groptim [cd::tlc][textutil::repeat::strRepeat [cd::hl] $max][cd::trc]]
	set footer [cd::groptim [cd::blc][textutil::repeat::strRepeat [cd::hl] $max][cd::brc]]

	set labels {}
	set at 0
	foreach {l code} $dict {
	    set map($at) $code
	    lappend labels ${l}[textutil::repeat::strRepeat " " [expr {$max-[string length $l]}]]
	    incr at
	}

	set h $height
	if {$h > [llength $labels]} {set h [llength $labels]}

	set eline "  [textutil::repeat::strRepeat {  } $max]"
	set empty $eline
	for {set i 0} {$i <= $h} {incr i} {
	    append empty \n$eline
	}

	set at  0
	set top 0
	return
    }

    variable top  0
    variable at   0
    variable done .

    proc Show {} {
	upvar 1 header header labels labels footer footer at at
	upvar 1 options(-in)     in  options(-column) col top top
	upvar 1 options(-out)    out options(-line)   row
	upvar 1 options(-height) height options(-framed) framed
	upvar 1 options(-hilitleft)  left
	upvar 1 options(-hilitright) right

	set bot [expr {$top + $height - 1}]
	set fr  [expr {$framed ? [cd::vl] : { }}]

	set text $header\n
	set i $top
	foreach l [lrange $labels $top $bot] {
	    append text $fr
	    if {$i != $at} {
		append text $l
	    } else {
		append text [string replace $l $left $right \
			[cd::sda_revers][string range $l $left $right][cd::sda_reset]]
	    }
	    append text $fr \n
	    incr i
	}
	append text $footer

	vt::wrch $out [cd::showat $row $col $text]
	return
    }

    proc Clear {} {
	upvar 1 empty         empty options(-column) col
	upvar 1 options(-out) out   options(-line)   row

	vt::wrch $out [cd::showat $row $col $empty]
	return
    }

    # ### ### ### ######### ######### #########
    ##

    method Up {str} {
	if {$at == 0} return
	incr at -1
	if {$at < $top} {incr top -1}
	Show
	return
    }

    method Down {str} {
	upvar 0 options(-height) height
	if {$at == ([llength $labels]-1)} return
	incr at
	set bot [expr {$top + $height - 1}]
	if {$at > $bot} {incr top}
	Show
	return
    }

    method Select {str} {
	$self done
	return
    }

    method DEF {str} {
	puts stderr "($str)"
	exit
    }

    ##
    # ### ### ### ######### ######### #########
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::term::interact::menu {
    term::ansi::code::ctrl::import cd
    term::ansi::send::import       vt
}

package provide term::interact::menu 0.1

##
# ### ### ### ######### ######### #########
