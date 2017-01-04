# bench_wtext.tcl --
#
#	Management of benchmarks, formatted text.
#
# Copyright (c) 2005 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# library derived from runbench.tcl application (C) Jeff Hobbs.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: bench_wcsv.tcl,v 1.4 2007/01/21 23:29:06 andreas_kupries Exp $

# ### ### ### ######### ######### ######### ###########################
## Requisites - Packages and namespace for the commands and data.

package require Tcl 8.2
package require csv

namespace eval ::bench::out {}

# ### ### ### ######### ######### ######### ###########################
## Public API - Benchmark execution

# ### ### ### ######### ######### ######### ###########################
## Public API - Result formatting.

# ::bench::out::csv --
#
#	Format the result of a benchmark run.
#	Style: CSV
#
# Arguments:
#	DATA dict
#
# Results:
#	String containing the formatted DATA.

proc ::bench::out::csv {data} {
    array set DATA $data
    set CSV {}

    # 1st record:              #shells
    # 2nd record to #shells+1: Interpreter data (id, version, path)
    # #shells+2 to end:        Benchmark data (id,desc,result1,...,result#shells)

    # --- --- ----
    # #interpreters used

    set ipkeys [array names DATA interp*]
    lappend CSV [csv::join [list [llength $ipkeys]]]

    # --- --- ----
    # Table 1: Interpreter information.

    set n 1
    set iplist {}
    foreach key [lsort -dict $ipkeys] {
	set ip [lindex $key 1]
	lappend CSV [csv::join [list $n $DATA($key) $ip]]
	set DATA($key) $n
	incr n
	lappend iplist $ip
    }

    # --- --- ----
    # Table 2: Benchmark information

    set dlist {}
    foreach key [lsort -dict -index 1 [array names DATA desc*]] {
	lappend dlist [lindex $key 1]
    }

    set n 1
    foreach desc $dlist { 
	set record {}
	lappend record $n
	lappend record $desc
	foreach ip $iplist {
	    if {[catch {
		lappend record $DATA([list usec $desc $ip])
	    }]} {
		lappend record {}
	    }
	}
	lappend CSV [csv::join $record]
	incr n
    }

    return [join $CSV \n]
}

# ### ### ### ######### ######### ######### ###########################
## Internal commands

# ### ### ### ######### ######### ######### ###########################
## Initialize internal data structures.

# ### ### ### ######### ######### ######### ###########################
## Ready to run

package provide bench::out::csv 0.1.2
