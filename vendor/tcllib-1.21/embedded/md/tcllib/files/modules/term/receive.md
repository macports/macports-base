
[//000000001]: # (term::receive \- Terminal control)
[//000000002]: # (Generated from file 'receive\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::receive\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::receive \- General input from terminals

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
package require term::receive ?0\.1?  

[__::term::receive::getch__ ?*chan*?](#1)  
[__::term::receive::listen__ *cmd* ?*chan*?](#2)  
[*cmd* __process__ *string*](#3)  
[*cmd* __eof__](#4)  
[__::term::receive::unlisten__ ?*chan*?](#5)  

# <a name='description'></a>DESCRIPTION

This package provides the most primitive commands for receiving characters to a
terminal\. They are in essence convenient wrappers around the builtin commands
__[read](\.\./\.\./\.\./\.\./index\.md\#read)__ and __fileevent__\.

  - <a name='1'></a>__::term::receive::getch__ ?*chan*?

    This command reads a single character from the channel with handle *chan*
    and returns it as the result of the command\.

    If not specified *chan* defaults to __stdin__\.

    It is the responsibility of the caller to make sure that the channel can
    provide single characters\. On unix this can be done, for example, by using
    the command of package __[term::ansi::ctrl::unix](ansi\_ctrlu\.md)__\.

  - <a name='2'></a>__::term::receive::listen__ *cmd* ?*chan*?

    This command sets up a filevent listener for the channel with handle
    *chan* and invokes the command prefix *cmd* whenever characters have
    been received, or EOF was reached\.

    If not specified *chan* defaults to __stdin__\.

    The signature of the command prefix is

      * <a name='3'></a>*cmd* __process__ *string*

        This method is invoked when characters were received, and *string*
        holds them for processing\.

      * <a name='4'></a>*cmd* __eof__

        This method is invoked when EOF was reached on the channel we listen on\.
        It will be the last call to be received by the callback\.

  - <a name='5'></a>__::term::receive::unlisten__ ?*chan*?

    This command disables the filevent listener for the channel with handle
    *chan*\.

    If not specified *chan* defaults to __stdin__\.

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

[character input](\.\./\.\./\.\./\.\./index\.md\#character\_input),
[control](\.\./\.\./\.\./\.\./index\.md\#control), [get
character](\.\./\.\./\.\./\.\./index\.md\#get\_character),
[listener](\.\./\.\./\.\./\.\./index\.md\#listener),
[receiver](\.\./\.\./\.\./\.\./index\.md\#receiver),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
