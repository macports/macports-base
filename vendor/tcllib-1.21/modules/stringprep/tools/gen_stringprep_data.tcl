#!/usr/bin/env tclsh

# gen_stringprep_data.tcl --
#
#	This program parses the RFC 3454 file and generates the
#	corresponding stringprep_data.tcl file with compressed character
#	data tables.  The input to this program should be rfc3454.txt.
#	It can be downloaded from http://www.ietf.org/rfc/rfc3454.txt
#
# Copyright (c) 1998-1999 by Scriptics Corporation.
# All rights reserved.
#
# Modified for ejabberd by Alexey Shchepin
# Modified for Tcl stringprep by Sergei Golovan
#
# Usage: gen_stringprep_data.tcl infile outdir
# 
# RCS: @(#) $Id: gen_stringprep_data.tcl,v 1.2 2009/11/02 00:26:44 patthoyts Exp $


namespace eval uni {
    set shift 7;		# number of bits of data within a page
				# This value can be adjusted to find the
				# best split to minimize table size

    variable pMap;		# map from page to page index, each entry is
				# an index into the pages table, indexed by
				# page number
    variable pages;		# map from page index to page info, each
				# entry is a list of indices into the groups
				# table, the list is indexed by the offset
    variable groups;		# list of character info values, indexed by
				# group number, initialized with the
				# unassigned character group
}

proc uni::getValue {i} {
    variable casemap
    variable casemap2
    variable tablemap

    if {[info exists tablemap($i)]} {
	set tables $tablemap($i)
    } else {
	set tables {}
    }

    if {[info exists casemap2($i)]} {
	set multicase 1
	set delta $casemap2($i)
    } else {
	set multicase 0
	if {[info exists casemap($i)]} {
	    set delta $casemap($i)
	} else {
	    set delta 0
	}
    }

    if {abs($delta) > 0xFFFFF} {
	puts "delta must be less than 22 bits wide"
	exit
    }

    set a1 0
    set b1 0
    set b2 0
    set b3 0
    set c11 0
    set c12 0
    set c21 0
    set c22 0
    set c3 0
    set c4 0
    set c5 0
    set c6 0
    set c7 0
    set c8 0
    set c9 0
    set d1 0
    set d2 0

    foreach tab $tables {
	switch -glob -- $tab {
	    A.1   {set a1 1}
	    B.1   {set b1 1}
	    B.2   {set b2 1}
	    B.3   {set b3 1}
	    C.1.1 {set c11 1}
	    C.1.2 {set c12 1}
	    C.2.1 {set c21 1}
	    C.2.2 {set c22 1}
	    C.3   {set c3 1}
	    C.4   {set c4 1}
	    C.5   {set c5 1}
	    C.6   {set c6 1}
	    C.7   {set c7 1}
	    C.8   {set c8 1}
	    C.9   {set c9 1}
	    D.1   {set d1 1}
	    D.2   {set d2 1}
	}
    }

    set val [expr {($a1  << 0) |
		   ($b1  << 1) |
		   ($b3  << 2) |
		   ($c11 << 3) |
		   ($c12 << 4) |
		   ($c21 << 5) |
		   ($c22 << 6) |
		   (($c3 | $c4 | $c5 | $c6 | $c7 | $c8 | $c9) << 7) |
		   ($d1  << 8) |
		   ($d2  << 9) |
		   ($multicase << 10) |
		   ($delta << 11)}]

    return $val
}

proc uni::getGroup {value} {
    variable groups

    set gIndex [lsearch -exact $groups $value]
    if {$gIndex == -1} {
	set gIndex [llength $groups]
	lappend groups $value
    }
    return $gIndex
}

proc uni::addPage {info} {
    variable pMap
    variable pages
    variable pages_map
    
    if {[info exists pages_map($info)]} {
	lappend pMap $pages_map($info)
    } else {
	set pIndex [llength $pages]
	lappend pages $info
	set pages_map($info) $pIndex
	lappend pMap $pIndex
    }
    return
}


