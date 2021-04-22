# graph.tcl --
#
#	Implementation of a graph data structure for Tcl.
#
# Copyright (c) 2000 by Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: graph1.tcl,v 1.5 2008/08/13 20:30:58 mic42 Exp $

# Create the namespace before determining cgraph vs. tcl
# Otherwise the loading 'struct.tcl' may get into trouble
# when trying to import commands from them

namespace eval ::struct {}
namespace eval ::struct::graph {}

# Try to load the cgraph package

if {![catch {package require cgraph 0.6}]} {
    # the cgraph package takes over, so we can return
    return
}

namespace eval ::struct {}
namespace eval ::struct::graph {
    # Data storage in the graph module
    # -------------------------------
    #
    # There's a lot of bits to keep track of for each graph:
    #	nodes
    #	node values
    #	node relationships (arcs)
    #   arc values
    #
    # It would quickly become unwieldy to try to keep these in arrays or lists
    # within the graph namespace itself.  Instead, each graph structure will
    # get its own namespace.  Each namespace contains:
    #	node:$node	array mapping keys to values for the node $node
    #	arc:$arc	array mapping keys to values for the arc $arc
    #	inArcs		array mapping nodes to the list of incoming arcs
    #	outArcs		array mapping nodes to the list of outgoing arcs
    #	arcNodes	array mapping arcs to the two nodes (start & end)
    
    # counter is used to give a unique name for unnamed graph
    variable counter 0

    # commands is the list of subcommands recognized by the graph
    variable commands [list	\
	    "arc"		\
	    "arcs"		\
	    "destroy"		\
	    "get"		\
	    "getall"		\
	    "keys"		\
	    "keyexists"		\
	    "node"		\
	    "nodes"		\
	    "set"		\
	    "swap"		\
	    "unset"             \
	    "walk"		\
	    ]

    variable arcCommands [list	\
	    "append"	\
	    "delete"	\
	    "exists"	\
	    "get"	\
	    "getall"	\
	    "insert"	\
	    "keys"	\
	    "keyexists"	\
	    "lappend"	\
	    "set"	\
	    "source"	\
	    "target"	\
	    "unset"	\
	    ]

    variable nodeCommands [list	\
	    "append"	\
	    "degree"	\
	    "delete"	\
	    "exists"	\
	    "get"	\
	    "getall"	\
	    "insert"	\
	    "keys"	\
	    "keyexists"	\
	    "lappend"	\
	    "opposite"	\
	    "set"	\
	    "unset"	\
	    ]

    # Only export one command, the one used to instantiate a new graph
    namespace export graph
}

# ::struct::graph::graph --
#
#	Create a new graph with a given name; if no name is given, use
#	graphX, where X is a number.
#
# Arguments:
#	name	name of the graph; if null, generate one.
#
# Results:
#	name	name of the graph created

proc ::struct::graph::graph {{name ""}} {
    variable counter
    
    if { [llength [info level 0]] == 1 } {
	incr counter
	set name "graph${counter}"
    }

    if { ![string equal [info commands ::$name] ""] } {
	error "command \"$name\" already exists, unable to create graph"
    }

    # Set up the namespace
    namespace eval ::struct::graph::graph$name {

	# Set up the map for values associated with the graph itself
	variable graphData
	array set graphData {data ""}

	# Set up the map from nodes to the arcs coming to them
	variable  inArcs
	array set inArcs {}

	# Set up the map from nodes to the arcs going out from them
	variable  outArcs
	array set outArcs {}

	# Set up the map from arcs to the nodes they touch.
	variable  arcNodes
	array set arcNodes {}

	# Set up a value for use in creating unique node names
	variable nextUnusedNode
	set nextUnusedNode 1

	# Set up a value for use in creating unique arc names
	variable nextUnusedArc
	set nextUnusedArc 1
    }

    # Create the command to manipulate the graph
    interp alias {} ::$name {} ::struct::graph::GraphProc $name

    return $name
}

##########################
# Private functions follow

# ::struct::graph::GraphProc --
#
#	Command that processes all graph object commands.
#
# Arguments:
#	name	name of the graph object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::struct::graph::GraphProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    if { [llength [info commands ::struct::graph::_$cmd]] == 0 } {
	variable commands
	set optlist [join $commands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	error "bad option \"$cmd\": must be $optlist"
    }
    eval [list ::struct::graph::_$cmd $name] $args
}

# ::struct::graph::_arc --
#
#	Dispatches the invocation of arc methods to the proper handler
#	procedure.
#
# Arguments:
#	name	name of the graph.
#	cmd	arc command to invoke
#	args	arguments to propagate to the handler for the arc command
#
# Results:
#	As of the invoked handler.

proc ::struct::graph::_arc {name cmd args} {

    # Split the args into command and args components
    if { [llength [info commands ::struct::graph::__arc_$cmd]] == 0 } {
	variable arcCommands
	set optlist [join $arcCommands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	error "bad option \"$cmd\": must be $optlist"
    }

    eval [list ::struct::graph::__arc_$cmd $name] $args
}

# ::struct::graph::__arc_delete --
#
#	Remove an arc from a graph, including all of its values.
#
# Arguments:
#	name	name of the graph.
#	args	list of arcs to delete.
#
# Results:
#	None.

proc ::struct::graph::__arc_delete {name args} {

    foreach arc $args {
	if { ![__arc_exists $name $arc] } {
	    error "arc \"$arc\" does not exist in graph \"$name\""
	}
    }

    upvar ::struct::graph::graph${name}::inArcs   inArcs
    upvar ::struct::graph::graph${name}::outArcs  outArcs
    upvar ::struct::graph::graph${name}::arcNodes arcNodes

    foreach arc $args {
	foreach {source target} $arcNodes($arc) break ; # lassign

	unset arcNodes($arc)
	# FRINK: nocheck
	unset ::struct::graph::graph${name}::arc$arc

	# Remove arc from the arc lists of source and target nodes.

	set index            [lsearch -exact $outArcs($source) $arc]
	set outArcs($source) [lreplace       $outArcs($source) $index $index]

	set index            [lsearch -exact $inArcs($target)  $arc]
	set inArcs($target)  [lreplace       $inArcs($target)  $index $index]
    }

    return
}

# ::struct::graph::__arc_exists --
#
#	Test for existance of a given arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to look for.
#
# Results:
#	1 if the arc exists, 0 else.

proc ::struct::graph::__arc_exists {name arc} {
    return [info exists ::struct::graph::graph${name}::arcNodes($arc)]
}

# ::struct::graph::__arc_get --
#
#	Get a keyed value from an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to query.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::__arc_get {name arc {flag -key} {key data}} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }
    
    upvar ::struct::graph::graph${name}::arc${arc} data

    if { ![info exists data($key)] } {
	error "invalid key \"$key\" for arc \"$arc\""
    }

    return $data($key)
}

