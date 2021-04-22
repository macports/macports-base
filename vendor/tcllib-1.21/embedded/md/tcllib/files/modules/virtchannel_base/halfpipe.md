
[//000000001]: # (tcl::chan::halfpipe \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'halfpipe\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009, 2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::halfpipe\(n\) 1\.0\.1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::halfpipe \- In\-memory channel, half of a fifo2

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Options](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require TclOO  
package require tcl::chan::events ?1?  
package require tcl::chan::halfpipe ?1\.0\.1?  

[__::tcl::chan::halfpipe__ ?__\-option__ *value*\.\.\.?](#1)  
[*objectCmd* __put__ *bytes*](#2)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::halfpipe__ package provides a command creating one half of
a __[tcl::chan::fifo2](tcllib\_fifo2\.md)__ pair\. Writing into such a
channel invokes a set of callbacks which then handle the data\. This is similar
to a channel handler, except having a much simpler API\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the channel handler is a sub\-class of the
__[tcl::chan::events](\.\./virtchannel\_core/events\.md)__ framework\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::chan::halfpipe__ ?__\-option__ *value*\.\.\.?

    This command creates a halfpipe channel and configures it with the callbacks
    to run when the channel is closed, data was written to it, or ran empty\. See
    the section [Options](#section3) for the list of options and associated
    semantics\. The result of the command is a list containing two elements, the
    handle of the new channel, and the object command of the channel handler, in
    this order\. The latter is supplied to the caller to provide her with access
    to the __put__ method for adding data to the channel\.

    Two halfpipes with a bit of glue logic in the callbacks make for one
    __[tcl::chan::fifo2](tcllib\_fifo2\.md)__\.

  - <a name='2'></a>*objectCmd* __put__ *bytes*

    This method of the channel handler object puts the data *bytes* into the
    channel so that it can be read from it\.

# <a name='section3'></a>Options

  - __\-close\-command__ cmdprefix

    This callback is invoked when the channel is closed\. A single argument is
    supplied, the handle of the channel being closed\. The result of the callback
    is ignored\.

  - __\-write\-command__ cmdprefix

    This callback is invoked when data is written to the channel\. Two arguments
    are supplied, the handle of the channel written to, and the data written\.
    The result of the callback is ignored\.

  - __\-empty\-command__ cmdprefix

    This callback is invoked when the channel has run out of data to read\. A
    single argument is supplied, the handle of the channel\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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

[callbacks](\.\./\.\./\.\./\.\./index\.md\#callbacks),
[fifo](\.\./\.\./\.\./\.\./index\.md\#fifo), [in\-memory
channel](\.\./\.\./\.\./\.\./index\.md\#in\_memory\_channel), [reflected
channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
219](\.\./\.\./\.\./\.\./index\.md\#tip\_219), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009, 2019 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
