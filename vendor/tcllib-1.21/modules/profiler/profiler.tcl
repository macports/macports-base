# profiler.tcl --
#
#	Tcl code profiler.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.3		;# uses [clock clicks -milliseconds]
package provide profiler 0.6

namespace eval ::profiler {}

# ::profiler::tZero --
#
#	Start a named timer instance
#
# Arguments:
#	tag	name for the timer instance; if none is given, defaults to ""
#
# Results:
#	None.

proc ::profiler::tZero { { tag "" } } {
    set ms [ clock clicks -milliseconds ]
    set us [ clock clicks ]
    set tag [string map {: ""} $tag]
    # FRINK: nocheck
    set ::profiler::T$tag [ list $us $ms ]
    return
}

# ::profiler::tMark --
#
#	Return the delta time since the start of a named timer.
#
# Arguments:
#	tag	Tag for which to return a delta; if none is given, defaults to
#		""
#
# Results:
#	dt	Time difference between start of the timer and the current
#		time, in microseconds.

proc ::profiler::tMark { { tag "" } } {
    set ut [ clock clicks ]
    set mt [ clock clicks -milliseconds ]
    set tag [string map {: ""} $tag]

    # Per tag a variable was created within the profiler
    # namespace. But we should check if the tag does ecxist.

    if {![info exists ::profiler::T$tag]} {
	error "Unknown tag \"$tag\""
    }
    # FRINK: nocheck
     set ust [ lindex [ set ::profiler::T$tag ] 0 ]
    # FRINK: nocheck
     set mst [ lindex [ set ::profiler::T$tag ] 1 ]
     set udt [ expr { ($ut-$ust) } ]
     set mdt [ expr { ($mt-$mst) } ]000
     set dt $udt
     ;## handle wrapping of the microsecond clock
     if { $dt < 0 || $dt > 1000000 } { set dt $mdt }
     set dt
}

# ::profiler::stats --
#
#	Compute statistical information for a set of values, including
#	the mean, the standard deviation, and the covariance.
#
# Arguments:
#	args	Values for which to compute information.
#
# Results:
#	A list with three elements:  the mean, the standard deviation, and the
#	covariance.

proc ::profiler::stats {args} {
    set sum      0
    set mean     0
    set sigma_sq 0
    set sigma    0
    set cov      0
    set N [ llength $args ]
    if { $N > 1 } {
        foreach val $args {
            incr sum $val
        }
        if {$sum > 0} {
            set mean [ expr { $sum/$N } ]
            foreach val $args {
                set sigma_sq [ expr { $sigma_sq+pow(($val-$mean),2) } ]
            }
            set sigma_sq [ expr { $sigma_sq/($N-1) } ]
            set sigma [ expr { round(sqrt($sigma_sq)) } ]
	    if { $mean != 0 } {
		set cov [ expr { (($sigma*1.0)/$mean)*100 } ]
		set cov [ expr { round($cov*10)/10.0 } ]
	    }
        }
    }
    return [ list $mean $sigma $cov ]
}

# ::profiler::Handler --
#
#	Profile a function (tcl8.3).  This function works together with
#       profProc, which replaces the proc command.  When a new procedure
#       is defined, it creates and alias to this function; when that
#       procedure is called, it calls this handler first, which gathers
#       profiling information from the call.
#
# Arguments:
#	name	name of the function to profile.
#	args	arguments to pass to the original function.
#
# Results:
#	res	result from the original function.

proc ::profiler::Handler {name args} {
    variable enabled

    if { [info level] == 1 } {
        set caller GLOBAL
    } else {
        # Get the name of the calling procedure
	set caller [lindex [info level -1] 0]
	# Remove the ORIG suffix
	set caller [string range $caller 0 end-4]

        # Make sure that caller names always include the "::" prefix;
        # otherwise we get confused by the string inequality between
        # "::foo" and "foo" -- even though those refer to the same proc.

        if { ![string equal -length 2 $caller "::"] } {
            set caller "::$caller"
        }
    }

    ::profiler::enterHandler $name $caller
    set CODE [uplevel 1 [list ${name}ORIG] $args]
    ::profiler::leaveHandler $name $caller
    return $CODE
}

