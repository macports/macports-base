
[//000000001]: # (xsxp \- Amazon S3 Web Service Utilities)
[//000000002]: # (Generated from file 'xsxp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (2006 Darren New\. All Rights Reserved\.)
[//000000004]: # (xsxp\(n\) 1\.0 tcllib "Amazon S3 Web Service Utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

xsxp \- eXtremely Simple Xml Parser

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require xsxp 1  
package require xml  

[__xsxp::parse__ *xml*](#1)  
[__xsxp::fetch__ *pxml* *path* ?*part*?](#2)  
[__xsxp::fetchall__ *pxml\_list* *path* ?*part*?](#3)  
[__xsxp::only__ *pxml* *tagname*](#4)  
[__xsxp::prettyprint__ *pxml* ?*chan*?](#5)  

# <a name='description'></a>DESCRIPTION

This package provides a simple interface to parse XML into a pure\-value list\. It
also provides accessor routines to pull out specific subtags, not unlike DOM
access\. This package was written for and is used by Darren New's Amazon S3
access package\.

This is pretty lame, but I needed something like this for S3, and at the time,
TclDOM would not work with the new 8\.5 Tcl due to version number problems\.

In addition, this is a pure\-value implementation\. There is no garbage to clean
up in the event of a thrown error, for example\. This simplifies the code for
sufficiently small XML documents, which is what Amazon's S3 guarantees\.

Copyright 2006 Darren New\. All Rights Reserved\. NO WARRANTIES OF ANY TYPE ARE
PROVIDED\. COPYING OR USE INDEMNIFIES THE AUTHOR IN ALL WAYS\. This software is
licensed under essentially the same terms as Tcl\. See LICENSE\.txt for the terms\.

# <a name='section2'></a>COMMANDS

The package implements five rather simple procedures\. One parses, one is for
debugging, and the rest pull various parts of the parsed document out for
processing\.

  - <a name='1'></a>__xsxp::parse__ *xml*

    This parses an XML document \(using the standard xml tcllib module in a SAX
    sort of way\) and builds a data structure which it returns if the parsing
    succeeded\. The return value is referred to herein as a "pxml", or "parsed
    xml"\. The list consists of two or more elements:

      * The first element is the name of the tag\.

      * The second element is an array\-get formatted list of key/value pairs\.
        The keys are attribute names and the values are attribute values\. This
        is an empty list if there are no attributes on the tag\.

      * The third through end elements are the children of the node, if any\.
        Each child is, recursively, a pxml\.

      * Note that if the zero'th element, i\.e\. the tag name, is "%PCDATA", then
        the attributes will be empty and the third element will be the text of
        the element\. In addition, if an element's contents consists only of
        PCDATA, it will have only one child, and all the PCDATA will be
        concatenated\. In other words, this parser works poorly for XML with
        elements that contain both child tags and PCDATA\. Since Amazon S3 does
        not do this \(and for that matter most uses of XML where XML is a poor
        choice don't do this\), this is probably not a serious limitation\.

  - <a name='2'></a>__xsxp::fetch__ *pxml* *path* ?*part*?

    *pxml* is a parsed XML, as returned from xsxp::parse\. *path* is a list
    of element tag names\. Each element is the name of a child to look up,
    optionally followed by a hash \("\#"\) and a string of digits\. An empty list or
    an initial empty element selects *pxml*\. If no hash sign is present, the
    behavior is as if "\#0" had been appended to that element\. \(In addition to a
    list, slashes can separate subparts where convenient\.\)

    An element of *path* scans the children at the indicated level for the
    n'th instance of a child whose tag matches the part of the element before
    the hash sign\. If an element is simply "\#" followed by digits, that indexed
    child is selected, regardless of the tags in the children\. Hence, an element
    of "\#3" will always select the fourth child of the node under consideration\.

    *part* defaults to "%ALL"\. It can be one of the following case\-sensitive
    terms:

      * %ALL

        returns the entire selected element\.

      * %TAGNAME

        returns lindex 0 of the selected element\.

      * %ATTRIBUTES

        returns index 1 of the selected element\.

      * %CHILDREN

        returns lrange 2 through end of the selected element, resulting in a
        list of elements being returned\.

      * %PCDATA

        returns a concatenation of all the bodies of direct children of this
        node whose tag is %PCDATA\. It throws an error if no such children are
        found\. That is, part=%PCDATA means return the textual content found in
        that node but not its children nodes\.

      * %PCDATA?

        is like %PCDATA, but returns an empty string if no PCDATA is found\.

    For example, to fetch the first bold text from the fifth paragraph of the
    body of your HTML file,

        xsxp::fetch $pxml {body p#4 b} %PCDATA

  - <a name='3'></a>__xsxp::fetchall__ *pxml\_list* *path* ?*part*?

    This iterates over each PXML in *pxml\_list* \(which must be a list of
    pxmls\) selecting the indicated path from it, building a new list with the
    selected data, and returning that new list\.

    For example, *pxml\_list* might be the %CHILDREN of a particular element,
    and the *path* and *part* might select from each child a sub\-element in
    which we're interested\.

  - <a name='4'></a>__xsxp::only__ *pxml* *tagname*

    This iterates over the direct children of *pxml* and selects only those
    with *tagname* as their tag\. Returns a list of matching elements\.

  - <a name='5'></a>__xsxp::prettyprint__ *pxml* ?*chan*?

    This outputs to *chan* \(default stdout\) a pretty\-printed version of
    *pxml*\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *amazon\-s3* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[dom](\.\./\.\./\.\./\.\./index\.md\#dom), [parser](\.\./\.\./\.\./\.\./index\.md\#parser),
[xml](\.\./\.\./\.\./\.\./index\.md\#xml)

# <a name='category'></a>CATEGORY

Text processing

# <a name='copyright'></a>COPYRIGHT

2006 Darren New\. All Rights Reserved\.
