#!/usr/bin/env tclsh

# gen_unicode_data.tcl --
#
#	This program parses the UnicodeData files and generates the
#	corresponding unicode_data.tcl file with compressed character
#	data tables.  The input to this program should be
#	UnicodeData.txt and CompositionExclusions.txt files
#	from: ftp://ftp.unicode.org/Public/UNIDATA/UnicodeData.txt
#	and ftp://ftp.unicode.org/Public/UNIDATA/CompositionExclusions.txt
#
# Copyright (c) 1998-1999 by Scriptics Corporation.
# All rights reserved.
#
# Modified for ejabberd by Alexey Shchepin
# Modified for Tcl stringprep by Sergei Golovan
# 
# Usage: gen_unicode_data.tcl infile1 infile2 outdir 
# 
# RCS: @(#) $Id: gen_unicode_data.tcl,v 1.1 2008/01/29 02:18:10 patthoyts Exp $


namespace eval uni {
    set cclass_shift 2
    set decomp_shift 3
    set comp_shift 1
    set shift 5;		# number of bits of data within a page
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

    variable categories {
	Cn Lu Ll Lt Lm Lo Mn Me Mc Nd Nl No Zs Zl Zp
	Cc Cf Co Cs Pc Pd Ps Pe Pi Pf Po Sm Sc Sk So
    };				# Ordered list of character categories, must
				# match the enumeration in the header file.

    variable titleCount 0;	# Count of the number of title case
				# characters.  This value is used in the
				# regular expression code to allocate enough
				# space for the title case variants.
}

proc uni::getValue {items index} {
    variable categories
    variable titleCount

    # Extract character info

    set category [lindex $items 2]
    if {[scan [lindex $items 12] %4x toupper] == 1} {
	set toupper [expr {$index - $toupper}]
    } else {
	set toupper {}
    }
    if {[scan [lindex $items 13] %4x tolower] == 1} {
	set tolower [expr {$tolower - $index}]
    } else {
	set tolower {}
    }
    if {[scan [lindex $items 14] %4x totitle] == 1} {
	set totitle [expr {$index - $totitle}]
    } else {
	set totitle {}
    }

    set categoryIndex [lsearch -exact $categories $category]
    if {$categoryIndex < 0} {
	puts "Unexpected character category: $index($category)"
	set categoryIndex 0
    } elseif {$category == "Lt"} {
	incr titleCount
    }

    return "$categoryIndex,$toupper,$tolower,$totitle"
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
    
    set pIndex [lsearch -exact $pages $info]
    if {$pIndex == -1} {
	set pIndex [llength $pages]
	lappend pages $info
    }
    lappend pMap $pIndex
    return
}

proc uni::addPage {map_var pages_var info} {
    variable $map_var
    variable $pages_var
    
    set pIndex [lsearch -exact [set $pages_var] $info]
    if {$pIndex == -1} {
	set pIndex [llength [set $pages_var]]
	lappend $pages_var $info
    }
    lappend $map_var $pIndex
    return
}

proc uni::load_exclusions {data} {
    variable exclusions

    foreach line [split $data \n] {
	if {$line == ""} continue

	set items [split $line " "]

	if {[lindex $items 0] == "#"} continue

	scan [lindex $items 0] %x index

	set exclusions($index) ""
    }
}

proc uni::load_tables {data} {
    variable cclass_map
    variable decomp_map
    variable decomp_compat
    variable comp_map
    variable comp_first
    variable comp_second
    variable exclusions

    foreach line [split $data \n] {
	if {$line == ""} continue

	set items [split $line \;]

	scan [lindex $items 0] %x index
	set cclass [lindex $items 3]
	set decomp [lindex $items 5]

	set cclass_map($index) $cclass
	#set decomp_map($index) $cclass

	if {$decomp != ""} {
	    set decomp_compat($index) 0
	    if {[string index [lindex $decomp 0] 0] == "<"} {
		set decomp_compat($index) 1
		set decomp1 [lreplace $decomp 0 0]
		set decomp {}
		foreach ch $decomp1 {
		    scan $ch %x ch
		    lappend decomp $ch
		}
		set decomp_map($index) $decomp
	    } else {
		switch -- [llength $decomp] {
		    1 {
			scan $decomp %x ch
			set decomp_map($index) $ch
		    }
		    2 {
			scan $decomp "%x %x" ch1 ch2
			set decomp [list $ch1 $ch2]
			set decomp_map($index) $decomp
			# hackish
			if {(![info exists cclass_map($ch1)] || \
				 $cclass_map($ch1) == 0) && \
				![info exists exclusions($index)]} {
			    if {[info exists comp_first($ch1)]} {
				incr comp_first($ch1)
			    } else {
				set comp_first($ch1) 1
			    }
			    if {[info exists comp_second($ch2)]} {
				incr comp_second($ch2)
			    } else {
				set comp_second($ch2) 1
			    }
			    set comp_map($decomp) $index
			} else {
			    #puts "Excluded $index"
			}
		    }
		    default {
			puts "Bad canonical decomposition: $line"
		    } 
		}
	    }

	    #puts "[format 0x%0.4x $index]\t$cclass\t$decomp_map($index)"
	}
    }
    #puts [array get comp_first]
    #puts [array get comp_second]
}

