
[//000000001]: # (autoproxy \- HTTP protocol helper modules)
[//000000002]: # (Generated from file 'autoproxy\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (autoproxy\(n\) 1\.7 tcllib "HTTP protocol helper modules")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

autoproxy \- Automatic HTTP proxy usage and authentication

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [TLS Security Considerations](#section2)

  - [COMMANDS](#section3)

  - [OPTIONS](#section4)

  - [Basic Authentication](#section5)

  - [EXAMPLES](#section6)

  - [REFERENCES](#section7)

  - [BUGS](#section8)

  - [AUTHORS](#section9)

  - [Bugs, Ideas, Feedback](#section10)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require http ?2\.0?  
package require autoproxy ?1\.7?  

[__::autoproxy::init__](#1)  
[__::autoproxy::cget__ *\-option*](#2)  
[__::autoproxy::configure__ ?\-option *value*?](#3)  
[__::autoproxy::tls\_connect__ *args*](#4)  
[__::autoproxy::tunnel\_connect__ *args*](#5)  
[__::autoproxy::tls\_socket__ *args*](#6)  

# <a name='description'></a>DESCRIPTION

This package attempts to automate the use of HTTP proxy servers in Tcl HTTP
client code\. It tries to initialize the web access settings from system standard
locations and can be configured to negotiate authentication with the proxy if
required\.

On Unix the standard for identifying the local HTTP proxy server seems to be to
use the environment variable http\_proxy or ftp\_proxy and no\_proxy to list those
domains to be excluded from proxying\. On Windows we can retrieve the Internet
Settings values from the registry to obtain pretty much the same information\.
With this information we can setup a suitable filter procedure for the Tcl http
package and arrange for automatic use of the proxy\.

There seem to be a number of ways that the http\_proxy environment variable may
be set up\. Either a plain host:port or more commonly a URL and sometimes the URL
may contain authentication parameters or these may be requested from the user or
provided via http\_proxy\_user and http\_proxy\_pass\. This package attempts to deal
with all these schemes\. It will do it's best to get the required parameters from
the environment or registry and if it fails can be reconfigured\.

# <a name='section2'></a>TLS Security Considerations

*Note* This section only applies if TLS support is provided by the
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package\. It does not apply when
__autoproxy__ was configured to use some other package which can provide the
same \(i\.e __twapi__\), via the __\-tls\_package__ configuration option\.

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

# <a name='section3'></a>COMMANDS

  - <a name='1'></a>__::autoproxy::init__

    Initialize the autoproxy package from system resources\. Under unix this
    means we look for environment variables\. Under windows we look for the same
    environment variables but also look at the registry settings used by
    Internet Explorer\.

  - <a name='2'></a>__::autoproxy::cget__ *\-option*

    Retrieve individual package configuration options\. See
    [OPTIONS](#section4)\.

  - <a name='3'></a>__::autoproxy::configure__ ?\-option *value*?

    Configure the autoproxy package\. Calling __configure__ with no options
    will return a list of all option names and values\. See
    [OPTIONS](#section4)\.

  - <a name='4'></a>__::autoproxy::tls\_connect__ *args*

    Connect to a secure socket through a proxy\. HTTP proxy servers permit the
    use of the CONNECT HTTP command to open a link through the proxy to the
    target machine\. This function hides the details\. For use with the http
    package see __tls\_socket__\.

    The *args* list may contain any of the options supported by the specific
    TLS package that is in use but must end with the host and port as the last
    two items\.

  - <a name='5'></a>__::autoproxy::tunnel\_connect__ *args*

    Connect to a target host throught a proxy\. This uses the same CONNECT HTTP
    command as the __tls\_connect__ but does not promote the link security
    once the connection is established\.

    The *args* list may contain any of the options supported by the specific
    TLS package that is in use but must end with the host and port as the last
    two items\.

    Note that many proxy servers will permit CONNECT calls to a limited set of
    ports \- typically only port 443 \(the secure HTTP port\)\.

  - <a name='6'></a>__::autoproxy::tls\_socket__ *args*

    This function is to be used to register a proxy\-aware secure socket handler
    for the https protocol\. It may only be used with the Tcl http package and
    should be registered using the http::register command \(see the examples
    below\)\. The job of actually creating the tunnelled connection is done by the
    tls\_connect command and this may be used when not registering with the http
    package\.

# <a name='section4'></a>OPTIONS

  - __\-host__ hostname

  - __\-proxy\_host__ hostname

    Set the proxy hostname\. This is normally set up by __init__ but may be
    configured here as well\.

  - __\-port__ number

  - __\-proxy\_port__ number

    Set the proxy port number\. This is normally set up by __init__\. e\.g\.
    __configure__ __\-port__ *3128*

  - __\-no\_proxy__ list

    You may manipulate the __no\_proxy__ list that was setup by __init__\.
    The value of this option is a tcl list of strings that are matched against
    the http request host using the tcl __string match__ command\. Therefore
    glob patterns are permitted\. For instance, __configure__
    __\-no\_proxy__ *\*\.localdomain*

  - __\-authProc__ procedure

    This option may be used to set an application defined procedure to be called
    when __configure__ __\-basic__ is called with either no or
    insufficient authentication details\. This can be used to present a dialog to
    the user to request the additional information\.

  - __\-basic__

    Following options are for configuring the Basic authentication scheme
    parameters\. See [Basic Authentication](#section5)\. To unset the proxy
    authentication information retained from a previous call of this function
    either "\-\-" or no additional parameters can be supplied\. This will remove
    the existing authentication information\.

  - __\-tls\_package__ packagename

    This option may be used to configure the Tcl package to use for TLS support\.
    Valid package names are __tls__ \(default\) and __twapi__\.

# <a name='section5'></a>Basic Authentication

Basic is the simplest and most commonly use HTTP proxy authentication scheme\. It
is described in \(1 section 11\) and also in \(2\)\. It offers no privacy whatsoever
and its use should be discouraged in favour of more secure alternatives like
Digest\. To perform Basic authentication the client base64 encodes the username
and plaintext password separated by a colon\. This encoded text is prefixed with
the word "Basic" and a space\.

The following options exists for this scheme:

  - __\-username__ name

    The username required to authenticate with the configured proxy\.

  - __\-password__ password

    The password required for the username specified\.

  - __\-realm__ realm

    This option is not used by this package but may be used in requesting
    authentication details from the user\.

  - __\-\-__

    The end\-of\-options indicator may be used alone to unset any authentication
    details currently enabled\.

# <a name='section6'></a>EXAMPLES

    package require autoproxy
    autoproxy::init
    autoproxy::configure -basic -username ME -password SEKRET
    set tok [http::geturl http://wiki.tcl.tk/]
    http::data $tok

    package require http
    package require tls
    package require autoproxy
    autoproxy::init
    http::register https 443 autoproxy::tls_socket
    set tok [http::geturl https://www.example.com/]

# <a name='section7'></a>REFERENCES

  1. Berners\-Lee, T\., Fielding R\. and Frystyk, H\. "Hypertext Transfer Protocol
     \-\- HTTP/1\.0", RFC 1945, May 1996,
     \([http://www\.rfc\-editor\.org/rfc/rfc1945\.txt](http://www\.rfc\-editor\.org/rfc/rfc1945\.txt)\)

  1. Franks, J\. et al\. "HTTP Authentication: Basic and Digest Access
     Authentication", RFC 2617, June 1999
     \([http://www\.rfc\-editor\.org/rfc/rfc2617\.txt](http://www\.rfc\-editor\.org/rfc/rfc2617\.txt)\)

# <a name='section8'></a>BUGS

At this time only Basic authentication \(1\) \(2\) is supported\. It is planned to
add support for Digest \(2\) and NTLM in the future\.

# <a name='section9'></a>AUTHORS

Pat Thoyts

# <a name='section10'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *http :: autoproxy* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

http\(n\)

# <a name='keywords'></a>KEYWORDS

[authentication](\.\./\.\./\.\./\.\./index\.md\#authentication),
[http](\.\./\.\./\.\./\.\./index\.md\#http), [proxy](\.\./\.\./\.\./\.\./index\.md\#proxy)

# <a name='category'></a>CATEGORY

Networking