proc uni::load_tables {data} {
    variable casemap
    variable casemap2
    variable multicasemap
    variable tablemap

    set multicasemap {}
    set table ""

    foreach line [split $data \n] {
	if {$table == ""} {
	    if {[regexp {   ----- Start Table (.*) -----} $line temp table]} {
		#puts "Start table '$table'"
	    }
	} else {
	    if {[regexp {   ----- End Table (.*) -----} $line temp table1]} {
		set table ""
	    } else {
		if {$table == "B.1"} {
		    if {[regexp {^   ([[:xdigit:]]+); ;} $line \
			     temp val]} {
			scan $val %x val
			if {$val <= 0x10ffff} {
			    lappend tablemap($val) $table
			}
		    }
		} elseif {$table == "B.2"} {
		    # B.2 table is used for mapping with normalisation
		    if {[regexp {^   ([[:xdigit:]]+); ([[:xdigit:]]+);} $line \
			     temp from to]} {
			scan $from %x from
			scan $to %x to
			if {$from <= 0x10ffff && $to <= 0x10ffff} {
			    set casemap($from) [expr {$to - $from}]
			}
		    } elseif {[regexp {^   ([[:xdigit:]]+); ([[:xdigit:]]+) ([[:xdigit:]]+);} $line \
			     temp from to1 to2]} {
			scan $from %x from
			scan $to1 %x to1
			scan $to2 %x to2
			if {$from <= 0x10ffff && \
				$to1 <= 0x10ffff && $to2 <= 0x10ffff} {
			    set casemap2($from) [llength $multicasemap]
			    lappend multicasemap [list $to1 $to2]
			}
		    } elseif {[regexp {^   ([[:xdigit:]]+); ([[:xdigit:]]+) ([[:xdigit:]]+) ([[:xdigit:]]+);} $line \
			     temp from to1 to2 to3]} {
			scan $from %x from
			scan $to1 %x to1
			scan $to2 %x to2
			scan $to3 %x to3
			if {$from <= 0x10ffff && \
				$to1 <= 0x10ffff && $to2 <= 0x10ffff && \
				$to3 <= 0x10ffff} {
			    set casemap2($from) [llength $multicasemap]
			    lappend multicasemap [list $to1 $to2 $to3]
			}
		    } elseif {[regexp {^   ([[:xdigit:]]+); ([[:xdigit:]]+) ([[:xdigit:]]+) ([[:xdigit:]]+) ([[:xdigit:]]+);} $line \
			     temp from to1 to2 to3 to4]} {
			scan $from %x from
			scan $to1 %x to1
			scan $to2 %x to2
			scan $to3 %x to3
			scan $to4 %x to4
			if {$from <= 0x10ffff && \
				$to1 <= 0x10ffff && $to2 <= 0x10ffff && \
				$to3 <= 0x10ffff && $to4 <= 0x10ffff} {
			    set casemap2($from) [llength $multicasemap]
			    lappend multicasemap [list $to1 $to2 $to3 $to4]
			}
		    } else {
			#puts "missed: $line"
		    }
		    
		} elseif {$table == "B.3"} {
		    # B.3 table is used for mapping without normalisation (B.3 is a subset of B.2)
		    if {[regexp {^   ([[:xdigit:]]+);} $line temp from]} {
			scan $from %x from
			if {$from <= 0x10ffff} {
			    lappend tablemap($from) $table
			}
		    }
		} else {
		    if {[regexp {^   ([[:xdigit:]]+)-([[:xdigit:]]+)} $line \
			     temp from to]} {
			scan $from %x from
			scan $to %x to
			for {set i $from} {$i <= $to && $i <= 0x10ffff} {incr i} {
			    lappend tablemap($i) $table
			}
		    } elseif {[regexp {^   ([[:xdigit:]]+)} $line \
			     temp val]} {
			scan $val %x val
			if {$val <= 0x10ffff} {
			    lappend tablemap($val) $table
			}
		    }
		}
	    }
	}
    }
}

proc uni::buildTables {} {
    variable shift

    variable casemap
    variable tablemap

    variable pMap {}
    variable pages {}
    variable groups {}
    set info {}			;# temporary page info
    
    set mask [expr {(1 << $shift) - 1}]

    set next 0

    for {set i 0} {$i <= 0x10ffff} {incr i} {
	set gIndex [getGroup [getValue $i]]

	# Split character index into offset and page number
	set offset [expr {$i & $mask}]
	set page [expr {($i >> $shift)}]

	# Add the group index to the info for the current page
	lappend info $gIndex

	# If this is the last entry in the page, add the page
	if {$offset == $mask} {
	    addPage $info
	    set info {}
	}
    }
    return
}

