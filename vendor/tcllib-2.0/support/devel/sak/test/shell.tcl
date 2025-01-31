# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

getpackage fileutil fileutil/fileutil.tcl

package require  sak::test
package require  sak::registry
namespace eval ::sak::test::shell {}

# ###

proc ::sak::test::shell {argv} {
    if {![llength $argv]} {Usage Sub command missing}

    set cmd  [lindex $argv 0]
    set argv [lrange $argv 1 end]

    switch -exact -- $cmd {
	add {
	    sak::test::shell::add $argv
	}
	delete {
	    sak::test::shell::delete $argv
	}
	default {
	    sak::test::usage Unknown command "\"shell $cmd\""
	}
    }
    return
}

proc ::sak::test::shell::list {} {
    return [sak::registry::local \
	    get||default Tests Shells {}]
}

proc ::sak::test::shell::add {paths} {
    foreach p $paths {
	if {![fileutil::test $p efrx msg "Shell"]} {
	    sak::test::usage $msg
	}
    }

    set shells [sak::registry::local \
	    get||default Tests Shells {}]
    array set known {}
    foreach sh $shells {set known($sh) .}

    set changed 0
    foreach p $paths {
	if {[info exists known($p)]} continue
	lappend shells $p
	set changed 1
    }

    if {$changed} {
	sak::registry::local \
		set Tests Shells [lsort -dict $shells]
    }
    return
}

proc ::sak::test::shell::delete {paths} {
    set shells [sak::registry::local \
	    get||default Tests Shells {}]
    array set known {}
    foreach sh $shells {set known($sh) .}

    set changed 0
    foreach p $paths {
	if {![info exists known($p)]} continue
	unset known($p)
	set changed 1
    }

    if {$changed} {
	sak::registry::local \
		set Tests Shells [lsort -dict \
		[array names known]]
    }
    return
}

# ###

namespace eval ::sak::test::shell {
}

##
# ###

package provide sak::test::shell 1.0
