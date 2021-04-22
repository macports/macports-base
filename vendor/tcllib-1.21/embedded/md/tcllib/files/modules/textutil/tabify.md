
[//000000001]: # (textutil::tabify \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'tabify\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::tabify\(n\) 0\.7 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::tabify \- Procedures to \(un\)tabify strings

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require textutil::tabify ?0\.7?  

[__::textutil::tabify::tabify__ *string* ?*num*?](#1)  
[__::textutil::tabify::tabify2__ *string* ?*num*?](#2)  
[__::textutil::tabify::untabify__ *string* ?*num*?](#3)  
[__::textutil::tabify::untabify2__ *string* ?*num*?](#4)  

# <a name='description'></a>DESCRIPTION

The package __textutil::tabify__ provides commands that convert between
tabulation and ordinary whitespace in strings\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::tabify::tabify__ *string* ?*num*?

    Tabify the *string* by replacing any substring of *num* space chars by a
    tabulation and return the result as a new string\. *num* defaults to 8\.

  - <a name='2'></a>__::textutil::tabify::tabify2__ *string* ?*num*?

    Similar to __::textutil::tabify__ this command tabifies the *string*
    and returns the result as a new string\. A different algorithm is used
    however\. Instead of replacing any substring of *num* spaces this command
    works more like an editor\. *num* defaults to 8\.

    Each line of the text in *string* is treated as if there are tabstops
    every *num* columns\. Only sequences of space characters containing more
    than one space character and found immediately before a tabstop are replaced
    with tabs\.

  - <a name='3'></a>__::textutil::tabify::untabify__ *string* ?*num*?

    Untabify the *string* by replacing any tabulation char by a substring of
    *num* space chars and return the result as a new string\. *num* defaults
    to 8\.

  - <a name='4'></a>__::textutil::tabify::untabify2__ *string* ?*num*?

    Untabify the *string* by replacing any tabulation char by a substring of
    at most *num* space chars and return the result as a new string\. Unlike
    __textutil::tabify::untabify__ each tab is not replaced by a fixed
    number of space characters\. The command overlays each line in the *string*
    with tabstops every *num* columns instead and replaces tabs with just
    enough space characters to reach the next tabstop\. This is the complement of
    the actions taken by __::textutil::tabify::tabify2__\. *num* defaults
    to 8\.

    There is one asymmetry though: A tab can be replaced with a single space,
    but not the other way around\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

regexp\(n\), split\(n\), string\(n\)

# <a name='keywords'></a>KEYWORDS

[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[tabstops](\.\./\.\./\.\./\.\./index\.md\#tabstops)

# <a name='category'></a>CATEGORY

Text processing
