# cgen.tcl --
#
#	Generator core for compiler of magic(5) files into recognizers
#	based on the 'rtcore'.
#
# Copyright (c) 2004-2005 Colin McCormack <coldstore@users.sourceforge.net>
# Copyright (c) 2005      Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: cgen.tcl,v 1.7 2007/06/23 03:39:34 andreas_kupries Exp $

#####
#
# "mime type recognition in pure tcl"
# http://wiki.tcl.tk/12526
#
# Tcl code harvested on:  10 Feb 2005, 04:06 GMT
# Wiki page last updated: ???
#
#####

# ### ### ### ######### ######### #########
## Requirements

package require Tcl 8.4
package require fileutil::magic::rt ; # Runtime core, for Access to the typemap
package require struct::list        ; # Our data structures.
package require struct::tree        ; #

package provide fileutil::magic::cgen 1.0

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic::cgen {
    # Import the runtime typemap into our scope.
    variable ::fileutil::magic::rt::typemap

    # The tree most operations use for their work.
    variable tree {}

    # Generator data structure.
    variable regions

    # Type mapping for indirect offsets.
    # empty -> long/Q, because this uses native byteorder.

    array set otmap {
        .b c    .B c
        .s s    .S S
        .l i    .L I
	{} Q
    }

    # Export the API
    namespace export 2tree treedump treegen
}


# Optimisations:

# reorder tests according to expected or observed frequency this
# conflicts with reduction in strength optimisations.

# Rewriting within a level will require pulling apart the list of
# tests at that level and reordering them.  There is an inconsistency
# between handling at 0-level and deeper level - this has to be
# removed or justified.

# Hypothetically, every test at the same level should be mutually
# exclusive, but this is not given, and should be detected.  If true,
# this allows reduction in strength to switch on Numeric tests

# reduce Numeric tests at the same level to switches
#
# - first pass through clauses at same level to categorise as
#   variant values over same test (type and offset).

# work out some way to cache String comparisons

# Reduce seek/reads for String comparisons at same level:
#
# - first pass through clauses at same level to determine string ranges.
#
# - String tests at same level over overlapping ranges can be
#   written as sub-string comparisons over the maximum range
#   this saves re-reading the same string from file.
#
# - common prefix strings will have to be guarded against, by
#   sorting string values, then sorting the tests in reverse length order.


proc ::fileutil::magic::cgen::path {tree} {
    # Annotates the tree. In each node we store the path from the root
    # to this node, as list of nodes, with the current node the last
    # element. The root node is never stored in the path.

    $tree set root path {}
    foreach child [$tree children root] {
   	$tree walk $child -type dfs node {
   	    set path [$tree get [$tree parent $node] path]
   	    lappend path [$tree index $node]
   	    $tree set $node path $path
   	}
    }
    return
}

proc ::fileutil::magic::cgen::tree_el {tree parent file line type qual comp offset val message args} {

    # Recursively creates and annotates a node for the specified
    # tests, and its sub-tests (args).

    set     node [$tree insert $parent end]
    set     path [$tree get    $parent path]
    lappend path [$tree index  $node]
    $tree set $node path $path

    # generate a proc call type for the type, Numeric or String
    variable ::fileutil::magic::rt::typemap

    switch -glob -- $type {
   	*byte* -
   	*short* -
   	*long* -
   	*date* {
   	    set otype N
   	    set type [lindex $typemap($type) 1]
   	}
   	*string {
   	    set otype S
   	}
   	default {
   	    puts stderr "Unknown type: '$type'"
   	}
    }

    # Stores the type determined above, and the arguments into
    # attributes of the new node.

    foreach key {line type qual comp offset val message file otype} {
   	if {[catch {
   	    $tree set $node $key [set $key]
   	} result]} {
	    upvar ::errorInfo eo
   	    puts "Tree: $eo - $file $line $type"
   	}
    }

    # now add children
    foreach el $args {
	eval [linsert $el 0 tree_el $tree $node $file]
   	# 8.5 # tree_el $tree $node $file {*}$el
    }
    return $node
}

proc ::fileutil::magic::cgen::2tree {script} {

    # Converts a recognizer which is in a simple script form into a
    # tree.

    variable tree
    set tree [::struct::tree]

    $tree set root path ""
    $tree set root otype Root
    $tree set root type root
    $tree set root message "unknown"

    # generate a test for each match
    set file "unknown"
    foreach el $script {
   	#puts "EL: $el"
   	if {[lindex $el 0] eq "file"} {
   	    set file [lindex $el 1]
   	} else {
	    set node [eval [linsert $el 0 tree_el $tree root $file]]
	    # 8.5 # set more [tree_el $tree root $file {*}$el]
   	    append result $node
   	}
    }
    optNum $tree root
    #optStr $tree root
    puts stderr "Script contains [llength [$tree children root]] discriminators"
    path $tree

    # Decoding the offsets, determination if we have to handle
    # relative offsets, and where. The less, the better.
    Offsets $tree

    return $tree
}

proc ::fileutil::magic::cgen::isStr {tree node} {
    return [expr {"S" eq [$tree get $node otype]}]
}

proc ::fileutil::magic::cgen::sortRegion {r1 r2} {
    set cmp 0
    if {[catch {
   	if {[string match (*) $r1] || [string match (*) $r2]} {
   	    set cmp [string compare $r1 $r2]
   	} else {
   	    set cmp [expr {[lindex $r1 0] - [lindex $r2 0]}]
   	    if {!$cmp} {
   		set cmp 0
   		set cmp [expr {[lindex $r1 1] - [lindex $r2 1]}]
   	    }
   	}
    } result]} {
   	set cmp [string compare $r1 $r2]
    }
    return $cmp
}

proc ::fileutil::magic::cgen::optStr {tree node} {
    variable regions
    catch {unset regions}
    array set regions {}

    optStr1 $tree $node

    puts stderr "Regions [array statistics regions]"
    foreach region [lsort \
	    -index   0 \
	    -command ::fileutil::magic::cgen::sortRegion \
	    [array name regions]] {
   	puts "$region - $regions($region)"
    }
}

proc ::fileutil::magic::cgen::optStr1 {tree node} {
    variable regions

    # traverse each numeric element of this node's children,
    # categorising them

    set kids [$tree children $node]
    foreach child $kids {
   	optStr1 $tree $child
    }

    set strings [$tree children $node filter ::fileutil::magic::cgen::isStr]
    #puts stderr "optstr: $node: $strings"

    foreach el $strings {
   	#if {[$tree get $el otype] eq "String"} {puts "[$tree getall $el] - [string length [$tree get $el val]]"}
	if {[$tree get $el comp] eq "x"} {
	    continue
	}

	set offset [$tree get $el offset]
	set len    [string length [$tree get $el val]]
	lappend regions([list $offset $len]) $el
    }
}

proc ::fileutil::magic::cgen::isNum {tree node} {
    return [expr {"N" eq [$tree get $node otype]}]
}

proc ::fileutil::magic::cgen::switchNSort {tree n1 n2} {
    return [expr {[$tree get $n1 val] - [$tree get $n1 val]}]
}

proc ::fileutil::magic::cgen::optNum {tree node} {
    array set offsets {}

    # traverse each numeric element of this node's children,
    # categorising them

    set kids [$tree children $node]
    foreach child $kids {
	optNum $tree $child
    }

    set numerics [$tree children $node filter ::fileutil::magic::cgen::isNum]
    #puts stderr "optNum: $node: $numerics"
    if {[llength $numerics] < 2} {
	return
    }

    foreach el $numerics {
	if {[$tree get $el comp] ne "=="} {
	    continue
	}
	lappend offsets([$tree get $el type],[$tree get $el offset],[$tree get $el qual]) $el
    }

    #puts "Offset: stderr [array get offsets]"
    foreach {match nodes} [array get offsets] {
	if {[llength $nodes] < 2} {
	    continue
	}

	catch {unset matcher}
	foreach n $nodes {
	    set nv [expr [$tree get $n val]]
	    if {[info exists matcher($nv)]} {
		puts stderr "*====================================="
		puts stderr "* Node         <[$tree getall $n]>"
		puts stderr "* clashes with <[$tree getall $matcher($nv)]>"
		puts stderr "*====================================="
	    } else {
		set matcher($nv) $n
	    }
	}

	foreach {type offset qual} [split $match ,] break
	set switch [$tree insert $node [$tree index [lindex $nodes 0]]]
	$tree set $switch otype   Switch
	$tree set $switch message $match
	$tree set $switch offset  $offset
	$tree set $switch type    $type
	$tree set $switch qual    $qual

	set nodes [lsort -command [list ::fileutil::magic::cgen::switchNSort $tree] $nodes]

	eval [linsert $nodes 0 $tree move $switch end]
	# 8.5 # $tree move $switch end {*}$nodes
	set     path [$tree get [$tree parent $switch] path]
	lappend path [$tree index $switch]
	$tree set $switch path $path
    }
}

proc ::fileutil::magic::cgen::Offsets {tree} {

    # Indicator if a node has to save field location information for
    # relative addressing. The 'kill' attribute is an accumulated
    # 'save' over the whole subtree. It will be used to determine when
    # level information was destroyed by subnodes and has to be
    # regenerated at the current level.

    $tree walk root -type dfs node {
	$tree set $node save 0
	$tree set $node kill 0
    }

    # We walk from the leafs up to the root, synthesizing the data
    # needed, as we go.
    $tree walk root -type dfs -order post node {
	if {$node eq "root"} continue
	DecodeOffset $tree $node [$tree get $node offset]

	# If the current node's parent is a switch, and the node has
	# to save, then the switch has to save. Because the current
	# node is not relevant during code generation anymore, the
	# switch is.

	if {[$tree get $node save]} {
	    # We save, therefore we kill.
	    $tree set $node kill 1
	    if {[$tree get [$tree parent $node] otype] eq "Switch"} {
		$tree set [$tree parent $node] save 1
	    }
	} else {
	    # We don't save i.e. kill, but we may inherit it from
	    # children which kill.

	    foreach c [$tree children $node] {
		if {[$tree get $c kill]} {
		    $tree set $node kill 1
		    break
		}
	    }
	}
    }
}

proc ::fileutil::magic::cgen::DecodeOffset {tree node offset} {
    if {[string match "(*)" $offset]} {
	# Indirection offset. (Decoding is non-trivial, therefore
	# packed into a proc).

	set ind 1 ; # Indirect location
	foreach {rel base itype idelta} [DecodeIndirectOffset $offset] break

    } elseif {[string match "&*" $offset]} {
	# Direct relative offset. (Decoding is trivial)

	set ind    0       ; # Direct location
	set rel    1       ; # Relative
	set base   [string range $offset 1 end] ; # Base Delta
	set itype  {}      ; # No data for indirect
	set idelta {}      ; # s.a.

    } else {
	set ind    0       ; # Direct location
	set rel    0       ; # Absolute
	set base   $offset ; # Here!
	set itype  {}      ; # No data for indirect
	set idelta {}      ; # s.a.
    }

    # Store the expanded data back into the tree.

    foreach v {ind rel base itype idelta} {
	$tree set $node $v [set $v]
    }

    # For nodes with adressing relative to last field above the latter
    # has to save this information.

    if {$rel} {
	$tree set [$tree parent $node] save 1
    }
    return
}

proc ::fileutil::magic::cgen::DecodeIndirectOffset {offset} {
    variable otmap ; # Offset typemap.

    # Offset parser.
    # Syntax:
    #   ( ?&? number ?.[bslBSL]? ?[+-]? ?number? )

    set n {(([0-9]+)|(0x[0-9A-Fa-f]+))}
    set o "\\((&?)(${n})((\\.\[bslBSL])?)(\[+-]?)(${n}?)\\)"
    #         |   | ||| ||               |       | |||
    #         1   2 345 67               8       9 012
    #         ^   ^     ^                ^       ^
    #         rel base  type             sign    index
    #
    #                            1   2    3 4 5 6    7 8    9   0 1 2
    set ok [regexp $o $offset -> rel base _ _ _ type _ sign idx _ _ _]

    if {!$ok} {
        return -code error "Bad offset \"$offset\""
    }

    # rel is in {"", &}, map to 0|1
    if {$rel eq ""} {set rel 0} else {set rel 1}

    # base is a number, enforce decimal. Not optional.
    set base [expr $base]

    # Type is in .b .s .l .B .S .L, and "". Map to a regular magic
    # type code.
    set type $otmap($type)

    # sign is in {+,-,""}. Map to -|"" (Becomes sign of index)
    if {$sign eq "+"} {set sign ""}

    # Index is optional number. Enforce decimal, empty is zero. Add in
    # the sign as well for a proper signed index.

    if {$idx eq ""} {set idx 0}
    set idx $sign[expr $idx]

    return [list $rel $base $type $idx]
}

proc ::fileutil::magic::cgen::treedump {tree} {
    set result ""
    $tree walk root -type dfs node {
	set path  [$tree get $node path]
	set depth [llength $path]

	append result [string repeat "  " $depth] [list $path] ": " [$tree get $node type]:

	if {[$tree keyexists $node offset]} {
	    append result " ,O|[$tree get $node offset]|"

	    set x {}
	    foreach v {ind rel base itype idelta} {lappend x [$tree get $node $v]}
	    append result "=<[join $x !]>"
	}
	if {[$tree keyexists $node qual]} {
	    set q [$tree get $node qual]
	    if {$q ne ""} {
		append result " ,q/$q/"
	    }
	}

	if {[$tree keyexists $node comp]} {
	    append result " " C([$tree get $node comp])
	}
	if {[$tree keyexists $node val]} {
	    append result " " V([$tree get $node val])
	}

	if {[$tree keyexists $node otype]} {
	    append result " " [$tree get $node otype]/[$tree get $node save]
	}

	if {$depth == 1} {
	    set msg [$tree get $node message]
	    set n $node
	    while {($n != {}) && ($msg == "")} {
		set n [lindex [$tree children $n] 0]
		if {$n != {}} {
		    set msg [$tree get $n message]
		}
	    }
	    append result " " ( $msg )
	    if {[$tree keyexists $node file]} {
		append result " - " [$tree get $node file]
	    }
	}

	#append result " <" [$tree getall $node] >
	append result \n
    }
    return $result
}

proc ::fileutil::magic::cgen::treegen {tree node} {
    return "[treegen1 $tree $node]\nresult\n"
}

proc ::fileutil::magic::cgen::treegen1 {tree node} {
    variable ::fileutil::magic::rt::typemap

    set result ""
    foreach k {otype type offset comp val qual message save path} {
	if {[$tree keyexists $node $k]} {
	    set $k [$tree get $node $k]
	}
    }

    set level [llength $path]

    # Generate code for each node per its type.

    switch $otype {
	N -
	S {
	    if {$save} {
		# We have to save field data for relative adressing under this
		# leaf.
		if {$otype eq "N"} {
		    set type [list Nx $level $type]
		} elseif {$otype eq "S"} {
		    set type [list Sx $level]
		}
	    } else {
		# Regular fetching of information.
		if {$otype eq "N"} {
		    set type [list N $type]
		} elseif {$otype eq "S"} {
		    set type S
		}
	    }

	    set offset [GenerateOffset $tree $node]

	    if {$qual eq ""} {
		append result "if \{\[$type $offset $comp [list $val]\]\} \{"
	    } else {
		append result "if \{\[$type $offset $comp [list $val] $qual\]\} \{"
	    }

	    if {[$tree isleaf $node]} {
		if {$message ne ""} {
		    append result "emit [list $message]"
		} else {
		    append result "emit [$tree get $node path]"
		}
	    } else {
		# If we saved data the child branches may destroy
		# level information. We regenerate it if needed.

		if {$message ne ""} {
		    append result "emit [list $message]\n"
		}

		set killed 0
		foreach child [$tree children $node] {
		    if {$save && $killed && [$tree get $child rel]} {
			# This location already does not regenerate if
			# the killing subnode was last. We also do not
			# need to regenerate if the current subnode
			# does not use relative adressing.
			append result "L $level;"
			set killed 0
		    }
		    append result [treegen1 $tree $child]
		    set killed [expr {$killed || [$tree get $child kill]}]
		}
		#append result "\nreturn \$result"
	    }

	    append result "\}\n"
	}
	Root {
	    foreach child [$tree children $node] {
		append result [treegen1 $tree $child]
	    }
	}
	Switch {
	    set offset [GenerateOffset $tree $node]

	    if {$save} {
		set fetch "Nvx $level"
	    } else {
		set fetch Nv
	    }

	    append fetch " " $type " " $offset
	    if {$qual ne ""} {
		append fetch " " $qual
	    }
	    append result "switch -- \[$fetch\] "

	    set scan [lindex $typemap($type) 1]

	    set ckilled 0
	    foreach child [$tree children $node] {
		binary scan [binary format $scan [$tree get $child val]] $scan val
		append result "$val \{"

		if {$save && $ckilled} {
		    # This location already does not regenerate if
		    # the killing subnode was last. We also do not
		    # need to regenerate if the current subnode
		    # does not use relative adressing.
		    append result "L $level;"
		    set ckilled 0
		}

		if {[$tree isleaf $child]} {
		    append result "emit [list [$tree get $child message]]"
		} else {
		    set killed 0
		    append result "emit [list [$tree get $child message]]\n"
		    foreach grandchild [$tree children $child] {
			if {$save && $killed && [$tree get $grandchild rel]} {
			    # This location already does not regenerate if
			    # the killing subnode was last. We also do not
			    # need to regenerate if the current subnode
			    # does not use relative adressing.
			    append result "L $level;"
			    set killed 0
			}
			append result [treegen1 $tree $grandchild]
			set killed [expr {$killed || [$tree get $grandchild kill]}]
		    }
		}

		set ckilled [expr {$ckilled || [$tree get $child kill]}]
		append result "\} "
	    }
	    append result "\n"
	}
    }
    return $result
}

proc ::fileutil::magic::cgen::GenerateOffset {tree node} {
    # Examples:
    # direct absolute:     45      -> 45
    # direct relative:    &45      -> [R 45]
    # indirect absolute:  (45.s+1) -> [I 45 s 1]
    # indirect relative: (&45.s+1) -> [I [R 45] s 1]

    foreach v {ind rel base itype idelta} {
	set $v [$tree get $node $v]
    }

    if {$rel} {set base "\[R $base\]"}
    if {$ind} {set base "\[I $base $itype $idelta\]"}
    return $base
}

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
