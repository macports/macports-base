# tree.tcl --
#
#	Implementation of a tree data structure for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: tree_tcl.tcl,v 1.5 2009/06/22 18:21:59 andreas_kupries Exp $

package require Tcl 8.2
package require struct::list

namespace eval ::struct::tree {
    # Data storage in the tree module
    # -------------------------------
    #
    # There's a lot of bits to keep track of for each tree:
    #	nodes
    #	node values
    #	node relationships
    #
    # It would quickly become unwieldy to try to keep these in arrays or lists
    # within the tree namespace itself.  Instead, each tree structure will get
    # its own namespace.  Each namespace contains:
    #	children	array mapping nodes to their children list
    #	parent		array mapping nodes to their parent node
    #	node:$node	array mapping keys to values for the node $node

    # counter is used to give a unique name for unnamed trees
    variable counter 0

    # Only export one command, the one used to instantiate a new tree
    namespace export tree_tcl
}

# ::struct::tree::tree_tcl --
#
#	Create a new tree with a given name; if no name is given, use
#	treeX, where X is a number.
#
# Arguments:
#	name	Optional name of the tree; if null or not given, generate one.
#
# Results:
#	name	Name of the tree created

proc ::struct::tree::tree_tcl {args} {
    variable counter

    set src     {}
    set srctype {}

    switch -exact -- [llength [info level 0]] {
	1 {
	    # Missing name, generate one.
	    incr counter
	    set name "tree${counter}"
	}
	2 {
	    # Standard call. New empty tree.
	    set name [lindex $args 0]
	}
	4 {
	    # Copy construction.
	    foreach {name as src} $args break
	    switch -exact -- $as {
		= - := - as {
		    set srctype tree
		}
		deserialize {
		    set srctype serial
		}
		default {
		    return -code error \
			    "wrong # args: should be \"tree ?name ?=|:=|as|deserialize source??\""
		}
	    }
	}
	default {
	    # Error.
	    return -code error \
		    "wrong # args: should be \"tree ?name ?=|:=|as|deserialize source??\""
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
    if {[llength [info commands $name]]} {
	return -code error \
		"command \"$name\" already exists, unable to create tree"
    }

    # Set up the namespace for the object,
    # identical to the object command.
    namespace eval $name {
	variable rootname
	set      rootname root

	# Set up root node's child list
	variable children
	set      children(root) [list]

	# Set root node's parent
	variable parent
	set      parent(root) [list]

	# Set up the node attribute mapping
	variable  attribute
	array set attribute {}

	# Set up a counter for use in creating unique node names
	variable nextUnusedNode
	set      nextUnusedNode 1

	# Set up a counter for use in creating node attribute arrays.
	variable nextAttr
	set      nextAttr 0
    }

    # Create the command to manipulate the tree
    interp alias {} $name {} ::struct::tree::TreeProc $name

    # Automatic execution of assignment if a source
    # is present.
    if {$src != {}} {
	switch -exact -- $srctype {
	    tree   {
		set code [catch {_= $name $src} msg]
		if {$code} {
		    namespace delete $name
		    interp alias {} $name {}
		    return -code $code -errorinfo $::errorInfo -errorcode $::errorCode $msg
		}
	    }
	    serial {
		set code [catch {_deserialize $name $src} msg]
		if {$code} {
		    namespace delete $name
		    interp alias {} $name {}
		    return -code $code -errorinfo $::errorInfo -errorcode $::errorCode $msg
		}
	    }
	    default {
		return -code error \
			"Internal error, illegal srctype \"$srctype\""
	    }
	}
    }

    # Give object to caller for use.
    return $name
}

# ::struct::tree::prune_tcl --
#
#	Abort the walk script, and ignore any children of the
#	node we are currently at.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Sideeffects:
#
#	Stops the execution of the script and throws a signal to the
#	surrounding walker to go to the next node, and ignore the
#	children of the current node.

proc ::struct::tree::prune_tcl {} {
    return -code 5
}

##########################
# Private functions follow

# ::struct::tree::TreeProc --
#
#	Command that processes all tree object commands.
#
# Arguments:
#	name	Name of the tree object to manipulate.
#	cmd	Subcommand to invoke.
#	args	Arguments for subcommand.
#
# Results:
#	Varies based on command to perform

proc ::struct::tree::TreeProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	return -code error "wrong # args: should be \"$name option ?arg arg ...?\""
    }

    # Split the args into command and args components
    set sub _$cmd
    if { [llength [info commands ::struct::tree::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::tree::_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 1 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }

    set code [catch {uplevel 1 [linsert $args 0 ::struct::tree::$sub $name]} result]

    if {$code == 1} {
	return -errorinfo [ErrorInfoAsCaller uplevel $sub]  \
		-errorcode $::errorCode -code error $result
    } elseif {$code == 2} {
	return -code $code $result
    }
    return $result
}

# ::struct::tree::_:= --
#
#	Assignment operator. Copies the source tree into the
#       destination, destroying the original information.
#
# Arguments:
#	name	Name of the tree object we are copying into.
#	source	Name of the tree object providing us with the
#		data to copy.
#
# Results:
#	Nothing.

proc ::struct::tree::_= {name source} {
    _deserialize $name [$source serialize]
    return
}

# ::struct::tree::_--> --
#
#	Reverse assignment operator. Copies this tree into the
#       destination, destroying the original information.
#
# Arguments:
#	name	Name of the tree object to copy
#	dest	Name of the tree object we are copying to.
#
# Results:
#	Nothing.

proc ::struct::tree::_--> {name dest} {
    $dest deserialize [_serialize $name]
    return
}

# ::struct::tree::_ancestors --
#
#	Return the list of all parent nodes of a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to look up.
#
# Results:
#	parents	List of parents of node $node.
#		Immediate ancestor (parent) first,
#		Root of tree (ancestor of all) last.

proc ::struct::tree::_ancestors {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::parent
    set a {}
    while {[info exists parent($node)]} {
	set node $parent($node)
	if {$node == {}} break
	lappend a $node
    }
    return $a
}

# ::struct::tree::_attr --
#
#	Return attribute data for one key and multiple nodes, possibly all.
#
# Arguments:
#	name	Name of the tree object.
#	key	Name of the attribute to retrieve.
#
# Results:
#	children	Dictionary mapping nodes to attribute data.

proc ::struct::tree::_attr {name key args} {
    # Syntax:
    #
    # t attr key
    # t attr key -nodes {nodelist}
    # t attr key -glob nodepattern
    # t attr key -regexp nodepattern

    variable ${name}::attribute

    set usage "wrong # args: should be \"[list $name] attr key ?-nodes list|-glob pattern|-regexp pattern?\""
    if {([llength $args] != 0) && ([llength $args] != 2)} {
	return -code error $usage
    } elseif {[llength $args] == 0} {
	# This automatically restricts the list
	# to nodes which can have the attribute
	# in question.

	set nodes [array names attribute]
    } else {
	# Determine a list of nodes to look at
	# based on the chosen restriction.

	foreach {mode value} $args break
	switch -exact -- $mode {
	    -nodes {
		# This is the only branch where we have to
		# perform an explicit restriction to the
		# nodes which have attributes.
		set nodes {}
		foreach n $value {
		    if {![info exists attribute($n)]} continue
		    lappend nodes $n
		}
	    }
	    -glob {
		set nodes [array names attribute $value]
	    }
	    -regexp {
		set nodes {}
		foreach n [array names attribute] {
		    if {![regexp -- $value $n]} continue
		    lappend nodes $n
		}
	    }
	    default {
		return -code error $usage
	    }
	}
    }

    # Without possibly matching nodes
    # the result has to be empty.

    if {![llength $nodes]} {
	return {}
    }

    # Now locate matching keys and their values.

    set result {}
    foreach n $nodes {
	upvar ${name}::$attribute($n) data
	if {[info exists data($key)]} {
	    lappend result $n $data($key)
	}
    }

    return $result
}

# ::struct::tree::_deserialize --
#
#	Assignment operator. Copies a serialization into the
#       destination, destroying the original information.
#
# Arguments:
#	name	Name of the tree object we are copying into.
#	serial	Serialized tree to copy from.
#
# Results:
#	Nothing.

proc ::struct::tree::_deserialize {name serial} {
    # As we destroy the original tree as part of
    # the copying process we don't have to deal
    # with issues like node names from the new tree
    # interfering with the old ...

    # I. Get the serialization of the source tree
    #    and check it for validity.

    CheckSerialization $serial attr p c rn

    # Get all the relevant data into the scope

    variable ${name}::rootname
    variable ${name}::children
    variable ${name}::parent
    variable ${name}::attribute
    variable ${name}::nextAttr

    # Kill the existing parent/children information and insert the new
    # data in their place.

    foreach n [array names parent] {
	unset parent($n) children($n)
    }
    array set parent   [array get p]
    array set children [array get c]
    unset p c

    set nextAttr 0
    foreach a [array names attribute] {
	unset ${name}::$attribute($a)
    }
    foreach n [array names attr] {
	GenAttributeStorage $name $n
	array set ${name}::$attribute($n) $attr($n)
    }

    set rootname $rn

    ## Debug ## Dump internals ...
    if {0} {
	puts "___________________________________ $name"
	puts $rootname
	parray children
	parray parent
	parray attribute
	puts ___________________________________
    }
    return
}

# ::struct::tree::_children --
#
#	Return the list of children for a given node of a tree.
#
# Arguments:
#	name	Name of the tree object.
#	node	Node to look up.
#
# Results:
#	children	List of children for the node.

proc ::struct::tree::_children {name args} {
    # args := ?-all? node ?filter cmdprefix?

    # '-all' implies that not only the direct children of the
    # node, but all their children, and so on, are returned.
    #
    # 'filter cmd' implies that only those nodes in the result list
    # which pass the test 'cmd' are placed into the final result. 

    set usage "wrong # args: should be \"[list $name] children ?-all? node ?filter cmd?\""

    if {([llength $args] < 1) || ([llength $args] > 4)} {
	return -code error $usage
    }
    if {[string equal [lindex $args 0] -all]} {
	set all 1
	set args [lrange $args 1 end]
    } else {
	set all 0
    }

    # args := node ?filter cmdprefix?

    if {([llength $args] != 1) && ([llength $args] != 3)} {
	return -code error $usage
    }
    if {[llength $args] == 3} {
	foreach {node _const_ cmd} $args break
	if {![string equal $_const_ filter] || ![llength $cmd]} {
	    return -code error $usage
	}
    } else {
	set node [lindex $args 0]
	set cmd {}
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    if {$all} {
	set result [DescendantsCore $name $node]
    } else {
	variable ${name}::children
	set result $children($node)
    }

    if {[llength $cmd]} {
	lappend cmd $name
	set result [uplevel 1 [list ::struct::list filter $result $cmd]]
    }

    return $result
}

# ::struct::tree::_cut --
#
#	Destroys the specified node of a tree, but not its children.
#	These children are made into children of the parent of the
#	destroyed node at the index of the destroyed node.
#
# Arguments:
#	name	Name of the tree object.
#	node	Node to look up and cut.
#
# Results:
#	None.

proc ::struct::tree::_cut {name node} {
    variable ${name}::rootname

    if { [string equal $node $rootname] } {
	# Can't delete the special root node
	return -code error "cannot cut root node"
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::parent
    variable ${name}::children

    # Locate our parent, children and our location in the parent
    set parentNode $parent($node)
    set childNodes $children($node)

    set index [lsearch -exact $children($parentNode) $node]

    # Excise this node from the parent list,
    set newChildren [lreplace $children($parentNode) $index $index]

    # Put each of the children of $node into the parent's children list,
    # in the place of $node, and update the parent pointer of those nodes.
    foreach child $childNodes {
	set newChildren [linsert $newChildren $index $child]
	set parent($child) $parentNode
	incr index
    }
    set children($parentNode) $newChildren

    KillNode $name $node
    return
}

# ::struct::tree::_delete --
#
#	Remove a node from a tree, including all of its values.  Recursively
#	removes the node's children.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to delete.
#
# Results:
#	None.

proc ::struct::tree::_delete {name node} {
    variable ${name}::rootname
    if { [string equal $node $rootname] } {
	# Can't delete the special root node
	return -code error "cannot delete root node"
    }
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    variable ${name}::parent

    # Remove this node from its parent's children list
    set parentNode $parent($node)
    set index [lsearch -exact $children($parentNode) $node]
    ldelete children($parentNode) $index

    # Yes, we could use the stack structure implemented in ::struct::stack,
    # but it's slower than inlining it.  Since we don't need a sophisticated
    # stack, don't bother.
    set st [list]
    foreach child $children($node) {
	lappend st $child
    }

    KillNode $name $node

    while {[llength $st] > 0} {
	set node [lindex $st end]
	ldelete           st end
	foreach child $children($node) {
	    lappend st $child
	}

	KillNode $name $node
    }
    return
}

# ::struct::tree::_depth --
#
#	Return the depth (distance from the root node) of a given node.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to find.
#
# Results:
#	depth	Number of steps from node to the root node.

proc ::struct::tree::_depth {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    variable ${name}::parent
    variable ${name}::rootname
    set depth 0
    while { ![string equal $node $rootname] } {
	incr depth
	set node $parent($node)
    }
    return $depth
}

# ::struct::tree::_descendants --
#
#	Return the list containing all descendants of a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to look at.
#
# Results:
#	desc	(filtered) List of nodes descending from 'node'.

proc ::struct::tree::_descendants {name node args} {
    # children -all sucessor, allows filtering.

    set usage "wrong # args: should be \"[list $name] descendants node ?filter cmd?\""

    if {[llength $args] > 2} {
	return -code error $usage
    } elseif {[llength $args] == 2} {
	foreach {_const_ cmd} $args break
	if {![string equal $_const_ filter] || ![llength $cmd]} {
	    return -code error $usage
	}
    } else {
	set cmd {}
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    set result [DescendantsCore $name $node]

    if {[llength $cmd]} {
	lappend cmd $name
	set result [uplevel 1 [list ::struct::list filter $result $cmd]]
    }

    return $result
}

proc ::struct::tree::DescendantsCore {name node} {
    # CORE for listing of node descendants.
    # No checks ...
    # No filtering ...

    variable ${name}::children

    # New implementation. Instead of keeping a second, and explicit,
    # list of pending nodes to shift through (= copying of array data
    # around), we reuse the result list for that, using a counter and
    # direct access to list elements to keep track of what nodes have
    # not been handled yet. This eliminates a whole lot of array
    # copying within the list implementation in the Tcl core. The
    # result is unchanged, i.e. the nodes are in the same order as
    # before.

    set result  $children($node)
    set at      0

    while {$at < [llength $result]} {
	set n [lindex $result $at]
	incr at
	foreach c $children($n) {
	    lappend result $c
	}
    }

    return $result
}

# ::struct::tree::_destroy --
#
#	Destroy a tree, including its associated command and data storage.
#
# Arguments:
#	name	Name of the tree to destroy.
#
# Results:
#	None.

proc ::struct::tree::_destroy {name} {
    namespace delete $name
    interp alias {} $name {}
}

# ::struct::tree::_exists --
#
#	Test for existence of a given node in a tree.
#
# Arguments:
#	name	Name of the tree to query.
#	node	Node to look for.
#
# Results:
#	1 if the node exists, 0 else.

proc ::struct::tree::_exists {name node} {
    return [info exists ${name}::parent($node)]
}

# ::struct::tree::_get --
#
#	Get a keyed value from a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to query.
#	key	Key to lookup.
#
# Results:
#	value	Value associated with the key given.

proc ::struct::tree::_get {name node key} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node, key has to be invalid.
	return -code error "invalid key \"$key\" for node \"$node\""
    }

    upvar ${name}::$attribute($node) data
    if {![info exists data($key)]} {
	return -code error "invalid key \"$key\" for node \"$node\""
    }
    return $data($key)
}

# ::struct::tree::_getall --
#
#	Get a serialized list of key/value pairs from a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to query.
#
# Results:
#	value	A serialized list of key/value pairs.

proc ::struct::tree::_getall {name node {pattern *}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attributes ...
	return {}
    }

    upvar ${name}::$attribute($node) data
    return [array get data $pattern]
}

# ::struct::tree::_height --
#
#	Return the height (distance from the given node to its deepest child)
#
# Arguments:
#	name	Name of the tree.
#	node	Node we wish to know the height for..
#
# Results:
#	height	Distance to deepest child of the node.

proc ::struct::tree::_height {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    variable ${name}::parent

    if {[llength $children($node)] == 0} {
	# No children, is a leaf, height is 0.
	return 0
    }

    # New implementation. We iteratively compute the height for each
    # node under the specified one, from the bottom up. The previous
    # implementation, using recursion will fail if the encountered
    # subtree has a height greater than the currently set recursion
    # limit.

    array set h {}

    # NOTE: Check out if a for loop doing direct access, i.e. without
    #       list reversal, is faster.

    foreach n [struct::list reverse [DescendantsCore $name $node]] {
	# Height of leafs
	if {![llength $children($n)]} {set h($n) 0}

	# Height of our parent is max of our and previous height.
	set p $parent($n)
	if {![info exists h($p)] || ($h($n) >= $h($p))} {
	    set h($p) [expr {$h($n) + 1}]
	}
    }

    # NOTE: Check out how much we gain by caching the result.
    #       For all nodes we have this computed. Use cache here
    #       as well to cut the inspection of descendants down.
    #       This may degenerate into a recursive solution again
    #       however.

    return $h($node)
}

# ::struct::tree::_keys --
#
#	Get a list of keys from a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to query.
#
# Results:
#	value	A serialized list of key/value pairs.

proc ::struct::tree::_keys {name node {pattern *}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node.
	return {}
    }

    upvar ${name}::$attribute($node) data
    return [array names data $pattern]
}

# ::struct::tree::_keyexists --
#
#	Test for existence of a given key for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to query.
#	key	Key to lookup.
#
# Results:
#	1 if the key exists, 0 else.

proc ::struct::tree::_keyexists {name node key} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node, key cannot exist
	return 0
    }

    upvar ${name}::$attribute($node) data
    return [info exists data($key)]
}

