
[//000000001]: # (term::ansi::ctrl::unix \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_ctrlu\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::ctrl::unix\(n\) 0\.1\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::ctrl::unix \- Control operations and queries

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Introspection](#subsection1)

      - [Operations](#subsection2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::ansi::ctrl::unix ?0\.1\.1?  

[__::term::ansi::ctrl::unix::import__ ?*ns*? ?*arg*\.\.\.?](#1)  
[__::term::ansi::ctrl::unix::raw__](#2)  
[__::term::ansi::ctrl::unix::cooked__](#3)  
[__::term::ansi::ctrl::unix::columns__](#4)  
[__::term::ansi::ctrl::unix::rows__](#5)  

# <a name='description'></a>DESCRIPTION

*WARNING*: This package is unix\-specific and depends on the availability of
two unix system commands for terminal control, i\.e\. __stty__ and
__tput__, both of which have to be found in the __$PATH__\. If any of
these two commands is missing the loading of the package will fail\.

The package provides commands to switch the standard input of the current
process between *[raw](\.\./\.\./\.\./\.\./index\.md\#raw)* and
*[cooked](\.\./\.\./\.\./\.\./index\.md\#cooked)* input modes, and to query the size
of terminals, i\.e\. the available number of columns and lines\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Introspection

  - <a name='1'></a>__::term::ansi::ctrl::unix::import__ ?*ns*? ?*arg*\.\.\.?

    This command imports some or all attribute commands into the namespace
    *ns*\. This is by default the namespace *ctrl*\. Note that this is
    relative namespace name, placing the imported command into a child of the
    current namespace\. By default all commands are imported, this can howver be
    restricted by listing the names of the wanted commands after the namespace
    argument\.

## <a name='subsection2'></a>Operations

  - <a name='2'></a>__::term::ansi::ctrl::unix::raw__

    This command switches the standard input of the current process to
    *[raw](\.\./\.\./\.\./\.\./index\.md\#raw)* input mode\. This means that from
    then on all characters typed by the user are immediately reported to the
    application instead of waiting in the OS buffer until the Enter/Return key
    is received\.

  - <a name='3'></a>__::term::ansi::ctrl::unix::cooked__

    This command switches the standard input of the current process to
    *[cooked](\.\./\.\./\.\./\.\./index\.md\#cooked)* input mode\. This means that
    from then on all characters typed by the user are kept in OS buffers for
    editing until the Enter/Return key is received\.

  - <a name='4'></a>__::term::ansi::ctrl::unix::columns__

    This command queries the terminal connected to the standard input for the
    number of columns available for display\.

  - <a name='5'></a>__::term::ansi::ctrl::unix::rows__

    This command queries the terminal connected to the standard input for the
    number of rows \(aka lines\) available for display\.

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
[columns](\.\./\.\./\.\./\.\./index\.md\#columns),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[cooked](\.\./\.\./\.\./\.\./index\.md\#cooked), [input
mode](\.\./\.\./\.\./\.\./index\.md\#input\_mode),
[lines](\.\./\.\./\.\./\.\./index\.md\#lines), [raw](\.\./\.\./\.\./\.\./index\.md\#raw),
[rows](\.\./\.\./\.\./\.\./index\.md\#rows),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
