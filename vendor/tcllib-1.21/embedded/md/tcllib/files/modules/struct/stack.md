
[//000000001]: # (struct::stack \- Tcl Data Structures)
[//000000002]: # (Generated from file 'stack\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (struct::stack\(n\) 1\.5\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::stack \- Create and manipulate stack objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require struct::stack ?1\.5\.3?  

[*stackName* __option__ ?*arg arg \.\.\.*?](#1)  
[*stackName* __clear__](#2)  
[*stackName* __destroy__](#3)  
[*stackName* __get__](#4)  
[*stackName* __getr__](#5)  
[*stackName* __peek__ ?*count*?](#6)  
[*stackName* __peekr__ ?*count*?](#7)  
[*stackName* __trim__ ?*newsize*?](#8)  
[*stackName* __trim\*__ ?*newsize*?](#9)  
[*stackName* __pop__ ?*count*?](#10)  
[*stackName* __push__ *item* ?*item\.\.\.*?](#11)  
[*stackName* __size__](#12)  

# <a name='description'></a>DESCRIPTION

The __::struct__ namespace contains a commands for processing finite stacks\.

It exports a single command, __::struct::stack__\. All functionality provided
here can be reached through a subcommand of this command\.

*Note:* As of version 1\.3\.3 of this package a critcl based C implementation is
available\. This implementation however requires Tcl 8\.4 to run\.

The __::struct::stack__ command creates a new stack object with an
associated global Tcl command whose name is *stackName*\. This command may be
used to invoke various operations on the stack\. It has the following general
form:

  - <a name='1'></a>*stackName* __option__ ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\. The
    following commands are possible for stack objects:

  - <a name='2'></a>*stackName* __clear__

    Remove all items from the stack\.

  - <a name='3'></a>*stackName* __destroy__

    Destroy the stack, including its storage space and associated command\.

  - <a name='4'></a>*stackName* __get__

    Returns the whole contents of the stack as a list, without removing them
    from the stack\.

  - <a name='5'></a>*stackName* __getr__

    A variant of __get__, which returns the contents in reversed order\.

  - <a name='6'></a>*stackName* __peek__ ?*count*?

    Return the top *count* items of the stack, without removing them from the
    stack\. If *count* is not specified, it defaults to 1\. If *count* is 1,
    the result is a simple string; otherwise, it is a list\. If specified,
    *count* must be greater than or equal to 1\. If there are not enoughs items
    on the stack to fulfull the request, this command will throw an error\.

  - <a name='7'></a>*stackName* __peekr__ ?*count*?

    A variant of __peek__, which returns the items in reversed order\.

  - <a name='8'></a>*stackName* __trim__ ?*newsize*?

    Shrinks the stack to contain at most *newsize* elements and returns a list
    containing the elements which were removed\. Nothing is done if the stack is
    already at the specified size, or smaller\. In that case the result is the
    empty list\.

  - <a name='9'></a>*stackName* __trim\*__ ?*newsize*?

    A variant of __trim__ which performs the shrinking, but does not return
    the removed elements\.

  - <a name='10'></a>*stackName* __pop__ ?*count*?

    Return the top *count* items of the stack, and remove them from the stack\.
    If *count* is not specified, it defaults to 1\. If *count* is 1, the
    result is a simple string; otherwise, it is a list\. If specified, *count*
    must be greater than or equal to 1\. If there are not enoughs items on the
    stack to fulfull the request, this command will throw an error\.

  - <a name='11'></a>*stackName* __push__ *item* ?*item\.\.\.*?

    Push the *item* or items specified onto the stack\. If more than one
    *item* is given, they will be pushed in the order they are listed\.

  - <a name='12'></a>*stackName* __size__

    Return the number of items on the stack\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: stack* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[graph](\.\./\.\./\.\./\.\./index\.md\#graph),
[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[queue](\.\./\.\./\.\./\.\./index\.md\#queue), [tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Data structures
