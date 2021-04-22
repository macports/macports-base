
[//000000001]: # (uevent::onidle \- User events)
[//000000002]: # (Generated from file 'uevent\_onidle\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (uevent::onidle\(n\) 0\.1 tcllib "User events")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uevent::onidle \- Request merging and deferal to idle time

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Examples](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require uevent::onidle ?0\.1?  
package require logger  

[__::uevent::onidle__ *objectName* *commandprefix*](#1)  
[*objectName* __request__](#2)  

# <a name='description'></a>DESCRIPTION

This package provides objects which can merge multiple requestes for an action
and execute the action the moment the system \(event loop\) becomes idle\. The
action to be run is configured during object construction\.

# <a name='section2'></a>API

The package exports a class, __uevent::onidle__, as specified below\.

  - <a name='1'></a>__::uevent::onidle__ *objectName* *commandprefix*

    The command creates a new *onidle* object with an associated global Tcl
    command whose name is *objectName*\. This command may be used to invoke
    various operations on the object\.

    The *commandprefix* is the action to perform when the event loop is idle
    and the user asked for it using the method __request__ \(See below\)\.

The object commands created by the class commands above have the form:

  - <a name='2'></a>*objectName* __request__

    This method requests the execution of the command prefix specified during
    the construction of *objectName* the next time the event loop is idle\.
    Multiple requests are merged and cause only one execution of the command
    prefix\.

# <a name='section3'></a>Examples

Examples of this type of deferal are buried in the \(C\-level\) implementations all
the Tk widgets, defering geometry calculations and window redraw activity in
this manner\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *uevent* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[callback](\.\./\.\./\.\./\.\./index\.md\#callback),
[deferal](\.\./\.\./\.\./\.\./index\.md\#deferal),
[event](\.\./\.\./\.\./\.\./index\.md\#event), [idle](\.\./\.\./\.\./\.\./index\.md\#idle),
[merge](\.\./\.\./\.\./\.\./index\.md\#merge),
[on\-idle](\.\./\.\./\.\./\.\./index\.md\#on\_idle)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
