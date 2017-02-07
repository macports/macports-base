# bench.tcl --
#
#	Management of benchmarks.
#
# Copyright (c) 2005-2008 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# library derived from runbench.tcl application (C) Jeff Hobbs.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: bench.tcl,v 1.14 2008/10/08 03:30:48 andreas_kupries Exp $

# ### ### ### ######### ######### ######### ###########################
## Requisites - Packages and namespace for the commands and data.

package require Tcl 8.2
package require logger
package require csv
package require struct::matrix
package require report

namespace eval ::bench      {}
namespace eval ::bench::out {}

# @mdgen OWNER: libbench.tcl

# ### ### ### ######### ######### ######### ###########################
## Public API - Benchmark execution

# ::bench::run --
#
#	Run a series of benchmarks.
#
# Arguments:
#	...
#
# Results:
#	Dictionary.

proc ::bench::run {args} {
    log::debug [linsert $args 0 ::bench::run]

    # -errors  0|1         default 1, propagate errors in benchmarks
    # -threads <num>       default 0, no threads, #threads to use
    # -match  <pattern>    only run tests matching this pattern
    # -rmatch <pattern>    only run tests matching this pattern
    # -iters  <num>        default 1000, max#iterations for any benchmark
    # -pkgdir <dir>        Defaults to nothing, regular bench invokation.

    # interps - dict (path -> version)
    # files   - list (of files)

    # Process arguments ......................................
    # Defaults first, then overides by the user

    set errors  1    ; # Propagate errors
    set threads 0    ; # Do not use threads
    set match   {}   ; # Do not exclude benchmarks based on glob pattern
    set rmatch  {}   ; # Do not exclude benchmarks based on regex pattern
    set iters   1000 ; # Limit #iterations for any benchmark
    set pkgdirs {}   ; # List of dirs to put in front of auto_path in the
                       # bench interpreters. Default: nothing.

    while {[string match "-*" [set opt [lindex $args 0]]]} {
	set val [lindex $args 1]
	switch -exact -- $opt {
	    -errors {
		if {![string is boolean -strict $val]} {
		    return -code error "Expected boolean, got \"$val\""
		}
		set errors $val
	    }
	    -threads {
		if {![string is int -strict $val] || ($val < 0)} {
		    return -code error "Expected int >= 0, got \"$val\""
		}
		set threads [lindex $args 1]
	    }
	    -match {
		set match [lindex $args 1]
	    }
	    -rmatch {
		set rmatch [lindex $args 1]
	    }
	    -iters {
		if {![string is int -strict $val] || ($val <= 0)} {
		    return -code error "Expected int > 0, got \"$val\""
		}
		set iters   [lindex $args 1]
	    }
	    -pkgdir {
		CheckPkgDirArg  $val
		lappend pkgdirs $val
	    }
	    default {
		return -code error "Unknown option \"$opt\", should -errors, -threads, -match, -rmatch, or -iters"
	    }
	}
	set args [lrange $args 2 end]
    }
    if {[llength $args] != 2} {
	return -code error "wrong\#args, should be: ?options? interp files"
    }
    foreach {interps files} $args break

    # Run the benchmarks .....................................

    array set DATA {}

    if {![llength $pkgdirs]} {
	# No user specified package directories => Simple run.
	foreach {ip ver} $interps {
	    Invoke $ip $ver {} ;# DATA etc passed via upvar.
	}
    } else {
	# User specified package directories.
	foreach {ip ver} $interps {
	    foreach pkgdir $pkgdirs {
		Invoke $ip $ver $pkgdir ;# DATA etc passed via upvar.
	    }
	}
    }

    # Benchmark data ... Structure, dict (key -> value)
    #
    # Key          || Value
    # ============ ++ =========================================
    # interp IP    -> Version. Shell IP was used to run benchmarks. IP is
    #                 the path to the shell.
    #
    # desc DESC    -> "". DESC is description of an executed benchmark.
    #
    # usec DESC IP -> Result. Result of benchmark DESC when run by the
    #                 shell IP. Usually time in microseconds, but can be
    #                 a special code as well (ERR, BAD_RES).
    # ============ ++ =========================================

    return [array get DATA]
}

# ::bench::locate --
#
#	Locate interpreters on the pathlist, based on a pattern.
#
# Arguments:
#	...
#
# Results:
#	List of paths.

