
[//000000001]: # (term::ansi::code::attr \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_cattr\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::code::attr\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::code::attr \- ANSI attribute sequences

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Introspection](#subsection1)

      - [Attributes](#subsection2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::ansi::code ?0\.1?  
package require term::ansi::code::attr ?0\.1?  

[__::term::ansi::code::attr::names__](#1)  
[__::term::ansi::code::attr::import__ ?*ns*? ?*arg*\.\.\.?](#2)  
[__::term::ansi::code::attr::fgblack__](#3)  
[__::term::ansi::code::attr::fgred__](#4)  
[__::term::ansi::code::attr::fggreen__](#5)  
[__::term::ansi::code::attr::fgyellow__](#6)  
[__::term::ansi::code::attr::fgblue__](#7)  
[__::term::ansi::code::attr::fgmagenta__](#8)  
[__::term::ansi::code::attr::fgcyan__](#9)  
[__::term::ansi::code::attr::fgwhite__](#10)  
[__::term::ansi::code::attr::fgdefault__](#11)  
[__::term::ansi::code::attr::bgblack__](#12)  
[__::term::ansi::code::attr::bgred__](#13)  
[__::term::ansi::code::attr::bggreen__](#14)  
[__::term::ansi::code::attr::bgyellow__](#15)  
[__::term::ansi::code::attr::bgblue__](#16)  
[__::term::ansi::code::attr::bgmagenta__](#17)  
[__::term::ansi::code::attr::bgcyan__](#18)  
[__::term::ansi::code::attr::bgwhite__](#19)  
[__::term::ansi::code::attr::bgdefault__](#20)  
[__::term::ansi::code::attr::bold__](#21)  
[__::term::ansi::code::attr::dim__](#22)  
[__::term::ansi::code::attr::italic__](#23)  
[__::term::ansi::code::attr::underline__](#24)  
[__::term::ansi::code::attr::blink__](#25)  
[__::term::ansi::code::attr::revers__](#26)  
[__::term::ansi::code::attr::hidden__](#27)  
[__::term::ansi::code::attr::strike__](#28)  
[__::term::ansi::code::attr::nobold__](#29)  
[__::term::ansi::code::attr::noitalic__](#30)  
[__::term::ansi::code::attr::nounderline__](#31)  
[__::term::ansi::code::attr::noblink__](#32)  
[__::term::ansi::code::attr::norevers__](#33)  
[__::term::ansi::code::attr::nohidden__](#34)  
[__::term::ansi::code::attr::nostrike__](#35)  
[__::term::ansi::code::attr::reset__](#36)  

# <a name='description'></a>DESCRIPTION

This package provides symbolic names for the ANSI attribute control codes\. For
each control code a single command is provided which returns this code as its
result\. None of the commands of this package write to a channel; that is handled
by higher level packages, like __[term::ansi::send](ansi\_send\.md)__\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Introspection

  - <a name='1'></a>__::term::ansi::code::attr::names__

    This command is for introspection\. It returns as its result a list
    containing the names of all attribute commands\.

  - <a name='2'></a>__::term::ansi::code::attr::import__ ?*ns*? ?*arg*\.\.\.?

    This command imports some or all attribute commands into the namespace
    *ns*\. This is by default the namespace *attr*\. Note that this is
    relative namespace name, placing the imported command into a child of the
    current namespace\. By default all commands are imported, this can howver be
    restricted by listing the names of the wanted commands after the namespace
    argument\.

## <a name='subsection2'></a>Attributes

  - <a name='3'></a>__::term::ansi::code::attr::fgblack__

    Set text color to *Black*\.

  - <a name='4'></a>__::term::ansi::code::attr::fgred__

    Set text color to *Red*\.

  - <a name='5'></a>__::term::ansi::code::attr::fggreen__

    Set text color to *Green*\.

  - <a name='6'></a>__::term::ansi::code::attr::fgyellow__

    Set text color to *Yellow*\.

  - <a name='7'></a>__::term::ansi::code::attr::fgblue__

    Set text color to *Blue*\.

  - <a name='8'></a>__::term::ansi::code::attr::fgmagenta__

    Set text color to *Magenta*\.

  - <a name='9'></a>__::term::ansi::code::attr::fgcyan__

    Set text color to *Cyan*\.

  - <a name='10'></a>__::term::ansi::code::attr::fgwhite__

    Set text color to *White*\.

  - <a name='11'></a>__::term::ansi::code::attr::fgdefault__

    Set default text color \(*Black*\)\.

  - <a name='12'></a>__::term::ansi::code::attr::bgblack__

    Set background to *Black*\.

  - <a name='13'></a>__::term::ansi::code::attr::bgred__

    Set background to *Red*\.

  - <a name='14'></a>__::term::ansi::code::attr::bggreen__

    Set background to *Green*\.

  - <a name='15'></a>__::term::ansi::code::attr::bgyellow__

    Set background to *Yellow*\.

  - <a name='16'></a>__::term::ansi::code::attr::bgblue__

    Set background to *Blue*\.

  - <a name='17'></a>__::term::ansi::code::attr::bgmagenta__

    Set background to *Magenta*\.

  - <a name='18'></a>__::term::ansi::code::attr::bgcyan__

    Set background to *Cyan*\.

  - <a name='19'></a>__::term::ansi::code::attr::bgwhite__

    Set background to *White*\.

  - <a name='20'></a>__::term::ansi::code::attr::bgdefault__

    Set default background \(Transparent\)\.

  - <a name='21'></a>__::term::ansi::code::attr::bold__

    Bold on\.

  - <a name='22'></a>__::term::ansi::code::attr::dim__

    Dim on\.

  - <a name='23'></a>__::term::ansi::code::attr::italic__

    Italics on\.

  - <a name='24'></a>__::term::ansi::code::attr::underline__

    Underscore on\.

  - <a name='25'></a>__::term::ansi::code::attr::blink__

    Blink on\.

  - <a name='26'></a>__::term::ansi::code::attr::revers__

    Reverse on\.

  - <a name='27'></a>__::term::ansi::code::attr::hidden__

    Hidden on\.

  - <a name='28'></a>__::term::ansi::code::attr::strike__

    Strike\-through on\.

  - <a name='29'></a>__::term::ansi::code::attr::nobold__

    Bold off\.

  - <a name='30'></a>__::term::ansi::code::attr::noitalic__

    Italics off\.

  - <a name='31'></a>__::term::ansi::code::attr::nounderline__

    Underscore off\.

  - <a name='32'></a>__::term::ansi::code::attr::noblink__

    Blink off\.

  - <a name='33'></a>__::term::ansi::code::attr::norevers__

    Reverse off\.

  - <a name='34'></a>__::term::ansi::code::attr::nohidden__

    Hidden off\.

  - <a name='35'></a>__::term::ansi::code::attr::nostrike__

    Strike\-through off\.

  - <a name='36'></a>__::term::ansi::code::attr::reset__

    Reset all attributes to their default values\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *term* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[ansi](\.\./\.\./\.\./\.\./index\.md\#ansi), [attribute
control](\.\./\.\./\.\./\.\./index\.md\#attribute\_control), [color
control](\.\./\.\./\.\./\.\./index\.md\#color\_control),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
