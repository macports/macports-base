
[//000000001]: # (tcl::transform::identity \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'identity\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::transform::identity\(n\) 1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::transform::identity \- Identity transformation

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

package require Tcl 8\.6  
package require tcl::transform::core ?1?  
package require tcl::transform::identity ?1?  

[__::tcl::transform::identity__ *chan*](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::transform::identity__ package provides a command creating an
identity channel transformation, which does nothing but pass the read and
written bytes through it unchanged\. Not really useful in an application, however
as the prototypical observer transformation its code is a useful starting point
for any other observers people may wish to write\.

The transformations in this module which derived from identity's code are
__[tcl::transform::adler32](adler32\.md)__,
__[tcl::transform::counter](vt\_counter\.md)__,
__[tcl::transform::crc32](vt\_crc32\.md)__, and
__[tcl::transform::observe](observe\.md)__\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the transform handler is a sub\-class of the
__[tcl::transform::core](\.\./virtchannel\_core/transformcore\.md)__
framework\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::transform::identity__ *chan*

    This command creates an identity transformation on top of the channel
    *chan* and returns its handle\.

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

[channel transformation](\.\./\.\./\.\./\.\./index\.md\#channel\_transformation),
[identity](\.\./\.\./\.\./\.\./index\.md\#identity), [reflected
channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
230](\.\./\.\./\.\./\.\./index\.md\#tip\_230),
[transformation](\.\./\.\./\.\./\.\./index\.md\#transformation), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
