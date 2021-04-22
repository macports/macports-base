
[//000000001]: # (coroutine::auto \- Coroutine utilities)
[//000000002]: # (Generated from file 'coro\_auto\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010\-2014 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (coroutine::auto\(n\) 1\.2 tcllib "Coroutine utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

coroutine::auto \- Automatic event and IO coroutine awareness

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require coroutine::auto 1\.2  
package require coroutine 1\.3  

# <a name='description'></a>DESCRIPTION

The __coroutine::auto__ package provides no commands or other directly
visible functionality\. Built on top of the package
__[coroutine](tcllib\_coroutine\.md)__, it intercepts various builtin
commands of the Tcl core to make any code using them coroutine\-oblivious, i\.e\.
able to run inside and outside of a coroutine without changes\.

The commands so affected by this package are

  - __[after](\.\./\.\./\.\./\.\./index\.md\#after)__

  - __[exit](\.\./\.\./\.\./\.\./index\.md\#exit)__

  - __[gets](\.\./\.\./\.\./\.\./index\.md\#gets)__

  - __[global](\.\./\.\./\.\./\.\./index\.md\#global)__

  - __puts__

  - __[read](\.\./\.\./\.\./\.\./index\.md\#read)__

  - __[socket](\.\./\.\./\.\./\.\./index\.md\#socket)__

  - __[update](\.\./\.\./\.\./\.\./index\.md\#update)__

  - __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *coroutine* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[after](\.\./\.\./\.\./\.\./index\.md\#after),
[channel](\.\./\.\./\.\./\.\./index\.md\#channel),
[coroutine](\.\./\.\./\.\./\.\./index\.md\#coroutine),
[events](\.\./\.\./\.\./\.\./index\.md\#events),
[exit](\.\./\.\./\.\./\.\./index\.md\#exit), [gets](\.\./\.\./\.\./\.\./index\.md\#gets),
[global](\.\./\.\./\.\./\.\./index\.md\#global), [green
threads](\.\./\.\./\.\./\.\./index\.md\#green\_threads),
[read](\.\./\.\./\.\./\.\./index\.md\#read),
[threads](\.\./\.\./\.\./\.\./index\.md\#threads),
[update](\.\./\.\./\.\./\.\./index\.md\#update),
[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)

# <a name='category'></a>CATEGORY

Coroutine

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010\-2014 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
