
[//000000001]: # (struct::set \- Tcl Data Structures)
[//000000002]: # (Generated from file 'struct\_set\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (struct::set\(n\) 2\.2\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::set \- Procedures for manipulating sets

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [REFERENCES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.0  
package require struct::set ?2\.2\.3?  

[__::struct::set__ __empty__ *set*](#1)  
[__::struct::set__ __size__ *set*](#2)  
[__::struct::set__ __contains__ *set* *item*](#3)  
[__::struct::set__ __union__ ?*set1*\.\.\.?](#4)  
[__::struct::set__ __intersect__ ?*set1*\.\.\.?](#5)  
[__::struct::set__ __difference__ *set1* *set2*](#6)  
[__::struct::set__ __symdiff__ *set1* *set2*](#7)  
[__::struct::set__ __intersect3__ *set1* *set2*](#8)  
[__::struct::set__ __equal__ *set1* *set2*](#9)  
[__::struct::set__ __include__ *svar* *item*](#10)  
[__::struct::set__ __exclude__ *svar* *item*](#11)  
[__::struct::set__ __add__ *svar* *set*](#12)  
[__::struct::set__ __subtract__ *svar* *set*](#13)  
[__::struct::set__ __subsetof__ *A* *B*](#14)  

# <a name='description'></a>DESCRIPTION

The __::struct::set__ namespace contains several useful commands for
processing finite sets\.

It exports only a single command, __struct::set__\. All functionality
provided here can be reached through a subcommand of this command\.

*Note:* As of version 2\.2 of this package a critcl based C implementation is
available\. This implementation however requires Tcl 8\.4 to run\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::struct::set__ __empty__ *set*

    Returns a boolean value indicating if the *set* is empty \(__true__\),
    or not \(__false__\)\.

  - <a name='2'></a>__::struct::set__ __size__ *set*

    Returns an integer number greater than or equal to zero\. This is the number
    of elements in the *set*\. In other words, its cardinality\.

  - <a name='3'></a>__::struct::set__ __contains__ *set* *item*

    Returns a boolean value indicating if the *set* contains the element
    *item* \(__true__\), or not \(__false__\)\.

  - <a name='4'></a>__::struct::set__ __union__ ?*set1*\.\.\.?

    Computes the set containing the union of *set1*, *set2*, etc\., i\.e\.
    "*set1* \+ *set2* \+ \.\.\.", and returns this set as the result of the
    command\.

  - <a name='5'></a>__::struct::set__ __intersect__ ?*set1*\.\.\.?

    Computes the set containing the intersection of *set1*, *set2*, etc\.,
    i\.e\. "*set1* \* *set2* \* \.\.\.", and returns this set as the result of the
    command\.

  - <a name='6'></a>__::struct::set__ __difference__ *set1* *set2*

    Computes the set containing the difference of *set1* and *set2*, i\.e\.
    \("*set1* \- *set2*"\) and returns this set as the result of the command\.

  - <a name='7'></a>__::struct::set__ __symdiff__ *set1* *set2*

    Computes the set containing the symmetric difference of *set1* and
    *set2*, i\.e\. \("\(*set1* \- *set2*\) \+ \(*set2* \- *set1*\)"\) and returns
    this set as the result of the command\.

  - <a name='8'></a>__::struct::set__ __intersect3__ *set1* *set2*

    This command is a combination of the methods __intersect__ and
    __difference__\. It returns a three\-element list containing
    "*set1*\**set2*", "*set1*\-*set2*", and "*set2*\-*set1*", in this
    order\. In other words, the intersection of the two parameter sets, and their
    differences\.

  - <a name='9'></a>__::struct::set__ __equal__ *set1* *set2*

    Returns a boolean value indicating if the two sets are equal \(__true__\)
    or not \(__false__\)\.

  - <a name='10'></a>__::struct::set__ __include__ *svar* *item*

    The element *item* is added to the set specified by the variable name in
    *svar*\. The return value of the command is empty\. This is the equivalent
    of __lappend__ for sets\. If the variable named by *svar* does not
    exist it will be created\.

  - <a name='11'></a>__::struct::set__ __exclude__ *svar* *item*

    The element *item* is removed from the set specified by the variable name
    in *svar*\. The return value of the command is empty\. This is a
    near\-equivalent of __lreplace__ for sets\.

  - <a name='12'></a>__::struct::set__ __add__ *svar* *set*

    All the element of *set* are added to the set specified by the variable
    name in *svar*\. The return value of the command is empty\. This is like the
    method __include__, but for the addition of a whole set\. If the variable
    named by *svar* does not exist it will be created\.

  - <a name='13'></a>__::struct::set__ __subtract__ *svar* *set*

    All the element of *set* are removed from the set specified by the
    variable name in *svar*\. The return value of the command is empty\. This is
    like the method __exclude__, but for the removal of a whole set\.

  - <a name='14'></a>__::struct::set__ __subsetof__ *A* *B*

    Returns a boolean value indicating if the set *A* is a true subset of or
    equal to the set *B* \(__true__\), or not \(__false__\)\.

# <a name='section3'></a>REFERENCES

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: set* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[cardinality](\.\./\.\./\.\./\.\./index\.md\#cardinality),
[difference](\.\./\.\./\.\./\.\./index\.md\#difference),
[emptiness](\.\./\.\./\.\./\.\./index\.md\#emptiness),
[exclusion](\.\./\.\./\.\./\.\./index\.md\#exclusion),
[inclusion](\.\./\.\./\.\./\.\./index\.md\#inclusion),
[intersection](\.\./\.\./\.\./\.\./index\.md\#intersection),
[membership](\.\./\.\./\.\./\.\./index\.md\#membership),
[set](\.\./\.\./\.\./\.\./index\.md\#set), [symmetric
difference](\.\./\.\./\.\./\.\./index\.md\#symmetric\_difference),
[union](\.\./\.\./\.\./\.\./index\.md\#union)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
