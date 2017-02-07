# -*- tcl -*-
# (C) 2006 Andreas Kupries <andreas_kupries@users.sourceforge.net>
##
# ###

package require Tcl 8.3
package require snit
package require tie

# ###

snit::type pregistry {

    # API
    # delete key ?attribute?
    # mtime  key ?attribute?
    # get    key attribute
    # keys   key ?pattern?/*
    # set    key ?attribute value?
    # attrs  key ?pattern?

    option -tie -default {} -configuremethod TIE ; # Persistence

    constructor {args} {
	$self configurelist $args
	$self INIT
	return
    }

    # ###

    method delete {key args} {
	#puts DEL|$key|

	if {[llength $args] > 1} {return -code error "wrong\#args"}

	if {[catch {NODE $key} n]} return
	if {[llength $args]} {
	    # Delete attribute

	    set attr    [lindex $args 0]
	    set pattern [list A $n $attr *]
	    set km      [list N $n M]

	    array unset data $pattern
	    set         data($km) [clock seconds]
	} else {
	    # Delete key and children.
	    #puts N|$n|

	    if {![llength $key]} {
		return -code error "cannot delete root"
	    }

	    # Children first
	    foreach c [array names data [list C $n *]] {
		set c [lindex $c end]
		#puts _|$c|
		$self delete [linsert $key end $c]
	    }

	    # And now the node itself. Modify the parent as well,
	    # remove this node as a child.

	    set self [lindex $key end]
	    set pidx [list N $n P]
	    set npat [list N $n *]
	    set apat [list A $n * *]

	    set pid  $data($pidx)
	    set cidx [list C $pid $self]
	    set midx [list N $pid M]

	    array unset data $apat
	    array unset data $npat
	    unset -nocomplain data($cidx)
	    set data($midx) [clock seconds]

	    unset -nocomplain ncache($key)
	}
	return
    }

    method mtime {key args} {
	if {[llength $args] > 1} {return -code error "wrong\#args"}
	set n [NODE $key]
	if {[llength $args]} {
	    set attr [lindex $args 0]
	    set idx  [list A $n $attr M]
	    if {![info exists data($idx)]} {
		return -code error "Unknown attribute \"$attr\" in key \"$key\""
	    }
	} else {
	    set idx [list N $n M]
	}
	return $data($idx)
    }

    method exists {key args} {
	if {[llength $args] > 1} {
	    return -code error "wrong\#args"
	} elseif {[catch {NODE $key} n]} {
	    return 0
	} elseif {![llength $args]} {
	    return 1
	}

	set attr [lindex $args 0]
	set idx  [list A $n $attr V]
	return   [info exist data($idx)]
    }

    method get {key attr} {
	set n   [NODE $key]
	set idx [list A $n $attr V]
	if {![info exists data($idx)]} {
	    return -code error "Unknown attribute \"$attr\" in key \"$key\""
	}
	return $data($idx)
    }

    method get||default {key attr default} {
	if {[catch {NODE $key} n]} {
	    return $default
	}
	set idx [list A $n $attr V]
	if {![info exists data($idx)]} {
	    return $default
	}
	return $data($idx)
    }

    method keys {key {pattern *}} {
	set n       [NODE $key]
	set pattern [list C $n $pattern]
	set res {}
	foreach c [array names data $pattern] {
	    lappend res [linsert $key end $c]
	}
	return $res
    }

    method attrs {key {pattern *}} {
	set n       [NODE $key]
	set pattern [list A $n $pattern V]
	set res {}
	foreach c [array names data $pattern] {
	    lappend res [lindex $c end-1]
	}
	return $res
    }

    method lappend {key attr value} {
	set     list [$self get||default $key $attr {}]
	lappend list $value
	$self set $key $attr $list
	return
    }

    method set {key args} {
	set n [NODE $key 1]
	if {![llength $args]} return
	if {[llength  $args] != 2} {return -code error "wrong\#args"}
	foreach {attr value} $args break

	# Ignore calls which do not change the contents of the
	# database.

	set aidx [list A $n $attr V]
	if {
	    [info exists   data($aidx)] &&
	    [string equal $data($aidx) $value]
	} return ; # {}

	#puts stderr "$n $attr | $key | ($value)"

	set aids [list A $n $attr M]
	set data($aidx) $value
	set data($aids) [clock seconds]
	return
    }

    # ### state

    variable data -array {}

    # Tree of keys. Each keys can have multiple attributes.
    # Each key, and attribute, have a modification timestamp.

    # Each node in the tree is identified by a numeric id. Children
    # refer to their parents. Parent id + name refers to unique child.

    # Array contents

    # (I)           -> number		id counter
    # (C id name)   -> id		parent id x name => child id
    # (N id P)      -> id		node id => parent id, empty for root
    # (N id M)      -> timestamp	node id => last modification
    # (A id name V) -> string		node id x attribute name => value
    # (A id name M) -> timestamp	s.a => last modification

    # This structure is less memory/space intensive than the setup of
    # 1registry. It is also more difficult to query as it is less
    # tabular, less redundant.

    # Another thing becoming more complex is the deletion of a
    # subtree. It is now necessary to walk the the tree, instead of
    # just deleting all keys in the array matching a certain
    # pattern. That at least can be done at the C level (array unset).

    # The conversion from key list to node is also linear in key
    # length, and an operation done often. Better cache it. However
    # only internally, or the space savingsare gone too as the space
    # is then taken by the conversion cache. Hm. Still less than
    # before, as each key is listed at most once. In 1registry it was
    # repeated for each of its attributes as well. This would regain
    # speed for searches, as the conversion cache now is a tabular
    # representation of the tree, and easily globbed.

    # ### configure -tie (persistence)

    method TIE {option value} {
	if {[string equal $options(-tie) $value]} return
	tie::untie [myvar data]
	# 8.5 - tie::tie [myvar data] {expand}$value
	eval [linsert $value 0 tie::tie [myvar data]]
	set options(-tie) $value
	return
    }

    method INIT {} {
	if {![info exists data(I)]} {
	    set anchor {C {} {}}
	    set rootp  {N 0 P}
	    set roots  {N 0 M}

	    set data(I) 0
	    set data($anchor) 0
	    set data($rootp)  {}
	    set data($roots)  [clock seconds]
	}
	return
    }

    variable ncache -array {}

    proc NODE {key {create 0}} {
	upvar 1 ncache ncache data data
	if {[info exist ncache($key)]} {
	    # Cached, shortcut
	    return $ncache($key)
	}
	if {![llength $key]} {
	    # Root, shortcut
	    set id 0
	} else {
	    # Recursively convert, possibly create
	    set parent [lrange $key 0 end-1]
	    set self   [lindex $key end]
	    set pid    [NODE $parent $create]
	    set idx    [list C $pid $self]

	    if {[info exists data($idx)]} {
		set id $data($idx)
	    } elseif {!$create} {
		return -code error "Unknown key \"$key\""
	    } else {
		set id   [incr data(I)]
		set idxp [list N $id P]
		set idxm [list N $id M]

		set data($idx)  $id
		set data($idxp) $pid
		set data($idxm) [clock seconds]
	    }
	}
	set ncache($key) $id
	return $id
    }

    # ###
}

##
# ###

package provide pregistry 0.1
