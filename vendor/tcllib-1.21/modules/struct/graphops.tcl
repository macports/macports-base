# graphops.tcl --
#
#	Operations on and algorithms for graph data structures.
#
# Copyright (c) 2008 Alejandro Paz <vidriloco@gmail.com>, algorithm implementation
# Copyright (c) 2008 Andreas Kupries, integration with Tcllib's struct::graph
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: graphops.tcl,v 1.19 2009/09/24 19:30:10 andreas_kupries Exp $

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.6

package require struct::disjointset ; # Used by kruskal -- 8.6 required
package require struct::prioqueue   ; # Used by kruskal, prim
package require struct::queue       ; # Used by isBipartite?, connectedComponent(Of)
package require struct::stack       ; # Used by tarjan
package require struct::graph       ; # isBridge, isCutVertex
package require struct::tree        ; # Used by BFS

# ### ### ### ######### ######### #########
##

namespace eval ::struct::graph::op {}

# ### ### ### ######### ######### #########
##

# This command constructs an adjacency matrix representation of the
# graph argument.

# Reference: http://en.wikipedia.org/wiki/Adjacency_matrix
#
# Note: The reference defines the matrix in such a way that some of
#       the limitations of the code here are not present. I.e. the
#       definition at wikipedia deals properly with arc directionality
#       and parallelism.
#
# TODO: Rework the code so that the result is in line with the reference.
#       Add features to handle weights as well.

proc ::struct::graph::op::toAdjacencyMatrix {g} {
    set nodeList [lsort -dict [$g nodes]]
    # Note the lsort. This is used to impose some order on the matrix,
    # for comparability of results. Otherwise different versions of
    # Tcl and struct::graph (critcl) may generate different, yet
    # equivalent matrices, dependent on things like the order a hash
    # search is done, or nodes have been added to the graph, or ...

    # Fill an array for index tracking later. Note how we start from
    # index 1. This allows us avoid multiple expr+1 later on when
    # iterating over the nodes and converting the names to matrix
    # indices. See (*).

    set i 1
    foreach n  $nodeList {
	set nodeDict($n) $i
	incr i
    }

    set matrix {}
    lappend matrix [linsert $nodeList 0 {}]

    # Setting up a template row with all of it's elements set to zero.

    set baseRow 0
    foreach n $nodeList {
	lappend baseRow 0
    }

    foreach node $nodeList {

	# The first element in every row is the name of its
	# corresponding node. Using lreplace to overwrite the initial
	# data in the template we get a copy apart from the template,
	# which we can then modify further.

	set currentRow [lreplace $baseRow 0 0 $node]

	# Iterate over the neighbours, also known as 'adjacent'
	# rows. The exact set of neighbours depends on the mode.

	foreach neighbour [$g nodes -adj $node] {
	    # Set value for neighbour on this node list
	    set at $nodeDict($neighbour)

	    # (*) Here we avoid +1 due to starting from index 1 in the
	    #     initialization of nodeDict.
	    set currentRow [lreplace $currentRow $at $at 1]
	}
	lappend matrix $currentRow
    }

    # The resulting matrix is a list of lists, size (n+1)^2 where n =
    # number of nodes. First row and column (index 0) are node
    # names. The other entries are boolean flags. True when an arc is
    # present, False otherwise. The matrix represents an
    # un-directional form of the graph with parallel arcs collapsed.

    return $matrix
}

#Adjacency List
#-------------------------------------------------------------------------------------
#Procedure creates for graph G, it's representation as Adjacency List.
#
#In comparison to Adjacency Matrix it doesn't force using array with quite big
#size - V^2, where V is a number of vertices ( instead, memory we need is about O(E) ).
#It's especially important when concerning rare graphs ( graphs with amount of vertices
#far bigger than amount of edges ). In practise, it turns out that generally,
#Adjacency List is more effective. Moreover, going through the set of edges take
#less time ( O(E) instead of O(E^2) ) and adding new edges is rapid.
#On the other hand, checking if particular edge exists in graph G takes longer
#( checking if edge {v1,v2} belongs to E(G) in proportion to min{deg(v1,v2)} ).
#Deleting an edge is also longer - in proportion to max{ deg(v1), deg(v2) }.
#
#Input:
# graph G ( directed or undirected ). Default is undirected.
#
#Output:
# Adjacency List for graph G, represented by dictionary containing lists of adjacent nodes
#for each node in G (key).
#
#Options:
# -weights - adds to returning dictionary arc weights for each connection between nodes, so
#each node returned by list as adjacent has additional parameter - weight of arc between him and
#current node.
# -directed - sets graph G to be interpreted as directed graph.
#
#Reference:
#http://en.wikipedia.org/wiki/Adjacency_list
#

proc ::struct::graph::op::toAdjacencyList {G args} {

    set arcTraversal "undirected"
    set weightsOn 0

    #options for procedure
    foreach option $args {
	switch -exact -- $option {
	    -directed {
		set arcTraversal "directed"
	    }
	    -weights {
		#checking if all edges have their weights set
		VerifyWeightsAreOk $G
		set weightsOn 1
	    }
	    default {
		return -code error "Bad option \"$option\". Expected -directed or -weights"
	    }
	}
    }

    set V [lsort -dict [$G nodes]]

    #mainloop
    switch -exact -- $arcTraversal {
	undirected {
	    #setting up the Adjacency List with nodes
	    foreach v [lsort -dict [$G nodes]] {
		dict set AdjacencyList $v {}
	    }
	    #appending the edges adjacent to nodes
	    foreach e [$G arcs] {

		set v [$G arc source $e]
		set u [$G arc target $e]

		if { !$weightsOn } {
		    dict lappend AdjacencyList $v $u
		    dict lappend AdjacencyList $u $v
		} else {
		    dict lappend AdjacencyList $v [list $u [$G arc getweight $e]]
		    dict lappend AdjacencyList $u [list $v [$G arc getweight $e]]
		}
	    }
	    #deleting duplicated edges
	    foreach x [dict keys $AdjacencyList] {
		dict set AdjacencyList $x [lsort -unique [dict get $AdjacencyList $x]]
	    }
	}
	directed {
	    foreach v $V {
		set E [$G arcs -out $v]
		set adjNodes {}
		foreach e $E {
		    if { !$weightsOn } {
			lappend adjNodes [$G arc target $e]
		    } else {
			lappend adjNodes [list [$G arc target $e] [$G arc getweight $e]]
		    }
		}
		dict set AdjacencyList $v $adjNodes
	    }
	}
	default {
	    return -code error "Error while executing procedure"
	}
    }

    return $AdjacencyList
}

#Bellman's Ford Algorithm
#-------------------------------------------------------------------------------------
#Searching for shortest paths between chosen node and
#all other nodes in graph G. Based on relaxation method. In comparison to Dijkstra
#it doesn't assume that all weights on edges are positive. However, this generality
#costs us time complexity - O(V*E), where V is number of vertices and E is number
#of edges.
#
#Input:
#Directed graph G, weighted on edges and not containing
#any cycles with negative sum of weights ( the presence of such cycles means
#there is no shortest path, since the total weight becomes lower each time the
#cycle is traversed ). Possible negative weights on edges.
#
#Output:
#dictionary d[u] - distances from start node to each other node in graph G.
#
#Reference: http://en.wikipedia.org/wiki/Bellman-Ford_algorithm
#

proc ::struct::graph::op::BellmanFord { G startnode } {

    #checking if all edges have their weights set
    VerifyWeightsAreOk $G

    #checking if the startnode exists in given graph G
    if {![$G node exists $startnode]} {
	return -code error "node \"$startnode\" does not exist in graph \"$G\""
    }

    #sets of nodes and edges for graph G
    set V [$G nodes]
    set E [$G arcs]

    #initialization
    foreach i $V {
	dict set distances $i Inf
    }

    dict set distances $startnode 0

    #main loop (relaxation)
    for { set i 1 } { $i <= ([dict size $distances]-1) } { incr i } {

	foreach j $E {
	    set u [$G arc source $j]	;# start node of edge j
	    set v [$G arc target $j]	;# end node of edge j

	    if { [ dict get $distances $v ] > [ dict get $distances $u ] + [ $G arc getweight $j ]} {
		dict set distances $v [ expr {[dict get $distances $u] + [$G arc getweight $j]} ]
	    }
	}
    }

    #checking if there exists cycle with negative sum of weights
    foreach i $E {
	set u [$G arc source $i]	;# start node of edge i
	set v [$G arc target $i]	;# end node of edge i

	if { [dict get $distances $v] > [ dict get $distances $u ] + [$G arc getweight $i] } {
	    return -code error "Error. Given graph \"$G\" contains cycle with negative sum of weights."
	}
    }

    return $distances

}


#Johnson's Algorithm
#-------------------------------------------------------------------------------------
#Searching paths between all pairs of vertices in graph. For rare graphs
#asymptotically quicker than Floyd-Warshall's algorithm. Johnson's algorithm
#uses Bellman-Ford's and Dijkstra procedures.
#
#Input:
#Directed graph G, weighted on edges and not containing
#any cycles with negative sum of weights ( the presence of such cycles means
#there is no shortest path, since the total weight becomes lower each time the
#cycle is traversed ). Possible negative weights on edges.
#Possible options:
# 	-filter ( returns only existing distances, cuts all Inf values for
#  non-existing connections between pairs of nodes )
#
#Output:
# Dictionary containing distances between all pairs of vertices
#
#Reference: http://en.wikipedia.org/wiki/Johnson_algorithm
#

proc ::struct::graph::op::Johnsons { G args } {

    #options for procedure
    set displaymode 0
    foreach option $args {
	switch -exact -- $option {
	    -filter {
		set displaymode 1
	    }
	    default {
		return -code error "Bad option \"$option\". Expected -filter"
	    }
	}
    }

    #checking if all edges have their weights set
    VerifyWeightsAreOk $G

    #Transformation of graph G - adding one more node connected with
    #each existing node with an edge, which weight is 0
    set V [$G nodes]
    set s [$G node insert]

    foreach i $V {
	if { $i ne $s } {
	    $G arc insert $s $i
	}
    }

    $G arc setunweighted

    #set potential values with Bellman-Ford's
    set h [BellmanFord $G $s]

    #transformed graph no needed longer - deleting added node and edges
    $G node delete $s

    #setting new weights for edges in graph G
    foreach i [$G arcs] {
	set u [$G arc source $i]
	set v [$G arc target $i]

	lappend weights [$G arc getweight $i]
	$G arc setweight $i [ expr { [$G arc getweight $i] + [dict get $h $u] - [dict get $h $v] } ]
    }

    #finding distances between all pair of nodes with Dijkstra started from each node
    foreach i [$G nodes] {
	set dijkstra [dijkstra $G $i -arcmode directed -outputformat distances]

	foreach j [$G nodes] {
	    if { $i ne $j } {
		if { $displaymode eq 1 } {
		    if { [dict get $dijkstra $j] ne "Inf" } {
			dict set values [list $i $j] [ expr {[ dict get $dijkstra $j] - [dict get $h $i] + [dict get $h $j]} ]
		    }
		} else {
		    dict set values [list $i $j] [ expr {[ dict get $dijkstra $j] - [dict get $h $i] + [dict get $h $j]} ]
		}
	    }
	}
    }

    #setting back edge weights for graph G
    set k 0
    foreach i [$G arcs] {
	$G arc setweight $i [ lindex $weights $k ]
	incr k
    }

    return $values
}


#Floyd-Warshall's Algorithm
#-------------------------------------------------------------------------------------
#Searching shortest paths between all pairs of edges in weighted graphs.
#Time complexity: O(V^3) - where V is number of vertices.
#Memory complexity: O(V^2)
#Input: directed weighted graph G
#Output: dictionary containing shortest distances to each node from each node
#
#Algorithm finds solutions dynamically. It compares all possible paths through the graph
#between each pair of vertices. Graph shouldn't possess any cycle with negative
#sum of weights ( the presence of such cycles means there is no shortest path,
#since the total weight becomes lower each time the cycle is traversed ).
#On the other hand algorithm can be used to find those cycles - if any shortest distance
#found by algorithm for any nodes v and u (when v is the same node as u) is negative,
#that node surely belong to at least one negative cycle.
#
#Reference: http://en.wikipedia.org/wiki/Floyd-Warshall_algorithm
#

proc ::struct::graph::op::FloydWarshall { G } {

    VerifyWeightsAreOk $G

    foreach v1 [$G nodes] {
	foreach v2 [$G nodes] {
	    dict set values [list $v1 $v2] Inf
	}
	dict set values [list $v1 $v1] 0
    }

    foreach e [$G arcs] {
	set v1 [$G arc source $e]
	set v2 [$G arc target $e]
	dict set values [list $v1 $v2] [$G arc getweight $e]
    }

    foreach u [$G nodes] {
	foreach v1 [$G nodes] {
	    foreach v2 [$G nodes] {

		set x [dict get $values [list $v1 $u]]
		set y [dict get $values [list $u $v2]]
		set d [ expr {$x + $y}]

		if { [dict get $values [list $v1 $v2]] > $d } {
		    dict set values [list $v1 $v2] $d
		}
	    }
	}
    }
    #finding negative cycles
    foreach v [$G nodes] {
	if { [dict get $values [list $v $v]] < 0 } {
	    return -code error "Error. Given graph \"$G\" contains cycle with negative sum of weights."
	}
    }

    return $values
}

#Metric Travelling Salesman Problem (TSP) - 2 approximation algorithm
#-------------------------------------------------------------------------------------
#Travelling salesman problem is a very popular problem in graph theory, where
#we are trying to find minimal Hamilton cycle in weighted complete graph. In other words:
#given a list of cities (nodes) and their pairwise distances (edges), the task is to find
#a shortest possible tour that visits each city exactly once.
#TSP problem is NP-Complete, so there is no efficient algorithm to solve it. Greedy methods
#are getting extremely slow, with the increase in the set of nodes.
#
#For this algorithm we consider a case when for given graph G, the triangle inequality is
#satisfied. So for example, for any three nodes A, B and C the distance between A and C must
#be at most the distance from A to B plus the distance from B to C. What's important
#most of the considered cases in TSP problem will satisfy this condition.
#
#Input: undirected, weighted graph G
#Output: approximated solution of minimum Hamilton Cycle - closed path visiting all nodes,
#each exactly one time.
#
#Reference: http://en.wikipedia.org/wiki/Travelling_salesman_problem
#

