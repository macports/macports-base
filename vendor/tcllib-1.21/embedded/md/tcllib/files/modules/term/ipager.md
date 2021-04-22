
[//000000001]: # (term::interact::pager \- Terminal control)
[//000000002]: # (Generated from file 'ipager\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (term::interact::pager\(n\) 0\.1 tcllib "Terminal control")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

term::interact::pager \- Terminal widget, paging

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Class API](#section2)

  - [Object API](#section3)

  - [Configuration](#section4)

  - [Interaction](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require term::interact::pager ?0\.1?  

[__term::interact::pager__ *object* *text* ?*options*\.\.\.?](#1)  
[*object* __interact__](#2)  
[*object* __done__](#3)  
[*object* __clear__](#4)  
[*object* __text__ *text*](#5)  
[*object* __configure__](#6)  
[*object* __configure__ *option*](#7)  
[*object* __configure__ *option* *value*\.\.\.](#8)  
[*object* __cget__ *option*](#9)  

# <a name='description'></a>DESCRIPTION

This package provides a class for the creation of a simple paging text display\.

# <a name='section2'></a>Class API

The package exports a single command, the class command, enabling the creation
of pager instances\. Its API is:

  - <a name='1'></a>__term::interact::pager__ *object* *text* ?*options*\.\.\.?

    This command creates a new pager object with the name *object*,
    initializes it, and returns the fully qualified name of the object command
    as its result\.

    The argument is the text to show, possibly followed by configuration options
    and their values\. The options are explained in the section
    [Configuration](#section4)\.

# <a name='section3'></a>Object API

The objects created by the class command provide the methods listed below:

  - <a name='2'></a>*object* __interact__

    Show the pager in the screen at the configured location and start
    interacting with it\. This opens its own event loop for the processing of
    incoming characters\. The method returns when the interaction has completed\.
    See section [Interaction](#section5) for a description of the possible
    interaction\.

  - <a name='3'></a>*object* __done__

    This method can be used by user supplied actions to terminate the
    interaction with the object\.

  - <a name='4'></a>*object* __clear__

    This method can be used by user supplied actions to remove the pager from
    the terminal\.

  - <a name='5'></a>*object* __text__ *text*

    This method can be used to change the text shown by the pager\. The pager
    will reset the dispay to show the first line of the text at the top\.

  - <a name='6'></a>*object* __configure__

  - <a name='7'></a>*object* __configure__ *option*

  - <a name='8'></a>*object* __configure__ *option* *value*\.\.\.

  - <a name='9'></a>*object* __cget__ *option*

    Standard methods to retrieve and configure the options of the pager\.

# <a name='section4'></a>Configuration

A pager instance recognizes the following options:

  - __\-in__ chan

    Specifies the channel to read character sequences from\. Defaults to
    __stdin__\.

  - __\-out__ chan

    Specifies the channel to write the pager contents to\. Defaults to
    __stdout__\.

  - __\-column__ int

    Specifies the column of the terminal where the left margin of the pager
    display should appear\. Defaults to 0, i\.e\. the left\-most column\.

  - __\-line__ int

    Specifies the line of the terminal where the top margin of the pager display
    should appear\. Defaults to 0, i\.e\. the top\-most line\.

  - __\-height__ int

    Specifies the number of lines of text to show at most in the display\.
    Defaults to 25\.

  - __\-actions__ dict

    Specifies a dictionary containing additional actions, using character
    sequences as keys\. Note that these sequences cannot override the hardwired
    sequences described in section [Interaction](#section5)\.

# <a name='section5'></a>Interaction

A pager object recognizes the control sequences listed below and acts as
described\. The user can supply more control sequences to act on via the
configuration, but is not able to overide these defaults\.

  - Cursor Up

    The text is scrolled down a single line, making one more line visible at the
    top\. The pager will not react if the first line of the text is already
    shown\.

  - Cursor Down

    The text is scrolled up a single line, making one more line visible at the
    bottom\. The pager will not react if the last line of the text is already
    shown\.

  - Page Up

    The text is scrolled down a page\. The pager will not react if the first line
    of the text is already shown\.

  - Page Down

    The text is scrolled up a page\. The pager will not react if the last line of
    the text is already shown\.

  - Enter/Return

    The interaction with the object is terminated\.

# <a name='section6'></a>Bugs, Ideas, Feedback

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
[pager](\.\./\.\./\.\./\.\./index\.md\#pager),
[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal), [text
display](\.\./\.\./\.\./\.\./index\.md\#text\_display)

# <a name='category'></a>CATEGORY

Terminal control

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
