
[//000000001]: # (page\_util\_quote \- Parser generator tools)
[//000000002]: # (Generated from file 'page\_util\_quote\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (page\_util\_quote\(n\) 1\.0 tcllib "Parser generator tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

page\_util\_quote \- page character quoting utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require page::util::quote ?0\.1?  
package require snit  

[__::page::util::quote::unquote__ *char*](#1)  
[__::page::util::quote::quote'tcl__ *char*](#2)  
[__::page::util::quote::quote'tclstr__ *char*](#3)  
[__::page::util::quote::quote'tclcom__ *char*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a few utility commands to convert characters into various
forms\.

# <a name='section2'></a>API

  - <a name='1'></a>__::page::util::quote::unquote__ *char*

    A character, as stored in an abstract syntax tree by a PEG processor \(See
    the packages __grammar::peg::interpreter__, __grammar::me__, and
    their relations\), i\.e\. in some quoted form, is converted into the equivalent
    Tcl character\. The character is returned as the result of the command\.

  - <a name='2'></a>__::page::util::quote::quote'tcl__ *char*

    This command takes a Tcl character \(internal representation\) and converts it
    into a string which is accepted by the Tcl parser, will regenerate the
    character in question and is 7bit ASCII\. The string is returned as the
    result of this command\.

  - <a name='3'></a>__::page::util::quote::quote'tclstr__ *char*

    This command takes a Tcl character \(internal representation\) and converts it
    into a string which is accepted by the Tcl parser and will generate a human
    readable representation of the character in question\. The string is returned
    as the result of this command\.

    The string does not use any unprintable characters\. It may use
    backslash\-quoting\. High UTF characters are quoted to avoid problems with the
    still prevalent ascii terminals\. It is assumed that the string will be used
    in a double\-quoted environment\.

  - <a name='4'></a>__::page::util::quote::quote'tclcom__ *char*

    This command takes a Tcl character \(internal representation\) and converts it
    into a string which is accepted by the Tcl parser when used within a Tcl
    comment\. The string is returned as the result of this command\.

# <a name='section3'></a>Bugs, Ideas, Feedback

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

[page](\.\./\.\./\.\./\.\./index\.md\#page), [parser
generator](\.\./\.\./\.\./\.\./index\.md\#parser\_generator),
[quoting](\.\./\.\./\.\./\.\./index\.md\#quoting), [text
processing](\.\./\.\./\.\./\.\./index\.md\#text\_processing)

# <a name='category'></a>CATEGORY

Page Parser Generator

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