proc ::struct::graph::op::MetricTravellingSalesman { G } {

    #checking if graph is connected
    if { ![isConnected? $G] } {
	return -code error "Error. Given graph \"$G\" is not a connected graph."
    }
    #checking if all weights are set
    VerifyWeightsAreOk $G

    # Extend graph to make it complete.
    # NOTE: The graph is modified in place.
    createCompleteGraph $G originalEdges

    #create minimum spanning tree for graph G
    set T [prim $G]

    #TGraph - spanning tree of graph G
    #filling TGraph with edges and nodes
    set TGraph [createTGraph $G $T 0]

    #finding Hamilton cycle
    set result [findHamiltonCycle $TGraph $originalEdges $G]

    $TGraph destroy

    # Note: Fleury, which is the algorithm used to find our the cycle
    # (inside of isEulerian?) is inherently directionless, i.e. it
    # doesn't care about arc direction. This does not matter if our
    # input is a symmetric graph, i.e. u->v and v->u have the same
    # weight for all nodes u, v in G, u != v. But for an asymmetric
    # graph as our input we really have to check the two possible
    # directions of the returned tour for the one with the smaller
    # weight. See test case MetricTravellingSalesman-1.1 for an
    # exmaple.

    set w {}
    foreach a [$G arcs] {
	set u [$G arc source $a]
	set v [$G arc target $a]
	set uv [list $u $v]
	# uv = <$G arc nodes $arc>
	dict set w $uv [$G arc getweight $a]
    }
    foreach k [dict keys $w] {
	lassign $k u v
	set vu [list $v $u]
	if {[dict exists $w $vu]} continue
	dict set w $vu [dict get $w $k]
    }

    set reversed [lreverse $result]

    if {[TourWeight $w $result] > [TourWeight $w $reversed]} {
	return $reversed
    }
    return $result
}

proc ::struct::graph::op::TourWeight {w tour} {
    set total 0
    foreach \
	u [lrange $tour 0 end-1] \
	v [lrange $tour 1 end] {
	    set uv [list $u $v]
	    set total [expr {
			     $total +
			     [dict get $w $uv]
			 }]
	}
    return $total
}

#Christofides Algorithm - for Metric Travelling Salesman Problem (TSP)
#-------------------------------------------------------------------------------------
#Travelling salesman problem is a very popular problem in graph theory, where
#we are trying to find minimal Hamilton cycle in weighted complete graph. In other words:
#given a list of cities (nodes) and their pairwise distances (edges), the task is to find
#a shortest possible tour that visits each city exactly once.
#TSP problem is NP-Complete, so there is no efficient algorithm to solve it. Greedy methods
#are getting extremely slow, with the increase in the set of nodes.
#
#For this algorithm we consider a case when for given graph G, the triangle inequality is
#satisfied. So for example, for any three nodes A, B and C the distance between A and C must
#be at most the distance from A to B plus the distance from B to C. What's important
#most of the considered cases in TSP problem will satisfy this condition.
#
#Christofides is a 3/2 approximation algorithm. For a graph given at input, it returns
#found Hamilton cycle (list of nodes).
#
#Reference: http://en.wikipedia.org/wiki/Christofides_algorithm
#

proc ::struct::graph::op::Christofides { G } {

    #checking if graph is connected
    if { ![isConnected? $G] } {
	return -code error "Error. Given graph \"$G\" is not a connected graph."
    }
    #checking if all weights are set
    VerifyWeightsAreOk $G

    createCompleteGraph $G originalEdges

    #create minimum spanning tree for graph G
    set T [prim $G]

    #setting graph algorithm is working on - spanning tree of graph G
    set TGraph [createTGraph $G $T 1]

    set oddTGraph [struct::graph]

    foreach v [$TGraph nodes] {
	if { [$TGraph node degree $v] % 2 == 1 } {
	    $oddTGraph node insert $v
	}
    }

    #create complete graph
    foreach v [$oddTGraph nodes] {
	foreach u [$oddTGraph nodes] {
	    if { ($u ne $v) && ![$oddTGraph arc exists [list $u $v]] } {
		$oddTGraph arc insert $v $u [list $v $u]
		$oddTGraph arc setweight [list $v $u] [distance $G $v $u]
	    }

	}
    }

    ####
    #		MAX MATCHING HERE!!!
    ####
    set M [GreedyMaxMatching $oddTGraph]

    foreach e [$oddTGraph arcs] {
	if { ![struct::set contains $M $e] } {
	    $oddTGraph arc delete $e
	}
    }

    #operation: M + T
    foreach e [$oddTGraph arcs] {
	set u [$oddTGraph arc source $e]
	set v [$oddTGraph arc target $e]
	set uv [list $u $v]

	# Check if the arc in max-matching is parallel or not, to make
	# sure that we always insert an anti-parallel arc.

	if {[$TGraph arc exists $uv]} {
	    set vu [list $v $u]
	    $TGraph arc insert $v $u $vu
	    $TGraph arc setweight $vu [$oddTGraph arc getweight $e]
	} else {
	    $TGraph arc insert $u $v $uv
	    $TGraph arc setweight $uv [$oddTGraph arc getweight $e]
	}
    }

    #finding Hamilton Cycle
    set result [findHamiltonCycle $TGraph $originalEdges $G]
    $oddTGraph destroy
    $TGraph destroy
    return $result
}

#Greedy Max Matching procedure, which finds maximal ( not maximum ) matching
#for given graph G. It adds edges to solution, beginning from edges with the
#lowest cost.

proc ::struct::graph::op::GreedyMaxMatching {G} {

    set maxMatch {}

    foreach e [sortEdges $G] {
	set v [$G arc source $e]
	set u [$G arc target $e]
	set neighbours [$G arcs -adj $v $u]
	set noAdjacentArcs 1

	lremove neighbours $e

	foreach a $neighbours {
	    if { $a in $maxMatch } {
		set noAdjacentArcs 0
		break
	    }
	}
	if { $noAdjacentArcs } {
	    lappend maxMatch $e
	}
    }

    return $maxMatch
}

#Subprocedure which for given graph G, returns the set of edges
#sorted with their costs.
proc ::struct::graph::op::sortEdges {G} {
    set weights [$G arc weights]

    # NOTE: Look at possible rewrite, simplification.

    set sortedEdges {}

    foreach val [lsort [dict values $weights]] {
	foreach x [dict keys $weights] {
	    if { [dict get $weights $x] == $val } {
		set weights [dict remove $weights $x]
		lappend sortedEdges $x ;#[list $val $x]
	    }
	}
    }

    return $sortedEdges
}

#Subprocedure, which for given graph G, returns the dictionary
#containing edges sorted by weights (sortMode -> weights) or
#nodes sorted by degree (sortMode -> degrees).

proc ::struct::graph::op::sortGraph {G sortMode} {

    switch -exact -- $sortMode {
	weights {
	    set weights [$G arc weights]
	    foreach val [lsort [dict values $weights]] {
		foreach x [dict keys $weights] {
		    if { [dict get $weights $x] == $val } {
			set weights [dict remove $weights $x]
			dict set sortedVals $x $val
		    }
		}
	    }
	}
	degrees {
	    foreach v [$G nodes] {
		dict set degrees $v [$G node degree $v]
	    }
	    foreach x [lsort -integer -decreasing [dict values $degrees]] {
		foreach y [dict keys $degrees] {
		    if { [dict get $degrees $y] == $x } {
			set degrees [dict remove $degrees $y]
			dict set sortedVals $y $x
		    }
		}
	    }
	}
	default {
	    return -code error "Unknown sort mode \"$sortMode\", expected weights, or degrees"
	}
    }

    return $sortedVals
}

#Finds Hamilton cycle in given graph G
#Procedure used by Metric TSP Algorithms:
#Christofides and Metric TSP 2-approximation algorithm

proc ::struct::graph::op::findHamiltonCycle {G originalEdges originalGraph} {

    isEulerian? $G tourvar tourstart

    # Note: The start node is not necessarily the source node of the
    # first arc in the tour. The Fleury in isEulerian? may have walked
    # the arcs against! their direction. See also the note in our
    # caller (MetricTravellingSalesman).

    # Instead of reconstructing the start node by intersecting the
    # node-set for first and last arc, we are taking the easy and get
    # it directly from isEulerian?, as that command knows which node
    # it had chosen for this.

    lappend result $tourstart
    lappend tourvar [lindex $tourvar 0]

    set v $tourstart
    foreach i $tourvar {
	set u [$G node opposite $v $i]

	if { $u ni $result } {
	    set va [lindex $result end]
	    set vb $u

	    if { ([list $va $vb] in $originalEdges) || ([list $vb $va] in $originalEdges) } {
		lappend result $u
	    } else {

		set path [dict get [dijkstra $G $va] $vb]

		#reversing the path
		set path [lreverse $path]
		#cutting the start element
		set path [lrange $path 1 end]

		#adding the path and the target element
		lappend result {*}$path
		lappend result $vb
	    }
	}
	set v $u
    }

    set path [dict get [dijkstra $originalGraph [lindex $result 0]] [lindex $result end]]
    set path [lreverse $path]

    set path [lrange $path 1 end]

    if { [llength $path] } {
	lappend result {*}$path
    }

    lappend result $tourstart
    return $result
}

#Subprocedure for TSP problems.
#
#Creating graph from sets of given nodes and edges.
#In option doubledArcs we decide, if we want edges to be
#duplicated or not:
#0 - duplicated (Metric TSP 2-approximation algorithm)
#1 - single (Christofides Algorithm)
#
#Note that it assumes that graph's edges are properly weighted. That
#condition is checked before in procedures that use createTGraph, but for
#other uses it should be taken into consideration.
#

proc ::struct::graph::op::createTGraph {G Edges doubledArcs} {
    #checking if given set of edges is proper (all edges are in graph G)
    foreach e $Edges {
	if { ![$G arc exists $e] } {
	    return -code error "Edge \"$e\" doesn't exist in graph \"$G\". Set the proper set of edges."
	}
    }

    set TGraph [struct::graph]

    #fill TGraph with nodes
    foreach v [$G nodes] {
	$TGraph node insert
    }

    #fill TGraph with arcs
    foreach e $Edges {
	set v [$G arc source $e]
	set u [$G arc target $e]
	if { ![$TGraph arc exists [list $u $v]] } {
	    $TGraph arc insert $u $v [list $u $v]
	    $TGraph arc setweight [list $u $v] [$G arc getweight $e]
	}
	if { !$doubledArcs } {
	    if { ![$TGraph arc exists [list $v $u]] } {
		$TGraph arc insert $v $u [list $v $u]
		$TGraph arc setweight [list $v $u] [$G arc getweight $e]
	    }
	}
    }

    return $TGraph
}

#Subprocedure for some algorithms, e.g. TSP algorithms.
#
#It returns graph filled with arcs missing to say that graph is complete.
#Also it sets variable originalEdges with edges, which existed in given
#graph G at beginning, before extending the set of edges.
#

proc ::struct::graph::op::createCompleteGraph {G originalEdges} {

    upvar $originalEdges st
    set st {}
    foreach e [$G arcs] {
	set v [$G arc source $e]
	set u [$G arc target $e]

	lappend st [list $v $u]
    }

    foreach v [$G nodes] {
	foreach u [$G nodes] {
	    if { ($u != $v) && ([list $v $u] ni $st) && ([list $u $v] ni $st) && ![$G arc exists [list $u $v]] } {
		$G arc insert $v $u [list $v $u]
		$G arc setweight [list $v $u] Inf
	    }
	}
    }
    return $G
}


#Maximum Cut - 2 approximation algorithm
#-------------------------------------------------------------------------------------
#Maximum cut problem is a problem finding a cut not smaller than any other cut. In
#other words, we divide set of nodes for graph G into such 2 sets of nodes U and V,
#that the amount of edges connecting U and V is as high as possible.
#
#Algorithm is a 2-approximation, so for ALG ( solution returned by Algorithm) and
#OPT ( optimal solution), such inequality is true: OPT <= 2 * ALG.
#
#Input:
#Graph G
#U - variable storing first set of nodes (cut) given by solution
#V - variable storing second set of nodes (cut) given by solution
#
#Output:
#Algorithm returns number of edges between found two sets of nodes.
#
#Reference: http://en.wikipedia.org/wiki/Maxcut
#

proc ::struct::graph::op::MaxCut {G U V} {

    upvar $U _U
    upvar $V _V

    set _U {}
    set _V {}
    set counter 0

    foreach {u v} [lsort -dict [$G nodes]] {
	lappend _U $u
	if {$v eq ""} continue
	lappend _V $v
    }

    set val 1
    set ALG [countEdges $G $_U $_V]
    while {$val>0} {
	set val [cut $G _U _V $ALG]
	if { $val > $ALG } {
	    set ALG $val
	}
    }
    return $ALG
}

#procedure replaces nodes between sets and checks if that change is profitable
proc ::struct::graph::op::cut {G Uvar Vvar param} {

    upvar $Uvar U
    upvar $Vvar V
    set _V {}
    set _U {}
    set value 0

    set maxValue $param
    set _U $U
    set _V $V

    foreach v [$G nodes] {

	if { $v ni $_U } {
	    lappend _U $v
	    lremove _V $v
	    set value [countEdges $G $_U $_V]
	} else {
	    lappend _V $v
	    lremove _U $v
	    set value [countEdges $G $_U $_V]
	}

	if { $value > $maxValue } {
	    set U $_U
	    set V $_V
	    set maxValue $value
	} else {
	    set _V $V
	    set _U $U
	}
    }

    set value $maxValue

    if { $value > $param } {
	return $value
    } else {
	return 0
    }
}

