# skiplist.tcl --
#
#	Implementation of a skiplist data structure for Tcl.
#
#	To quote the inventor of skip lists, William Pugh:
#		Skip lists are a probabilistic data structure that seem likely
#		to supplant balanced trees as the implementation method of
#		choice for many applications. Skip list algorithms have the
#		same asymptotic expected time bounds as balanced trees and are
#		simpler, faster and use less space.
#
#	For more details on how skip lists work, see Pugh, William. Skip
#	lists: a probabilistic alternative to balanced trees in
#	Communications of the ACM, June 1990, 33(6) 668-676. Also, see
#	ftp://ftp.cs.umd.edu/pub/skipLists/
# 
# Copyright (c) 2000 by Keith Vetter
# This software is licensed under a BSD license as described in tcl/tk
# license.txt file but with the copyright held by Keith Vetter.
#
# TODO:
#	customize key comparison to a user supplied routine

namespace eval ::struct {}

namespace eval ::struct::skiplist {
    # Data storage in the skiplist module
    # -------------------------------
    #
    # For each skiplist, we have the following arrays
    #   state - holds the current level plus some magic constants
    #	nodes - all the nodes in the skiplist, including a dummy header node
    
    # counter is used to give a unique name for unnamed skiplists
    variable counter 0

    # Internal constants
    variable MAXLEVEL 16
    variable PROB .5
    variable MAXINT [expr {0x7FFFFFFF}]

    # commands is the list of subcommands recognized by the skiplist
    variable commands [list \
	    "destroy"	\
	    "delete"	\
	    "insert"	\
	    "search"	\
	    "size"	\
	    "walk"	\
	    ]

    # State variables that can be set in the instantiation
    variable vars [list maxlevel probability]
    
    # Only export one command, the one used to instantiate a new skiplist
    namespace export skiplist
}

# ::struct::skiplist::skiplist --
#
#	Create a new skiplist with a given name; if no name is given, use
#	skiplistX, where X is a number.
#
# Arguments:
#	name	name of the skiplist; if null, generate one.
#
# Results:
#	name	name of the skiplist created

proc ::struct::skiplist::skiplist {{name ""} args} {
    set usage "skiplist name ?-maxlevel ##? ?-probability ##?"
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "skiplist${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
	error "command \"$name\" already exists, unable to create skiplist"
    }

    # Handle the optional arguments
    set more_eval ""
    for {set i 0} {$i < [llength $args]} {incr i} {
	set flag [lindex $args $i]
	incr i
	if { $i >= [llength $args] } {
	    error "value for \"$flag\" missing: should be \"$usage\""
	}
	set value [lindex $args $i]
	switch -glob -- $flag {
	    "-maxl*" {
		set n [catch {set value [expr $value]}]
		if {$n || $value <= 0} {
		    error "value for the maxlevel option must be greater than 0"
		}
		append more_eval "; set state(maxlevel) $value"
	    }
	    "-prob*" {
		set n [catch {set value [expr $value]}]
		if {$n || $value <= 0 || $value >= 1} {
		    error "probability must be between 0 and 1"
		}
		append more_eval "; set state(prob) $value"
	    }
	    default {
		error "unknown option \"$flag\": should be \"$usage\""
	    }
	}
    }
    
    # Set up the namespace for this skiplist
    namespace eval ::struct::skiplist::skiplist$name {
	variable state
	variable nodes

	# NB. maxlevel and prob may be overridden by $more_eval at the end
	set state(maxlevel) $::struct::skiplist::MAXLEVEL
	set state(prob) $::struct::skiplist::PROB
	set state(level) 1
	set state(cnt) 0
	set state(size) 0

	set nodes(nil,key) $::struct::skiplist::MAXINT
	set nodes(header,key) "---"
	set nodes(header,value) "---"

	for {set i 1} {$i < $state(maxlevel)} {incr i} {
	    set nodes(header,$i) nil
	}
    } $more_eval

    # Create the command to manipulate the skiplist
    interp alias {} ::$name {} ::struct::skiplist::SkiplistProc $name

    return $name
}

