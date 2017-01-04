# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI - Higher level macros

# ### ### ### ######### ######### #########
## Requirements

package require textutil::repeat
package require textutil::tabify
package require term::ansi::code::ctrl

namespace eval ::term::ansi::code::macros {}

# ### ### ### ######### ######### #########
## API. Symbolic names.

proc ::term::ansi::code::macros::import {{ns macros} args} {
    if {![llength $args]} {set args *}
    set args ::term::ansi::code::macros::[join $args " ::term::ansi::code::macros::"]
    uplevel 1 [list namespace eval ${ns} [linsert $args 0 namespace import]]
    return
}

# ### ### ### ######### ######### #########
## Higher level operations

# Format a menu / framed block of text

proc ::term::ansi::code::macros::menu {menu} {
    # Menu = dict (label => char)
    array set _ {}
    set shift 0
    foreach {label c} $menu {
	if {[string first $c $label] < 0} {
	    set shift 1
	    break
	}
    }
    set max 0
    foreach {label c} $menu {
	set pos [string first $c $label]
	if {$shift || ($pos < 0)} {
	    set xlabel "$c $label"
	    set pos 0
	} else {
	    set xlabel $label
	}
	set len [string length $xlabel]
	if {$len > $max} {set max $len}
	set _($label) " [string replace $xlabel $pos $pos \
		[cd::sda_fgred][cd::sda_bold][string index $xlabel $pos][cd::sda_reset]]"
    }

    append ms [cd::tlc][textutil::repeat::strRepeat [cd::hl] $max][cd::trc]\n
    foreach {l c} $menu {append ms $_($l)\n}
    append ms [cd::blc][textutil::repeat::strRepeat [cd::hl] $max][cd::brc]

    return [cd::groptim $ms]
}

proc ::term::ansi::code::macros::frame {string} {
    set lines [split [textutil::tabify::untabify2 $string] \n]
    set max 0
    foreach l $lines {
	if {[set len [string length $l]] > $max} {set max $len}
    }
    append fs [cd::tlc][textutil::repeat::strRepeat [cd::hl] $max][cd::trc]\n
    foreach l $lines {
	append fs [cd::vl]${l}[textutil::repeat::strRepeat " " [expr {$max-[string length $l]}]][cd::vl]\n
    }
    append fs [cd::blc][textutil::repeat::strRepeat [cd::hl] $max][cd::brc]
    return [cd::groptim $fs]
}

##
# ### ### ### ######### ######### #########

# ### ### ### ######### ######### #########
## Data structures.

namespace eval ::term::ansi::code::macros {
    term::ansi::code::ctrl::import cd

    namespace export menu frame
}

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::code::macros 0.1

##
# ### ### ### ######### ######### #########
