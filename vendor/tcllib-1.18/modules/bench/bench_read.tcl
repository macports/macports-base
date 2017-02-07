# bench_read.tcl --
#
#	Management of benchmarks, reading results in various formats.
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# library derived from runbench.tcl application (C) Jeff Hobbs.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: bench_read.tcl,v 1.3 2006/06/13 23:20:30 andreas_kupries Exp $

# ### ### ### ######### ######### ######### ###########################
## Requisites - Packages and namespace for the commands and data.

package require Tcl 8.2
package require csv

namespace eval ::bench::in {}

# ### ### ### ######### ######### ######### ###########################
## Public API - Result reading

# ::bench::in::read --
#
#	Read a bench result in any of the raw/csv/text formats
#
# Arguments:
#	path to file to read
#
# Results:
#	DATA dictionary, internal representation of the bench results.

proc ::bench::in::read {file} {

    set f [open $file r]
    set head [gets $f]

    if {![string match "# -\\*- tcl -\\*- bench/*" $head]} {
	return -code error "Bad file format, not a benchmark file"
    } else {
	regexp {bench/(.*)$} $head -> format

	switch -exact -- $format {
	    raw - csv - text {
		set res [RD$format $f]
	    }
	    default {
		return -code error "Bad format \"$val\", expected text, csv, or raw"
	    }
	}
    }
    close $f
    return $res
}

# ### ### ### ######### ######### ######### ###########################
## Internal commands

proc ::bench::in::RDraw {chan} {
    return [string trimright [::read $chan]]
}

proc ::bench::in::RDcsv {chan} {
    # Lines                                     Format
    # First line is number of interpreters #n.  int
    # Next to 1+n is interpreter data.          id,ver,path
    # Beyond is benchmark results.              id,desc,res1,...,res#n

    array set DATA {}

    # #Interp ...

    set nip [lindex [csv::split [gets $chan]] 0]

    # Interp data ...

    set iplist {}
    for {set i 0} {$i < $nip} {incr i} {
	foreach {__ ver ip} [csv::split [gets $chan]] break

	set DATA([list interp $ip]) $ver
	lappend iplist $ip
    }

    # Benchmark data ...

    while {[gets $chan line] >= 0} {
	set line [string trim $line]
	if {$line == {}} break
	set line [csv::split $line]
	set desc [lindex $line 1]

	set DATA([list desc $desc]) {}
	foreach val [lrange $line 2 end] ip $iplist {
	    if {$val == {}} continue
	    set DATA([list usec $desc $ip]) $val
	}
    }

    return [array get DATA]
}

proc ::bench::in::RDtext {chan} {
    array set DATA {}

    # Interp data ...

    # Empty line     - ignore
    # "id: ver path" - interp data.
    # Empty line     - separator before benchmark data.

    set n 0
    set iplist {}
    while {[gets $chan line] >= 0} {
	set line [string trim $line]
	if {$line == {}} {
	    incr n
	    if {$n == 2} break
	    continue
	}

	regexp {[^:]+: ([^ ]+) (.*)$} $line -> ver ip
	set DATA([list interp $ip]) $ver
	lappend iplist $ip
    }

    # Benchmark data ...

    # '---' -> Ignore.
    # '|' column separators. Remove spaces around it. Then treat line
    # as CSV data with a particular separator.
    # Ignore the INTERP line.

    while {[gets $chan line] >= 0} {
	set line [string trim $line]
	if {$line == {}}                     continue
	if {[string match "+---*"    $line]} continue
	if {[string match "*INTERP*" $line]} continue

	regsub -all "\\| +" $line {|} line
	regsub -all " +\\|" $line {|} line
	set line [csv::split [string trim $line |] |]
	set desc [lindex $line 1]

	set DATA([list desc $desc]) {}
	foreach val [lrange $line 2 end] ip $iplist {
	    if {$val == {}} continue
	    set DATA([list usec $desc $ip]) $val
	}
    }

    return [array get DATA]
}

# ### ### ### ######### ######### ######### ###########################
## Initialize internal data structures.

# ### ### ### ######### ######### ######### ###########################
## Ready to run

package provide bench::in 0.1