proc ::bench::locate {pattern paths} {
    # Cache of executables already found.
    array set var {}
    set res {}

    foreach path $paths {
	foreach ip [glob -nocomplain [file join $path $pattern]] {
	    if {[package vsatisfies [package provide Tcl] 8.4]} {
		set ip [file normalize $ip]
	    }

	    # Follow soft-links to the actual executable.
	    while {[string equal link [file type $ip]]} {
		set link [file readlink $ip]
		if {[string match relative [file pathtype $link]]} {
		    set ip [file join [file dirname $ip] $link]
		} else {
		    set ip $link
		}
	    }

	    if {
		[file executable $ip] && ![info exists var($ip)]
	    } {
		if {[catch {exec $ip << "exit"} dummy]} {
		    log::debug "$ip: $dummy"
		    continue
		}
		set var($ip) .
		lappend res $ip
	    }
	}
    }

    return $res
}

# ::bench::versions --
#
#	Take list of interpreters, find their versions.
#	Removes all interps for which it cannot do so.
#
# Arguments:
#	List of interpreters (paths)
#
# Results:
#	dictionary: interpreter -> version.

proc ::bench::versions {interps} {
    set res {}
    foreach ip $interps {
	if {[catch {
	    exec $ip << {puts [info patchlevel] ; exit}
	} patchlevel]} {
	    log::debug "$ip: $patchlevel"
	    continue
	}

	lappend res [list $patchlevel $ip]
    }

    # -uniq 8.4-ism, replaced with use of array.
    array set tmp {}
    set resx {}
    foreach item [lsort -dictionary -decreasing -index 0 $res] {
	foreach {p ip} $item break
	if {[info exists tmp($p)]} continue
	set tmp($p) .
	lappend resx $ip $p
    }

    return $resx
}

# ::bench::merge --
#
#	Take the data of several benchmark runs and merge them into
#	one data set.
#
# Arguments:
#	One or more data sets to merge
#
# Results:
#	The merged data set.

proc ::bench::merge {args} {
    if {[llength $args] == 1} {
	return [lindex $args 0]
    }

    array set DATA {}
    foreach data $args {
	array set DATA $data
    }
    return [array get DATA]
}

# ::bench::norm --
#
#	Normalize the time data in the dataset, using one of the
#	columns as reference.
#
# Arguments:
#	Data to normalize
#	Index of reference column
#
# Results:
#	The normalized data set.

proc ::bench::norm {data col} {

    if {![string is integer -strict $col]} {
	return -code error "Ref.column: Expected integer, but got \"$col\""
    }
    if {$col < 1} {
	return -code error "Ref.column out of bounds"
    }

    array set DATA $data
    set ipkeys [array names DATA interp*]

    if {$col > [llength $ipkeys]} {
	return -code error "Ref.column out of bounds"
    }
    incr col -1
    set refip [lindex [lindex [lsort -dict $ipkeys] $col] 1]

    foreach key [array names DATA] {
	if {[string match "desc*"   $key]} continue
	if {[string match "interp*" $key]} continue

	foreach {_ desc ip} $key break
	if {[string equal $ip $refip]}      continue

	set v $DATA($key)
	if {![string is double -strict $v]} continue

	if {![info exists DATA([list usec $desc $refip])]} {
	    # We cannot normalize, we do not keep the time value.
	    # The row will be shown, empty.
	    set DATA($key) ""
	    continue
	}
	set vref $DATA([list usec $desc $refip])

	if {![string is double -strict $vref]} continue

	set DATA($key) [expr {$v/double($vref)}]
    }

    foreach key [array names DATA [list * $refip]] {
	if {![string is double -strict $DATA($key)]} continue
	set DATA($key) 1
    }

    return [array get DATA]
}

# ::bench::edit --
#
#	Change the 'path' of an interp to a user-defined value.
#
# Arguments:
#	Data to edit
#	Index of column to change
#	The value replacing the current path
#
# Results:
#	The changed data set.

proc ::bench::edit {data col new} {

    if {![string is integer -strict $col]} {
	return -code error "Ref.column: Expected integer, but got \"$col\""
    }
    if {$col < 1} {
	return -code error "Ref.column out of bounds"
    }

    array set DATA $data
    set ipkeys [array names DATA interp*]

    if {$col > [llength $ipkeys]} {
	return -code error "Ref.column out of bounds"
    }
    incr col -1
    set refip [lindex [lindex [lsort -dict $ipkeys] $col] 1]

    if {[string equal $new $refip]} {
	# No change, quick return
	return $data
    }

    set refkey [list interp $refip]
    set DATA([list interp $new]) $DATA($refkey)
    unset                         DATA($refkey)

    foreach key [array names DATA [list * $refip]] {
	if {![string equal [lindex $key 0] "usec"]} continue
	foreach {__ desc ip} $key break
	set DATA([list usec $desc $new]) $DATA($key)
	unset                             DATA($key)
    }

    return [array get DATA]
}

# ::bench::del --
#
#	Remove the data for an interp.
#
# Arguments:
#	Data to edit
#	Index of column to remove
#
# Results:
#	The changed data set.

