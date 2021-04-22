
[//000000001]: # (deleg\_proc \- Interpreter utilities)
[//000000002]: # (Generated from file 'deleg\_proc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (deleg\_proc\(n\) 0\.2 tcllib "Interpreter utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

deleg\_proc \- Creation of comm delegates \(procedures\)

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

package require Tcl 8\.3  
package require interp::delegate::proc ?0\.2?  

[__::interp::delegate::proc__ ?__\-async__? *name* *arguments* *comm* *id*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a single command for the convenient creation of procedures
which delegate the actual work to a remote location via a "channel" created by
the package __[comm](\.\./comm/comm\.md)__\.

# <a name='section2'></a>API

  - <a name='1'></a>__::interp::delegate::proc__ ?__\-async__? *name* *arguments* *comm* *id*

    This commands creates a procedure which is named by *name* and returns its
    fully\-qualified name\. All invokations of this procedure will delegate the
    actual work to the remote location identified by the comm channel *comm*
    and the endpoint *id*\.

    The name of the remote procedure invoked by the delegator is \[namespace tail
    *name*\]\. I\.e\., namespace information is stripped from the call\.

    Normally the generated procedure marshalls the *arguments*, and returns
    the result from the remote procedure as its own result\. If however the
    option __\-async__ was specified then the generated procedure will not
    wait for a result and return immediately\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *interp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[comm](\.\./\.\./\.\./\.\./index\.md\#comm),
[delegation](\.\./\.\./\.\./\.\./index\.md\#delegation),
[interpreter](\.\./\.\./\.\./\.\./index\.md\#interpreter),
[procedure](\.\./\.\./\.\./\.\./index\.md\#procedure)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
