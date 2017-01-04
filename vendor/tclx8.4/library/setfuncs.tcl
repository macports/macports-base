#
# setfuncs --
#
# Perform set functions on lists.  Also has a procedure for removing duplicate
# list entries.
#------------------------------------------------------------------------------
# Copyright 1992-1999 Karl Lehenbauer and Mark Diekhans.
#
# Permission to use, copy, modify, and distribute this software and its
# documentation for any purpose and without fee is hereby granted, provided
# that the above copyright notice appear in all copies.  Karl Lehenbauer and
# Mark Diekhans make no representations about the suitability of this
# software for any purpose.  It is provided "as is" without express or
# implied warranty.
#------------------------------------------------------------------------------
# $Id: setfuncs.tcl,v 1.1 2001/10/24 23:31:48 hobbs Exp $
#------------------------------------------------------------------------------
#

#@package: TclX-set_functions union intersect intersect3 lrmdups

#
# return the logical union of two lists, removing any duplicates
#
proc union {lista listb} {
    return [lrmdups [concat $lista $listb]]
}

#
# sort a list, returning the sorted version minus any duplicates
#
proc lrmdups list {
    if [lempty $list] {
        return {}
    }
    set list [lsort $list]
    set last [lvarpop list]
    lappend result $last
    foreach element $list {
	if ![cequal $last $element] {
	    lappend result $element
	    set last $element
	}
    }
    return $result
}

#
# intersect3 - perform the intersecting of two lists, returning a list
# containing three lists.  The first list is everything in the first
# list that wasn't in the second, the second list contains the intersection
# of the two lists, the third list contains everything in the second list
# that wasn't in the first.
#

proc intersect3 {list1 list2} {
    set la1(0) {} ; unset la1(0)
    set lai(0) {} ; unset lai(0)
    set la2(0) {} ; unset la2(0)
    foreach v $list1 {
        set la1($v) {}
    }
    foreach v $list2 {
        set la2($v) {}
    }
    foreach elem [concat $list1 $list2] {
        if {[info exists la1($elem)] && [info exists la2($elem)]} {
            unset la1($elem)
            unset la2($elem)
            set lai($elem) {}
        }
    }
    list [lsort [array names la1]] [lsort [array names lai]] \
         [lsort [array names la2]]
}

#
# intersect - perform an intersection of two lists, returning a list
# containing every element that was present in both lists
#
proc intersect {list1 list2} {
    set intersectList ""

    set list1 [lsort $list1]
    set list2 [lsort $list2]

    while {1} {
        if {[lempty $list1] || [lempty $list2]} break

        set compareResult [string compare [lindex $list1 0] [lindex $list2 0]]

        if {$compareResult < 0} {
            lvarpop list1
            continue
        }

        if {$compareResult > 0} {
            lvarpop list2
            continue
        }

        lappend intersectList [lvarpop list1]
        lvarpop list2
    }
    return $intersectList
}




