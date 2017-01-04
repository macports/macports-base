# disjointset.tcl --
#
#  Implementation of a Disjoint Set for Tcl.
#
# Copyright (c) Google Summer of Code 2008 Alejandro Eduardo Cruz Paz
# Copyright (c) 2008 Andreas Kupries (API redesign and simplification)

package require Tcl 8.2
package require struct::set

# Initialize the disjointset structure namespace. Note that any
# missing parent namespace (::struct) will be automatically created as
# well.
namespace eval ::struct::disjointset {
    # Counter for naming disjoint sets without a given name
    variable counter 0

    # Only export one command, the one used to instantiate a new
    # disjoint set
    namespace export disjointset
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
    variable counter

    # Derived from the constructor of struct::queue, see file
    # "queue_tcl.tcl". Create name of not specified.
    switch -exact -- [llength [info level 0]] {
	1 {
	    # Missing name, generate one.
	    incr counter
	    set name "disjointset${counter}"
	}
	2 {
	    # Standard call. New empty disjoint set.
	    set name [lindex $args 0]
	}
	default {
	    # Error.
	    return -code error \
		"wrong # args: should be \"::struct::disjointset ?name?\""
	}
    }

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 [list namespace current]]
        if {"::" != $ns} {
            append ns "::"
        }
        set name "$ns$name"
    }

    # Done after qualification so that we have a canonical name and
    # know exactly what we are looking for.
    if {[llength [info commands $name]]} {
	return -code error \
	    "command \"$name\" already exists, unable to create disjointset"
    }


    # This is the structure where each disjoint set will be kept. A
    # namespace containing a list/set of the partitions, and a set of
    # all elements (for quick testing of validity when adding
    # partitions.).

    namespace eval $name {
	variable partitions {} ; # Set of partitions.
	variable all        {} ; # Set of all elements.
    }

    # Create the command to manipulate the DisjointSet
    interp alias {} ::$name {} ::struct::disjointset::DisjointSetProc $name
    return $name
}

##########################
# Private functions follow

# ::struct::disjointset::DisjointSetProc --
#
#	Command that processes all disjointset object commands.
#
# Arguments:
#	name	Name of the disjointset object to manipulate.
#	cmd	Subcommand to invoke.
#	args	Arguments for subcommand.
#
# Results:
#	Varies based on command to perform