#Removing element from the list - auxiliary procedure
proc ::struct::graph::op::lremove {listVariable value} {
    upvar 1 $listVariable var
    set idx [lsearch -exact $var $value]
    set var [lreplace $var $idx $idx]
}

#procedure counts edges that link two sets of nodes
proc ::struct::graph::op::countEdges {G U V} {

    set value 0

    foreach u $U {
        foreach e [$G arcs -out $u] {
            set v [$G arc target $e]
            if {$v ni $V} continue
            incr value
        }
    }
    foreach v $V {
        foreach e [$G arcs -out $v] {
            set u [$G arc target $e]
            if {$u ni $U} continue
            incr value
        }
    }

    return $value
}

#K-Center Problem - 2 approximation algorithm
#-------------------------------------------------------------------------------------
#Input:
#Undirected complete graph G, which satisfies triangle inequality.
#k - positive integer
#
#Definition:
#For any set S ( which is subset of V ) and node v, let the connect(v,S) be the
#cost of cheapest edge connecting v with any node in S. The goal is to find
#such S, that |S| = k and max_v{connect(v,S)} is possibly small.
#
#In other words, we can use it i.e. for finding best locations in the city ( nodes
#of input graph ) for placing k buildings, such that those buildings will be as close
#as possible to all other locations in town.
#
#Output:
#set of nodes - k center for graph G
#

proc ::struct::graph::op::UnweightedKCenter {G k} {

    #checking if all weights for edges in graph G are set well
    VerifyWeightsAreOk $G

    #checking if proper value of k is given at input
    if { $k <= 0 } {
	return -code error "The \"k\" value must be an positive integer."
    }

    set j [ expr {$k+1} ]

    #variable for holding the graph G(i) in each iteration
    set Gi [struct::graph]
    #two squared graph G
    set GiSQ [struct::graph]
    #sorted set of edges for graph G
    set arcs [sortEdges $G]

    #initializing both graph variables
    foreach v [$G nodes] {
	$Gi node insert $v
	$GiSQ node insert $v
    }

    #index i for each iteration

    #we seek for final solution, as long as the max independent
    #set Mi (found in particular iterations), such that |Mi| <= k, is found.
    for {set index 0} {$j > $k} {incr index} {
	#source node of an edge we add in current iteration
	set u [$G arc source [lindex $arcs $index]]
	#target node of an edge we add in current iteration
	set v [$G arc target [lindex $arcs $index]]

	#adding edge Ei to graph G(i)
	$Gi arc insert $u $v [list $u $v]
	#extending G(i-1)**2 to G(i)**2 using G(i)
	set GiSQ [extendTwoSquaredGraph $GiSQ $Gi $u $v]

	#finding maximal independent set for G(i)**2
	set Mi [GreedyMaxIndependentSet $GiSQ]

	#number of nodes in maximal independent set that was found
	set j [llength $Mi]
    }

    $Gi destroy
    $GiSQ destroy
    return $Mi
}

#Weighted K-Center - 3 approximation algorithm
#-------------------------------------------------------------------------------------
#
#The variation of unweighted k-center problem. Besides the fact graph is edge-weighted,
#there are also weights on vertices of input graph G. We've got also restriction
#W. The goal is to choose such set of nodes S ( which is a subset of V ), that it's
#total weight is not greater than W and also function: max_v { min_u { cost(u,v) }}
#has the smallest possible worth ( v is a node in V and u is a node in S ).
#
#Note:
#For more information about K-Center problem check Unweighted K-Center algorithm
#description.

proc ::struct::graph::op::WeightedKCenter {G nodeWeights W} {

    #checking if all weights for edges in graph G are set well
    VerifyWeightsAreOk $G

    #checking if proper value of k is given at input
    if { $W <= 0 } {
	return -code error "The \"W\" value must be an positive integer."
    }
    #initilization
    set j [ expr {$W+1} ]

    #graphs G(i) and G(i)**2
    set Gi   [struct::graph]
    set GiSQ [struct::graph]
    #the set of arcs for graph G sorted with their weights (increasing)
    set arcs [sortEdges $G]

    #initialization of graphs G(i) and G(i)**2
    foreach v [$G nodes] {
	$Gi   node insert $v
	$GiSQ node insert $v
    }

    #the main loop - iteration over all G(i)'s and G(i)**2's,
    #extended with each iteration till the solution is found

    foreach arc $arcs {
	#initilization of the set of nodes, which are cheapest neighbours
	#for particular nodes in maximal independent set
	set Si {}

	set u [$G arc source $arc]
	set v [$G arc target $arc]

	#extending graph G(i)
	$Gi arc insert $u $v [list $u $v]

	#extending graph G(i)**2 from G(i-1)**2 using G(i)
	set GiSQ [extendTwoSquaredGraph $GiSQ $Gi $u $v]

	#finding maximal independent set (Mi) for graph G(i)**2 found in the
	#previous step. Mi is found using greedy algorithm that also considers
	#weights on vertices.
	set Mi [GreedyWeightedMaxIndependentSet $GiSQ $nodeWeights]

	#for each node u in Maximal Independent set found in previous step,
	#we search for its cheapest ( considering costs at vertices ) neighbour.
	#Note that node u is considered as it is a neighbour for itself.
	foreach u $Mi {

	    set minWeightOfSi Inf

	    #the neighbours of u
	    set neighbours [$Gi nodes -adj $u]
	    set smallestNeighbour 0
	    #u is a neighbour for itself
	    lappend neighbours $u

	    #finding neighbour with minimal cost
	    foreach w [lsort -index 1 $nodeWeights] {
		lassign $w node weight
		if {[struct::set contains $neighbours $node]} {
                    set minWeightOfSi $weight
		    set smallestNeighbour $node
                    break
		}
	    }

	    lappend Si [list $smallestNeighbour $minWeightOfSi]
	}

	set totalSiWeight 0
	set possibleSolution {}

	foreach s $Si {
	    #counting the total weight of the set of nodes - Si
	    set totalSiWeight [ expr { $totalSiWeight + [lindex $s 1] } ]

	    #it's final solution, if weight found in previous step is
	    #not greater than W
	    lappend possibleSolution [lindex $s 0]
	}

	#checking if final solution is found
	if { $totalSiWeight <= $W } {
	    $Gi destroy
	    $GiSQ destroy
	    return $possibleSolution
	}
    }

    $Gi destroy
    $GiSQ destroy

    #no solution found - error returned
    return -code error "No k-center found for restriction W = $W"

}

#Maximal Independent Set - 2 approximation greedy algorithm
#-------------------------------------------------------------------------------------
#
#A maximal independent set is an independent set such that adding any other node
#to the set forces the set to contain an edge.
#
#Note:
#Don't confuse it with maximum independent set, which is a largest independent set
#for a given graph G.
#
#Reference: http://en.wikipedia.org/wiki/Maximal_independent_set

proc ::struct::graph::op::GreedyMaxIndependentSet {G} {

    set result {}
    set nodes [$G nodes]

    foreach v $nodes {
	if { [struct::set contains $nodes $v] } {
	    lappend result $v

	    foreach neighbour [$G nodes -adj $v] {
		struct::set exclude nodes $neighbour
	    }
	}
    }

    return $result
}

#Weighted Maximal Independent Set - 2 approximation greedy algorithm
#-------------------------------------------------------------------------------------
#
#Weighted variation of Maximal Independent Set. It takes as an input argument
#not only graph G but also set of weights for all vertices in graph G.
#
#Note:
#Read also Maximal Independent Set description for more info.
#
#Reference: http://en.wikipedia.org/wiki/Maximal_independent_set

proc ::struct::graph::op::GreedyWeightedMaxIndependentSet {G nodeWeights} {

    set result {}
    set nodes {}
    foreach v [lsort -index 1 $nodeWeights] {
	lappend nodes [lindex $v 0]
    }

    foreach v $nodes {
	if { [struct::set contains $nodes $v] } {
	    lappend result $v

	    set neighbours [$G nodes -adj $v]

	    foreach neighbour [$G nodes -adj $v] {
		struct::set exclude nodes $neighbour
	    }
	}
    }

    return $result
}

#subprocedure creating from graph G two squared graph
#G^2 - graph in which edge between nodes u and v exists,
#if and only if, when distance (in edges, not weights)
#between those nodes is not greater than 2 and u != v.

proc ::struct::graph::op::createSquaredGraph {G} {

    set H [struct::graph]
    foreach v [$G nodes] {
	$H node insert $v
    }

    foreach v [$G nodes] {
	foreach u [$G nodes -adj $v] {
	    if { ($v != $u) && ![$H arc exists [list $v $u]] && ![$H arc exists [list $u $v]] } {
		$H arc insert $u $v [list $u $v]
	    }
	    foreach z [$G nodes -adj $u] {
		if { ($v != $z) && ![$H arc exists [list $v $z]] && ![$H arc exists [list $z $v]] } {
		    $H arc insert $v $z [list $v $z]
		}
	    }
	}
    }

    return $H
}

#subprocedure for Metric K-Center problem
#
#Input:
#previousGsq - graph G(i-1)**2
#currentGi - graph G(i)
#u and v - source and target of an edge added in this iteration
#
#Output:
#Graph G(i)**2 used by next steps of K-Center algorithm

proc ::struct::graph::op::extendTwoSquaredGraph {previousGsq currentGi u v} {

    #adding new edge
    if { ![$previousGsq arc exists [list $v $u]] && ![$previousGsq arc exists [list $u $v]]} {
	$previousGsq arc insert $u $v [list $u $v]
    }

    #adding new edges to solution graph:
    #here edges, where source is a $u node and targets are neighbours of node $u except for $v
    foreach x [$currentGi nodes -adj $u] {
	if { ( $x != $v) && ![$previousGsq arc exists [list $v $x]] && ![$previousGsq arc exists [list $x $v]] } {
	    $previousGsq arc insert $v $x [list $v $x]
	}
    }
    #here edges, where source is a $v node and targets are neighbours of node $v except for $u
    foreach x [$currentGi nodes -adj $v] {
	if { ( $x != $u ) && ![$previousGsq arc exists [list $u $x]] && ![$previousGsq arc exists [list $x $u]] } {
	    $previousGsq arc insert $u $x [list $u $x]
	}
    }

    return $previousGsq
}

#Vertices Cover - 2 approximation algorithm
#-------------------------------------------------------------------------------------
#Vertices cover is a set o vertices such that each edge of the graph is incident to
#at least one vertex of the set. This 2-approximation algorithm searches for minimum
#vertices cover, which is a classical optimization problem in computer science and
#is a typical example of an NP-hard optimization problem that has an approximation
#algorithm.
#
#Reference: http://en.wikipedia.org/wiki/Vertex_cover_problem
#

proc ::struct::graph::op::VerticesCover {G} {
    #variable containing final solution
    set vc {}
    #variable containing sorted (with degree) set of arcs for graph G
    set arcs {}

    #setting the dictionary with degrees for each node
    foreach v [$G nodes] {
	dict set degrees $v [$G node degree $v]
    }

    #creating a list containing the sum of degrees for source and
    #target nodes for each edge in graph G
    foreach e [$G arcs] {
	set v [$G arc source $e]
	set u [$G arc target $e]

	lappend values [list [expr {[dict get $degrees $v]+[dict get $degrees $u]}] $e]
    }
    #sorting the list of source and target degrees
    set values [lsort -integer -decreasing -index 0 $values]

    #setting the set of edges in a right sequence
    foreach e $values {
	lappend arcs [lindex $e 1]
    }

    #for each node in graph G, we add it to the final solution and
    #erase all arcs adjacent to it, so they cannot be
    #added to solution in next iterations
    foreach e $arcs {

	if { [struct::set contains $arcs $e] } {
	    set v [$G arc source $e]
	    set u [$G arc target $e]
	    lappend vc $v $u

	    foreach n [$G arcs -adj $v $u] {
		struct::set exclude arcs $n
	    }
	}
    }

    return $vc
}


#Ford's Fulkerson algorithm - computing maximum flow in a flow network
#-------------------------------------------------------------------------------------
#
#The general idea of algorithm is finding augumenting paths in graph G, as long
#as they exist, and for each path updating the edge's weights along that path,
#with maximum possible throughput. The final (maximum) flow is found
#when there is no other augumenting path from source to sink.
#
#Input:
#graph G - weighted and directed graph. Weights at edges are considered as
#maximum throughputs that can be carried by that link (edge).
#s - the node that is a source for graph G
#t - the node that is a sink for graph G
#
#Output:
#Procedure returns the dictionary contaning throughputs for all edges. For
#each key ( the edge between nodes u and v in the for of list u v ) there is
#a value that is a throughput for that key. Edges where throughput values
#are equal to 0 are not returned ( it is like there was no link in the flow network
#between nodes connected by such edge).
#
#Reference: http://en.wikipedia.org/wiki/Ford-Fulkerson_algorithm

