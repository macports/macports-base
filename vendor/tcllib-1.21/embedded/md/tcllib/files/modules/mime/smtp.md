
[//000000001]: # (smtp \- smtp client)
[//000000002]: # (Generated from file 'smtp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 1999\-2000 Marshall T\. Rose and others)
[//000000004]: # (smtp\(n\) 1\.5\.1 tcllib "smtp client")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

smtp \- Client\-side tcl implementation of the smtp protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Authentication](#section2)

  - [EXAMPLE](#section3)

  - [TLS Security Considerations](#section4)

  - [REFERENCES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl  
package require mime ?1\.5\.4?  
package require smtp ?1\.5\.1?  

[__::smtp::sendmessage__ *token* *option*\.\.\.](#1)  

# <a name='description'></a>DESCRIPTION

The __smtp__ library package provides the client side of the Simple Mail
Transfer Protocol \(SMTP\) \(1\) \(2\)\.

  - <a name='1'></a>__::smtp::sendmessage__ *token* *option*\.\.\.

    This command sends the MIME part \(see package __[mime](mime\.md)__\)
    represented by *token* to an SMTP server\. *options* is a list of options
    and their associated values\. The recognized options are:

      * __\-servers__

        A list of SMTP servers\. The default is __localhost__\.

        If multiple servers are specified they are tried in sequence\. Note that
        the __\-ports__ are iterated over in tandem with the servers\. If
        there are not enough ports for the number of servers the default port
        \(see below\) is used\. If there are more ports than servers the
        superfluous ports are ignored\.

      * __\-ports__

        A list of SMTP ports\. The default is __25__\.

        See option __\-servers__ above regardig the behaviour for then
        multiple servers and ports are specified\.

      * __\-client__

        The name to use as our hostname when connecting to the server\. By
        default this is either localhost if one of the servers is localhost, or
        is set to the string returned by __info hostname__\.

      * __\-queue__

        Indicates that the SMTP server should be asked to queue the message for
        later processing\. A boolean value\.

      * __\-atleastone__

        Indicates that the SMTP server must find at least one recipient
        acceptable for the message to be sent\. A boolean value\.

      * __\-originator__

        A string containing an 822\-style address specification\. If present the
        header isn't examined for an originator address\.

      * __\-recipients__

        A string containing one or more 822\-style address specifications\. If
        present the header isn't examined for recipient addresses\)\. If the
        string contains more than one address they will be separated by commas\.

      * __\-header__

        A list containing two elements, an smtp header and its associated value
        \(the \-header option may occur zero or more times\)\.

      * __\-usetls__

        This package supports the RFC 3207 TLS extension \(3\) by default provided
        the tls package is available\. You can turn this off with this boolean
        option\.

      * __\-tlsimport__

        This boolean flag is __false__ by default\. When this flag is set the
        package will import TLS on a sucessfully opened channel\. This is needed
        for connections using native TLS negotiation instead of
        __STARTTLS__\. The __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__
        package is automatically required when needed\.

      * __\-tlspolicy__

        This option lets you specify a command to be called if an error occurs
        during TLS setup\. The command is called with the SMTP code and
        diagnostic message appended\. The command should return 'secure' or
        'insecure' where insecure will cause the package to continue on the
        unencrypted channel\. Returning 'secure' will cause the socket to be
        closed and the next server in the __\-servers__ list to be tried\.

      * __\-username__

      * __\-password__

        If your SMTP server requires authentication \(RFC 2554 \(4\)\) before
        accepting mail you can use __\-username__ and __\-password__ to
        provide your authentication details to the server\. Currently this
        package supports DIGEST\-MD5, CRAM\-MD5, LOGIN and PLAIN authentication
        methods\. The most secure method will be tried first and each method
        tried in turn until we are either authorized or we run out of methods\.
        Note that if the server permits a TLS connection, then the authorization
        will occur after we begin using the secure channel\.

        Please also read the section on [Authentication](#section2), it
        details the necessary prequisites, i\.e\. packages needed to support these
        options and authentication\.

    If the __\-originator__ option is not present, the originator address is
    taken from __From__ \(or __Resent\-From__\); similarly, if the
    __\-recipients__ option is not present, recipient addresses are taken
    from __To__, __cc__, and __Bcc__ \(or __Resent\-To__, and so
    on\)\. Note that the header key/values supplied by the __\-header__ option
    \(not those present in the MIME part\) are consulted\. Regardless, header
    key/values are added to the outgoing message as necessary to ensure that a
    valid 822\-style message is sent\.

    The command returns a list indicating which recipients were unacceptable to
    the SMTP server\. Each element of the list is another list, containing the
    address, an SMTP error code, and a textual diagnostic\. Depending on the
    __\-atleastone__ option and the intended recipients, a non\-empty list may
    still indicate that the message was accepted by the server\.

# <a name='section2'></a>Authentication

Beware\. SMTP authentication uses __[SASL](\.\./sasl/sasl\.md)__\. I\.e\. if
the user has to authenticate a connection, i\.e\. use the options __\-user__
and __\-password__ \(see above\) it is necessary to have the __sasl__
package available so that __smtp__ can load it\.

This is a soft dependency because not everybody requires authentication, and
__sasl__ depends on a lot of the cryptographic \(secure\) hashes, i\.e\. all of
__[md5](\.\./md5/md5\.md)__, __[otp](\.\./otp/otp\.md)__,
__[md4](\.\./md4/md4\.md)__, __[sha1](\.\./sha1/sha1\.md)__, and
__[ripemd160](\.\./ripemd/ripemd160\.md)__\.

# <a name='section3'></a>EXAMPLE

    proc send_simple_message {recipient email_server subject body} {
        package require smtp
        package require mime

        set token [mime::initialize -canonical text/plain \
    	-string $body]
        mime::setheader $token Subject $subject
        smtp::sendmessage $token \
    	-recipients $recipient -servers $email_server
        mime::finalize $token
    }

    send_simple_message someone@somewhere.com localhost \
        "This is the subject." "This is the message."

# <a name='section4'></a>TLS Security Considerations

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

# <a name='section5'></a>REFERENCES

  1. Jonathan B\. Postel, "SIMPLE MAIL TRANSFER PROTOCOL", RFC 821, August 1982\.
     \([http://www\.rfc\-editor\.org/rfc/rfc821\.txt](http://www\.rfc\-editor\.org/rfc/rfc821\.txt)\)

  1. J\. Klensin, "Simple Mail Transfer Protocol", RFC 2821, April 2001\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2821\.txt](http://www\.rfc\-editor\.org/rfc/rfc2821\.txt)\)

  1. P\. Hoffman, "SMTP Service Extension for Secure SMTP over Transport Layer
     Security", RFC 3207, February 2002\.
     \([http://www\.rfc\-editor\.org/rfc/rfc3207\.txt](http://www\.rfc\-editor\.org/rfc/rfc3207\.txt)\)

  1. J\. Myers, "SMTP Service Extension for Authentication", RFC 2554, March
     1999\.
     \([http://www\.rfc\-editor\.org/rfc/rfc2554\.txt](http://www\.rfc\-editor\.org/rfc/rfc2554\.txt)\)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *smtp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[ftp](\.\./ftp/ftp\.md), [http](\.\./\.\./\.\./\.\./index\.md\#http),
[mime](mime\.md), [pop3](\.\./pop3/pop3\.md)

# <a name='keywords'></a>KEYWORDS

[email](\.\./\.\./\.\./\.\./index\.md\#email),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[mail](\.\./\.\./\.\./\.\./index\.md\#mail), [mime](\.\./\.\./\.\./\.\./index\.md\#mime),
[net](\.\./\.\./\.\./\.\./index\.md\#net), [rfc
2554](\.\./\.\./\.\./\.\./index\.md\#rfc\_2554), [rfc
2821](\.\./\.\./\.\./\.\./index\.md\#rfc\_2821), [rfc
3207](\.\./\.\./\.\./\.\./index\.md\#rfc\_3207), [rfc
821](\.\./\.\./\.\./\.\./index\.md\#rfc\_821), [rfc
822](\.\./\.\./\.\./\.\./index\.md\#rfc\_822), [smtp](\.\./\.\./\.\./\.\./index\.md\#smtp),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 1999\-2000 Marshall T\. Rose and others