###########################
# Private functions follow

# ::struct::skiplist::SkiplistProc --
#
#	Command that processes all skiplist object commands.
#
# Arguments:
#	name	name of the skiplist object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::struct::skiplist::SkiplistProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    if { [llength [info commands ::struct::skiplist::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	error "bad option \"$cmd\": must be $optlist"
    }
    eval [linsert $args 0 ::struct::skiplist::_$cmd $name]
}

## ::struct::skiplist::_destroy --
#
#	Destroy a skiplist, including its associated command and data storage.
#
# Arguments:
#	name	name of the skiplist.
#
# Results:
#	None.

proc ::struct::skiplist::_destroy {name} {
    namespace delete ::struct::skiplist::skiplist$name
    interp alias {} ::$name {}
}

# ::struct::skiplist::_search --
#
#	Searches for a key in a skiplist
#
# Arguments:
#	name		name of the skiplist.
#	key		key for the node to search for
#
# Results:
#	0 if not found
#	[list 1 node_value] if found

proc ::struct::skiplist::_search {name key} {
    upvar ::struct::skiplist::skiplist${name}::state state
    upvar ::struct::skiplist::skiplist${name}::nodes nodes

    set x header
    for {set i $state(level)} {$i >= 1} {incr i -1} {
	while {1} {
	    set fwd $nodes($x,$i)
	    if {$nodes($fwd,key) == $::struct::skiplist::MAXINT} break
	    if {$nodes($fwd,key) >= $key} break
	    set x $fwd
	}
    }
    set x $nodes($x,1)
    if {$nodes($x,key) == $key} {
	return [list 1 $nodes($x,value)]
    }
    return 0
}

# ::struct::skiplist::_insert --
#
#	Add a node to a skiplist.
#
# Arguments:
#	name		name of the skiplist.
#	key		key for the node to insert
#	value		value of the node to insert
#
# Results:
#	0      if new node was created
#       level  if existing node was updated

proc ::struct::skiplist::_insert {name key value} {
    upvar ::struct::skiplist::skiplist${name}::state state
    upvar ::struct::skiplist::skiplist${name}::nodes nodes
    
    set x header
    for {set i $state(level)} {$i >= 1} {incr i -1} {
	while {1} {
	    set fwd $nodes($x,$i)
	    if {$nodes($fwd,key) == $::struct::skiplist::MAXINT} break
	    if {$nodes($fwd,key) >= $key} break
	    set x $fwd
	}
	set update($i) $x
    }
    set x $nodes($x,1)

    # Does the node already exist?
    if {$nodes($x,key) == $key} {
	set nodes($x,value) $value
	return 0
    }

    # Here to insert item
    incr state(size)
    set lvl [randomLevel $state(prob) $state(level) $state(maxlevel)]

    # Did the skip list level increase???
    if {$lvl > $state(level)} {
	for {set i [expr {$state(level) + 1}]} {$i <= $lvl} {incr i} {
	    set update($i) header
	}
	set state(level) $lvl
    }

    # Create a unique new node name and fill in the key, value parts
    set x [incr state(cnt)] 
    set nodes($x,key) $key
    set nodes($x,value) $value

    for {set i 1} {$i <= $lvl} {incr i} {
	set nodes($x,$i) $nodes($update($i),$i)
	set nodes($update($i),$i) $x
    }

    return $lvl
}

# ::struct::skiplist::_delete --
#
#	Deletes a node from a skiplist
#
# Arguments:
#	name		name of the skiplist.
#	key		key for the node to delete
#
# Results:
#	1 if we deleted a node
#       0 otherwise