proc ::struct::graph::op::FordFulkerson {G s t} {

    #checking if nodes s and t are in graph G
    if { !([$G node exists $s] && [$G node exists $t]) } {
	return -code error "Nodes \"$s\" and \"$t\" should be contained in graph's G set of nodes"
    }

    #checking if all attributes for input network are set well ( costs and throughputs )
    foreach e [$G arcs] {
	if { ![$G arc keyexists $e throughput] } {
	    return -code error "The input network doesn't have all attributes set correctly... Please, check again attributes: \"throughput\" for input graph."
	}
    }

    #initilization
    foreach e [$G arcs] {
	set u [$G arc source $e]
	set v [$G arc target $e]
	dict set f [list $u $v] 0
	dict set f [list $v $u] 0
    }

    #setting the residual graph for the first iteration
    set residualG [createResidualGraph $G $f]

    #deleting the arcs that are 0-weighted
    foreach e [$residualG arcs] {
	if { [$residualG arc set $e throughput] == 0 } {
	    $residualG arc delete $e
	}
    }

    #the main loop - works till the path between source and the sink can be found
    while {1} {
	set paths [ShortestsPathsByBFS $residualG $s paths]

	if { ($paths == {}) || (![dict exists $paths $t]) } break

	set path [dict get $paths $t]
	#setting the path from source to sink

	#adding sink to path
	lappend path $t

	#finding the throughput of path p - the smallest value of c(f) among
	#edges that are contained in the path
	set maxThroughput Inf

	foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {
	    set pathEdgeFlow [$residualG arc set [list $u $v] throughput]
	    if { $maxThroughput > $pathEdgeFlow } {
		set maxThroughput $pathEdgeFlow
	    }
	}

	#increase of throughput using the path p, with value equal to maxThroughput
	foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {

	    #if maximum throughput that was found for the path p (maxThroughput) is bigger than current throughput
	    #at the edge not contained in the path p (for current pair of nodes u and v), then we add to the edge
	    #which is contained into path p the maxThroughput value decreased by the value of throughput at
	    #the second edge (not contained in path). That second edge's throughtput value is set to 0.

	    set f_uv [dict get $f [list $u $v]]
	    set f_vu [dict get $f [list $v $u]]
	    if { $maxThroughput >= $f_vu } {
		dict set f [list $u $v] [ expr { $f_uv + $maxThroughput - $f_vu } ]
		dict set f [list $v $u] 0
	    } else {

		#if maxThroughput is not greater than current throughput at the edge not contained in path p (here - v->u),
		#we add a difference between those values to edge contained in the path p (here u->v) and substract that
		#difference from edge not contained in the path p.
		set difference [ expr { $f_vu - $maxThroughput } ]
		dict set f [list $u $v] [ expr { $f_uv + $difference } ]
		dict set f [list $v $u] $maxThroughput
	    }
	}

	#when the current throughput for the graph is updated, we generate new residual graph
	#for new values of throughput
	$residualG destroy
	set residualG [createResidualGraph $G $f]

	foreach e [$residualG arcs] {
	    if { [$residualG arc set $e throughput] == 0 } {
		$residualG arc delete $e
	    }
	}
    }

    $residualG destroy

    #removing 0-weighted edges from solution
    foreach e [dict keys $f] {
	if { [dict get $f $e] == 0 } {
	    set f [dict remove $f $e]
	}
    }

    return $f
}

#subprocedure for FordFulkerson's algorithm, which creates
#for input graph G and given throughput f residual graph
#for further operations to find maximum flow in flow network

proc ::struct::graph::op::createResidualGraph {G f} {

    #initialization
    set residualG [struct::graph]

    foreach v [$G nodes] {
	$residualG node insert $v
    }

    foreach e [$G arcs] {
	set u [$G arc source $e]
	set v [$G arc target $e]
	dict set GF [list $u $v] [$G arc set $e throughput]
    }

    foreach e [dict keys $GF] {

	lassign $e u v

	set c_uv [dict get $GF $e]
	set flow_uv [dict get $f $e]
	set flow_vu [dict get $f [list $v $u]]

	if { ![$residualG arc exists $e] } {
	    $residualG arc insert $u $v $e
	}

	if { ![$residualG arc exists [list $v $u]] } {
	    $residualG arc insert $v $u [list $v $u]
	}

	#new value of c_f(u,v) for residual Graph is a max flow value for this edge
	#minus current flow on that edge
	if { ![$residualG arc keyexists $e throughput] } {
	    if { [dict exists $GF [list $v $u]] } {
		$residualG arc set [list $u $v] throughput [ expr { $c_uv - $flow_uv + $flow_vu } ]
	    } else {
		$residualG arc set $e throughput [ expr { $c_uv - $flow_uv } ]
	    }
	}

	if { [dict exists $GF [list $v $u]] } {
	    #when double arcs in graph G (u->v , v->u)
	    #so, x/y i w/z    y-x+w
	    set c_vu [dict get $GF [list $v $u]]
	    if { ![$residualG arc keyexists [list $v $u] throughput] } {
		$residualG arc set [list $v $u] throughput [ expr { $c_vu - $flow_vu + $flow_uv} ]
	    }
	} else {
	    $residualG arc set [list $v $u] throughput $flow_uv
	}
    }

    #setting all weights at edges to 1 for proper usage of shortest paths finding procedures
    $residualG arc setunweighted 1

    return $residualG
}

#Subprocedure for Busacker Gowen algorithm
#
#Input:
#graph G - flow network. Graph G has two attributes for each edge:
#cost and throughput. Each arc must have it's attribute value assigned.
#dictionary f - some flow for network G. Keys represent edges and values
#are flows at those edges
#path - set of nodes for which we transform the network
#
#Subprocedure checks 6 vital conditions and for them updates the network
#(let values with * be updates values for network). So, let edge (u,v) be
#the non-zero flow for network G, c(u,v) throughput of edge (u,v) and
#d(u,v) non-negative cost of edge (u,v):
#1. c*(v,u) = f(u,v)  --- adding apparent arc
#2. d*(v,u) = -d(u,v)
#3. c*(u,v) = c(u,v) - f(u,v)    --- if f(v,u) = 0 and c(u,v) > f(u,v)
#4. d*(u,v) = d(u,v)             --- if f(v,u) = 0 and c(u,v) > f(u,v)
#5. c*(u,v) = 0                  --- if f(v,u) = 0 and c(u,v) = f(u,v)
#6. d*(u,v) = Inf                --- if f(v,u) = 0 and c(u,v) = f(u,v)

proc ::struct::graph::op::createAugmentingNetwork {G f path} {

    set Gf [struct::graph]

    #setting the Gf graph
    foreach v [$G nodes] {
	$Gf node insert $v
    }

    foreach e [$G arcs] {
	set u [$G arc source $e]
	set v [$G arc target $e]

	$Gf arc insert $u $v [list $u $v]

	$Gf arc set [list $u $v] throughput [$G arc set $e throughput]
	$Gf arc set [list $u $v] cost [$G arc set $e cost]
    }

    #we set new values for each edge contained in the path from input
    foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {

	set f_uv [dict get $f [list $u $v]]
	set f_vu [dict get $f [list $v $u]]
	set c_uv [$G arc get [list $u $v] throughput]
	set d_uv [$G arc get [list $u $v] cost]

	#adding apparent arcs
	if { ![$Gf arc exists [list $v $u]] } {
	    $Gf arc insert $v $u [list $v $u]
	    #1.
	    $Gf arc set [list $v $u] throughput $f_uv
	    #2.
	    $Gf arc set [list $v $u] cost [ expr { -1 * $d_uv } ]
	} else {
	    #1.
	    $Gf arc set [list $v $u] throughput $f_uv
	    #2.
	    $Gf arc set [list $v $u] cost [ expr { -1 * $d_uv } ]
	    $Gf arc set [list $u $v] cost Inf
	    $Gf arc set [list $u $v] throughput 0
	}

	if { ($f_vu == 0 ) && ( $c_uv > $f_uv ) } {
	    #3.
	    $Gf arc set [list $u $v] throughput [ expr { $c_uv - $f_uv } ]
	    #4.
	    $Gf arc set [list $u $v] cost $d_uv
	}

	if { ($f_vu == 0 ) && ( $c_uv == $f_uv) } {
	    #5.
	    $Gf arc set [list $u $v] throughput 0
	    #6.
	    $Gf arc set [list $u $v] cost Inf
	}
    }

    return $Gf
}

#Busacker Gowen's algorithm - computing minimum cost maximum flow in a flow network
#-------------------------------------------------------------------------------------
#
#The goal is to find a flow, whose max value can be d, from source node to
#sink node in given flow network. That network except throughputs at edges has
#also defined a non-negative cost on each edge - cost of using that edge when
#directing flow with that edge ( it can illustrate e.g. fuel usage, time or
#any other measure dependent on usages ).
#
#Input:
#graph G - flow network, weights at edges are costs of using particular edge
#desiredFlow - max value of the flow for that network
#dictionary c - throughputs for all edges
#node s - the source node for graph G
#node t - the sink node for graph G
#
#Output:
#f - dictionary containing values of used throughputs for each edge ( key )
#found by algorithm.
#
#Reference: http://en.wikipedia.org/wiki/Minimum_cost_flow_problem
#

proc ::struct::graph::op::BusackerGowen {G desiredFlow s t} {

    #checking if nodes s and t are in graph G
    if { !([$G node exists $s] && [$G node exists $t]) } {
	return -code error "Nodes \"$s\" and \"$t\" should be contained in graph's G set of nodes"
    }

    if { $desiredFlow <= 0 } {
	return -code error "The \"desiredFlow\" value must be an positive integer."
    }

    #checking if all attributes for input network are set well ( costs and throughputs )
    foreach e [$G arcs] {
	if { !([$G arc keyexists $e throughput] && [$G arc keyexists $e cost]) } {
	    return -code error "The input network doesn't have all attributes set correctly... Please, check again attributes: \"throughput\" and \"cost\" for input graph."
	}
    }

    set Gf [struct::graph]

    #initialization of Augmenting Network
    foreach v [$G nodes] {
	$Gf node insert $v
    }

    foreach e [$G arcs] {
	set u [$G arc source $e]
	set v [$G arc target $e]
	$Gf arc insert $u $v [list $u $v]

	$Gf arc set [list $u $v] throughput [$G arc set $e throughput]
	$Gf arc set [list $u $v] cost [$G arc set $e cost]
    }

    #initialization of f
    foreach e [$G arcs] {
	set u [$G arc source $e]
	set v [$G arc target $e]
	dict set f [list $u $v] 0
	dict set f [list $v $u] 0
    }

    set currentFlow 0

    #main loop - it ends when we reach desired flow value or there is no path in Gf
    #leading from source node s to sink t

    while { $currentFlow < $desiredFlow } {

	#preparing correct values for pathfinding
	foreach edge [$Gf arcs] {
	    $Gf arc setweight $edge [$Gf arc get $edge cost]
	}

	#setting the path 'p' from 's' to 't'
	set paths [ShortestsPathsByBFS $Gf $s paths]

	#if there are no more paths, the search has ended
	if { ($paths == {}) || (![dict exists $paths $t]) } break

	set path [dict get $paths $t]
	lappend path $t

	#counting max throughput that is availiable to send
	#using path 'p'
	set maxThroughput Inf
	foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {
	    set uv_throughput [$Gf arc set [list $u $v] throughput]
	    if { $maxThroughput > $uv_throughput } {
		set maxThroughput $uv_throughput
	    }
	}

	#if max throughput that was found will cause exceeding the desired
	#flow, send as much as it's possible
	if { ( $currentFlow + $maxThroughput ) <= $desiredFlow } {
	    set fAdd $maxThroughput
	    set currentFlow [ expr { $currentFlow + $fAdd } ]
	} else {
	    set fAdd [ expr { $desiredFlow - $currentFlow } ]
	    set currentFlow $desiredFlow
	}

	#update the throuputs on edges
	foreach v [lrange $path 0 end-1] u [lrange $path 1 end] {
	    if { [dict get $f [list $u $v]] >= $fAdd } {
		dict set f [list $u $v] [ expr { [dict get $f [list $u $v]] - $fAdd } ]
	    }

	    if { ( [dict get $f [list $u $v]] < $fAdd ) && ( [dict get $f [list $u $v]] > 0 ) } {
		dict set f [list $v $u] [ expr { $fAdd - [dict get $f [list $u $v]] } ]
		dict set f [list $u $v] 0
	    }

	    if { [dict get $f [list $u $v]] == 0 } {
		dict set f [list $v $u] [ expr { [dict get $f [list $v $u]] + $fAdd } ]
	    }
	}

	#create new Augemnting Network

	set Gfnew [createAugmentingNetwork $Gf $f $path]
        $Gf destroy
        set Gf $Gfnew
    }

    set f [dict filter $f script {flow flowvalue} {expr {$flowvalue != 0}}]

    $Gf destroy
    return $f
}

#
proc ::struct::graph::op::ShortestsPathsByBFS {G s outputFormat} {

    switch -exact -- $outputFormat {
	distances {
	    set outputMode distances
	}
	paths {
	    set outputMode paths
	}
	default {
	    return -code error "Unknown output format \"$outputFormat\", expected distances, or paths."
	}
    }

    set queue [list $s]
    set result {}

    #initialization of marked nodes, distances and predecessors
    foreach v [$G nodes] {
	dict set marked $v 0
	dict set distances $v Inf
	dict set pred $v -1
    }

    #the s node is initially marked and has 0 distance to itself
    dict set marked $s 1
    dict set distances $s 0

    #the main loop
    while { [llength $queue] != 0 } {

	#removing top element from the queue
	set v [lindex $queue 0]
	lremove queue $v

	#for each arc that begins in v
	foreach arc [$G arcs -out $v] {

	    set u [$G arc target $arc]
	    set newlabel [ expr { [dict get $distances $v] + [$G arc getweight $arc] } ]

	    if { $newlabel < [dict get $distances $u] } {

		dict set distances $u $newlabel
		dict set pred $u $v

		#case when current node wasn't placed in a queue yet -
		#we set u at the end of the queue
		if { [dict get $marked $u] == 0 } {
		    lappend queue $u
		    dict set marked $u 1
		} else {

		    #case when current node u was in queue before but it is not in it now -
		    #we set u at the beginning of the queue
		    if { [lsearch $queue $u] < 0 } {
			set queue [linsert $queue 0 $u]
		    }
		}
	    }
	}
    }

    #if the outputformat is paths, we travel back to find shorests paths
    #to return sets of nodes for each node, which are their paths between
    #s and particular node
    dict set paths nopaths 1
    if { $outputMode eq "paths" } {
	foreach node [$G nodes] {

	    set path {}
	    set lastNode $node

	    while { $lastNode != -1 } {
		set currentNode [dict get $pred $lastNode]
		if { $currentNode != -1 } {
		    lappend path $currentNode
		}
		set lastNode $currentNode
	    }

	    set path [lreverse $path]

	    if { [llength $path] != 0 } {
		dict set paths $node $path
		dict unset paths nopaths
	    }
	}

	if { ![dict exists $paths nopaths] } {
	    return $paths
	} else {
	    return {}
	}

	#returning dictionary containing distance from start node to each other node (key)
    } else {
	return $distances
    }

}