# ::profiler::TraceHandler --
#
#	Profile a function (tcl8.4+).  This function works together with
#       profProc, which replaces the proc command.  When a new procedure
#       is defined, it creates an execution trace on the function; when
#       that function is called, 'enter' and 'leave' traces invoke this
#       handler first, which gathers profiling information from the call.
#
# Arguments:
#	name	name of the function to profile.
#	cmd	command name and its expanded arguments.
#	args	for 'enter' operation, value of args is "enter"
#	    	for 'leave' operation, args is list of
#               3 elements: <code> <result> "leave"
#
# Results:
#	None

proc ::profiler::TraceHandler {name cmd args} {

    if { [info level] == 1 } {
        set caller GLOBAL
    } else {
        # Get the name of the calling procedure
	set caller [lindex [info level -1] 0]

        # Make sure that caller names always include the "::" prefix;
        # otherwise we get confused by the string inequality between
        # "::foo" and "foo" -- even though those refer to the same proc.

        if { ![string equal -length 2 $caller "::"] } {
            set caller "::$caller"
        }
    }

    set type [lindex $args end]
    ::profiler::${type}Handler $name $caller
}

# ::profiler::enterHandler --
#
#	Profile a function.  This function works together with Handler and
#       TraceHandler to collect profiling information just before it invokes
#       the function.
#
# Arguments:
#	name	name of the function to profile.
#	caller	name of the function that calls the profiled function.
#
# Results:
#	None

proc ::profiler::enterHandler {name caller} {
    variable enabled

    if { !$enabled($name) } {
        return
    }

    if { [catch {incr ::profiler::callers($name,$caller)}] } {
        set ::profiler::callers($name,$caller) 1
    }
    ::profiler::tZero $name.$caller
}

# ::profiler::leaveHandler --
#
#	Profile a function.  This function works together with Handler and
#       TraceHandler to collect profiling information just after it invokes
#       the function.
#
# Arguments:
#	name	name of the function to profile.
#	caller	name of the function that calls the profiled function.
#
# Results:
#	None

proc ::profiler::leaveHandler {name caller} {
    variable enabled

    # Tkt [0dd4b31bb8] Note that the result is pulled from the
    # caller's context as it is not passed into leaveHandler

    if { !$enabled($name) } {
	return [uplevel 1 {lindex $args 1}] ;# RETURN RESULT!
    }

    set t [::profiler::tMark $name.$caller]
    lappend ::profiler::statTime($name) $t

    if { [incr ::profiler::callCount($name)] == 1 } {
        set ::profiler::compileTime($name) $t
    }
    incr ::profiler::totalRuntime($name) $t
    if { [catch {incr ::profiler::descendantTime($caller) $t}] } {
        set ::profiler::descendantTime($caller) $t
    }
    if { [catch {incr ::profiler::descendants($caller,$name)}] } {
        set ::profiler::descendants($caller,$name) 1
    }

    return [uplevel 1 {lindex $args 1}] ;# RETURN RESULT!
}

# ::profiler::profProc --
#
#	Replacement for the proc command that adds rudimentary profiling
#	capabilities to Tcl.
#
# Arguments:
#	name		name of the procedure
#	arglist		list of arguments
#	body		body of the procedure
#
# Results:
#	None.

proc ::profiler::profProc {name arglist body} {
    variable callCount
    variable compileTime
    variable totalRuntime
    variable descendantTime
    variable statTime
    variable enabled
    variable paused

    # Get the fully qualified name of the proc
    set ns [uplevel [list namespace current]]
    # If the proc call did not happen at the global context and it did not
    # have an absolute namespace qualifier, we have to prepend the current
    # namespace to the command name
    if { ![string equal $ns "::"] } {
	if { ![string match "::*" $name] } {
	    set name "${ns}::${name}"
	}
    }
    if { ![string match "::*" $name] } {
	set name "::$name"
    }

    # Set up accounting for this procedure
    set callCount($name) 0
    set compileTime($name) 0
    set totalRuntime($name) 0
    set descendantTime($name) 0
    set statTime($name) {}
    set enabled($name) [expr {!$paused}]

    if {[package vsatisfies [package provide Tcl] 8.4]} {
        uplevel 1 [list ::_oldProc $name $arglist $body]
        trace add execution $name {enter leave} \
                 [list ::profiler::TraceHandler $name]
    } else {
        uplevel 1 [list ::_oldProc ${name}ORIG $arglist $body]
        uplevel 1 [list interp alias {} $name {} ::profiler::Handler $name]
    }
    return
}

# ::profiler::init --
#
#	Initialize the profiler.
#
# Arguments:
#	None.
#
# Results:
#	None.  Renames proc to _oldProc and sets an alias for proc to
#		profiler::profProc