# ::struct::tree::_index --
#
#	Determine the index of node with in its parent's list of children.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to look up.
#
# Results:
#	index	The index of the node in its parent

proc ::struct::tree::_index {name node} {
    variable ${name}::rootname
    if { [string equal $node $rootname] } {
	# The special root node has no parent, thus no index in it either.
	return -code error "cannot determine index of root node"
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    variable ${name}::parent

    # Locate the parent and ourself in its list of children
    set parentNode $parent($node)

    return [lsearch -exact $children($parentNode) $node]
}

# ::struct::tree::_insert --
#
#	Add a node to a tree; if the node(s) specified already exist, they
#	will be moved to the given location.
#
# Arguments:
#	name		Name of the tree.
#	parentNode	Parent to add the node to.
#	index		Index at which to insert.
#	args		Node(s) to insert.  If none is given, the routine
#			will insert a single node with a unique name.
#
# Results:
#	nodes		List of nodes inserted.

proc ::struct::tree::_insert {name parentNode index args} {
    if { [llength $args] == 0 } {
	# No node name was given; generate a unique one
	set args [list [GenerateUniqueNodeName $name]]
    }
    if { ![_exists $name $parentNode] } {
	return -code error "parent node \"$parentNode\" does not exist in tree \"$name\""
    }

    variable ${name}::parent
    variable ${name}::children
    variable ${name}::rootname

    # Make sure the index is numeric

    if {[string equal $index "end"]} {
	set index [llength $children($parentNode)]
    } elseif {[regexp {^end-([0-9]+)$} $index -> n]} {
	set index [expr {[llength $children($parentNode)] - $n}]
    }

    foreach node $args {
	if {[_exists $name $node] } {
	    # Move the node to its new home
	    if { [string equal $node $rootname] } {
		return -code error "cannot move root node"
	    }
	
	    # Cannot make a node its own descendant (I'm my own grandpa...)
	    set ancestor $parentNode
	    while { ![string equal $ancestor $rootname] } {
		if { [string equal $ancestor $node] } {
		    return -code error "node \"$node\" cannot be its own descendant"
		}
		set ancestor $parent($ancestor)
	    }
	    # Remove this node from its parent's children list
	    set oldParent $parent($node)
	    set ind [lsearch -exact $children($oldParent) $node]
	    ldelete children($oldParent) $ind
	
	    # If the node is moving within its parent, and its old location
	    # was before the new location, decrement the new location, so that
	    # it gets put in the right spot
	    if { [string equal $oldParent $parentNode] && $ind < $index } {
		incr index -1
	    }
	} else {
	    # Set up the new node
	    set children($node) [list]
	}

	# Add this node to its parent's children list
	set children($parentNode) [linsert $children($parentNode) $index $node]

	# Update the parent pointer for this node
	set parent($node) $parentNode
	incr index
    }

    return $args
}

# ::struct::tree::_isleaf --
#
#	Return whether the given node of a tree is a leaf or not.
#
# Arguments:
#	name	Name of the tree object.
#	node	Node to look up.
#
# Results:
#	isleaf	True if the node is a leaf; false otherwise.

proc ::struct::tree::_isleaf {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    return [expr {[llength $children($node)] == 0}]
}

# ::struct::tree::_move --
#
#	Move a node (and all its subnodes) from where ever it is to a new
#	location in the tree.
#
# Arguments:
#	name		Name of the tree
#	parentNode	Parent to add the node to.
#	index		Index at which to insert.
#	node		Node to move; the node must exist in the tree.
#	args		Additional nodes to move; these nodes must exist
#			in the tree.
#
# Results:
#	None.

proc ::struct::tree::_move {name parentNode index node args} {
    set args [linsert $args 0 $node]

    # Can only move a node to a real location in the tree
    if { ![_exists $name $parentNode] } {
	return -code error "parent node \"$parentNode\" does not exist in tree \"$name\""
    }

    variable ${name}::parent
    variable ${name}::children
    variable ${name}::rootname

    # Make sure the index is numeric

    if {[string equal $index "end"]} {
	set index [llength $children($parentNode)]
    } elseif {[regexp {^end-([0-9]+)$} $index -> n]} {
	set index [expr {[llength $children($parentNode)] - $n}]
    }

    # Validate all nodes to move before trying to move any.
    foreach node $args {
	if { [string equal $node $rootname] } {
	    return -code error "cannot move root node"
	}

	# Can only move real nodes
	if { ![_exists $name $node] } {
	    return -code error "node \"$node\" does not exist in tree \"$name\""
	}

	# Cannot move a node to be a descendant of itself
	set ancestor $parentNode
	while { ![string equal $ancestor $rootname] } {
	    if { [string equal $ancestor $node] } {
		return -code error "node \"$node\" cannot be its own descendant"
	    }
	    set ancestor $parent($ancestor)
	}
    }

    # Remove all nodes from their current parent's children list
    foreach node $args {
	set oldParent $parent($node)
	set ind [lsearch -exact $children($oldParent) $node]

	ldelete children($oldParent) $ind

	# Update the nodes parent value
	set parent($node) $parentNode
    }

    # Add all nodes to their new parent's children list
    set children($parentNode) \
	[eval [list linsert $children($parentNode) $index] $args]

    return
}

# ::struct::tree::_next --
#
#	Return the right sibling for a given node of a tree.
#
# Arguments:
#	name		Name of the tree object.
#	node		Node to retrieve right sibling for.
#
# Results:
#	sibling		The right sibling for the node, or null if node was
#			the rightmost child of its parent.

proc ::struct::tree::_next {name node} {
    # The 'root' has no siblings.
    variable ${name}::rootname
    if { [string equal $node $rootname] } {
	return {}
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    # Locate the parent and our place in its list of children.
    variable ${name}::parent
    variable ${name}::children

    set parentNode $parent($node)
    set  index [lsearch -exact $children($parentNode) $node]

    # Go to the node to the right and return its name.
    return [lindex $children($parentNode) [incr index]]
}

# ::struct::tree::_numchildren --
#
#	Return the number of immediate children for a given node of a tree.
#
# Arguments:
#	name		Name of the tree object.
#	node		Node to look up.
#
# Results:
#	numchildren	Number of immediate children for the node.

proc ::struct::tree::_numchildren {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    return [llength $children($node)]
}

# ::struct::tree::_nodes --
#
#	Return a list containing all nodes known to the tree.
#
# Arguments:
#	name		Name of the tree object.
#
# Results:
#	nodes	List of nodes in the tree.

proc ::struct::tree::_nodes {name} {
    variable ${name}::children
    return [array names children]
}

# ::struct::tree::_parent --
#
#	Return the name of the parent node of a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to look up.
#
# Results:
#	parent	Parent of node $node

proc ::struct::tree::_parent {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    # FRINK: nocheck
    return [set ${name}::parent($node)]
}

# ::struct::tree::_previous --
#
#	Return the left sibling for a given node of a tree.
#
# Arguments:
#	name		Name of the tree object.
#	node		Node to look up.
#
# Results:
#	sibling		The left sibling for the node, or null if node was
#			the leftmost child of its parent.

proc ::struct::tree::_previous {name node} {
    # The 'root' has no siblings.
    variable ${name}::rootname
    if { [string equal $node $rootname] } {
	return {}
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    # Locate the parent and our place in its list of children.
    variable ${name}::parent
    variable ${name}::children

    set parentNode $parent($node)
    set  index [lsearch -exact $children($parentNode) $node]

    # Go to the node to the right and return its name.
    return [lindex $children($parentNode) [incr index -1]]
}

# ::struct::tree::_rootname --
#
#	Query or change the name of the root node.
#
# Arguments:
#	name	Name of the tree.
#
# Results:
#	The name of the root node

proc ::struct::tree::_rootname {name} {
    variable ${name}::rootname
    return $rootname
}

# ::struct::tree::_rename --
#
#	Change the name of any node.
#
# Arguments:
#	name	Name of the tree.
#	node	Name of node to be renamed
#	newname	New name for the node.
#
# Results:
#	The new name of the node.

proc ::struct::tree::_rename {name node newname} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {[_exists $name $newname]} {
	return -code error "unable to rename node to \"$newname\",\
		node of that name already present in the tree \"$name\""
    }

    set oldname  $node

    # Perform the rename in the internal
    # data structures.

    variable ${name}::rootname
    variable ${name}::children
    variable ${name}::parent
    variable ${name}::attribute

    set children($newname) $children($oldname)
    unset                   children($oldname)
    set parent($newname)     $parent($oldname)
    unset                     parent($oldname)

    foreach c $children($newname) {
	set parent($c) $newname
    }

    if {[string equal $oldname $rootname]} {
	set rootname $newname
    } else {
	set p $parent($newname)
	set pos  [lsearch -exact $children($p) $oldname]
	lset children($p) $pos $newname
    }

    if {[info exists attribute($oldname)]} {
	set attribute($newname) $attribute($oldname)
	unset                    attribute($oldname)
    }

    return $newname
}

# ::struct::tree::_serialize --
#
#	Serialize a tree object (partially) into a transportable value.
#
# Arguments:
#	name	Name of the tree.
#	node	Root node of the serialized tree.
#
# Results:
#	A list structure describing the part of the tree which was serialized.

proc ::struct::tree::_serialize {name args} {
    if {[llength $args] > 1} {
	return -code error \
		"wrong # args: should be \"[list $name] serialize ?node?\""
    } elseif {[llength $args] == 1} {
	set node [lindex $args 0]

	if {![_exists $name $node]} {
	    return -code error "node \"$node\" does not exist in tree \"$name\""
	}
    } else {
	variable ${name}::rootname
	set node $rootname
    }

    set                   tree [list]
    Serialize $name $node tree
    return               $tree
}

# ::struct::tree::_set --
#
#	Set or get a value for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify or query.
#	args	Optional argument specifying a value.
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_set {name node key args} {
    if {[llength $args] > 1} {
	return -code error "wrong # args: should be \"$name set node key\
		?value?\""
    }
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    # Process the arguments ...

    if {[llength $args] > 0} {
	# Setting the value. This may have to create
	# the attribute array for this particular
	# node

	variable ${name}::attribute
	if {![info exists attribute($node)]} {
	    # No attribute data for this node,
	    # so create it as we need it now.
	    GenAttributeStorage $name $node
	}
	upvar ${name}::$attribute($node) data

	return [set data($key) [lindex $args end]]
    } else {
	# Getting the value

	return [_get $name $node $key]
    }
}

# ::struct::tree::_append --
#
#	Append a value for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify.
#	key	Name of attribute to modify.
#	value	Value to append
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_append {name node key value} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# so create it as we need it.
	GenAttributeStorage $name $node
    }

    upvar ${name}::$attribute($node) data
    return [append data($key) $value]
}

