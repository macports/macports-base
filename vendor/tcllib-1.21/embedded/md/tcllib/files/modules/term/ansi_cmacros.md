
[//000000001]: # (term::ansi::code::macros \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_cmacros\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::code::macros\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::code::macros \- Macro sequences

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Introspection](#subsection1)

      - [Sequences](#subsection2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require textutil::repeat  
package require textutil::tabify  
package require term::ansi::code::macros ?0\.1?  

[__::term::ansi::code::macros::names__](#1)  
[__::term::ansi::code::macros::import__ ?*ns*? ?*arg*\.\.\.?](#2)  
[__::term::ansi::code::macros::menu__ *menu*](#3)  
[__::term::ansi::code::macros::frame__ *string*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides higher level control sequences for more complex shapes\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Introspection

  - <a name='1'></a>__::term::ansi::code::macros::names__

    This command is for introspection\. It returns as its result a list
    containing the names of all attribute commands\.

  - <a name='2'></a>__::term::ansi::code::macros::import__ ?*ns*? ?*arg*\.\.\.?

    This command imports some or all attribute commands into the namespace
    *ns*\. This is by default the namespace *macros*\. Note that this is
    relative namespace name, placing the imported command into a child of the
    current namespace\. By default all commands are imported, this can howver be
    restricted by listing the names of the wanted commands after the namespace
    argument\.

## <a name='subsection2'></a>Sequences

  - <a name='3'></a>__::term::ansi::code::macros::menu__ *menu*

    The description of a menu is converted into a formatted rectangular block of
    text, with the menu command characters highlighted using bold red text\. The
    result is returned as the result of the command\.

    The description, *menu*, is a dictionary mapping from menu label to
    command character\.

  - <a name='4'></a>__::term::ansi::code::macros::frame__ *string*

    The paragraph of text contained in the string is padded with spaces at the
    right margin, after normalizing internal tabs, and then put into a frame
    made of box\-graphics\. The result is returned as the result of the command\.

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

[ansi](\.\./\.\./\.\./\.\./index\.md\#ansi),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[frame](\.\./\.\./\.\./\.\./index\.md\#frame), [menu](\.\./\.\./\.\./\.\./index\.md\#menu),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
