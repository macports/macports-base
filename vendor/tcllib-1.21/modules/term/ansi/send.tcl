# -*- tcl -*-
# ### ### ### ######### ######### #########
## Terminal packages - ANSI - Control codes

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4
package require term::send
package require term::ansi::code::ctrl

namespace eval ::term::ansi::send {}

# ### ### ### ######### ######### #########
## Make command easily available

proc ::term::ansi::send::import {{ns send} args} {
    if {![llength $args]} {set args *}
    set args ::term::ansi::send::[join $args " ::term::ansi::send::"]
    uplevel 1 [list namespace eval ${ns} [linsert $args 0 namespace import]]
    return
}

# ### ### ### ######### ######### #########
## Internal - Setup.

proc ::term::ansi::send::ChName {n} {
    if {![string match *-* $n]} {
	return ${n}ch
    }
    set nl   [split $n -]
    set stem [lindex       $nl 0]
    set sfx  [join [lrange $nl 1 end] -]
    return ${stem}ch-$sfx
}

proc ::term::ansi::send::Args {n -> arv achv avv} {
    upvar 1 $arv a $achv ach $avv av
    set code ::term::ansi::code::ctrl::$n
    set a   [info args $code]
    set av  [expr {
	[llength $a]
	? " \$[join $a { $}]"
	: $a
    }]
    foreach a1 $a[set a {}] {
        if {[info default $code $a1 default]} {
            lappend a [list $a1 $default]
        } else {
            lappend a $a1
        }
    }
    set ach [linsert $a 0 ch]
    return $code
}

proc ::term::ansi::send::INIT {} {
    foreach n [::term::ansi::code::ctrl::names] {
	set nch  [ChName $n]
	set code [Args $n -> a ach av]

	if {[lindex $a end] eq "args"} {
	    # An args argument requires more care, and an eval
	    set av [lrange $av 0 end-1]
	    if {$av ne {}} {set av " $av"}
	    set gen "eval \[linsert \$args 0 $code$av\]"
	    #8.5: (written for clarity): set gen "$code$av {*}\$args"
	} else {
	    set gen $code$av
	}

	proc $n   $a   "wr        \[$gen\]" ; namespace export $n
	proc $nch $ach "wrch \$ch \[$gen\]" ; namespace export $nch
    }
    return
}

namespace eval ::term::ansi::send {
    namespace import ::term::send::wr
    namespace import ::term::send::wrch
    namespace export wr wrch
}

::term::ansi::send::INIT

# ### ### ### ######### ######### #########
## Ready

package provide term::ansi::send 0.2

##
# ### ### ### ######### ######### #########
