
[//000000001]: # (textutil::repeat \- Text and string utilities, macro processing)
[//000000002]: # (Generated from file 'repeat\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (textutil::repeat\(n\) 0\.7\.1 tcllib "Text and string utilities, macro processing")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

textutil::repeat \- Procedures to repeat strings\.

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
package require textutil::repeat ?0\.7?  

[__::textutil::repeat::strRepeat__ *text* *num*](#1)  
[__::textutil::repeat::blank__ *num*](#2)  

# <a name='description'></a>DESCRIPTION

The package __textutil::repeat__ provides commands to generate long strings
by repeating a shorter string many times\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::textutil::repeat::strRepeat__ *text* *num*

    This command returns a string containing the *text* repeated *num*
    times\. The repetitions are joined without characters between them\. A value
    of *num* <= 0 causes the command to return an empty string\.

    *Note*: If the Tcl core the package is loaded in provides the command
    __string repeat__ then this command will be implemented in its terms,
    for maximum possible speed\. Otherwise a fast implementation in Tcl will be
    used\.

  - <a name='2'></a>__::textutil::repeat::blank__ *num*

    A convenience command\. Returns a string of *num* spaces\.

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

[blanks](\.\./\.\./\.\./\.\./index\.md\#blanks),
[repetition](\.\./\.\./\.\./\.\./index\.md\#repetition),
[string](\.\./\.\./\.\./\.\./index\.md\#string)

# <a name='category'></a>CATEGORY

Text processing