proc uni::buildTables {} {
    variable cclass_shift
    variable decomp_shift
    variable comp_shift

    variable cclass_map
    variable cclass_pmap {}
    variable cclass_pages {}
    variable decomp_map
    variable decomp_compat
    variable decomp_pmap {}
    variable decomp_pages {}
    variable decomp_list {}
    variable comp_map
    variable comp_pmap {}
    variable comp_pages {}
    variable comp_first
    variable comp_second
    variable comp_first_list {}
    variable comp_second_list {}
    variable comp_x_list {}
    variable comp_y_list {}
    variable comp_both_map {}

    set cclass_info {}
    set decomp_info {}
    set comp_info {}
    
    set cclass_mask [expr {(1 << $cclass_shift) - 1}]
    set decomp_mask [expr {(1 << $decomp_shift) - 1}]
    set comp_mask [expr {(1 << $comp_shift) - 1}]

    foreach comp [array names comp_map] {
	set ch1 [lindex $comp 0]
	if {[info exists comp_first($ch1)] && $comp_first($ch1) > 0 && \
		[info exists comp_second($ch1)] && $comp_second($ch1) > 0} {
	    if {[lsearch -exact $comp_x_list $ch1] < 0} {
		set i [llength $comp_x_list]
		lappend comp_x_list $ch1
		set comp_info_map($ch1) $i
		lappend comp_y_list $ch1
		set comp_info_map($ch1) $i
		puts "There should be no symbols which appears on"
		puts "both first and second place in composition"
		exit 1
	    }
	}
    }

    foreach comp [array names comp_map] {
	set ch1 [lindex $comp 0]
	set ch2 [lindex $comp 1]

	if {$comp_first($ch1) == 1 && ![info exists comp_second($ch1)]} {
	    set i [llength $comp_first_list]
	    lappend comp_first_list [list $ch2 $comp_map($comp)]
	    set comp_info_map($ch1) [expr {$i | (1 << 16)}]
	} elseif {$comp_second($ch2) == 1 && ![info exists comp_first($ch2)]} {
	    set i [llength $comp_second_list]
	    lappend comp_second_list [list $ch1 $comp_map($comp)]
	    set comp_info_map($ch2) [expr {$i | (1 << 16) | (1 << 17)}]
	} else {
	    if {[lsearch -exact $comp_x_list $ch1] < 0} {
		set i [llength $comp_x_list]
		lappend comp_x_list $ch1
		set comp_info_map($ch1) $i
	    }
	    if {[lsearch -exact $comp_y_list $ch2] < 0} {
		set i [llength $comp_y_list]
		lappend comp_y_list $ch2
		set comp_info_map($ch2) [expr {$i | (1 << 17)}]
	    }
	}
    }

    set next 0

    for {set i 0} {$i <= 0x10ffff} {incr i} {
	#set gIndex [getGroup [getValue $i]]

	set cclass_offset [expr {$i & $cclass_mask}]

	if {[info exists cclass_map($i)]} {
	    set cclass $cclass_map($i)
	} else {
	    set cclass 0
	}
	lappend cclass_info $cclass

	if {$cclass_offset == $cclass_mask} {
	    addPage cclass_pmap cclass_pages $cclass_info
	    set cclass_info {}
	}


	set decomp_offset [expr {$i & $decomp_mask}]

	if {[info exists decomp_map($i)]} {
	    set decomp $decomp_map($i)
	    if {[llength $decomp] > (1 << 14)} {
		puts "Too long decomp for $i"
		exit 1
	    }

	    if {[info exists decomp_used($decomp)]} {
		lappend decomp_info [expr {$decomp_used($decomp) | ($decomp_compat($i) << 16)}]
	    } else {
		set val [expr {([llength $decomp] << 17) + \
				   [llength $decomp_list]}]
		set decomp_used($decomp) $val
		lappend decomp_info [expr {$val | ($decomp_compat($i) << 16)}]
		#puts "$val $decomp"
		foreach d $decomp {
		    lappend decomp_list $d
		}
	    }
	} else {
	    lappend decomp_info -1
	}

	if {$decomp_offset == $decomp_mask} {
	    addPage decomp_pmap decomp_pages $decomp_info
	    set decomp_info {}
	}


	set comp_offset [expr {$i & $comp_mask}]

	if {[info exists comp_info_map($i)]} {
	    set comp $comp_info_map($i)
	} else {
	    set comp -1
	}
	lappend comp_info $comp

	if {$comp_offset == $comp_mask} {
	    addPage comp_pmap comp_pages $comp_info
	    set comp_info {}
	}
    }

    #puts [array get decomp_map]
    #puts $decomp_list

    return
}