proc ::profiler::init {} {
    # paused is set to 1 when the profiler is suspended.
    variable paused 0

    rename ::proc ::_oldProc
    interp alias {} proc {} ::profiler::profProc

    return
}

# ::profiler::printname --
#
#	Returns a string with some human readable information about
#	the command name that was passed to this procedure.

proc ::profiler::printname {name} {
    variable callCount
    variable compileTime
    variable totalRuntime
    variable descendantTime
    variable descendants
    variable statTime
    variable callers

    set result ""

    set avgRuntime 0
    set sigmaRuntime 0
    set covRuntime 0
    set avgDesTime 0
    if { $callCount($name) > 0 } {
	foreach {m s c} [eval ::profiler::stats $statTime($name)] { break }
	set avgRuntime   $m
	set sigmaRuntime $s
	set covRuntime   $c
	set avgDesTime \
	    [expr {$descendantTime($name)/$callCount($name)}]
    }

    append result "Profiling information for $name\n"
    append result "[string repeat = 60]\n"
    append result "            Total calls:  $callCount($name)\n"
    if { !$callCount($name) } {
	append result "\n"
	return $result
    }
    append result "    Caller distribution:\n"
    set i [expr {[string length $name] + 1}]
    foreach index [lsort [array names callers $name,*]] {
	append result "  [string range $index $i end]:  $callers($index)\n"
    }
    append result "           Compile time:  $compileTime($name)\n"
    append result "          Total runtime:  $totalRuntime($name)\n"
    append result "        Average runtime:  $avgRuntime\n"
    append result "          Runtime StDev:  $sigmaRuntime\n"
    append result "         Runtime cov(%):  $covRuntime\n"
    append result "  Total descendant time:  $descendantTime($name)\n"
    append result "Average descendant time:  $avgDesTime\n"
    append result "Descendants:\n"
    if { !$descendantTime($name) } {
	append result "  none\n"
    }
    foreach index [lsort [array names descendants $name,*]] {
	append result "  [string range $index $i end]: \
		    $descendants($index)\n"
    }
    append result "\n"
    return $result
}


# ::profiler::print --
#
#	Print information about a proc.
#
# Arguments:
#	pattern	pattern of the proc's to get info for; default is *.
#
# Results:
#	A human readable printout of info.

proc ::profiler::print {{pattern *}} {
    variable callCount
    #parray callCount

    set result ""
    foreach name [lsort [array names callCount $pattern]] {
	append result [printname $name]
    }
    return $result
}

# ::profiler::printsorted --
#
#	This proc takes a key and a pattern as arguments, and produces
#	human readable results for the procs that match the pattern,
#	sorted by the key.

proc ::profiler::printsorted {key {pattern *}} {
    variable callCount
    variable compileTime
    variable totalRuntime
    variable descendantTime
    variable descendants
    variable statTime
    variable callers

    set data [sortFunctions $key]
    foreach {k v} $data {
	append result [printname [lindex $k 0]]
    }
    return $result
}


# ::profiler::dump --
#
#	Dump out the information for a proc in a big blob.
#
# Arguments:
#	pattern	pattern of the proc's to lookup; default is *.
#
# Results:
#	data	data about the proc's.

proc ::profiler::dump {{pattern *}} {
    variable callCount
    variable compileTime
    variable totalRuntime
    variable callers
    variable descendantTime
    variable descendants
    variable statTime

    set result ""
    foreach name [lsort [array names callCount $pattern]] {
	set i [expr {[string length $name] + 1}]
	catch {unset thisCallers}
	foreach index [lsort [array names callers $name,*]] {
	    set thisCallers([string range $index $i end]) $callers($index)
	}
	set avgRuntime 0
	set sigmaRuntime 0
	set covRuntime 0
	set avgDesTime 0
	if { $callCount($name) > 0 } {
	    foreach {m s c} [eval ::profiler::stats $statTime($name)] { break }
	    set avgRuntime   $m
	    set sigmaRuntime $s
	    set covRuntime   $c
	    set avgDesTime \
		    [expr {$descendantTime($name)/$callCount($name)}]
	}
	set descendantList [list ]
	foreach index [lsort [array names descendants $name,*]] {
	    lappend descendantList [string range $index $i end]
	}
	lappend result $name [list callCount $callCount($name) \
		callerDist [array get thisCallers] \
		compileTime $compileTime($name) \
		totalRuntime $totalRuntime($name) \
		averageRuntime $avgRuntime \
		stddevRuntime  $sigmaRuntime \
		covpercentRuntime $covRuntime \
		descendantTime $descendantTime($name) \
		averageDescendantTime $avgDesTime \
		descendants $descendantList]
    }
    return $result
}

