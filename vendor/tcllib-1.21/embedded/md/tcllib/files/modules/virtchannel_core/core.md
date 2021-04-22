
[//000000001]: # (tcl::chan::core \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'core\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::core\(n\) 1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::core \- Basic reflected/virtual channel support

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Class API](#section2)

  - [Instance API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require TclOO  
package require tcl::chan::core ?1?  

[__::tcl::chan::core__ *objectName*](#1)  
[*objectName* __initialize__ *thechannel* *mode*](#2)  
[*objectName* __finalize__ *thechannel*](#3)  
[*objectName* __destroy__](#4)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::core__ package provides a
__[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing common
behaviour needed by virtually every reflected or virtual channel
\(initialization, finalization\)\.

This class expects to be used as either superclass of a concrete channel class,
or to be mixed into such a class\.

# <a name='section2'></a>Class API

  - <a name='1'></a>__::tcl::chan::core__ *objectName*

    This command creates a new channel core object with an associated global Tcl
    command whose name is *objectName*\. This command may be used to invoke
    various operations on the object, as described in the section for the
    [Instance API](#section3)\.

# <a name='section3'></a>Instance API

The API of channel core instances provides only two methods, both corresponding
to channel handler commands \(For reference see [TIP
219](http:/tip\.tcl\.tk/219)\)\. They expect to be called from whichever object
instance the channel core was made a part of\.

  - <a name='2'></a>*objectName* __initialize__ *thechannel* *mode*

    This method implements standard behaviour for the __initialize__ method
    of channel handlers\. Using introspection it finds the handler methods
    supported by the instance and returns a list containing their names, as
    expected by the support for reflected channels in the Tcl core\.

    It further remembers the channel handle in an instance variable for access
    by sub\-classes\.

  - <a name='3'></a>*objectName* __finalize__ *thechannel*

    This method implements standard behaviour for the __finalize__ method of
    channel handlers\. It simply destroys itself\.

  - <a name='4'></a>*objectName* __destroy__

    Destroying the channel core instance closes the channel it was initialized
    for, see the method __initialize__\. When destroyed from within a call of
    __finalize__ this does not happen, under the assumption that the channel
    is being destroyed by Tcl\.

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

[reflected channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
219](\.\./\.\./\.\./\.\./index\.md\#tip\_219), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