proc uni::main {} {
    global argc argv0 argv
    variable cclass_shift
    variable cclass_pmap
    variable cclass_pages
    variable decomp_shift
    variable decomp_pmap
    variable decomp_pages
    variable decomp_list
    variable comp_shift
    variable comp_map
    variable comp_pmap
    variable comp_pages
    variable comp_first_list
    variable comp_second_list
    variable comp_x_list
    variable comp_y_list
    variable pages
    variable groups {}
    variable titleCount

    if {$argc != 3} {
	puts stderr "\nusage: $argv0 <datafile> <exclusionsfile> <outdir>\n"
	exit 1
    }
    set f [open [lindex $argv 1] r]
    set data [read $f]
    close $f

    load_exclusions $data

    set f [open [lindex $argv 0] r]
    set data [read $f]
    close $f

    load_tables $data
    buildTables
    #puts "X = [llength $pMap]  Y= [llength $pages]  A= [llength $groups]"
    #set size [expr {[llength $pMap] + [llength $pages]*(1<<$shift)}]
    #puts "shift = 6, space = $size"
    #puts "title case count = $titleCount"

    set f [open [file join [lindex $argv 2] unicode_data.tcl] w]
    fconfigure $f -translation lf
    puts $f \
"# unicode_data.tcl --
#
#	Declarations of Unicode character information tables.  This file is
#	automatically generated by the gen_unicode_data.tcl script.  Do not
#	modify this file by hand.
#
# Copyright (c) 1998 Scriptics Corporation.
# Copyright (c) 2007 Alexey Shchepin
# Copyright (c) 2007 Sergei Golovan
#
# See the file \"license.terms\" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) \$Id\$

#
# A 16-bit Unicode character is split into two parts in order to index
# into the following tables.  The lower CCLASS_OFFSET_BITS comprise an offset
# into a page of characters.  The upper bits comprise the page number.
#

package provide unicode::data 1.0.0

namespace eval ::unicode::data {

set CCLASS_OFFSET_BITS $cclass_shift

#
# The cclassPageMap is indexed by page number and returns an alternate page number
# that identifies a unique page of characters.  Many Unicode characters map
# to the same alternate page number.
#

array unset cclassPageMap
array set cclassPageMap \[list \\"
    array unset tmp
    foreach idx $cclass_pmap {
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
    set last [expr {[llength $cclass_pmap] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set num [lindex $cclass_pmap $i]
	if {$num != $max_id} {
	    append line " $i $num"
	}
	if {[string length $line] > 70} {
	    puts $f "$line \\"
	    set line "   "
	}
    }
    puts $f "$line\]

set CCLASS_COMMON_PAGE_MAP $max_id

#
# The cclassGroupMap is indexed by combining the alternate page number with
# the page offset and returns a combining class number.
#

set cclassGroupMap \[list \\"
    set line "    "
    set lasti [expr {[llength $cclass_pages] - 1}]
    for {set i 0} {$i <= $lasti} {incr i} {
	set page [lindex $cclass_pages $i]
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

proc GetUniCharCClass {uc} {
    variable CCLASS_OFFSET_BITS
    variable CCLASS_COMMON_PAGE_MAP
    variable cclassPageMap
    variable cclassGroupMap

    set page \[expr {(\$uc & 0x1fffff) >> \$CCLASS_OFFSET_BITS}\]
    if {\[info exists cclassPageMap(\$page)\]} {
	set apage \$cclassPageMap(\$page)
    } else {
	set apage \$CCLASS_COMMON_PAGE_MAP
    }

    lindex \$cclassGroupMap \\
	   \[expr {(\$apage << \$CCLASS_OFFSET_BITS) | \\
		   (\$uc & ((1 << \$CCLASS_OFFSET_BITS) - 1))}\]
}


set DECOMP_OFFSET_BITS $decomp_shift

#
# The pageMap is indexed by page number and returns an alternate page number
# that identifies a unique page of characters.  Many Unicode characters map
# to the same alternate page number.
#

array unset decompPageMap
array set decompPageMap \[list \\"
    array unset tmp
    foreach idx $decomp_pmap {
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
    set last [expr {[llength $decomp_pmap] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set num [lindex $decomp_pmap $i]
	if {$num != $max_id} {
	    append line " $i $num"
	}
	if {[string length $line] > 70} {
	    puts $f "$line \\"
	    set line "   "
	}
    }
    puts $f "$line\]

set DECOMP_COMMON_PAGE_MAP $max_id

#
# The decompGroupMap is indexed by combining the alternate page number with
# the page offset and returns a group number that identifies a length and
# shift of decomposition sequence in decompList
#

set decompGroupMap \[list \\"
    set line "    "
    set lasti [expr {[llength $decomp_pages] - 1}]
    for {set i 0} {$i <= $lasti} {incr i} {
	set page [lindex $decomp_pages $i]
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
# List of decomposition sequences
#

set decompList \[list \\"
    set line "    "
    set last [expr {[llength $decomp_list] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set val [lindex $decomp_list $i]

	append line [format "%d" $val]
	if {$i != $last} {
	    append line " "
	}
	if {[string length $line] > 70} {
	    puts $f "$line\\"
	    set line "    "
	}
    }
    puts $f "$line\]

set DECOMP_COMPAT_MASK [expr {1 << 16}]
set DECOMP_INFO_BITS 17

#
# This macro extracts the information about a character from the
# Unicode character tables.
#

proc GetUniCharDecompCompatInfo {uc} {
    variable DECOMP_OFFSET_BITS
    variable DECOMP_COMMON_PAGE_MAP
    variable decompPageMap
    variable decompGroupMap

    set page \[expr {(\$uc & 0x1fffff) >> \$DECOMP_OFFSET_BITS}\]
    if {\[info exists decompPageMap(\$page)\]} {
	set apage \$decompPageMap(\$page)
    } else {
	set apage \$DECOMP_COMMON_PAGE_MAP
    }

    lindex \$decompGroupMap \\
	   \[expr {(\$apage << \$DECOMP_OFFSET_BITS) | \\
		   (\$uc & ((1 << \$DECOMP_OFFSET_BITS) - 1))}\]
}

proc GetUniCharDecompInfo {uc} {
    variable DECOMP_COMPAT_MASK

    set info \[GetUniCharDecompCompatInfo \$uc\]
    if {\$info & \$DECOMP_COMPAT_MASK} {
	return -1
    } else {
	return \$info
    }
}

proc GetDecompList {info} {
    variable DECOMP_INFO_BITS
    variable decompList

    set decomp_len \[expr {\$info >> \$DECOMP_INFO_BITS}\]
    set decomp_shift \[expr {\$info & ((1 << (\$DECOMP_INFO_BITS - 1)) - 1)}\]

    lrange \$decompList \$decomp_shift \[expr {\$decomp_shift + \$decomp_len - 1}\]
}

set COMP_OFFSET_BITS $comp_shift

#
# The pageMap is indexed by page number and returns an alternate page number
# that identifies a unique page of characters.  Many Unicode characters map
# to the same alternate page number.
#

array unset compPageMap
array set compPageMap \[list \\"
    array unset tmp
    foreach idx $comp_pmap {
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
    set last [expr {[llength $comp_pmap] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set num [lindex $comp_pmap $i]
	if {$num != $max_id} {
	    append line " $i $num"
	}
	if {[string length $line] > 70} {
	    puts $f "$line \\"
	    set line "   "
	}
    }
    puts $f "$line\]

set COMP_COMMON_PAGE_MAP $max_id

#
# The groupMap is indexed by combining the alternate page number with
# the page offset and returns a group number that identifies a unique
# set of character attributes.
#

set compGroupMap \[list \\"
    set line "    "
    set lasti [expr {[llength $comp_pages] - 1}]
    for {set i 0} {$i <= $lasti} {incr i} {
	set page [lindex $comp_pages $i]
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
# Lists of compositions for characters that appears only in one composition
#

set compFirstList \[list \\"
    set line "    "
    set last [expr {[llength $comp_first_list] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set val [lindex $comp_first_list $i]

	append line [format "{%d %d}" [lindex $val 0] [lindex $val 1]]
	if {$i != $last} {
	    append line " "
	}
	if {[string length $line] > 60} {
	    puts $f "$line\\"
	    set line "    "
	}
    }
    puts $f "$line\]

set compSecondList \[list \\"
    set line "    "
    set last [expr {[llength $comp_second_list] - 1}]
    for {set i 0} {$i <= $last} {incr i} {
	set val [lindex $comp_second_list $i]

	append line [format "{%d %d}" [lindex $val 0] [lindex $val 1]]
	if {$i != $last} {
	    append line " "
	}
	if {[string length $line] > 60} {
	    puts $f "$line\\"
	    set line "    "
	}
    }
    puts $f "$line\]

#
# Compositions matrix
#

array unset compBothMap
array set compBothMap \[list \\"
    set lastx [expr {[llength $comp_x_list] - 1}]
    set lasty [expr {[llength $comp_y_list] - 1}]
    set line "   "
    for {set i 0} {$i <= $lastx} {incr i} {
	for {set j 0} {$j <= $lasty} {incr j} {
	    set comp [list [lindex $comp_x_list $i] [lindex $comp_y_list $j]]
	    if {[info exists comp_map($comp)]} {
		append line " " [expr {$i*[llength $comp_x_list]+$j}] \
			    " " [format "%d" $comp_map($comp)]
	    }
	    if {[string length $line] > 70} {
		puts $f "$line \\"
		set line "   "
	    }
	}
    }
    puts $f "$line\]


proc GetUniCharCompInfo {uc} {
    variable COMP_OFFSET_BITS
    variable COMP_COMMON_PAGE_MAP
    variable compPageMap
    variable compGroupMap

    set page \[expr {(\$uc & 0x1fffff) >> \$COMP_OFFSET_BITS}\]
    if {\[info exists compPageMap(\$page)\]} {
	set apage \$compPageMap(\$page)
    } else {
	set apage \$COMP_COMMON_PAGE_MAP
    }

    lindex \$compGroupMap \\
	   \[expr {(\$apage << \$COMP_OFFSET_BITS) | \\
		   (\$uc & ((1 << \$COMP_OFFSET_BITS) - 1))}\]
}

set COMP_SINGLE_MASK [expr {1 << 16}]
set COMP_SECOND_MASK [expr {1 << 17}]
set COMP_MASK [expr {(1 << 16) - 1}]
set COMP_LENGTH1 [llength $comp_x_list]

proc GetCompFirst {uc info} {
    variable COMP_SINGLE_MASK
    variable COMP_SECOND_MASK
    variable COMP_MASK
    variable compFirstList

    if {\$info == -1 || !(\$info & \$COMP_SINGLE_MASK)} {
	return -1
    }
    if {!(\$info & \$COMP_SECOND_MASK)} {
	set comp \[lindex \$compFirstList \[expr {\$info & \$COMP_MASK}\]\]
	if {\$uc == \[lindex \$comp 0\]} {
	    return \[lindex \$comp 1\]
	}
    }
    return 0
}

proc GetCompSecond {uc info} {
    variable COMP_SINGLE_MASK
    variable COMP_SECOND_MASK
    variable COMP_MASK
    variable compSecondList

    if {\$info == -1 || !(\$info & \$COMP_SINGLE_MASK)} {
	return -1
    }
    if {\$info & \$COMP_SECOND_MASK} {
	set comp \[lindex \$compSecondList \[expr {\$info & \$COMP_MASK}\]\]
	if {\$uc == \[lindex \$comp 0\]} {
	    return \[lindex \$comp 1\]
	}
    }
    return 0
}

proc GetCompBoth {info1 info2} {
    variable COMP_SECOND_MASK
    variable COMP_MASK
    variable COMP_LENGTH1
    variable compBothMap

    if {\$info1 != -1 && \$info2 != -1 && \
       !(\$info1 & \$COMP_SECOND_MASK) && (\$info2 & \$COMP_SECOND_MASK)} {
	set idx \[expr {\$COMP_LENGTH1 * \$info1 + (\$info2 & \$COMP_MASK)}\]
	if {\[info exists compBothMap(\$idx)\]} {
	    return \$compBothMap(\$idx)
	} else {
	    return 0
	}
    } else {
	return 0
    }
}

} ; # namespace eval ::unicode::data
"

    close $f
}

uni::main

return