#
proc ::struct::graph::op::BFS {G s outputFormat} {

    set queue [list $s]

    switch -exact -- $outputFormat {
	graph {
	    set outputMode graph
	}
	tree {
	    set outputMode tree
	}
	default {
	    return -code error "Unknown output format \"$outputFormat\", expected graph, or tree."
	}
    }

    if { $outputMode eq "graph" } {
	#graph initializing
	set BFSGraph [struct::graph]
	foreach v [$G nodes] {
	    $BFSGraph node insert $v
	}
    } else {
	#tree initializing
	set BFSTree [struct::tree]
	$BFSTree set root name $s
	$BFSTree rename root $s
    }

    #initilization of marked nodes
    foreach v [$G nodes] {
	dict set marked $v 0
    }

    #start node is marked from the beginning
    dict set marked $s 1

    #the main loop
    while { [llength $queue] != 0 } {
	#removing top element from the queue

	set v [lindex $queue 0]
	lremove queue $v

	foreach x [$G nodes -adj $v] {
	    if { ![dict get $marked $x] } {
		dict set marked $x 1
		lappend queue $x

		if { $outputMode eq "graph" } {
		    $BFSGraph arc insert $v $x [list $v $x]
		} else {
		    $BFSTree insert $v end $x
		}
	    }
	}
    }

    if { $outputMode eq "graph" } {
	return $BFSGraph
    } else {
	return $BFSTree
    }
}

#Minimum Diameter Spanning Tree - MDST
#-------------------------------------------------------------------------------------
#
#The goal is to find for input graph G, the spanning tree that
#has the minimum diameter worth.
#
#General idea of algorithm is to run BFS over all vertices in graph
#G. If the diameter "d" of the tree is odd, then we are sure that tree
#given by BFS is minimum (considering diameter value). When, diameter "d"
#is even, then optimal tree can have minimum diameter equal to "d" or
#"d-1".
#
#In that case, what algorithm does is rebuilding the tree given by BFS, by
#adding a vertice between root node and root's child node (nodes), such that
#subtree created with child node as root node is the greatest one (has the
#greatests height). In the next step for such rebuilded tree, we run again BFS
#with new node as root node. If the height of the tree didn't changed, we have found
#a better solution.

proc ::struct::graph::op::MinimumDiameterSpanningTree {G} {

    set min_diameter Inf
    set best_Tree [struct::graph]

    foreach v [$G nodes] {

	#BFS Tree
	set T [BFS $G $v tree]
	#BFS Graph
	set TGraph [BFS $G $v graph]

	#Setting all arcs to 1 for diameter procedure
	$TGraph arc setunweighted 1

	#setting values for current Tree
	set diam [diameter $TGraph]
	set subtreeHeight [ expr { $diam / 2 - 1} ]

	##############################################
	#case when diameter found for tree found by BFS is even:
	#it's possible to decrease the diameter by one.
	if { ( $diam % 2 ) == 0 } {

	    #for each child u that current root node v has, we search
	    #for the greatest subtree(subtrees) with the root in child u.
	    #
	    foreach u [$TGraph nodes -adj $v] {
		set u_depth 1 ;#[$T depth $u]
		set d_depth 0

		set descendants [$T descendants $u]

		foreach d $descendants {
		    if { $d_depth < [$T depth $d] } {
			set d_depth [$T depth $d]
		    }
		}

		#depth of the current subtree
		set depth [ expr { $d_depth - $u_depth } ]

		#proceed if found subtree is the greatest one
		if { $depth >= $subtreeHeight } {

		    #temporary Graph for holding potential better values
		    set tempGraph [struct::graph]

		    foreach node [$TGraph nodes] {
			$tempGraph node insert $node
		    }

		    #zmienic nazwy zmiennych zeby sie nie mylily
		    foreach arc [$TGraph arcs] {
			set _u [$TGraph arc source $arc]
			set _v [$TGraph arc target $arc]
			$tempGraph arc insert $_u $_v [list $_u $_v]
		    }

		    if { [$tempGraph arc exists [list $u $v]] } {
			$tempGraph arc delete [list $u $v]
		    } else {
			$tempGraph arc delete [list $v $u]
		    }

		    #for nodes u and v, we add a node between them
		    #to again start BFS with root in new node to check
		    #if it's possible to decrease the diameter in solution
		    set node [$tempGraph node insert]
		    $tempGraph arc insert $node $v [list $node $v]
		    $tempGraph arc insert $node $u [list $node $u]

		    set newtempGraph [BFS $tempGraph $node graph]
		    $tempGraph destroy
		    set tempGraph $newtempGraph

		    $tempGraph node delete $node
		    $tempGraph arc insert $u $v [list $u $v]
		    $tempGraph arc setunweighted 1

		    set tempDiam [diameter $tempGraph]

		    #if better tree is found (that any that were already found)
		    #replace it
		    if { $min_diameter > $tempDiam } {
			set $min_diameter [diameter $tempGraph ]
			$best_Tree destroy
			set best_Tree $tempGraph
		    } else {
			$tempGraph destroy
		    }
		}

	    }
	}
	################################################################

	set currentTreeDiameter $diam

	if { $min_diameter > $currentTreeDiameter } {
	    set min_diameter $currentTreeDiameter
	    $best_Tree destroy
	    set best_Tree $TGraph
	} else {
	    $TGraph destroy
	}

	$T destroy
    }

    return $best_Tree
}

#Minimum Degree Spanning Tree
#-------------------------------------------------------------------------------------
#
#In graph theory, minimum degree spanning tree (or degree-constrained spanning tree)
#is a spanning tree where the maximum vertex degree is as small as possible (or is
#limited to a certain constant k). The minimum degree spanning tree problem is to
#determine whether a particular graph has such a spanning tree for a particular k.
#
#Algorithm for input undirected graph G finds its spanning tree with the smallest
#possible degree. Algorithm is a 2-approximation, so it doesn't assure that optimal
#solution will be found.
#
#Reference: http://en.wikipedia.org/wiki/Degree-constrained_spanning_tree

proc ::struct::graph::op::MinimumDegreeSpanningTree {G} {

    #initialization of spanning tree for G
    set MST [struct::graph]

    foreach v [$G nodes] {
	$MST node insert $v
    }

    #forcing all arcs to be 1-weighted
    foreach e [$G arcs] {
	$G arc setweight $e 1
    }

    foreach e [kruskal $G] {
	set u [$G arc source $e]
	set v [$G arc target $e]

	$MST arc insert $u $v [list $u $v]
    }

    #main loop
    foreach e [$G arcs] {

	set u [$G arc source $e]
	set v [$G arc target $e]

	#if nodes u and v are neighbours, proceed to next iteration
	if { ![$MST arc exists [list $u $v]] && ![$MST arc exists [list $v $u]] } {

	    $MST arc setunweighted 1

	    #setting the path between nodes u and v in Spanning Tree MST
	    set path [dict get [dijkstra $MST $u] $v]
	    lappend path $v

	    #search for the node in the path, such that its degree is greater than degree of any of nodes
	    #u or v increased by one
	    foreach node $path {
		if { [$MST node degree $node] > ([Max [$MST node degree $u] [$MST node degree $v]] + 1) } {

		    #if such node is found add the arc between nodes u and v
                    $MST arc insert $u $v [list $u $v]

		    #then to hold MST being a spanning tree, delete any arc that is in the path
		    #that is adjacent to found node
		    foreach n [$MST nodes -adj $node] {
			if { $n in $path } {
			    if { [$MST arc exists [list $node $n]] } {
				$MST arc delete [list $node $n]
			    } else {
				$MST arc delete [list $n $node]
			    }
			    break
			}
		    }

		    # Node found, stop processing the path
		    break
		}
	    }
	}
    }

    return $MST
}

#Dinic algorithm for finding maximum flow in flow network
#-------------------------------------------------------------------------------------
#
#Reference: http://en.wikipedia.org/wiki/Dinic's_algorithm
#
proc ::struct::graph::op::MaximumFlowByDinic {G s t blockingFlowAlg} {

    if { !($blockingFlowAlg eq "dinic" || $blockingFlowAlg eq "mkm") } {
	return -code error "Uncorrect name of blocking flow algorithm. Choose \"mkm\" for Malhotra, Kumar and Maheshwari algorithm and \"dinic\" for Dinic algorithm."
    }

    foreach arc [$G arcs] {
	set u [$G arc source $arc]
	set v [$G arc target $arc]

	dict set f [list $u $v] 0
	dict set f [list $v $u] 0
    }

    while {1} {
	set residualG [createResidualGraph $G $f]
	if { $blockingFlowAlg == "mkm" } {
	    set blockingFlow [BlockingFlowByMKM $residualG $s $t]
	} else {
	    set blockingFlow [BlockingFlowByDinic $residualG $s $t]
	}
	$residualG destroy

	if { $blockingFlow == {} } break

	foreach key [dict keys $blockingFlow] {
	    dict set f $key [ expr { [dict get $f $key] + [dict get $blockingFlow $key] } ]
	}
    }

    set f [dict filter $f script {flow flowvalue} {expr {$flowvalue != 0}}]

    return $f
}

#Dinic algorithm for finding blocking flow
#-------------------------------------------------------------------------------------
#
#Algorithm for given network G with source s and sink t, finds a blocking
#flow, which can be used to obtain a maximum flow for that network G.
#
#Some steps that algorithm takes:
#1. constructing the level graph from network G
#2. until there are edges in level graph:
#	3. find the path between s and t nodes in level graph
#	4. for each edge in path update current throughputs at those edges and...
#	5. ...deleting nodes from which there are no residual edges
#6. return the dictionary containing the blocking flow

proc ::struct::graph::op::BlockingFlowByDinic {G s t} {

    #initializing blocking flow dictionary
    foreach edge [$G arcs] {
	set u [$G arc source $edge]
	set v [$G arc target $edge]

	dict set b [list $u $v] 0
    }

    #1.
    set LevelGraph [createLevelGraph $G $s]

    #2. the main loop
    while { [llength [$LevelGraph arcs]] > 0 } {

	if { ![$LevelGraph node exists $s] || ![$LevelGraph node exists $t] } break

	#3.
	set paths [ShortestsPathsByBFS $LevelGraph $s paths]

	if { $paths == {} } break
	if { ![dict exists $paths $t] } break

	set path [dict get $paths $t]
	lappend path $t

	#setting the max throughput to go with the path found one step before
	set maxThroughput Inf
	foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {

	    set uv_throughput [$LevelGraph arc get [list $u $v] throughput]

	    if { $maxThroughput > $uv_throughput } {
		set maxThroughput $uv_throughput
	    }
	}

	#4. updating throughputs and blocking flow
	foreach u [lrange $path 0 end-1] v [lrange $path 1 end] {

	    set uv_throughput [$LevelGraph arc get [list $u $v] throughput]
	    #decreasing the throughputs contained in the path by max flow value
	    $LevelGraph arc set [list $u $v] throughput [ expr { $uv_throughput - $maxThroughput } ]

	    #updating blocking flows
	    dict set b [list $u $v] [ expr { [dict get $b [list $u $v]] + $maxThroughput } ]
	    #dict set b [list $v $u] [ expr { -1 * [dict get $b [list $u $v]] } ]

	    #5. deleting the arcs, whose throughput is completely used
	    if { [$LevelGraph arc get [list $u $v] throughput] == 0 } {
		$LevelGraph arc delete [list $u $v]
	    }

	    #deleting the node, if it hasn't any outgoing arcs
	    if { ($u != $s) && ( ![llength [$LevelGraph nodes -out $u]] || ![llength [$LevelGraph nodes -in $u]] ) } {
		$LevelGraph node delete $u
	    }
	}

    }

    set b [dict filter $b script {flow flowvalue} {expr {$flowvalue != 0}}]

    $LevelGraph destroy

    #6.
    return $b
}

#Malhotra, Kumar and Maheshwari Algorithm for finding blocking flow
#-------------------------------------------------------------------------------------
#
#Algorithm for given network G with source s and sink t, finds a blocking
#flow, which can be used to obtain a maximum flow for that network G.
#
#For given node v, Let c(v) be the min{ a, b }, where a is the sum of all incoming
#throughputs and b is the sum of all outcoming throughputs from the node v.
#
#Some steps that algorithm takes:
#1. constructing the level graph from network G
#2. until there are edges in level graph:
#   3. finding the node with the minimum c(v)
#   4. sending c(v) units of throughput by incoming arcs of v
#	5. sending c(v) units of throughput by outcoming arcs of v
#	6. 4 and 5 steps can cause excess or deficiency of throughputs at nodes, so we
#	send exceeds forward choosing arcs greedily and...
#	7. ...the same with deficiencies but we send those backward.
#	8. delete the v node from level graph
#	9. upgrade the c values for all nodes
#
#10. if no other edges left in level graph, return b - found blocking flow
#