# ::struct::graph::__arc_getall --
#
#	Get a serialized array of key/value pairs from an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to query.
#
# Results:
#	value	serialized array of key/value pairs.

proc ::struct::graph::__arc_getall {name arc args} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    if { [llength $args] } {
	error "wrong # args: should be none"
    }
    
    upvar ::struct::graph::graph${name}::arc${arc} data

    return [array get data]
}

# ::struct::graph::__arc_keys --
#
#	Get a list of keys for an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to query.
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::__arc_keys {name arc args} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    if { [llength $args] } {
	error "wrong # args: should be none"
    }    

    upvar ::struct::graph::graph${name}::arc${arc} data

    return [array names data]
}

# ::struct::graph::__arc_keyexists --
#
#	Test for existance of a given key for a given arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to query.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	1 if the key exists, 0 else.

proc ::struct::graph::__arc_keyexists {name arc {flag -key} {key data}} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    if { ![string equal $flag "-key"] } {
	error "invalid option \"$flag\": should be -key"
    }
    
    upvar ::struct::graph::graph${name}::arc${arc} data

    return [info exists data($key)]
}

# ::struct::graph::__arc_insert --
#
#	Add an arc to a graph.
#
# Arguments:
#	name		name of the graph.
#	source		source node of the new arc
#	target		target node of the new arc
#	args		arc to insert; must be unique.  If none is given,
#			the routine will generate a unique node name.
#
# Results:
#	arc		The name of the new arc.

proc ::struct::graph::__arc_insert {name source target args} {

    if { [llength $args] == 0 } {
	# No arc name was given; generate a unique one
	set arc [__generateUniqueArcName $name]
    } else {
	set arc [lindex $args 0]
    }

    if { [__arc_exists $name $arc] } {
	error "arc \"$arc\" already exists in graph \"$name\""
    }
    
    if { ![__node_exists $name $source] } {
	error "source node \"$source\" does not exist in graph \"$name\""
    }
    
    if { ![__node_exists $name $target] } {
	error "target node \"$target\" does not exist in graph \"$name\""
    }
    
    upvar ::struct::graph::graph${name}::inArcs    inArcs
    upvar ::struct::graph::graph${name}::outArcs   outArcs
    upvar ::struct::graph::graph${name}::arcNodes  arcNodes
    upvar ::struct::graph::graph${name}::arc${arc} data

    # Set up the new arc
    set data(data)       ""
    set arcNodes($arc) [list $source $target]

    # Add this arc to the arc lists of its source resp. target nodes.
    lappend outArcs($source) $arc
    lappend inArcs($target)  $arc

    return $arc
}

# ::struct::graph::__arc_set --
#
#	Set or get a value for an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to modify or query.
#	args	?-key key? ?value?
#
# Results:
#	val	value associated with the given key of the given arc

proc ::struct::graph::__arc_set {name arc args} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arc$arc data

    if { [llength $args] > 3 } {
	error "wrong # args: should be \"$name arc set $arc ?-key key?\
		?value?\""
    }
    
    set key "data"
    set haveValue 0
    if { [llength $args] > 1 } {
	foreach {flag key} $args break
	if { ![string match "${flag}*" "-key"] } {
	    error "invalid option \"$flag\": should be key"
	}
	if { [llength $args] == 3 } {
	    set haveValue 1
	    set value [lindex $args end]
	}
    } elseif { [llength $args] == 1 } {
	set haveValue 1
	set value [lindex $args end]
    }

    if { $haveValue } {
	# Setting a value
	return [set data($key) $value]
    } else {
	# Getting a value
	if { ![info exists data($key)] } {
	    error "invalid key \"$key\" for arc \"$arc\""
	}
	return $data($key)
    }
}

# ::struct::graph::__arc_append --
#
#	Append a value for an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to modify or query.
#	args	?-key key? value
#
# Results:
#	val	value associated with the given key of the given arc

proc ::struct::graph::__arc_append {name arc args} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arc$arc data

    if { [llength $args] != 1 && [llength $args] != 3 } {
	error "wrong # args: should be \"$name arc append $arc ?-key key?\
		value\""
    }
    
    if { [llength $args] == 3 } {
	foreach {flag key} $args break
	if { ![string equal $flag "-key"] } {
	    error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

    return [append data($key) $value]
}

# ::struct::graph::__arc_lappend --
#
#	lappend a value for an arc in a graph.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to modify or query.
#	args	?-key key? value
#
# Results:
#	val	value associated with the given key of the given arc

proc ::struct::graph::__arc_lappend {name arc args} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arc$arc data

    if { [llength $args] != 1 && [llength $args] != 3 } {
	error "wrong # args: should be \"$name arc lappend $arc ?-key key?\
		value\""
    }
    
    if { [llength $args] == 3 } {
	foreach {flag key} $args break
	if { ![string equal $flag "-key"] } {
	    error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

    return [lappend data($key) $value]
}

# ::struct::graph::__arc_source --
#
#	Return the node at the beginning of the specified arc.
#
# Arguments:
#	name	name of the graph object.
#	arc	arc to look up.
#
# Results:
#	node	name of the node.

proc ::struct::graph::__arc_source {name arc} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arcNodes arcNodes
    return [lindex $arcNodes($arc) 0]
}

# ::struct::graph::__arc_target --
#
#	Return the node at the end of the specified arc.
#
# Arguments:
#	name	name of the graph object.
#	arc	arc to look up.
#
# Results:
#	node	name of the node.

proc ::struct::graph::__arc_target {name arc} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arcNodes arcNodes
    return [lindex $arcNodes($arc) 1]
}

