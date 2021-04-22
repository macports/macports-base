
[//000000001]: # (struct::disjointset \- Tcl Data Structures)
[//000000002]: # (Generated from file 'disjointset\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (struct::disjointset\(n\) 1\.1 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::disjointset \- Disjoint set data structure

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require struct::disjointset ?1\.1?  

[__::struct::disjointset__ *disjointsetName*](#1)  
[*disjointsetName* *option* ?*arg arg \.\.\.*?](#2)  
[*disjointsetName* __add\-element__ *item*](#3)  
[*disjointsetName* __add\-partition__ *elements*](#4)  
[*disjointsetName* __partitions__](#5)  
[*disjointsetName* __num\-partitions__](#6)  
[*disjointsetName* __equal__ *a* *b*](#7)  
[*disjointsetName* __merge__ *a* *b*](#8)  
[*disjointsetName* __find__ *e*](#9)  
[*disjointsetName* __exemplars__](#10)  
[*disjointsetName* __find\-exemplar__ *e*](#11)  
[*disjointsetName* __destroy__](#12)  

# <a name='description'></a>DESCRIPTION

This package provides *disjoint sets*\. An alternative name for this kind of
structure is *merge\-find*\.

Normally when dealing with sets and their elements the question is "Is this
element E contained in this set S?", with both E and S known\.

Here the question is "Which of several sets contains the element E?"\. I\.e\. while
the element is known, the set is not, and we wish to find it quickly\. It is not
quite the inverse of the original question, but close\. Another operation which
is often wanted is that of quickly merging two sets into one, with the result
still fast for finding elements\. Hence the alternative term *merge\-find* for
this\.

Why now is this named a *disjoint\-set* ? Because another way of describing the
whole situation is that we have

  - a finite *[set](\.\./\.\./\.\./\.\./index\.md\#set)* S, containing

  - a number of *elements* E, split into

  - a set of *partitions* P\. The latter term applies, because the intersection
    of each pair P, P' of partitions is empty, with the union of all partitions
    covering the whole set\.

  - An alternative name for the *partitions* would be *equvalence classes*,
    and all elements in the same class are considered as equal\.

Here is a pictorial representation of the concepts listed above:

    +-----------------+ The outer lines are the boundaries of the set S.
    |           /     | The inner regions delineated by the skewed lines
    |  *       /   *  | are the partitions P. The *'s denote the elements
    |      *  / \     | E in the set, each in a single partition, their
    |*       /   \    | equivalence class.
    |       /  *  \   |
    |      / *   /    |
    | *   /\  * /     |
    |    /  \  /      |
    |   /    \/  *    |
    |  / *    \       |
    | /     *  \      |
    +-----------------+

For more information see
[http://en\.wikipedia\.org/wiki/Disjoint\_set\_data\_structure](http://en\.wikipedia\.org/wiki/Disjoint\_set\_data\_structure)\.

# <a name='section2'></a>API

The package exports a single command, __::struct::disjointset__\. All
functionality provided here can be reached through a subcommand of this command\.

  - <a name='1'></a>__::struct::disjointset__ *disjointsetName*

    Creates a new disjoint set object with an associated global Tcl command
    whose name is *disjointsetName*\. This command may be used to invoke
    various operations on the disjointset\. It has the following general form:

      * <a name='2'></a>*disjointsetName* *option* ?*arg arg \.\.\.*?

        The __option__ and the *arg*s determine the exact behavior of the
        command\. The following commands are possible for disjointset objects:

  - <a name='3'></a>*disjointsetName* __add\-element__ *item*

    Creates a new partition in the specified disjoint set, and fills it with the
    single item *item*\. The command maintains the integrity of the disjoint
    set, i\.e\. it verifies that none of the *elements* are already part of the
    disjoint set and throws an error otherwise\.

    The result of this method is the empty string\.

    This method runs in constant time\.

  - <a name='4'></a>*disjointsetName* __add\-partition__ *elements*

    Creates a new partition in specified disjoint set, and fills it with the
    values found in the set of *elements*\. The command maintains the integrity
    of the disjoint set, i\.e\. it verifies that none of the *elements* are
    already part of the disjoint set and throws an error otherwise\.

    The result of the command is the empty string\.

    This method runs in time proportional to the size of *elements*\]\.

  - <a name='5'></a>*disjointsetName* __partitions__

    Returns the set of partitions the named disjoint set currently consists of\.
    The form of the result is a list of lists; the inner lists contain the
    elements of the partitions\.

    This method runs in time O\(N\*alpha\(N\)\), where N is the number of elements in
    the disjoint set and alpha is the inverse Ackermann function\.

  - <a name='6'></a>*disjointsetName* __num\-partitions__

    Returns the number of partitions the named disjoint set currently consists
    of\.

    This method runs in constant time\.

  - <a name='7'></a>*disjointsetName* __equal__ *a* *b*

    Determines if the two elements *a* and *b* of the disjoint set belong to
    the same partition\. The result of the method is a boolean value,
    __True__ if the two elements are contained in the same partition, and
    __False__ otherwise\.

    An error will be thrown if either *a* or *b* are not elements of the
    disjoint set\.

    This method runs in amortized time O\(alpha\(N\)\), where N is the number of
    elements in the larger partition and alpha is the inverse Ackermann
    function\.

  - <a name='8'></a>*disjointsetName* __merge__ *a* *b*

    Determines the partitions the elements *a* and *b* are contained in and
    merges them into a single partition\. If the two elements were already
    contained in the same partition nothing will change\.

    The result of the method is the empty string\.

    This method runs in amortized time O\(alpha\(N\)\), where N is the number of
    items in the larger of the partitions being merged\. The worst case time is
    O\(N\)\.

  - <a name='9'></a>*disjointsetName* __find__ *e*

    Returns a list of the members of the partition of the disjoint set which
    contains the element *e*\.

    This method runs in O\(N\*alpha\(N\)\) time, where N is the total number of items
    in the disjoint set and alpha is the inverse Ackermann function, See
    __find\-exemplar__ for a faster method, if all that is needed is a unique
    identifier for the partition, rather than an enumeration of all its
    elements\.

  - <a name='10'></a>*disjointsetName* __exemplars__

    Returns a list containing an exemplar of each partition in the disjoint set\.
    The exemplar is a member of the partition, chosen arbitrarily\.

    This method runs in O\(N\*alpha\(N\)\) time, where N is the total number of items
    in the disjoint set and alpha is the inverse Ackermann function\.

  - <a name='11'></a>*disjointsetName* __find\-exemplar__ *e*

    Returns the exemplar of the partition of the disjoint set containing the
    element *e*\. Throws an error if *e* is not found in the disjoint set\.
    The exemplar is an arbitrarily chosen member of the partition\. The only
    operation that will change the exemplar of any partition is __merge__\.

    This method runs in O\(alpha\(N\)\) time, where N is the number of items in the
    partition containing E, and alpha is the inverse Ackermann function\.

  - <a name='12'></a>*disjointsetName* __destroy__

    Destroys the disjoint set object and all associated memory\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: disjointset* of
the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[disjoint set](\.\./\.\./\.\./\.\./index\.md\#disjoint\_set), [equivalence
class](\.\./\.\./\.\./\.\./index\.md\#equivalence\_class),
[find](\.\./\.\./\.\./\.\./index\.md\#find), [merge
find](\.\./\.\./\.\./\.\./index\.md\#merge\_find),
[partition](\.\./\.\./\.\./\.\./index\.md\#partition), [partitioned
set](\.\./\.\./\.\./\.\./index\.md\#partitioned\_set),
[union](\.\./\.\./\.\./\.\./index\.md\#union)

# <a name='category'></a>CATEGORY

Data structures
