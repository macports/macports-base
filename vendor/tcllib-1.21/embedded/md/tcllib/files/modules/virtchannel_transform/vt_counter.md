
[//000000001]: # (tcl::transform::counter \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'vt\_counter\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::transform::counter\(n\) 1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::transform::counter \- Counter transformation

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
package require tcl::transform::counter ?1?  

[__::tcl::transform::counter__ *chan* __\-option__ *value*\.\.\.](#1)  

# <a name='description'></a>DESCRIPTION

The __tcl::transform::counterr__ package provides a command creating a
channel transformation which passes the read and written bytes through unchanged
\(like __[tcl::transform::identity](identity\.md)__\), but additionally
counts the bytes it has seen for each direction and stores these counts in Tcl
variables specified at construction time\.

Related transformations in this module are
__[tcl::transform::adler32](adler32\.md)__,
__[tcl::transform::crc32](vt\_crc32\.md)__,
__[tcl::transform::identity](identity\.md)__, and
__[tcl::transform::observe](observe\.md)__\.

The internal __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing
the transform handler is a sub\-class of the
__[tcl::transform::core](\.\./virtchannel\_core/transformcore\.md)__
framework\.

# <a name='section2'></a>API

  - <a name='1'></a>__::tcl::transform::counter__ *chan* __\-option__ *value*\.\.\.

    This command creates a counter transformation on top of the channel *chan*
    and returns its handle\. The accepted options are

      * __\-read\-variable__ varname

        The value of the option is the name of a global or namespaced variable,
        the location where the transformation has to store the byte count of the
        data read from the channel\.

        If not specified, or the empty string, the counter of the read direction
        is not saved\.

      * __\-write\-variable__ varname

        The value of the option is the name of a global or namespaced variable,
        the location where the transformation has to store the byte count of the
        data written to the channel\.

        If not specified, or the empty string, the counter of the write
        direction is not saved\.

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
[counter](\.\./\.\./\.\./\.\./index\.md\#counter), [reflected
channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
230](\.\./\.\./\.\./\.\./index\.md\#tip\_230),
[transformation](\.\./\.\./\.\./\.\./index\.md\#transformation), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