# ::struct::graph::__arc_unset --
#
#	Remove a keyed value from a arc.
#
# Arguments:
#	name	name of the graph.
#	arc	arc to modify.
#	args	additional args: ?-key key?
#
# Results:
#	None.

proc ::struct::graph::__arc_unset {name arc {flag -key} {key data}} {
    if { ![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }
    
    if { ![string match "${flag}*" "-key"] } {
	error "invalid option \"$flag\": should be \"$name arc unset\
		$arc ?-key key?\""
    }

    upvar ::struct::graph::graph${name}::arc${arc} data
    if { [info exists data($key)] } {
	unset data($key)
    }
    return
}

# ::struct::graph::_arcs --
#
#	Return a list of all arcs in a graph satisfying some
#	node based restriction.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	arcs	list of arcs

proc ::struct::graph::_arcs {name args} {

    # Discriminate between conditions and nodes

    set haveCond 0
    set haveKey 0
    set haveValue 0
    set cond "none"
    set condNodes [list]

    for {set i 0} {$i < [llength $args]} {incr i} {
	set arg [lindex $args $i]
	switch -glob -- $arg {
	    -in -
	    -out -
	    -adj -
	    -inner -
	    -embedding {
		if {$haveCond} {
		    return -code error "invalid restriction:\
			    illegal multiple use of\
			    \"-in\"|\"-out\"|\"-adj\"|\"-inner\"|\"-embedding\""
		}

		set haveCond 1
		set cond [string range $arg 1 end]
	    }
	    -key {
		if {$haveKey} {
		    return -code error {invalid restriction: illegal multiple use of "-key"}
		}

		incr i
		set key [lindex $args $i]
		set haveKey 1
	    }
	    -value {
		if {$haveValue} {
		    return -code error {invalid restriction: illegal multiple use of "-value"}
		}

		incr i
		set value [lindex $args $i]
		set haveValue 1
	    }
	    -* {
		error "invalid restriction \"$arg\": should be -in, -out,\
			-adj, -inner, -embedding, -key or -value"
	    }
	    default {
		lappend condNodes $arg
	    }
	}
    }

    # Validate that there are nodes to use in the restriction.
    # otherwise what's the point?
    if {$haveCond} {
	if {[llength $condNodes] == 0} {
	    set usage "$name arcs ?-key key? ?-value value? ?-in|-out|-adj|-inner|-embedding node node...?"
	    error "no nodes specified: should be \"$usage\""
	}

	# Make sure that the specified nodes exist!
	foreach node $condNodes {
	    if { ![__node_exists $name $node] } {
		error "node \"$node\" does not exist in graph \"$name\""
	    }
	}
    }

    # Now we are able to go to work
    upvar ::struct::graph::graph${name}::inArcs   inArcs
    upvar ::struct::graph::graph${name}::outArcs  outArcs
    upvar ::struct::graph::graph${name}::arcNodes arcNodes

    set       arcs [list]

    switch -exact -- $cond {
	in {
	    # Result is all arcs going to at least one node
	    # in the list of arguments.

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    # As an arc has only one destination, i.e. is the
		    # in-arc of exactly one node it is impossible to
		    # count an arc twice. IOW the [info exists] below
		    # is never true. Found through coverage analysis
		    # and then trying to think up a testcase invoking
		    # the continue.
		    # if {[info exists coll($e)]} {continue}
		    lappend arcs    $e
		    #set     coll($e) .
		}
	    }
	}
	out {
	    # Result is all arcs coming from at least one node
	    # in the list of arguments.

	    foreach node $condNodes {
		foreach e $outArcs($node) {
		    # See above 'in', same reasoning, one source per arc.
		    # if {[info exists coll($e)]} {continue}
		    lappend arcs    $e
		    #set     coll($e) .
		}
	    }
	}
	adj {
	    # Result is all arcs coming from or going to at
	    # least one node in the list of arguments.

	    array set coll  {}
	    # Here we do need 'coll' as each might be an in- and
	    # out-arc for one or two nodes in the list of arguments.

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    if {[info exists coll($e)]} {continue}
		    lappend arcs    $e
		    set     coll($e) .
		}
		foreach e $outArcs($node) {
		    if {[info exists coll($e)]} {continue}
		    lappend arcs    $e
		    set     coll($e) .
		}
	    }
	}
	inner {
	    # Result is all arcs running between nodes in the list.

	    array set coll  {}
	    # Here we do need 'coll' as each might be an in- and
	    # out-arc for one or two nodes in the list of arguments.

	    array set group {}
	    foreach node $condNodes {
		set group($node) .
	    }

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {![info exists group($n)]} {continue}
		    if { [info exists coll($e)]}  {continue}
		    lappend arcs    $e
		    set     coll($e) .
		}
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {![info exists group($n)]} {continue}
		    if { [info exists coll($e)]}  {continue}
		    lappend arcs    $e
		    set     coll($e) .
		}
	    }
	}
	embedding {
	    # Result is all arcs from -adj minus the arcs from -inner.
	    # IOW all arcs going from a node in the list to a node
	    # which is *not* in the list

	    # This also means that no arc can be counted twice as it
	    # is either going to a node, or coming from a node in the
	    # list, but it can't do both, because then it is part of
	    # -inner, which was excluded!

	    array set group {}
	    foreach node $condNodes {
		set group($node) .
	    }

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {[info exists group($n)]} {continue}
		    # if {[info exists coll($e)]}  {continue}
		    lappend arcs    $e
		    # set     coll($e) .
		}
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {[info exists group($n)]} {continue}
		    # if {[info exists coll($e)]}  {continue}
		    lappend arcs    $e
		    # set     coll($e) .
		}
	    }
	}
	none {
	    set arcs [array names arcNodes]
	}
	default {error "Can't happen, panic"}
    }

    #
    # We have a list of arcs that match the relation to the nodes.
    # Now filter according to -key and -value.
    #

    set filteredArcs [list]

    if {$haveKey} {
	foreach arc $arcs {
	    catch {
		set aval [__arc_get $name $arc -key $key]
		if {$haveValue} {
		    if {$aval == $value} {
			lappend filteredArcs $arc
		    }
		} else {
		    lappend filteredArcs $arc
		}
	    }
	}
    } else {
	set filteredArcs $arcs
    }

    return $filteredArcs
}