# ::struct::tree::_lappend --
#
#	lappend a value for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify or query.
#	key	Name of attribute to modify.
#	value	Value to append
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_lappend {name node key value} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# so create it as we need it.
	GenAttributeStorage $name $node
    }

    upvar ${name}::$attribute($node) data
    return [lappend data($key) $value]
}

# ::struct::tree::_leaves --
#
#	Return a list containing all leaf nodes known to the tree.
#
# Arguments:
#	name		Name of the tree object.
#
# Results:
#	nodes	List of leaf nodes in the tree.

proc ::struct::tree::_leaves {name} {
    variable ${name}::children

    set res {}
    foreach n [array names children] {
	if {[llength $children($n)]} continue
	lappend res $n
    }
    return $res
}

# ::struct::tree::_size --
#
#	Return the number of descendants of a given node.  The default node
#	is the special root node.
#
# Arguments:
#	name	Name of the tree.
#	node	Optional node to start counting from (default is root).
#
# Results:
#	size	Number of descendants of the node.

proc ::struct::tree::_size {name args} {
    variable ${name}::rootname
    if {[llength $args] > 1} {
	return -code error \
		"wrong # args: should be \"[list $name] size ?node?\""
    } elseif {[llength $args] == 1} {
	set node [lindex $args 0]

	if { ![_exists $name $node] } {
	    return -code error "node \"$node\" does not exist in tree \"$name\""
	}
    } else {
	# If the node is the root, we can do the cheap thing and just count the
	# number of nodes (excluding the root node) that we have in the tree with
	# array size.

	return [expr {[array size ${name}::parent] - 1}]
    }

    # If the node is the root, we can do the cheap thing and just count the
    # number of nodes (excluding the root node) that we have in the tree with
    # array size.

    if { [string equal $node $rootname] } {
	return [expr {[array size ${name}::parent] - 1}]
    }

    # Otherwise we have to do it the hard way and do a full tree search
    variable ${name}::children
    set size 0
    set st [list ]
    foreach child $children($node) {
	lappend st $child
    }
    while { [llength $st] > 0 } {
	set node [lindex $st end]
	ldelete st end
	incr size
	foreach child $children($node) {
	    lappend st $child
	}
    }
    return $size
}

