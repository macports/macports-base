
[//000000001]: # (term::send \- Terminal control)
[//000000002]: # (Generated from file 'term\_send\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::send\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::send \- General output to terminals

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
package require term::send ?0\.1?  

[__::term::send::wrch__ *chan* *str*](#1)  
[__::term::send::wr__ *str*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides the most primitive commands for sending characters to a
terminal\. They are in essence convenient wrappers around the builtin command
__puts__\.

  - <a name='1'></a>__::term::send::wrch__ *chan* *str*

    Send the text *str* to the channel specified by the handle *chan*\. In
    contrast to the builtin command __puts__ this command does not terminate
    the string with a line terminator\. It also forces an flush of Tcl internal
    and OS buffers to ensure that the characters are processed immediately\.

  - <a name='2'></a>__::term::send::wr__ *str*

    This convenience command is like __::term::send::wrch__, except that the
    destination channel is fixed to *stdout*\.

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

[character output](\.\./\.\./\.\./\.\./index\.md\#character\_output),
[control](\.\./\.\./\.\./\.\./index\.md\#control),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
