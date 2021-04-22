
[//000000001]: # (struct::graph::op \- Tcl Data Structures)
[//000000002]: # (Generated from file 'graphops\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Alejandro Paz <vidriloco@gmail\.com>)
[//000000004]: # (Copyright &copy; 2008 \(docs\) Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (Copyright &copy; 2009 Michal Antoniewski <antoniewski\.m@gmail\.com>)
[//000000006]: # (struct::graph::op\(n\) 0\.11\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::graph::op \- Operation for \(un\)directed graph objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Operations](#section2)

  - [Background theory and terms](#section3)

      - [Shortest Path Problem](#subsection1)

      - [Travelling Salesman Problem](#subsection2)

      - [Matching Problem](#subsection3)

      - [Cut Problems](#subsection4)

      - [K\-Center Problem](#subsection5)

      - [Flow Problems](#subsection6)

      - [Approximation algorithm](#subsection7)

  - [References](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require struct::graph::op ?0\.11\.3?  

[__struct::graph::op::toAdjacencyMatrix__ *g*](#1)  
[__struct::graph::op::toAdjacencyList__ *G* ?*options*\.\.\.?](#2)  
[__struct::graph::op::kruskal__ *g*](#3)  
[__struct::graph::op::prim__ *g*](#4)  
[__struct::graph::op::isBipartite?__ *g* ?*bipartvar*?](#5)  
[__struct::graph::op::tarjan__ *g*](#6)  
[__struct::graph::op::connectedComponents__ *g*](#7)  
[__struct::graph::op::connectedComponentOf__ *g* *n*](#8)  
[__struct::graph::op::isConnected?__ *g*](#9)  
[__struct::graph::op::isCutVertex?__ *g* *n*](#10)  
[__struct::graph::op::isBridge?__ *g* *a*](#11)  
[__struct::graph::op::isEulerian?__ *g* ?*tourvar*?](#12)  
[__struct::graph::op::isSemiEulerian?__ *g* ?*pathvar*?](#13)  
[__struct::graph::op::dijkstra__ *g* *start* ?*options*\.\.\.?](#14)  
[__struct::graph::op::distance__ *g* *origin* *destination* ?*options*\.\.\.?](#15)  
[__struct::graph::op::eccentricity__ *g* *n* ?*options*\.\.\.?](#16)  
[__struct::graph::op::radius__ *g* ?*options*\.\.\.?](#17)  
[__struct::graph::op::diameter__ *g* ?*options*\.\.\.?](#18)  
[__struct::graph::op::BellmanFord__ *G* *startnode*](#19)  
[__struct::graph::op::Johnsons__ *G* ?*options*\.\.\.?](#20)  
[__struct::graph::op::FloydWarshall__ *G*](#21)  
[__struct::graph::op::MetricTravellingSalesman__ *G*](#22)  
[__struct::graph::op::Christofides__ *G*](#23)  
[__struct::graph::op::GreedyMaxMatching__ *G*](#24)  
[__struct::graph::op::MaxCut__ *G* *U* *V*](#25)  
[__struct::graph::op::UnweightedKCenter__ *G* *k*](#26)  
[__struct::graph::op::WeightedKCenter__ *G* *nodeWeights* *W*](#27)  
[__struct::graph::op::GreedyMaxIndependentSet__ *G*](#28)  
[__struct::graph::op::GreedyWeightedMaxIndependentSet__ *G* *nodeWeights*](#29)  
[__struct::graph::op::VerticesCover__ *G*](#30)  
[__struct::graph::op::EdmondsKarp__ *G* *s* *t*](#31)  
[__struct::graph::op::BusackerGowen__ *G* *desiredFlow* *s* *t*](#32)  
[__struct::graph::op::ShortestsPathsByBFS__ *G* *s* *outputFormat*](#33)  
[__struct::graph::op::BFS__ *G* *s* ?*outputFormat*\.\.\.?](#34)  
[__struct::graph::op::MinimumDiameterSpanningTree__ *G*](#35)  
[__struct::graph::op::MinimumDegreeSpanningTree__ *G*](#36)  
[__struct::graph::op::MaximumFlowByDinic__ *G* *s* *t* *blockingFlowAlg*](#37)  
[__struct::graph::op::BlockingFlowByDinic__ *G* *s* *t*](#38)  
[__struct::graph::op::BlockingFlowByMKM__ *G* *s* *t*](#39)  
[__struct::graph::op::createResidualGraph__ *G* *f*](#40)  
[__struct::graph::op::createAugmentingNetwork__ *G* *f* *path*](#41)  
[__struct::graph::op::createLevelGraph__ *Gf* *s*](#42)  
[__struct::graph::op::TSPLocalSearching__ *G* *C*](#43)  
[__struct::graph::op::TSPLocalSearching3Approx__ *G* *C*](#44)  
[__struct::graph::op::createSquaredGraph__ *G*](#45)  
[__struct::graph::op::createCompleteGraph__ *G* *originalEdges*](#46)  

# <a name='description'></a>DESCRIPTION

The package described by this document, __struct::graph::op__, is a
companion to the package __[struct::graph](graph\.md)__\. It provides a
series of common operations and algorithms applicable to \(un\)directed graphs\.

Despite being a companion the package is not directly dependent on
__[struct::graph](graph\.md)__, only on the API defined by that package\.
I\.e\. the operations of this package can be applied to any and all graph objects
which provide the same API as the objects created through
__[struct::graph](graph\.md)__\.

# <a name='section2'></a>Operations

  - <a name='1'></a>__struct::graph::op::toAdjacencyMatrix__ *g*

    This command takes the graph *g* and returns a nested list containing the
    adjacency matrix of *g*\.

    The elements of the outer list are the rows of the matrix, the inner
    elements are the column values in each row\. The matrix has "__n__\+1"
    rows and columns, with the first row and column \(index 0\) containing the
    name of the node the row/column is for\. All other elements are boolean
    values, __True__ if there is an arc between the 2 nodes of the
    respective row and column, and __False__ otherwise\.

    Note that the matrix is symmetric\. It does not represent the directionality
    of arcs, only their presence between nodes\. It is also unable to represent
    parallel arcs in *g*\.

  - <a name='2'></a>__struct::graph::op::toAdjacencyList__ *G* ?*options*\.\.\.?

    Procedure creates for input graph *G*, it's representation as
    *[Adjacency List](\.\./\.\./\.\./\.\./index\.md\#adjacency\_list)*\. It handles
    both directed and undirected graphs \(default is undirected\)\. It returns
    dictionary that for each node \(key\) returns list of nodes adjacent to it\.
    When considering weighted version, for each adjacent node there is also
    weight of the edge included\.

      * Arguments:

          + Graph object *G* \(input\)

            A graph to convert into an *[Adjacency
            List](\.\./\.\./\.\./\.\./index\.md\#adjacency\_list)*\.

      * Options:

          + __\-directed__

            By default *G* is operated as if it were an *Undirected graph*\.
            Using this option tells the command to handle *G* as the directed
            graph it is\.

          + __\-weights__

            By default any weight information the graph *G* may have is
            ignored\. Using this option tells the command to put weight
            information into the result\. In that case it is expected that all
            arcs have a proper weight, and an error is thrown if that is not the
            case\.

  - <a name='3'></a>__struct::graph::op::kruskal__ *g*

    This command takes the graph *g* and returns a list containing the names
    of the arcs in *g* which span up a minimum weight spanning tree \(MST\), or,
    in the case of an un\-connected graph, a minimum weight spanning forest
    \(except for the 1\-vertex components\)\. Kruskal's algorithm is used to compute
    the tree or forest\. This algorithm has a time complexity of *O\(E\*log E\)*
    or *O\(E\* log V\)*, where *V* is the number of vertices and
    *[E](\.\./\.\./\.\./\.\./index\.md\#e)* is the number of edges in graph *g*\.

    The command will throw an error if one or more arcs in *g* have no weight
    associated with them\.

    A note regarding the result, the command refrains from explicitly listing
    the nodes of the MST as this information is implicitly provided in the arcs
    already\.

  - <a name='4'></a>__struct::graph::op::prim__ *g*

    This command takes the graph *g* and returns a list containing the names
    of the arcs in *g* which span up a minimum weight spanning tree \(MST\), or,
    in the case of an un\-connected graph, a minimum weight spanning forest
    \(except for the 1\-vertex components\)\. Prim's algorithm is used to compute
    the tree or forest\. This algorithm has a time complexity between *O\(E\+V\*log
    V\)* and *O\(V\*V\)*, depending on the implementation \(Fibonacci heap \+
    Adjacency list versus Adjacency Matrix\)\. As usual *V* is the number of
    vertices and *[E](\.\./\.\./\.\./\.\./index\.md\#e)* the number of edges in
    graph *g*\.

    The command will throw an error if one or more arcs in *g* have no weight
    associated with them\.

    A note regarding the result, the command refrains from explicitly listing
    the nodes of the MST as this information is implicitly provided in the arcs
    already\.

  - <a name='5'></a>__struct::graph::op::isBipartite?__ *g* ?*bipartvar*?

    This command takes the graph *g* and returns a boolean value indicating
    whether it is bipartite \(__true__\) or not \(__false__\)\. If the
    variable *bipartvar* is specified the two partitions of the graph are
    there as a list, if, and only if the graph is bipartit\. If it is not the
    variable, if specified, is not touched\.

  - <a name='6'></a>__struct::graph::op::tarjan__ *g*

    This command computes the set of *strongly connected* components \(SCCs\) of
    the graph *g*\. The result of the command is a list of sets, each of which
    contains the nodes for one of the SCCs of *g*\. The union of all SCCs
    covers the whole graph, and no two SCCs intersect with each other\.

    The graph *g* is *acyclic* if all SCCs in the result contain only a
    single node\. The graph *g* is *strongly connected* if the result
    contains only a single SCC containing all nodes of *g*\.

  - <a name='7'></a>__struct::graph::op::connectedComponents__ *g*

    This command computes the set of *connected* components \(CCs\) of the graph
    *g*\. The result of the command is a list of sets, each of which contains
    the nodes for one of the CCs of *g*\. The union of all CCs covers the whole
    graph, and no two CCs intersect with each other\.

    The graph *g* is *connected* if the result contains only a single SCC
    containing all nodes of *g*\.

  - <a name='8'></a>__struct::graph::op::connectedComponentOf__ *g* *n*

    This command computes the *connected* component \(CC\) of the graph *g*
    containing the node *n*\. The result of the command is a sets which
    contains the nodes for the CC of *n* in *g*\.

    The command will throw an error if *n* is not a node of the graph *g*\.

  - <a name='9'></a>__struct::graph::op::isConnected?__ *g*

    This is a convenience command determining whether the graph *g* is
    *connected* or not\. The result is a boolean value, __true__ if the
    graph is connected, and __false__ otherwise\.

  - <a name='10'></a>__struct::graph::op::isCutVertex?__ *g* *n*

    This command determines whether the node *n* in the graph *g* is a
    *[cut vertex](\.\./\.\./\.\./\.\./index\.md\#cut\_vertex)* \(aka *[articulation
    point](\.\./\.\./\.\./\.\./index\.md\#articulation\_point)*\)\. The result is a
    boolean value, __true__ if the node is a cut vertex, and __false__
    otherwise\.

    The command will throw an error if *n* is not a node of the graph *g*\.

  - <a name='11'></a>__struct::graph::op::isBridge?__ *g* *a*

    This command determines whether the arc *a* in the graph *g* is a
    *[bridge](\.\./\.\./\.\./\.\./index\.md\#bridge)* \(aka *[cut
    edge](\.\./\.\./\.\./\.\./index\.md\#cut\_edge)*, or
    *[isthmus](\.\./\.\./\.\./\.\./index\.md\#isthmus)*\)\. The result is a boolean
    value, __true__ if the arc is a bridge, and __false__ otherwise\.

    The command will throw an error if *a* is not an arc of the graph *g*\.

  - <a name='12'></a>__struct::graph::op::isEulerian?__ *g* ?*tourvar*?

    This command determines whether the graph *g* is *eulerian* or not\. The
    result is a boolean value, __true__ if the graph is eulerian, and
    __false__ otherwise\.

    If the graph is eulerian and *tourvar* is specified then an euler tour is
    computed as well and stored in the named variable\. The tour is represented
    by the list of arcs traversed, in the order of traversal\.

  - <a name='13'></a>__struct::graph::op::isSemiEulerian?__ *g* ?*pathvar*?

    This command determines whether the graph *g* is *semi\-eulerian* or not\.
    The result is a boolean value, __true__ if the graph is semi\-eulerian,
    and __false__ otherwise\.

    If the graph is semi\-eulerian and *pathvar* is specified then an euler
    path is computed as well and stored in the named variable\. The path is
    represented by the list of arcs traversed, in the order of traversal\.

  - <a name='14'></a>__struct::graph::op::dijkstra__ *g* *start* ?*options*\.\.\.?

    This command determines distances in the weighted *g* from the node
    *start* to all other nodes in the graph\. The options specify how to
    traverse graphs, and the format of the result\.

    Two options are recognized

      * __\-arcmode__ mode

        The accepted mode values are __directed__ and __undirected__\.
        For directed traversal all arcs are traversed from source to target\. For
        undirected traversal all arcs are traversed in the opposite direction as
        well\. Undirected traversal is the default\.

      * __\-outputformat__ format

        The accepted format values are __distances__ and __tree__\. In
        both cases the result is a dictionary keyed by the names of all nodes in
        the graph\. For __distances__ the value is the distance of the node
        to *start*, whereas for __tree__ the value is the path from the
        node to *start*, excluding the node itself, but including *start*\.
        Tree format is the default\.

  - <a name='15'></a>__struct::graph::op::distance__ *g* *origin* *destination* ?*options*\.\.\.?

    This command determines the \(un\)directed distance between the two nodes
    *origin* and *destination* in the graph *g*\. It accepts the option
    __\-arcmode__ of __struct::graph::op::dijkstra__\.

  - <a name='16'></a>__struct::graph::op::eccentricity__ *g* *n* ?*options*\.\.\.?

    This command determines the \(un\)directed
    *[eccentricity](\.\./\.\./\.\./\.\./index\.md\#eccentricity)* of the node *n*
    in the graph *g*\. It accepts the option __\-arcmode__ of
    __struct::graph::op::dijkstra__\.

    The \(un\)directed *[eccentricity](\.\./\.\./\.\./\.\./index\.md\#eccentricity)*
    of a node is the maximal \(un\)directed distance between the node and any
    other node in the graph\.

  - <a name='17'></a>__struct::graph::op::radius__ *g* ?*options*\.\.\.?

    This command determines the \(un\)directed
    *[radius](\.\./\.\./\.\./\.\./index\.md\#radius)* of the graph *g*\. It accepts
    the option __\-arcmode__ of __struct::graph::op::dijkstra__\.

    The \(un\)directed *[radius](\.\./\.\./\.\./\.\./index\.md\#radius)* of a graph is
    the minimal \(un\)directed
    *[eccentricity](\.\./\.\./\.\./\.\./index\.md\#eccentricity)* of all nodes in
    the graph\.

  - <a name='18'></a>__struct::graph::op::diameter__ *g* ?*options*\.\.\.?

    This command determines the \(un\)directed
    *[diameter](\.\./\.\./\.\./\.\./index\.md\#diameter)* of the graph *g*\. It
    accepts the option __\-arcmode__ of __struct::graph::op::dijkstra__\.

    The \(un\)directed *[diameter](\.\./\.\./\.\./\.\./index\.md\#diameter)* of a
    graph is the maximal \(un\)directed
    *[eccentricity](\.\./\.\./\.\./\.\./index\.md\#eccentricity)* of all nodes in
    the graph\.

  - <a name='19'></a>__struct::graph::op::BellmanFord__ *G* *startnode*

    Searching for [shortests paths](#subsection1) between chosen node and
    all other nodes in graph *G*\. Based on relaxation method\. In comparison to
    __struct::graph::op::dijkstra__ it doesn't need assumption that all
    weights on edges in input graph *G* have to be positive\.

    That generality sets the complexity of algorithm to \- *O\(V\*E\)*, where
    *V* is the number of vertices and *[E](\.\./\.\./\.\./\.\./index\.md\#e)* is
    number of edges in graph *G*\.

      * Arguments:

          + Graph object *G* \(input\)

            Directed, connected and edge weighted graph *G*, without any
            negative cycles \( presence of cycles with the negative sum of weight
            means that there is no shortest path, since the total weight becomes
            lower each time the cycle is traversed \)\. Negative weights on edges
            are allowed\.

          + Node *startnode* \(input\)

            The node for which we find all shortest paths to each other node in
            graph *G*\.

      * Result:

        Dictionary containing for each node \(key\) distances to each other node
        in graph *G*\.

    *Note:* If algorithm finds a negative cycle, it will return error message\.

  - <a name='20'></a>__struct::graph::op::Johnsons__ *G* ?*options*\.\.\.?

    Searching for [shortest paths](#subsection1) between all pairs of
    vertices in graph\. For sparse graphs asymptotically quicker than
    __struct::graph::op::FloydWarshall__ algorithm\. Johnson's algorithm uses
    __struct::graph::op::BellmanFord__ and
    __struct::graph::op::dijkstra__ as subprocedures\.

    Time complexity: *O\(n\*\*2\*log\(n\) \+n\*m\)*, where *n* is the number of nodes
    and *m* is the number of edges in graph *G*\.

      * Arguments:

          + Graph object *G* \(input\)

            Directed graph *G*, weighted on edges and not containing any
            cycles with negative sum of weights \( the presence of such cycles
            means there is no shortest path, since the total weight becomes
            lower each time the cycle is traversed \)\. Negative weights on edges
            are allowed\.

      * Options:

          + __\-filter__

            Returns only existing distances, cuts all *Inf* values for
            non\-existing connections between pairs of nodes\.

      * Result:

        Dictionary containing distances between all pairs of vertices\.

  - <a name='21'></a>__struct::graph::op::FloydWarshall__ *G*

    Searching for [shortest paths](#subsection1) between all pairs of edges
    in weighted graphs\.

    Time complexity: *O\(V^3\)* \- where *V* is number of vertices\.

    Memory complexity: *O\(V^2\)*\.

      * Arguments:

          + Graph object *G* \(input\)

            Directed and weighted graph *G*\.

      * Result:

        Dictionary containing shortest distances to each node from each node\.

    *Note:* Algorithm finds solutions dynamically\. It compares all possible
    paths through the graph between each pair of vertices\. Graph shouldn't
    possess any cycle with negative sum of weights \(the presence of such cycles
    means there is no shortest path, since the total weight becomes lower each
    time the cycle is traversed\)\.

    On the other hand algorithm can be used to find those cycles \- if any
    shortest distance found by algorithm for any nodes *v* and *u* \(when
    *v* is the same node as *u*\) is negative, that node surely belong to at
    least one negative cycle\.

  - <a name='22'></a>__struct::graph::op::MetricTravellingSalesman__ *G*

    Algorithm for solving a metric variation of [Travelling salesman
    problem](#subsection2)\. *TSP problem* is *NP\-Complete*, so there is
    no efficient algorithm to solve it\. Greedy methods are getting extremely
    slow, with the increase in the set of nodes\.

      * Arguments:

          + Graph object *G* \(input\)

            Undirected, weighted graph *G*\.

      * Result:

        Approximated solution of minimum *Hamilton Cycle* \- closed path
        visiting all nodes, each exactly one time\.

    *Note:* [It's 2\-approximation algorithm\.](#subsection7)

  - <a name='23'></a>__struct::graph::op::Christofides__ *G*

    Another algorithm for solving [metric *TSP problem*](#subsection2)\.
    Christofides implementation uses *Max Matching* for reaching better
    approximation factor\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected, weighted graph *G*\.

      * Result:

        Approximated solution of minimum *Hamilton Cycle* \- closed path
        visiting all nodes, each exactly one time\.

    *Note:* [It's is a 3/2 approximation algorithm\. ](#subsection7)

  - <a name='24'></a>__struct::graph::op::GreedyMaxMatching__ *G*

    *Greedy Max Matching* procedure, which finds [maximal
    matching](#subsection3) \(not maximum\) for given graph *G*\. It adds
    edges to solution, beginning from edges with the lowest cost\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected graph *G*\.

      * Result:

        Set of edges \- the max matching for graph *G*\.

  - <a name='25'></a>__struct::graph::op::MaxCut__ *G* *U* *V*

    Algorithm solving a [Maximum Cut Problem](#subsection4)\.

      * Arguments:

          + Graph Object *G* \(input\)

            The graph to cut\.

          + List *U* \(output\)

            Variable storing first set of nodes \(cut\) given by solution\.

          + List *V* \(output\)

            Variable storing second set of nodes \(cut\) given by solution\.

      * Result:

        Algorithm returns number of edges between found two sets of nodes\.

    *Note:* *MaxCut* is a [2\-approximation algorithm\.](#subsection7)

  - <a name='26'></a>__struct::graph::op::UnweightedKCenter__ *G* *k*

    Approximation algorithm that solves a [k\-center problem](#subsection5)\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected complete graph *G*, which satisfies triangle
            inequality\.

          + Integer *k* \(input\)

            Positive integer that sets the number of nodes that will be included
            in *k\-center*\.

      * Result:

        Set of nodes \- *k* center for graph *G*\.

    *Note:* *UnweightedKCenter* is a [2\-approximation
    algorithm\.](#subsection7)

  - <a name='27'></a>__struct::graph::op::WeightedKCenter__ *G* *nodeWeights* *W*

    Approximation algorithm that solves a weighted version of [k\-center
    problem](#subsection5)\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected complete graph *G*, which satisfies triangle
            inequality\.

          + Integer *W* \(input\)

            Positive integer that sets the maximum possible weight of
            *k\-center* found by algorithm\.

          + List *nodeWeights* \(input\)

            List of nodes and its weights in graph *G*\.

      * Result:

        Set of nodes, which is solution found by algorithm\.

    *Note:**WeightedKCenter* is a [3\-approximation
    algorithm\.](#subsection7)

  - <a name='28'></a>__struct::graph::op::GreedyMaxIndependentSet__ *G*

    A *maximal independent set* is an *[independent
    set](\.\./\.\./\.\./\.\./index\.md\#independent\_set)* such that adding any other
    node to the set forces the set to contain an edge\.

    Algorithm for input graph *G* returns set of nodes \(list\), which are
    contained in Max Independent Set found by algorithm\.

  - <a name='29'></a>__struct::graph::op::GreedyWeightedMaxIndependentSet__ *G* *nodeWeights*

    Weighted variation of *Maximal Independent Set*\. It takes as an input
    argument not only graph *G* but also set of weights for all vertices in
    graph *G*\.

    *Note:* Read also *Maximal Independent Set* description for more info\.

  - <a name='30'></a>__struct::graph::op::VerticesCover__ *G*

    *Vertices cover* is a set of vertices such that each edge of the graph is
    incident to at least one vertex of the set\. This 2\-approximation algorithm
    searches for minimum *vertices cover*, which is a classical optimization
    problem in computer science and is a typical example of an *NP\-hard*
    optimization problem that has an approximation algorithm\. For input graph
    *G* algorithm returns the set of edges \(list\), which is Vertex Cover found
    by algorithm\.

  - <a name='31'></a>__struct::graph::op::EdmondsKarp__ *G* *s* *t*

    Improved Ford\-Fulkerson's algorithm, computing the [maximum
    flow](#subsection6) in given flow network *G*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Weighted and directed graph\. Each edge should have set integer
            attribute considered as maximum throughputs that can be carried by
            that link \(edge\)\.

          + Node *s* \(input\)

            The node that is a source for graph *G*\.

          + Node *t* \(input\)

            The node that is a sink for graph *G*\.

      * Result:

        Procedure returns the dictionary containing throughputs for all edges\.
        For each key \( the edge between nodes *u* and *v* in the form of
        *list u v* \) there is a value that is a throughput for that key\. Edges
        where throughput values are equal to 0 are not returned \( it is like
        there was no link in the flow network between nodes connected by such
        edge\)\.

    The general idea of algorithm is finding the shortest augumenting paths in
    graph *G*, as long as they exist, and for each path updating the edge's
    weights along that path, with maximum possible throughput\. The final
    \(maximum\) flow is found when there is no other augumenting path from source
    to sink\.

    *Note:* Algorithm complexity : *O\(V\*E\)*, where *V* is the number of
    nodes and *[E](\.\./\.\./\.\./\.\./index\.md\#e)* is the number of edges in
    graph *G*\.

  - <a name='32'></a>__struct::graph::op::BusackerGowen__ *G* *desiredFlow* *s* *t*

    Algorithm finds solution for a [minimum cost flow
    problem](#subsection6)\. So, the goal is to find a flow, whose max value
    can be *desiredFlow*, from source node *s* to sink node *t* in given
    flow network *G*\. That network except throughputs at edges has also
    defined a non\-negative cost on each edge \- cost of using that edge when
    directing flow with that edge \( it can illustrate e\.g\. fuel usage, time or
    any other measure dependent on usages \)\.

      * Arguments:

          + Graph Object *G* \(input\)

            Flow network \(directed graph\), each edge in graph should have two
            integer attributes: *cost* and *throughput*\.

          + Integer *desiredFlow* \(input\)

            Max value of the flow for that network\.

          + Node *s* \(input\)

            The source node for graph *G*\.

          + Node *t* \(input\)

            The sink node for graph *G*\.

      * Result:

        Dictionary containing values of used throughputs for each edge \( key \)\.
        found by algorithm\.

    *Note:* Algorithm complexity : *O\(V\*\*2\*desiredFlow\)*, where *V* is the
    number of nodes in graph *G*\.

  - <a name='33'></a>__struct::graph::op::ShortestsPathsByBFS__ *G* *s* *outputFormat*

    Shortest pathfinding algorithm using BFS method\. In comparison to
    __struct::graph::op::dijkstra__ it can work with negative weights on
    edges\. Of course negative cycles are not allowed\. Algorithm is better than
    dijkstra for sparse graphs, but also there exist some pathological cases
    \(those cases generally don't appear in practise\) that make time complexity
    increase exponentially with the growth of the number of nodes\.

      * Arguments:

          + Graph Object *G* \(input\)

            Input graph\.

          + Node *s* \(input\)

            Source node for which all distances to each other node in graph
            *G* are computed\.

      * Options and result:

          + __distances__

            When selected *outputFormat* is __distances__ \- procedure
            returns dictionary containing distances between source node *s*
            and each other node in graph *G*\.

          + __paths__

            When selected *outputFormat* is __paths__ \- procedure returns
            dictionary containing for each node *v*, a list of nodes, which is
            a path between source node *s* and node *v*\.

  - <a name='34'></a>__struct::graph::op::BFS__ *G* *s* ?*outputFormat*\.\.\.?

    Breadth\-First Search \- algorithm creates the BFS Tree\. Memory and time
    complexity: *O\(V \+ E\)*, where *V* is the number of nodes and
    *[E](\.\./\.\./\.\./\.\./index\.md\#e)* is number of edges\.

      * Arguments:

          + Graph Object *G* \(input\)

            Input graph\.

          + Node *s* \(input\)

            Source node for BFS procedure\.

      * Options and result:

          + __graph__

            When selected __outputFormat__ is __graph__ \- procedure
            returns a graph structure \(__[struct::graph](graph\.md)__\),
            which is equivalent to BFS tree found by algorithm\.

          + __tree__

            When selected __outputFormat__ is __tree__ \- procedure
            returns a tree structure
            \(__[struct::tree](struct\_tree\.md)__\), which is equivalent to
            BFS tree found by algorithm\.

  - <a name='35'></a>__struct::graph::op::MinimumDiameterSpanningTree__ *G*

    The goal is to find for input graph *G*, the *spanning tree* that has
    the minimum *[diameter](\.\./\.\./\.\./\.\./index\.md\#diameter)* value\.

    General idea of algorithm is to run *[BFS](\.\./\.\./\.\./\.\./index\.md\#bfs)*
    over all vertices in graph *G*\. If the diameter *d* of the tree is odd,
    then we are sure that tree given by *[BFS](\.\./\.\./\.\./\.\./index\.md\#bfs)*
    is minimum \(considering diameter value\)\. When, diameter *d* is even, then
    optimal tree can have minimum
    *[diameter](\.\./\.\./\.\./\.\./index\.md\#diameter)* equal to *d* or *d\-1*\.

    In that case, what algorithm does is rebuilding the tree given by
    *[BFS](\.\./\.\./\.\./\.\./index\.md\#bfs)*, by adding a vertice between root
    node and root's child node \(nodes\), such that subtree created with child
    node as root node is the greatest one \(has the greatests height\)\. In the
    next step for such rebuilded tree, we run again
    *[BFS](\.\./\.\./\.\./\.\./index\.md\#bfs)* with new node as root node\. If the
    height of the tree didn't changed, we have found a better solution\.

    For input graph *G* algorithm returns the graph structure
    \(__[struct::graph](graph\.md)__\) that is a spanning tree with minimum
    diameter found by algorithm\.

  - <a name='36'></a>__struct::graph::op::MinimumDegreeSpanningTree__ *G*

    Algorithm finds for input graph *G*, a spanning tree *T* with the
    minimum possible degree\. That problem is *NP\-hard*, so algorithm is an
    approximation algorithm\.

    Let *V* be the set of nodes for graph *G* and let *W* be any subset of
    *V*\. Lets assume also that *OPT* is optimal solution and *ALG* is
    solution found by algorithm for input graph *G*\.

    It can be proven that solution found with the algorithm must fulfil
    inequality:

    *\(\(&#124;W&#124; \+ k \- 1\) / &#124;W&#124;\) <= ALG <= 2\*OPT \+ log2\(n\) \+ 1*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected simple graph\.

      * Result:

        Algorithm returns graph structure, which is equivalent to spanning tree
        *T* found by algorithm\.

  - <a name='37'></a>__struct::graph::op::MaximumFlowByDinic__ *G* *s* *t* *blockingFlowAlg*

    Algorithm finds [maximum flow](#subsection6) for the flow network
    represented by graph *G*\. It is based on the blocking\-flow finding
    methods, which give us different complexities what makes a better fit for
    different graphs\.

      * Arguments:

          + Graph Object *G* \(input\)

            Directed graph *G* representing the flow network\. Each edge should
            have attribute *throughput* set with integer value\.

          + Node *s* \(input\)

            The source node for the flow network *G*\.

          + Node *t* \(input\)

            The sink node for the flow network *G*\.

      * Options:

          + __dinic__

            Procedure will find maximum flow for flow network *G* using
            Dinic's algorithm \(__struct::graph::op::BlockingFlowByDinic__\)
            for blocking flow computation\.

          + __mkm__

            Procedure will find maximum flow for flow network *G* using
            Malhotra, Kumar and Maheshwari's algorithm
            \(__struct::graph::op::BlockingFlowByMKM__\) for blocking flow
            computation\.

      * Result:

        Algorithm returns dictionary containing it's flow value for each edge
        \(key\) in network *G*\.

    *Note:* __struct::graph::op::BlockingFlowByDinic__ gives *O\(m\*n^2\)*
    complexity and __struct::graph::op::BlockingFlowByMKM__ gives *O\(n^3\)*
    complexity, where *n* is the number of nodes and *m* is the number of
    edges in flow network *G*\.

  - <a name='38'></a>__struct::graph::op::BlockingFlowByDinic__ *G* *s* *t*

    Algorithm for given network *G* with source *s* and sink *t*, finds a
    [blocking flow](#subsection6), which can be used to obtain a
    *[maximum flow](\.\./\.\./\.\./\.\./index\.md\#maximum\_flow)* for that network
    *G*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Directed graph *G* representing the flow network\. Each edge should
            have attribute *throughput* set with integer value\.

          + Node *s* \(input\)

            The source node for the flow network *G*\.

          + Node *t* \(input\)

            The sink node for the flow network *G*\.

      * Result:

        Algorithm returns dictionary containing it's blocking flow value for
        each edge \(key\) in network *G*\.

    *Note:* Algorithm's complexity is *O\(n\*m\)*, where *n* is the number of
    nodes and *m* is the number of edges in flow network *G*\.

  - <a name='39'></a>__struct::graph::op::BlockingFlowByMKM__ *G* *s* *t*

    Algorithm for given network *G* with source *s* and sink *t*, finds a
    [blocking flow](#subsection6), which can be used to obtain a
    *[maximum flow](\.\./\.\./\.\./\.\./index\.md\#maximum\_flow)* for that
    *[network](\.\./\.\./\.\./\.\./index\.md\#network)* *G*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Directed graph *G* representing the flow network\. Each edge should
            have attribute *throughput* set with integer value\.

          + Node *s* \(input\)

            The source node for the flow network *G*\.

          + Node *t* \(input\)

            The sink node for the flow network *G*\.

      * Result:

        Algorithm returns dictionary containing it's blocking flow value for
        each edge \(key\) in network *G*\.

    *Note:* Algorithm's complexity is *O\(n^2\)*, where *n* is the number of
    nodes in flow network *G*\.

  - <a name='40'></a>__struct::graph::op::createResidualGraph__ *G* *f*

    Procedure creates a *[residual
    graph](\.\./\.\./\.\./\.\./index\.md\#residual\_graph)* \(or [residual
    network](#subsection6) \) for network *G* and given flow *f*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Flow network \(directed graph where each edge has set attribute:
            *throughput* \)\.

          + dictionary *f* \(input\)

            Current flows in flow network *G*\.

      * Result:

        Procedure returns graph structure that is a *[residual
        graph](\.\./\.\./\.\./\.\./index\.md\#residual\_graph)* created from input flow
        network *G*\.

  - <a name='41'></a>__struct::graph::op::createAugmentingNetwork__ *G* *f* *path*

    Procedure creates an [augmenting network](#subsection6) for a given
    residual network *G* , flow *f* and augmenting path *path*\.

      * Arguments:

          + Graph Object *G* \(input\)

            Residual network \(directed graph\), where for every edge there are
            set two attributes: throughput and cost\.

          + Dictionary *f* \(input\)

            Dictionary which contains for every edge \(key\), current value of the
            flow on that edge\.

          + List *path* \(input\)

            Augmenting path, set of edges \(list\) for which we create the network
            modification\.

      * Result:

        Algorithm returns graph structure containing the modified augmenting
        network\.

  - <a name='42'></a>__struct::graph::op::createLevelGraph__ *Gf* *s*

    For given residual graph *Gf* procedure finds the [level
    graph](#subsection6)\.

      * Arguments:

          + Graph Object *Gf* \(input\)

            Residual network, where each edge has it's attribute *throughput*
            set with certain value\.

          + Node *s* \(input\)

            The source node for the residual network *Gf*\.

      * Result:

        Procedure returns a *[level
        graph](\.\./\.\./\.\./\.\./index\.md\#level\_graph)* created from input
        *residual network*\.

  - <a name='43'></a>__struct::graph::op::TSPLocalSearching__ *G* *C*

    Algorithm is a *heuristic of local searching* for *Travelling Salesman
    Problem*\. For some solution of *TSP problem*, it checks if it's possible
    to find a better solution\. As *TSP* is well known NP\-Complete problem, so
    algorithm is a approximation algorithm \(with 2 approximation factor\)\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected and complete graph with attributes "weight" set on each
            single edge\.

          + List *C* \(input\)

            A list of edges being *Hamiltonian cycle*, which is solution of
            *TSP Problem* for graph *G*\.

      * Result:

        Algorithm returns the best solution for *TSP problem*, it was able to
        find\.

    *Note:* The solution depends on the choosing of the beginning cycle *C*\.
    It's not true that better cycle assures that better solution will be found,
    but practise shows that we should give starting cycle with as small sum of
    weights as possible\.

  - <a name='44'></a>__struct::graph::op::TSPLocalSearching3Approx__ *G* *C*

    Algorithm is a *heuristic of local searching* for *Travelling Salesman
    Problem*\. For some solution of *TSP problem*, it checks if it's possible
    to find a better solution\. As *TSP* is well known NP\-Complete problem, so
    algorithm is a approximation algorithm \(with 3 approximation factor\)\.

      * Arguments:

          + Graph Object *G* \(input\)

            Undirected and complete graph with attributes "weight" set on each
            single edge\.

          + List *C* \(input\)

            A list of edges being *Hamiltonian cycle*, which is solution of
            *TSP Problem* for graph *G*\.

      * Result:

        Algorithm returns the best solution for *TSP problem*, it was able to
        find\.

    *Note:* In practise 3\-approximation algorithm turns out to be far more
    effective than 2\-approximation, but it gives worser approximation factor\.
    Further heuristics of local searching \(e\.g\. 4\-approximation\) doesn't give
    enough boost to square the increase of approximation factor, so 2 and 3
    approximations are mainly used\.

  - <a name='45'></a>__struct::graph::op::createSquaredGraph__ *G*

    X\-Squared graph is a graph with the same set of nodes as input graph *G*,
    but a different set of edges\. X\-Squared graph has edge *\(u,v\)*, if and
    only if, the distance between *u* and *v* nodes is not greater than X
    and *u \!= v*\.

    Procedure for input graph *G*, returns its two\-squared graph\.

    *Note:* Distances used in choosing new set of edges are considering the
    number of edges, not the sum of weights at edges\.

  - <a name='46'></a>__struct::graph::op::createCompleteGraph__ *G* *originalEdges*

    For input graph *G* procedure adds missing arcs to make it a *[complete
    graph](\.\./\.\./\.\./\.\./index\.md\#complete\_graph)*\. It also holds in variable
    *originalEdges* the set of arcs that graph *G* possessed before that
    operation\.

# <a name='section3'></a>Background theory and terms

## <a name='subsection1'></a>Shortest Path Problem

  - Definition \(*single\-pair shortest path problem*\):

    Formally, given a weighted graph \(let *V* be the set of vertices, and
    *[E](\.\./\.\./\.\./\.\./index\.md\#e)* a set of edges\), and one vertice *v*
    of *V*, find a path *P* from *v* to a *v'* of V so that the sum of
    weights on edges along the path is minimal among all paths connecting v to
    v'\.

  - Generalizations:

      * *The single\-source shortest path problem*, in which we have to find
        shortest paths from a source vertex v to all other vertices in the
        graph\.

      * *The single\-destination shortest path problem*, in which we have to
        find shortest paths from all vertices in the graph to a single
        destination vertex v\. This can be reduced to the single\-source shortest
        path problem by reversing the edges in the graph\.

      * *The all\-pairs shortest path problem*, in which we have to find
        shortest paths between every pair of vertices v, v' in the graph\.

    *Note:* The result of *Shortest Path problem* can be *Shortest Path
    tree*, which is a subgraph of a given \(possibly weighted\) graph constructed
    so that the distance between a selected root node and all other nodes is
    minimal\. It is a tree because if there are two paths between the root node
    and some vertex v \(i\.e\. a cycle\), we can delete the last edge of the longer
    path without increasing the distance from the root node to any node in the
    subgraph\.

## <a name='subsection2'></a>Travelling Salesman Problem

  - Definition:

    For given edge\-weighted \(weights on edges should be positive\) graph the goal
    is to find the cycle that visits each node in graph exactly once
    \(*Hamiltonian cycle*\)\.

  - Generalizations:

      * *Metric TSP* \- A very natural restriction of the *TSP* is to require
        that the distances between cities form a *metric*, i\.e\., they satisfy
        *the triangle inequality*\. That is, for any 3 cities *A*, *B* and
        *[C](\.\./\.\./\.\./\.\./index\.md\#c)*, the distance between *A* and
        *[C](\.\./\.\./\.\./\.\./index\.md\#c)* must be at most the distance from
        *A* to *B* plus the distance from *B* to
        *[C](\.\./\.\./\.\./\.\./index\.md\#c)*\. Most natural instances of *TSP*
        satisfy this constraint\.

      * *Euclidean TSP* \- Euclidean TSP, or *planar TSP*, is the *TSP*
        with the distance being the ordinary *Euclidean distance*\. *Euclidean
        TSP* is a particular case of *TSP* with *triangle inequality*,
        since distances in plane obey triangle inequality\. However, it seems to
        be easier than general *TSP* with *triangle inequality*\. For
        example, *the minimum spanning tree* of the graph associated with an
        instance of *Euclidean TSP* is a *Euclidean minimum spanning tree*,
        and so can be computed in expected *O\(n log n\)* time for *n* points
        \(considerably less than the number of edges\)\. This enables the simple
        *2\-approximation algorithm* for TSP with triangle inequality above to
        operate more quickly\.

      * *Asymmetric TSP* \- In most cases, the distance between two nodes in
        the *TSP* network is the same in both directions\. The case where the
        distance from *A* to *B* is not equal to the distance from *B* to
        *A* is called *asymmetric TSP*\. A practical application of an
        *asymmetric TSP* is route optimisation using street\-level routing
        \(asymmetric due to one\-way streets, slip\-roads and motorways\)\.

## <a name='subsection3'></a>Matching Problem

  - Definition:

    Given a graph *G = \(V,E\)*, a matching or *edge\-independent set* *M* in
    *G* is a set of pairwise non\-adjacent edges, that is, no two edges share a
    common vertex\. A vertex is *matched* if it is incident to an edge in the
    *matching M*\. Otherwise the vertex is *unmatched*\.

  - Generalizations:

      * *Maximal matching* \- a matching *M* of a graph G with the property
        that if any edge not in *M* is added to *M*, it is no longer a
        *[matching](\.\./\.\./\.\./\.\./index\.md\#matching)*, that is, *M* is
        maximal if it is not a proper subset of any other
        *[matching](\.\./\.\./\.\./\.\./index\.md\#matching)* in graph G\. In other
        words, a *matching M* of a graph G is maximal if every edge in G has a
        non\-empty intersection with at least one edge in *M*\.

      * *Maximum matching* \- a matching that contains the largest possible
        number of edges\. There may be many *maximum matchings*\. The *matching
        number* of a graph G is the size of a *maximum matching*\. Note that
        every *maximum matching* is *maximal*, but not every *maximal
        matching* is a *maximum matching*\.

      * *Perfect matching* \- a matching which matches all vertices of the
        graph\. That is, every vertex of the graph is incident to exactly one
        edge of the matching\. Every *perfect matching* is
        *[maximum](\.\./\.\./\.\./\.\./index\.md\#maximum)* and hence *maximal*\.
        In some literature, the term *complete matching* is used\. A *perfect
        matching* is also a *minimum\-size edge cover*\. Moreover, the size of
        a *maximum matching* is no larger than the size of a *minimum edge
        cover*\.

      * *Near\-perfect matching* \- a matching in which exactly one vertex is
        unmatched\. This can only occur when the graph has an odd number of
        vertices, and such a *[matching](\.\./\.\./\.\./\.\./index\.md\#matching)*
        must be *[maximum](\.\./\.\./\.\./\.\./index\.md\#maximum)*\. If, for every
        vertex in a graph, there is a near\-perfect matching that omits only that
        vertex, the graph is also called *factor\-critical*\.

  - Related terms:

      * *Alternating path* \- given a matching *M*, an *alternating path*
        is a path in which the edges belong alternatively to the matching and
        not to the matching\.

      * *[Augmenting path](\.\./\.\./\.\./\.\./index\.md\#augmenting\_path)* \- given
        a matching *M*, an *[augmenting
        path](\.\./\.\./\.\./\.\./index\.md\#augmenting\_path)* is an *alternating
        path* that starts from and ends on free \(unmatched\) vertices\.

## <a name='subsection4'></a>Cut Problems

  - Definition:

    A *cut* is a partition of the vertices of a graph into two *disjoint
    subsets*\. The *cut\-set* of the *cut* is the set of edges whose end
    points are in different subsets of the partition\. Edges are said to be
    crossing the cut if they are in its *cut\-set*\.

    Formally:

      * a *cut* *C = \(S,T\)* is a partition of *V* of a graph *G = \(V,
        E\)*\.

      * an *s\-t cut* *C = \(S,T\)* of a *[flow
        network](\.\./\.\./\.\./\.\./index\.md\#flow\_network)* *N = \(V, E\)* is a cut
        of *N* such that *s* is included in *S* and *t* is included in
        *T*, where *s* and *t* are the
        *[source](\.\./\.\./\.\./\.\./index\.md\#source)* and the *sink* of *N*
        respectively\.

      * The *cut\-set* of a *cut C = \(S,T\)* is such set of edges from graph
        *G = \(V, E\)* that each edge *\(u, v\)* satisfies condition that *u*
        is included in *S* and *v* is included in *T*\.

    In an *unweighted undirected* graph, the size or weight of a cut is the
    number of edges crossing the cut\. In a *weighted graph*, the same term is
    defined by the sum of the weights of the edges crossing the cut\.

    In a *[flow network](\.\./\.\./\.\./\.\./index\.md\#flow\_network)*, an *s\-t
    cut* is a cut that requires the
    *[source](\.\./\.\./\.\./\.\./index\.md\#source)* and the *sink* to be in
    different subsets, and its *cut\-set* only consists of edges going from the
    *source's* side to the *sink's* side\. The capacity of an *s\-t cut* is
    defined by the sum of capacity of each edge in the *cut\-set*\.

    The *cut* of a graph can sometimes refer to its *cut\-set* instead of the
    partition\.

  - Generalizations:

      * *Minimum cut* \- A cut is minimum if the size of the cut is not larger
        than the size of any other cut\.

      * *Maximum cut* \- A cut is maximum if the size of the cut is not smaller
        than the size of any other cut\.

      * *Sparsest cut* \- The *Sparsest cut problem* is to bipartition the
        vertices so as to minimize the ratio of the number of edges across the
        cut divided by the number of vertices in the smaller half of the
        partition\.

## <a name='subsection5'></a>K\-Center Problem

  - Definitions:

      * *Unweighted K\-Center*

        For any set *S* \( which is subset of *V* \) and node *v*, let the
        *connect\(v,S\)* be the cost of cheapest edge connecting *v* with any
        node in *S*\. The goal is to find such *S*, that *&#124;S&#124; = k* and
        *max\_v\{connect\(v,S\)\}* is possibly small\.

        In other words, we can use it i\.e\. for finding best locations in the
        city \( nodes of input graph \) for placing k buildings, such that those
        buildings will be as close as possible to all other locations in town\.

      * *Weighted K\-Center*

        The variation of *unweighted k\-center problem*\. Besides the fact graph
        is edge\-weighted, there are also weights on vertices of input graph
        *G*\. We've got also restriction *W*\. The goal is to choose such set
        of nodes *S* \( which is a subset of *V* \), that it's total weight is
        not greater than *W* and also function: *max\_v \{ min\_u \{ cost\(u,v\)
        \}\}* has the smallest possible worth \( *v* is a node in *V* and
        *u* is a node in *S* \)\.

## <a name='subsection6'></a>Flow Problems

  - Definitions:

      * *the maximum flow problem* \- the goal is to find a feasible flow
        through a single\-source, single\-sink flow network that is maximum\. The
        *maximum flow problem* can be seen as a special case of more complex
        network flow problems, such as the *circulation problem*\. The maximum
        value of an *s\-t flow* is equal to the minimum capacity of an *s\-t
        cut* in the network, as stated in the *max\-flow min\-cut theorem*\.

        More formally for flow network *G = \(V,E\)*, where for each edge *\(u,
        v\)* we have its throuhgput *c\(u,v\)* defined\. As
        *[flow](\.\./\.\./\.\./\.\./index\.md\#flow)* *F* we define set of
        non\-negative integer attributes *f\(u,v\)* assigned to edges, satisfying
        such conditions:

          1. for each edge *\(u, v\)* in *G* such condition should be
             satisfied: 0 <= f\(u,v\) <= c\(u,v\)

          1. Network *G* has source node *s* such that the flow *F* is
             equal to the sum of outcoming flow decreased by the sum of incoming
             flow from that source node *s*\.

          1. Network *G* has sink node *t* such that the the *\-F* value is
             equal to the sum of the incoming flow decreased by the sum of
             outcoming flow from that sink node *t*\.

          1. For each node that is not a
             *[source](\.\./\.\./\.\./\.\./index\.md\#source)* or *sink* the sum
             of incoming flow and sum of outcoming flow should be equal\.

      * *the minimum cost flow problem* \- the goal is finding the cheapest
        possible way of sending a certain amount of flow through a *[flow
        network](\.\./\.\./\.\./\.\./index\.md\#flow\_network)*\.

      * *[blocking flow](\.\./\.\./\.\./\.\./index\.md\#blocking\_flow)* \- a
        *[blocking flow](\.\./\.\./\.\./\.\./index\.md\#blocking\_flow)* for a
        *residual network* *Gf* we name such flow *b* in *Gf* that:

          1. Each path from *sink* to
             *[source](\.\./\.\./\.\./\.\./index\.md\#source)* is the shortest path
             in *Gf*\.

          1. Each shortest path in *Gf* contains an edge with fully used
             throughput in *Gf\+b*\.

      * *residual network* \- for a flow network *G* and flow *f*
        *residual network* is built with those edges, which can send larger
        flow\. It contains only those edges, which can send flow larger than 0\.

      * *level network* \- it has the same set of nodes as *[residual
        graph](\.\./\.\./\.\./\.\./index\.md\#residual\_graph)*, but has only those
        edges *\(u,v\)* from *Gf* for which such equality is satisfied:
        *distance\(s,u\)\+1 = distance\(s,v\)*\.

      * *[augmenting network](\.\./\.\./\.\./\.\./index\.md\#augmenting\_network)* \-
        it is a modification of *residual network* considering the new flow
        values\. Structure stays unchanged but values of throughputs and costs at
        edges are different\.

## <a name='subsection7'></a>Approximation algorithm

  - k\-approximation algorithm:

    Algorithm is a k\-approximation, when for *ALG* \(solution returned by
    algorithm\) and *OPT* \(optimal solution\), such inequality is true:

      * for minimalization problems: *ALG/OPT <= k*

      * for maximalization problems: *OPT/ALG <= k*

# <a name='section4'></a>References

  1. [Adjacency matrix](http://en\.wikipedia\.org/wiki/Adjacency\_matrix)

  1. [Adjacency list](http://en\.wikipedia\.org/wiki/Adjacency\_list)

  1. [Kruskal's
     algorithm](http://en\.wikipedia\.org/wiki/Kruskal%27s\_algorithm)

  1. [Prim's algorithm](http://en\.wikipedia\.org/wiki/Prim%27s\_algorithm)

  1. [Bipartite graph](http://en\.wikipedia\.org/wiki/Bipartite\_graph)

  1. [Strongly connected
     components](http://en\.wikipedia\.org/wiki/Strongly\_connected\_components)

  1. [Tarjan's strongly connected components
     algorithm](http://en\.wikipedia\.org/wiki/Tarjan%27s\_strongly\_connected\_components\_algorithm)

  1. [Cut vertex](http://en\.wikipedia\.org/wiki/Cut\_vertex)

  1. [Bridge](http://en\.wikipedia\.org/wiki/Bridge\_\(graph\_theory\))

  1. [Bellman\-Ford's
     algorithm](http://en\.wikipedia\.org/wiki/Bellman\-Ford\_algorithm)

  1. [Johnson's algorithm](http://en\.wikipedia\.org/wiki/Johnson\_algorithm)

  1. [Floyd\-Warshall's
     algorithm](http://en\.wikipedia\.org/wiki/Floyd\-Warshall\_algorithm)

  1. [Travelling Salesman
     Problem](http://en\.wikipedia\.org/wiki/Travelling\_salesman\_problem)

  1. [Christofides
     Algorithm](http://en\.wikipedia\.org/wiki/Christofides\_algorithm)

  1. [Max Cut](http://en\.wikipedia\.org/wiki/Maxcut)

  1. [Matching](http://en\.wikipedia\.org/wiki/Matching)

  1. [Max Independent
     Set](http://en\.wikipedia\.org/wiki/Maximal\_independent\_set)

  1. [Vertex Cover](http://en\.wikipedia\.org/wiki/Vertex\_cover\_problem)

  1. [Ford\-Fulkerson's
     algorithm](http://en\.wikipedia\.org/wiki/Ford\-Fulkerson\_algorithm)

  1. [Maximum Flow
     problem](http://en\.wikipedia\.org/wiki/Maximum\_flow\_problem)

  1. [Busacker\-Gowen's
     algorithm](http://en\.wikipedia\.org/wiki/Minimum\_cost\_flow\_problem)

  1. [Dinic's algorithm](http://en\.wikipedia\.org/wiki/Dinic's\_algorithm)

  1. [K\-Center
     problem](http://www\.csc\.kth\.se/~viggo/wwwcompendium/node128\.html)

  1. [BFS](http://en\.wikipedia\.org/wiki/Breadth\-first\_search)

  1. [Minimum Degree Spanning
     Tree](http://en\.wikipedia\.org/wiki/Degree\-constrained\_spanning\_tree)

  1. [Approximation
     algorithm](http://en\.wikipedia\.org/wiki/Approximation\_algorithm)

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: graph* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[adjacency list](\.\./\.\./\.\./\.\./index\.md\#adjacency\_list), [adjacency
matrix](\.\./\.\./\.\./\.\./index\.md\#adjacency\_matrix),
[adjacent](\.\./\.\./\.\./\.\./index\.md\#adjacent), [approximation
algorithm](\.\./\.\./\.\./\.\./index\.md\#approximation\_algorithm),
[arc](\.\./\.\./\.\./\.\./index\.md\#arc), [articulation
point](\.\./\.\./\.\./\.\./index\.md\#articulation\_point), [augmenting
network](\.\./\.\./\.\./\.\./index\.md\#augmenting\_network), [augmenting
path](\.\./\.\./\.\./\.\./index\.md\#augmenting\_path),
[bfs](\.\./\.\./\.\./\.\./index\.md\#bfs),
[bipartite](\.\./\.\./\.\./\.\./index\.md\#bipartite), [blocking
flow](\.\./\.\./\.\./\.\./index\.md\#blocking\_flow),
[bridge](\.\./\.\./\.\./\.\./index\.md\#bridge), [complete
graph](\.\./\.\./\.\./\.\./index\.md\#complete\_graph), [connected
component](\.\./\.\./\.\./\.\./index\.md\#connected\_component), [cut
edge](\.\./\.\./\.\./\.\./index\.md\#cut\_edge), [cut
vertex](\.\./\.\./\.\./\.\./index\.md\#cut\_vertex),
[degree](\.\./\.\./\.\./\.\./index\.md\#degree), [degree constrained spanning
tree](\.\./\.\./\.\./\.\./index\.md\#degree\_constrained\_spanning\_tree),
[diameter](\.\./\.\./\.\./\.\./index\.md\#diameter),
[dijkstra](\.\./\.\./\.\./\.\./index\.md\#dijkstra),
[distance](\.\./\.\./\.\./\.\./index\.md\#distance),
[eccentricity](\.\./\.\./\.\./\.\./index\.md\#eccentricity),
[edge](\.\./\.\./\.\./\.\./index\.md\#edge), [flow
network](\.\./\.\./\.\./\.\./index\.md\#flow\_network),
[graph](\.\./\.\./\.\./\.\./index\.md\#graph),
[heuristic](\.\./\.\./\.\./\.\./index\.md\#heuristic), [independent
set](\.\./\.\./\.\./\.\./index\.md\#independent\_set),
[isthmus](\.\./\.\./\.\./\.\./index\.md\#isthmus), [level
graph](\.\./\.\./\.\./\.\./index\.md\#level\_graph), [local
searching](\.\./\.\./\.\./\.\./index\.md\#local\_searching),
[loop](\.\./\.\./\.\./\.\./index\.md\#loop),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching), [max
cut](\.\./\.\./\.\./\.\./index\.md\#max\_cut), [maximum
flow](\.\./\.\./\.\./\.\./index\.md\#maximum\_flow), [minimal spanning
tree](\.\./\.\./\.\./\.\./index\.md\#minimal\_spanning\_tree), [minimum cost
flow](\.\./\.\./\.\./\.\./index\.md\#minimum\_cost\_flow), [minimum degree spanning
tree](\.\./\.\./\.\./\.\./index\.md\#minimum\_degree\_spanning\_tree), [minimum diameter
spanning tree](\.\./\.\./\.\./\.\./index\.md\#minimum\_diameter\_spanning\_tree),
[neighbour](\.\./\.\./\.\./\.\./index\.md\#neighbour),
[node](\.\./\.\./\.\./\.\./index\.md\#node),
[radius](\.\./\.\./\.\./\.\./index\.md\#radius), [residual
graph](\.\./\.\./\.\./\.\./index\.md\#residual\_graph), [shortest
path](\.\./\.\./\.\./\.\./index\.md\#shortest\_path), [squared
graph](\.\./\.\./\.\./\.\./index\.md\#squared\_graph), [strongly connected
component](\.\./\.\./\.\./\.\./index\.md\#strongly\_connected\_component),
[subgraph](\.\./\.\./\.\./\.\./index\.md\#subgraph), [travelling
salesman](\.\./\.\./\.\./\.\./index\.md\#travelling\_salesman),
[vertex](\.\./\.\./\.\./\.\./index\.md\#vertex), [vertex
cover](\.\./\.\./\.\./\.\./index\.md\#vertex\_cover)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Alejandro Paz <vidriloco@gmail\.com>  
Copyright &copy; 2008 \(docs\) Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2009 Michal Antoniewski <antoniewski\.m@gmail\.com>