# ::struct::tree::_splice --
#
#	Add a node to a tree, making a range of children from the given
#	parent children of the new node.
#
# Arguments:
#	name		Name of the tree.
#	parentNode	Parent to add the node to.
#	from		Index at which to insert.
#	to		Optional end of the range of children to replace.
#			Defaults to 'end'.
#	args		Optional node name; if given, must be unique.  If not
#			given, a unique name will be generated.
#
# Results:
#	node		Name of the node added to the tree.

proc ::struct::tree::_splice {name parentNode from {to end} args} {

    if { ![_exists $name $parentNode] } {
	return -code error "node \"$parentNode\" does not exist in tree \"$name\""
    }

    if { [llength $args] == 0 } {
	# No node name given; generate a unique node name
	set node [GenerateUniqueNodeName $name]
    } else {
	set node [lindex $args 0]
    }

    if { [_exists $name $node] } {
	return -code error "node \"$node\" already exists in tree \"$name\""
    }

    variable ${name}::children
    variable ${name}::parent

    if {[string equal $from "end"]} {
	set from [expr {[llength $children($parentNode)] - 1}]
    } elseif {[regexp {^end-([0-9]+)$} $from -> n]} {
	set from [expr {[llength $children($parentNode)] - 1 - $n}]
    }
    if {[string equal $to "end"]} {
	set to [expr {[llength $children($parentNode)] - 1}]
    } elseif {[regexp {^end-([0-9]+)$} $to -> n]} {
	set to   [expr {[llength $children($parentNode)] - 1 - $n}]
    }

    # Save the list of children that are moving
    set moveChildren [lrange $children($parentNode) $from $to]

    # Remove those children from the parent
    ldelete children($parentNode) $from $to

    # Add the new node
    _insert $name $parentNode $from $node

    # Move the children
    set children($node) $moveChildren
    foreach child $moveChildren {
	set parent($child) $node
    }

    return $node
}

