
[//000000001]: # (debug::heartbeat \- debug narrative)
[//000000002]: # (Generated from file 'debug\_heartbeat\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 200?, Colin McCormack, Wub Server Utilities)
[//000000004]: # (Copyright &copy; 2012, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (debug::heartbeat\(n\) 1\.0\.1 tcllib "debug narrative")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

debug::heartbeat \- debug narrative \- heartbeat

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
package require debug::heartbeat ?1\.0\.1?  
package require debug ?1?  

[__[debug](debug\.md)__ __heartbeat__ ?*delta*?](#1)  

# <a name='description'></a>DESCRIPTION

# <a name='section2'></a>API

  - <a name='1'></a>__[debug](debug\.md)__ __heartbeat__ ?*delta*?

    This method activates or disables a heartbeat with which to monitor the
    event loop of an event\-based Tcl application\.

    It reserves the debug tag __heartbeat__ for its operation and writes a
    message every *delta* milliseconds\.

    A *delta*\-value <= 0 disables the heartbeat\.

    The message produced by the heartbeat contains a sequence counter and the
    time in milliseconds since the last beat, thus providing insight into timing
    variationsn and deviations from the nominal *delta*\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *debug* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[debug](\.\./\.\./\.\./\.\./index\.md\#debug),
[heartbeat](\.\./\.\./\.\./\.\./index\.md\#heartbeat),
[log](\.\./\.\./\.\./\.\./index\.md\#log),
[narrative](\.\./\.\./\.\./\.\./index\.md\#narrative),
[trace](\.\./\.\./\.\./\.\./index\.md\#trace)

# <a name='category'></a>CATEGORY

debugging, tracing, and logging

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 200?, Colin McCormack, Wub Server Utilities  
Copyright &copy; 2012, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
