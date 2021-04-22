
[//000000001]: # (textutil::split \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'textutil\_split\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::split\(n\) 0\.8 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::split \- Procedures to split texts

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
package require textutil::split ?0\.8?  

[__::textutil::split::splitn__ *string* ?*len*?](#1)  
[__::textutil::split::splitx__ *string* ?*regexp*?](#2)  

# <a name='description'></a>DESCRIPTION

The package __textutil::split__ provides commands that split strings by size
and arbitrary regular expressions\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::split::splitn__ *string* ?*len*?

    This command splits the given *string* into chunks of *len* characters
    and returns a list containing these chunks\. The argument *len* defaults to
    __1__ if none is specified\. A negative length is not allowed and will
    cause the command to throw an error\. Providing an empty string as input is
    allowed, the command will then return an empty list\. If the length of the
    *string* is not an entire multiple of the chunk length, then the last
    chunk in the generated list will be shorter than *len*\.

  - <a name='2'></a>__::textutil::split::splitx__ *string* ?*regexp*?

    This command splits the *string* and return a list\. The string is split
    according to the regular expression *regexp* instead of a simple list of
    chars\. *Note*: When parentheses are used in the *regexp*, i\.e\. regex
    capture groups, then these groups will be added into the result list as
    additional elements\. If the *string* is empty the result is the empty
    list, like for __[split](\.\./\.\./\.\./\.\./index\.md\#split)__\. If
    *regexp* is empty the *string* is split at every character, like
    __[split](\.\./\.\./\.\./\.\./index\.md\#split)__ does\. The regular expression
    *regexp* defaults to "\[\\\\t \\\\r\\\\n\]\+"\.

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

[regular expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression),
[split](\.\./\.\./\.\./\.\./index\.md\#split),
[string](\.\./\.\./\.\./\.\./index\.md\#string)

# <a name='category'></a>CATEGORY

Text processing