# ::struct::tree::_swap --
#
#	Swap two nodes in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node1	First node to swap.
#	node2	Second node to swap.
#
# Results:
#	None.

proc ::struct::tree::_swap {name node1 node2} {
    # Can't swap the magic root node
    variable ${name}::rootname
    if {[string equal $node1 $rootname] || [string equal $node2 $rootname]} {
	return -code error "cannot swap root node"
    }

    # Can only swap two real nodes
    if {![_exists $name $node1]} {
	return -code error "node \"$node1\" does not exist in tree \"$name\""
    }
    if {![_exists $name $node2]} {
	return -code error "node \"$node2\" does not exist in tree \"$name\""
    }

    # Can't swap a node with itself
    if {[string equal $node1 $node2]} {
	return -code error "cannot swap node \"$node1\" with itself"
    }

    # Swapping nodes means swapping their labels and values
    variable ${name}::children
    variable ${name}::parent

    set parent1 $parent($node1)
    set parent2 $parent($node2)

    # Replace node1 with node2 in node1's parent's children list, and
    # node2 with node1 in node2's parent's children list
    set i1 [lsearch -exact $children($parent1) $node1]
    set i2 [lsearch -exact $children($parent2) $node2]

    lset children($parent1) $i1 $node2
    lset children($parent2) $i2 $node1

    # Make node1 the parent of node2's children, and vis versa
    foreach child $children($node2) {
	set parent($child) $node1
    }
    foreach child $children($node1) {
	set parent($child) $node2
    }

    # Swap the children lists
    set children1 $children($node1)
    set children($node1) $children($node2)
    set children($node2) $children1

    if { [string equal $node1 $parent2] } {
	set parent($node1) $node2
	set parent($node2) $parent1
    } elseif { [string equal $node2 $parent1] } {
	set parent($node1) $parent2
	set parent($node2) $node1
    } else {
	set parent($node1) $parent2
	set parent($node2) $parent1
    }

    return
}

