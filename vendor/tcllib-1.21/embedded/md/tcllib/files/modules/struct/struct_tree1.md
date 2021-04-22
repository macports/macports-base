
[//000000001]: # (struct::tree\_v1 \- Tcl Data Structures)
[//000000002]: # (Generated from file 'struct\_tree1\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::tree\_v1\(n\) 1\.2\.2 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::tree\_v1 \- Create and manipulate tree objects

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
package require struct::tree ?1\.2\.2?  

[__treeName__ __option__ ?*arg arg \.\.\.*?](#1)  
[*treeName* __append__ *node* ?\-key *key*? *value*](#2)  
[*treeName* __children__ *node*](#3)  
[*treeName* __cut__ *node*](#4)  
[*treeName* __delete__ *node* ?*node* \.\.\.?](#5)  
[*treeName* __depth__ *node*](#6)  
[*treeName* __destroy__](#7)  
[*treeName* __exists__ *node*](#8)  
[*treeName* __get__ *node* ?__\-key__ *key*?](#9)  
[*treeName* __getall__ *node*](#10)  
[*treeName* __keys__ *node*](#11)  
[*treeName* __keyexists__ *node* ?\-key *key*?](#12)  
[*treeName* __index__ *node*](#13)  
[*treeName* __insert__ *parent* *index* ?*child* ?*child* \.\.\.??](#14)  
[*treeName* __isleaf__ *node*](#15)  
[*treeName* __lappend__ *node* ?\-key *key*? *value*](#16)  
[*treeName* __move__ *parent* *index* *node* ?*node* \.\.\.?](#17)  
[*treeName* __next__ *node*](#18)  
[*treeName* __numchildren__ *node*](#19)  
[*treeName* __parent__ *node*](#20)  
[*treeName* __previous__ *node*](#21)  
[*treeName* __set__ *node* ?__\-key__ *key*? ?*value*?](#22)  
[*treeName* __size__ ?*node*?](#23)  
[*treeName* __splice__ *parent* *from* ?*to*? ?*child*?](#24)  
[*treeName* __swap__ *node1* *node2*](#25)  
[*treeName* __unset__ *node* ?__\-key__ *key*?](#26)  
[*treeName* __walk__ *node* ?__\-order__ *order*? ?__\-type__ *type*? __\-command__ *cmd*](#27)  

# <a name='description'></a>DESCRIPTION

The __::struct::tree__ command creates a new tree object with an associated
global Tcl command whose name is *treeName*\. This command may be used to
invoke various operations on the tree\. It has the following general form:

  - <a name='1'></a>__treeName__ __option__ ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

A tree is a collection of named elements, called nodes, one of which is
distinguished as a root, along with a relation \("parenthood"\) that places a
hierarchical structure on the nodes\. \(Data Structures and Algorithms; Aho,
Hopcroft and Ullman; Addison\-Wesley, 1987\)\. In addition to maintaining the node
relationships, this tree implementation allows any number of keyed values to be
associated with each node\.

The element names can be arbitrary strings\.

A tree is thus similar to an array, but with three important differences:

  1. Trees are accessed through an object command, whereas arrays are accessed
     as variables\. \(This means trees cannot be local to a procedure\.\)

  1. Trees have a hierarchical structure, whereas an array is just an unordered
     collection\.

  1. Each node of a tree has a separate collection of attributes and values\.
     This is like an array where every value is a dictionary\.

The following commands are possible for tree objects:

  - <a name='2'></a>*treeName* __append__ *node* ?\-key *key*? *value*

    Appends a *value* to one of the keyed values associated with an node\. If
    no *key* is specified, the key __data__ is assumed\.

  - <a name='3'></a>*treeName* __children__ *node*

    Return a list of the children of *node*\.

  - <a name='4'></a>*treeName* __cut__ *node*

    Removes the node specified by *node* from the tree, but not its children\.
    The children of *node* are made children of the parent of the *node*, at
    the index at which *node* was located\.

  - <a name='5'></a>*treeName* __delete__ *node* ?*node* \.\.\.?

    Removes the specified nodes from the tree\. All of the nodes' children will
    be removed as well to prevent orphaned nodes\.

  - <a name='6'></a>*treeName* __depth__ *node*

    Return the number of steps from node *node* to the root node\.

  - <a name='7'></a>*treeName* __destroy__

    Destroy the tree, including its storage space and associated command\.

  - <a name='8'></a>*treeName* __exists__ *node*

    Returns true if the specified node exists in the tree\.

  - <a name='9'></a>*treeName* __get__ *node* ?__\-key__ *key*?

    Return the value associated with the key *key* for the node *node*\. If
    no key is specified, the key __data__ is assumed\.

  - <a name='10'></a>*treeName* __getall__ *node*

    Returns a serialized list of key/value pairs \(suitable for use with
    \[__array set__\]\) for the *node*\.

  - <a name='11'></a>*treeName* __keys__ *node*

    Returns a list of keys for the *node*\.

  - <a name='12'></a>*treeName* __keyexists__ *node* ?\-key *key*?

    Return true if the specified *key* exists for the *node*\. If no *key*
    is specified, the key __data__ is assumed\.

  - <a name='13'></a>*treeName* __index__ *node*

    Returns the index of *node* in its parent's list of children\. For example,
    if a node has *nodeFoo*, *nodeBar*, and *nodeBaz* as children, in that
    order, the index of *nodeBar* is 1\.

  - <a name='14'></a>*treeName* __insert__ *parent* *index* ?*child* ?*child* \.\.\.??

    Insert one or more nodes into the tree as children of the node *parent*\.
    The nodes will be added in the order they are given\. If *parent* is
    __root__, it refers to the root of the tree\. The new nodes will be added
    to the *parent* node's child list at the index given by *index*\. The
    *index* can be __end__ in which case the new nodes will be added after
    the current last child\.

    If any of the specified children already exist in *treeName*, those nodes
    will be moved from their original location to the new location indicated by
    this command\.

    If no *child* is specified, a single node will be added, and a name will
    be generated for the new node\. The generated name is of the form
    *node*__x__, where __x__ is a number\. If names are specified they
    must neither contain whitespace nor colons \(":"\)\.

    The return result from this command is a list of nodes added\.

  - <a name='15'></a>*treeName* __isleaf__ *node*

    Returns true if *node* is a leaf of the tree \(if *node* has no
    children\), false otherwise\.

  - <a name='16'></a>*treeName* __lappend__ *node* ?\-key *key*? *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *node*\. If no *key* is specified, the key __data__ is assumed\.

  - <a name='17'></a>*treeName* __move__ *parent* *index* *node* ?*node* \.\.\.?

    Make the specified nodes children of *parent*, inserting them into the
    parent's child list at the index given by *index*\. Note that the command
    will take all nodes out of the tree before inserting them under the new
    parent, and that it determines the position to place them into after the
    removal, before the re\-insertion\. This behaviour is important when it comes
    to moving one or more nodes to a different index without changing their
    parent node\.

  - <a name='18'></a>*treeName* __next__ *node*

    Return the right sibling of *node*, or the empty string if *node* was
    the last child of its parent\.

  - <a name='19'></a>*treeName* __numchildren__ *node*

    Return the number of immediate children of *node*\.

  - <a name='20'></a>*treeName* __parent__ *node*

    Return the parent of *node*\.

  - <a name='21'></a>*treeName* __previous__ *node*

    Return the left sibling of *node*, or the empty string if *node* was the
    first child of its parent\.

  - <a name='22'></a>*treeName* __set__ *node* ?__\-key__ *key*? ?*value*?

    Set or get one of the keyed values associated with a node\. If no key is
    specified, the key __data__ is assumed\. Each node that is added to a
    tree has the value "" assigned to the key __data__ automatically\. A node
    may have any number of keyed values associated with it\. If *value* is not
    specified, this command returns the current value assigned to the key; if
    *value* is specified, this command assigns that value to the key\.

  - <a name='23'></a>*treeName* __size__ ?*node*?

    Return a count of the number of descendants of the node *node*; if no node
    is specified, __root__ is assumed\.

  - <a name='24'></a>*treeName* __splice__ *parent* *from* ?*to*? ?*child*?

    Insert a node named *child* into the tree as a child of the node
    *parent*\. If *parent* is __root__, it refers to the root of the
    tree\. The new node will be added to the parent node's child list at the
    index given by *from*\. The children of *parent* which are in the range
    of the indices *from* and *to* are made children of *child*\. If the
    value of *to* is not specified it defaults to __end__\. If no name is
    given for *child*, a name will be generated for the new node\. The
    generated name is of the form *node*__x__, where __x__ is a
    number\. The return result from this command is the name of the new node\.

  - <a name='25'></a>*treeName* __swap__ *node1* *node2*

    Swap the position of *node1* and *node2* in the tree\.

  - <a name='26'></a>*treeName* __unset__ *node* ?__\-key__ *key*?

    Removes a keyed value from the node *node*\. If no key is specified, the
    key __data__ is assumed\.

  - <a name='27'></a>*treeName* __walk__ *node* ?__\-order__ *order*? ?__\-type__ *type*? __\-command__ *cmd*

    Perform a breadth\-first or depth\-first walk of the tree starting at the node
    *node*\. The type of walk, breadth\-first or depth\-first, is determined by
    the value of *type*; __bfs__ indicates breadth\-first, __dfs__
    indicates depth\-first\. Depth\-first is the default\. The order of the walk,
    pre\-, post\-, both\- or in\-order is determined by the value of *order*;
    __pre__ indicates pre\-order, __post__ indicates post\-order,
    __both__ indicates both\-order and __in__ indicates in\-order\.
    Pre\-order is the default\.

    Pre\-order walking means that a parent node is visited before any of its
    children\. For example, a breadth\-first search starting from the root will
    visit the root, followed by all of the root's children, followed by all of
    the root's grandchildren\. Post\-order walking means that a parent node is
    visited after any of its children\. Both\-order walking means that a parent
    node is visited before *and* after any of its children\. In\-order walking
    means that a parent node is visited after its first child and before the
    second\. This is a generalization of in\-order walking for binary trees and
    will do the right thing if a binary is walked\. The combination of a
    breadth\-first walk with in\-order is illegal\.

    As the walk progresses, the command *cmd* will be evaluated at each node\.
    Percent substitution will be performed on *cmd* before evaluation, just as
    in a __[bind](\.\./\.\./\.\./\.\./index\.md\#bind)__ script\. The following
    substitutions are recognized:

      * __%%__

        Insert the literal % character\.

      * __%t__

        Name of the tree object\.

      * __%n__

        Name of the current node\.

      * __%a__

        Name of the action occurring; one of __enter__, __leave__, or
        __visit__\. __enter__ actions occur during pre\-order walks;
        __leave__ actions occur during post\-order walks; __visit__
        actions occur during in\-order walks\. In a both\-order walk, the command
        will be evaluated twice for each node; the action is __enter__ for
        the first evaluation, and __leave__ for the second\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: tree* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
