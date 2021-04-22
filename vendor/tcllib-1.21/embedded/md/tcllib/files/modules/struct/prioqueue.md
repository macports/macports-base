
[//000000001]: # (struct::prioqueue \- Tcl Data Structures)
[//000000002]: # (Generated from file 'prioqueue\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003 Michael Schlenker <mic42@users\.sourceforge\.net>)
[//000000004]: # (struct::prioqueue\(n\) 1\.4 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::prioqueue \- Create and manipulate prioqueue objects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::prioqueue ?1\.4?  

[__::struct::prioqueue__ ?__\-ascii&#124;\-dictionary&#124;\-integer&#124;\-real__? ?*prioqueueName*?](#1)  
[*prioqueueName* __option__ ?*arg arg \.\.\.*?](#2)  
[*prioqueueName* __clear__](#3)  
[*prioqueueName* __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *item*](#4)  
[*prioqueueName* __destroy__](#5)  
[*prioqueueName* __get__ ?*count*?](#6)  
[*prioqueueName* __peek__ ?*count*?](#7)  
[*prioqueueName* __peekpriority__ ?*count*?](#8)  
[*prioqueueName* __put__ *item prio* ?*item prio \.\.\.*?](#9)  
[*prioqueueName* __size__](#10)  

# <a name='description'></a>DESCRIPTION

This package implements a simple priority queue using nested tcl lists\.

The command __::struct::prioqueue__ creates a new priority queue with
default priority key type *\-integer*\. This means that keys given to the
__put__ subcommand must have this type\.

This also sets the priority ordering\. For key types *\-ascii* and
*\-dictionary* the data is sorted in ascending order \(as with __lsort__
*\-increasing*\), thereas for *\-integer* and *\-real* the data is sorted in
descending order \(as with __lsort__ *\-decreasing*\)\.

Prioqueue names are unrestricted, but may be recognized as options if no
priority type is given\.

  - <a name='1'></a>__::struct::prioqueue__ ?__\-ascii&#124;\-dictionary&#124;\-integer&#124;\-real__? ?*prioqueueName*?

    The __::struct::prioqueue__ command creates a new prioqueue object with
    an associated global Tcl command whose name is *prioqueueName*\. This
    command may be used to invoke various operations on the prioqueue\. It has
    the following general form:

  - <a name='2'></a>*prioqueueName* __option__ ?*arg arg \.\.\.*?

    __option__ and the *arg*s determine the exact behavior of the command\.
    The following commands are possible for prioqueue objects:

  - <a name='3'></a>*prioqueueName* __clear__

    Remove all items from the prioqueue\.

  - <a name='4'></a>*prioqueueName* __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *item*

    Remove the selected item from this priority queue\.

  - <a name='5'></a>*prioqueueName* __destroy__

    Destroy the prioqueue, including its storage space and associated command\.

  - <a name='6'></a>*prioqueueName* __get__ ?*count*?

    Return the front *count* items of the prioqueue \(but not their priorities\)
    and remove them from the prioqueue\. If *count* is not specified, it
    defaults to 1\. If *count* is 1, the result is a simple string; otherwise,
    it is a list\. If specified, *count* must be greater than or equal to 1\. If
    there are no or too few items in the prioqueue, this command will throw an
    error\.

  - <a name='7'></a>*prioqueueName* __peek__ ?*count*?

    Return the front *count* items of the prioqueue \(but not their
    priorities\), without removing them from the prioqueue\. If *count* is not
    specified, it defaults to 1\. If *count* is 1, the result is a simple
    string; otherwise, it is a list\. If specified, *count* must be greater
    than or equal to 1\. If there are no or too few items in the queue, this
    command will throw an error\.

  - <a name='8'></a>*prioqueueName* __peekpriority__ ?*count*?

    Return the front *count* items priority keys, without removing them from
    the prioqueue\. If *count* is not specified, it defaults to 1\. If *count*
    is 1, the result is a simple string; otherwise, it is a list\. If specified,
    *count* must be greater than or equal to 1\. If there are no or too few
    items in the queue, this command will throw an error\.

  - <a name='9'></a>*prioqueueName* __put__ *item prio* ?*item prio \.\.\.*?

    Put the *item* or items specified into the prioqueue\. *prio* must be a
    valid priority key for this type of prioqueue, otherwise an error is thrown
    and no item is added\. Items are inserted at their priority ranking\. Items
    with equal priority are added in the order they were added\.

  - <a name='10'></a>*prioqueueName* __size__

    Return the number of items in the prioqueue\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: prioqueue* of
the [Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also
report any ideas for enhancements you may have for either package and/or
documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[ordered list](\.\./\.\./\.\./\.\./index\.md\#ordered\_list),
[prioqueue](\.\./\.\./\.\./\.\./index\.md\#prioqueue), [priority
queue](\.\./\.\./\.\./\.\./index\.md\#priority\_queue)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003 Michael Schlenker <mic42@users\.sourceforge\.net>
