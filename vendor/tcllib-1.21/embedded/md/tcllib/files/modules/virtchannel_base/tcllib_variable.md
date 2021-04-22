
[//000000001]: # (tcl::chan::variable \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'tcllib\_variable\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::variable\(n\) 1\.0\.4 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::variable \- In\-memory channel using variable for storage

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
package require tcl::chan::variable ?1\.0\.4?  

[__::tcl::chan::variable__ *varname*](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::variable__ package provides a command creating channels
which live purely in memory\. They provide random\-access, i\.e\. are seekable\. In
contrast to the channels created by
__[tcl::chan::memchan](tcllib\_memchan\.md)__ the data is not hidden in
the channel however, but stored in an associated variable, specified at the time
of construction\.

Packages related to this are __[tcl::chan::memchan](tcllib\_memchan\.md)__
and __[tcl::chan::string](tcllib\_string\.md)__\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the channel handler is a sub\-class of the
__[tcl::chan::events](\.\./virtchannel\_core/events\.md)__ framework\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::chan::variable__ *varname*

    This command creates a new variable channel and returns its handle\. The
    content of the channel is stored in the associated namespace variable
    *varname*\.

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

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
