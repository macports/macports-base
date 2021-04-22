
[//000000001]: # (SASL::XGoogleToken \- Simple Authentication and Security Layer \(SASL\))
[//000000002]: # (Generated from file 'gtoken\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (SASL::XGoogleToken\(n\) 1\.0\.1 tcllib "Simple Authentication and Security Layer \(SASL\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

SASL::XGoogleToken \- Implementation of SASL NTLM mechanism for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [TLS Security Considerations](#section2)

  - [AUTHORS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require SASL::XGoogleToken ?1\.0\.1?  

# <a name='description'></a>DESCRIPTION

This package provides the XGoogleToken authentication mechanism for the Simple
Authentication and Security Layer \(SASL\)\.

Please read the documentation for package __sasl__ for details\.

# <a name='section2'></a>TLS Security Considerations

This package uses the __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package to
handle the security for __https__ urls and other socket connections\.

Policy decisions like the set of protocols to support and what ciphers to use
are not the responsibility of __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__, nor
of this package itself however\. Such decisions are the responsibility of
whichever application is using the package, and are likely influenced by the set
of servers the application will talk to as well\.

For example, in light of the recent [POODLE
attack](http://googleonlinesecurity\.blogspot\.co\.uk/2014/10/this\-poodle\-bites\-exploiting\-ssl\-30\.html)
discovered by Google many servers will disable support for the SSLv3 protocol\.
To handle this change the applications using
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ must be patched, and not this
package, nor __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ itself\. Such a patch
may be as simple as generally activating __tls1__ support, as shown in the
example below\.

    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...

# <a name='section3'></a>AUTHORS

Pat Thoyts

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *sasl* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[SASL](\.\./\.\./\.\./\.\./index\.md\#sasl),
[XGoogleToken](\.\./\.\./\.\./\.\./index\.md\#xgoogletoken),
[authentication](\.\./\.\./\.\./\.\./index\.md\#authentication)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>
