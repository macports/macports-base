
[//000000001]: # (uri\_urn \- Tcl Uniform Resource Identifier Management)
[//000000002]: # (Generated from file 'urn\-scheme\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (uri\_urn\(n\) 1\.0\.3 tcllib "Tcl Uniform Resource Identifier Management")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uri\_urn \- URI utilities, URN scheme

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require uri::urn ?1\.0\.3?  

[__uri::urn::quote__ *url*](#1)  
[__uri::urn::unquote__ *url*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides two commands to quote and unquote the disallowed
characters for url using the *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)* scheme,
registers the scheme with the package __[uri](uri\.md)__, and provides
internal helpers which will be automatically used by the commands
__uri::split__ and __uri::join__ of package __[uri](uri\.md)__ to
handle urls using the *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)* scheme\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__uri::urn::quote__ *url*

    This command quotes the characters disallowed by the
    *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)* scheme \(per RFC 2141 sec2\.2\) in the
    *url* and returns the modified url as its result\.

  - <a name='2'></a>__uri::urn::unquote__ *url*

    This commands performs the reverse of __::uri::urn::quote__\. It takes an
    *[urn](\.\./\.\./\.\./\.\./index\.md\#urn)* url, removes the quoting from all
    disallowed characters, and returns the modified urls as its result\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *uri* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[rfc 2141](\.\./\.\./\.\./\.\./index\.md\#rfc\_2141),
[uri](\.\./\.\./\.\./\.\./index\.md\#uri), [url](\.\./\.\./\.\./\.\./index\.md\#url),
[urn](\.\./\.\./\.\./\.\./index\.md\#urn)

# <a name='category'></a>CATEGORY

Networking