proc ::struct::graph::op::BlockingFlowByMKM {G s t} {

    #initializing blocking flow dictionary
    foreach edge [$G arcs] {
	set u [$G arc source $edge]
	set v [$G arc target $edge]

	dict set b [list $u $v] 0
    }

    #1. setting the level graph
    set LevelGraph [createLevelGraph $G $s]

    #setting the in/out throughputs for each node
    set c [countThroughputsAtNodes $LevelGraph $s $t]

    #2. the main loop
    while { [llength [$LevelGraph nodes]] > 2 } {

	#if there is no path between s and t nodes, end the procedure and
	#return current blocking flow
	set distances [ShortestsPathsByBFS $LevelGraph $s distances]
	if { [dict get $distances $t] == "Inf" } {
	    $LevelGraph destroy
	    set b [dict filter $b script {flow flowvalue} {expr {$flowvalue != 0}}]
	    return $b
	}

	#3. finding the node with minimum value of c(v)
	set min_cv Inf

	dict for {node cv} $c {
	    if { $min_cv > $cv } {
		set min_cv $cv
		set minCv_node $node
	    }
	}

	#4. sending c(v) by all incoming arcs of node with minimum c(v)
	set _min_cv $min_cv
	foreach arc [$LevelGraph arcs -in $minCv_node] {

	    set t_arc [$LevelGraph arc get $arc throughput]
	    set u [$LevelGraph arc source $arc]
	    set v [$LevelGraph arc target $arc]
	    set b_uv [dict get $b [list $u $v]]

	    if { $t_arc >= $min_cv } {
		$LevelGraph arc set $arc throughput [ expr { $t_arc - $min_cv } ]
		dict set b [list $u $v] [ expr { $b_uv + $min_cv } ]
		break
	    } else {
		set difference [ expr { $min_cv - $t_arc } ]
		set min_cv $difference
		dict set b [list $u $v] [ expr { $b_uv + $difference } ]
		$LevelGraph arc set $arc throughput 0
	    }
	}

	#5. sending c(v) by all outcoming arcs of node with minimum c(v)
	foreach arc [$LevelGraph arcs -out $minCv_node] {

	    set t_arc [$LevelGraph arc get $arc throughput]
	    set u [$LevelGraph arc source $arc]
	    set v [$LevelGraph arc target $arc]
	    set b_uv [dict get $b [list $u $v]]

	    if { $t_arc >= $min_cv } {
		$LevelGraph arc set $arc throughput [ expr { $t_arc - $_min_cv } ]
		dict set b [list $u $v] [ expr { $b_uv + $_min_cv } ]
		break
	    } else {
		set difference [ expr { $_min_cv - $t_arc } ]
		set _min_cv $difference
		dict set b [list $u $v] [ expr { $b_uv + $difference } ]
		$LevelGraph arc set $arc throughput 0
	    }
	}

	#find exceeds and if any, send them forward or backwards
	set distances [ShortestsPathsByBFS $LevelGraph $s distances]

	#6.
	for {set i [ expr {[dict get $distances $minCv_node] + 1}] } { $i < [llength [$G nodes]] } { incr i } {
	    foreach w [$LevelGraph nodes] {
		if { [dict get $distances $w] == $i } {
		    set excess [findExcess $LevelGraph $w $b]
		    if { $excess > 0 } {
			set b [sendForward $LevelGraph $w $b $excess]
		    }
		}
	    }
	}

	#7.
	for { set i [ expr { [dict get $distances $minCv_node] - 1} ] } { $i > 0 } { incr i -1 } {
	    foreach w [$LevelGraph nodes] {
		if { [dict get $distances $w] == $i } {
		    set excess [findExcess $LevelGraph $w $b]
		    if { $excess < 0 } {
			set b [sendBack $LevelGraph $w $b [ expr { (-1) * $excess } ]]
		    }
		}
	    }
	}

	#8. delete current node from the network
	$LevelGraph node delete $minCv_node

	#9. correctingg the in/out throughputs for each node after
	#deleting one of the nodes in network
	set c [countThroughputsAtNodes $LevelGraph $s $t]

	#if node has no availiable outcoming or incoming throughput
	#delete that node from the graph
	dict for {key val} $c {
	    if { $val == 0 } {
		$LevelGraph node delete $key
		dict unset c $key
	    }
	}
    }

    set b [dict filter $b script {flow flowvalue} {expr {$flowvalue != 0}}]

    $LevelGraph destroy
    #10.
    return $b
}

#Subprocedure for algorithms that find blocking-flows.
#It's creating a level graph from the residual network.
proc ::struct::graph::op::createLevelGraph {Gf s} {

    set LevelGraph [struct::graph]

    $Gf arc setunweighted 1

    #deleting arcs with 0 throughputs for proper pathfinding
    foreach arc [$Gf arcs] {
	if { [$Gf arc get $arc throughput] == 0 } {
	    $Gf arc delete $arc
	}
    }

    set distances [ShortestsPathsByBFS $Gf $s distances]

    foreach v [$Gf nodes] {
	$LevelGraph node insert $v
	$LevelGraph node set $v distance [dict get $distances $v]
    }

    foreach e [$Gf arcs] {
	set u [$Gf arc source $e]
	set v [$Gf arc target $e]

	if { ([$LevelGraph node get $u distance] + 1) == [$LevelGraph node get $v distance]} {
	    $LevelGraph arc insert $u $v [list $u $v]
	    $LevelGraph arc set [list $u $v] throughput [$Gf arc get $e throughput]
	}
    }

    $LevelGraph arc setunweighted 1
    return $LevelGraph
}

#Subprocedure for blocking flow finding by MKM algorithm
#
#It computes for graph G and each of his nodes the throughput value -
#for node v: from the sum of availiable throughputs from incoming arcs and
#the sum of availiable throughputs from outcoming arcs chooses lesser and sets
#as the throughput of the node.
#
#Throughputs of nodes are returned in the dictionary.
#
proc ::struct::graph::op::countThroughputsAtNodes {G s t} {

    set c {}
    foreach v [$G nodes] {

	if { ($v eq $t) || ($v eq $s) } continue

	set outcoming [$G arcs -out $v]
	set incoming [$G arcs -in $v]

	set outsum 0
	set insum 0

	foreach o $outcoming i $incoming {

	    if { [llength $o] > 0 } {
		set outsum [ expr { $outsum + [$G arc get $o throughput] } ]
	    }

	    if { [llength $i] > 0 } {
		set insum [ expr { $insum + [$G arc get $i throughput] } ]
	    }

	    set value [Min $outsum $insum]
	}

	dict set c $v $value
    }

    return $c
}

#Subprocedure for blocking-flow finding algorithm by MKM
#
#If for a given input node, outcoming flow is bigger than incoming, then that deficiency
#has to be send back by that subprocedure.
proc ::struct::graph::op::sendBack {G node b value} {

    foreach arc [$G arcs -in $node] {
	set u [$G arc source $arc]
	set v [$G arc target $arc]

	if { $value > [$G arc get $arc throughput] } {
	    set value [ expr { $value - [$G arc get $arc throughput] } ]
	    dict set b [list $u $v] [ expr { [dict get $b [list $u $v]] + [$G arc get $arc throughput] } ]
	    $G arc set $arc throughput 0
	} else {
	    $G arc set $arc throughput [ expr { [$G arc get $arc throughput] - $value } ]
	    dict set b [list $u $v] [ expr { [dict get $b [list $u $v]] + $value } ]
	    set value 0
	    break
	}
    }

    return $b
}

#Subprocedure for blocking-flow finding algorithm by MKM
#
#If for a given input node, incoming flow is bigger than outcoming, then that exceed
#has to be send forward by that sub procedure.
proc ::struct::graph::op::sendForward {G node b value} {

    foreach arc [$G arcs -out $node] {

	set u [$G arc source $arc]
	set v [$G arc target $arc]

	if { $value > [$G arc get $arc throughput] } {
	    set value [ expr { $value - [$G arc get $arc throughput] } ]
	    dict set b [list $u $v] [ expr { [dict get $b [list $u $v]] + [$G arc get $arc throughput] } ]
	    $G arc set $arc throughput 0
	} else {
	    $G arc set $arc throughput [ expr { [$G arc get $arc throughput] - $value } ]
	    dict set b [list $u $v] [ expr { [dict get $b [list $u $v]] + $value } ]

	    set value 0
	    break
	}
    }

    return $b
}

#Subprocedure for blocking-flow finding algorithm by MKM
#
#It checks for graph G if node given at input has a exceed
#or deficiency of throughput.
#
#For exceed the positive value of exceed is returned, for deficiency
#procedure returns negative value. If the incoming throughput
#is the same as outcoming, procedure returns 0.
#
proc ::struct::graph::op::findExcess {G node b} {

    set incoming 0
    set outcoming 0

    foreach key [dict keys $b] {

	lassign $key u v
	if { $u eq $node } {
	    set outcoming [ expr { $outcoming + [dict get $b $key] } ]
	}
	if { $v eq $node } {
	    set incoming [ expr { $incoming + [dict get $b $key] } ]
	}
    }

    return [ expr { $incoming - $outcoming } ]
}

#Travelling Salesman Problem - Heuristic of local searching
#2 - approximation Algorithm
#-------------------------------------------------------------------------------------
#

proc ::struct::graph::op::TSPLocalSearching {G C} {

    foreach arc $C {
	if { ![$G arc exists $arc] } {
	    return -code error "Given cycle has arcs not included in graph G."
	}
    }

    #initialization
    set CGraph [struct::graph]
    set GCopy [struct::graph]
    set w 0

    foreach node [$G nodes] {
	$CGraph node insert $node
	$GCopy node insert $node
    }

    foreach arc [$G arcs] {
	set u [$G arc source $arc]
	set v [$G arc target $arc]
	$GCopy arc insert $u $v [list $u $v]
	$GCopy arc set [list $u $v] weight [$G arc get $arc weight]
    }

    foreach arc $C {

	set u [$G arc source $arc]
	set v [$G arc target $arc]
	set arcWeight [$G arc get $arc weight]

	$CGraph arc insert $u $v [list $u $v]
	$CGraph arc set [list $u $v] weight $arcWeight

	set w [ expr { $w + $arcWeight } ]
    }

    set reductionDone 1

    while { $reductionDone } {

	set queue {}
	set reductionDone 0

	#double foreach loop goes through all pairs of arcs
	foreach i [$CGraph arcs] {

	    #source and target nodes of first arc
	    set iu [$CGraph arc source $i]
	    set iv [$CGraph arc target $i]

	    #second arc
	    foreach j [$CGraph arcs] {

		#if pair of arcs already was considered, continue with next pair of arcs
		if { [list $j $i] ni $queue } {

		    #add current arc to queue to mark that it was used
		    lappend queue [list $i $j]

		    set ju [$CGraph arc source $j]
		    set jv [$CGraph arc target $j]

		    #we consider only arcs that are not adjacent
		    if { !($iu eq $ju) && !($iu eq $jv) && !($iv eq $ju) && !($iv eq $jv) } {

			#set the current cycle
			set CPrim [copyGraph $CGraph]

			#transform the current cycle:
			#1.
			$CPrim arc delete $i
			$CPrim arc delete $j


			set param 0

			#adding new edges instead of erased ones
			if { !([$CPrim arc exists [list $iu $ju]] || [$CPrim arc exists [list $iv $jv]] || [$CPrim arc exists [list $ju $iu]] || [$CPrim arc exists [list $jv $iv]] ) } {

			    $CPrim arc insert $iu $ju [list $iu $ju]
			    $CPrim arc insert $iv $jv [list $iv $jv]

			    if { [$GCopy arc exists [list $iu $ju]] } {
				$CPrim arc set [list $iu $ju] weight [$GCopy arc get [list $iu $ju] weight]
			    } else {
				$CPrim arc set [list $iu $ju] weight [$GCopy arc get [list $ju $iu] weight]
			    }

			    if { [$GCopy arc exists [list $iv $jv]] } {
				$CPrim arc set [list $iv $jv] weight [$GCopy arc get [list $iv $jv] weight]
			    } else {
				$CPrim arc set [list $iv $jv] weight [$GCopy arc get [list $jv $iv] weight]
			    }
			} else {
			    set param 1
			}

			$CPrim arc setunweighted 1

			#check if it's still a cycle or if any arcs were added instead those erased
			if { !([struct::graph::op::distance $CPrim $iu $ju] > 0 ) || $param } {

			    #deleting new edges if they were added before in current iteration
			    if { !$param } {
				$CPrim arc delete [list $iu $ju]
			    }

			    if { !$param } {
				$CPrim arc delete [list $iv $jv]
			    }

			    #adding new ones that will assure the graph is still a cycle
			    $CPrim arc insert $iu $jv [list $iu $jv]
			    $CPrim arc insert $iv $ju [list $iv $ju]

			    if { [$GCopy arc exists [list $iu $jv]] } {
				$CPrim arc set [list $iu $jv] weight [$GCopy arc get [list $iu $jv] weight]
			    } else {
				$CPrim arc set [list $iu $jv] weight [$GCopy arc get [list $jv $iu] weight]
			    }

			    if { [$GCopy arc exists [list $iv $ju]] } {
				$CPrim arc set [list $iv $ju] weight [$GCopy arc get [list $iv $ju] weight]
			    } else {
				$CPrim arc set [list $iv $ju] weight [$GCopy arc get [list $ju $iv] weight]
			    }
			}

			#count current value of cycle
			set cycleWeight [countCycleWeight $CPrim]

			#if we found cycle with lesser sum of weights, we set is as a result and
			#marked that reduction was successful
			if { $w > $cycleWeight } {
			    set w $cycleWeight
			    set reductionDone 1
			    set C [$CPrim arcs]
			}

			$CPrim destroy
		    }
		}
	    }
	}

	#setting the new current cycle if the reduction was successful
	if { $reductionDone } {
	    foreach arc [$CGraph arcs] {
		$CGraph arc delete $arc
	    }
	    for {set i 0} { $i < [llength $C] } { incr i } {
		lset C $i [lsort [lindex $C $i]]
	    }

	    foreach arc [$GCopy arcs] {
		if { [lsort $arc] in $C } {
		    set u [$GCopy arc source $arc]
		    set v [$GCopy arc target $arc]
		    $CGraph arc insert $u $v [list $u $v]
		    $CGraph arc set $arc weight [$GCopy arc get $arc weight]
		}
	    }
	}
    }

    $GCopy destroy
    $CGraph destroy

    return $C
}

proc ::struct::graph::op::copyGraph {G} {

    set newGraph [struct::graph]

    foreach node [$G nodes] {
	$newGraph node insert $node
    }
    foreach arc [$G arcs] {
	set u [$G arc source $arc]
	set v [$G arc target $arc]
	$newGraph arc insert $u $v $arc
	$newGraph arc set $arc weight [$G arc get $arc weight]
    }

    return $newGraph
}

proc ::struct::graph::op::countCycleWeight {G} {

    set result 0

    foreach arc [$G arcs] {
	set result [ expr { $result + [$G arc get $arc weight] } ]
    }

    return $result
}

# ### ### ### ######### ######### #########
##

# This command finds a minimum spanning tree/forest (MST) of the graph
# argument, using the algorithm developed by Joseph Kruskal. The
# result is a set (as list) containing the names of the arcs in the
# MST. The set of nodes of the MST is implied by set of arcs, and thus
# not given explicitly. The algorithm does not consider arc
# directions. Note that unconnected nodes are left out of the result.