proc ::bench::del {data col} {

    if {![string is integer -strict $col]} {
	return -code error "Ref.column: Expected integer, but got \"$col\""
    }
    if {$col < 1} {
	return -code error "Ref.column out of bounds"
    }

    array set DATA $data
    set ipkeys [array names DATA interp*]

    if {$col > [llength $ipkeys]} {
	return -code error "Ref.column out of bounds"
    }
    incr col -1
    set refip [lindex [lindex [lsort -dict $ipkeys] $col] 1]

    unset DATA([list interp $refip])

    # Do not use 'array unset'. Keep 8.2 clean.
    foreach key [array names DATA [list * $refip]] {
	if {![string equal [lindex $key 0] "usec"]} continue
	unset DATA($key)
    }

    return [array get DATA]
}

# ### ### ### ######### ######### ######### ###########################
## Public API - Result formatting.

# ::bench::out::raw --
#
#	Format the result of a benchmark run.
#	Style: Raw data.
#
# Arguments:
#	DATA dict
#
# Results:
#	String containing the formatted DATA.

proc ::bench::out::raw {data} {
    return $data
}

# ### ### ### ######### ######### ######### ###########################
## Internal commands

proc ::bench::CheckPkgDirArg {path {expected {}}} {
    # Allow empty string, special.
    if {![string length $path]} return

    if {![file isdirectory $path]} {
	return -code error \
	    "The path \"$path\" is not a directory."
    }
    if {![file readable $path]} {
	return -code error \
	    "The path \"$path\" is not readable."
    }
}

proc ::bench::Invoke {ip ver pkgdir} {
    variable self
    # Import remainder of the current configuration/settings.

    upvar 1 DATA DATA match match rmatch rmatch \
	iters iters errors errors threads threads \
	files files

    if {[string length $pkgdir]} {
	log::info "Benchmark $ver ($pkgdir) $ip"
	set idstr "$ip ($pkgdir)"
    } else {
	log::info "Benchmark $ver $ip"
	set idstr $ip
    }

    set DATA([list interp $idstr]) $ver

    set cmd [list $ip [file join $self libbench.tcl] \
		 -match   $match   \
		 -rmatch  $rmatch  \
		 -iters   $iters   \
		 -interp  $ip      \
		 -errors  $errors  \
		 -threads $threads \
		 -pkgdir  $pkgdir  \
		]

    # Determine elapsed time per file, logged.
    set start [clock seconds]

    array set tmp {}

    if {$threads} {
	foreach f $files { lappend cmd $f }
	if {[catch {
	    close [Process [open |$cmd r+]]
	} output]} {
	    if {$errors} {
		error $::errorInfo
	    }
	}
    } else {
	foreach file $files {
	    log::info [file tail $file]
	    if {[catch {
		close [Process [open |[linsert $cmd end $file] r+]]
	    } output]} {
		if {$errors} {
		    error $::errorInfo
		} else {
		    continue
		}
	    }
	}
    }

    foreach desc [array names tmp] {
	set DATA([list desc $desc]) {}
	set DATA([list usec $desc $idstr]) $tmp($desc)
    }

    unset tmp
    set elapsed [expr {[clock seconds] - $start}]

    set hour [expr {$elapsed / 3600}]
    set min  [expr {$elapsed / 60}]
    set sec  [expr {$elapsed % 60}]
    log::info " [format %.2d:%.2d:%.2d $hour $min $sec] elapsed"
    return
}


proc ::bench::Process {pipe} {
    while {1} {
	if {[eof  $pipe]} break
	if {[gets $pipe line] < 0} break
	# AK: FUTURE: Log all lines?!
	#puts |$line|
	set line [string trim $line]
	if {[string equal $line ""]} continue

	Result
	Feedback
	# Unknown lines are printed. Future: Callback?!
	log::info $line
    }
    return $pipe
}

proc ::bench::Result {} {
    upvar 1 line line
    if {[lindex $line 0] ne "RESULT"} return
    upvar 2 tmp tmp
    foreach {_ desc result} $line break
    set tmp($desc) $result
    return -code continue
}

proc ::bench::Feedback {} {
    upvar 1 line line
    if {[lindex $line 0] ne "LOG"} return
    # AK: Future - Run through callback?!
    log::info [lindex $line 1]
    return -code continue
}

# ### ### ### ######### ######### ######### ###########################
## Initialize internal data structures.

namespace eval ::bench {
    variable self [file join [pwd] [file dirname [info script]]]

    logger::init bench
    logger::import -force -all -namespace log bench
}

# ### ### ### ######### ######### ######### ###########################
## Ready to run

package provide bench 0.4
