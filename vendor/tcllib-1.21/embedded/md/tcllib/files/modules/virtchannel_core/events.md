
[//000000001]: # (tcl::chan::events \- Reflected/virtual channel support)
[//000000002]: # (Generated from file 'events\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tcl::chan::events\(n\) 1 tcllib "Reflected/virtual channel support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tcl::chan::events \- Event support for reflected/virtual channels

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
package require tcl::chan::events ?1?  

[__::tcl::chan::events__ *objectName*](#1)  
[*objectName* __finalize__ *thechannel*](#2)  
[*objectName* __watch__ *thechannel* *eventmask*](#3)  
[*objectName* __allow__ *eventname*\.\.\.](#4)  
[*objectName* __disallow__ *eventname*\.\.\.](#5)  

# <a name='description'></a>DESCRIPTION

The __tcl::chan::events__ package provides a
__[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__ class implementing common
behaviour needed by virtually every reflected or virtual channel supporting
event driven IO\. It is a sub\-class of __[tcl::chan::core](core\.md)__,
inheriting all of its behaviour\.

This class expects to be used as either superclass of a concrete channel class,
or to be mixed into such a class\.

# <a name='section2'></a>Class API

  - <a name='1'></a>__::tcl::chan::events__ *objectName*

    This command creates a new channel event core object with an associated
    global Tcl command whose name is *objectName*\. This command may be used to
    invoke various operations on the object, as described in the section for the
    [Instance API](#section3)\.

# <a name='section3'></a>Instance API

The API of channel event core instances provides only four methods, two
corresponding to channel handler commands \(For reference see [TIP
219](http:/tip\.tcl\.tk/219)\), and the other two for use by sub\-classes to
control event generation\. They former expect to be called from whichever object
instance the channel event core was made a part of\.

  - <a name='2'></a>*objectName* __finalize__ *thechannel*

    This method implements standard behaviour for the __finalize__ method of
    channel handlers\. It overrides the behaviour inherited from
    __[tcl::chan::core](core\.md)__ and additionally disables any and all
    event generation before destroying itself\.

  - <a name='3'></a>*objectName* __watch__ *thechannel* *eventmask*

    This method implements standard behaviour for the __watch__ method of
    channel handlers\. Called by the IO system whenever the interest in event
    changes it updates the instance state to activate and/or suppress the
    generation of the events of \(non\-\)interest\.

  - <a name='4'></a>*objectName* __allow__ *eventname*\.\.\.

  - <a name='5'></a>*objectName* __disallow__ *eventname*\.\.\.

    These two methods are exported to sub\-classes, so that their instances can
    notify their event core of the events the channel they implement can \(allow\)
    or cannot \(disallow\) generate\. Together with the information about the
    events requested by Tcl's IO system coming in through the __watch__
    method the event core is able to determine which events it should \(not\)
    generate and act accordingly\.

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

[event management](\.\./\.\./\.\./\.\./index\.md\#event\_management), [reflected
channel](\.\./\.\./\.\./\.\./index\.md\#reflected\_channel), [tip
219](\.\./\.\./\.\./\.\./index\.md\#tip\_219), [virtual
channel](\.\./\.\./\.\./\.\./index\.md\#virtual\_channel)

# <a name='category'></a>CATEGORY

Channels

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