# ::struct::tree::_unset --
#
#	Remove a keyed value from a node.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify.
#	key	Name of attribute to unset.
#
# Results:
#	None.

proc ::struct::tree::_unset {name node key} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# nothing to do.
	return
    }

    upvar ${name}::$attribute($node) data
    catch {unset data($key)}

    if {[array size data] == 0} {
	# No attributes stored for this node, squash the whole array.
	unset attribute($node)
	unset data
    }
    return
}

# ::struct::tree::_walk --
#
#	Walk a tree using a pre-order depth or breadth first
#	search. Pre-order DFS is the default.  At each node that is visited,
#	a command will be called with the name of the tree and the node.
#
# Arguments:
#	name	Name of the tree.
#	node	Node at which to start.
#	args	Optional additional arguments specifying the type and order of
#		the tree walk, and the command to execute at each node.
#		Format is
#		    ?-type {bfs|dfs}? ?-order {pre|post|in|both}? a n script
#
# Results:
#	None.

proc ::struct::tree::_walk {name node args} {
    set usage "$name walk node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? loopvar script"

    if {[llength $args] > 7 || [llength $args] < 2} {
	return -code error "wrong # args: should be \"$usage\""
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    set args [WalkOptions $args 2 $usage]
    # Remainder is 'a n script'

    foreach {loopvariables script} $args break

    if {[llength $loopvariables] > 2} {
	return -code error "too many loop variables, at most two allowed"
    } elseif {[llength $loopvariables] == 2} {
	foreach {avar nvar} $loopvariables break
    } else {
	set nvar [lindex $loopvariables 0]
	set avar {}
    }

    # Make sure we have a script to run, otherwise what's the point?
    if { [string equal $script ""] } {
	return -code error "no script specified, or empty"
    }

    # Do the walk
    variable ${name}::children
    set st [list ]
    lappend st $node

    # Compute some flags for the possible places of command evaluation
    set leave [expr {[string equal $order post] || [string equal $order both]}]
    set enter [expr {[string equal $order pre]  || [string equal $order both]}]
    set touch [string equal $order in]

    if {$leave} {
	set lvlabel leave
    } elseif {$touch} {
	# in-order does not provide a sense
	# of nesting for the parent, hence
	# no enter/leave, just 'visit'.
	set lvlabel visit
    }

    set rcode 0
    set rvalue {}

    if {[string equal $type "dfs"]} {
	# Depth-first walk, several orders of visiting nodes
	# (pre, post, both, in)

	array set visited {}

	while { [llength $st] > 0 } {
	    set node [lindex $st end]

	    if {[info exists visited($node)]} {
		# Second time we are looking at this 'node'.
		# Pop it, then evaluate the command (post, both, in).

		ldelete st end

		if {$leave || $touch} {
		    # Evaluate the script at this node
		    WalkCall $avar $nvar $name $node $lvlabel $script
		    # prune stops execution of loop here.
		}
	    } else {
		# First visit of this 'node'.
		# Do *not* pop it from the stack so that we are able
		# to visit again after its children

		# Remember it.
		set visited($node) .

		if {$enter} {
		    # Evaluate the script at this node (pre, both).
		    #
		    # Note: As this is done before the children are
		    # looked at the script may change the children of
		    # this node and thus affect the walk.

		    WalkCall $avar $nvar $name $node "enter" $script
		    # prune stops execution of loop here.
		}

		# Add the children of this node to the stack.
		# The exact behaviour depends on the chosen
		# order. For pre, post, both-order we just
		# have to add them in reverse-order so that
		# they will be popped left-to-right. For in-order
		# we have rearrange the stack so that the parent
		# is revisited immediately after the first child.
		# (but only if there is ore than one child,)

		set clist        $children($node)
		set len [llength $clist]

		if {$touch && ($len > 1)} {
		    # Pop node from stack, insert into list of children
		    ldelete st end
		    set clist [linsert $clist 1 $node]
		    incr len
		}

		for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
		    lappend st [lindex $clist $i]
		}
	    }
	}
    } else {
	# Breadth first walk (pre, post, both)
	# No in-order possible. Already captured.

	if {$leave} {
	    set backward $st
	}

	while { [llength $st] > 0 } {
	    set node [lindex   $st 0]
	    ldelete st 0

	    if {$enter} {
		# Evaluate the script at this node
		WalkCall $avar $nvar $name $node "enter" $script
		# prune stops execution of loop here.
	    }

	    # Add this node's children
	    # And create a mirrored version in case of post/both order.

	    foreach child $children($node) {
		lappend st $child
		if {$leave} {
		    set backward [linsert $backward 0 $child]
		}
	    }
	}

	if {$leave} {
	    foreach node $backward {
		# Evaluate the script at this node
		WalkCall $avar $nvar $name $node "leave" $script
	    }
	}
    }

    if {$rcode != 0} {
	return -code $rcode $rvalue
    }
    return
}

