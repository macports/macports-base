
[//000000001]: # (tcl::chan::facade \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'facade\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::facade\(n\) 1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::facade \- Facade channel

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require TclOO  
package require logger  
package require tcl::chan::core ?1?  
package require tcl::chan::facade ?1?  

[__::tcl::chan::facade__ *chan*](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::facade__ package provides a command creating facades to
other channels\. These are channels which own a single subordinate channel and
delegate all operations to\.

The main use for facades is the debugging of actions on a channel\. While most of
the information could be tracked by a virtual channel transformation it does not
have access to the event\-related operation, and furthermore they are only
available in Tcl 8\.6\.

Therefore this channel, usable with Tcl 8\.5, and having access to everything
going on for a channel\.

The intercepted actions on channel are logged through package
__[logger](\.\./log/logger\.md)__\.

Beyond that facades provide the following additional channel configuration
options:

  - __\-self__

    The TclOO object handling the facade\.

  - __\-fd__

    The handle of the subordinate, i\.e\. wrapped channel\.

  - __\-used__

    The last time the wrapped channel was read from or written to by the facade,
    as per __clock milliseconds__\. A value of __0__ indicates that the
    subordinate channel was not accessed at all, yet\.

  - __\-created__

    The time the facade was created, as per __clock milliseconds__\.

  - __\-user__

    A free\-form value identifying the user of the facade and its wrapped
    channel\.

Of these only option __\-user__ is writable\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::chan::facade__ *chan*

    This command creates the facade channel around the provided channel
    *chan*, and returns its handle\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *virtchannel* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[concatenation channel](\.\./\.\./\.\./\.\./index\.md\#concatenation\_channel),
[reflected channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
219](\.\./\.\./\.\./\.\./index\.md\#tip\_219), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
