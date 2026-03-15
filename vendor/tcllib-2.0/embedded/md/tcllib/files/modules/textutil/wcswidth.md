
[//000000001]: # (textutil::wcswidth \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'wcswidth\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::wcswidth\(n\) 35\.3 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::wcswidth \- Procedures to compute terminal width of strings

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5 9  
package require textutil::wcswidth ?35\.3?  

[__::textutil::wcswidth__ *string*](#1)  
[__::textutil::wcswidth\_char__ *char*](#2)  
[__::textutil::wcswidth\_type__ *char*](#3)  

# <a name='description'></a>DESCRIPTION

The package __textutil::wcswidth__ provides commands that determine
character type and width when used in terminals, and the length of strings when
printed in a terminal\.

The data underlying the functionality of this package is provided by the Unicode
database file
[http://www\.unicode\.org/Public/UCD/latest/ucd/EastAsianWidth\.txt](http://www\.unicode\.org/Public/UCD/latest/ucd/EastAsianWidth\.txt)\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::wcswidth__ *string*

    Returns the number of character cells taken by the string when printed to
    the terminal\. This takes double\-wide characters from the various Asian and
    other scripts into account\.

  - <a name='2'></a>__::textutil::wcswidth\_char__ *char*

    Returns the number of character cells taken by the character when printed to
    the terminal\.

    *Beware*: The character *char* is specified as Unicode codepoint\.

  - <a name='3'></a>__::textutil::wcswidth\_type__ *char*

    Returns the character type of the specified character\. This a single
    character in the set of __A__, __F__, __H__, __N__,
    __Na__, and __W__, as specified per
    [http://www\.unicode\.org/Public/UCD/latest/ucd/EastAsianWidth\.txt](http://www\.unicode\.org/Public/UCD/latest/ucd/EastAsianWidth\.txt)

    *Beware*: The character *char* is specified as Unicode codepoint\.

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

[character type](\.\./\.\./\.\./\.\./index\.md\#character\_type), [character
width](\.\./\.\./\.\./\.\./index\.md\#character\_width), [double\-wide
character](\.\./\.\./\.\./\.\./index\.md\#double\_wide\_character),
[prefix](\.\./\.\./\.\./\.\./index\.md\#prefix), [regular
expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression),
[string](\.\./\.\./\.\./\.\./index\.md\#string)

# <a name='category'></a>CATEGORY

Text processing
