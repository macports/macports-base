#-----------------------------------------------------------------------------
# tclx.tcl -- Extended Tcl initialization.
#-----------------------------------------------------------------------------
# $Id: tclx.tcl,v 1.6 2005/11/21 18:37:58 hobbs Exp $
#-----------------------------------------------------------------------------

namespace eval ::tclx {
    global auto_path auto_index tclx_library
    if {[info exists tclx_library] && [string length $tclx_library]} {
	set auto_index(buildpackageindex) \
		{source [file join $tclx_library buildidx.tcl]}
	if {![info exists auto_path] ||
	    [lsearch -exact $auto_path $tclx_library] == -1} {
	    lappend auto_path $tclx_library
	}
    }

    variable file ""
    variable dir  ""
    variable libfiles
    array set libfiles {
	arrayprocs.tcl	1
	autoload.tcl	0
	buildhelp.tcl	0
	buildidx.tcl	0
	compat.tcl	1
	convlib.tcl	1
	edprocs.tcl	1
	events.tcl	1
	fmath.tcl	1
	forfile.tcl	1
	globrecur.tcl	1
	help.tcl	1
	profrep.tcl	1
	pushd.tcl	1
	setfuncs.tcl	1
	showproc.tcl	1
	stringfile.tcl	1
	tcllib.tcl	0
	tclx.tcl	0
    }
    set dir [file dirname [info script]]
    foreach file [array names libfiles] {
	if {$libfiles($file)} {
	    uplevel \#0 [list source [file join $dir $file]]
	}
    }

    if 0 {
	# A pure Tcl equivalent to TclX's readdir, except that it includes
	# . and .., which should be removed
	proc ::readdir {args} {
	    set len [llength $args]
	    set ptn [list *]
	    if {![string equal $::tcl_platform(platform) "windows"]} {
		lappend ptn .*
	    }
	    if {$len == 1} {
		set dir [lindex $args 0]
	    } elseif {$len == 2} {
		if {![string equal [lindex $args 0] "-hidden"]} {
		    return -code error \
			"expected option of \"-hidden\", got \"[lindex $args 0]\""
		}
		if {[string equal $::tcl_platform(platform) "windows"]} {
		    lappend ptn .*
		}
		set dir [lindex $args 1]
	    } else {
		set cmd [lindex [info level 0] 0]
		return -code error \
		    "wrong \# args: $cmd ?-hidden? dirPath"
	    }
	    return [eval [list glob -tails -nocomplain -directory $dir] $ptn]
	}
    }

}; # end namespace tclx
