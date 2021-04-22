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
# RCS: @(#) $Id: bench_wtext.tcl,v 1.4 2007/01/21 23:29:06 andreas_kupries Exp $

# ### ### ### ######### ######### ######### ###########################
## Requisites - Packages and namespace for the commands and data.

package require Tcl 8.2
package require struct::matrix
package require report

namespace eval ::bench::out {}

# ### ### ### ######### ######### ######### ###########################
## Public API - Result formatting.

# ::bench::out::text --
#
#	Format the result of a benchmark run.
#	Style: TEXT
#
#	General structure like CSV, but nicely formatted and aligned
#	columns.
#
# Arguments:
#	DATA dict
#
# Results:
#	String containing the formatted DATA.

proc ::bench::out::text {data} {
    array set DATA $data
    set LINES {}

    # 1st line to #shells: Interpreter data (id, version, path)
    # #shells+1 to end:    Benchmark data (id,desc,result1,...,result#shells)

    lappend LINES {}

    # --- --- ----
    # Table 1: Interpreter information.

    set ipkeys [array names DATA interp*]
    set n 1
    set iplist {}
    set vlen 0
    foreach key [lsort -dict $ipkeys] {
	lappend iplist [lindex $key 1]
	incr n
	set l [string length $DATA($key)]
	if {$l > $vlen} {set vlen $l}
    }
    set idlen [string length $n]

    set dlist {}
    set n 1
    foreach key [lsort -dict -index 1 [array names DATA desc*]] {
	lappend dlist [lindex $key 1]
	incr n
    }
    set didlen [string length $n]

    set n 1
    set record [list "" INTERP]
    foreach ip $iplist {
	set v $DATA([list interp $ip])
	lappend LINES " [PADL $idlen $n]: [PADR $vlen $v] $ip"
	lappend record $n
	incr n
    }

    lappend LINES {}

    # --- --- ----
    # Table 2: Benchmark information

    set m [struct::matrix m]
    $m add columns [expr {2 + [llength $iplist]}]
    $m add row $record

    set n 1
    foreach desc $dlist { 
	set     record [list $n]
	lappend record $desc

	foreach ip $iplist {
	    if {[catch {
		set val $DATA([list usec $desc $ip])
	    }]} {
		set val {}
	    }
	    if {[string is double -strict $val]} {
		lappend record [format %.2f $val]
	    } else {
		lappend record [format %s   $val]
	    }
	}
	$m add row $record
	incr n
    }

    ::report::defstyle simpletable {} {
	data	set [split "[string repeat "| "   [columns]]|"]
	top	set [split "[string repeat "+ - " [columns]]+"]
	bottom	set [top get]
	top	enable
	bottom	enable

	set c [columns]
	justify 0 right
	pad 0 both

	if {$c > 1} {
	    justify 1 left
	    pad 1 both
	}
	for {set i 2} {$i < $c} {incr i} {
	    justify $i right
	    pad $i both
	}
    }
    ::report::defstyle captionedtable {{n 1}} {
	simpletable
	topdata   set [data get]
	topcapsep set [top get]
	topcapsep enable
	tcaption $n
    }

    set r [report::report r [$m columns] style captionedtable]
    lappend LINES [$m format 2string $r]
    $m destroy
    $r destroy

    return [join $LINES \n]
}

# ### ### ### ######### ######### ######### ###########################
## Internal commands

proc ::bench::out::PADL {max str} {
    format "%${max}s" $str
    #return "[PAD $max $str]$str"
}

proc ::bench::out::PADR {max str} {
    format "%-${max}s" $str
    #return "$str[PAD $max $str]"
}

# ### ### ### ######### ######### ######### ###########################
## Initialize internal data structures.

# ### ### ### ######### ######### ######### ###########################
## Ready to run

package provide bench::out::text 0.1.2
