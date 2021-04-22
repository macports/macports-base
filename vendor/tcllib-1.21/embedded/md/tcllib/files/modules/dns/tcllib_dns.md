
[//000000001]: # (dns \- Domain Name Service)
[//000000002]: # (Generated from file 'tcllib\_dns\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts)
[//000000004]: # (dns\(n\) 1\.5\.0 tcllib "Domain Name Service")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

dns \- Tcl Domain Name Service Client

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [REFERENCES](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require dns ?1\.5\.0?  

[__::dns::resolve__ *query* ?*options*?](#1)  
[__::dns::configure__ ?*options*?](#2)  
[__::dns::name__ *token*](#3)  
[__::dns::address__ *token*](#4)  
[__::dns::cname__ *token*](#5)  
[__::dns::result__ *token*](#6)  
[__::dns::status__ *token*](#7)  
[__::dns::error__ *token*](#8)  
[__::dns::reset__ *token*](#9)  
[__::dns::wait__ *token*](#10)  
[__::dns::cleanup__ *token*](#11)  
[__::dns::nameservers__](#12)  

# <a name='description'></a>DESCRIPTION

The dns package provides a Tcl only Domain Name Service client\. You should refer
to \(1\) and \(2\) for information about the DNS protocol or read resolver\(3\) to
find out how the C library resolves domain names\. The intention of this package
is to insulate Tcl scripts from problems with using the system library resolver
for slow name servers\. It may or may not be of practical use\. Internet name
resolution is a complex business and DNS is only one part of the resolver\. You
may find you are supposed to be using hosts files, NIS or WINS to name a few
other systems\. This package is not a substitute for the C library resolver \- it
does however implement name resolution over DNS\. The package also extends the
package __[uri](\.\./uri/uri\.md)__ to support DNS URIs \(4\) of the form
[dns:what\.host\.com](dns:what\.host\.com) or
[dns://my\.nameserver/what\.host\.com](dns://my\.nameserver/what\.host\.com)\. The
__dns::resolve__ command can handle DNS URIs or simple domain names as a
query\.

*Note:* The package defaults to using DNS over TCP connections\. If you wish to
use UDP you will need to have the __tcludp__ package installed and have a
version that correctly handles binary data \(> 1\.0\.4\)\. This is available at
[http://tcludp\.sourceforge\.net/](http://tcludp\.sourceforge\.net/)\. If the
__udp__ package is present then UDP will be used by default\.

*Note:* The package supports DNS over TLS \(RFC 7858\) for enhanced privacy of
DNS queries\. Using this feature requires the TLS package\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::dns::resolve__ *query* ?*options*?

    Resolve a domain name using the *[DNS](\.\./\.\./\.\./\.\./index\.md\#dns)*
    protocol\. *query* is the domain name to be lookup up\. This should be
    either a fully qualified domain name or a DNS URI\.

      * __\-nameserver__ *hostname* or __\-server__ *hostname*

        Specify an alternative name server for this request\.

      * __\-protocol__ *tcp&#124;udp*

        Specify the network protocol to use for this request\. Can be one of
        *tcp* or *udp*\.

      * __\-port__ *portnum*

        Specify an alternative port\.

      * __\-search__ *domainlist*

      * __\-timeout__ *milliseconds*

        Override the default timeout\.

      * __\-type__ *TYPE*

        Specify the type of DNS record you are interested in\. Valid values are
        A, NS, MD, MF, CNAME, SOA, MB, MG, MR, NULL, WKS, PTR, HINFO, MINFO, MX,
        TXT, SPF, SRV, AAAA, AXFR, MAILB, MAILA and \*\. See RFC1035 for details
        about the return values\. See
        [http://spf\.pobox\.com/](http://spf\.pobox\.com/) about SPF\. See \(3\)
        about AAAA records and RFC2782 for details of SRV records\.

      * __\-class__ *CLASS*

        Specify the class of domain name\. This is usually IN but may be one of
        IN for internet domain names, CS, CH, HS or \* for any class\.

      * __\-recurse__ *boolean*

        Set to *false* if you do not want the name server to recursively act
        upon your request\. Normally set to *true*\.

      * __\-command__ *procname*

        Set a procedure to be called upon request completion\. The procedure will
        be passed the token as its only argument\.

      * __\-usetls__ *boolean*

        Set the *true* to use DNS over TLS\. This will force the use of TCP and
        change the default port to 853\. Certificate validation is required so a
        source of trusted certificate authority certificates must be provided
        using *\-cafile* or *\-cadir*\.

      * __\-cafile__ *filepath*

        Specify a file containing a collection of trusted certificate authority
        certficates\. See the __update\-ca\-certificates__ command manual page
        for details or the __\-CAfile__ option help from __openssl__\.

      * __\-cadir__ *dirpath*

        Specify a directory containing trusted certificate authority
        certificates\. This must be provided if __\-cafile__ is not specified
        for certificate validation to work when __\-usetls__ is enabled\. See
        the __openssl__ documentation for the required structure of this
        directory\.

  - <a name='2'></a>__::dns::configure__ ?*options*?

    The __::dns::configure__ command is used to setup the dns package\. The
    server to query, the protocol and domain search path are all set via this
    command\. If no arguments are provided then a list of all the current
    settings is returned\. If only one argument then it must the the name of an
    option and the value for that option is returned\.

      * __\-nameserver__ *hostname*

        Set the default name server to be used by all queries\. The default is
        *localhost*\.

      * __\-protocol__ *tcp&#124;udp*

        Set the default network protocol to be used\. Default is *tcp*\.

      * __\-port__ *portnum*

        Set the default port to use on the name server\. The default is 53\.

      * __\-search__ *domainlist*

        Set the domain search list\. This is currently not used\.

      * __\-timeout__ *milliseconds*

        Set the default timeout value for DNS lookups\. Default is 30 seconds\.

      * __\-loglevel__ *level*

        Set the log level used for emitting diagnostic messages from this
        package\. The default is *warn*\. See the
        __[log](\.\./log/log\.md)__ package for details of the available
        levels\.

      * __\-cafile__ *filepath*

        Set the default file path to be used for the __\-cafile__ option to
        __dns::resolve__\.

      * __\-cadir__ *dirpath*

        Set the default directory path to be used for the __\-cadir__ option
        to __dns::resolve__\.

  - <a name='3'></a>__::dns::name__ *token*

    Returns a list of all domain names returned as an answer to your query\.

  - <a name='4'></a>__::dns::address__ *token*

    Returns a list of the address records that match your query\.

  - <a name='5'></a>__::dns::cname__ *token*

    Returns a list of canonical names \(usually just one\) matching your query\.

  - <a name='6'></a>__::dns::result__ *token*

    Returns a list of all the decoded answer records provided for your query\.
    This permits you to extract the result for more unusual query types\.

  - <a name='7'></a>__::dns::status__ *token*

    Returns the status flag\. For a successfully completed query this will be
    *ok*\. May be *error* or *timeout* or *eof*\. See also
    __::dns::error__

  - <a name='8'></a>__::dns::error__ *token*

    Returns the error message provided for requests whose status is *error*\.
    If there is no error message then an empty string is returned\.

  - <a name='9'></a>__::dns::reset__ *token*

    Reset or cancel a DNS query\.

  - <a name='10'></a>__::dns::wait__ *token*

    Wait for a DNS query to complete and return the status upon completion\.

  - <a name='11'></a>__::dns::cleanup__ *token*

    Remove all state variables associated with the request\.

  - <a name='12'></a>__::dns::nameservers__

    Attempts to return a list of the nameservers currently configured for the
    users system\. On a unix machine this parses the /etc/resolv\.conf file for
    nameservers \(if it exists\) and on Windows systems we examine certain parts
    of the registry\. If no nameserver can be found then the loopback address
    \(127\.0\.0\.1\) is used as a default\.

# <a name='section3'></a>EXAMPLES

    % set tok [dns::resolve www.tcl.tk]
    ::dns::1
    % dns::status $tok
    ok
    % dns::address $tok
    199.175.6.239
    % dns::name $tok
    www.tcl.tk
    % dns::cleanup $tok

Using DNS URIs as queries:

    % set tok [dns::resolve "dns:tcl.tk;type=MX"]
    % set tok [dns::resolve "dns://l.root-servers.net/www.tcl.tk"]

Reverse address lookup:

    % set tok [dns::resolve 127.0.0.1]
    ::dns::1
    % dns::name $tok
    localhost
    % dns::cleanup $tok

Using DNS over TLS \(RFC 7858\):

    % set tok [dns::resolve www.tcl.tk -nameserver dns-tls.bitwiseshift.net  -usetls 1 -cafile /etc/ssl/certs/ca-certificates.crt]
    ::dns::12
    % dns::wait $tok
    ok
    % dns::address $tok
    104.25.119.118 104.25.120.118

# <a name='section4'></a>REFERENCES

  1. Mockapetris, P\., "Domain Names \- Concepts and Facilities", RFC 1034,
     November 1987\.
     \([http://www\.ietf\.org/rfc/rfc1034\.txt](http://www\.ietf\.org/rfc/rfc1034\.txt)\)

  1. Mockapetris, P\., "Domain Names \- Implementation and Specification", RFC
     1035, November 1087\.
     \([http://www\.ietf\.org/rfc/rfc1035\.txt](http://www\.ietf\.org/rfc/rfc1035\.txt)\)

  1. Thompson, S\. and Huitema, C\., "DNS Extensions to support IP version 6", RFC
     1886, December 1995\.
     \([http://www\.ietf\.org/rfc/rfc1886\.txt](http://www\.ietf\.org/rfc/rfc1886\.txt)\)

  1. Josefsson, S\., "Domain Name System Uniform Resource Identifiers",
     Internet\-Draft, October 2003,
     \([http://www\.ietf\.org/internet\-drafts/draft\-josefsson\-dns\-url\-09\.txt](http://www\.ietf\.org/internet\-drafts/draft\-josefsson\-dns\-url\-09\.txt)\)

  1. Gulbrandsen, A\., Vixie, P\. and Esibov, L\., "A DNS RR for specifying the
     location of services \(DNS SRV\)", RFC 2782, February 2000,
     \([http://www\.ietf\.org/rfc/rfc2782\.txt](http://www\.ietf\.org/rfc/rfc2782\.txt)\)

  1. Ohta, M\. "Incremental Zone Transfer in DNS", RFC 1995, August 1996,
     \([http://www\.ietf\.org/rfc/rfc1995\.txt](http://www\.ietf\.org/rfc/rfc1995\.txt)\)

  1. Hu, Z\., etc al\. "Specification for DNS over Transport Layer Security
     \(TLS\)", RFC 7858, May 2016,
     \([http://www\.ietf\.org/rfc/rfc7858\.txt](http://www\.ietf\.org/rfc/rfc7858\.txt)\)

# <a name='section5'></a>AUTHORS

Pat Thoyts

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *dns* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

resolver\(5\)

# <a name='keywords'></a>KEYWORDS

[DNS](\.\./\.\./\.\./\.\./index\.md\#dns), [domain name
service](\.\./\.\./\.\./\.\./index\.md\#domain\_name\_service),
[resolver](\.\./\.\./\.\./\.\./index\.md\#resolver), [rfc
1034](\.\./\.\./\.\./\.\./index\.md\#rfc\_1034), [rfc
1035](\.\./\.\./\.\./\.\./index\.md\#rfc\_1035), [rfc
1886](\.\./\.\./\.\./\.\./index\.md\#rfc\_1886), [rfc
7858](\.\./\.\./\.\./\.\./index\.md\#rfc\_7858)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts
