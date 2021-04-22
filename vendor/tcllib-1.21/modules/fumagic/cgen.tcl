# cgen.tcl --
#
#	Generator core for compiler of magic(5) files into recognizers
#	based on the 'rtcore'.
#
# Copyright (c) 2016      Poor Yorick     <tk.tcl.core.tcllib@pooryorick.com>
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

package provide fileutil::magic::cgen 1.3.0

# ### ### ### ######### ######### #########
## Implementation

namespace eval ::fileutil::magic {
    namespace export *
}
namespace eval ::fileutil::magic::cgen {
    namespace ensemble create
    namespace export *
    # Import the runtime typemap into our scope.
    variable ::fileutil::magic::rt::typemap

    # The tree most operations use for their work.
    variable tree {}

    # Generator data structure.
    variable regions

    # Export the API
    namespace export 2tree treedump treegen

   # Assumption : the parser folds the test inversion operator into equality and
   # inequality operators .
    variable offsetskey {
	type o rel ind ir it ioi ioo iir io compinvert mod mand
    }

    variable indent {}
    variable indents {}
    variable innamed 0
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


proc ::fileutil::magic::cgen::LessIndent {} {
    variable indent
    variable indents
    set size [expr {[string length $indent] - 1}]
    if {[dict exists $indents $size]} {
	set indent [dict get $indents $size]
    } else {
	set indent [string repeat \t $size]
	dict set indents $size $indent
    }
    return
}

proc ::fileutil::magic::cgen::MoreIndent {} {
    variable indent
    variable indents
    set size [expr {[string length $indent] + 1}]
    if {[dict exists $indents $size]} {
        set indent [dict get $indents $size]
    } else {
        set indent [string repeat \t $size]
        dict set indents $size $indent
    }
    return
}


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

proc ::fileutil::magic::cgen::tree_el {tree node} {
    set parent [$tree parent $node]
    if {[$tree keyexists $parent path]} {
	set path [$tree get $parent path]
    } else {
	set path {} 
    }
    lappend path [$tree index $node]
    $tree set $node path $path

    foreach name {type} {
	set $name [$tree get $node $name]
    }

    puts stderr [list frlaalm [$tree getall $node]]

    # Recursively creates and annotates a node for the specified
    # tests, and its sub-tests (args).


    # generate a proc call type for the type, Numeric or String
    variable ::fileutil::magic::rt::typemap

    switch -glob -- $type {
   	*byte* -
	*double* -
	*float* -
   	*short* -
   	*long* -
	*quad* -
   	*date* {
   	    $tree set $node otype N
   	}
   	clear - search - regex - *string* {
   	    $tree set $node otype S
   	}
	name {
	    $tree set $node otype A
	}
	use {
	    $tree set $node otype U
	}
	default {
	    $tree set $node otype D
	}
	indirect {
	    $tree set $node otype T
	}
   	default {
   	    puts stderr "Unknown type: '$type'"
	    $tree set $node otype Unknown
   	}
    }

    # Stores the type determined above, and the arguments into
    # attributes of the new node.

    # now add children
    foreach el [$tree children $node] {
	tree_el $tree $el
    }
    return
}

proc ::fileutil::magic::cgen::2tree {tree} {

    foreach child [$tree children root] {
	tree_el $tree $child
    }
    optNum $tree root
    #optStr $tree root
    puts stderr "Script contains [llength [$tree children root]] discriminators"
    path $tree

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

	set o [$tree get $el o]
	set len    [string length [$tree get $el val]]
	lappend regions([list $o $len]) $el
    }
}

proc ::fileutil::magic::cgen::isNum {tree node} {
    return [expr {"N" eq [$tree get $node otype]}]
}

proc ::fileutil::magic::cgen::switchNSort {tree n1 n2} {

    # deal with the fact that [lsort] barfs if the result is larger than 32
    # bits
    set val1 [$tree get $n1 val]
    set val2 [$tree get $n2 val]
    expr {$val1 > $val2 ? 1 : $val1 < $val2 ? -1 : 0}
}

proc ::fileutil::magic::cgen::optNum {tree node} {
    variable offsetskey
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
	if {[$tree get $el comp] ne {==}} {
	    continue
	}
	set key {}
	foreach name $offsetskey {
	    lappend key [$tree get $el $name]
	}
	lappend offsets([join $key ,]) $el
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

	foreach $offsetskey [split $match ,] break
	set switch [$tree insert $node [$tree index [lindex $nodes 0]]]
	$tree set $switch otype   Switch
	$tree set $switch desc $match
	foreach name $offsetskey {
	    $tree set $switch $name [set $name]
	}

	set nodes [lsort -command [list ::fileutil::magic::cgen::switchNSort $tree] $nodes]

	eval [linsert $nodes 0 $tree move $switch end]
	# 8.5 # $tree move $switch end {*}$nodes
	set     path [$tree get [$tree parent $switch] path]
	lappend path [$tree index $switch]
	$tree set $switch path $path

	set level [$tree get [$tree parent $switch] level]
	$tree set $switch level [expr {$level+1}]
    }
}


# Useful when debugging
proc ::fileutil::magic::cgen::stack {tree node} {
    set res {}
    set files [$tree get root files]
    while 1 {
	set s [dict create \
	    file [lindex $files [$tree get $node file]] \
	    linenum [$tree get $node linenum]]
	if {[$tree keyexists $node origin]} {
	    set origin [$tree get $node origin]
	    dict set s origin [dict create \
		name [$tree get $origin val] \
		file [lindex $files [$tree get $origin file]] \
		linenum [$tree get $origin linenum]]
	}
	set res [linsert $res 0 $s]
	set node [$tree parent $node]
	if {$node eq {root}} {
	    break
	}
    }
    return $res
}

proc ::fileutil::magic::cgen::treedump {tree} {
    set result ""
    $tree walk root -type dfs node {
	set path  [$tree get $node path]
	set depth [llength $path]

	append result [string repeat "  " $depth] [list $path] ": " [$tree get $node type]:

	if {[$tree keyexists $node o]} {
	    append result " ,O|[$tree get $node o]|"

	    set x {}
	    foreach v {ind rel base itype iop ioperand idelta} {lappend x [$tree get $node $v]}
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
	    append result " " [$tree get $node otype]
	}

	if {$depth == 1} {
	    set msg [$tree get $node desc]
	    set n $node
	    while {($n != {}) && ($msg == "")} {
		set n [lindex [$tree children $n] 0]
		if {$n != {}} {
		    set msg [$tree get $n desc]
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
    variable indent
    variable innamed
    variable ::fileutil::magic::rt::typemap

    set result {} 
    set otype [$tree get $node otype]
    set level [$tree get $node level]

    # Generate code for each node per its type.

    switch $otype {
	A {
	    incr innamed
	    try  {
		set file [$tree get $node file]
		set val [$tree get $node val]
		if {[dict exists named $file$val]} {
		    return -code error [list {name already exists} $file $val]
		}
		set aresult {}
		foreach child [$tree children $node] {
		    lappend aresult [treegen $tree $child]
		}
		set named [$tree get root named]
		dict set named $file $val [join $aresult \n]
		$tree set root named $named
		return
	    } finally {
		incr innamed -1
	    }
	}
	U {
	    set file [$tree get $node file]
	    set val [$tree get $node val]
	    # generateOffset is expanded via subsitution
	    append result "${indent}U [list $file] [list $val] [
		GenerateOffset $tree $node]\n" 
	}
	N - S - D {
	    set names {type mod mand testinvert compinvert comp val desc path}
	    foreach name $names {
		set $name [$tree get $node $name]
	    }

	    set o [GenerateOffset $tree $node]

	    if {$val eq {}} {
		# If the value is the empty string, armor it.  Otherwise, it's
		# already been armored.
		set val [list $val]
	    }

	    switch $otype {
		N {
		    set type [list N $type]
		    # $type and $o are expanded via substitution 
		    append result "${indent}if \{\[$type $o [list $testinvert] [
			list $compinvert] [list $mod] [list $mand] [
			list $comp] $val\]\} \{\n"
			MoreIndent
			append result "${indent}>\n"
		}
		S {
		    switch $comp {
			== {set comp eq}
			!= {set comp ne}
		    }

		    set type [list S $type]

		    append result "${indent}if \{\[$type $o [list $testinvert] [
			list $mod] [list $mand] [list $comp] $val\]\} \{\n"
			MoreIndent
			append result "${indent}>\n"
		}

		D {
		    set type [list D]
		    append result "${indent}if \{\[$type $o]\} \{\n" 
			MoreIndent
			append result "${indent}>\n"

		}
	    }

	    MoreIndent

		if {[$tree isleaf $node] && $desc ne {}} {
		    append result "${indent}emit [list $desc]\n"
		} else {
		    if {$desc ne {}} {
			append result "${indent}emit [list $desc]\n"
		    }
		    foreach child [$tree children $node] {
			append result [treegen $tree $child]\n
		    }
		    #append result "\nreturn \$result"
		}

		if {[$tree keyexists $node ext_mime]} {
		    append result "${indent}mime [list [$tree get $node ext_mime]]\n"
		}

		if {[$tree keyexists $node ext_ext]} {
		    append result "${indent}ext [list [$tree get $node ext_ext]]\n"
		}

		if {[$tree keyexists $node ext_strength]} {
		    append result "${indent}strength [list [$tree get $node ext_strength]]\n"
		}

	    LessIndent

	    append result ${indent}<\n
	    LessIndent
	    append result ${indent}\}\n
	}
	T {
	    set desc [$tree get $node desc]
	    if {$desc ne {}} {
		append result "${indent}emit [list $desc]\n"
	    }
	    set o [GenerateOffset $tree $node]
	    set mod [$tree get $node mod]
	    append result "${indent}T $o [list $mod]\n"
	}
	Root {
	    foreach child [$tree children $node] {
		lappend result [treegen $tree $child]
		if {[lindex $result end] eq {}} {
		    set result [lreplace $result[set result {}] end end]
		}
	    }
	}
	Switch {
	    set names {o type compinvert mod mand}
	    foreach name $names {
		set $name [$tree get $node $name]
	    }
	    set o [GenerateOffset $tree $node]

	    set fetch Nv

	    append fetch " $type $o [list $compinvert] [list $mod] [list $mand]"
	    append result "${indent}switch \[$fetch\] \{\n"

	    MoreIndent

		set scan [lindex $typemap($type) 1]

		foreach child [lsort -command [
		    list ::fileutil::magic::cgen::switchNSort $tree] [
			$tree children $node]] {

		    # See ::fileutil::magic::rt::rtscan
		    if {$scan eq {me}} {
			set scan I
		    }

		    set val [$tree get $child val]

		    if {[info exists lastval] && $lastval != $val} {
			LessIndent
			append result "${indent}\}\n"
		    } 

		    if {![info exists lastval] || $lastval != $val} {
			append result "${indent}$val \{\n"
			MoreIndent
		    }

		    append result "${indent}>\n"

		    MoreIndent

			set desc [$tree get $child desc]

			# emit, mime, and ext come first so that they are
			# picked up when child nodes produce results

			if {$desc ne {}} {
			    append result "${indent}emit [list $desc]\n"
			}

			if {[$tree keyexists $child ext_mime]} {
			    append result "${indent}mime [list [
				$tree get $child ext_mime]]\n"
			}

			if {[$tree keyexists $child ext_ext]} {
			    append result "${indent}ext [list [
				$tree get $child ext_ext]]\n"
			}

			if {![$tree isleaf $child]} {
			    foreach grandchild [$tree children $child] {
				append result [treegen $tree $grandchild]\n
			    }
			}
		    LessIndent

		    append result "${indent}<\n"

		    set lastval $val
		}

	    LessIndent
	    append result "${indent}\}\n"

	    LessIndent
	    append result "${indent}\}\n"
	}
    }
    return $result
}

proc ::fileutil::magic::cgen::GenerateOffset {tree node} {
    # Examples:
    # direct absolute:     45      -> 45
    # direct relative:    &45      -> [R 45]
    # indirect absolute:  (45.s+1) -> [I 45 s + 0 1]
    # indirect absolute (indirect offset):  (45.s+(1)) -> [I 45 s + 1 1]
    # relative indirect absolute:  &(45.s+1) -> [R [I 45 s + 0 1]]
    # relative indirect absolute (indirect offset):  &(45.s+(1)) -> [R [I 45 s + 1 1]]
    # indirect relative: (&45.s+1) -> [I [R 45] s op 0 1]
    # relative indirect relative: &(&45.s+1) -> [R [I [R 45] s + 0 1]]
    # relative indirect relative: &(&45.s+(1)) -> [R [I [R 45] s + 1 1]]

    variable innamed

    foreach v {o rel ind ir it ioi iir ioo io} {
	set $v [$tree get $node $v]
    }

    #foreach v {ind rel base itype iop ioperand iindir idelta} {
    #    set $v [$tree get $node $v]
    #}

    if {$ind} {
	if {$ir} {set o "\[R $o]"}
	set o "\[I $o [list $it] [list $ioi] [list $ioo] [list $iir] [list $io]\]"
    }

    # spec
    #   named instance direct offsets are relative to the offset of the
    #   previous matched entry
    if {$innamed} {
	set o "\[O $o]"
    }

    if {$rel} {
	set o "\[R $o\]"
    }
    
    return $o
}

# ### ### ### ######### ######### #########
## Ready for use.
# EOF
