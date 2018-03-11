# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

namespace eval ::sak::util {}

# ###

proc ::sak::util::path2modules {paths} {
    set modules {}
    foreach p $paths {
	if {[file exists $p]} {set p [file tail $p]}
	lappend modules $p
    }
    return $modules
}

proc ::sak::util::modules2path {modules} {
    global distribution
    set modbase [file join $distribution modules]

    set paths {}
    foreach m $modules {
	lappend paths [file join $modbase $m]
    }
    return $paths
}

proc ::sak::util::module2path {module} {
    global distribution
    set modbase [file join $distribution modules]
    return [file join $modbase $module]
}

proc ::sak::util::checkModules {modvar} {
    upvar 1 $modvar modules

    if {![llength $modules]} {
	# Default to all if none are specified. This information does
	# not require validation.

	set modules [modules]
	return 1
    }

    set modules [path2modules $modules]

    set fail 0
    foreach m $modules {
	if {[modules_mod $m]} {
	    lappend results $m
	    continue
	}

	puts "  Unknown module: $m"
	set fail 1
    }

    if {$fail} {
	puts "  Stop."
	return 0
    }

    set modules $results
    return 1
}

##
# ###

package provide sak::util 1.0
