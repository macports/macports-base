
[//000000001]: # (tcl::chan::cat \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'cat\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::cat\(n\) 1\.0\.3 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::cat \- Concatenation channel

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
package require tcl::chan::core ?1?  
package require tcl::chan::cat ?1\.0\.3?  

[__::tcl::chan::cat__ *chan*\.\.\.](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::cat__ package provides a command creating concatenation
channels\. These are non\-seekable channels owning a list of subordinate channels
whose contents they return in order, until all are exhausted\. In this manner the
channel is the concatentation of the contents of all the sub\-ordinate channels\.

Note that the created channels take ownership of the channels they were
constructed with\. Whenever they have exhausted one of their channel it will be
closed\. Similarly, closing the cat channel will close all the sub\-ordinates it
still has\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the channel handler is a sub\-class of the
__[tcl::chan::core](\.\./virtchannel\_core/core\.md)__ framework\.

Event handling is delegated to the currently active sub\-channel\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::chan::cat__ *chan*\.\.\.

    This command creates the concatenation channel using all the provided
    channels, and returns its handle\.

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
