
[//000000001]: # (term::ansi::code \- Terminal control)
[//000000002]: # (Generated from file 'ansi\_code\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::ansi::code\(n\) 0\.2 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::ansi::code \- Helper for control sequences

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::ansi::code ?0\.2?  

[__::term::ansi::code::esc__ *str*](#1)  
[__::term::ansi::code::escb__ *str*](#2)  
[__::term::ansi::code::define__ *name* *escape* *code*](#3)  
[__::term::ansi::code::const__ *name* *code*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides commands enabling the definition of control sequences in
an easy manner\.

  - <a name='1'></a>__::term::ansi::code::esc__ *str*

    This command returns the argument string, prefixed with the ANSI escape
    character, "\\033\."

  - <a name='2'></a>__::term::ansi::code::escb__ *str*

    This command returns the argument string, prefixed with a common ANSI escape
    sequence, "\\033\["\.

  - <a name='3'></a>__::term::ansi::code::define__ *name* *escape* *code*

    This command defines a procedure *name* which returns the control sequence
    *code*, beginning with the specified escape sequence, either __esc__,
    or __escb__\.

  - <a name='4'></a>__::term::ansi::code::const__ *name* *code*

    This command defines a procedure *name* which returns the control sequence
    *code*\.

# <a name='section2'></a>Bugs, Ideas, Feedback

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

[control](\.\./\.\./\.\./\.\./index\.md\#control),
[declare](\.\./\.\./\.\./\.\./index\.md\#declare),
[define](\.\./\.\./\.\./\.\./index\.md\#define),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
