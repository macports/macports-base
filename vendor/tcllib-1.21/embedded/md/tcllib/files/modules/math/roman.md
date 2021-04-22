
[//000000001]: # (math::roman \- Tcl Math Library)
[//000000002]: # (Generated from file 'roman\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Kenneth Green <kenneth\.green@gmail\.com>)
[//000000004]: # (math::roman\(\) 1\.0 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::roman \- Tools for creating and manipulating roman numerals

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

package require Tcl 8\.3  
package require math::roman ?1\.0?  

[__::math::roman::toroman__ *i*](#1)  
[__::math::roman::tointeger__ *r*](#2)  
[__::math::roman::sort__ *list*](#3)  
[__::math::roman::expr__ *args*](#4)  

# <a name='description'></a>DESCRIPTION

__::math::roman__ is a pure\-Tcl library for converting between integers and
roman numerals\. It also provides utility functions for sorting and performing
arithmetic on roman numerals\.

This code was originally harvested from the Tcler's wiki at
http://wiki\.tcl\.tk/1823 and as such is free for any use for any purpose\. Many
thanks to the ingeneous folk who devised these clever routines and generously
contributed them to the Tcl community\.

While written and tested under Tcl 8\.3, I expect this library will work under
all 8\.x versions of Tcl\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::math::roman::toroman__ *i*

    Convert an integer to roman numerals\. The result is always in upper case\.
    The value zero is converted to an empty string\.

  - <a name='2'></a>__::math::roman::tointeger__ *r*

    Convert a roman numeral into an integer\.

  - <a name='3'></a>__::math::roman::sort__ *list*

    Sort a list of roman numerals from smallest to largest\.

  - <a name='4'></a>__::math::roman::expr__ *args*

    Evaluate an expression where the operands are all roman numerals\.

Of these commands both *toroman* and *tointeger* are exported for easier
use\. The other two are not, as they could interfer or be confused with existing
Tcl commands\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: roman* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[integer](\.\./\.\./\.\./\.\./index\.md\#integer), [roman
numeral](\.\./\.\./\.\./\.\./index\.md\#roman\_numeral)

# <a name='category'></a>CATEGORY

Mathematics

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Kenneth Green <kenneth\.green@gmail\.com>
