# tree.tcl --
#
#	Implementation of a tree data structure for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: tree1.tcl,v 1.5 2005/10/04 17:15:05 andreas_kupries Exp $

package require Tcl 8.2

namespace eval ::struct {}

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
    namespace export tree
}

# ::struct::tree::tree --
#
#	Create a new tree with a given name; if no name is given, use
#	treeX, where X is a number.
#
# Arguments:
#	name	Optional name of the tree; if null or not given, generate one.
#
# Results:
#	name	Name of the tree created

proc ::struct::tree::tree {{name ""}} {
    variable counter

    if {[llength [info level 0]] == 1} {
	incr counter
	set name "tree${counter}"
    }
    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 namespace current]
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
    interp alias {} ::$name {} ::struct::tree::TreeProc $name

    return $name
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
    return [uplevel 1 [linsert $args 0 ::struct::tree::$sub $name]]
}

# ::struct::tree::_children --
#
#	Return the child list for a given node of a tree.
#
# Arguments:
#	name	Name of the tree object.
#	node	Node to look up.
#
# Results:
#	children	List of children for the node.

proc ::struct::tree::_children {name node} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    return $children($node)
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
    if { [string equal $node "root"] } {
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
    if { [string equal $node "root"] } {
	# Can't delete the special root node
	return -code error "cannot delete root node"
    }
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::children
    variable ${name}::parent

    # Remove this node from its parent's children list
    set parentNode $parent($node)
    set index [lsearch -exact $children($parentNode) $node]
    set children($parentNode) [lreplace $children($parentNode) $index $index]

    # Yes, we could use the stack structure implemented in ::struct::stack,
    # but it's slower than inlining it.  Since we don't need a sophisticated
    # stack, don't bother.
    set st [list]
    foreach child $children($node) {
	lappend st $child
    }

    KillNode $name $node

    while { [llength $st] > 0 } {
	set node [lindex   $st end]
	set st   [lreplace $st end end]
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
    set depth 0
    while { ![string equal $node "root"] } {
	incr depth
	set node $parent($node)
    }
    return $depth
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
    interp alias {} ::$name {}
}

# ::struct::tree::_exists --
#
#	Test for existance of a given node in a tree.
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
#	flag	Optional flag specifier; if present, must be "-key".
#	key	Optional key to lookup; defaults to data.
#
# Results:
#	value	Value associated with the key given.

proc ::struct::tree::_get {name node {flag -key} {key data}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# except for the default key 'data'.

	if {[string equal $key data]} {
	    return ""
	}
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

proc ::struct::tree::_getall {name node args} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {[llength $args]} {
	return -code error "wrong # args: should be \"$name getall $node\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# Only default key is present, invisibly.
	return {data {}}
    }

    upvar ${name}::$attribute($node) data
    return [array get data]
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

proc ::struct::tree::_keys {name node args} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {[llength $args]} {
	return -code error "wrong # args: should be \"$name keys $node\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# except for the default key 'data'.
	return {data}
    }

    upvar ${name}::$attribute($node) data
    return [array names data]
}

# ::struct::tree::_keyexists --
#
#	Test for existance of a given key for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to query.
#	flag	Optional flag specifier; if present, must be "-key".
#	key	Optional key to lookup; defaults to data.
#
# Results:
#	1 if the key exists, 0 else.

proc ::struct::tree::_keyexists {name node {flag -key} {key data}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {![string equal $flag "-key"]} {
	return -code error "invalid option \"$flag\": should be -key"
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# except for the default key 'data'.

	return [string equal $key data]
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
    if { [string equal $node "root"] } {
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

    # Make sure the index is numeric
    if { ![string is integer $index] } {
	# If the index is not numeric, make it numeric by lsearch'ing for
	# the value at index, then incrementing index (because "end" means
	# just past the end for inserts)
	set val [lindex $children($parentNode) $index]
	set index [expr {[lsearch -exact $children($parentNode) $val] + 1}]
    }

    foreach node $args {
	if {[_exists $name $node] } {
	    # Move the node to its new home
	    if { [string equal $node "root"] } {
		return -code error "cannot move root node"
	    }
	
	    # Cannot make a node its own descendant (I'm my own grandpaw...)
	    set ancestor $parentNode
	    while { ![string equal $ancestor "root"] } {
		if { [string equal $ancestor $node] } {
		    return -code error "node \"$node\" cannot be its own descendant"
		}
		set ancestor $parent($ancestor)
	    }
	    # Remove this node from its parent's children list
	    set oldParent $parent($node)
	    set ind [lsearch -exact $children($oldParent) $node]
	    set children($oldParent) [lreplace $children($oldParent) $ind $ind]
	
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

    # Make sure the index is numeric
    if { ![string is integer $index] } {
	# If the index is not numeric, make it numeric by lsearch'ing for
	# the value at index, then incrementing index (because "end" means
	# just past the end for inserts)
	set val [lindex $children($parentNode) $index]
	set index [expr {[lsearch -exact $children($parentNode) $val] + 1}]
    }

    # Validate all nodes to move before trying to move any.
    foreach node $args {
	if { [string equal $node "root"] } {
	    return -code error "cannot move root node"
	}

	# Can only move real nodes
	if { ![_exists $name $node] } {
	    return -code error "node \"$node\" does not exist in tree \"$name\""
	}

	# Cannot move a node to be a descendant of itself
	set ancestor $parentNode
	while { ![string equal $ancestor "root"] } {
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

	set children($oldParent) [lreplace $children($oldParent) $ind $ind]

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
    if { [string equal $node "root"] } {
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
    if { [string equal $node "root"] } {
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

proc ::struct::tree::_serialize {name {node root}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    Serialize $name $node tree attr
    return [list $tree [array get attr]]
}

# ::struct::tree::_set --
#
#	Set or get a value for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify or query.
#	args	Optional arguments specifying a key and a value.  Format is
#			?-key key? ?value?
#		If no key is specified, the key "data" is used.
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_set {name node args} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {[llength $args] > 3} {
	return -code error "wrong # args: should be \"$name set [list $node] ?-key key?\
		?value?\""
    }

    # Process the arguments ...

    set key "data"
    set haveValue 0
    if {[llength $args] > 1} {
	foreach {flag key} $args break
	if {![string match "${flag}*" "-key"]} {
	    return -code error "invalid option \"$flag\": should be key"
	}
	if {[llength $args] == 3} {
	    set haveValue 1
	    set value [lindex $args end]
	}
    } elseif {[llength $args] == 1} {
	set haveValue 1
	set value [lindex $args end]
    }

    if {$haveValue} {
	# Setting a value. This may have to create
	# the attribute array for this particular
	# node

	variable ${name}::attribute
	if {![info exists attribute($node)]} {
	    # No attribute data for this node,
	    # so create it as we need it.
	    GenAttributeStorage $name $node
	}
	upvar ${name}::$attribute($node) data

	return [set data($key) $value]
    } else {
	# Getting a value

	return [_get $name $node -key $key]
    }
}

# ::struct::tree::_append --
#
#	Append a value for a node in a tree.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify or query.
#	args	Optional arguments specifying a key and a value.  Format is
#			?-key key? ?value?
#		If no key is specified, the key "data" is used.
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_append {name node args} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {
	([llength $args] != 1) &&
	([llength $args] != 3)
    } {
	return -code error "wrong # args: should be \"$name set [list $node] ?-key key?\
		value\""
    }
    if {[llength $args] == 3} {
	foreach {flag key} $args break
	if {![string equal $flag "-key"]} {
	    return -code error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

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
#	args	Optional arguments specifying a key and a value.  Format is
#			?-key key? ?value?
#		If no key is specified, the key "data" is used.
#
# Results:
#	val	Value associated with the given key of the given node

proc ::struct::tree::_lappend {name node args} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {
	([llength $args] != 1) &&
	([llength $args] != 3)
    } {
	return -code error "wrong # args: should be \"$name lappend [list $node] ?-key key?\
		value\""
    }
    if {[llength $args] == 3} {
	foreach {flag key} $args break
	if {![string equal $flag "-key"]} {
	    return -code error "invalid option \"$flag\": should be -key"
	}
    } else {
	set key "data"
    }

    set value [lindex $args end]

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# so create it as we need it.
	GenAttributeStorage $name $node
    }
    upvar ${name}::$attribute($node) data

    return [lappend data($key) $value]
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

proc ::struct::tree::_size {name {node root}} {
    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    # If the node is the root, we can do the cheap thing and just count the
    # number of nodes (excluding the root node) that we have in the tree with
    # array names
    if { [string equal $node "root"] } {
	set size [llength [array names ${name}::parent]]
	return [expr {$size - 1}]
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
	set st [lreplace $st end end]
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
#	node		Optional node name; if given, must be unique.  If not
#			given, a unique name will be generated.
#
# Results:
#	node		Name of the node added to the tree.

proc ::struct::tree::_splice {name parentNode from {to end} args} {
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

    # Save the list of children that are moving
    set moveChildren [lrange $children($parentNode) $from $to]

    # Remove those children from the parent
    set children($parentNode) [lreplace $children($parentNode) $from $to]

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
    if {[string equal $node1 "root"] || [string equal $node2 "root"]} {
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

    set children($parent1) [lreplace $children($parent1) $i1 $i1 $node2]
    set children($parent2) [lreplace $children($parent2) $i2 $i2 $node1]

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

    # Swap the values
    # More complicated now with the possibility that nodes do not have
    # attribute storage associated with them.

    variable ${name}::attribute

    if {
	[set ia [info exists attribute($node1)]] ||
	[set ib [info exists attribute($node2)]]
    } {
	# At least one of the nodes has attribute data. We simply swap
	# the references to the arrays containing them. No need to
	# copy the actual data around.

	if {$ia && $ib} {
	    set tmp               $attribute($node1)
	    set attribute($node1) $attribute($node2)
	    set attribute($node2) $tmp
	} elseif {$ia} {
	    set   attribute($node2) $attribute($node1)
	    unset attribute($node1)
	} elseif {$ib} {
	    set   attribute($node1) $attribute($node2)
	    unset attribute($node2)
	} else {
	    return -code error "Impossible condition."
	}
    } ; # else: No attribute storage => Nothing to do {}

    return
}

# ::struct::tree::_unset --
#
#	Remove a keyed value from a node.
#
# Arguments:
#	name	Name of the tree.
#	node	Node to modify.
#	args	Optional additional args specifying which key to unset;
#		if given, must be of the form "-key key".  If not given,
#		the key "data" is unset.
#
# Results:
#	None.

proc ::struct::tree::_unset {name node {flag -key} {key data}} {
    if {![_exists $name $node]} {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }
    if {![string match "${flag}*" "-key"]} {
	return -code error "invalid option \"$flag\": should be \"$name unset\
		[list $node] ?-key key?\""
    }

    variable ${name}::attribute
    if {![info exists attribute($node)]} {
	# No attribute data for this node,
	# except for the default key 'data'.
	GenAttributeStorage $name $node
    }
    upvar ${name}::$attribute($node) data

    catch {unset data($key)}
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
#		    ?-type {bfs|dfs}? ?-order {pre|post|in|both}? -command cmd
#
# Results:
#	None.

proc ::struct::tree::_walk {name node args} {
    set usage "$name walk $node ?-type {bfs|dfs}? ?-order {pre|post|in|both}? -command cmd"

    if {[llength $args] > 6 || [llength $args] < 2} {
	return -code error "wrong # args: should be \"$usage\""
    }

    if { ![_exists $name $node] } {
	return -code error "node \"$node\" does not exist in tree \"$name\""
    }

    # Set defaults
    set type dfs
    set order pre
    set cmd ""

    for {set i 0} {$i < [llength $args]} {incr i} {
	set flag [lindex $args $i]
	incr i
	if { $i >= [llength $args] } {
	    return -code error "value for \"$flag\" missing: should be \"$usage\""
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
	    default {
		return -code error "unknown option \"$flag\": should be \"$usage\""
	    }
	}
    }

    # Make sure we have a command to run, otherwise what's the point?
    if { [string equal $cmd ""] } {
	return -code error "no command specified: should be \"$usage\""
    }

    # Validate that the given type is good
    switch -exact -- $type {
	"dfs" - "bfs" {
	    set type $type
	}
	default {
	    return -code error "invalid search type \"$type\": should be dfs, or bfs"
	}
    }

    # Validate that the given order is good
    switch -exact -- $order {
	"pre" - "post" - "in" - "both" {
	    set order $order
	}
	default {
	    return -code error "invalid search order \"$order\":\
		    should be pre, post, both, or in"
	}
    }

    if {[string equal $order "in"] && [string equal $type "bfs"]} {
	return -code error "unable to do a ${order}-order breadth first walk"
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

    if { [string equal $type "dfs"] } {
	# Depth-first walk, several orders of visiting nodes
	# (pre, post, both, in)

	array set visited {}

	while { [llength $st] > 0 } {
	    set node [lindex $st end]

	    if {[info exists visited($node)]} {
		# Second time we are looking at this 'node'.
		# Pop it, then evaluate the command (post, both, in).

		set st [lreplace $st end end]

		if {$leave || $touch} {
		    # Evaluate the command at this node
		    WalkCall $name $node $lvlabel $cmd
		}
	    } else {
		# First visit of this 'node'.
		# Do *not* pop it from the stack so that we are able
		# to visit again after its children

		# Remember it.
		set visited($node) .

		if {$enter} {
		    # Evaluate the command at this node (pre, both)
		    WalkCall $name $node "enter" $cmd
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
		    set st    [lreplace $st end end]
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
	    set st   [lreplace $st 0 0]

	    if {$enter} {
		# Evaluate the command at this node
		WalkCall $name $node "enter" $cmd
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
		# Evaluate the command at this node
		WalkCall $name $node "leave" $cmd
	    }
	}
    }
    return
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

proc ::struct::tree::WalkCall {tree node action cmd} {
    set subs [list %n [list $node] %a [list $action] %t [list $tree] %% %]
    uplevel 2 [string map $subs $cmd]
    return
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
#	Create an array to store the attrributes of a node in.
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
    upvar ${name}::$attr data
    set   data(data) ""
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

proc ::struct::tree::Serialize {name node tvar avar} {
    upvar 1 $tvar tree $avar attr

    variable ${name}::children
    variable ${name}::attribute

    # Store attribute data
    if {[info exists attribute($node)]} {
	set attr($node) [array get ${name}::$attribute($node)]
    } else {
	set attr($node) {}
    }

    # Build tree structure as nested list.

    set subtrees [list]
    foreach c $children($node) {
	Serialize $name $c sub attr
	lappend subtrees $sub
    }

    set tree [list $node $subtrees]
    return
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'tree::tree' into the general structure namespace.
    namespace import -force tree::tree
    namespace export tree
}
package provide struct::tree 1.2.2