# ::struct::graph::_destroy --
#
#	Destroy a graph, including its associated command and data storage.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	None.

proc ::struct::graph::_destroy {name} {
    namespace delete ::struct::graph::graph$name
    interp alias {} ::$name {}
}

# ::struct::graph::__generateUniqueArcName --
#
#	Generate a unique arc name for the given graph.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	arc	name of a arc guaranteed to not exist in the graph.

proc ::struct::graph::__generateUniqueArcName {name} {
    upvar ::struct::graph::graph${name}::nextUnusedArc nextUnusedArc
    while {[__arc_exists $name "arc${nextUnusedArc}"]} {
	incr nextUnusedArc
    }
    return "arc${nextUnusedArc}"
}

# ::struct::graph::__generateUniqueNodeName --
#
#	Generate a unique node name for the given graph.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	node	name of a node guaranteed to not exist in the graph.

proc ::struct::graph::__generateUniqueNodeName {name} {
    upvar ::struct::graph::graph${name}::nextUnusedNode nextUnusedNode
    while {[__node_exists $name "node${nextUnusedNode}"]} {
	incr nextUnusedNode
    }
    return "node${nextUnusedNode}"
}

# ::struct::graph::_get --
#
#	Get a keyed value from the graph itself
#
# Arguments:
#	name	name of the graph.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::_get {name {flag -key} {key data}} {
    upvar ::struct::graph::graph${name}::graphData data

    if { ![info exists data($key)] } {
	error "invalid key \"$key\" for graph \"$name\""
    }

    return $data($key)
}

# ::struct::graph::_getall --
#
#	Get a serialized list of key/value pairs from a graph.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::_getall {name args} { 
    if { [llength $args] } {
	error "wrong # args: should be none"
    }
    
    upvar ::struct::graph::graph${name}::graphData data
    return [array get data]
}

# ::struct::graph::_keys --
#
#	Get a list of keys from a graph.
#
# Arguments:
#	name	name of the graph.
#
# Results:
#	value	list of known keys

proc ::struct::graph::_keys {name args} { 
    if { [llength $args] } {
	error "wrong # args: should be none"
    }

    upvar ::struct::graph::graph${name}::graphData data
    return [array names data]
}

# ::struct::graph::_keyexists --
#
#	Test for existance of a given key in a graph.
#
# Arguments:
#	name	name of the graph.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	1 if the key exists, 0 else.

proc ::struct::graph::_keyexists {name {flag -key} {key data}} {
    if { ![string equal $flag "-key"] } {
	error "invalid option \"$flag\": should be -key"
    }
    
    upvar ::struct::graph::graph${name}::graphData data
    return [info exists data($key)]
}

# ::struct::graph::_node --
#
#	Dispatches the invocation of node methods to the proper handler
#	procedure.
#
# Arguments:
#	name	name of the graph.
#	cmd	node command to invoke
#	args	arguments to propagate to the handler for the node command
#
# Results:
#	As of the the invoked handler.

proc ::struct::graph::_node {name cmd args} {

    # Split the args into command and args components
    if { [llength [info commands ::struct::graph::__node_$cmd]] == 0 } {
	variable nodeCommands
	set optlist [join $nodeCommands ", "]
	set optlist [linsert $optlist "end-1" "or"]
	error "bad option \"$cmd\": must be $optlist"
    }

    eval [list ::struct::graph::__node_$cmd $name] $args
}

# ::struct::graph::__node_degree --
#
#	Return the number of arcs adjacent to the specified node.
#	If one of the restrictions -in or -out is given only
#	incoming resp. outgoing arcs are counted.
#
# Arguments:
#	name	name of the graph.
#	args	option, followed by the node.
#
# Results:
#	None.

proc ::struct::graph::__node_degree {name args} {

    if {([llength $args] < 1) || ([llength $args] > 2)} {
	error "wrong # args: should be \"$name node degree ?-in|-out? node\""
    }

    switch -exact -- [llength $args] {
	1 {
	    set opt {}
	    set node [lindex $args 0]
	}
	2 {
	    set opt  [lindex $args 0]
	    set node [lindex $args 1]
	}
	default {error "Can't happen, panic"}
    }

    # Validate the option.

    switch -exact -- $opt {
	{}   -
	-in  -
	-out {}
	default {
	    error "invalid option \"$opt\": should be -in or -out"
	}
    }

    # Validate the node

    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::inArcs   inArcs
    upvar ::struct::graph::graph${name}::outArcs  outArcs

    switch -exact -- $opt {
	-in  {
	    set result [llength $inArcs($node)]
	}
	-out {
	    set result [llength $outArcs($node)]
	}
	{} {
	    set result [expr {[llength $inArcs($node)] \
		    + [llength $outArcs($node)]}]

	    # loops count twice, don't do <set> arithmetics, i.e. no union!
	    if {0} {
		array set coll  {}
		set result [llength $inArcs($node)]

		foreach e $inArcs($node) {
		    set coll($e) .
		}
		foreach e $outArcs($node) {
		    if {[info exists coll($e)]} {continue}
		    incr result
		    set     coll($e) .
		}
	    }
	}
	default {error "Can't happen, panic"}
    }

    return $result
}