proc uni::main {} {
    global argc argv0 argv
    variable pMap
    variable pages
    variable groups
    variable shift
    variable multicasemap

    if {$argc != 2} {
	puts stderr "\nusage: $argv0 <datafile> <outdir>\n"
	exit 1
    }
    set f [open [lindex $argv 0] r]
    set data [read $f]
    close $f

    load_tables $data
    buildTables
    #puts "X = [llength $pMap]  Y= [llength $pages]  A= [llength $groups]"
    #set size [expr {[llength $pMap] + [llength $pages]*(1<<$shift)}]
    #puts "shift = $shift, space = $size"

    set f [open [file join [lindex $argv 1] stringprep_data.tcl] w]
    fconfigure $f -translation lf
    puts $f \
"# stringprep_data.tcl --
#
#	Declarations of Unicode character information tables.  This file is
#	automatically generated by the gen_stringprep_data.tcl script.  Do not
#	modify this file by hand.
#
# Copyright (c) 1998 Scriptics Corporation.
# Copyright (c) 2007 Alexey Shchepin
# Copyright (c) 2008 Sergei Golovan
#
# RCS: @(#) \$Id\$
#

package provide stringprep::data 1.0.1

namespace eval ::stringprep::data {

#
# A 16-bit Unicode character is split into two parts in order to index
# into the following tables.  The lower OFFSET_BITS comprise an offset
# into a page of characters.  The upper bits comprise the page number.
#

set OFFSET_BITS $shift

#
# The pageMap is indexed by page number and returns an alternate page number
# that identifies a unique page of characters.  Many Unicode characters map
# to the same alternate page number.
#

array unset pageMap
array set pageMap \[list \\"
    array unset tmp
    foreach idx $pMap {
	if {![info exists tmp($idx)]} {
	    set tmp($idx) 1
	} else {
	    incr tmp($idx)
	}
    }
    set max 0
    set max_id 0
    foreach idx [array names tmp] {
	if {$tmp($idx) > $max} {
	    set max $tmp($idx)
	    set max_id $idx
	}
    }
    set line "   "
    set last [expr {[llength $pMap] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set num [lindex $pMap $i]
	if {$num != $max_id} {
	    append line " $i $num"
	}
	if {[string length $line] > 70} {
	    puts $f "$line \\"
	    set line "   "
	}
    }
    puts $f "$line\]

set COMMON_PAGE_MAP $max_id

#
# The groupMap is indexed by combining the alternate page number with
# the page offset and returns a group number that identifies a unique
# set of character attributes.
#

set groupMap \[list \\"
    set line "    "
    set lasti [expr {[llength $pages] - 1}]
    for {set i 0} {$i <= $lasti} {incr i} {
	set page [lindex $pages $i]
	set lastj [expr {[llength $page] - 1}]
	for {set j 0} {$j <= $lastj} {incr j} {
	    append line [lindex $page $j]
	    if {$j != $lastj || $i != $lasti} {
		append line " "
	    }
	    if {[string length $line] > 70} {
		puts $f "$line\\"
		set line "    "
	    }
	}
    }
    puts $f "$line\]

#
# Each group represents a unique set of character attributes.  The attributes
# are encoded into a 32-bit value as follows:
#
# Bit  0	A.1
#
# Bit  1	B.1
#
# Bit  2	B.3
#
# Bit  3	C.1.1
#
# Bit  4	C.1.2
#
# Bit  5	C.2.1
#
# Bit  6	C.2.2
#
# Bit  7	C.3--C.9
#
# Bit  8	D.1
#
# Bit  9	D.2
#
# Bit  10	Case maps to several characters
#
# Bits 11-31	Case delta: delta for case conversions.  This should be the
#		highest field so we can easily sign extend.
#

set groups \[list \\"
    set line "    "
    set last [expr {[llength $groups] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set val [lindex $groups $i]

	append line [format "%d" $val]
	if {$i != $last} {
	    append line " "
	}
	if {[string length $line] > 65} {
	    puts $f "$line\\"
	    set line "    "
	}
    }
    puts $f "$line\]

#
# Table for characters that lowercased to multiple ones
#

set multiCaseTable \[list \\"
    set last [expr {[llength $multicasemap] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set val [lindex $multicasemap $i]

	set line "    "
	append line "{" [join $val " "] "}"
	puts $f "$line \\"
    }
    puts $f "\]

#
# The following constants are used to determine the category of a
# Unicode character.
#

set A1Mask  \[expr {1 << 0}\]
set B1Mask  \[expr {1 << 1}\]
set B3Mask  \[expr {1 << 2}\]
set C11Mask \[expr {1 << 3}\]
set C12Mask \[expr {1 << 4}\]
set C21Mask \[expr {1 << 5}\]
set C22Mask \[expr {1 << 6}\]
set C39Mask \[expr {1 << 7}\]
set D1Mask  \[expr {1 << 8}\]
set D2Mask  \[expr {1 << 9}\]
set MCMask  \[expr {1 << 10}\]

#
# The following procs extract the fields of the character info.
#

proc GetCaseType {info} {expr {(\$info & 0xE0) >> 5}}
proc GetCategory {info} {expr {\$info & 0x1F}}
proc GetDelta {info} {expr {\$info >> 11}}
proc GetMC {info} {
    variable multiCaseTable
    lindex \$multiCaseTable \[GetDelta \$info\]
}

#
# This proc extracts the information about a character from the
# Unicode character tables.
#

proc GetUniCharInfo {uc} {
    variable OFFSET_BITS
    variable COMMON_PAGE_MAP
    variable pageMap
    variable groupMap
    variable groups

    set page \[expr {(\$uc & 0x1fffff) >> \$OFFSET_BITS}\]
    if {\[info exists pageMap(\$page)\]} {
	set apage \$pageMap(\$page)
    } else {
	set apage \$COMMON_PAGE_MAP
    }

    lindex \$groups \\
	   \[lindex \$groupMap \\
		   \[expr {(\$apage << \$OFFSET_BITS) | \\
			   (\$uc & ((1 << \$OFFSET_BITS) - 1))}\]\]
}

} ; # namespace eval ::stringprep::data
"
    close $f
}

uni::main

return