# Reference: http://en.wikipedia.org/wiki/Kruskal%27s_algorithm

proc ::struct::graph::op::kruskal {g} {
    # Check graph argument for proper configuration.

    VerifyWeightsAreOk $g

    # Transient helper data structures. A priority queue for the arcs
    # under consideration, using their weights as priority, and a
    # disjoint-set to keep track of the forest of partial minimum
    # spanning trees we are working with.

    set consider [::struct::prioqueue -dictionary consider]
    set forest   [::struct::disjointset forest]

    # Start with all nodes in the graph each in their partition.

    foreach n [$g nodes] {
	$forest add-partition $n
    }

    # Then fill the queue with all arcs, using their weight to
    # prioritize. The weight is the cost of the arc. The lesser the
    # better.

    foreach {arc weight} [$g arc weights] {
	$consider put $arc $weight
    }

    # And now we can construct the tree. This is done greedily. In
    # each round we add the arc with the smallest weight to the
    # minimum spanning tree, except if doing so would violate the tree
    # condition.

    set result {}

    while {[$consider size]} {
	set minarc [$consider get]
	set origin [$g arc source $minarc]
	set destin [$g arc target $minarc]

	# Ignore the arc if both ends are in the same partition. Using
	# it would add a cycle to the result, i.e. it would not be a
	# tree anymore.

	if {[$forest equal $origin $destin]} continue

	# Take the arc for the result, and merge the trees both ends
	# are in into a single tree.

	lappend result $minarc
	$forest merge $origin $destin
    }

    # We are done. Get rid of the transient helper structures and
    # return our result.

    $forest   destroy
    $consider destroy

    return $result
}

# ### ### ### ######### ######### #########
##

# This command finds a minimum spanning tree/forest (MST) of the graph
# argument, using the algorithm developed by Prim. The result is a
# set (as list) containing the names of the arcs in the MST. The set
# of nodes of the MST is implied by set of arcs, and thus not given
# explicitly. The algorithm does not consider arc directions.

# Reference: http://en.wikipedia.org/wiki/Prim%27s_algorithm

proc ::struct::graph::op::prim {g} {
    VerifyWeightsAreOk $g

    # Fill an array with all nodes, to track which nodes have been
    # visited at least once. When the inner loop runs out of nodes and
    # we still have some left over we restart using one of the
    # leftover as new starting point. In this manner we get the MST of
    # the whole graph minus unconnected nodes, instead of only the MST
    # for the component the initial starting node is in.

    array set unvisited {}
    foreach n [$g nodes] { set unvisited($n) . }

    # Transient helper data structure. A priority queue for the nodes
    # and arcs under consideration for inclusion into the MST. Each
    # element of the queue is a list containing node name, a flag bit,
    # and arc name, in this order. The associated priority is the
    # weight of the arc. The flag bit is set for the initial queue
    # entry only, containing a fake (empty) arc, to trigger special
    # handling.

    set consider [::struct::prioqueue -dictionary consider]

    # More data structures, the result arrays.
    array set weightmap {} ; # maps nodes to min arc weight seen so
    # far. This is the threshold other arcs
    # on this node will have to beat to be
    # added to the MST.
    array set arcmap    {} ; # maps arcs to nothing, these are the
    # arcs in the MST.

    while {[array size unvisited]} {
	# Choose a 'random' node as the starting point for the inner
	# loop, prim's algorithm, and put it on the queue for
	# consideration. Then we iterate until we have considered all
	# nodes in the its component.

	set startnode [lindex [array names unvisited] 0]
	$consider put [list $startnode 1 {}] 0

	while {[$consider size] > 0} {
	    # Pull the next minimum weight to look for. This is the
	    # priority of the next item we can get from the queue. And the
	    # associated node/decision/arc data.

	    set arcweight [$consider peekpriority 1]

	    foreach {v arcundefined arc} [$consider get] break
	    #8.5: lassign [$consider get] v arcundefined arc

	    # Two cases to consider: The node v is already part of the
	    # MST, or not. If yes we check if the new arcweight is better
	    # than what we have stored already, and update accordingly.

	    if {[info exists weightmap($v)]} {
		set currentweight $weightmap($v)
		if {$arcweight < $currentweight} {
		    # The new weight is better, update to use it as
		    # the new threshold. Note that this fill not touch
		    # any other arcs found for this node, as these are
		    # still minimal.

		    set weightmap($v) $arcweight
		    set arcmap($arc)  .
		}
	    } else {
		# Node not yet present. Save weight and arc. The
		# latter if and only the arc is actually defined. For
		# the first, initial queue entry, it is not.  Then we
		# add all the arcs adjacent to the current node to the
		# queue to consider them in the next rounds.

		set weightmap($v) $arcweight
		if {!$arcundefined} {
		    set arcmap($arc) .
		}
		foreach adjacentarc [$g arcs -adj $v] {
		    set weight    [$g arc  getweight   $adjacentarc]
		    set neighbour [$g node opposite $v $adjacentarc]
		    $consider put [list $neighbour 0 $adjacentarc] $weight
		}
	    }

	    # Mark the node as visited, belonging to the current
	    # component. Future iterations will ignore it.
	    unset -nocomplain unvisited($v)
	}
    }

    # We are done. Get rid of the transient helper structure and
    # return our result.

    $consider destroy

    return [array names arcmap]
}

# ### ### ### ######### ######### #########
##

# This command checks whether the graph argument is bi-partite or not,
# and returns the result as a boolean value, true for a bi-partite
# graph, and false otherwise. A variable can be provided to store the
# bi-partition into.
#
# Reference: http://en.wikipedia.org/wiki/Bipartite_graph

proc ::struct::graph::op::isBipartite? {g {bipartitionvar {}}} {

    # Handle the special cases of empty graphs, or one without arcs
    # quickly. Both are bi-partite.

    if {$bipartitionvar ne ""} {
	upvar 1 $bipartitionvar bipartitions
    }
    if {![llength [$g nodes]]} {
	set  bipartitions {{} {}}
	return 1
    } elseif {![llength [$g arcs]]} {
	if {$bipartitionvar ne ""} {
	    set  bipartitions [list [$g nodes] {}]
	}
	return 1
    }

    # Transient helper data structure, a queue of the nodes waiting
    # for processing.

    set pending [struct::queue pending]
    set nodes   [$g nodes]

    # Another structure, a map from node names to their 'color',
    # indicating which of the two partitions a node belngs to. All
    # nodes start out as undefined (0). Traversing the arcs we
    # set and flip them as needed (1,2).

    array set color {}
    foreach node $nodes {
	set color($node) 0
    }

    # Iterating over all nodes we use their connections to traverse
    # the components and assign colors. We abort when encountering
    # paradox, as that means that the graph is not bi-partite.

    foreach node $nodes {
	# Ignore nodes already in the second partition.
	if {$color($node)} continue

	# Flip the color, then travel the component and check for
	# conflicts with the neighbours.

	set color($node) 1

	$pending put $node
	while {[$pending size]} {
	    set current [$pending get]
	    foreach neighbour [$g nodes -adj $current] {
		if {!$color($neighbour)} {
		    # Exchange the color between current and previous
		    # nodes, and remember the neighbour for further
		    # processing.
		    set color($neighbour) [expr {3 - $color($current)}]
		    $pending put $neighbour
		} elseif {$color($neighbour) == $color($current)} {
		    # Color conflict between adjacent nodes, should be
		    # different.  This graph is not bi-partite. Kill
		    # the data structure and abort.

		    $pending destroy
		    return 0
		}
	    }
	}
    }

    # The graph is bi-partite. Kill the transient data structure, and
    # move the partitions into the provided variable, if there is any.

    $pending destroy

    if {$bipartitionvar ne ""} {
	# Build bipartition, then set the data into the variable
	# passed as argument to this command.

	set X {}
	set Y {}

	foreach {node partition} [array get color] {
	    if {$partition == 1} {
		lappend X $node
	    } else {
		lappend Y $node
	    }
	}
	set bipartitions [list $X $Y]
    }

    return 1
}

# ### ### ### ######### ######### #########
##

# This command computes a maximal matching, if it exists, for the
# graph argument G and its bi-partition as specified through the node
# sets X and Y. As is implied, this method requires that the graph is
# bi-partite. Use the command 'isBipartite?' to check for this
# property, and to obtain the bi-partition.
if 0 {
    proc ::struct::graph::op::maxMatching {g X Y} {
	return -code error "not implemented yet"
    }}

# ### ### ### ######### ######### #########
##

# This command computes the strongly connected components (SCCs) of
# the graph argument G. The result is a list of node-sets, each set
# containing the nodes of one SCC of G. In any SCC there is a directed
# path between any two nodes U, V from U to V. If all SCCs contain
# only a single node the graph is acyclic.

proc ::struct::graph::op::tarjan {g} {
    set all [$g nodes]

    # Quick bailout for simple special cases, i.e. graphs without
    # nodes or arcs.
    if {![llength $all]} {
	# No nodes => no SCCs
	return {}
    } elseif {![llength [$g arcs]]} {
	# Have nodes, but no arcs => each node is its own SCC.
	set r {} ; foreach a $all { lappend r [list $a] }
	return $r
    }

    # Transient data structures. Stack of nodes to consider, the
    # result, and various state arrays. TarjanSub upvar's all them
    # into its scope.

    set pending [::struct::stack pending]
    set result  {}

    array set index   {}
    array set lowlink {}
    array set instack {}

    # Invoke the main search system while we have unvisited
    # nodes. TarjanSub will remove all visited nodes from 'all',
    # ensuring termination.

    while {[llength $all]} {
	TarjanSub [lindex $all 0] 0
    }

    # Release the transient structures and return result.
    $pending destroy
    return $result
}

proc ::struct::graph::op::TarjanSub {start counter} {
    # Import the tracer state from our caller.
    upvar 1 g g index index lowlink lowlink instack instack result result pending pending all all

    struct::set subtract all $start

    set component {}
    set   index($start) $counter
    set lowlink($start) $counter
    incr counter

    $pending push $start
    set instack($start) 1

    foreach outarc [$g arcs -out $start] {
	set neighbour [$g arc target $outarc]

	if {![info exists index($neighbour)]} {
	    # depth-first-search of reachable nodes from the neighbour
	    # node. Original from the chosen startnode.
	    TarjanSub $neighbour $counter
	    set lowlink($start) [Min $lowlink($start) $lowlink($neighbour)]

	} elseif {[info exists instack($neighbour)]} {
	    set lowlink($start) [Min $lowlink($start) $lowlink($neighbour)]
	}
    }

    # Check if the 'start' node on this recursion level is the root
    # node of a SCC, and collect the component if yes.

    if {$lowlink($start) == $index($start)} {
	while {1} {
	    set v [$pending pop]
	    unset instack($v)
	    lappend component $v
	    if {$v eq $start} break
	}
	lappend result $component
    }

    return
}

# ### ### ### ######### ######### #########
##

# This command computes the connected components (CCs) of the graph
# argument G. The result is a list of node-sets, each set containing
# the nodes of one CC of G. In any CC there is UN-directed path
# between any two nodes U, V.

proc ::struct::graph::op::connectedComponents {g} {
    set all [$g nodes]

    # Quick bailout for simple special cases, i.e. graphs without
    # nodes or arcs.
    if {![llength $all]} {
	# No nodes => no CCs
	return {}
    } elseif {![llength [$g arcs]]} {
	# Have nodes, but no arcs => each node is its own CC.
	set r {} ; foreach a $all { lappend r [list $a] }
	return $r
    }

    # Invoke the main search system while we have unvisited
    # nodes.

    set result  {}
    while {[llength $all]} {
	set component [ComponentOf $g [lindex $all 0]]
	lappend result $component
	# all = all - component
	struct::set subtract all $component
    }
    return $result
}

# A derivative command which computes the connected component (CC) of
# the graph argument G containing the node N. The result is a node-set
# containing the nodes of the CC of N in G.

proc ::struct::graph::op::connectedComponentOf {g n} {
    # Quick bailout for simple special cases
    if {![$g node exists $n]} {
	return -code error "node \"$n\" does not exist in graph \"$g\""
    } elseif {![llength [$g arcs -adj $n]]} {
	# The chosen node has no neighbours, so is its own CC.
	return [list $n]
    }

    # Invoke the main search system for the chosen node.

    return [ComponentOf $g $n]
}

# Internal helper for finding connected components.

proc ::struct::graph::op::ComponentOf {g start} {
    set pending [::struct::queue pending]
    $pending put $start

    array set visited {}
    set visited($start) .

    while {[$pending size]} {
	set current [$pending get 1]
	foreach neighbour [$g nodes -adj $current] {
	    if {[info exists visited($neighbour)]} continue
	    $pending put $neighbour
	    set visited($neighbour) 1
	}
    }
    $pending destroy
    return [array names visited]
}

# ### ### ### ######### ######### #########
##

# This command determines if the specified arc A in the graph G is a
# bridge, i.e. if its removal will split the connected component its
# end nodes belong to, into two. The result is a boolean value. Uses
# the 'ComponentOf' helper command.

proc ::struct::graph::op::isBridge? {g arc} {
    if {![$g arc exists $arc]} {
	return -code error "arc \"$arc\" does not exist in graph \"$g\""
    }

    # Note: We could avoid the need for a copy of the graph if we were
    # willing to modify G (*). As we are not willing using a copy is
    # the easiest way to allow us a trivial modification. For the
    # future consider the creation of a graph class which represents
    # virtual graphs over a source, generated by deleting nodes and/or
    # arcs. without actually modifying the source.
    #
    # (Ad *): Create a new unnamed helper node X. Move the arc
    #         destination to X. Recompute the component and ignore
    #         X. Then move the arc target back to its original node
    #         and remove X again.

    set src        [$g arc source $arc]
    set compBefore [ComponentOf $g $src]
    if {[llength $compBefore] == 1} {
	# Special case, the arc is a loop on an otherwise unconnected
	# node. The component will not split, this is not a bridge.
	return 0
    }

    set copy       [struct::graph BridgeCopy = $g]
    $copy arc delete $arc
    set compAfter  [ComponentOf $copy $src]
    $copy destroy

    return [expr {[llength $compBefore] != [llength $compAfter]}]
}

