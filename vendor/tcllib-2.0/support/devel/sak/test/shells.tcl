# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require  sak::test
package require  sak::test::shell
namespace eval ::sak::test::shells {}

# ###

proc ::sak::test::shells {argv} {
    if {[llength $argv]} {
	sak::test::usage Wrong # args
    }

    puts stdout [join [sak::test::shell::list] \n]
    return
}

##
# ###

package provide sak::test::shells 1.0
