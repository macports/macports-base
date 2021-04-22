
[//000000001]: # (page\_util\_flow \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_util\_flow\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_util\_flow\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_util\_flow \- page dataflow/treewalker utility

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [FLOW API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require page::util::flow ?0\.1?  
package require snit  

[__::page::util::flow__ *start* *flowvar* *nodevar* *script*](#1)  
[*flow* __visit__ *node*](#2)  
[*flow* __visitl__ *nodelist*](#3)  
[*flow* __visita__ *node*\.\.\.](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a single utility command for easy dataflow based
manipulation of arbitrary data structures, especially abstract syntax trees\.

# <a name='section2'></a>API

  - <a name='1'></a>__::page::util::flow__ *start* *flowvar* *nodevar* *script*

    This command contains the core logic to drive the walking of an arbitrary
    data structure which can partitioned into separate parts\. Examples of such
    structures are trees and graphs\.

    The command makes no assumptions at all about the API of the structure to be
    walked, except that that its parts, here called *nodes*, are identified by
    strings\. These strings are taken as is, from the arguments, and the body,
    and handed back to the body, without modification\.

    Access to the actual data structure, and all decisions regarding which nodes
    to visit in what order are delegated to the body of the loop, i\.e\. the
    *script*\.

    The body is invoked first for the nodes in the start\-set specified via
    *start*\), and from then on for the nodes the body has requested to be
    visited\. The command stops when the set of nodes to visit becomes empty\.
    Note that a node can be visited more than once\. The body has complete
    control about this\.

    The body is invoked in the context of the caller\. The variable named by
    *nodevar* will be set to the current node, and the variable named by
    *flowvar* will be set to the command of the flow object through which the
    body can request the nodes to visit next\. The API provided by this object is
    described in the next section, [FLOW API](#section3)\.

    Note that the command makes no promises regarding the order in which nodes
    are visited, excpt that the nodes requested to be visited by the current
    iteration will be visited afterward, in some order\.

# <a name='section3'></a>FLOW API

This section describes the API provided by the flow object made accessible to
the body script of __::page::util::flow__\.

  - <a name='2'></a>*flow* __visit__ *node*

    Invoking this method requests that the node *n* is visited after the
    current iteration\.

  - <a name='3'></a>*flow* __visitl__ *nodelist*

    Invoking this method requests that all the nodes found in the list
    *nodelist* are visited after the current iteration\.

  - <a name='4'></a>*flow* __visita__ *node*\.\.\.

    This is the variadic arguments form of the method __visitl__, see above\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *page* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[dataflow](\.\./\.\./\.\./\.\./index\.md\#dataflow), [graph
walking](\.\./\.\./\.\./\.\./index\.md\#graph\_walking),
[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing), [tree
walking](\.\./\.\./\.\./\.\./index\.md\#tree\_walking)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
