
[//000000001]: # (struct::tree \- Tcl Data Structures)
[//000000002]: # (Generated from file 'struct\_tree\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2004,2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::tree\(n\) 2\.1\.1 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::tree \- Create and manipulate tree objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Tree CLASS API](#subsection1)

      - [Tree OBJECT API](#subsection2)

      - [Changes for 2\.0](#subsection3)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::tree ?2\.1\.1?  
package require struct::list ?1\.5?  

[__::struct::tree__ ?*treeName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?](#1)  
[__treeName__ __option__ ?*arg arg \.\.\.*?](#2)  
[__::struct::tree::prune__](#3)  
[*treeName* __=__ *sourcetree*](#4)  
[*treeName* __\-\->__ *desttree*](#5)  
[*treeName* __ancestors__ *node*](#6)  
[*treeName* __append__ *node* *key* *value*](#7)  
[*treeName* __attr__ *key*](#8)  
[*treeName* __attr__ *key* __\-nodes__ *list*](#9)  
[*treeName* __attr__ *key* __\-glob__ *globpattern*](#10)  
[*treeName* __attr__ *key* __\-regexp__ *repattern*](#11)  
[*treeName* __children__ ?__\-all__? *node* ?__filter__ *cmdprefix*?](#12)  
[*treeName* __cut__ *node*](#13)  
[*treeName* __delete__ *node* ?*node* \.\.\.?](#14)  
[*treeName* __depth__ *node*](#15)  
[*treeName* __descendants__ *node* ?__filter__ *cmdprefix*?](#16)  
[*treeName* __deserialize__ *serialization*](#17)  
[*treeName* __destroy__](#18)  
[*treeName* __exists__ *node*](#19)  
[*treeName* __get__ *node* *key*](#20)  
[*treeName* __getall__ *node* ?*pattern*?](#21)  
[*treeName* __keys__ *node* ?*pattern*?](#22)  
[*treeName* __keyexists__ *node* *key*](#23)  
[*treeName* __index__ *node*](#24)  
[*treeName* __insert__ *parent* *index* ?*child* ?*child* \.\.\.??](#25)  
[*treeName* __isleaf__ *node*](#26)  
[*treeName* __lappend__ *node* *key* *value*](#27)  
[*treeName* __leaves__](#28)  
[*treeName* __move__ *parent* *index* *node* ?*node* \.\.\.?](#29)  
[*treeName* __next__ *node*](#30)  
[*treeName* __numchildren__ *node*](#31)  
[*treeName* __nodes__](#32)  
[*treeName* __parent__ *node*](#33)  
[*treeName* __previous__ *node*](#34)  
[*treeName* __rename__ *node* *newname*](#35)  
[*treeName* __rootname__](#36)  
[*treeName* __serialize__ ?*node*?](#37)  
[*treeName* __set__ *node* *key* ?*value*?](#38)  
[*treeName* __size__ ?*node*?](#39)  
[*treeName* __splice__ *parent* *from* ?*to*? ?*child*?](#40)  
[*treeName* __swap__ *node1* *node2*](#41)  
[*treeName* __unset__ *node* *key*](#42)  
[*treeName* __walk__ *node* ?__\-order__ *order*? ?__\-type__ *type*? *loopvar* *script*](#43)  
[*treeName* __walkproc__ *node* ?__\-order__ *order*? ?__\-type__ *type*? *cmdprefix*](#44)  

# <a name='description'></a>DESCRIPTION

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

*Note:* The major version of the package
__[struct](\.\./\.\./\.\./\.\./index\.md\#struct)__ has been changed to version
2\.0, due to backward incompatible changes in the API of this module\. Please read
the section [Changes for 2\.0](#subsection3) for a full list of all changes,
incompatible and otherwise\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Tree CLASS API

The main commands of the package are:

  - <a name='1'></a>__::struct::tree__ ?*treeName*? ?__=__&#124;__:=__&#124;__as__&#124;__deserialize__ *source*?

    The command creates a new tree object with an associated global Tcl command
    whose name is *treeName*\. This command may be used to invoke various
    operations on the tree\. It has the following general form:

      * <a name='2'></a>__treeName__ __option__ ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

    If *treeName* is not specified a unique name will be generated by the
    package itself\. If a *source* is specified the new tree will be
    initialized to it\. For the operators __=__, __:=__, and __as__
    *source* is interpreted as the name of another tree object, and the
    assignment operator __=__ will be executed\. For __deserialize__ the
    *source* is a serialized tree object and __deserialize__ will be
    executed\.

    In other words

        ::struct::tree mytree = b

    is equivalent to

        ::struct::tree mytree
        mytree = b

    and

        ::struct::tree mytree deserialize $b

    is equivalent to

        ::struct::tree mytree
        mytree deserialize $b

  - <a name='3'></a>__::struct::tree::prune__

    This command is provided outside of the tree methods, as it is not a tree
    method per se\. It however interacts tightly with the method __walk__\.
    When used in the walk script it causes the traversal to ignore the children
    of the node we are currently at\. This command cannot be used with the
    traversal modes which look at children before their parent, i\.e\.
    __post__ and __in__\. The only applicable orders of traversal are
    __pre__ and __both__\. An error is thrown if the command and chosen
    order of traversal do not fit\.

## <a name='subsection2'></a>Tree OBJECT API

Two general observations beforehand:

  1. The root node of the tree can be used in most places where a node is asked
     for\. The default name of the rootnode is "root", but this can be changed
     with the method __rename__ \(see below\)\. Whatever the current name for
     the root node of the tree is, it can be retrieved by calling the method
     __rootname__\.

  1. The method __insert__ is the only way to create new nodes, and they are
     automatically added to a parent\. A tree object cannot have nodes without a
     parent, save the root node\.

And now the methods supported by tree objects created by this package:

  - <a name='4'></a>*treeName* __=__ *sourcetree*

    This is the assignment operator for tree objects\. It copies the tree
    contained in the tree object *sourcetree* over the tree data in
    *treeName*\. The old contents of *treeName* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *treeName* __deserialize__ \[*sourcetree* __serialize__\]

  - <a name='5'></a>*treeName* __\-\->__ *desttree*

    This is the reverse assignment operator for tree objects\. It copies the tree
    contained in the tree object *treeName* over the tree data in the object
    *desttree*\. The old contents of *desttree* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *desttree* __deserialize__ \[*treeName* __serialize__\]

  - <a name='6'></a>*treeName* __ancestors__ *node*

    This method extends the method __parent__ and returns a list containing
    all ancestor nodes to the specified *node*\. The immediate ancestor, in
    other words, parent node, is the first element in that list, its parent the
    second element, and so on until the root node is reached, making it the last
    element of the returned list\.

  - <a name='7'></a>*treeName* __append__ *node* *key* *value*

    Appends a *value* to one of the keyed values associated with an node\.
    Returns the new value given to the attribute *key*\.

  - <a name='8'></a>*treeName* __attr__ *key*

  - <a name='9'></a>*treeName* __attr__ *key* __\-nodes__ *list*

  - <a name='10'></a>*treeName* __attr__ *key* __\-glob__ *globpattern*

  - <a name='11'></a>*treeName* __attr__ *key* __\-regexp__ *repattern*

    This method retrieves the value of the attribute named *key*, for all
    nodes in the tree \(matching the restriction specified via one of the
    possible options\) and having the specified attribute\.

    The result is a dictionary mapping from node names to the value of attribute
    *key* at that node\. Nodes not having the attribute *key*, or not passing
    a specified restriction, are not listed in the result\.

    The possible restrictions are:

      * __\-nodes__

        The value is a list of nodes\. Only the nodes mentioned in this list are
        searched for the attribute\.

      * __\-glob__

        The value is a glob pattern\. Only the nodes in the tree whose names
        match this pattern are searched for the attribute\.

      * __\-regexp__

        The value is a regular expression\. Only the nodes in the tree whose
        names match this pattern are searched for the attribute\.

  - <a name='12'></a>*treeName* __children__ ?__\-all__? *node* ?__filter__ *cmdprefix*?

    Return a list of the children of *node*\. If the option __\-all__ is
    specified, then not only the direct children, but their children, and so on
    are returned in the result\. If a filter command is specified only those
    nodes are listed in the final result which pass the test\. The command in
    *cmdprefix* is called with two arguments, the name of the tree object, and
    the name of the node in question\. It is executed in the context of the
    caller and has to return a boolean value\. Nodes for which the command
    returns __false__ are removed from the result list before it is returned
    to the caller\.

    Some examples:

            mytree insert root end 0 ; mytree set 0 volume 30
            mytree insert root end 1
            mytree insert root end 2
            mytree insert 0    end 3
            mytree insert 0    end 4
            mytree insert 4    end 5 ; mytree set 5 volume 50
            mytree insert 4    end 6

            proc vol {t n} {
        	$t keyexists $n volume
            }
            proc vgt40 {t n} {
        	if {![$t keyexists $n volume]} {return 0}
        	expr {[$t get $n volume] > 40}
            }

            tclsh> lsort [mytree children -all root filter vol]
            0 5

            tclsh> lsort [mytree children -all root filter vgt40]
            5

            tclsh> lsort [mytree children root filter vol]
            0

            tclsh> puts ([lsort [mytree children root filter vgt40]])
            ()

  - <a name='13'></a>*treeName* __cut__ *node*

    Removes the node specified by *node* from the tree, but not its children\.
    The children of *node* are made children of the parent of the *node*, at
    the index at which *node* was located\.

  - <a name='14'></a>*treeName* __delete__ *node* ?*node* \.\.\.?

    Removes the specified nodes from the tree\. All of the nodes' children will
    be removed as well to prevent orphaned nodes\.

  - <a name='15'></a>*treeName* __depth__ *node*

    Return the number of steps from node *node* to the root node\.

  - <a name='16'></a>*treeName* __descendants__ *node* ?__filter__ *cmdprefix*?

    This method extends the method __children__ and returns a list
    containing all nodes descending from *node*, and passing the filter, if
    such was specified\.

    This is actually the same as "*treeName* __children__ __\-all__"\.
    __descendants__ should be prefered, and "children \-all" will be
    deprecated sometime in the future\.

  - <a name='17'></a>*treeName* __deserialize__ *serialization*

    This is the complement to __serialize__\. It replaces tree data in
    *treeName* with the tree described by the *serialization* value\. The old
    contents of *treeName* are deleted by this operation\.

  - <a name='18'></a>*treeName* __destroy__

    Destroy the tree, including its storage space and associated command\.

  - <a name='19'></a>*treeName* __exists__ *node*

    Returns true if the specified node exists in the tree\.

  - <a name='20'></a>*treeName* __get__ *node* *key*

    Returns the value associated with the key *key* for the node *node*\.

  - <a name='21'></a>*treeName* __getall__ *node* ?*pattern*?

    Returns a dictionary \(suitable for use with \[__array set__\]\) containing
    the attribute data for the *node*\. If the glob *pattern* is specified
    only the attributes whose names match the pattern will be part of the
    dictionary\.

  - <a name='22'></a>*treeName* __keys__ *node* ?*pattern*?

    Returns a list of keys for the *node*\. If the *pattern* is specified
    only the attributes whose names match the pattern will be part of the
    returned list\. The pattern is a __glob__ pattern\.

  - <a name='23'></a>*treeName* __keyexists__ *node* *key*

    Return true if the specified *key* exists for the *node*\.

  - <a name='24'></a>*treeName* __index__ *node*

    Returns the index of *node* in its parent's list of children\. For example,
    if a node has *nodeFoo*, *nodeBar*, and *nodeBaz* as children, in that
    order, the index of *nodeBar* is 1\.

  - <a name='25'></a>*treeName* __insert__ *parent* *index* ?*child* ?*child* \.\.\.??

    Insert one or more nodes into the tree as children of the node *parent*\.
    The nodes will be added in the order they are given\. If *parent* is
    __root__, it refers to the root of the tree\. The new nodes will be added
    to the *parent* node's child list at the index given by *index*\. The
    *index* can be __end__ in which case the new nodes will be added after
    the current last child\. Indices of the form "end\-__n__" are accepted as
    well\.

    If any of the specified children already exist in *treeName*, those nodes
    will be moved from their original location to the new location indicated by
    this command\.

    If no *child* is specified, a single node will be added, and a name will
    be generated for the new node\. The generated name is of the form
    *node*__x__, where __x__ is a number\. If names are specified they
    must neither contain whitespace nor colons \(":"\)\.

    The return result from this command is a list of nodes added\.

  - <a name='26'></a>*treeName* __isleaf__ *node*

    Returns true if *node* is a leaf of the tree \(if *node* has no
    children\), false otherwise\.

  - <a name='27'></a>*treeName* __lappend__ *node* *key* *value*

    Appends a *value* \(as a list\) to one of the keyed values associated with
    an *node*\. Returns the new value given to the attribute *key*\.

  - <a name='28'></a>*treeName* __leaves__

    Return a list containing all leaf nodes known to the tree\.

  - <a name='29'></a>*treeName* __move__ *parent* *index* *node* ?*node* \.\.\.?

    Make the specified nodes children of *parent*, inserting them into the
    parent's child list at the index given by *index*\. Note that the command
    will take all nodes out of the tree before inserting them under the new
    parent, and that it determines the position to place them into after the
    removal, before the re\-insertion\. This behaviour is important when it comes
    to moving one or more nodes to a different index without changing their
    parent node\.

  - <a name='30'></a>*treeName* __next__ *node*

    Return the right sibling of *node*, or the empty string if *node* was
    the last child of its parent\.

  - <a name='31'></a>*treeName* __numchildren__ *node*

    Return the number of immediate children of *node*\.

  - <a name='32'></a>*treeName* __nodes__

    Return a list containing all nodes known to the tree\.

  - <a name='33'></a>*treeName* __parent__ *node*

    Return the parent of *node*\.

  - <a name='34'></a>*treeName* __previous__ *node*

    Return the left sibling of *node*, or the empty string if *node* was the
    first child of its parent\.

  - <a name='35'></a>*treeName* __rename__ *node* *newname*

    Renames the node *node* to *newname*\. An error is thrown if either the
    node does not exist, or a node with name *newname* does exist\. The result
    of the command is the new name of the node\.

  - <a name='36'></a>*treeName* __rootname__

    Returns the name of the root node of the tree\.

  - <a name='37'></a>*treeName* __serialize__ ?*node*?

    This method serializes the sub\-tree starting at *node*\. In other words it
    returns a tcl *value* completely describing the tree starting at *node*\.
    This allows, for example, the transfer of tree objects \(or parts thereof\)
    over arbitrary channels, persistence, etc\. This method is also the basis for
    both the copy constructor and the assignment operator\.

    The result of this method has to be semantically identical over all
    implementations of the tree interface\. This is what will enable us to copy
    tree data between different implementations of the same interface\.

    The result is a list containing containing a multiple of three elements\. It
    is like a serialized array except that there are two values following each
    key\. They are the names of the nodes in the serialized tree\. The two values
    are a reference to the parent node and the attribute data, in this order\.

    The reference to the parent node is the empty string for the root node of
    the tree\. For all other nodes it is the index of the parent node in the
    list\. This means that they are integers, greater than or equal to zero, less
    than the length of the list, and multiples of three\. The order of the nodes
    in the list is important insofar as it is used to reconstruct the lists of
    children for each node\. The children of a node have to be listed in the
    serialization in the same order as they are listed in their parent in the
    tree\.

    The attribute data of a node is a dictionary, i\.e\. a list of even length
    containing a serialized array\. For a node without attribute data the
    dictionary is the empty list\.

    *Note:* While the current implementation returns the root node as the
    first element of the list, followed by its children and their children in a
    depth\-first traversal this is not necessarily true for other
    implementations\. The only information a reader of the serialized data can
    rely on for the structure of the tree is that the root node is signaled by
    the empty string for the parent reference, that all other nodes refer to
    their parent through the index in the list, and that children occur in the
    same order as in their parent\.

        A possible serialization for the tree structure

                    +- d
              +- a -+
        root -+- b  +- e
              +- c
        is

        {root {} {} a 0 {} d 3 {} e 3 {} b 0 {} c 0 {}}

        The above assumes that none of the nodes have attributes.

  - <a name='38'></a>*treeName* __set__ *node* *key* ?*value*?

    Set or get one of the keyed values associated with a node\. A node may have
    any number of keyed values associated with it\. If *value* is not
    specified, this command returns the current value assigned to the key; if
    *value* is specified, this command assigns that value to the key, and
    returns it\.

  - <a name='39'></a>*treeName* __size__ ?*node*?

    Return a count of the number of descendants of the node *node*; if no node
    is specified, __root__ is assumed\.

  - <a name='40'></a>*treeName* __splice__ *parent* *from* ?*to*? ?*child*?

    Insert a node named *child* into the tree as a child of the node
    *parent*\. If *parent* is __root__, it refers to the root of the
    tree\. The new node will be added to the parent node's child list at the
    index given by *from*\. The children of *parent* which are in the range
    of the indices *from* and *to* are made children of *child*\. If the
    value of *to* is not specified it defaults to __end__\. If no name is
    given for *child*, a name will be generated for the new node\. The
    generated name is of the form *node*__x__, where __x__ is a
    number\. The return result from this command is the name of the new node\.

    The arguments *from* and *to* are regular list indices, i\.e\. the form
    "end\-__n__" is accepted as well\.

  - <a name='41'></a>*treeName* __swap__ *node1* *node2*

    Swap the position of *node1* and *node2* in the tree\.

  - <a name='42'></a>*treeName* __unset__ *node* *key*

    Removes a keyed value from the node *node*\. The method will do nothing if
    the *key* does not exist\.

  - <a name='43'></a>*treeName* __walk__ *node* ?__\-order__ *order*? ?__\-type__ *type*? *loopvar* *script*

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
    will do the right thing if a binary tree is walked\. The combination of a
    breadth\-first walk with in\-order is illegal\.

    As the walk progresses, the *script* will be evaluated at each node\. The
    evaluation takes place in the context of the caller of the method\. Regarding
    loop variables, these are listed in *loopvar*\. If one only one variable is
    specified it will be set to the id of the node\. When two variables are
    specified, i\.e\. *loopvar* is a true list, then the first variable will be
    set to the action performed at the node, and the other to the id of the node
    itself\. All loop variables are created in the context of the caller\.

    There are three possible actions: __enter__, __leave__, or
    __visit__\. __enter__ actions occur during pre\-order walks;
    __leave__ actions occur during post\-order walks; __visit__ actions
    occur during in\-order walks\. In a both\-order walk, the command will be
    evaluated twice for each node; the action is __enter__ for the first
    evaluation, and __leave__ for the second\.

    *Note*: The __enter__ action for a node is always performed before the
    walker will look at the children of that node\. This means that changes made
    by the *script* to the children of the node will immediately influence the
    walker and the steps it will take\.

    Any other manipulation, for example of nodes higher in the tree \(i\.e already
    visited\), or upon leaving will have undefined results\. They may succeed,
    error out, silently compute the wrong result, or anything in between\.

    At last a small table showing the relationship between the various options
    and the possible actions\.

        order       type    actions         notes
        -----       ----    -----           -----
        pre         dfs     enter           parent before children
        post        dfs     leave           parent after children
        in          dfs     visit           parent between first and second child.
        both        dfs     enter, leave    parent before and after children
        -----       ----    -----           -----
        pre         bfs     enter           parent before children
        post        bfs     leave           parent after children
        in          bfs             -- illegal --
        both        bfs     enter, leave    parent before and after children
        -----       ----    -----           -----

    Note the command __::struct::tree::prune__\. This command can be used in
    the walk script to force the command to ignore the children of the node we
    are currently at\. It will throw an error if the order of traversal is either
    __post__ or __in__ as these modes visit the children before their
    parent, making pruning non\-sensical\.

  - <a name='44'></a>*treeName* __walkproc__ *node* ?__\-order__ *order*? ?__\-type__ *type*? *cmdprefix*

    This method is like method __walk__ in all essentials, except the
    interface to the user code\. This method invokes a command prefix with three
    additional arguments \(tree, node, and action\), instead of evaluating a
    script and passing the node via a loop variable\.

## <a name='subsection3'></a>Changes for 2\.0

The following noteworthy changes have occurred:

  1. The API for accessing attributes and their values has been simplified\.

     All functionality regarding the default attribute "data" has been removed\.
     This default attribute does not exist anymore\. All accesses to attributes
     have to specify the name of the attribute in question\. This backward
     *incompatible* change allowed us to simplify the signature of all methods
     handling attributes\.

     Especially the flag __\-key__ is not required anymore, even more, its
     use is now forbidden\. Please read the documentation for the methods
     __set__, __get__, __getall__, __unset__, __append__,
     __lappend__, __keyexists__ and __keys__ for a description of
     the new API's\.

  1. The methods __keys__ and __getall__ now take an optional pattern
     argument and will return only attribute data for keys matching this
     pattern\.

  1. Nodes can now be renamed\. See the documentation for the method
     __rename__\.

  1. The structure has been extended with API's for the serialization and
     deserialization of tree objects, and a number of operations based on them
     \(tree assignment, copy construction\)\.

     Please read the documentation for the methods __serialize__,
     __deserialize__, __=__, and __\-\->__, and the documentation on
     the construction of tree objects\.

     Beyond the copying of whole tree objects these new API's also enable the
     transfer of tree objects over arbitrary channels and for easy persistence\.

  1. The walker API has been streamlined and made more similar to the command
     __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__\. In detail:

       - The superfluous option __\-command__ has been removed\.

       - Ditto for the place holders\. Instead of the placeholders two loop
         variables have to be specified to contain node and action information\.

       - The old command argument has been documented as a script now, which it
         was in the past too\.

       - The fact that __enter__ actions are called before the walker looks
         at the children of a node has been documented now\. In other words it is
         now officially allowed to manipulate the list of children for a node
         under *these* circumstances\. It has been made clear that changes
         under any other circumstances will have undefined results, from
         silently computing the wrong result to erroring out\.

  1. A new method, __attr__, was added allowing the query and retrieval of
     attribute data without regard to the node relationship\.

  1. The method __children__ has been extended with the ability to select
     from the children of the node based on an arbitrary filtering criterium\.
     Another extension is the ability to look not only at the immediate children
     of the node, but the whole tree below it\.

# <a name='section3'></a>EXAMPLES

The following example demonstrates the creation of new nodes:

    mytree insert root end 0   ; # Create node 0, as child of the root
    mytree insert root end 1 2 ; # Ditto nodes 1 & 2
    mytree insert 0    end 3   ; # Now create node 3 as child of node 0
    mytree insert 0    end     ; # Create another child of 0, with a
    #                              generated name. The name is returned
    #                              as the result of the command.

# <a name='section4'></a>Bugs, Ideas, Feedback

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

[breadth\-first](\.\./\.\./\.\./\.\./index\.md\#breadth\_first),
[depth\-first](\.\./\.\./\.\./\.\./index\.md\#depth\_first),
[in\-order](\.\./\.\./\.\./\.\./index\.md\#in\_order),
[node](\.\./\.\./\.\./\.\./index\.md\#node),
[post\-order](\.\./\.\./\.\./\.\./index\.md\#post\_order),
[pre\-order](\.\./\.\./\.\./\.\./index\.md\#pre\_order),
[serialization](\.\./\.\./\.\./\.\./index\.md\#serialization),
[tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2004,2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
