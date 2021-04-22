
[//000000001]: # (ident \- Identification protocol client)
[//000000002]: # (Generated from file 'ident\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Reinhard Max <max@tclers\.tk>)
[//000000004]: # (ident\(n\) 0\.42 tcllib "Identification protocol client")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ident \- Ident protocol client

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require ident ?0\.42?  

[__::ident::query__ *socket* ?*callback*?](#1)  

# <a name='description'></a>DESCRIPTION

The __ident__ package provides a client implementation of the ident protocol
as defined in RFC 1413
\([http://www\.rfc\-editor\.org/rfc/rfc1413\.txt](http://www\.rfc\-editor\.org/rfc/rfc1413\.txt)\)\.

  - <a name='1'></a>__::ident::query__ *socket* ?*callback*?

    This command queries the ident daemon on the remote side of the given
    socket, and returns the result of the query as a dictionary\. Interpreting
    the dictionary as list the first key will always be __resp\-type__, and
    can have one of the values __USERID__, __ERROR__, and __FATAL__\.
    These *response types* have the following meanings:

      * USERID

        This indicates a successful response\. Two more keys and associated
        values are returned, __opsys__, and __user\-id__\.

      * ERROR

        This means the ident server has returned an error\. A second key named
        __error__ is present whose value contains the __error\-type__
        field from the server response\.

      * FATAL

        Fatal errors happen when no ident server is listening on the remote
        side, or when the ident server gives a response that does not conform to
        the RFC\. A detailed error message is returned under the __error__
        key\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ident* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[ident](\.\./\.\./\.\./\.\./index\.md\#ident),
[identification](\.\./\.\./\.\./\.\./index\.md\#identification), [rfc
1413](\.\./\.\./\.\./\.\./index\.md\#rfc\_1413)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Reinhard Max <max@tclers\.tk>
