
[//000000001]: # (struct::skiplist \- Tcl Data Structures)
[//000000002]: # (Generated from file 'skiplist\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2000 Keith Vetter)
[//000000004]: # (struct::skiplist\(n\) 1\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::skiplist \- Create and manipulate skiplists

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
package require struct::skiplist ?1\.3?  

[__skiplistName__ *option* ?*arg arg \.\.\.*?](#1)  
[*skiplistName* __delete__ *node* ?*node*\.\.\.?](#2)  
[*skiplistName* __destroy__](#3)  
[*skiplistName* __insert__ *key value*](#4)  
[*skiplistName* __search__ *node* ?__\-key__ *key*?](#5)  
[*skiplistName* __size__](#6)  
[*skiplistName* __walk__ *cmd*](#7)  

# <a name='description'></a>DESCRIPTION

The __::struct::skiplist__ command creates a new skiplist object with an
associated global Tcl command whose name is *skiplistName*\. This command may
be used to invoke various operations on the skiplist\. It has the following
general form:

  - <a name='1'></a>__skiplistName__ *option* ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

Skip lists are an alternative data structure to binary trees\. They can be used
to maintain ordered lists over any sequence of insertions and deletions\. Skip
lists use randomness to achieve probabilistic balancing, and as a result the
algorithms for insertion and deletion in skip lists are much simpler and faster
than those for binary trees\.

To read more about skip lists see Pugh, William\. *Skip lists: a probabilistic
alternative to balanced trees* In: Communications of the ACM, June 1990, 33\(6\)
668\-676\.

Currently, the key can be either a number or a string, and comparisons are
performed with the built in greater than operator\. The following commands are
possible for skiplist objects:

  - <a name='2'></a>*skiplistName* __delete__ *node* ?*node*\.\.\.?

    Remove the specified nodes from the skiplist\.

  - <a name='3'></a>*skiplistName* __destroy__

    Destroy the skiplist, including its storage space and associated command\.

  - <a name='4'></a>*skiplistName* __insert__ *key value*

    Insert a node with the given *key* and *value* into the skiplist\. If a
    node with that key already exists, then the that node's value is updated and
    its node level is returned\. Otherwise a new node is created and 0 is
    returned\.

  - <a name='5'></a>*skiplistName* __search__ *node* ?__\-key__ *key*?

    Search for a given key in a skiplist\. If not found then 0 is returned\. If
    found, then a two element list of 1 followed by the node's value is retuned\.

  - <a name='6'></a>*skiplistName* __size__

    Return a count of the number of nodes in the skiplist\.

  - <a name='7'></a>*skiplistName* __walk__ *cmd*

    Walk the skiplist from the first node to the last\. At each node, the command
    *cmd* will be evaluated with the key and value of the current node
    appended\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: skiplist* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[skiplist](\.\./\.\./\.\./\.\./index\.md\#skiplist)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2000 Keith Vetter