# ::struct::graph::__node_delete --
#
#	Remove a node from a graph, including all of its values.
#	Additionally removes the arcs connected to this node.
#
# Arguments:
#	name	name of the graph.
#	args	list of the nodes to delete.
#
# Results:
#	None.

proc ::struct::graph::__node_delete {name args} {

    foreach node $args {
	if { ![__node_exists $name $node] } {
	    error "node \"$node\" does not exist in graph \"$name\""
	}
    }

    upvar ::struct::graph::graph${name}::inArcs  inArcs
    upvar ::struct::graph::graph${name}::outArcs outArcs

    foreach node $args {
	# Remove all the arcs connected to this node
	foreach e $inArcs($node) {
	    __arc_delete $name $e
	}
	foreach e $outArcs($node) {
	    # Check existence to avoid problems with
	    # loops (they are in and out arcs! at
	    # the same time and thus already deleted)
	    if { [__arc_exists $name $e] } {
		__arc_delete $name $e
	    }
	}

	unset inArcs($node)
	unset outArcs($node)
	# FRINK: nocheck
	unset ::struct::graph::graph${name}::node$node
    }

    return
}

# ::struct::graph::__node_exists --
#
#	Test for existance of a given node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to look for.
#
# Results:
#	1 if the node exists, 0 else.

proc ::struct::graph::__node_exists {name node} {
    return [info exists ::struct::graph::graph${name}::inArcs($node)]
}

# ::struct::graph::__node_get --
#
#	Get a keyed value from a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to query.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::__node_get {name node {flag -key} {key data}} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    
    upvar ::struct::graph::graph${name}::node${node} data

    if { ![info exists data($key)] } {
	error "invalid key \"$key\" for node \"$node\""
    }

    return $data($key)
}

# ::struct::graph::__node_getall --
#
#	Get a serialized list of key/value pairs from a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to query.
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::__node_getall {name node args} { 
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }

    if { [llength $args] } {
	error "wrong # args: should be none"
    }
    
    upvar ::struct::graph::graph${name}::node${node} data

    return [array get data]
}

# ::struct::graph::__node_keys --
#
#	Get a list of keys from a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to query.
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::__node_keys {name node args} { 
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    
    if { [llength $args] } {
	error "wrong # args: should be none"
    }

    upvar ::struct::graph::graph${name}::node${node} data

    return [array names data]
}

# ::struct::graph::__node_keyexists --
#
#	Test for existance of a given key for a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to query.
#	flag	-key; anything else is an error
#	key	key to lookup; defaults to data
#
# Results:
#	1 if the key exists, 0 else.

proc ::struct::graph::__node_keyexists {name node {flag -key} {key data}} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    
    if { ![string equal $flag "-key"] } {
	error "invalid option \"$flag\": should be -key"
    }
    
    upvar ::struct::graph::graph${name}::node${node} data

    return [info exists data($key)]
}

# ::struct::graph::__node_insert --
#
#	Add a node to a graph.
#
# Arguments:
#	name		name of the graph.
#	args		node to insert; must be unique.  If none is given,
#			the routine will generate a unique node name.
#
# Results:
#	node		The namee of the new node.

proc ::struct::graph::__node_insert {name args} {

    if { [llength $args] == 0 } {
	# No node name was given; generate a unique one
	set node [__generateUniqueNodeName $name]
    } else {
	set node [lindex $args 0]
    }

    if { [__node_exists $name $node] } {
	error "node \"$node\" already exists in graph \"$name\""
    }
    
    upvar ::struct::graph::graph${name}::inArcs      inArcs
    upvar ::struct::graph::graph${name}::outArcs     outArcs
    upvar ::struct::graph::graph${name}::node${node} data

    # Set up the new node
    set inArcs($node)  [list]
    set outArcs($node) [list]
    set data(data) ""

    return $node
}

# ::struct::graph::__node_opposite --
#
#	Retrieve node opposite to the specified one, along the arc.
#
# Arguments:
#	name		name of the graph.
#	node		node to look up.
#	arc		arc to look up.
#
# Results:
#	nodex	Node opposite to <node,arc>

