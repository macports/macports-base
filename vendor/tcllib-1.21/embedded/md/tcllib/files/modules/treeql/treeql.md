
[//000000001]: # (treeql \- Tree Query Language)
[//000000002]: # (Generated from file 'treeql\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Colin McCormack <coldstore@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (treeql\(n\) 1\.3\.1 tcllib "Tree Query Language")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

treeql \- Query tree objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [TreeQL CLASS API](#subsection1)

      - [TreeQL OBJECT API](#subsection2)

  - [The Tree Query Language](#section3)

      - [TreeQL Concepts](#subsection3)

      - [Structural generators](#subsection4)

      - [Attribute Filters](#subsection5)

      - [Attribute Mutators](#subsection6)

      - [Attribute String Accessors](#subsection7)

      - [Sub\-queries](#subsection8)

      - [Node Set Operators](#subsection9)

      - [Node Set Iterators](#subsection10)

      - [Typed node support](#subsection11)

  - [Examples](#section4)

  - [References](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require snit  
package require struct::list  
package require struct::set  
package require treeql ?1\.3\.1?  

[__treeql__ *objectname* __\-tree__ *tree* ?__\-query__ *query*? ?__\-nodes__ *nodes*? ?*args*\.\.\.?](#1)  
[*qo* __query__ *args*\.\.\.](#2)  
[*qo* __result__](#3)  
[*qo* __discard__](#4)  

# <a name='description'></a>DESCRIPTION

This package provides objects which can be used to query and transform tree
objects following the API of tree objects created by the package
__[struct::tree](\.\./struct/struct\_tree\.md)__\.

The tree query and manipulation language used here, TreeQL, is inspired by Cost
\(See section [References](#section5) for more information\)\.

__treeql__, the package, is a fairly thin query facility over
tree\-structured data types\. It implements an ordered set of nodes \(really a
list\) which are generated and filtered through the application of TreeQL
operators to each node in turn\.

# <a name='section2'></a>API

## <a name='subsection1'></a>TreeQL CLASS API

The command __treeql__ is a __[snit](\.\./snit/snit\.md)__::type which
implements the Treeql Query Language\. This means that it follows the API for
class commands as specified by the package __[snit](\.\./snit/snit\.md)__\.
Its general syntax is

  - <a name='1'></a>__treeql__ *objectname* __\-tree__ *tree* ?__\-query__ *query*? ?__\-nodes__ *nodes*? ?*args*\.\.\.?

    The command creates a new tree query object and returns the fully qualified
    name of the object command as its result\. The API the returned command is
    following is described in the section [TreeQL OBJECT API](#subsection2)

    Each query object is associated with a single *tree* object\. This is the
    object all queries will be run against\.

    If the option __\-nodes__ was specified then its argument is treated as a
    list of nodes\. This list is used to initialize the node set\. It defaults to
    the empty list\.

    If the option __\-query__ was specified then its argument will be
    interpreted as an object, the *parent query* of this query\. It defaults to
    the object itself\. All queries will be interpreted in the environment of
    this object\.

    Any arguments coming after the options are treated as a query and run
    immediately, after the *node set* has been initialized\. This uses the same
    syntax for the query as the method __query__\.

    The operations of the TreeQL available for this are explained in the section
    about [The Tree Query Language](#section3)\. This section also explains
    the term *node set* used above\.

## <a name='subsection2'></a>TreeQL OBJECT API

As __treeql__ has been implemented in __[snit](\.\./snit/snit\.md)__
all the standard methods of __[snit](\.\./snit/snit\.md)__\-based classes
are available to the user and therefore not listed here\. Please read the
documentation for __[snit](\.\./snit/snit\.md)__ for what they are and what
functionality they provide

The methods provided by the package __treeql__ itself are listed and
explained below\.

  - <a name='2'></a>*qo* __query__ *args*\.\.\.

    This method interprets its arguments as a series of TreeQL operators and
    interpretes them from the left to right \(i\.e\. first to last\)\. Note that the
    first operator uses the *node set* currently known to the object to
    perform its actions\. In other words, the *node set* is *not* cleared, or
    modified in other ways, before the query is run\. This allows the user to run
    several queries one after the other and have each use the results of the
    last\. Any initialization has to be done by any query itself, using TreeQL
    operators\. The result of the method is the *node set* after the last
    operator of the query has been executed\.

    *Note* that uncaught errors will leave the *node set* of the object in
    an intermediate state, per the TreeQL operators which were executed
    successfully before the error occurred\.

    The above means in detail that:

      1. The first argument is interpreted as the name of a query operator, the
         number of arguments required by that operator is then determined, and
         taken from the immediately following arguments\.

         Because of this operators cannot have optional arguments, all arguments
         have to be present as defined\. Failure to do this will, at least,
         confuse the query interpreter, but more likely cause errors\.

      1. The operator is applied to the current node set, yielding a new node
         set, and/or manipulating the tree object the query object is connected
         to\.

      1. The arguments used \(i\.e\. operator name and arguments\) are removed from
         the list of method arguments, and then the whole process is repeated
         from step \[1\], until the list of arguments is empty or an error
         occurred\.

            # q is the query object.

            q query root children get data

            # The above query
            # - Resets the node set to the root node - root
            # - Adds the children of root to the set - children
            # - Replaces the node set with the       - get data
            #   values for the attribute 'data',
            #   for all nodes in the set which
            #   have such an attribute.
            # - And returns this information.

            # Below we can see the same query, but rewritten
            # to show the structure as it is seen by the query
            # interpreter.

            q query \
        	    root \
        	    children \
        	    get data

    The operators of the TreeQL language available for this are explained in the
    section about [The Tree Query Language](#section3)\. This section also
    explains the term *node set* used above\.

  - <a name='3'></a>*qo* __result__

    This method returns a list containing the current node set\.

  - <a name='4'></a>*qo* __discard__

    This method returns the current node set \(like method __result__\), but
    also destroys the query object \(*qo*\)\. This is useful when constructing
    and using sub\-queries \(%AUTO% objects immediately destroyed after use\)\.

# <a name='section3'></a>The Tree Query Language

This and the following sections specify the Tree Query Language used by the
query objects of this package in detail\.

First we explain the general concepts underneath the language which are required
to comprehend it\. This is followed by the specifications for all the available
query operators\. They fall into eight categories, and each category has its own
section\.

  1. [TreeQL Concepts](#subsection3)

  1. [Structural generators](#subsection4)

  1. [Attribute Filters](#subsection5)

  1. [Attribute Mutators](#subsection6)

  1. [Attribute String Accessors](#subsection7)

  1. [Sub\-queries](#subsection8)

  1. [Node Set Operators](#subsection9)

  1. [Node Set Iterators](#subsection10)

  1. [Typed node support](#subsection11)

## <a name='subsection3'></a>TreeQL Concepts

The main concept which has to be understood is that of the *node set*\. Each
query object maintains exactly one such *node set*, and essentially all
operators use it and input argument and for their result\. This structure simply
contains the handles of all nodes which are currently of interest to the query
object\. To name it a *[set](\.\./\.\./\.\./\.\./index\.md\#set)* is a bit of a
misnomer, because

  1. A node \(handle\) can occur in the structure more than once, and

  1. the order of nodes in the structure is important as well\. Whenever an
     operator processes all nodes in the node set it will do so in the order
     they occur in the structure\.

Regarding the possible multiple occurrence of a node, consider a node set
containing two nodes A and B, both having node P as their immediate parent\.
Application of the TreeQL operator "parent" will then add P to the new node set
twice, once per node it was parent of\. I\.e\. the new node set will then be \{P P\}\.

## <a name='subsection4'></a>Structural generators

All tree\-structural operators locate nodes in the tree based on a structural
relation ship to the nodes currently in the set and then replace the current
node set with the set of nodes found Nodes which fulfill such a relationship
multiple times are added to the result as often as they fulfill the
relationship\.

It is important to note that the found nodes are collected in a separate storage
area while processing the node set, and are added to \(or replacing\) the current
node set only after the current node set has been processed completely\. In other
words, the new nodes are *not* processed by the operator as well and do not
affect the iteration\.

When describing an operator the variable __N__ will be used to refer to any
node in the node set\.

  - __ancestors__

    Replaces the current node set with the ancestors for all nodes __N__ in
    the node set, should __N__ have a parent\. In other words, nodes without
    a parent do not contribute to the new node set\. In other words, uses all
    nodes on the path from node __N__ to root, in this order \(root last\),
    for all nodes __N__ in the node set\. This includes the root, but not the
    node itself\.

  - __rootpath__

    Replaces the current node set with the ancestors for all nodes __N__ in
    the node set, should __N__ have a parent\. In other words, nodes without
    a parent do not contribute to the new node set\. In contrast to the operator
    __ancestors__ the nodes are added in reverse order however, i\.e\. the
    root node first\.

  - __parent__

    Replaces the current node set with the parent of node __N__, for all
    nodes __N__ in the node set, should __N__ have a parent\. In other
    words, nodes without a parent do not contribute to the new node set\.

  - __children__

    Replaces the current node set with the immediate children of node __N__,
    for all nodes __N__ in the node set, should __N__ have children\. In
    other words, nodes without children do not contribute to the new node set\.

  - __left__

    Replaces the current node set with the previous/left sibling for all nodes
    __N__ in the node set, should __N__ have siblings to the left\. In
    other words, nodes without left siblings do not contribute to the new node
    set\.

  - __right__

    Replaces the current node set with the next/right sibling for all nodes
    __N__ in the node set, should __N__ have siblings to the right\. In
    other words, nodes without right siblings do not contribute to the new node
    set\.

  - __prev__

    Replaces the current node set with all previous/left siblings of node
    __N__, for all nodes __N__ in the node set, should __N__ have
    siblings to the left\. In other words, nodes without left siblings are
    ignored\. The left sibling adjacent to the node is added first, and the
    leftmost sibling last \(reverse tree order\)\.

  - __esib__

    Replaces the current node set with all previous/left siblings of node
    __N__, for all nodes __N__ in the node set, should __N__ have
    siblings to the left\. In other words, nodes without left siblings are
    ignored\. The leftmost sibling is added first, and the left sibling adjacent
    to the node last \(tree order\)\.

    The method name is a shorthand for *Earlier SIBling*\.

  - __next__

    Replaces the current node set with all next/right siblings of node
    __N__, for all nodes __N__ in the node set, should __N__ have
    siblings to the right\. In other words, nodes without right siblings do not
    contribute to the new node set\. The right sibling adjacent to the node is
    added first, and the rightmost sibling last \(tree order\)\.

  - __root__

    Replaces the current node set with a node set containing a single node, the
    root of the tree\.

  - __tree__

    Replaces the current node set with a node set containing all nodes found in
    the tree\. The nodes are added in pre\-order \(parent first, then children, the
    latter from left to right, first to last\)\.

  - __descendants__

    Replaces the current node set with the nodes in all subtrees rooted at node
    __N__, for all nodes __N__ in the node set, should __N__ have
    children\. In other words, nodes without children do not contribute to the
    new node set\.

    This is like the operator __children__, but covers the children of
    children as well, i\.e\. all the *proper descendants*\. "Rooted at __N__"
    means that __N__ itself is not added to the new set, which is also
    implied by *proper descendants*\.

  - __subtree__

    Like operator __descendants__, but includes the node __N__\. In other
    words:

    Replaces the current node set with the nodes of the subtree of node
    __N__, for all nodes __N__ in the node set, should __N__ have
    children\. In other words, nodes without children do not contribute to the
    new node set\. I\.e this is like the operator __children__, but covers the
    children of children, etc\. as well\. "Of __N__" means that __N__
    itself is added to the new set\.

  - __forward__

    Replaces the current node set with the nodes in the subtrees rooted at the
    right siblings of node __N__, for all nodes __N__ in the node set,
    should __N__ have right siblings, and they children\. In other words,
    nodes without right siblings, and them without children are ignored\.

    This is equivalent to the operator sequence

        next descendants

  - __later__

    This is an alias for the operator __forward__\.

  - __backward__

    Replaces the current node set with the nodes in the flattened previous
    subtrees, in reverse tree order\.

    This is nearly equivalent to the operator sequence

        prev descendants

    The only difference is that this uses the nodes in reverse order\.

  - __earlier__

    Replaces the current node set with the nodes in the flattened previous
    subtrees, in tree order\.

    This is equivalent to the operator sequence

        prev subtree

## <a name='subsection5'></a>Attribute Filters

These operators filter the node set by reference to attributes of nodes and
their properties\. Filter means that all nodes not fulfilling the criteria are
removed from the node set\. In other words, the node set is replaced by the set
of nodes fulfilling the filter criteria\.

  - __hasatt__ *attr*

    Reduces the node set to nodes which have an attribute named *attr*\.

  - __withatt__ *attr* *value*

    Reduces the node set to nodes which have an attribute named *attr*, and
    where the value of that attribute is equal to *value* \(The "==" operator
    is __string equal \-nocase__\)\.

  - __withatt\!__ *attr* *val*

    This is the same as __withatt__, but all nodes in the node set have to
    have the attribute, and the "==" operator is __string equal__, i\.e\. no
    __\-nocase__\. The operator will fail with an error if they don't have the
    attribute\.

  - __attof__ *attr* *vals*

    Reduces the node set to nodes which which have an attribute named *attr*
    and where the value of that attribute is contained in the list *vals* of
    legal values\. The contained\-in operator used here does glob matching \(using
    the attribute value as pattern\) and ignores the case of the attribute value,
    *but not* for the elements of *vals*\.

  - __attmatch__ *attr* *match*

    Same as __withatt__, but __string match__ is used as the "=="
    operator, and *match* is the pattern checked for\.

    *Note* that *match* is a interpreted as a partial argument *list* for
    __string match__\. This means that it is interpreted as a list containing
    the pattern, and the pattern element can be preceded by options understand
    by __string match__, like __\-nocase__\. This is especially important
    should the pattern contain spaces\. It has to be wrapped into a list for
    correct interpretation by this operator

## <a name='subsection6'></a>Attribute Mutators

These operators change node attributes within the underlying tree\. In other
words, all these operators have *side effects*\.

  - __set__ *attr* *val*

    Sets the attribute *attr* to the value *val*, for all nodes __N__ in
    the node set\. The operator will fail if a node does not have an attribute
    named *attr*\. The tree will be left in a partially modified state\.

  - __unset__ *attr*

    Unsets the attribute *attr*, for all nodes __N__ in the node set\. The
    operator will fail if a node does not have an attribute named *attr*\. The
    tree will be left in a partially modified state\.

## <a name='subsection7'></a>Attribute String Accessors

These operators retrieve the values of node attributes from the underlying tree\.
The collected results are stored in the node set, but are not actually nodes\.

In other words, they redefine the semantics of the node set stored by the query
object to contain non\-node data after their completion\.

The query interpreter will terminate after it has finished processing one of
these operators, silently discarding any later query elements\. It also means
that our talk about maintenance of a node set is not quite true\. It is a node
set while the interpreter is processing commands, but can be left as an
attribute value set at the end of query processing\.

  - __string__ *op* *attr*

    Applies the string operator *op* to the attribute named *attr*, for all
    nodes __N__ in the node set, collects the results of that application
    and places them into the node set\.

    The operator will fail if a node does not have an attribute named *attr*\.

    The argument *op* is interpreted as partial argument list for the builtin
    command __[string](\.\./\.\./\.\./\.\./index\.md\#string)__\. Its first word
    has to be any of the sub\-commands understood by
    __[string](\.\./\.\./\.\./\.\./index\.md\#string)__\. This has to be followed
    by all arguments required for the subcommand, except the last\. that last
    argument is supplied by the attribute value\.

  - __get__ *pattern*

    For all nodes __N__ in the node set it determines all their attributes
    with names matching the glob *pattern*, then the values of these
    attributes, at last it replaces the node set with the list of these
    attribute values\.

  - __attlist__

    This is a convenience definition for the operator __getvals \*__\. In
    other words, it replaces the node set with a list of the attribute values
    for all attributes for all nodes __N__ in the node set\.

  - __attrs__ *glob*

    Replaces the current node set with a list of attribute lists, one attribute
    list per for all nodes __N__ in the node set\.

  - __attval__ *attname*

    Reduces the current node set with the operator __hasatt__, and then
    replaces it with a list containing the values of the attribute named
    *attname* for all nodes __N__ in the node set\.

## <a name='subsection8'></a>Sub\-queries

Sub\-queries yield node sets which are then used to augment, reduce or replace
the current node set\.

  - __andq__ *query*

    Replaces the node set with the set\-intersection of the node set generated by
    the sub\-query *query* and itself\.

    The execution of the sub\-query uses the current node set as its own initial
    node set\.

  - __orq__ *query*

    Replaces the node set with the set\-union of the node set generated by the
    sub\-query *query* and itself\. Duplicate nodes are removed\.

    The execution of the sub\-query uses the current node set as its own initial
    node set\.

  - __notq__ *query*

    Replaces the node set with the set of nodes generated by the sub\-query
    *query* which are also not in the current node set\. In other word the set
    difference of itself and the node set generated by the sub\-query\.

    The execution of the sub\-query uses the current node set as its own initial
    node set\.

## <a name='subsection9'></a>Node Set Operators

These operators change the node set directly, without referring to the tree\.

  - __unique__

    Removes duplicate nodes from the node set, preserving order\. In other words,
    the earliest occurrence of a node handle is preserved, every other
    occurrence is removed\.

  - __select__

    Replaces the current node set with a node set containing only the first node
    from the current node set

  - __transform__ *query* *var* *body*

    First it interprets the sub\-query *query*, using the current node set as
    its initial node set\. Then it iterates over the result of that query,
    binding the handle of each node to the variable named in *var*, and
    executing the script *body*\. The collected results of these executions is
    made the new node set, replacing the current one\.

    The script *body* is executed in the context of the caller\.

  - __map__ *var* *body*

    Iterates over the current node set, binding the handle of each node to the
    variable named in *var*, and executing the script *body*\. The collected
    results of these executions is made the new node set, replacing the current
    one\.

    The script *body* is executed in the context of the caller\.

  - __quote__ *val*

    Appends the literal value *val* to the current node set\.

  - __replace__ *val*

    Replaces the current node set with the literal list value *val*\.

## <a name='subsection10'></a>Node Set Iterators

  - __foreach__ *query* *var* *body*

    Interprets the sub\-query *query*, then performs the equivalent of operator
    __over__ on the nodes in the node set created by that query\. The current
    node set is not changed, except through side effects from the script
    *body*\.

    The script *body* is executed in the context of the caller\.

  - __with__ *query* *body*

    Interprets the *query*, then runs the script *body* on the node set
    generated by the query\. At last it restores the current node set as it was
    before the execution of the query\.

    The script *body* is executed in the context of the caller\.

  - __over__ *var* *body*

    Executes the script *body* for each node in the node set, with the
    variable named by *var* bound to the name of the current node\. The script
    *body* is executed in the context of the caller\.

    This is like the builtin
    __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__, with the node set as
    the source of the list to iterate over\.

    The results of executing the *body* are ignored\.

  - __delete__

    Deletes all the nodes contained in the current node set from the tree\.

## <a name='subsection11'></a>Typed node support

These filters and accessors assume the existence of an attribute called
__@type__, and are short\-hand forms useful for cost\-like tree query, html
tree editing, and so on\.

  - __nodetype__

    Returns the node type of nodes\. Attribute string accessor\. This is
    equivalent to

        get @type

  - __oftype__ *t*

    Reduces the node set to nodes whose type is equal to *t*, with letter case
    ignored\.

  - __nottype__ *t*

    Reduces the node set to nodes whose type is not equal to *t*, with letter
    case ignored\.

  - __oftypes__ *attrs*

    Reduces set to nodes whose @type is an element in the list *attrs* of
    types\. The value of @type is used as a glob pattern, and letter case is
    relevant\.

# <a name='section4'></a>Examples

\.\.\. TODO \.\.\.

# <a name='section5'></a>References

  1. [COST](http://wiki\.tcl\.tk/COST) on the Tcler's Wiki\.

  1. [TreeQL](http://wiki\.tcl\.tk/treeql) on the Tcler's Wiki\. Discuss this
     package there\.

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *treeql* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[Cost](\.\./\.\./\.\./\.\./index\.md\#cost), [DOM](\.\./\.\./\.\./\.\./index\.md\#dom),
[TreeQL](\.\./\.\./\.\./\.\./index\.md\#treeql),
[XPath](\.\./\.\./\.\./\.\./index\.md\#xpath), [XSLT](\.\./\.\./\.\./\.\./index\.md\#xslt),
[structured queries](\.\./\.\./\.\./\.\./index\.md\#structured\_queries),
[tree](\.\./\.\./\.\./\.\./index\.md\#tree), [tree query
language](\.\./\.\./\.\./\.\./index\.md\#tree\_query\_language)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Colin McCormack <coldstore@users\.sourceforge\.net>  
Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