proc ::struct::tree::_walkproc {name node args} {
    set usage "$name walkproc node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? ?--? cmdprefix"

    if {[llength $args] > 6 || [llength $args] < 1} {
	return -code error "wrong # args: should be \"$usage\""
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    set args [WalkOptions $args 1 $usage]
    # Remainder is 'n cmdprefix'

    set script [lindex $args 0]

    # Make sure we have a script to run, otherwise what's the point?
    if { ![llength $script] } {
	return -code error "no script specified, or empty"
    }

    # Do the walk
    variable ${name}::children
    set st [list ]
    lappend st $node

    # Compute some flags for the possible places of command evaluation
    set leave [expr {[string equal $order post] || [string equal $order both]}]
    set enter [expr {[string equal $order pre]  || [string equal $order both]}]
    set touch [string equal $order in]

    if {$leave} {
	set lvlabel leave
    } elseif {$touch} {
	# in-order does not provide a sense
	# of nesting for the parent, hence
	# no enter/leave, just 'visit'.
	set lvlabel visit
    }

    set rcode 0
    set rvalue {}

    if {[string equal $type "dfs"]} {
	# Depth-first walk, several orders of visiting nodes
	# (pre, post, both, in)

	array set visited {}

	while { [llength $st] > 0 } {
	    set node [lindex $st end]

	    if {[info exists visited($node)]} {
		# Second time we are looking at this 'node'.
		# Pop it, then evaluate the command (post, both, in).

		ldelete st end

		if {$leave || $touch} {
		    # Evaluate the script at this node
		    WalkCallProc $name $node $lvlabel $script
		    # prune stops execution of loop here.
		}
	    } else {
		# First visit of this 'node'.
		# Do *not* pop it from the stack so that we are able
		# to visit again after its children

		# Remember it.
		set visited($node) .

		if {$enter} {
		    # Evaluate the script at this node (pre, both).
		    #
		    # Note: As this is done before the children are
		    # looked at the script may change the children of
		    # this node and thus affect the walk.

		    WalkCallProc $name $node "enter" $script
		    # prune stops execution of loop here.
		}

		# Add the children of this node to the stack.
		# The exact behaviour depends on the chosen
		# order. For pre, post, both-order we just
		# have to add them in reverse-order so that
		# they will be popped left-to-right. For in-order
		# we have rearrange the stack so that the parent
		# is revisited immediately after the first child.
		# (but only if there is ore than one child,)

		set clist        $children($node)
		set len [llength $clist]

		if {$touch && ($len > 1)} {
		    # Pop node from stack, insert into list of children
		    ldelete st end
		    set clist [linsert $clist 1 $node]
		    incr len
		}

		for {set i [expr {$len - 1}]} {$i >= 0} {incr i -1} {
		    lappend st [lindex $clist $i]
		}
	    }
	}
    } else {
	# Breadth first walk (pre, post, both)
	# No in-order possible. Already captured.

	if {$leave} {
	    set backward $st
	}

	while { [llength $st] > 0 } {
	    set node [lindex   $st 0]
	    ldelete st 0

	    if {$enter} {
		# Evaluate the script at this node
		WalkCallProc $name $node "enter" $script
		# prune stops execution of loop here.
	    }

	    # Add this node's children
	    # And create a mirrored version in case of post/both order.

	    foreach child $children($node) {
		lappend st $child
		if {$leave} {
		    set backward [linsert $backward 0 $child]
		}
	    }
	}

	if {$leave} {
	    foreach node $backward {
		# Evaluate the script at this node
		WalkCallProc $name $node "leave" $script
	    }
	}
    }

    if {$rcode != 0} {
	return -code $rcode $rvalue
    }
    return
}

proc ::struct::tree::WalkOptions {theargs n usage} {
    upvar 1 type type order order

    # Set defaults
    set type dfs
    set order pre

    while {[llength $theargs]} {
	set flag [lindex $theargs 0]
	switch -exact -- $flag {
	    "-type" {
		if {[llength $theargs] < 2} {
		    return -code error "value for \"$flag\" missing"
		}
		set type [string tolower [lindex $theargs 1]]
		set theargs [lrange $theargs 2 end]
	    }
	    "-order" {
		if {[llength $theargs] < 2} {
		    return -code error "value for \"$flag\" missing"
		}
		set order [string tolower [lindex $theargs 1]]
		set theargs [lrange $theargs 2 end]
	    }
	    "--" {
		set theargs [lrange $theargs 1 end]
		break
	    }
	    default {
		break
	    }
	}
    }

    if {[llength $theargs] == 0} {
	return -code error "wrong # args: should be \"$usage\""
    }
    if {[llength $theargs] != $n} {
	return -code error "unknown option \"$flag\""
    }

    # Validate that the given type is good
    switch -exact -- $type {
	"dfs" - "bfs" {
	    set type $type
	}
	default {
	    return -code error "bad search type \"$type\": must be bfs or dfs"
	}
    }

    # Validate that the given order is good
    switch -exact -- $order {
	"pre" - "post" - "in" - "both" {
	    set order $order
	}
	default {
	    return -code error "bad search order \"$order\":\
		    must be both, in, pre, or post"
	}
    }

    if {[string equal $order "in"] && [string equal $type "bfs"]} {
	return -code error "unable to do a ${order}-order breadth first walk"
    }

    return $theargs
}

# ::struct::tree::WalkCall --
#
#	Helper command to 'walk' handling the evaluation
#	of the user-specified command. Information about
#	the tree, node and current action are substituted
#	into the command before it evaluation.
#
# Arguments:
#	tree	Tree we are walking
#	node	Node we are at.
#	action	The current action.
#	cmd	The command to call, already partially substituted.
#
# Results:
#	None.

proc ::struct::tree::WalkCall {avar nvar tree node action cmd} {

    if {$avar != {}} {
	upvar 2 $avar a ; set a $action
    }
    upvar 2 $nvar n ; set n $node

    set code [catch {uplevel 2 $cmd} result]

    # decide what to do upon the return code:
    #
    #               0 - the body executed successfully
    #               1 - the body raised an error
    #               2 - the body invoked [return]
    #               3 - the body invoked [break]
    #               4 - the body invoked [continue]
    #               5 - the body invoked [struct::tree::prune]
    # everything else - return and pass on the results
    #
    switch -exact -- $code {
	0 {}
	1 {
	    return -errorinfo [ErrorInfoAsCaller uplevel WalkCall]  \
		    -errorcode $::errorCode -code error $result
	}
	3 {
	    # FRINK: nocheck
	    return -code break
	}
	4 {}
	5 {
	    upvar order order
	    if {[string equal $order post] || [string equal $order in]} {
		return -code error "Illegal attempt to prune ${order}-order walking"
	    }
	    return -code continue
	}
	default {
	    upvar 1 rcode rcode rvalue rvalue
	    set rcode $code
	    set rvalue $result
	    return -code break
	    #return -code $code $result
	}
    }
    return {}
}

proc ::struct::tree::WalkCallProc {tree node action cmd} {

    lappend cmd $tree $node $action
    set code [catch {uplevel 2 $cmd} result]

    # decide what to do upon the return code:
    #
    #               0 - the body executed successfully
    #               1 - the body raised an error
    #               2 - the body invoked [return]
    #               3 - the body invoked [break]
    #               4 - the body invoked [continue]
    #               5 - the body invoked [struct::tree::prune]
    # everything else - return and pass on the results
    #
    switch -exact -- $code {
	0 {}
	1 {
	    return -errorinfo [ErrorInfoAsCaller uplevel WalkCallProc]  \
		    -errorcode $::errorCode -code error $result
	}
	3 {
	    # FRINK: nocheck
	    return -code break
	}
	4 {}
	5 {
	    upvar order order
	    if {[string equal $order post] || [string equal $order in]} {
		return -code error "Illegal attempt to prune ${order}-order walking"
	    }
	    return -code continue
	}
	default {
	    upvar 1 rcode rcode rvalue rvalue
	    set rcode $code
	    set rvalue $result
	    return -code break
	}
    }
    return {}
}

proc ::struct::tree::ErrorInfoAsCaller {find replace} {
    set info $::errorInfo
    set i [string last "\n    (\"$find" $info]
    if {$i == -1} {return $info}
    set result [string range $info 0 [incr i 6]]	;# keep "\n    (\""
    append result $replace			;# $find -> $replace
    incr i [string length $find]
    set j [string first ) $info [incr i]]	;# keep rest of parenthetical
    append result [string range $info $i $j]
    return $result
}