proc ::struct::disjointset::DisjointSetProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }

    # Derived from the struct::queue dispatcher (see queue_tcl.tcl).
    # Gets rid of the explicit list of commands. Slower in case of an
    # error, considered acceptable, as errors should not happen, or
    # only seldomly.

    set sub _$cmd
    if { ![llength [info commands ::struct::disjointset::$sub]]} {
	set optlist [lsort [info commands ::struct::disjointset::_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 1 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }

    # Run the method in the same context as the dispatcher.
    return [uplevel 1 [linsert $args 0 ::struct::disjointset::_$cmd $name]]
}

# ::struct::disjointset::_add-partition
#
#	Creates a new partition in the disjoint set structure,
#	verifying the integrity of each new insertion for previous
#	existence in the structure.
#
# Arguments:
#	name	The name of the actual disjoint set structure
#	items	A set of elements to add to the set as a new partition.
#
# Results:
#	A new partition is added to the disjoint set.  If the disjoint
#	set already included any of the elements in any of its
#	partitions an error will be thrown.

proc ::struct::disjointset::_add-partition {name items} {
    variable ${name}::partitions
    variable ${name}::all

    # Validate that one of the elements to be added are already known.
    foreach element $items {
	if {[struct::set contains $all $element]} {
	    return -code error \
		"The element \"$element\" is already known to the disjoint set $name"
	}
    }

    struct::set add all $items
    lappend partitions  $items
    return
}

# ::struct::disjointset::_partitions
#
#	Retrieves the set of partitions the disjoint set consists of.
#
# Arguments:
#	name	The name of the disjoint set.
#
# Results:
#	A set of the partitions contained in the disjoint set.
#	If the disjoint set has no partitions the returned set
#       will be empty.

proc ::struct::disjointset::_partitions {name} {
    variable ${name}::partitions
    return $partitions
}

# ::struct::disjointset::_num-partitions
#
#	Retrieves the number of partitions the disjoint set consists of.
#
# Arguments:
#	name	The name of the disjoint set.
#
# Results:
#	The number of partitions contained in the disjoint set.

proc ::struct::disjointset::_num-partitions {name} {
    variable ${name}::partitions
    return [llength $partitions]
}

# ::struct::disjointset::_equal
#
#	Determines if the two elements belong to the same partition
#	of the disjoint set. Throws an error if either element does
#	not belong to the disjoint set at all.
#
# Arguments:
#	name	The name of the disjoint set.
#	a	The first element to be compared
#	b	The second element set to be compared
#
# Results:
#	The result of the comparison, a boolean flag.
#	True if the element are in the same partition, and False otherwise.

proc ::struct::disjointset::_equal {name a b} {
    CheckValidity $name $a
    CheckValidity $name $b
    return [expr {[FindIndex $name $a] == [FindIndex $name $b]}]
}

# ::struct::disjointset::_merge
#
#	Determines the partitions the two elements belong to and
#	merges them, if they are not the same. An error is thrown
#	if either element does not belong to the disjoint set.
#
# Arguments:
#	name	The name of the actual disjoint set structure
#	a	1st item whose partition will be merged.
#	b	2nd item whose partition will be merged.
#
# Results:
#	An empty string.

proc ::struct::disjointset::_merge {name a b} {
    CheckValidity $name $a
    CheckValidity $name $b

    set a [FindIndex $name $a]
    set b [FindIndex $name $b]

    if {$a == $b} return

    variable ${name}::partitions

    set apart [lindex $partitions $a]
    set bpart [lindex $partitions $b]

    # Remove the higher partition first, otherwise the 2nd replace
    # will access the wrong element.
    if {$b > $a} { set t $a ; set a $b ; set b $t }

    set partitions [linsert \
			[lreplace [lreplace [K $partitions [unset partitions]] \
				       $a $a] $b $b] \
			end [struct::set union $apart $bpart]]
    return
}

# ::struct::disjointset::_find
#
#	Determines and returns the partition the element belongs to.
#	Returns an empty partition if the element does not belong to
#	the disjoint set.
#
# Arguments:
#	name	The name of the disjoint set.
#	item	The element to be searched.
#
# Results:
#	Returns the partition containing the element, or an empty
#	partition if the item is not present.

proc ::struct::disjointset::_find {name item} {
    variable ${name}::all
    if {![struct::set contains $all $item]} {
	return {}
    } else {
	variable ${name}::partitions
	return [lindex $partitions [FindIndex $name $item]]
    }
}

proc ::struct::disjointset::FindIndex {name item} {
    variable ${name}::partitions
    # Check each partition directly.
    # AK XXX Future Use a nested-tree structure to make the search
    # faster

    set i 0
    foreach p $partitions {
	if {[struct::set contains $p $item]} {
	    return $i
	}
	incr i
    }
    return -1
}

# ::struct::disjointset::_destroy
#
#	Destroy the disjoint set structure and releases all memory
#	associated with it.
#
# Arguments:
#	name	The name of the actual disjoint set structure

proc ::struct::disjointset::_destroy {name} {
    namespace delete $name
    interp alias {} ::$name {}
    return
}

# ### ### ### ######### ######### #########
## Internal helper

# ::struct::disjointset::CheckValidity
#
#	Verifies if the argument element is a member of the disjoint
#	set or not. Throws an error if not.
#
# Arguments:
#	name	The name of the disjoint set
#	element	The element to look for.
#
# Results:
#	1 if element is a unary list, 0 otherwise

proc ::struct::disjointset::CheckValidity {name element} {
    variable ${name}::all
    if {![struct::set contains $all $element]} {
	return -code error \
	    "The element \"$element\" is not known to the disjoint set $name"
    }
    return
}

proc ::struct::disjointset::K { x y } { set x }

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    namespace import -force disjointset::disjointset
    namespace export disjointset
}

package provide struct::disjointset 1.0
