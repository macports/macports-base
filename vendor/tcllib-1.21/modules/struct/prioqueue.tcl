# prioqueue.tcl --
#
#  Priority Queue implementation for Tcl.
#
# adapted from queue.tcl
# Copyright (c) 2002,2003 Michael Schlenker
# Copyright (c) 2008 Alejandro Paz <vidriloco@gmail.com>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: prioqueue.tcl,v 1.10 2008/09/04 04:35:02 andreas_kupries Exp $

package require Tcl 8.2

namespace eval ::struct {}

namespace eval ::struct::prioqueue {
    # The queues array holds all of the queues you've made
    variable queues

    # counter is used to give a unique name for unnamed queues
    variable counter 0

    # commands is the list of subcommands recognized by the queue
    variable commands [list \
        "clear" \
        "destroy"   \
        "get"   \
        "peek"  \
        "put"   \
        "remove" \
        "size"  \
        "peekpriority" \
        ]

    variable sortopt [list \
        "-integer" \
        "-real" \
        "-ascii" \
        "-dictionary" \
        ]

    # this is a simple design decision, that integer and real
    # are sorted decreasing (-1), and -ascii and -dictionary are sorted -increasing (1)
    # the values here map to the sortopt list
    # could be changed to something configurable.
    variable sortdir [list \
        "-1" \
        "-1" \
        "1" \
        "1" \
        ]



    # Only export one command, the one used to instantiate a new queue
    namespace export prioqueue

    proc K {x y} {set x} ;# DKF's K combinator
}

# ::struct::prioqueue::prioqueue --
#
#   Create a new prioqueue with a given name; if no name is given, use
#   prioqueueX, where X is a number.
#
# Arguments:
#   sorting sorting option for lsort to use, no -command option
#           defaults to integer
#   name    name of the queue; if null, generate one.
#           names may not begin with -
#
#
# Results:
#   name    name of the queue created

proc ::struct::prioqueue::prioqueue {args} {
    variable queues
    variable counter
    variable queues_sorting
    variable sortopt

    # check args
    if {[llength $args] > 2} {
        error "wrong # args: should be \"[lindex [info level 0] 0] ?-ascii|-dictionary|-integer|-real? ?name?\""
    }
    if {[llength $args] == 0} {
        # defaulting to integer priorities
        set sorting -integer
    } else {
        if {[llength $args] == 1} {
            if {[string match "-*" [lindex $args 0]]==1} {
                set sorting [lindex $args 0]
            } else {
                set sorting -integer
                set name [lindex $args 0]
            }
        } else {
            if {[llength $args] == 2} {
                foreach {sorting name} $args {break}
            }
        }
    }
    # check option (like lsort sorting options without -command)
    if {[lsearch $sortopt $sorting] == -1} {
        # if sortoption is unknown, but name is a sortoption we give a better error message
        if {[info exists name] && [lsearch $sortopt $name]!=-1} {
            error "wrong argument position: should be \"[lindex [info level 0] 0] ?-ascii|-dictionary|-integer|-real? ?name?\""
        }
        error "unknown sort option \"$sorting\""
    }
    # create name if not given
    if {![info exists name]} {
        incr counter
        set name "prioqueue${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
    error "command \"$name\" already exists, unable to create prioqueue"
    }

    # Initialize the queue as empty
    set queues($name) [list ]
    switch -exact -- $sorting {
    -integer { set queues_sorting($name) 0}
    -real    { set queues_sorting($name) 1}
    -ascii   { set queues_sorting($name) 2}
    -dictionary { set queues_sorting($name) 3}
    }

    # Create the command to manipulate the queue
    interp alias {} ::$name {} ::struct::prioqueue::QueueProc $name

    return $name
}

##########################
# Private functions follow

# ::struct::prioqueue::QueueProc --
#
#   Command that processes all queue object commands.
#
# Arguments:
#   name    name of the queue object to manipulate.
#   args    command name and args for the command
#
# Results:
#   Varies based on command to perform

proc ::struct::prioqueue::QueueProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
    error "wrong # args: should be \"$name option ?arg arg ...?\""
    }

    # Split the args into command and args components
    if { [string equal [info commands ::struct::prioqueue::_$cmd] ""] } {
    variable commands
    set optlist [join $commands ", "]
    set optlist [linsert $optlist "end-1" "or"]
    error "bad option \"$cmd\": must be $optlist"
    }
    return [eval [linsert $args 0 ::struct::prioqueue::_$cmd $name]]
}

# ::struct::prioqueue::_clear --
#
#   Clear a queue.
#
# Arguments:
#   name    name of the queue object.
#
# Results:
#   None.

