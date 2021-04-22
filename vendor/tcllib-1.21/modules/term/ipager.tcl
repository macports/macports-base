# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - string -> action mappings
## (pager objects). For use with 'receive listen'.
## In essence a DFA with tree structure.

# ### ### ### ######### ######### #########
## Requirements

package require snit
package require textutil::repeat
package require textutil::tabify
package require term::ansi::send
package require term::receive::bind
package require term::ansi::code::ctrl

namespace eval ::term::receive::pager {}

# ### ### ### ######### ######### #########

snit::type ::term::interact::pager {

    option -in      -default stdin
    option -out     -default stdout
    option -column  -default 0
    option -line    -default 0
    option -height  -default 25
    option -actions -default {}

    # ### ### ### ######### ######### #########
    ##

    constructor {str args} {
	$self configurelist $args
	Save $str

	install bind using ::term::receive::bind \
	    ${selfns}::bind $options(-actions)

	$bind map [cd::cu] [mymethod Up]
	$bind map [cd::cd] [mymethod Down]
	$bind map \033\[5~ [mymethod PageUp]
	$bind map \033\[6~ [mymethod PageDown]
	$bind map \n       [mymethod Done]
	#$bind default [mymethod DEF]

	return
    }

    # ### ### ### ######### ######### #########
    ##

    method interact {} {
	Show
	$bind listen   $options(-in)
	set interacting 1
	vwait [myvar done]
	set interacting 0
	$bind unlisten $options(-in)
	return
    }

    method done  {} {set done . ; return}
    method clear {} {Clear      ; return}

    method text {str} {
	if {$interacting} {Clear}
	Save $str
	if {$interacting} {Show}
	return
    }

    # ### ### ### ######### ######### #########
    ##

    component bind

    # ### ### ### ######### ######### #########
    ##

    variable header
    variable text
    variable footer
    variable empty

    proc Save {str} {
	upvar 1 header header text text footer footer maxline maxline
	upvar 1 options(-height) height empty empty at at

	set lines [split [textutil::tabify::untabify2 $str] \n]

	set max 0
	foreach l $lines {
	    if {[set len [string length $l]] > $max} {set max $len}
	}

	set header [cd::groptim [cd::tlc][textutil::repeat::strRepeat [cd::hl] $max][cd::trc]]
	set footer [cd::groptim [cd::blc][textutil::repeat::strRepeat [cd::hl] $max][cd::brc]]

	set text {}
	foreach l $lines {
	    lappend text [cd::vl]${l}[textutil::repeat::strRepeat " " [expr {$max-[string length $l]}]][cd::vl]
	}

	set h $height
	if {$h > [llength $text]} {set h [llength $text]}

	set eline "  [textutil::repeat::strRepeat {  } $max]"
	set empty $eline
	for {set i 0} {$i <= $h} {incr i} {
	    append empty \n$eline
	}

	set maxline [expr {[llength $text] - $height}]
	if {$maxline < 0} {set maxline 0}
	set at 0
	return
    }

    variable interacting 0
    variable at   0
    variable maxline -1
    variable done .

    proc Show {} {
	upvar 1 header header text text footer footer at at
	upvar 1 options(-in)     in  options(-column) col
	upvar 1 options(-out)    out options(-line)   row
	upvar 1 options(-height) height

	set to [expr {$at + $height -1}]

	vt::wrch $out [cd::showat $row $col \
			   $header\n[join [lrange $text $at $to] \n]\n$footer]
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
	Show
	return
    }

    method Down {str} {
	if {$at >= $maxline} return
	incr at
	Show
	return
    }

    method PageUp {str} {
	set newat [expr {$at - $options(-height) + 1}]
	if {$newat < 0} {set newat 0}
	if {$newat == $at} return
	set at $newat
	Show
	return
    }

    method PageDown {str} {
	set newat [expr {$at + $options(-height) - 1}]
	if {$newat >= $maxline} {set newat $maxline}
	if {$newat == $at} return
	set at $newat
	Show
	return
    }

    method Done {str} {
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

namespace eval ::term::interact::pager {
    term::ansi::code::ctrl::import cd
    term::ansi::send::import       vt
}

package provide term::interact::pager 0.1

##
# ### ### ### ######### ######### #########
