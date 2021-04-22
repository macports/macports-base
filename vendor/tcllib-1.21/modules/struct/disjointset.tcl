# disjointset.tcl --
#
#  Implementation of a Disjoint Set for Tcl.
#
# Copyright (c) Google Summer of Code 2008 Alejandro Eduardo Cruz Paz
# Copyright (c) 2008 Andreas Kupries (API redesign and simplification)
# Copyright (c) 2018 by Kevin B. Kenny - reworked to a proper disjoint-sets
# data structure, added 'add-element', 'exemplars' and 'find-exemplar'.

# References
#
# - General overview
#   - https://en.wikipedia.org/wiki/Disjoint-set_data_structure
#
# - Time/Complexity proofs
#   - https://dl.acm.org/citation.cfm?doid=62.2160
#   - https://dl.acm.org/citation.cfm?doid=364099.364331
#

package require Tcl 8.6

# Initialize the disjointset structure namespace. Note that any
# missing parent namespace (::struct) will be automatically created as
# well.
namespace eval ::struct::disjointset {

    # Only export one command, the one used to instantiate a new
    # disjoint set
    namespace export disjointset
}

# class struct::disjointset::_disjointset --
#
#	Implementation of a disjoint-sets data structure

oo::class create struct::disjointset::_disjointset {

    # elements - Dictionary whose keys are all the elements in the structure,
    #            and whose values are element numbers. 
    # tree     - List indexed by element number whose members are
    #            ordered triples consisting of the element's name,
    #            the element number of the element's parent (or the element's
    #            own index if the element is a root), and the rank of
    #		 the element.
    # nParts   - Number of partitions in the structure. Maintained only
    #            so that num_partitions will work.

    variable elements tree nParts

    constructor {} {
	set elements {}
	set tree {}
	set nParts 0
    }

    # add-element --
    #
    #	Adds an element to the structure
    #
    # Parameters:
    #	item - Name of the element to add
    #
    # Results:
    #	None.
    #
    # Side effects:
    #	Element is added

    method add-element {item} {
	if {[dict exists $elements $item]} {
	    return -code error \
		-errorcode [list STRUCT DISJOINTSET DUPLICATE $item [self]] \
		"The element \"$item\" is already known to the disjoint\
            	 set [self]"
	}
	set n [llength $tree]
	dict set elements $item $n
	lappend tree [list $item $n 0]
	incr nParts
	return
    }

    # add-partition --
    #
    #	Adds a collection of new elements to a disjoint-sets structure and
    #	makes them all one partition.
    #
    # Parameters:
    #	items - List of elements to add.
    #
    # Results:
    #	None.
    #
    # Side effects:
    #	Adds all the elements, and groups them into a single partition.

    method add-partition {items} {

	# Integrity check - make sure that none of the elements have yet
	# been added

	foreach name $items {
	    if {[dict exists $elements $name]} {
		return -code error \
		    -errorcode [list STRUCT DISJOINTSET DUPLICATE \
				    $name [self]] \
		    "The element \"$name\" is already known to the disjoint\
            	     set [self]"	      	 
	    }
	}

	# Add all the elements in one go, and establish parent links for all
	# but the first
	
	set first -1
	foreach n $items {
	    set idx [llength $tree]
	    dict set elements $n $idx
	    if {$first < 0} {
		set first $idx
		set rank 1
	    } else {
		set rank 0
	    }
	    lappend tree [list $n $first $rank]
	}
	incr nParts
	return
    }

    # equal --
    #
    #	Test if two elements belong to the same partition in a disjoint-sets
    #	data structure.
    #
    # Parameters:
    #	a - Name of the first element
    #	b - Name of the second element
    #
    # Results:
    #	Returns 1 if the elements are in the same partition, and 0 otherwise.

    method equal {a b} {
	expr {[my FindNum $a] == [my FindNum $b]}
    }

    # exemplars --
    #
    #	Find one representative element for each partition in a disjoint-sets
    #	data structure.
    #
    # Results:
    #	Returns a list of element names

    method exemplars {} {
	set result {}
	set n -1
	foreach row $tree {
	    if {[lindex $row 1] == [incr n]} {
		lappend result [lindex $row 0]
	    }
	}
	return $result
    }

    # find --
    #
    #	Find the partition to which a given element belongs.
    #
    # Parameters:
    #	item - Item to find
    #
    # Results:
    #	Returns a list of the partition's members
    #
    # Notes:
    #	This operation takes time proportional to the total number of elements
    #	in the disjoint-sets structure. If a simple name of the partition
    #	is all that is required, use "find-exemplar" instead, which runs
    #	in amortized time proportional to the inverse Ackermann function of
    #	the size of the partition.

    method find {item} {
	set result {}
	# No error on a nonexistent item
	if {![dict exists $elements $item]} {
	    return {}
	}
	set pnum [my FindNum $item]
	set n -1
	foreach row $tree {
	    if {[my FindByNum [incr n]] eq $pnum} {
		lappend result [lindex $row 0]
	    }
	}
	return $result
    }

    # find-exemplar --
    #
    #	Find a representative element of the partition that contains a given
    #	element.
    #
    # parameters:
    #	item - Item to examine
    #
    # Results:
    #	Returns the exemplar
    #
    # Notes:
    #	Takes O(alpha(|P|)) amortized time, where |P| is the size of the
    #	partition, and alpha is the inverse Ackermann function

    method find-exemplar {item} {
	return [lindex $tree [my FindNum $item] 0]
    }
    
    # merge --
    #
    #	Merges the partitions that two elements are in.
    #
    # Results:
    #	None.

    method merge {a b} {
	my MergeByNum [my FindNum $a] [my FindNum $b]
    }

    # num-partitions --
    #
    #	Counts the partitions of a disjoint-sets data structure
    #
    # Results:
    #	Returns the partition count.

    method num-partitions {} {
	return $nParts
    }
    
    # partitions --
    #
    #	Enumerates the partitions of a disjoint-sets data structure
    #
    # Results:
    #	Returns a list of lists. Each list is one of the partitions
    #	in the disjoint set, and each member of the sublist is one
    #	of the elements added to the structure.

    method partitions {} {

	# Find the partition number for each element, and accumulate a
	# list per partition
	set parts {}
	dict for {element eltNo} $elements {
	    set partNo [my FindByNum $eltNo]
	    dict lappend parts $partNo $element
	}
	return [dict values $parts]
    }

    # FindNum --
    #
    #	Finds the partition number for an element.
    #
    # Parameters:
    #	item - Item to look up
    #
    # Results:
    #	Returns the partition number

    method FindNum {item} {
	if {![dict exists $elements $item]} {
	    return -code error \
		-errorcode [list STRUCT DISJOINTSET NOTFOUND $item [self]] \
		"The element \"$item\" is not known to the disjoint\
                 set [self]"	  
	}
	return [my FindByNum [dict get $elements $item]]
    }

    # FindByNum --
    #
    #	Finds the partition number for an element, given the element's
    #	index
    #
    # Parameters:
    #	idx - Index of the item to look up
    #
    # Results:
    #	Returns the partition number
    #
    # Side effects:
    #	Performs path splitting

    method FindByNum {idx} {
	while {1} {
	    set parent [lindex $tree $idx 1]
	    if {$parent == $idx} {
		return $idx
	    }
	    set prev $idx
	    set idx $parent
	    lset tree $prev 1 [lindex $tree $idx 1]
	}
    }

    # MergeByNum --
    #
    #	Merges two partitions in a disjoint-sets data structure
    #
    # Parameters:
    #	x - Index of an element in the first partition
    #	y - Index of an element in the second partition
    #
    # Results:
    #	None
    #
    # Side effects:
    #	Merges the partition of the lower rank into the one of the
    #	higher rank.

    method MergeByNum {x y} {
	set xroot [my FindByNum $x]
	set yroot [my FindByNum $y]

	if {$xroot == $yroot} {
	    # The elements are already in the same partition
	    return
	}

	incr nParts -1

	# Make xroot the taller tree
	if {[lindex $tree $xroot 2] < [lindex $tree $yroot 2]} {
	    set t $xroot; set xroot $yroot; set yroot $t
	}

	# Merge yroot into xroot
	set xrank [lindex $tree $xroot 2]
	set yrank [lindex $tree $yroot 2]
	lset tree $yroot 1 $xroot
	if {$xrank == $yrank} {
	    lset tree $xroot 2 [expr {$xrank + 1}]
	}
    }
}

# ::struct::disjointset::disjointset --
#
#	Create a new disjoint set with a given name; if no name is
#	given, use disjointsetX, where X is a number.
#
# Arguments:
#	name	Optional name of the disjoint set; if not specified, generate one.
#
# Results:
#	name	Name of the disjoint set created

proc ::struct::disjointset::disjointset {args} {

    switch -exact -- [llength $args] {
	0 {
	    return [_disjointset new]
	}
	1 {
	    # Name supplied by user
	    return [uplevel 1 [list [namespace which _disjointset] \
				   create [lindex $args 0]]]
	}
	default {
	    # Too many args
	    return -code error \
		-errorcode {TCL WRONGARGS} \
		"wrong # args: should be \"[lindex [info level 0] 0] ?name?\""
	}
    }
}

namespace eval ::struct {
    namespace import disjointset::disjointset
    namespace export disjointset
}

package provide struct::disjointset 1.1
return