proc ::struct::prioqueue::_clear {name} {
    variable queues
    set queues($name) [list]
    return
}

# ::struct::prioqueue::_destroy --
#
#   Destroy a queue object by removing it's storage space and
#   eliminating it's proc.
#
# Arguments:
#   name    name of the queue object.
#
# Results:
#   None.

proc ::struct::prioqueue::_destroy {name} {
    variable queues
    variable queues_sorting
    unset queues($name)
    unset queues_sorting($name)
    interp alias {} ::$name {}
    return
}

# ::struct::prioqueue::_get --
#
#   Get an item from a queue.
#
# Arguments:
#   name    name of the queue object.
#   count   number of items to get; defaults to 1
#
# Results:
#   item    first count items from the queue; if there are not enough
#           items in the queue, throws an error.
#

proc ::struct::prioqueue::_get {name {count 1}} {
    variable queues
    if { $count < 1 } {
    error "invalid item count $count"
    }

    if { $count > [llength $queues($name)] } {
    error "insufficient items in prioqueue to fill request"
    }

    if { $count == 1 } {
    # Handle this as a special case, so single item gets aren't listified
    set item [lindex [lindex $queues($name) 0] 1]
    set queues($name) [lreplace [K $queues($name) [set queues($name) ""]] 0 0]
    return $item
    }

    # Otherwise, return a list of items
    incr count -1
    set items [lrange $queues($name) 0 $count]
    foreach item $items {
        lappend result [lindex $item 1]
    }
    set items ""

    set queues($name) [lreplace [K $queues($name) [set queues($name) ""]] 0 $count]
    return $result
}

# ::struct::prioqueue::_peek --
#
#   Retrive the value of an item on the queue without removing it.
#
# Arguments:
#   name    name of the queue object.
#   count   number of items to peek; defaults to 1
#
# Results:
#   items   top count items from the queue; if there are not enough items
#       to fufill the request, throws an error.

proc ::struct::prioqueue::_peek {name {count 1}} {
    variable queues
    if { $count < 1 } {
    error "invalid item count $count"
    }

    if { $count > [llength $queues($name)] } {
    error "insufficient items in prioqueue to fill request"
    }

    if { $count == 1 } {
    # Handle this as a special case, so single item pops aren't listified
    return [lindex [lindex $queues($name) 0] 1]
    }

    # Otherwise, return a list of items
    set index [expr {$count - 1}]
    foreach item [lrange $queues($name) 0 $index] {
        lappend result [lindex $item 1]
    }
    return $result
}

# ::struct::prioqueue::_peekpriority --
#
#   Retrive the priority of an item on the queue without removing it.
#
# Arguments:
#   name    name of the queue object.
#   count   number of items to peek; defaults to 1
#
# Results:
#   items   top count items from the queue; if there are not enough items
#       to fufill the request, throws an error.

proc ::struct::prioqueue::_peekpriority {name {count 1}} {
    variable queues
    if { $count < 1 } {
    error "invalid item count $count"
    }

    if { $count > [llength $queues($name)] } {
    error "insufficient items in prioqueue to fill request"
    }

    if { $count == 1 } {
    # Handle this as a special case, so single item pops aren't listified
    return [lindex [lindex $queues($name) 0] 0]
    }

    # Otherwise, return a list of items
    set index [expr {$count - 1}]
    foreach item [lrange $queues($name) 0 $index] {
        lappend result [lindex $item 0]
    }
    return $result
}


# ::struct::prioqueue::_put --
#
#   Put an item into a queue.
#
# Arguments:
#   name    name of the queue object
#   args    list of the form "item1 prio1 item2 prio2 item3 prio3"
#
# Results:
#   None.

proc ::struct::prioqueue::_put {name args} {
    variable queues
    variable queues_sorting
    variable sortopt
    variable sortdir

    if { [llength $args] == 0 || [llength $args] % 2} {
    error "wrong # args: should be \"$name put item prio ?item prio ...?\""
    }

    # check for prio type before adding
    switch -exact -- $queues_sorting($name) {
        0    {
        foreach {item prio} $args {
        if {![string is integer -strict $prio]} {
            error "priority \"$prio\" is not an integer type value"
        }
        }
    }
        1    {
        foreach {item prio} $args {
        if {![string is double -strict $prio]} {
            error "priority \"$prio\" is not a real type value"
        }
        }
    }
        default {
        #no restrictions for -ascii and -dictionary
    }
    }

    # sort by priorities
    set opt [lindex $sortopt $queues_sorting($name)]
    set dir [lindex $sortdir $queues_sorting($name)]

    # add only if check has passed
    foreach {item prio} $args {
        set new [list $prio $item]
        set queues($name) [__linsertsorted [K $queues($name) [set queues($name) ""]] $new $opt $dir]
    }
    return
}