proc ::struct::graph::__node_opposite {name node arc} {
    if {![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    
    if {![__arc_exists $name $arc] } {
	error "arc \"$arc\" does not exist in graph \"$name\""
    }

    upvar ::struct::graph::graph${name}::arcNodes arcNodes

    # Node must be connected to at least one end of the arc.

    if {[string equal $node [lindex $arcNodes($arc) 0]]} {
	set result [lindex $arcNodes($arc) 1]
    } elseif {[string equal $node [lindex $arcNodes($arc) 1]]} {
	set result [lindex $arcNodes($arc) 0]
    } else {
	error "node \"$node\" and arc \"$arc\" are not connected\
		in graph \"$name\""
    }

    return $result
}

# ::struct::graph::__node_set --
#
#	Set or get a value for a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to modify or query.
#	args	?-key key? ?value?
#
# Results:
#	val	value associated with the given key of the given node

proc ::struct::graph::__node_set {name node args} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    upvar ::struct::graph::graph${name}::node$node data

    if { [llength $args] > 3 } {
	error "wrong # args: should be \"$name node set $node ?-key key?\
		?value?\""
    }
    
    set key "data"
    set haveValue 0
    if { [llength $args] > 1 } {
	foreach {flag key} $args break
	if { ![string match "${flag}*" "-key"] } {
	    error "invalid option \"$flag\": should be key"
	}
	if { [llength $args] == 3 } {
	    set haveValue 1
	    set value [lindex $args end]
	}
    } elseif { [llength $args] == 1 } {
	set haveValue 1
	set value [lindex $args end]
    }

    if { $haveValue } {
	# Setting a value
	return [set data($key) $value]
    } else {
	# Getting a value
	if { ![info exists data($key)] } {
	    error "invalid key \"$key\" for node \"$node\""
	}
	return $data($key)
    }
}

# ::struct::graph::__node_append --
#
#	Append a value for a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to modify or query.
#	args	?-key key? value
#
# Results:
#	val	value associated with the given key of the given node

proc ::struct::graph::__node_append {name node args} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    upvar ::struct::graph::graph${name}::node$node data

    if { [llength $args] != 1 && [llength $args] != 3 } {
	error "wrong # args: should be \"$name node append $node ?-key key?\
		value\""
    }
    
    if { [llength $args] == 3 } {
	foreach {flag key} $args break
	if { ![string equal $flag "-key"] } {
	    error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

    return [append data($key) $value]
}

# ::struct::graph::__node_lappend --
#
#	lappend a value for a node in a graph.
#
# Arguments:
#	name	name of the graph.
#	node	node to modify or query.
#	args	?-key key? value
#
# Results:
#	val	value associated with the given key of the given node

proc ::struct::graph::__node_lappend {name node args} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    upvar ::struct::graph::graph${name}::node$node data

    if { [llength $args] != 1 && [llength $args] != 3 } {
	error "wrong # args: should be \"$name node lappend $node ?-key key?\
		value\""
    }
    
    if { [llength $args] == 3 } {
	foreach {flag key} $args break
	if { ![string equal $flag "-key"] } {
	    error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

    return [lappend data($key) $value]
}

# ::struct::graph::__node_unset --
#
#	Remove a keyed value from a node.
#
# Arguments:
#	name	name of the graph.
#	node	node to modify.
#	args	additional args: ?-key key?
#
# Results:
#	None.

proc ::struct::graph::__node_unset {name node {flag -key} {key data}} {
    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }
    
    if { ![string match "${flag}*" "-key"] } {
	error "invalid option \"$flag\": should be \"$name node unset\
		$node ?-key key?\""
    }

    upvar ::struct::graph::graph${name}::node${node} data
    if { [info exists data($key)] } {
	unset data($key)
    }
    return
}

# ::struct::graph::_nodes --
#
#	Return a list of all nodes in a graph satisfying some restriction.
#
# Arguments:
#	name	name of the graph.
#	args	list of options and nodes specifying the restriction.
#
# Results:
#	nodes	list of nodes

proc ::struct::graph::_nodes {name args} {

    # Discriminate between conditions and nodes

    set haveCond 0
    set haveKey 0
    set haveValue 0
    set cond "none"
    set condNodes [list]

    for {set i 0} {$i < [llength $args]} {incr i} {
	set arg [lindex $args $i]
	switch -glob -- $arg {
	    -in -
	    -out -
	    -adj -
	    -inner -
	    -embedding {
		if {$haveCond} {
		    return -code error "invalid restriction:\
			    illegal multiple use of\
			    \"-in\"|\"-out\"|\"-adj\"|\"-inner\"|\"-embedding\""
		}

		set haveCond 1
		set cond [string range $arg 1 end]
	    }
	    -key {
		if {$haveKey} {
		    return -code error {invalid restriction: illegal multiple use of "-key"}
		}

		incr i
		set key [lindex $args $i]
		set haveKey 1
	    }
	    -value {
		if {$haveValue} {
		    return -code error {invalid restriction: illegal multiple use of "-value"}
		}

		incr i
		set value [lindex $args $i]
		set haveValue 1
	    }
	    -* {
		error "invalid restriction \"$arg\": should be -in, -out,\
			-adj, -inner, -embedding, -key or -value"
	    }
	    default {
		lappend condNodes $arg
	    }
	}
    }

    # Validate that there are nodes to use in the restriction.
    # otherwise what's the point?
    if {$haveCond} {
	if {[llength $condNodes] == 0} {
	    set usage "$name nodes ?-key key? ?-value value? ?-in|-out|-adj|-inner|-embedding node node...?"
	    error "no nodes specified: should be \"$usage\""
	}

	# Make sure that the specified nodes exist!
	foreach node $condNodes {
	    if { ![__node_exists $name $node] } {
		error "node \"$node\" does not exist in graph \"$name\""
	    }
	}
    }

    # Now we are able to go to work
    upvar ::struct::graph::graph${name}::inArcs   inArcs
    upvar ::struct::graph::graph${name}::outArcs  outArcs
    upvar ::struct::graph::graph${name}::arcNodes arcNodes

    set       nodes [list]
    array set coll  {}

    switch -exact -- $cond {
	in {
	    # Result is all nodes with at least one arc going to
	    # at least one node in the list of arguments.

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {[info exists coll($n)]} {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
	    }
	}
	out {
	    # Result is all nodes with at least one arc coming from
	    # at least one node in the list of arguments.

	    foreach node $condNodes {
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {[info exists coll($n)]} {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
	    }
	}
	adj {
	    # Result is all nodes with at least one arc coming from
	    # or going to at least one node in the list of arguments.

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {[info exists coll($n)]} {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {[info exists coll($n)]} {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
	    }
	}
	inner {
	    # Result is all nodes from the list! with at least one arc
	    # coming from or going to at least one node in the list of
	    # arguments.

	    array set group {}
	    foreach node $condNodes {
		set group($node) .
	    }

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {![info exists group($n)]} {continue}
		    if { [info exists coll($n)]}  {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {![info exists group($n)]} {continue}
		    if { [info exists coll($n)]}  {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
	    }
	}
	embedding {
	    # Result is all nodes with at least one arc coming from
	    # or going to at least one node in the list of arguments,
	    # but not in the list itself!

	    array set group {}
	    foreach node $condNodes {
		set group($node) .
	    }

	    foreach node $condNodes {
		foreach e $inArcs($node) {
		    set n [lindex $arcNodes($e) 0]
		    if {[info exists group($n)]} {continue}
		    if {[info exists coll($n)]}  {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
		foreach e $outArcs($node) {
		    set n [lindex $arcNodes($e) 1]
		    if {[info exists group($n)]} {continue}
		    if {[info exists coll($n)]}  {continue}
		    lappend nodes    $n
		    set     coll($n) .
		}
	    }
	}
	none {
	    set nodes [array names inArcs]
	}
	default {error "Can't happen, panic"}
    }

    #
    # We have a list of nodes that match the relation to the nodes.
    # Now filter according to -key and -value.
    #

    set filteredNodes [list]

    if {$haveKey} {
	foreach node $nodes {
	    catch {
		set nval [__node_get $name $node -key $key]
		if {$haveValue} {
		    if {$nval == $value} {
			lappend filteredNodes $node
		    }
		} else {
		    lappend filteredNodes $node
		}
	    }
	}
    } else {
	set filteredNodes $nodes
    }

    return $filteredNodes
}

# ::struct::graph::_set --
#
#	Set or get a keyed value from the graph itself
#
# Arguments:
#	name	name of the graph.
#	flag	-key; anything else is an error
#	args	?-key key? ?value?
#
# Results:
#	value	value associated with the key given.

proc ::struct::graph::_set {name args} {
    upvar ::struct::graph::graph${name}::graphData data

    if { [llength $args] > 3 } {
	error "wrong # args: should be \"$name set ?-key key?\
		?value?\""
    }

    set key "data"
    set haveValue 0
    if { [llength $args] > 1 } {
	foreach {flag key} $args break
	if { ![string match "${flag}*" "-key"] } {
	    error "invalid option \"$flag\": should be key"
	}
	if { [llength $args] == 3 } {
	    set haveValue 1
	    set value [lindex $args end]
	}
    } elseif { [llength $args] == 1 } {
	set haveValue 1
	set value [lindex $args end]
    }

    if { $haveValue } {
	# Setting a value
	return [set data($key) $value]
    } else {
	# Getting a value
	if { ![info exists data($key)] } {
	    error "invalid key \"$key\" for graph \"$name\""
	}
	return $data($key)
    }
}

# ::struct::graph::_swap --
#
#	Swap two nodes in a graph.
#
# Arguments:
#	name	name of the graph.
#	node1	first node to swap.
#	node2	second node to swap.
#
# Results:
#	None.

proc ::struct::graph::_swap {name node1 node2} {
    # Can only swap two real nodes
    if { ![__node_exists $name $node1] } {
	error "node \"$node1\" does not exist in graph \"$name\""
    }
    if { ![__node_exists $name $node2] } {
	error "node \"$node2\" does not exist in graph \"$name\""
    }

    # Can't swap a node with itself
    if { [string equal $node1 $node2] } {
	error "cannot swap node \"$node1\" with itself"
    }

    # Swapping nodes means swapping their labels, values and arcs
    upvar ::struct::graph::graph${name}::outArcs      outArcs
    upvar ::struct::graph::graph${name}::inArcs       inArcs
    upvar ::struct::graph::graph${name}::arcNodes     arcNodes
    upvar ::struct::graph::graph${name}::node${node1} node1Vals
    upvar ::struct::graph::graph${name}::node${node2} node2Vals

    # Redirect arcs to the new nodes.

    foreach e $inArcs($node1) {
	set arcNodes($e) [lreplace $arcNodes($e) end end $node2]
    }
    foreach e $inArcs($node2) {
	set arcNodes($e) [lreplace $arcNodes($e) end end $node1]
    }
    foreach e $outArcs($node1) {
	set arcNodes($e) [lreplace $arcNodes($e) 0 0 $node2]
    }
    foreach e $outArcs($node2) {
	set arcNodes($e) [lreplace $arcNodes($e) 0 0 $node1]
    }

    # Swap arc lists

    set tmp            $inArcs($node1)
    set inArcs($node1) $inArcs($node2)
    set inArcs($node2) $tmp

    set tmp             $outArcs($node1)
    set outArcs($node1) $outArcs($node2)
    set outArcs($node2) $tmp

    # Swap the values
    set   value1        [array get node1Vals]
    unset node1Vals
    array set node1Vals [array get node2Vals]
    unset node2Vals
    array set node2Vals $value1

    return
}

# ::struct::graph::_unset --
#
#	Remove a keyed value from the graph itself
#
# Arguments:
#	name	name of the graph.
#	flag	-key; anything else is an error
#	args	additional args: ?-key key?
#
# Results:
#	None.

proc ::struct::graph::_unset {name {flag -key} {key data}} {
    upvar ::struct::graph::graph${name}::graphData data
    
    if { ![string match "${flag}*" "-key"] } {
	error "invalid option \"$flag\": should be \"$name unset\
		?-key key?\""
    }

    if { [info exists data($key)] } {
	unset data($key)
    }

    return
}

# ::struct::graph::_walk --
#
#	Walk a graph using a pre-order depth or breadth first
#	search. Pre-order DFS is the default.  At each node that is visited,
#	a command will be called with the name of the graph and the node.
#
# Arguments:
#	name	name of the graph.
#	node	node at which to start.
#	args	additional args: ?-order pre|post|both? ?-type {bfs|dfs}?
#		-command cmd
#
# Results:
#	None.

proc ::struct::graph::_walk {name node args} {
    set usage "$name walk $node ?-dir forward|backward?\
	    ?-order pre|post|both? ?-type {bfs|dfs}? -command cmd"

    if {[llength $args] > 8 || [llength $args] < 2} {
	error "wrong # args: should be \"$usage\""
    }

    if { ![__node_exists $name $node] } {
	error "node \"$node\" does not exist in graph \"$name\""
    }

    # Set defaults
    set type  dfs
    set order pre
    set cmd   ""
    set dir   forward

    # Process specified options
    for {set i 0} {$i < [llength $args]} {incr i} {
	set flag [lindex $args $i]
	incr i
	if { $i >= [llength $args] } {
	    error "value for \"$flag\" missing: should be \"$usage\""
	}
	switch -glob -- $flag {
	    "-type" {
		set type [string tolower [lindex $args $i]]
	    }
	    "-order" {
		set order [string tolower [lindex $args $i]]
	    }
	    "-command" {
		set cmd [lindex $args $i]
	    }
	    "-dir" {
		set dir [string tolower [lindex $args $i]]
	    }
	    default {
		error "unknown option \"$flag\": should be \"$usage\""
	    }
	}
    }
    
    # Make sure we have a command to run, otherwise what's the point?
    if { [string equal $cmd ""] } {
	error "no command specified: should be \"$usage\""
    }

    # Validate that the given type is good
    switch -glob -- $type {
	"dfs" {
	    set type "dfs"
	}
	"bfs" {
	    set type "bfs"
	}
	default {
	    error "invalid search type \"$type\": should be dfs, or bfs"
	}
    }
    
    # Validate that the given order is good
    switch -glob -- $order {
	"both" {
	    set order both
	}
	"pre" {
	    set order pre
	}
	"post" {
	    set order post
	}
	default {
	    error "invalid search order \"$order\": should be both,\
		    pre or post"
	}
    }

    # Validate that the given direction is good
    switch -glob -- $dir {
	"forward" {
	    set dir -out
	}
	"backward" {
	    set dir -in
	}
	default {
	    error "invalid search direction \"$dir\": should be\
		    forward or backward"
	}
    }

    # Do the walk

    set st [list ]
    lappend st $node
    array set visited {}

    if { [string equal $type "dfs"] } {
	if { [string equal $order "pre"] } {
	    # Pre-order Depth-first search

	    while { [llength $st] > 0 } {
		set node [lindex   $st end]
		set st   [lreplace $st end end]

		# Evaluate the command at this node
		set cmdcpy $cmd
		lappend cmdcpy enter $name $node
		uplevel 2 $cmdcpy

		set visited($node) .

		# Add this node's neighbours (according to direction)
		#  Have to add them in reverse order
		#  so that they will be popped left-to-right

		set next [_nodes $name $dir $node]
		set len  [llength $next]

		for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
		    set nextnode [lindex $next $i]
		    if {[info exists visited($nextnode)]} {
			# Skip nodes already visited
			continue
		    }
		    lappend st $nextnode
		}
	    }
	} elseif { [string equal $order "post"] } {
	    # Post-order Depth-first search

	    while { [llength $st] > 0 } {
		set node [lindex $st end]

		if {[info exists visited($node)]} {
		    # Second time we are here, pop it,
		    # then evaluate the command.

		    set st [lreplace $st end end]

		    # Evaluate the command at this node
		    set cmdcpy $cmd
		    lappend cmdcpy leave $name $node
		    uplevel 2 $cmdcpy
		} else {
		    # First visit. Remember it.
		    set visited($node) .
	    
		    # Add this node's neighbours.
		    set next [_nodes $name $dir $node]
		    set len  [llength $next]

		    for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
			set nextnode [lindex $next $i]
			if {[info exists visited($nextnode)]} {
			    # Skip nodes already visited
			    continue
			}
			lappend st $nextnode
		    }
		}
	    }
	} else {
	    # Both-order Depth-first search

	    while { [llength $st] > 0 } {
		set node [lindex $st end]

		if {[info exists visited($node)]} {
		    # Second time we are here, pop it,
		    # then evaluate the command.

		    set st [lreplace $st end end]

		    # Evaluate the command at this node
		    set cmdcpy $cmd
		    lappend cmdcpy leave $name $node
		    uplevel 2 $cmdcpy
		} else {
		    # First visit. Remember it.
		    set visited($node) .

		    # Evaluate the command at this node
		    set cmdcpy $cmd
		    lappend cmdcpy enter $name $node
		    uplevel 2 $cmdcpy
	    
		    # Add this node's neighbours.
		    set next [_nodes $name $dir $node]
		    set len  [llength $next]

		    for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
			set nextnode [lindex $next $i]
			if {[info exists visited($nextnode)]} {
			    # Skip nodes already visited
			    continue
			}
			lappend st $nextnode
		    }
		}
	    }
	}

    } else {
	if { [string equal $order "pre"] } {
	    # Pre-order Breadth first search
	    while { [llength $st] > 0 } {
		set node [lindex $st 0]
		set st   [lreplace $st 0 0]
		# Evaluate the command at this node
		set cmdcpy $cmd
		lappend cmdcpy enter $name $node
		uplevel 2 $cmdcpy
	    
		set visited($node) .

		# Add this node's neighbours.
		foreach child [_nodes $name $dir $node] {
		    if {[info exists visited($child)]} {
			# Skip nodes already visited
			continue
		    }
		    lappend st $child
		}
	    }
	} else {
	    # Post-order Breadth first search
	    # Both-order Breadth first search
	    # Haven't found anything in Knuth
	    # and unable to define something
	    # consistent for myself. Leave it
	    # out.

	    error "unable to do a ${order}-order breadth first walk"
	}
    }
    return
}

# ::struct::graph::Union --
#
#	Return a list which is the union of the elements
#	in the specified lists.
#
# Arguments:
#	args	list of lists representing sets.
#
# Results:
#	set	list representing the union of the argument lists.

proc ::struct::graph::Union {args} {
    switch -- [llength $args] {
	0 {
	    return {}
	}
	1 {
	    return [lindex $args 0]
	}
	default {
	    foreach set $args {
		foreach e $set {
		    set tmp($e) .
		}
	    }
	    return [array names tmp]
	}
    }
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'graph::graph' into the general structure namespace.
    namespace import -force graph::graph
    namespace export graph
}
package provide struct::graph 1.2.1
