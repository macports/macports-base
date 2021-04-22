# -*- tcl -*-
# (C) 2008 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::color {}

# ###

if {$::tcl_platform(platform) == "windows"} {
    # No ansi colorization on windows
    namespace eval ::sak::color {
	variable n
	foreach n {cya yel whi mag red green rst} {
	    proc $n {} {return ""}
	    namespace export $n

	    proc =$n {s} {return $s}
	    namespace export =$n
	}
	unset n
    }
} else {
    getpackage term::ansi::code::attr term/ansi/code/attr.tcl
    getpackage term::ansi::code::ctrl term/ansi/code/ctrl.tcl

    ::term::ansi::code::ctrl::import ::sak::color sda_bg* sda_reset

    namespace eval ::sak::color {
	variable s
	variable n
	foreach {s n} {
	    sda_bgcyan    cya
	    sda_bgyellow  yel
	    sda_bgwhite   whi
	    sda_bgmagenta mag
	    sda_bgred     red
	    sda_bggreen   green
	    sda_reset     rst
	} {
	    rename $s $n
	    namespace export $n

	    proc =$n {s} "return \[$n\]\$s\[rst\]"
	    namespace export =$n
	}
	unset s n
    }
}

##
# ###

package provide sak::color 1.0