# This command determines if the specified node N in the graph G is a
# cut vertex, i.e. if its removal will split the connected component
# it belongs to into two. The result is a boolean value. Uses the
# 'ComponentOf' helper command.

proc ::struct::graph::op::isCutVertex? {g n} {
    if {![$g node exists $n]} {
	return -code error "node \"$n\" does not exist in graph \"$g\""
    }

    # Note: We could avoid the need for a copy of the graph if we were
    # willing to modify G (*). As we are not willing using a copy is
    # the easiest way to allow us a trivial modification. For the
    # future consider the creation of a graph class which represents
    # virtual graphs over a source, generated by deleting nodes and/or
    # arcs. without actually modifying the source.
    #
    # (Ad *): Create two new unnamed helper nodes X and Y. Move the
    #         icoming and outgoing arcs to these helpers. Recompute
    #         the component and ignore the helpers. Then move the arcs
    #         back to their original nodes and remove the helpers
    #         again.

    set compBefore [ComponentOf $g $n]

    if {[llength $compBefore] == 1} {
	# Special case. The node is unconnected. Its removal will
	# cause no changes. Therefore not a cutvertex.
	return 0
    }

    # We remove the node from the original component, so that we can
    # select a new start node without fear of hitting on the
    # cut-vertex candidate. Also makes the comparison later easier
    # (straight ==).
    struct::set subtract compBefore $n

    set copy       [struct::graph CutVertexCopy = $g]
    $copy node delete $n
    set compAfter  [ComponentOf $copy [lindex $compBefore 0]]
    $copy destroy

    return [expr {[llength $compBefore] != [llength $compAfter]}]
}

# This command determines if the graph G is connected.

proc ::struct::graph::op::isConnected? {g} {
    return [expr { [llength [connectedComponents $g]] == 1 }]
}

# ### ### ### ######### ######### #########
##

# This command determines if the specified graph G has an eulerian
# cycle (aka euler tour, <=> g is eulerian) or not. If yes, it can
# return the cycle through the named variable, as a list of arcs
# traversed.
#
# Note that for a graph to be eulerian all nodes have to have an even
# degree, and the graph has to be connected. And if more than two
# nodes have an odd degree the graph is not even semi-eulerian (cannot
# even have an euler path).

proc ::struct::graph::op::isEulerian? {g {eulervar {}} {tourstart {}}} {
    set nodes [$g nodes]
    if {![llength $nodes] || ![llength [$g arcs]]} {
	# Quick bailout for special cases. No nodes, or no arcs imply
	# that no euler cycle is present.
	return 0
    }

    # Check the condition regarding even degree nodes, then
    # connected-ness.

    foreach n $nodes {
	if {([$g node degree $n] % 2) == 0} continue
	# Odd degree node found, not eulerian.
	return 0
    }

    if {![isConnected? $g]} {
	return 0
    }

    # At this point the graph is connected, with all nodes of even
    # degree. As per Carl Hierholzer the graph has to have an euler
    # tour. If the user doesn't request it we do not waste the time to
    # actually compute one.

    if {$tourstart ne ""} {
	upvar 1 $tourstart start
    }

    # We start the tour at an arbitrary node.
    set start [lindex $nodes 0]

    if {$eulervar eq ""} {
	return 1
    }

    upvar 1 $eulervar tour
    Fleury $g $start tour
    return 1
}

# This command determines if the specified graph G has an eulerian
# path (<=> g is semi-eulerian) or not. If yes, it can return the
# path through the named variable, as a list of arcs traversed.
#
# (*) Aka euler tour.
#
# Note that for a graph to be semi-eulerian at most two nodes are
# allowed to have an odd degree, all others have to be of even degree,
# and the graph has to be connected.

proc ::struct::graph::op::isSemiEulerian? {g {eulervar {}}} {
    set nodes [$g nodes]
    if {![llength $nodes] || ![llength [$g arcs]]} {
	# Quick bailout for special cases. No nodes, or no arcs imply
	# that no euler path is present.
	return 0
    }

    # Check the condition regarding oddd/even degree nodes, then
    # connected-ness.

    set odd 0
    foreach n $nodes {
	if {([$g node degree $n] % 2) == 0} continue
	incr odd
	set lastodd $n
    }
    if {($odd > 2) || ![isConnected? $g]} {
	return 0
    }

    # At this point the graph is connected, with the node degrees
    # supporting existence of an euler path. If the user doesn't
    # request it we do not waste the time to actually compute one.

    if {$eulervar eq ""} {
	return 1
    }

    upvar 1 $eulervar path

    # We start at either an odd-degree node, or any node, if there are
    # no odd-degree ones. In the last case we are actually
    # constructing an euler tour, i.e. a closed path.

    if {$odd} {
	set start $lastodd
    } else {
	set start [lindex $nodes 0]
    }

    Fleury $g $start path
    return 1
}

proc ::struct::graph::op::Fleury {g start eulervar} {
    upvar 1 $eulervar path

    # We start at the chosen node.

    set copy  [struct::graph FleuryCopy = $g]
    set path  {}

    # Edges are chosen per Fleury's algorithm. That is easy,
    # especially as we already have a command to determine whether an
    # arc is a bridge or not.

    set arcs [$copy arcs]
    while {![struct::set empty $arcs]} {
	set adjacent [$copy arcs -adj $start]

	if {[llength $adjacent] == 1} {
	    # No choice in what arc to traverse.
	    set arc [lindex $adjacent 0]
	} else {
	    # Choose first non-bridge arcs. The euler conditions force
	    # that at least two such are present.

	    set has 0
	    foreach arc $adjacent {
		if {[isBridge? $copy $arc]} {
		    continue
		}
		set has 1
		break
	    }
	    if {!$has} {
		$copy destroy
		return -code error {Internal error}
	    }
	}

	set start [$copy node opposite $start $arc]
	$copy arc delete $arc
	struct::set exclude arcs $arc
	lappend path $arc
    }

    $copy destroy
    return
}

# ### ### ### ######### ######### #########
##

# This command uses dijkstra's algorithm to find all shortest paths in
# the graph G starting at node N. The operation can be configured to
# traverse arcs directed and undirected, and the format of the result.

proc ::struct::graph::op::dijkstra {g node args} {
    # Default traversal is undirected.
    # Default output format is tree.

    set arcTraversal undirected
    set resultFormat tree

    # Process options to override the defaults, if any.
    foreach {option param} $args {
	switch -exact -- $option {
	    -arcmode {
		switch -exact -- $param {
		    directed -
		    undirected {
			set arcTraversal $param
		    }
		    default {
			return -code error "Bad value for -arcmode, expected one of \"directed\" or \"undirected\""
		    }
		}
	    }
	    -outputformat {
		switch -exact -- $param {
		    tree -
		    distances {
			set resultFormat $param
		    }
		    default {
			return -code error "Bad value for -outputformat, expected one of \"distances\" or \"tree\""
		    }
		}
	    }
	    default {
		return -code error "Bad option \"$option\", expected one of \"-arcmode\" or \"-outputformat\""
	    }
	}
    }

    # We expect that all arcs of g are given a weight.
    VerifyWeightsAreOk $g

    # And the start node has to belong to the graph too, of course.
    if {![$g node exists $node]} {
	return -code error "node \"$node\" does not exist in graph \"$g\""
    }

    # TODO: Quick bailout for special cases (no arcs).

    # Transient and other data structures for the core algorithm.
    set pending [::struct::prioqueue -dictionary DijkstraQueue]
    array set distance {} ; # array: node -> distance to 'n'
    array set previous {} ; # array: node -> parent in shortest path to 'n'.
    array set visited  {} ; # array: node -> bool, true when node processed

    # Initialize the data structures.
    foreach n [$g nodes] {
	set distance($n) Inf
	set previous($n) undefined
	set  visited($n) 0
    }

    # Compute the distances ...
    $pending put $node 0
    set distance($node) 0
    set previous($node) none

    while {[$pending size]} {
	set current [$pending get]
	set visited($current) 1

	# Traversal to neighbours according to the chosen mode.
	if {$arcTraversal eq "undirected"} {
	    set arcNeighbours [$g arcs -adj $current]
	} else {
	    set arcNeighbours [$g arcs -out $current]
	}

	# Compute distances, record newly discovered nodes, minimize
	# distances for nodes reachable through multiple paths.
	foreach arcNeighbour $arcNeighbours {
	    set cost      [$g arc getweight $arcNeighbour]
	    set neighbour [$g node opposite $current $arcNeighbour]
	    set delta     [expr {$distance($current) + $cost}]

	    if {
		($distance($neighbour) eq "Inf") ||
		($delta < $distance($neighbour))
	    } {
		# First path, or better path to the node folund,
		# update our records.

		set distance($neighbour) $delta
		set previous($neighbour) $current
		if {!$visited($neighbour)} {
		    $pending put $neighbour $delta
		}
	    }
	}
    }

    $pending destroy

    # Now generate the result based on the chosen format.
    if {$resultFormat eq "distances"} {
	return [array get distance]
    } else {
	array set listofprevious {}
	foreach n [$g nodes] {
	    set current $n
	    while {1} {
		if {$current eq "undefined"} break
		if {$current eq $node} {
		    lappend listofprevious($n) $current
		    break
		}
		if {$current ne $n} {
		    lappend listofprevious($n) $current
		}
		set current $previous($current)
	    }
	}
	return [array get listofprevious]
    }
}

# This convenience command is a wrapper around dijkstra's algorithm to
# find the (un)directed distance between two nodes in the graph G.

proc ::struct::graph::op::distance {g origin destination args} {
    if {![$g node exists $origin]} {
	return -code error "node \"$origin\" does not exist in graph \"$g\""
    }
    if {![$g node exists $destination]} {
	return -code error "node \"$destination\" does not exist in graph \"$g\""
    }

    set arcTraversal undirected

    # Process options to override the defaults, if any.
    foreach {option param} $args {
	switch -exact -- $option {
	    -arcmode {
		switch -exact -- $param {
		    directed -
		    undirected {
			set arcTraversal $param
		    }
		    default {
			return -code error "Bad value for -arcmode, expected one of \"directed\" or \"undirected\""
		    }
		}
	    }
	    default {
		return -code error "Bad option \"$option\", expected \"-arcmode\""
	    }
	}
    }

    # Quick bailout for special case: the distance from a node to
    # itself is zero

    if {$origin eq $destination} {
	return 0
    }

    # Compute all distances, then pick and return the one we are
    # interested in.
    array set distance [dijkstra $g $origin -outputformat distances -arcmode $arcTraversal]
    return $distance($destination)
}

# This convenience command is a wrapper around dijkstra's algorithm to
# find the (un)directed eccentricity of the node N in the graph G. The
# eccentricity is the maximal distance to any other node in the graph.

proc ::struct::graph::op::eccentricity {g node args} {
    if {![$g node exists $node]} {
	return -code error "node \"$node\" does not exist in graph \"$g\""
    }

    set arcTraversal undirected

    # Process options to override the defaults, if any.
    foreach {option param} $args {
	switch -exact -- $option {
	    -arcmode {
		switch -exact -- $param {
		    directed -
		    undirected {
			set arcTraversal $param
		    }
		    default {
			return -code error "Bad value for -arcmode, expected one of \"directed\" or \"undirected\""
		    }
		}
	    }
	    default {
		return -code error "Bad option \"$option\", expected \"-arcmode\""
	    }
	}
    }

    # Compute all distances, then pick out the max

    set ecc 0
    foreach {n distance} [dijkstra $g $node -outputformat distances -arcmode $arcTraversal] {
	if {$distance eq "Inf"} { return Inf }
	if {$distance > $ecc} { set ecc $distance }
    }

    return $ecc
}

# This convenience command is a wrapper around eccentricity to find
# the (un)directed radius of the graph G. The radius is the minimal
# eccentricity over all nodes in the graph.

proc ::struct::graph::op::radius {g args} {
    return [lindex [RD $g $args] 0]
}

# This convenience command is a wrapper around eccentricity to find
# the (un)directed diameter of the graph G. The diameter is the
# maximal eccentricity over all nodes in the graph.

proc ::struct::graph::op::diameter {g args} {
    return [lindex [RD $g $args] 1]
}

proc ::struct::graph::op::RD {g options} {
    set arcTraversal undirected

    # Process options to override the defaults, if any.
    foreach {option param} $options {
	switch -exact -- $option {
	    -arcmode {
		switch -exact -- $param {
		    directed -
		    undirected {
			set arcTraversal $param
		    }
		    default {
			return -code error "Bad value for -arcmode, expected one of \"directed\" or \"undirected\""
		    }
		}
	    }
	    default {
		return -code error "Bad option \"$option\", expected \"-arcmode\""
	    }
	}
    }

    set radius   Inf
    set diameter 0
    foreach n [$g nodes] {
	set e [eccentricity $g $n -arcmode $arcTraversal]
	#puts "$n ==> ($e)"
	if {($e eq "Inf") || ($e > $diameter)} {
	    set diameter $e
	}
	if {($radius eq "Inf") || ($e < $radius)} {
	    set radius $e
	}
    }

    return [list $radius $diameter]
}

#
## place holder for operations to come
#

# ### ### ### ######### ######### #########
## Internal helpers

proc ::struct::graph::op::Min {first second} {
    if {$first > $second} {
	return $second
    } else {
	return $first
    }
}

proc ::struct::graph::op::Max {first second} {
    if {$first < $second} {
	return $second
    } else {
	return $first
    }
}

# This method verifies that every arc on the graph has a weight
# assigned to it. This is required for some algorithms.
proc ::struct::graph::op::VerifyWeightsAreOk {g} {
    if {![llength [$g arc getunweighted]]} return
    return -code error "Operation invalid for graph with unweighted arcs."
}

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct::graph::op {
    #namespace export ...
}

package provide struct::graph::op 0.11.3