proc ::struct::skiplist::_delete {name key} {
    upvar ::struct::skiplist::skiplist${name}::state state
    upvar ::struct::skiplist::skiplist${name}::nodes nodes
    
    set x header
    for {set i $state(level)} {$i >= 1} {incr i -1} {
	while {1} {
	    set fwd $nodes($x,$i)
	    if {$nodes($fwd,key) >= $key} break
	    set x $fwd
	}
	set update($i) $x
    }
    set x $nodes($x,1)

    # Did we find a node to delete?
    if {$nodes($x,key) != $key} {
	return 0
    }
    
    # Here when we found a node to delete
    incr state(size) -1
    
    # Unlink this node from all the linked lists that include to it
    for {set i 1} {$i <= $state(level)} {incr i} {
	set fwd $nodes($update($i),$i)
	if {$nodes($fwd,key) != $key} break
	set nodes($update($i),$i) $nodes($x,$i)
    }
    
    # Delete all traces of this node
    foreach v [array names nodes($x,*)] {
	unset nodes($v)
    }

    # Fix up the level in case it went down
    while {$state(level) > 1} {
	if {! [string equal "nil" $nodes(header,$state(level))]} break
	incr state(level) -1
    }

    return 1
}

# ::struct::skiplist::_size --
#
#	Returns how many nodes are in the skiplist
#
# Arguments:
#	name		name of the skiplist.
#
# Results:
#	number of nodes in the skiplist

proc ::struct::skiplist::_size {name} {
    upvar ::struct::skiplist::skiplist${name}::state state

    return $state(size)
}

# ::struct::skiplist::_walk --
#
#	Walks a skiplist performing a specified command on each node.
#	Command is executed at the global level with the actual command
#	executed is:  command key value
#
# Arguments:
#	name	name of the skiplist.
#	cmd		command to run on each node
#
# Results:
#	none.

proc ::struct::skiplist::_walk {name cmd} {
    upvar ::struct::skiplist::skiplist${name}::nodes nodes

    for {set x $nodes(header,1)} {$x != "nil"} {set x $nodes($x,1)} {
	# Evaluate the command at this node
	set cmdcpy $cmd
	lappend cmdcpy $nodes($x,key) $nodes($x,value)
	uplevel 2 $cmdcpy
    }
}

# ::struct::skiplist::randomLevel --
#
#	Generates a random level for a new node. We limit it to 1 greater
#	than the current level. 
#
# Arguments:
#	prob		probability to use in generating level
#	level		current biggest level
#	maxlevel	biggest possible level
#
# Results:
#	an integer between 1 and $maxlevel

proc ::struct::skiplist::randomLevel {prob level maxlevel} {

    set lvl 1
    while {(rand() < $prob) && ($lvl < $maxlevel)} {
	incr lvl
    }

    if {$lvl > $level} {
	set lvl [expr {$level + 1}]
    }
    
    return $lvl
}

# ::struct::skiplist::_dump --
#
#	Dumps out a skip list. Useful for debugging.
#
# Arguments:
#	name	name of the skiplist.
#
# Results:
#	none.

proc ::struct::skiplist::_dump {name} {
    upvar ::struct::skiplist::skiplist${name}::state state
    upvar ::struct::skiplist::skiplist${name}::nodes nodes


    puts "Current level $state(level)"
    puts "Maxlevel:     $state(maxlevel)"
    puts "Probability:  $state(prob)"
    puts ""
    puts "NODE    KEY  FORWARD"
    for {set x header} {$x != "nil"} {set x $nodes($x,1)} {
	puts -nonewline [format "%-6s  %3s %4s" $x $nodes($x,key) $nodes($x,1)]
	for {set i 2} {[info exists nodes($x,$i)]} {incr i} {
	    puts -nonewline [format %4s $nodes($x,$i)]
	}
	puts ""
    }
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'skiplist::skiplist' into the general structure namespace.
    namespace import -force skiplist::skiplist
    namespace export skiplist
}
package provide struct::skiplist 1.3
