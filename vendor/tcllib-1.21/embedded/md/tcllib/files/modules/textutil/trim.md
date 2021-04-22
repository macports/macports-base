
[//000000001]: # (textutil::trim \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'trim\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::trim\(n\) 0\.7 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::trim \- Procedures to trim strings

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
package require textutil::trim ?0\.7?  

[__::textutil::trim::trim__ *string* ?*regexp*?](#1)  
[__::textutil::trim::trimleft__ *string* ?*regexp*?](#2)  
[__::textutil::trim::trimright__ *string* ?*regexp*?](#3)  
[__::textutil::trim::trimPrefix__ *string* *prefix*](#4)  
[__::textutil::trim::trimEmptyHeading__ *string*](#5)  

# <a name='description'></a>DESCRIPTION

The package __textutil::trim__ provides commands that trim strings using
arbitrary regular expressions\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::trim::trim__ *string* ?*regexp*?

    Remove in *string* any leading and trailing substring according to the
    regular expression *regexp* and return the result as a new string\. This is
    done for all *lines* in the string, that is any substring between 2
    newline chars, or between the beginning of the string and a newline, or
    between a newline and the end of the string, or, if the string contain no
    newline, between the beginning and the end of the string\. The regular
    expression *regexp* defaults to "\[ \\\\t\]\+"\.

  - <a name='2'></a>__::textutil::trim::trimleft__ *string* ?*regexp*?

    Remove in *string* any leading substring according to the regular
    expression *regexp* and return the result as a new string\. This apply on
    any *line* in the string, that is any substring between 2 newline chars,
    or between the beginning of the string and a newline, or between a newline
    and the end of the string, or, if the string contain no newline, between the
    beginning and the end of the string\. The regular expression *regexp*
    defaults to "\[ \\\\t\]\+"\.

  - <a name='3'></a>__::textutil::trim::trimright__ *string* ?*regexp*?

    Remove in *string* any trailing substring according to the regular
    expression *regexp* and return the result as a new string\. This apply on
    any *line* in the string, that is any substring between 2 newline chars,
    or between the beginning of the string and a newline, or between a newline
    and the end of the string, or, if the string contain no newline, between the
    beginning and the end of the string\. The regular expression *regexp*
    defaults to "\[ \\\\t\]\+"\.

  - <a name='4'></a>__::textutil::trim::trimPrefix__ *string* *prefix*

    Removes the *prefix* from the beginning of *string* and returns the
    result\. The *string* is left unchanged if it doesn't have *prefix* at
    its beginning\.

  - <a name='5'></a>__::textutil::trim::trimEmptyHeading__ *string*

    Looks for empty lines \(including lines consisting of only whitespace\) at the
    beginning of the *string* and removes it\. The modified string is returned
    as the result of the command\.

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

[prefix](\.\./\.\./\.\./\.\./index\.md\#prefix), [regular
expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression),
[string](\.\./\.\./\.\./\.\./index\.md\#string),
[trimming](\.\./\.\./\.\./\.\./index\.md\#trimming)

# <a name='category'></a>CATEGORY

Text processing