# ::profiler::sortFunctions --
#
#	Return a list of functions sorted by a particular field and the
#	value of that field.
#
# Arguments:
#	field	field to sort by
#
# Results:
#	slist	sorted list of lists, sorted by the field in question.

proc ::profiler::sortFunctions {{field ""}} {
    switch -glob -- $field {
	"calls" {
	    upvar ::profiler::callCount data
	}
	"compileTime" {
	    upvar ::profiler::compileTime data
	}
	"totalRuntime" {
	    upvar ::profiler::totalRuntime data
	}
	"avgRuntime" -
	"averageRuntime" {
	    variable callCount
	    variable totalRuntime
	    foreach fxn [array names callCount] {
		if { $callCount($fxn) > 1 } {
		    set data($fxn) \
			    [expr {$totalRuntime($fxn)/($callCount($fxn) - 1)}]
		}
	    }
	}
	"exclusiveRuntime" {
	    variable totalRuntime
	    variable descendantTime
	    foreach fxn [array names totalRuntime] {
		set data($fxn) \
			[expr {$totalRuntime($fxn) - $descendantTime($fxn)}]
	    }
	}
	"avgExclusiveRuntime" {
	    variable totalRuntime
	    variable callCount
	    variable descendantTime
	    foreach fxn [array names totalRuntime] {
		if { $callCount($fxn) } {
		    set data($fxn) \
			    [expr {($totalRuntime($fxn) - \
				$descendantTime($fxn)) / $callCount($fxn)}]
		}
	    }
	}
	"nonCompileTime" {
	    variable compileTime
	    variable totalRuntime
	    foreach fxn [array names totalRuntime] {
		set data($fxn) [expr {$totalRuntime($fxn)-$compileTime($fxn)}]
	    }
	}
	default {
	    error "unknown statistic \"$field\": should be calls,\
		    compileTime, exclusiveRuntime, nonCompileTime,\
		    totalRuntime, avgExclusiveRuntime, or avgRuntime"
	}
    }

    set result [list ]
    foreach fxn [array names data] {
	lappend result [list $fxn $data($fxn)]
    }
    return [lsort -integer -index 1 $result]
}

# ::profiler::reset --
#
#	Reset collected data for functions matching a given pattern.
#
# Arguments:
#	pattern		pattern of functions to reset; default is *.
#
# Results:
#	None.

proc ::profiler::reset {{pattern *}} {
    variable callCount
    variable compileTime
    variable totalRuntime
    variable callers
    variable statTime
    variable descendantTime
    variable descendants

    foreach name [array names callCount $pattern] {
	set callCount($name) 0
	set compileTime($name) 0
	set totalRuntime($name) 0
	set statTime($name) {}
	foreach caller [array names callers $name,*] {
	    unset callers($caller)
	}
	set descendantTime($name) 0
        foreach descendant [array names descendants $name,*] {
            unset descendants($descendant)
        }
    }
    return
}

# ::profiler::suspend --
#
#	Suspend the profiler.
#
# Arguments:
#	pattern		pattern of functions to suspend; default is *.
#
# Results:
#	None.  Resets the `enabled($name)' variable to 0
#	       to suspend profiling

proc ::profiler::suspend {{pattern *}} {
    variable callCount
    variable enabled

    foreach name [array names callCount $pattern] {
        set enabled($name) 0
    }

    return
}

# ::profiler::resume --
#
#	Resume the profiler, after it has been suspended.
#
# Arguments:
#	pattern		pattern of functions to suspend; default is *.
#
# Results:
#	None.  Sets the `enabled($name)' variable to 1
#	       so as to enable the profiler.

proc ::profiler::resume {{pattern *}} {
    variable callCount
    variable enabled

    foreach name [array names callCount $pattern] {
        set enabled($name) 1
    }

    return
}

# ::profiler::new-disabled --
#
#	Start new procedures with profiling disabled
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::profiler::new-disabled {} {
    variable paused 1
    return
}

# ::profiler::new-enabled --
#
#	Start new procedures with profiling enabled
#
# Arguments:
#	None.
#
# Results:
#	None.

proc ::profiler::new-enabled {} {
    variable paused 0
    return
}
