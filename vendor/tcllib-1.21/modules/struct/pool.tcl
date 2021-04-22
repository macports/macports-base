################################################################################
# pool.tcl
#
#
# Author: Erik Leunissen
#
#
# Acknowledgement:
#     The author is grateful for the advice provided by
#     Andreas Kupries during the development of this code.
#
################################################################################

package require cmdline

namespace eval ::struct {}
namespace eval ::struct::pool {

    # a list of all current pool names
    variable pools {}

    # counter is used to give a unique name to a pool if
    # no name was supplied, e.g. pool1, pool2 etc.
    variable counter 0

    # `commands' is the list of subcommands recognized by a pool-object command
    variable commands {add clear destroy info maxsize release remove request}

    # All errors with corresponding (unformatted) messages.
    # The format strings will be replaced by the appropriate
    # values when an error occurs.
    variable  Errors
    array set Errors {
	BAD_SUBCMD             {Bad subcommand "%s": must be %s}
	DUPLICATE_ITEM_IN_ARGS {Duplicate item `%s' in arguments.}
	DUPLICATE_POOLNAME     {The pool `%s' already exists.}
	EXCEED_MAXSIZE         "This command would increase the total number of items\
		\nbeyond the maximum size of the pool. No items registered."
	FORBIDDEN_ALLOCID      "The value -1 is not allowed as an allocID."
	INVALID_POOLSIZE       {The pool currently holds %s items.\
		Can't set maxsize to a value less than that.}
	ITEM_ALREADY_IN_POOL   {`%s' already is a member of the pool. No items registered.}
	ITEM_NOT_IN_POOL       {`%s' is not a member of %s.}
	ITEM_NOT_ALLOCATED     {Can't release `%s' because it isn't allocated.}
	ITEM_STILL_ALLOCATED   {Can't remove `%s' because it is still allocated.}
	NONINT_REQSIZE         {The second argument must be a positive integer value}
	SOME_ITEMS_NOT_FREE    {Couldn't %s `%s' because some items are still allocated.}
	UNKNOWN_ARG            {Unknown argument `%s'}
	UNKNOWN_POOL           {Nothing known about `%s'.}
	VARNAME_EXISTS         {A variable `::struct::pool::%s' already exists.}
	WRONG_INFO_TYPE        "Expected second argument to be one of:\
		\n     allitems, allocstate, cursize, freeitems, maxsize,\
		\nbut received: `%s'."
	WRONG_NARGS            "wrong#args"
    }
    
    namespace export pool
}

# A small helper routine to generate structured errors

if {[package vsatisfies [package present Tcl] 8.5]} {
    # Tcl 8.5+, have expansion operator and syntax. And option -level.
    proc ::struct::pool::Error {error args} {
	variable Errors
	return -code error -level 1 \
	    -errorcode [list STRUCT POOL $error {*}$args] \
	    [format $Errors($error) {*}$args]
    }
} else {
    # Tcl 8.4. No expansion operator available. Nor -level.
    # Construct the pieces explicitly, via linsert/eval hop&dance.
    proc ::struct::pool::Error {error args} {
	variable Errors
	lappend code STRUCT POOL $error
	eval [linsert $args 0 lappend code]
	set msg [eval [linsert $args 0 format $Errors($error)]]
	return -code error -errorcode $code $msg
    }
}

# A small helper routine to check list membership
proc ::struct::pool::lmember {list element} {
    if { [lsearch -exact $list $element] >= 0 } {
        return 1
    } else  {
        return 0
    }
}

# General note
# ============
#
# All procedures below use the following method to reference
# a particular pool-object:
#
#    variable $poolname
#    upvar #0 ::struct::pool::$poolname pool
#    upvar #0 ::struct::pool::Allocstate_$poolname state
#
# Therefore, the names `pool' and `state' refer to a particular
# instance of a pool.
#
# In the comments to the code below, the words `pool' and `state'
# also refer to a particular pool.
#

# ::struct::pool::create
#
#    Creates a new instance of a pool (a pool-object).
#    ::struct::pool::pool (see right below) is an alias to this procedure.
#
#
# Arguments:
#    poolname: name of the pool-object
#    maxsize:  the maximum number of elements that the pool is allowed
#              consist of.
#
#
# Results:
#    the name of the newly created pool
#
#
# Side effects:
#    - Registers the pool-name in the variable `pools'.
#
#    - Creates the pool array which holds general state about the pool.
#      The following elements are initialized:
#          pool(freeitems): a list of non-allocated items
#          pool(cursize):   the current number of elements in the pool
#          pool(maxsize):   the maximum allowable number of pool elements
#      Additional state may be hung off this array as long as the three
#      elements above are not corrupted.
#
#    - Creates a separate array `state' that will hold allocation state
#      of the pool elements.
#
#    - Creates an object-procedure that has the same name as the pool.
#
proc ::struct::pool::create { {poolname ""} {maxsize 10} } {
    variable pools
    variable counter
    
    # check maxsize argument
    if { ![string equal $maxsize 10] } {
        if { ![regexp {^\+?[1-9][0-9]*$} $maxsize] } {
            Error NONINT_REQSIZE
        }
    }
    
    # create a name if no name was supplied
    if { [string length $poolname]==0 } {
        incr counter
        set poolname pool$counter
        set incrcnt 1
    }
    
    # check whether there exists a pool named $poolname
    if { [lmember $pools $poolname] } {
        if { [::info exists incrcnt] } {
            incr counter -1
        }
        Error DUPLICATE_POOLNAME $poolname
    }
    
    # check whether the namespace variable exists
    if { [::info exists ::struct::pool::$poolname] } {
        if { [::info exists incrcnt] } {
            incr counter -1
        }
        Error VARNAME_EXISTS $poolname
    }
    
    variable $poolname
    
    # register
    lappend pools $poolname
    
    # create and initialize the new pool data structure
    upvar #0 ::struct::pool::$poolname pool
    set pool(freeitems) {}
    set pool(maxsize) $maxsize
    set pool(cursize) 0
    
    # the array that holds allocation state
    upvar #0 ::struct::pool::Allocstate_$poolname state
    array set state {}
    
    # create a pool-object command and map it to the pool commands
    interp alias {} ::$poolname {} ::struct::pool::poolCmd $poolname
    return $poolname
}

#
# This alias provides compatibility with the implementation of the
# other data structures (stack, queue etc...) in the tcllib::struct package.
#
proc ::struct::pool::pool { {poolname ""} {maxsize 10} } {
    ::struct::pool::create $poolname $maxsize
}


# ::struct::pool::poolCmd
#
#    This proc constitutes a level of indirection between the pool-object
#    subcommand and the pool commands (below); it's sole function is to pass
#    the command along to one of the pool commands, and receive any results.
#
# Arguments:
#    poolname:    name of the pool-object
#    subcmd:      the subcommand, which identifies the pool-command to
#                 which calls will be passed.
#    args:        any arguments. They will be inspected by the pool-command
#                 to which this call will be passed along.
#
# Results:
#    Whatever result the pool command returns, is once more returned.
#
# Side effects:
#    Dispatches the call onto a specific pool command and receives any results.
#
proc ::struct::pool::poolCmd {poolname subcmd args} {
    # check the subcmd argument
    if { [lsearch -exact $::struct::pool::commands $subcmd] == -1 } {
        set optlist [join $::struct::pool::commands ", "]
        set optlist [linsert $optlist "end-1" "or"]
        Error BAD_SUBCMD $subcmd $optlist
    }
    
    # pass the call to the pool command indicated by the subcmd argument,
    # and return the result from that command.
    return [eval [linsert $args 0 ::struct::pool::$subcmd $poolname]]
}


# ::struct::pool::destroy
#
#    Destroys a pool-object, its associated variables and "object-command"
#
# Arguments:
#    poolname:    name of the pool-object
#    forceArg:    if set to `-force', the pool-object will be destroyed
#                 regardless the allocation state of its objects.
#
# Results:
#    none
#
# Side effects:
#    - unregisters the pool name in the variable `pools'.
#    - unsets `pool' and `state' (poolname specific variables)
#    - destroys the "object-procedure" that was associated with the pool.
#
proc ::struct::pool::destroy {poolname {forceArg ""}} {
    variable pools
    
    # check forceArg argument
    if { [string length $forceArg] } {
        if { [string equal $forceArg -force] } {
            set force 1
        } else {
            Error UNKNOWN_ARG $forceArg
        }
    } else {
        set force 0
    }
    
    set index [lsearch -exact $pools $poolname]
    if {$index == -1 } {
        Error UNKNOWN_POOL $poolname
    }
    
    if { !$force } {
        # check for any lingering allocated items
        variable $poolname
        upvar #0 ::struct::pool::$poolname pool
        upvar #0 ::struct::pool::Allocstate_$poolname state
        if { [llength $pool(freeitems)] != $pool(cursize) } {
            Error SOME_ITEMS_NOT_FREE destroy $poolname
        }
    }
    
    rename ::$poolname {}
    unset ::struct::pool::$poolname
    catch {unset ::struct::pool::Allocstate_$poolname}
    set pools [lreplace $pools $index $index]
    
    return
}


# ::struct::pool::add
#
#    Add items to the pool
#
# Arguments:
#    poolname:    name of the pool-object
#    args:        the items to add
#
# Results:
#    none
#
# Side effects:
#    sets the initial allocation state of the added items to -1 (free)
#
proc ::struct::pool::add {poolname args} {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # argument check
    if { [llength $args] == 0 } {
        Error WRONG_NARGS
    }
    
    # will this operation exceed the size limit of the pool?
    if {[expr { $pool(cursize) + [llength $args] }] > $pool(maxsize) } {
        Error EXCEED_MAXSIZE
    }
    
    
    # check for duplicate items on the command line
    set N [llength $args]
    if { $N > 1} {
        for {set i 0} {$i<=$N} {incr i} {
            foreach item [lrange $args [expr {$i+1}] end] {
                if { [string equal [lindex $args $i] $item]} {
                    Error DUPLICATE_ITEM_IN_ARGS $item
                }
            }
        }
    }
    
    # check whether the items exist yet in the pool
    foreach item $args {
        if { [lmember [array names state] $item] } {
            Error ITEM_ALREADY_IN_POOL $item
        }
    }
    
    # add items to the pool, and initialize their allocation state
    foreach item $args {
        lappend pool(freeitems) $item
        set state($item) -1
        incr pool(cursize)
    }
    return
}



# ::struct::pool::clear
#
#    Removes all items from the pool and clears corresponding
#    allocation state.
#
#
# Arguments:
#    poolname: name of the pool-object
#    forceArg: if set to `-force', all items are removed
#              regardless their allocation state.
#
# Results:
#    none
#
# Side effects:
#    see description above
#
proc ::struct::pool::clear {poolname {forceArg ""} } {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # check forceArg argument
    if { [string length $forceArg] } {
        if { [string equal $forceArg -force] } {
            set force 1
        } else {
            Error UNKNOWN_ARG $forceArg
        }
    } else {
        set force 0
    }
    
    # check whether some items are still allocated
    if { !$force } {
        if { [llength $pool(freeitems)] != $pool(cursize) } {
            Error SOME_ITEMS_NOT_FREE clear $poolname
        }
    }
    
    # clear the pool, clean up state and adjust the pool size
    set pool(freeitems) {}
    array unset state
    array set state {}
    set pool(cursize) 0
    return
}



# ::struct::pool::info
#
#    Returns information about the pool in data structures that allow
#    further programmatic use.
#
# Arguments:
#    poolname: name of the pool-object
#    type:     the type of info requested
#
#
# Results:
#    The info requested
#
#
# Side effects:
#    none
#
proc ::struct::pool::info {poolname type args} {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # check the number of arguments
    if { [string equal $type allocID] } {
        if { [llength $args]!=1 } {
            Error WRONG_NARGS
        }
    } elseif { [llength $args] > 0 } {
        Error WRONG_NARGS
    }
    
    switch $type {
        allitems {
            return [array names state]
        }
        allocstate {
            return [array get state]
        }
        allocID {
            set item [lindex $args 0]
            if {![lmember [array names state] $item]} {
                Error ITEM_NOT_IN_POOL $item $poolname
            }
            return $state($item)
        }
        cursize {
            return $pool(cursize)
        }
        freeitems {
            return $pool(freeitems)
        }
        maxsize {
            return $pool(maxsize)
        }
        default {
            Error WRONG_INFO_TYPE $type
        }
    }
}


# ::struct::pool::maxsize
#
#    Returns the current or sets a new maximum size of the pool.
#    As far as querying only is concerned, this is an alias for
#    `::struct::pool::info maxsize'.
#
#
# Arguments:
#    poolname: name of the pool-object
#    reqsize:  if supplied, it is the requested size of the pool, i.e.
#              the maximum number of elements in the pool.
#
#
# Results:
#    The current/new maximum size of the pool.
#
#
# Side effects:
#    Sets pool(maxsize) if a new size is supplied.
#
proc ::struct::pool::maxsize {poolname {reqsize ""} } {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    if { [string length $reqsize] } {
        if { [regexp {^\+?[1-9][0-9]*$} $reqsize] } {
            if { $pool(cursize) <= $reqsize } {
                set pool(maxsize) $reqsize
            } else  {
                Error INVALID_POOLSIZE $pool(cursize)
            }
        } else  {
            Error NONINT_REQSIZE
        }
    }
    return $pool(maxsize)
}


# ::struct::pool::release
#
#    Deallocates an item
#
#
# Arguments:
#    poolname: name of the pool-object
#    item:     name of the item to be released
#
#
# Results:
#    none
#
# Side effects:
#    - sets the item's allocation state to free (-1)
#    - appends item to the list of free items
#
proc ::struct::pool::release {poolname item} {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # Is item in the pool?
    if {![lmember [array names state] $item]} {
        Error ITEM_NOT_IN_POOL $item $poolname
    }
    
    # check whether item was allocated
    if { $state($item) == -1 } {
        Error ITEM_NOT_ALLOCATED $item
    } else  {
        
        # set item free and return it to the pool of free items
        set state($item) -1
        lappend pool(freeitems) $item
        
    }
    return
}

# ::struct::pool::remove
#
#    Removes an item from the pool
#
#
# Arguments:
#    poolname: name of the pool-object
#    item:     the item to be removed
#    forceArg: if set to `-force', the item is removed
#              regardless its allocation state.
#
# Results:
#    none
#
# Side effects:
#    - cleans up allocation state related to the item
#
proc ::struct::pool::remove {poolname item {forceArg ""} } {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # check forceArg argument
    if { [string length $forceArg] } {
        if { [string equal $forceArg -force] } {
            set force 1
        } else {
            Error UNKNOWN_ARG $forceArg
        }
    } else {
        set force 0
    }
    
    # Is item in the pool?
    if {![lmember [array names state] $item]} {
        Error ITEM_NOT_IN_POOL $item $poolname
    }
    
    set index [lsearch $pool(freeitems) $item]
    if { $index >= 0} {
        
        # actual removal
        set pool(freeitems) [lreplace $pool(freeitems) $index $index]
        
    } elseif { !$force }  {
        Error ITEM_STILL_ALLOCATED $item
    }
    
    # clean up state and adjust the pool size
    unset state($item)
    incr pool(cursize) -1
    return
}



# ::struct::pool::request
#
#     Handles requests for an item, taking into account a preference
#     for a particular item if supplied.
#
#
# Arguments:
#    poolname:    name of the pool-object
#
#    itemvar:     variable to which the item-name will be assigned
#                 if the request is honored.
#
#    args:        an optional sequence of key-value pairs, indicating the
#                 following options:
#                 -prefer:  the preferred item to allocate.
#                 -allocID: An ID for the entity to which the item will be
#                           allocated. This facilitates reverse lookups.
#
# Results:
#
#    1 if the request was honored; an item is allocated
#    0 if the request couldn't be honored; no item is allocated
#
#    The user is strongly advised to check the return values
#    when calling this procedure.
#
#
# Side effects:
#
#   if the request is honored:
#    - sets allocation state to $allocID (or dummyID if it was not supplied)
#      if allocation was succesful. Allocation state is maintained in the
#      namespace variable state (see: `General note' above)
#    - sets the variable passed via `itemvar' to the allocated item.
#
#   if the request is denied, no side effects occur.
#
proc ::struct::pool::request {poolname itemvar args} {
    variable $poolname
    upvar #0 ::struct::pool::$poolname pool
    upvar #0 ::struct::pool::Allocstate_$poolname state
    
    # check args
    set nargs [llength $args]
    if { ! ($nargs==0 || $nargs==2 || $nargs==4) } {
        if { ![string equal $args -?] && ![string equal $args -help]} {
            Error WRONG_NARGS
        }
    } elseif { $nargs } {
        foreach {name value} $args {
            if { ![string match -* $name] } {
                Error UNKNOWN_ARG $name
            }
        }
    }
    
    set allocated 0
    
    # are there any items available?
    if { [llength $pool(freeitems)] > 0} {
        
        # process command options
        set options [cmdline::getoptions args { \
            {prefer.arg {} {The preference for a particular item}} \
            {allocID.arg {} {An ID for the entity to which the item will be allocated} } \
                } \
                "usage: $poolname request itemvar ?options?:"]
        foreach {key value} $options {
            set $key $value
        }
        
        if { $allocID == -1 } {
            Error FORBIDDEN_ALLOCID
        }
        
        # let `item' point to a variable two levels up the call stack
        upvar 2 $itemvar item
        
        # check whether a preference was supplied
        if { [string length $prefer] } {
            if {![lmember [array names state] $prefer]} {
                Error ITEM_NOT_IN_POOL $prefer $poolname
            }
            if { $state($prefer) == -1 } {
                set index [lsearch $pool(freeitems) $prefer]
                set item $prefer
            } else {
		return 0
	    }
        } else  {
            set index 0
            set item [lindex $pool(freeitems) 0]
        }
        
        # do the actual allocation
        set pool(freeitems) [lreplace $pool(freeitems) $index $index]
        if { [string length $allocID] } {
            set state($item) $allocID
        } else  {
            set state($item) dummyID
        }
        set allocated 1
    }
    return $allocated
}


# EOF pool.tcl

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'pool::pool' into the general structure namespace.
    namespace import -force pool::pool
    namespace export pool
}
package provide struct::pool 1.2.3
