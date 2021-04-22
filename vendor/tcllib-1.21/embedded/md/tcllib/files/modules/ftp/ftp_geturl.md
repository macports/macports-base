
[//000000001]: # (ftp::geturl \- ftp client)
[//000000002]: # (Generated from file 'ftp\_geturl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (ftp::geturl\(n\) 0\.2\.2 tcllib "ftp client")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ftp::geturl \- Uri handler for ftp urls

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require ftp::geturl ?0\.2\.2?  

[__::ftp::geturl__ *url*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a command which wraps around the client side of the
*[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)* protocol provided by package
__[ftp](ftp\.md)__ to allow the retrieval of urls using the
*[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)* schema\.

# <a name='section2'></a>API

  - <a name='1'></a>__::ftp::geturl__ *url*

    This command can be used by the generic command __::uri::geturl__ \(See
    package __[uri](\.\./uri/uri\.md)__\) to retrieve the contents of ftp
    urls\. Internally it uses the commands of the package
    __[ftp](ftp\.md)__ to fulfill the request\.

    The contents of a *[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp)* url are defined as
    follows:

      * *[file](\.\./\.\./\.\./\.\./index\.md\#file)*

        The contents of the specified file itself\.

      * *directory*

        A listing of the contents of the directory in key value notation where
        the file name is the key and its attributes the associated value\.

      * *link*

        The attributes of the link, including the path it refers to\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ftp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[ftpd](\.\./ftpd/ftpd\.md), [mime](\.\./mime/mime\.md),
[pop3](\.\./pop3/pop3\.md), [smtp](\.\./mime/smtp\.md)

# <a name='keywords'></a>KEYWORDS

[ftp](\.\./\.\./\.\./\.\./index\.md\#ftp),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[net](\.\./\.\./\.\./\.\./index\.md\#net), [rfc 959](\.\./\.\./\.\./\.\./index\.md\#rfc\_959)

# <a name='category'></a>CATEGORY

Networking
