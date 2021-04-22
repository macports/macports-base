
[//000000001]: # (struct::queue \- Tcl Data Structures)
[//000000002]: # (Generated from file 'queue\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (struct::queue\(n\) 1\.4\.5 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::queue \- Create and manipulate queue objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require struct::queue ?1\.4\.5?  

[*queueName* __option__ ?*arg arg \.\.\.*?](#1)  
[*queueName* __clear__](#2)  
[*queueName* __destroy__](#3)  
[*queueName* __get__ ?*count*?](#4)  
[*queueName* __peek__ ?*count*?](#5)  
[*queueName* __put__ *item* ?*item \.\.\.*?](#6)  
[*queueName* __unget__ *item*](#7)  
[*queueName* __size__](#8)  

# <a name='description'></a>DESCRIPTION

The __::struct__ namespace contains a commands for processing finite queues\.

It exports a single command, __::struct::queue__\. All functionality provided
here can be reached through a subcommand of this command\.

*Note:* As of version 1\.4\.1 of this package a critcl based C implementation is
available\. This implementation however requires Tcl 8\.4 to run\.

The __::struct::queue__ command creates a new queue object with an
associated global Tcl command whose name is *queueName*\. This command may be
used to invoke various operations on the queue\. It has the following general
form:

  - <a name='1'></a>*queueName* __option__ ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\. The
    following commands are possible for queue objects:

  - <a name='2'></a>*queueName* __clear__

    Remove all items from the queue\.

  - <a name='3'></a>*queueName* __destroy__

    Destroy the queue, including its storage space and associated command\.

  - <a name='4'></a>*queueName* __get__ ?*count*?

    Return the front *count* items of the queue and remove them from the
    queue\. If *count* is not specified, it defaults to 1\. If *count* is 1,
    the result is a simple string; otherwise, it is a list\. If specified,
    *count* must be greater than or equal to 1\. If there are not enough items
    in the queue to fulfull the request, this command will throw an error\.

  - <a name='5'></a>*queueName* __peek__ ?*count*?

    Return the front *count* items of the queue, without removing them from
    the queue\. If *count* is not specified, it defaults to 1\. If *count* is
    1, the result is a simple string; otherwise, it is a list\. If specified,
    *count* must be greater than or equal to 1\. If there are not enough items
    in the queue to fulfull the request, this command will throw an error\.

  - <a name='6'></a>*queueName* __put__ *item* ?*item \.\.\.*?

    Put the *item* or items specified into the queue\. If more than one
    *item* is given, they will be added in the order they are listed\.

  - <a name='7'></a>*queueName* __unget__ *item*

    Put the *item* into the queue, at the front, i\.e\. before any other items
    already in the queue\. This makes this operation the complement to the method
    __get__\.

  - <a name='8'></a>*queueName* __size__

    Return the number of items in the queue\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: queue* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[graph](\.\./\.\./\.\./\.\./index\.md\#graph), [list](\.\./\.\./\.\./\.\./index\.md\#list),
[matrix](\.\./\.\./\.\./\.\./index\.md\#matrix),
[pool](\.\./\.\./\.\./\.\./index\.md\#pool),
[prioqueue](\.\./\.\./\.\./\.\./index\.md\#prioqueue),
[record](\.\./\.\./\.\./\.\./index\.md\#record), [set](\.\./\.\./\.\./\.\./index\.md\#set),
[skiplist](\.\./\.\./\.\./\.\./index\.md\#skiplist),
[stack](\.\./\.\./\.\./\.\./index\.md\#stack), [tree](\.\./\.\./\.\./\.\./index\.md\#tree)

# <a name='category'></a>CATEGORY

Data structures
