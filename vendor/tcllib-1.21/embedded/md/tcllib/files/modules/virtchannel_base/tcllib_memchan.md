
[//000000001]: # (tcl::chan::memchan \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'tcllib\_memchan\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009\-2017 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::memchan\(n\) 1\.0\.4 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::memchan \- In\-memory channel

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
package require tcl::chan::events ?1?  
package require tcl::chan::memchan ?1\.0\.4?  

[__::tcl::chan::memchan__](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::memchan__ package provides a command creating channels
which live purely in memory\. They provide random\-access, i\.e\. are seekable\. This
is equivalent to the memchan channels provided by the package __Memchan__,
except that this is written in pure Tcl, not C\. On the other hand,
__Memchan__ is usable with Tcl 8\.4 and before, whereas this package requires
Tcl 8\.5 or higher, and __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__\.

Packages related to this are __[tcl::chan::string](tcllib\_string\.md)__
and __[tcl::chan::variable](tcllib\_variable\.md)__\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the channel handler is a sub\-class of the
__[tcl::chan::events](\.\./virtchannel\_core/events\.md)__ framework\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::chan::memchan__

    This command creates a new memchan channel and returns its handle\.

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

[in\-memory channel](\.\./\.\./\.\./\.\./index\.md\#in\_memory\_channel), [reflected
channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
219](\.\./\.\./\.\./\.\./index\.md\#tip\_219), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009\-2017 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
