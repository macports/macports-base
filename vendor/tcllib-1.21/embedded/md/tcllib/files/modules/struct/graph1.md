
[//000000001]: # (struct::graph\_v1 \- Tcl Data Structures)
[//000000002]: # (Generated from file 'graph1\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::graph\_v1\(n\) 1\.2\.1 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::graph\_v1 \- Create and manipulate directed graph objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::graph ?1\.2\.1?  

[__graphName__ *option* ?*arg arg \.\.\.*?](#1)  
[*graphName* __destroy__](#2)  
[*graphName* __arc append__ *arc* ?\-key *key*? *value*](#3)  
[*graphName* __arc delete__ *arc* ?*arc* \.\.\.?](#4)  
[*graphName* __arc exists__ *arc*](#5)  
[*graphName* __arc get__ *arc* ?\-key *key*?](#6)  
[*graphName* __arc getall__ *arc*](#7)  
[*graphName* __arc keys__ *arc*](#8)  
[*graphName* __arc keyexists__ *arc* ?\-key *key*?](#9)  
[*graphName* __arc insert__ *start* *end* ?*child*?](#10)  
[*graphName* __arc lappend__ *arc* ?\-key *key*? *value*](#11)  
[*graphName* __arc set__ *arc* ?\-key *key*? ?*value*?](#12)  
[*graphName* __arc source__ *arc*](#13)  
[*graphName* __arc target__ *arc*](#14)  
[*graphName* __arc unset__ *arc* ?\-key *key*?](#15)  
[*graphName* __arcs__ ?\-key *key*? ?\-value *value*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *nodelist*?](#16)  
[*graphName* __node append__ *node* ?\-key *key*? *value*](#17)  
[*graphName* __node degree__ ?\-in&#124;\-out? *node*](#18)  
[*graphName* __node delete__ *node* ?*node* \.\.\.?](#19)  
[*graphName* __node exists__ *node*](#20)  
[*graphName* __node get__ *node* ?\-key *key*?](#21)  
[*graphName* __node getall__ *node*](#22)  
[*graphName* __node keys__ *node*](#23)  
[*graphName* __node keyexists__ *node* ?\-key *key*?](#24)  
[*graphName* __node insert__ ?*child*?](#25)  
[*graphName* __node lappend__ *node* ?\-key *key*? *value*](#26)  
[*graphName* __node opposite__ *node* *arc*](#27)  
[*graphName* __node set__ *node* ?\-key *key*? ?*value*?](#28)  
[*graphName* __node unset__ *node* ?\-key *key*?](#29)  
[*graphName* __nodes__ ?\-key *key*? ?\-value *value*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *nodelist*?](#30)  
[*graphName* __get__ ?\-key *key*?](#31)  
[*graphName* __getall__](#32)  
[*graphName* __keys__](#33)  
[*graphName* __keyexists__ ?\-key *key*?](#34)  
[*graphName* __set__ ?\-key *key*? ?*value*?](#35)  
[*graphName* __swap__ *node1* *node2*](#36)  
[*graphName* __unset__ ?\-key *key*?](#37)  
[*graphName* __walk__ *node* ?\-order *order*? ?\-type *type*? ?\-dir *direction*? \-command *cmd*](#38)  

# <a name='description'></a>DESCRIPTION

The __::struct::graph__ command creates a new graph object with an
associated global Tcl command whose name is *graphName*\. This command may be
used to invoke various operations on the graph\. It has the following general
form:

  - <a name='1'></a>__graphName__ *option* ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

A directed graph is a structure containing two collections of elements, called
*nodes* and *arcs* respectively, together with a relation \("connectivity"\)
that places a general structure upon the nodes and arcs\.

Each arc is connected to two nodes, one of which is called the *source* and
the other the *target*\. This imposes a direction upon the arc, which is said
to go from the source to the target\. It is allowed that source and target of an
arc are the same node\. Such an arc is called a *loop*\. Whenever a node is
source or target of an arc both are said to be *adjacent*\. This extends into a
relation between nodes, i\.e\. if two nodes are connected through at least one arc
they are said to be *adjacent* too\.

Each node can be the source and target for any number of arcs\. The former are
called the *outgoing arcs* of the node, the latter the *incoming arcs* of
the node\. The number of edges in either set is called the *in\-* resp\. the
*out\-degree* of the node\.

In addition to maintaining the node and arc relationships, this graph
implementation allows any number of keyed values to be associated with each node
and arc\.

The following commands are possible for graph objects:

  - <a name='2'></a>*graphName* __destroy__

    Destroy the graph, including its storage space and associated command\.

  - <a name='3'></a>*graphName* __arc append__ *arc* ?\-key *key*? *value*

    Appends a *value* to one of the keyed values associated with an *arc*\.
    If no *key* is specified, the key __data__ is assumed\.

  - <a name='4'></a>*graphName* __arc delete__ *arc* ?*arc* \.\.\.?

    Remove the specified arcs from the graph\.

  - <a name='5'></a>*graphName* __arc exists__ *arc*

    Return true if the specified *arc* exists in the graph\.

  - <a name='6'></a>*graphName* __arc get__ *arc* ?\-key *key*?

    Return the value associated with the key *key* for the *arc*\. If no key
    is specified, the key __data__ is assumed\.

  - <a name='7'></a>*graphName* __arc getall__ *arc*

    Returns a serialized list of key/value pairs \(suitable for use with
    \[__array set__\]\) for the *arc*\.

  - <a name='8'></a>*graphName* __arc keys__ *arc*

    Returns a list of keys for the *arc*\.

  - <a name='9'></a>*graphName* __arc keyexists__ *arc* ?\-key *key*?

    Return true if the specified *key* exists for the *arc*\. If no *key*
    is specified, the key __data__ is assumed\.

  - <a name='10'></a>*graphName* __arc insert__ *start* *end* ?*child*?

    Insert an arc named *child* into the graph beginning at the node *start*
    and ending at the node *end*\. If the name of the new arc is not specified
    the system will generate a unique name of the form *arc**x*\.

  - <a name='11'></a>*graphName* __arc lappend__ *arc* ?\-key *key*? *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *arc*\. If no *key* is specified, the key __data__ is assumed\.

  - <a name='12'></a>*graphName* __arc set__ *arc* ?\-key *key*? ?*value*?

    Set or get one of the keyed values associated with an arc\. If no key is
    specified, the key __data__ is assumed\. Each arc that is added to a
    graph has the empty string assigned to the key __data__ automatically\.
    An arc may have any number of keyed values associated with it\. If *value*
    is not specified, this command returns the current value assigned to the
    key; if *value* is specified, this command assigns that value to the key\.

  - <a name='13'></a>*graphName* __arc source__ *arc*

    Return the node the given *arc* begins at\.

  - <a name='14'></a>*graphName* __arc target__ *arc*

    Return the node the given *arc* ends at\.

  - <a name='15'></a>*graphName* __arc unset__ *arc* ?\-key *key*?

    Remove a keyed value from the arc *arc*\. If no key is specified, the key
    __data__ is assumed\.

  - <a name='16'></a>*graphName* __arcs__ ?\-key *key*? ?\-value *value*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *nodelist*?

    Return a list of arcs in the graph\. If no restriction is specified a list
    containing all arcs is returned\. Restrictions can limit the list of returned
    arcs based on the nodes that are connected by the arc, on the keyed values
    associated with the arc, or both\. The restrictions that involve connected
    nodes have a list of nodes as argument, specified after the name of the
    restriction itself\.

      * __\-in__

        Return a list of all arcs whose target is one of the nodes in the
        *nodelist*\.

      * __\-out__

        Return a list of all arcs whose source is one of the nodes in the
        *nodelist*\.

      * __\-adj__

        Return a list of all arcs adjacent to at least one of the nodes in the
        *nodelist*\. This is the union of the nodes returned by __\-in__ and
        __\-out__\.

      * __\-inner__

        Return a list of all arcs adjacent to two of the nodes in the
        *nodelist*\. This is the set of arcs in the subgraph spawned by the
        specified nodes\.

      * __\-embedding__

        Return a list of all arcs adjacent to exactly one of the nodes in the
        *nodelist*\. This is the set of arcs connecting the subgraph spawned by
        the specified nodes to the rest of the graph\.

      * __\-key__ *key*

        Limit the list of arcs that are returned to those arcs that have an
        associated key *key*\.

      * __\-value__ *value*

        This restriction can only be used in combination with __\-key__\. It
        limits the list of arcs that are returned to those arcs whose associated
        key *key* has the value *value*\.

    The restrictions imposed by either __\-in__, __\-out__, __\-adj__,
    __\-inner__, or __\-embedded__ are applied first\. Specifying more than
    one of them is illegal\. At last the restrictions set via __\-key__ \(and
    __\-value__\) are applied\. Specifying more than one __\-key__ \(and
    __\-value__\) is illegal\.

  - <a name='17'></a>*graphName* __node append__ *node* ?\-key *key*? *value*

    Appends a *value* to one of the keyed values associated with an *node*\.
    If no *key* is specified, the key __data__ is assumed\.

  - <a name='18'></a>*graphName* __node degree__ ?\-in&#124;\-out? *node*

    Return the number of arcs adjacent to the specified *node*\. If one of the
    restrictions __\-in__ or __\-out__ is given only the incoming resp\.
    outgoing arcs are counted\.

  - <a name='19'></a>*graphName* __node delete__ *node* ?*node* \.\.\.?

    Remove the specified nodes from the graph\. All of the nodes' arcs will be
    removed as well to prevent unconnected arcs\.

  - <a name='20'></a>*graphName* __node exists__ *node*

    Return true if the specified *node* exists in the graph\.

  - <a name='21'></a>*graphName* __node get__ *node* ?\-key *key*?

    Return the value associated with the key *key* for the *node*\. If no key
    is specified, the key __data__ is assumed\.

  - <a name='22'></a>*graphName* __node getall__ *node*

    Returns a serialized list of key/value pairs \(suitable for use with
    \[__array set__\]\) for the *node*\.

  - <a name='23'></a>*graphName* __node keys__ *node*

    Returns a list of keys for the *node*\.

  - <a name='24'></a>*graphName* __node keyexists__ *node* ?\-key *key*?

    Return true if the specified *key* exists for the *node*\. If no *key*
    is specified, the key __data__ is assumed\.

  - <a name='25'></a>*graphName* __node insert__ ?*child*?

    Insert a node named *child* into the graph\. The nodes has no arcs
    connected to it\. If the name of the new child is not specified the system
    will generate a unique name of the form *node**x*\.

  - <a name='26'></a>*graphName* __node lappend__ *node* ?\-key *key*? *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *node*\. If no *key* is specified, the key __data__ is assumed\.

  - <a name='27'></a>*graphName* __node opposite__ *node* *arc*

    Return the node at the other end of the specified *arc*, which has to be
    adjacent to the given *node*\.

  - <a name='28'></a>*graphName* __node set__ *node* ?\-key *key*? ?*value*?

    Set or get one of the keyed values associated with a node\. If no key is
    specified, the key __data__ is assumed\. Each node that is added to a
    graph has the empty string assigned to the key __data__ automatically\. A
    node may have any number of keyed values associated with it\. If *value* is
    not specified, this command returns the current value assigned to the key;
    if *value* is specified, this command assigns that value to the key\.

  - <a name='29'></a>*graphName* __node unset__ *node* ?\-key *key*?

    Remove a keyed value from the node *node*\. If no key is specified, the key
    __data__ is assumed\.

  - <a name='30'></a>*graphName* __nodes__ ?\-key *key*? ?\-value *value*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *nodelist*?

    Return a list of nodes in the graph\. Restrictions can limit the list of
    returned nodes based on neighboring nodes, or based on the keyed values
    associated with the node\. The restrictions that involve neighboring nodes
    have a list of nodes as argument, specified after the name of the
    restriction itself\.

    The possible restrictions are the same as for method __arcs__\. The set
    of nodes to return is computed as the union of all source and target nodes
    for all the arcs satisfying the restriction as defined for __arcs__\.

  - <a name='31'></a>*graphName* __get__ ?\-key *key*?

    Return the value associated with the key *key* for the graph\. If no key is
    specified, the key __data__ is assumed\.

  - <a name='32'></a>*graphName* __getall__

    Returns a serialized list of key/value pairs \(suitable for use with
    \[__array set__\]\) for the whole graph\.

  - <a name='33'></a>*graphName* __keys__

    Returns a list of keys for the whole graph\.

  - <a name='34'></a>*graphName* __keyexists__ ?\-key *key*?

    Return true if the specified *key* exists for the whole graph\. If no
    *key* is specified, the key __data__ is assumed\.

  - <a name='35'></a>*graphName* __set__ ?\-key *key*? ?*value*?

    Set or get one of the keyed values associated with a graph\. If no key is
    specified, the key __data__ is assumed\. Each graph has the empty string
    assigned to the key __data__ automatically\. A graph may have any number
    of keyed values associated with it\. If *value* is not specified, this
    command returns the current value assigned to the key; if *value* is
    specified, this command assigns that value to the key\.

  - <a name='36'></a>*graphName* __swap__ *node1* *node2*

    Swap the position of *node1* and *node2* in the graph\.

  - <a name='37'></a>*graphName* __unset__ ?\-key *key*?

    Remove a keyed value from the graph\. If no key is specified, the key
    __data__ is assumed\.

  - <a name='38'></a>*graphName* __walk__ *node* ?\-order *order*? ?\-type *type*? ?\-dir *direction*? \-command *cmd*

    Perform a breadth\-first or depth\-first walk of the graph starting at the
    node *node* going in either the direction of outgoing or opposite to the
    incoming arcs\.

    The type of walk, breadth\-first or depth\-first, is determined by the value
    of *type*; __bfs__ indicates breadth\-first, __dfs__ indicates
    depth\-first\. Depth\-first is the default\.

    The order of the walk, pre\-order, post\-order or both\-order is determined by
    the value of *order*; __pre__ indicates pre\-order, __post__
    indicates post\-order, __both__ indicates both\-order\. Pre\-order is the
    default\. Pre\-order walking means that a node is visited before any of its
    neighbors \(as defined by the *direction*, see below\)\. Post\-order walking
    means that a parent is visited after any of its neighbors\. Both\-order
    walking means that a node is visited before *and* after any of its
    neighbors\. The combination of a bread\-first walk with post\- or both\-order is
    illegal\.

    The direction of the walk is determined by the value of *dir*;
    __backward__ indicates the direction opposite to the incoming arcs,
    __forward__ indicates the direction of the outgoing arcs\.

    As the walk progresses, the command *cmd* will be evaluated at each node,
    with the mode of the call \(__enter__ or __leave__\) and values
    *graphName* and the name of the current node appended\. For a pre\-order
    walk, all nodes are __enter__ed, for a post\-order all nodes are left\. In
    a both\-order walk the first visit of a node __enter__s it, the second
    visit __leave__s it\.

# <a name='section2'></a>Bugs, Ideas, Feedback

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

[cgraph](\.\./\.\./\.\./\.\./index\.md\#cgraph),
[graph](\.\./\.\./\.\./\.\./index\.md\#graph)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