# ::struct::tree::GenerateUniqueNodeName --
#
#	Generate a unique node name for the given tree.
#
# Arguments:
#	name	Name of the tree to generate a unique node name for.
#
# Results:
#	node	Name of a node guaranteed to not exist in the tree.

proc ::struct::tree::GenerateUniqueNodeName {name} {
    variable ${name}::nextUnusedNode
    while {[_exists $name "node${nextUnusedNode}"]} {
	incr nextUnusedNode
    }
    return "node${nextUnusedNode}"
}

# ::struct::tree::KillNode --
#
#	Delete all data of a node.
#
# Arguments:
#	name	Name of the tree containing the node
#	node	Name of the node to delete.
#
# Results:
#	none

proc ::struct::tree::KillNode {name node} {
    variable ${name}::parent
    variable ${name}::children
    variable ${name}::attribute

    # Remove all record of $node
    unset parent($node)
    unset children($node)

    if {[info exists attribute($node)]} {
	# FRINK: nocheck
	unset ${name}::$attribute($node)
	unset attribute($node)
    }
    return
}

# ::struct::tree::GenAttributeStorage --
#
#	Create an array to store the attributes of a node in.
#
# Arguments:
#	name	Name of the tree containing the node
#	node	Name of the node which got attributes.
#
# Results:
#	none

proc ::struct::tree::GenAttributeStorage {name node} {
    variable ${name}::nextAttr
    variable ${name}::attribute

    set   attr "a[incr nextAttr]"
    set   attribute($node) $attr
    return
}

# ::struct::tree::Serialize --
#
#	Serialize a tree object (partially) into a transportable value.
#
# Arguments:
#	name	Name of the tree.
#	node	Root node of the serialized tree.
#
# Results:
#	None

proc ::struct::tree::Serialize {name node tvar} {
    upvar 1 $tvar tree

    variable ${name}::attribute
    variable ${name}::parent

    # 'node' is the root of the tree to serialize. The precondition
    # for the call is that this node is already stored in the list
    # 'tvar', at index 'rootidx'.

    # The attribute data for 'node' goes immediately after the 'node'
    # data. the node information is _not_ yet stored, and this command
    # has to do this.


    array set r {}
    set loc($node) 0

    lappend tree $node {}
    if {[info exists attribute($node)]} {
	upvar ${name}::$attribute($node) data
	lappend tree [array get data]
    } else {
	# Encode nodes without attributes.
	lappend tree {}
    }

    foreach n [DescendantsCore $name $node] {
	set loc($n) [llength $tree]
	lappend tree $n $loc($parent($n))

	if {[info exists attribute($n)]} {
	    upvar ${name}::$attribute($n) data
	    lappend tree [array get data]
	} else {
	    # Encode nodes without attributes.
	    lappend tree {}
	}
    }

    return $tree
}


proc ::struct::tree::CheckSerialization {ser avar pvar cvar rnvar} {
    upvar 1 $avar attr $pvar p $cvar ch $rnvar rn

    # Overall length ok ?

    if {[llength $ser] % 3} {
	return -code error \
		"error in serialization: list length not a multiple of 3."
    }

    set rn {}
    array set p    {}
    array set ch   {}
    array set attr {}

    # Basic decoder pass

    foreach {node parent nattr} $ser {

	# Initialize children data, if not already done
	if {![info exists ch($node)]} {
	    set ch($node) {}
	}
	# Attribute length ok ? Dictionary!
	if {[llength $nattr] % 2} {
	    return -code error \
		    "error in serialization: malformed attribute dictionary."
	}
	# Remember attribute data only for non-empty nodes
	if {[llength $nattr]} {
	    set attr($node) $nattr
	}
	# Remember root
	if {$parent == {}} {
	    lappend rn $node
	    set p($node) {}
	    continue
	}
	# Parent reference ok ?
	if {
	    ![string is integer -strict $parent] ||
	    ($parent % 3) ||
	    ($parent < 0) ||
	    ($parent >= [llength $ser])
	} {
	    return -code error \
		    "error in serialization: bad parent reference \"$parent\"."
	}
	# Remember parent, and reconstruct children

	set p($node) [lindex $ser $parent]
	lappend ch($p($node)) $node
    }

    # Root node information ok ?

    if {[llength $rn] < 1} {
	return -code error \
		"error in serialization: no root specified."
    } elseif {[llength $rn] > 1} {
	return -code error \
		"error in serialization: multiple root nodes."
    }
    set rn [lindex $rn 0]

    # Duplicate node names ?

    if {[array size ch] < ([llength $ser] / 3)} {
	return -code error \
		"error in serialization: duplicate node names."
    }

    # Cycles in the parent relationship ?

    array set visited {}
    foreach n [array names p] {
	if {[info exists visited($n)]} {continue}
	array set _ {}
	while {$n != {}} {
	    if {[info exists _($n)]} {
		# Node already converted, cycle.
		return -code error \
			"error in serialization: cycle detected."
	    }
	    set _($n)       .
	    # root ?
	    if {$p($n) == {}} {break}
	    set n $p($n)
	    if {[info exists visited($n)]} {break}
	    set visited($n) .
	}
	unset _
    }
    # Ok. The data is now ready for the caller.

    return
}

##########################
# Private functions follow
#
# Do a compatibility version of [lset] for pre-8.4 versions of Tcl.
# This version does not do multi-arg [lset]!

proc ::struct::tree::K { x y } { set x }

if { [package vcompare [package provide Tcl] 8.4] < 0 } {
    proc ::struct::tree::lset { var index arg } {
	upvar 1 $var list
	set list [::lreplace [K $list [set list {}]] $index $index $arg]
    }
}

proc ::struct::tree::ldelete {var index {end {}}} {
    upvar 1 $var list
    if {$end == {}} {set end $index}
    set list [lreplace [K $list [set list {}]] $index $end]
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Put 'tree::tree' into the general structure namespace
    # for pickup by the main management.

    namespace import -force tree::tree_tcl
}