# ::struct::prioqueue::_remove --
#
#   Delete an item together with it's related priority value from the queue.
#
# Arguments:
#   name    name of the queue object
#   item    item to be removed
#
# Results:
#   None.

if {[package vcompare [package present Tcl] 8.5] < 0} {
    # 8.4-: We have -index option for lsearch, so we use glob to allow
    # us to create a pattern which can ignore the priority value. We
    # quote everything in the item to prevent it from being
    # glob-matched, exact matching is required.

    proc ::struct::prioqueue::_remove {name item} {
	variable queues
	set queuelist $queues($name)
	set itemrep "* \\[join [split $item {}] "\\"]"
	set foundat [lsearch -glob $queuelist $itemrep]

	# the item to remove was not found if foundat remains at -1,
	# nothing to replace then
	if {$foundat < 0} return
	set queues($name) [lreplace $queuelist $foundat $foundat]
	return
    }
} else {
    # 8.5+: We have the -index option, allowing us to exactly address
    # the column used to search.

    proc ::struct::prioqueue::_remove {name item} {
	variable queues
	set queuelist $queues($name)
	set foundat [lsearch -index 1 -exact $queuelist $item]

	# the item to remove was not found if foundat remains at -1,
	# nothing to replace then
	if {$foundat < 0} return
	set queues($name) [lreplace $queuelist $foundat $foundat]
	return
    }
}

# ::struct::prioqueue::_size --
#
#   Return the number of objects on a queue.
#
# Arguments:
#   name    name of the queue object.
#
# Results:
#   count   number of items on the queue.

proc ::struct::prioqueue::_size {name} {
    variable queues
    return [llength $queues($name)]
}

# ::struct::prioqueue::__linsertsorted
#
# Helper proc for inserting into a sorted list.
#
#

proc ::struct::prioqueue::__linsertsorted {list newElement sortopt sortdir} {
    
    set cmpcmd __elementcompare${sortopt}
    set pos -1
    set newPrio [lindex $newElement 0]

    # do a binary search
    set lower -1
    set upper [llength $list]
    set bound [expr {$upper+1}]
    set pivot 0
    
    if {$upper > 0} {
        while {$lower +1 != $upper } {
           
           # get the pivot element
           set pivot [expr {($lower + $upper) / 2}]
           set element [lindex $list $pivot]
        set prio [lindex $element 0]
           
           # check
           set test [$cmpcmd $prio $newPrio $sortdir]
           if {$test == 0} {
                set pos $pivot
                set upper $pivot
                # now break as we need the last item
                break
           } elseif {$test > 0 } {
                # search lower section
                set upper $pivot
                set bound $upper
                set pos -1
           } else {
                # search upper section
                set lower $pivot
                set pos $bound
           }
        }
        
        
        if {$pos == -1} {
            # we do an insert before the pivot element
            set pos $pivot
        }
        
        # loop to the last matching element to 
        # keep a stable insertion order
        while {[$cmpcmd $prio $newPrio $sortdir]==0} {
        incr pos
            if {$pos > [llength $list]} {break}
            set element [lindex $list $pos]
            set prio [lindex $element 0]
        }            
        
    } else {
        set pos 0
    }
    
    # do the insert without copying
    linsert [K $list [set list ""]] $pos $newElement
}

# ::struct::prioqueue::__elementcompare
#
# Compare helpers with the sort options.
#
#

proc ::struct::prioqueue::__elementcompare-integer {prio newPrio sortdir} {
    return [expr {$prio < $newPrio ? -1*$sortdir : ($prio != $newPrio)*$sortdir}]
}

proc ::struct::prioqueue::__elementcompare-real {prio newPrio sortdir} {
    return [expr {$prio < $newPrio ? -1*$sortdir : ($prio != $newPrio)*$sortdir}] 
}

proc ::struct::prioqueue::__elementcompare-ascii {prio newPrio sortdir} {
    return [expr {[string compare $prio $newPrio]*$sortdir}]
}

proc ::struct::prioqueue::__elementcompare-dictionary {prio newPrio sortdir} {
    # need to use lsort to access -dictionary sorting
    set tlist [lsort -increasing -dictionary [list $prio $newPrio]]
    set e1 [string equal [lindex $tlist 0]  $prio]
    set e2 [string equal [lindex $tlist 1]  $prio]    
    return [expr {$e1 > $e2 ? -1*$sortdir : ($e1 != $e2)*$sortdir}]
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'prioqueue::prioqueue' into the general structure namespace.
    namespace import -force prioqueue::prioqueue
    namespace export prioqueue
}

package provide struct::prioqueue 1.4
