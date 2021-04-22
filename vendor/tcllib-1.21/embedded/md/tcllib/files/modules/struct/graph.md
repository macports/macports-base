
[//000000001]: # (struct::graph \- Tcl Data Structures)
[//000000002]: # (Generated from file 'graph\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2009,2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::graph\(n\) 2\.4\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::graph \- Create and manipulate directed graph objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Changes for 2\.0](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require struct::graph ?2\.4\.3?  
package require struct::list ?1\.5?  
package require struct::set ?2\.2\.3?  

[__::struct::graph__ ?*graphName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?](#1)  
[__graphName__ *option* ?*arg arg \.\.\.*?](#2)  
[*graphName* __=__ *sourcegraph*](#3)  
[*graphName* __\-\->__ *destgraph*](#4)  
[*graphName* __append__ *key* *value*](#5)  
[*graphName* __deserialize__ *serialization*](#6)  
[*graphName* __destroy__](#7)  
[*graphName* __arc append__ *arc* *key* *value*](#8)  
[*graphName* __arc attr__ *key*](#9)  
[*graphName* __arc attr__ *key* __\-arcs__ *list*](#10)  
[*graphName* __arc attr__ *key* __\-glob__ *globpattern*](#11)  
[*graphName* __arc attr__ *key* __\-regexp__ *repattern*](#12)  
[*graphName* __arc delete__ *arc* ?*arc* \.\.\.?](#13)  
[*graphName* __arc exists__ *arc*](#14)  
[*graphName* __arc flip__ *arc*](#15)  
[*graphName* __arc get__ *arc* *key*](#16)  
[*graphName* __arc getall__ *arc* ?*pattern*?](#17)  
[*graphName* __arc getunweighted__](#18)  
[*graphName* __arc getweight__ *arc*](#19)  
[*graphName* __arc keys__ *arc* ?*pattern*?](#20)  
[*graphName* __arc keyexists__ *arc* *key*](#21)  
[*graphName* __arc insert__ *start* *end* ?*child*?](#22)  
[*graphName* __arc lappend__ *arc* *key* *value*](#23)  
[*graphName* __arc rename__ *arc* *newname*](#24)  
[*graphName* __arc set__ *arc* *key* ?*value*?](#25)  
[*graphName* __arc setunweighted__ ?*weight*?](#26)  
[*graphName* __arc setweight__ *arc* *weight*](#27)  
[*graphName* __arc unsetweight__ *arc*](#28)  
[*graphName* __arc hasweight__ *arc*](#29)  
[*graphName* __arc source__ *arc*](#30)  
[*graphName* __arc target__ *arc*](#31)  
[*graphName* __arc nodes__ *arc*](#32)  
[*graphName* __arc move\-source__ *arc* *newsource*](#33)  
[*graphName* __arc move\-target__ *arc* *newtarget*](#34)  
[*graphName* __arc move__ *arc* *newsource* *newtarget*](#35)  
[*graphName* __arc unset__ *arc* *key*](#36)  
[*graphName* __arc weights__](#37)  
[*graphName* __arcs__ ?\-key *key*? ?\-value *value*? ?\-filter *cmdprefix*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *node node\.\.\.*?](#38)  
[*graphName* __lappend__ *key* *value*](#39)  
[*graphName* __node append__ *node* *key* *value*](#40)  
[*graphName* __node attr__ *key*](#41)  
[*graphName* __node attr__ *key* __\-nodes__ *list*](#42)  
[*graphName* __node attr__ *key* __\-glob__ *globpattern*](#43)  
[*graphName* __node attr__ *key* __\-regexp__ *repattern*](#44)  
[*graphName* __node degree__ ?\-in&#124;\-out? *node*](#45)  
[*graphName* __node delete__ *node* ?*node*\.\.\.?](#46)  
[*graphName* __node exists__ *node*](#47)  
[*graphName* __node get__ *node* *key*](#48)  
[*graphName* __node getall__ *node* ?*pattern*?](#49)  
[*graphName* __node keys__ *node* ?*pattern*?](#50)  
[*graphName* __node keyexists__ *node* *key*](#51)  
[*graphName* __node insert__ ?*node*\.\.\.?](#52)  
[*graphName* __node lappend__ *node* *key* *value*](#53)  
[*graphName* __node opposite__ *node* *arc*](#54)  
[*graphName* __node rename__ *node* *newname*](#55)  
[*graphName* __node set__ *node* *key* ?*value*?](#56)  
[*graphName* __node unset__ *node* *key*](#57)  
[*graphName* __nodes__ ?\-key *key*? ?\-value *value*? ?\-filter *cmdprefix*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *node* *node*\.\.\.?](#58)  
[*graphName* __get__ *key*](#59)  
[*graphName* __getall__ ?*pattern*?](#60)  
[*graphName* __keys__ ?*pattern*?](#61)  
[*graphName* __keyexists__ *key*](#62)  
[*graphName* __serialize__ ?*node*\.\.\.?](#63)  
[*graphName* __set__ *key* ?*value*?](#64)  
[*graphName* __swap__ *node1* *node2*](#65)  
[*graphName* __unset__ *key*](#66)  
[*graphName* __walk__ *node* ?\-order *order*? ?\-type *type*? ?\-dir *direction*? \-command *cmd*](#67)  

# <a name='description'></a>DESCRIPTION

A directed graph is a structure containing two collections of elements, called
*nodes* and *arcs* respectively, together with a relation \("connectivity"\)
that places a general structure upon the nodes and arcs\.

Each arc is connected to two nodes, one of which is called the
*[source](\.\./\.\./\.\./\.\./index\.md\#source)* and the other the *target*\. This
imposes a direction upon the arc, which is said to go from the source to the
target\. It is allowed that source and target of an arc are the same node\. Such
an arc is called a *[loop](\.\./\.\./\.\./\.\./index\.md\#loop)*\. Whenever a node is
either the source or target of an arc both are said to be
*[adjacent](\.\./\.\./\.\./\.\./index\.md\#adjacent)*\. This extends into a relation
between nodes, i\.e\. if two nodes are connected through at least one arc they are
said to be *[adjacent](\.\./\.\./\.\./\.\./index\.md\#adjacent)* too\.

Each node can be the source and target for any number of arcs\. The former are
called the *outgoing arcs* of the node, the latter the *incoming arcs* of
the node\. The number of arcs in either set is called the *in\-degree* resp\. the
*out\-degree* of the node\.

In addition to maintaining the node and arc relationships, this graph
implementation allows any number of named *attributes* to be associated with
the graph itself, and each node or arc\.

*Note:* The major version of the package
__[struct](\.\./\.\./\.\./\.\./index\.md\#struct)__ has been changed to version
2\.0, due to backward incompatible changes in the API of this module\. Please read
the section [Changes for 2\.0](#section2) for a full list of all changes,
incompatible and otherwise\.

*Note:* A C\-implementation of the command can be had from the location
[http://www\.purl\.org/NET/schlenker/tcl/cgraph](http://www\.purl\.org/NET/schlenker/tcl/cgraph)\.
See also [http://wiki\.tcl\.tk/cgraph](http://wiki\.tcl\.tk/cgraph)\. This
implementation uses a bit less memory than the tcl version provided here
directly, and is faster\. Its support is limited to versions of the package
before 2\.0\.

As of version 2\.2 of this package a critcl based C implementation is available
from here as well\. This implementation however requires Tcl 8\.4 to run\.

The main command of the package is:

  - <a name='1'></a>__::struct::graph__ ?*graphName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?

    The command creates a new graph object with an associated global Tcl command
    whose name is *graphName*\. This command may be used to invoke various
    operations on the graph\. It has the following general form:

      * <a name='2'></a>__graphName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

    If *graphName* is not specified a unique name will be generated by the
    package itself\. If a *source* is specified the new graph will be
    initialized to it\. For the operators __=__, __:=__, and __as__
    the *source* argument is interpreted as the name of another graph object,
    and the assignment operator __=__ will be executed\. For the operator
    __deserialize__ the *source* is a serialized graph object and
    __deserialize__ will be executed\.

    In other words

        ::struct::graph mygraph = b

    is equivalent to

        ::struct::graph mygraph
        mygraph = b

    and

        ::struct::graph mygraph deserialize $b

    is equivalent to

        ::struct::graph mygraph
        mygraph deserialize $b

The following commands are possible for graph objects:

  - <a name='3'></a>*graphName* __=__ *sourcegraph*

    This is the *assignment* operator for graph objects\. It copies the graph
    contained in the graph object *sourcegraph* over the graph data in
    *graphName*\. The old contents of *graphName* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *graphName* __deserialize__ \[*sourcegraph* __serialize__\]

    The operation assumes that the *sourcegraph* provides the method
    __serialize__ and that this method returns a valid graph serialization\.

  - <a name='4'></a>*graphName* __\-\->__ *destgraph*

    This is the *reverse assignment* operator for graph objects\. It copies the
    graph contained in the graph object *graphName* over the graph data in the
    object *destgraph*\. The old contents of *destgraph* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *destgraph* __deserialize__ \[*graphName* __serialize__\]

    The operation assumes that the *destgraph* provides the method
    __deserialize__ and that this method takes a graph serialization\.

  - <a name='5'></a>*graphName* __append__ *key* *value*

    Appends a *value* to one of the keyed values associated with the graph\.
    Returns the new value given to the attribute *key*\.

  - <a name='6'></a>*graphName* __deserialize__ *serialization*

    This is the complement to __serialize__\. It replaces the graph data in
    *graphName* with the graph described by the *serialization* value\. The
    old contents of *graphName* are deleted by this operation\.

  - <a name='7'></a>*graphName* __destroy__

    Destroys the graph, including its storage space and associated command\.

  - <a name='8'></a>*graphName* __arc append__ *arc* *key* *value*

    Appends a *value* to one of the keyed values associated with an *arc*\.
    Returns the new value given to the attribute *key*\.

  - <a name='9'></a>*graphName* __arc attr__ *key*

  - <a name='10'></a>*graphName* __arc attr__ *key* __\-arcs__ *list*

  - <a name='11'></a>*graphName* __arc attr__ *key* __\-glob__ *globpattern*

  - <a name='12'></a>*graphName* __arc attr__ *key* __\-regexp__ *repattern*

    This method retrieves the value of the attribute named *key*, for all arcs
    in the graph \(matching the restriction specified via one of the possible
    options\) and having the specified attribute\.

    The result is a dictionary mapping from arc names to the value of attribute
    *key* at that arc\. Arcs not having the attribute *key*, or not passing a
    specified restriction, are not listed in the result\.

    The possible restrictions are:

      * __\-arcs__

        The value is a list of arcs\. Only the arcs mentioned in this list are
        searched for the attribute\.

      * __\-glob__

        The value is a glob pattern\. Only the arcs in the graph whose names
        match this pattern are searched for the attribute\.

      * __\-regexp__

        The value is a regular expression\. Only the arcs in the graph whose
        names match this pattern are searched for the attribute\.

  - <a name='13'></a>*graphName* __arc delete__ *arc* ?*arc* \.\.\.?

    Remove the specified arcs from the graph\.

  - <a name='14'></a>*graphName* __arc exists__ *arc*

    Return true if the specified *arc* exists in the graph\.

  - <a name='15'></a>*graphName* __arc flip__ *arc*

    Reverses the direction of the named *arc*, i\.e\. the source and target
    nodes of the arc are exchanged with each other\.

  - <a name='16'></a>*graphName* __arc get__ *arc* *key*

    Returns the value associated with the key *key* for the *arc*\.

  - <a name='17'></a>*graphName* __arc getall__ *arc* ?*pattern*?

    Returns a dictionary \(suitable for use with \[__array set__\]\) for the
    *arc*\. If the *pattern* is specified only the attributes whose names
    match the pattern will be part of the returned dictionary\. The pattern is a
    __glob__ pattern\.

  - <a name='18'></a>*graphName* __arc getunweighted__

    Returns a list containing the names of all arcs in the graph which have no
    weight associated with them\.

  - <a name='19'></a>*graphName* __arc getweight__ *arc*

    Returns the weight associated with the *arc*\. Throws an error if the arc
    has no weight associated with it\.

  - <a name='20'></a>*graphName* __arc keys__ *arc* ?*pattern*?

    Returns a list of keys for the *arc*\. If the *pattern* is specified only
    the attributes whose names match the pattern will be part of the returned
    list\. The pattern is a __glob__ pattern\.

  - <a name='21'></a>*graphName* __arc keyexists__ *arc* *key*

    Return true if the specified *key* exists for the *arc*\.

  - <a name='22'></a>*graphName* __arc insert__ *start* *end* ?*child*?

    Insert an arc named *child* into the graph beginning at the node *start*
    and ending at the node *end*\. If the name of the new arc is not specified
    the system will generate a unique name of the form *arc**x*\.

  - <a name='23'></a>*graphName* __arc lappend__ *arc* *key* *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *arc*\. Returns the new value given to the attribute *key*\.

  - <a name='24'></a>*graphName* __arc rename__ *arc* *newname*

    Renames the arc *arc* to *newname*\. An error is thrown if either the arc
    does not exist, or a arc with name *newname* does exist\. The result of the
    command is the new name of the arc\.

  - <a name='25'></a>*graphName* __arc set__ *arc* *key* ?*value*?

    Set or get one of the keyed values associated with an arc\. An arc may have
    any number of keyed values associated with it\. If *value* is not
    specified, this command returns the current value assigned to the key; if
    *value* is specified, this command assigns that value to the key, and
    returns that value\.

  - <a name='26'></a>*graphName* __arc setunweighted__ ?*weight*?

    Sets the weight of all arcs without a weight to *weight*\. Returns the
    empty string as its result\. If not present *weight* defaults to __0__\.

  - <a name='27'></a>*graphName* __arc setweight__ *arc* *weight*

    Sets the weight of the *arc* to *weight*\. Returns *weight*\.

  - <a name='28'></a>*graphName* __arc unsetweight__ *arc*

    Removes the weight of the *arc*, if present\. Does nothing otherwise\.
    Returns the empty string\.

  - <a name='29'></a>*graphName* __arc hasweight__ *arc*

    Determines if the *arc* has a weight associated with it\. The result is a
    boolean value, __True__ if a weight is defined, and __False__
    otherwise\.

  - <a name='30'></a>*graphName* __arc source__ *arc*

    Return the node the given *arc* begins at\.

  - <a name='31'></a>*graphName* __arc target__ *arc*

    Return the node the given *arc* ends at\.

  - <a name='32'></a>*graphName* __arc nodes__ *arc*

    Return the nodes the given *arc* begins and ends at, as a two\-element
    list\.

  - <a name='33'></a>*graphName* __arc move\-source__ *arc* *newsource*

    Changes the source node of the arc to *newsource*\. It can be said that the
    arc rotates around its target node\.

  - <a name='34'></a>*graphName* __arc move\-target__ *arc* *newtarget*

    Changes the target node of the arc to *newtarget*\. It can be said that the
    arc rotates around its source node\.

  - <a name='35'></a>*graphName* __arc move__ *arc* *newsource* *newtarget*

    Changes both source and target nodes of the arc to *newsource*, and
    *newtarget* resp\.

  - <a name='36'></a>*graphName* __arc unset__ *arc* *key*

    Remove a keyed value from the arc *arc*\. The method will do nothing if the
    *key* does not exist\.

  - <a name='37'></a>*graphName* __arc weights__

    Returns a dictionary whose keys are the names of all arcs which have a
    weight associated with them, and the values are these weights\.

  - <a name='38'></a>*graphName* __arcs__ ?\-key *key*? ?\-value *value*? ?\-filter *cmdprefix*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *node node\.\.\.*?

    Returns a list of arcs in the graph\. If no restriction is specified a list
    containing all arcs is returned\. Restrictions can limit the list of returned
    arcs based on the nodes that are connected by the arc, on the keyed values
    associated with the arc, or both\. A general filter command can be used as
    well\. The restrictions that involve connected nodes take a variable number
    of nodes as argument, specified after the name of the restriction itself\.

    The restrictions imposed by either __\-in__, __\-out__, __\-adj__,
    __\-inner__, or __\-embedding__ are applied first\. Specifying more
    than one of them is illegal\.

    After that the restrictions set via __\-key__ \(and __\-value__\) are
    applied\. Specifying more than one __\-key__ \(and __\-value__\) is
    illegal\. Specifying __\-value__ alone, without __\-key__ is illegal as
    well\.

    Any restriction set through __\-filter__ is applied last\. Specifying more
    than one __\-filter__ is illegal\.

    Coming back to the restrictions based on a set of nodes, the command
    recognizes the following switches:

      * __\-in__

        Return a list of all arcs whose target is one of the nodes in the set of
        nodes\. I\.e\. it computes the union of all incoming arcs of the nodes in
        the set\.

      * __\-out__

        Return a list of all arcs whose source is one of the nodes in the set of
        nodes\. I\.e\. it computes the union of all outgoing arcs of the nodes in
        the set\.

      * __\-adj__

        Return a list of all arcs adjacent to at least one of the nodes in the
        set\. This is the union of the nodes returned by __\-in__ and
        __\-out__\.

      * __\-inner__

        Return a list of all arcs which are adjacent to two of the nodes in the
        set\. This is the set of arcs in the subgraph spawned by the specified
        nodes\.

      * __\-embedding__

        Return a list of all arcs adjacent to exactly one of the nodes in the
        set\. This is the set of arcs connecting the subgraph spawned by the
        specified nodes to the rest of the graph\.

    *Attention*: After the above options any word with a leading dash which is
    not a valid option is treated as a node name instead of an invalid option to
    error out on\. This condition holds until either a valid option terminates
    the list of nodes, or the end of the command is reached, whichever comes
    first\.

    The remaining filter options are:

      * __\-key__ *key*

        Limit the list of arcs that are returned to those arcs that have an
        associated key *key*\.

      * __\-value__ *value*

        This restriction can only be used in combination with __\-key__\. It
        limits the list of arcs that are returned to those arcs whose associated
        key *key* has the value *value*\.

      * __\-filter__ *cmdrefix*

        Limit the list of arcs that are returned to those arcs that pass the
        test\. The command in *cmdprefix* is called with two arguments, the
        name of the graph object, and the name of the arc in question\. It is
        executed in the context of the caller and has to return a boolean value\.
        Arcs for which the command returns __false__ are removed from the
        result list before it is returned to the caller\.

  - <a name='39'></a>*graphName* __lappend__ *key* *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    the graph\. Returns the new value given to the attribute *key*\.

  - <a name='40'></a>*graphName* __node append__ *node* *key* *value*

    Appends a *value* to one of the keyed values associated with an *node*\.
    Returns the new value given to the attribute *key*\.

  - <a name='41'></a>*graphName* __node attr__ *key*

  - <a name='42'></a>*graphName* __node attr__ *key* __\-nodes__ *list*

  - <a name='43'></a>*graphName* __node attr__ *key* __\-glob__ *globpattern*

  - <a name='44'></a>*graphName* __node attr__ *key* __\-regexp__ *repattern*

    This method retrieves the value of the attribute named *key*, for all
    nodes in the graph \(matching the restriction specified via one of the
    possible options\) and having the specified attribute\.

    The result is a dictionary mapping from node names to the value of attribute
    *key* at that node\. Nodes not having the attribute *key*, or not passing
    a specified restriction, are not listed in the result\.

    The possible restrictions are:

      * __\-nodes__

        The value is a list of nodes\. Only the nodes mentioned in this list are
        searched for the attribute\.

      * __\-glob__

        The value is a glob pattern\. Only the nodes in the graph whose names
        match this pattern are searched for the attribute\.

      * __\-regexp__

        The value is a regular expression\. Only the nodes in the graph whose
        names match this pattern are searched for the attribute\.

  - <a name='45'></a>*graphName* __node degree__ ?\-in&#124;\-out? *node*

    Return the number of arcs adjacent to the specified *node*\. If one of the
    restrictions __\-in__ or __\-out__ is given only the incoming resp\.
    outgoing arcs are counted\.

  - <a name='46'></a>*graphName* __node delete__ *node* ?*node*\.\.\.?

    Remove the specified nodes from the graph\. All of the nodes' arcs will be
    removed as well to prevent unconnected arcs\.

  - <a name='47'></a>*graphName* __node exists__ *node*

    Return true if the specified *node* exists in the graph\.

  - <a name='48'></a>*graphName* __node get__ *node* *key*

    Return the value associated with the key *key* for the *node*\.

  - <a name='49'></a>*graphName* __node getall__ *node* ?*pattern*?

    Returns a dictionary \(suitable for use with \[__array set__\]\) for the
    *node*\. If the *pattern* is specified only the attributes whose names
    match the pattern will be part of the returned dictionary\. The pattern is a
    __glob__ pattern\.

  - <a name='50'></a>*graphName* __node keys__ *node* ?*pattern*?

    Returns a list of keys for the *node*\. If the *pattern* is specified
    only the attributes whose names match the pattern will be part of the
    returned list\. The pattern is a __glob__ pattern\.

  - <a name='51'></a>*graphName* __node keyexists__ *node* *key*

    Return true if the specified *key* exists for the *node*\.

  - <a name='52'></a>*graphName* __node insert__ ?*node*\.\.\.?

    Insert one or more nodes into the graph\. The new nodes have no arcs
    connected to them\. If no node is specified one node will be inserted, and
    the system will generate a unique name of the form *node**x* for it\.

  - <a name='53'></a>*graphName* __node lappend__ *node* *key* *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *node*\. Returns the new value given to the attribute *key*\.

  - <a name='54'></a>*graphName* __node opposite__ *node* *arc*

    Return the node at the other end of the specified *arc*, which has to be
    adjacent to the given *node*\.

  - <a name='55'></a>*graphName* __node rename__ *node* *newname*

    Renames the node *node* to *newname*\. An error is thrown if either the
    node does not exist, or a node with name *newname* does exist\. The result
    of the command is the new name of the node\.

  - <a name='56'></a>*graphName* __node set__ *node* *key* ?*value*?

    Set or get one of the keyed values associated with a node\. A node may have
    any number of keyed values associated with it\. If *value* is not
    specified, this command returns the current value assigned to the key; if
    *value* is specified, this command assigns that value to the key\.

  - <a name='57'></a>*graphName* __node unset__ *node* *key*

    Remove a keyed value from the node *node*\. The method will do nothing if
    the *key* does not exist\.

  - <a name='58'></a>*graphName* __nodes__ ?\-key *key*? ?\-value *value*? ?\-filter *cmdprefix*? ?\-in&#124;\-out&#124;\-adj&#124;\-inner&#124;\-embedding *node* *node*\.\.\.?

    Return a list of nodes in the graph\. Restrictions can limit the list of
    returned nodes based on neighboring nodes, or based on the keyed values
    associated with the node\. The restrictions that involve neighboring nodes
    have a list of nodes as argument, specified after the name of the
    restriction itself\.

    The possible restrictions are the same as for method __arcs__\. Note that
    while the exact meanings change slightly, as they operate on nodes instead
    of arcs, the general behaviour is the same, especially when it comes to the
    handling of words with a leading dash in node lists\.

    The command recognizes:

      * __\-in__

        Return a list of all nodes with at least one outgoing arc ending in a
        node found in the specified set of nodes\. Alternatively specified as the
        set of source nodes for the __\-in__ arcs of the node set\. The
        *incoming neighbours*\.

      * __\-out__

        Return a list of all nodes with at least one incoming arc starting in a
        node found in the specified set of nodes\. Alternatively specified as the
        set of target nodes for the __\-out__ arcs of the node set\. The
        *outgoing neighbours*\.

      * __\-adj__

        This is the union of the nodes returned by __\-in__ and __\-out__\.
        The *neighbours*\.

      * __\-inner__

        The set of neighbours \(see __\-adj__ above\) which are also in the set
        of nodes\. I\.e\. the intersection between the set of nodes and the
        neighbours per __\-adj__\.

      * __\-embedding__

        The set of neighbours \(see __\-adj__ above\) which are not in the set
        of nodes\. I\.e\. the difference between the neighbours as per
        __\-adj__, and the set of nodes\.

      * __\-key__ *key*

        Limit the list of nodes that are returned to those nodes that have an
        associated key *key*\.

      * __\-value__ *value*

        This restriction can only be used in combination with __\-key__\. It
        limits the list of nodes that are returned to those nodes whose
        associated key *key* has the value *value*\.

      * __\-filter__ *cmdrefix*

        Limit the list of nodes that are returned to those nodes that pass the
        test\. The command in *cmdprefix* is called with two arguments, the
        name of the graph object, and the name of the node in question\. It is
        executed in the context of the caller and has to return a boolean value\.
        Nodes for which the command returns __false__ are removed from the
        result list before it is returned to the caller\.

  - <a name='59'></a>*graphName* __get__ *key*

    Return the value associated with the key *key* for the graph\.

  - <a name='60'></a>*graphName* __getall__ ?*pattern*?

    Returns a dictionary \(suitable for use with \[__array set__\]\) for the
    whole graph\. If the *pattern* is specified only the attributes whose names
    match the pattern will be part of the returned dictionary\. The pattern is a
    __glob__ pattern\.

  - <a name='61'></a>*graphName* __keys__ ?*pattern*?

    Returns a list of keys for the whole graph\. If the *pattern* is specified
    only the attributes whose names match the pattern will be part of the
    returned list\. The pattern is a __glob__ pattern\.

  - <a name='62'></a>*graphName* __keyexists__ *key*

    Return true if the specified *key* exists for the whole graph\.

  - <a name='63'></a>*graphName* __serialize__ ?*node*\.\.\.?

    This method serializes the sub\-graph spanned up by the *node*s\. In other
    words it returns a tcl value completely describing that graph\. If no nodes
    are specified the whole graph will be serialized\. This allows, for example,
    the transfer of graph objects \(or parts thereof\) over arbitrary channels,
    persistence, etc\. This method is also the basis for both the copy
    constructor and the assignment operator\.

    The result of this method has to be semantically identical over all
    implementations of the graph interface\. This is what will enable us to copy
    graph data between different implementations of the same interface\.

    The result is a list containing a multiple of three items, plus one\! In
    other words, '\[llength $serial\] % 3 == 1'\. Valid values include 1, 4, 7, \.\.\.

    The last element of the list is a dictionary containing the attributes
    associated with the whole graph\. Regarding the other elements; each triple
    consists of

      1. The name of the node to be described,

      1. A dictionary containing the attributes associated with the node,

      1. And a list describing all the arcs starting at that node\.

    The elements of the arc list are lists containing three or four elements
    each, i\.e\.

      1. The name of the arc described by the element,

      1. A reference to the destination node of the arc\. This reference is an
         integer number given the index of that node in the main serialization
         list\. As that it is greater than or equal to zero, less than the length
         of the serialization, and a multiple of three\. *Note:* For internal
         consistency no arc name may be used twice, whether in the same node, or
         at some other node\. This is a global consistency requirement for the
         serialization\.

      1. And a dictionary containing the attributes associated with the arc\.

      1. The weight associated with the arc\. This value is optional\. Its
         non\-presence means that the arc in question has no weight associated
         with it\.

         *Note:* This information is new, compared to the serialization of
         __[graph](\.\./\.\./\.\./\.\./index\.md\#graph)__ 2\.3 and earlier\. By
         making it an optional element the new format is maximally compatible
         with the old\. This means that any graph not using weights will generate
         a serialization which is still understood by the older graph package\. A
         serialization will not be understood any longer by the older packages
         if, and only if the graph it was generated from actually has arcs with
         weights\.

    For all attribute dictionaries they keys are the names of the attributes,
    and the values are the values for each name\.

    *Note:* The order of the nodes in the serialization has no relevance, nor
    has the order of the arcs per node\.

        # A possible serialization for the graph structure
        #
        #        d -----> %2
        #       /         ^ \
        #      /         /   \
        #     /         b     \
        #    /         /       \
        #  %1 <- a - %0         e
        #    ^         \\      /
        #     \\        c     /
        #      \\        \\  /
        #       \\        v v
        #        f ------ %3
        # is
        #
        # %3 {} {{f 6 {}}} %0 {} {{a 6 {}} {b 9 {}} {c 0 {}}} %1 {} {{d 9 {}}} %2 {} {{e 0 {}}} {}
        #
        # This assumes that the graph has neither attribute data nor weighted arcs.

  - <a name='64'></a>*graphName* __set__ *key* ?*value*?

    Set or get one of the keyed values associated with a graph\. A graph may have
    any number of keyed values associated with it\. If *value* is not
    specified, this command returns the current value assigned to the key; if
    *value* is specified, this command assigns that value to the key\.

  - <a name='65'></a>*graphName* __swap__ *node1* *node2*

    Swap the position of *node1* and *node2* in the graph\.

  - <a name='66'></a>*graphName* __unset__ *key*

    Remove a keyed value from the graph\. The method will do nothing if the
    *key* does not exist\.

  - <a name='67'></a>*graphName* __walk__ *node* ?\-order *order*? ?\-type *type*? ?\-dir *direction*? \-command *cmd*

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
    neighbors\. The combination of a breadth\-first walk with post\- or both\-order
    is illegal\.

    The direction of the walk is determined by the value of *dir*;
    __backward__ indicates the direction opposite to the incoming arcs,
    __forward__ indicates the direction of the outgoing arcs\.

    As the walk progresses, the command *cmd* will be evaluated at each node,
    with the mode of the call \(__enter__ or __leave__\) and values
    *graphName* and the name of the current node appended\. For a pre\-order
    walk, all nodes are __enter__ed, for a post\-order all nodes are left\. In
    a both\-order walk the first visit of a node __enter__s it, the second
    visit __leave__s it\.

# <a name='section2'></a>Changes for 2\.0

The following noteworthy changes have occurred:

  1. The API for accessing attributes and their values has been simplified\.

     All functionality regarding the default attribute "data" has been removed\.
     This default attribute does not exist anymore\. All accesses to attributes
     have to specify the name of the attribute in question\. This backward
     *incompatible* change allowed us to simplify the signature of all methods
     handling attributes\.

     Especially the flag __\-key__ is not required anymore, even more, its
     use is now forbidden\. Please read the documentation for the arc and node
     methods __set__, __get__, __getall__, __unset__,
     __append__, __lappend__, __keyexists__ and __keys__ for a
     description of the new API's\.

  1. The methods __keys__ and __getall__ now take an optional pattern
     argument and will return only attribute data for keys matching this
     pattern\.

  1. Arcs and nodes can now be renamed\. See the documentation for the methods
     __arc rename__ and __node rename__\.

  1. The structure has been extended with API's for the serialization and
     deserialization of graph objects, and a number of operations based on them
     \(graph assignment, copy construction\)\.

     Please read the documentation for the methods __serialize__,
     __deserialize__, __=__, and __\-\->__, and the documentation on
     the construction of graph objects\.

     Beyond the copying of whole graph objects these new API's also enable the
     transfer of graph objects over arbitrary channels and for easy persistence\.

  1. A new method, __attr__, was added to both __arc__ and __node__
     allowing the query and retrieval of attribute data without regard to arc
     and node relationships\.

  1. Both methods __arcs__ and __nodes__ have been extended with the
     ability to select arcs and nodes based on an arbitrary filtering criterium\.

# <a name='section3'></a>Bugs, Ideas, Feedback

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

[adjacent](\.\./\.\./\.\./\.\./index\.md\#adjacent),
[arc](\.\./\.\./\.\./\.\./index\.md\#arc), [cgraph](\.\./\.\./\.\./\.\./index\.md\#cgraph),
[degree](\.\./\.\./\.\./\.\./index\.md\#degree),
[edge](\.\./\.\./\.\./\.\./index\.md\#edge), [graph](\.\./\.\./\.\./\.\./index\.md\#graph),
[loop](\.\./\.\./\.\./\.\./index\.md\#loop),
[neighbour](\.\./\.\./\.\./\.\./index\.md\#neighbour),
[node](\.\./\.\./\.\./\.\./index\.md\#node),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization),
[subgraph](\.\./\.\./\.\./\.\./index\.md\#subgraph),
[vertex](\.\./\.\./\.\./\.\./index\.md\#vertex)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2009,2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
