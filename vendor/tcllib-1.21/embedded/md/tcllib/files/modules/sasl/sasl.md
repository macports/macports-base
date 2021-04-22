
[//000000001]: # (SASL \- Simple Authentication and Security Layer \(SASL\))
[//000000002]: # (Generated from file 'sasl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (SASL\(n\) 1\.3\.3 tcllib "Simple Authentication and Security Layer \(SASL\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

SASL \- Implementation of SASL mechanisms for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [OPTIONS](#section3)

  - [CALLBACK PROCEDURE](#section4)

  - [MECHANISMS](#section5)

  - [EXAMPLES](#section6)

  - [REFERENCES](#section7)

  - [AUTHORS](#section8)

  - [Bugs, Ideas, Feedback](#section9)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require SASL ?1\.3\.3?  

[__::SASL::new__ *option value ?\.\.\.?*](#1)  
[__::SASL::configure__ *option value* ?*\.\.\.*?](#2)  
[__::SASL::step__ *context* *challenge* ?*\.\.\.*?](#3)  
[__::SASL::response__ *context*](#4)  
[__::SASL::reset__ *context*](#5)  
[__::SASL::cleanup__ *context*](#6)  
[__::SASL::mechanisms__ ?*type*? ?*minimum*?](#7)  
[__::SASL::register__ *mechanism* *preference* *clientproc* ?*serverproc*?](#8)  

# <a name='description'></a>DESCRIPTION

The Simple Authentication and Security Layer \(SASL\) is a framework for providing
authentication and authorization to comunications protocols\. The SASL framework
is structured to permit negotiation among a number of authentication mechanisms\.
SASL may be used in SMTP, IMAP and HTTP authentication\. It is also in use in
XMPP, LDAP and BEEP\. See [MECHANISMS](#section5) for the set of available
SASL mechanisms provided with tcllib\.

The SASL framework operates using a simple multi\-step challenge response
mechanism\. All the mechanisms work the same way although the number of steps may
vary\. In this implementation a callback procedure must be provided from which
the SASL framework will obtain users details\. See [CALLBACK
PROCEDURE](#section4) for details of this procedure\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::SASL::new__ *option value ?\.\.\.?*

    Contruct a new SASL context\. See [OPTIONS](#section3) for details of
    the possible options to this command\. A context token is required for most
    of the SASL procedures\.

  - <a name='2'></a>__::SASL::configure__ *option value* ?*\.\.\.*?

    Modify and inspect the SASL context option\. See [OPTIONS](#section3)
    for further details\.

  - <a name='3'></a>__::SASL::step__ *context* *challenge* ?*\.\.\.*?

    This is the core procedure for using the SASL framework\. The __step__
    procedure should be called until it returns 0\. Each step takes a server
    challenge string and the response is calculated and stored in the context\.
    Each mechanism may require one or more steps\. For some steps there may be no
    server challenge required in which case an empty string should be provided
    for this parameter\. All mechanisms should accept an initial empty challenge\.

  - <a name='4'></a>__::SASL::response__ *context*

    Returns the next response string that should be sent to the server\.

  - <a name='5'></a>__::SASL::reset__ *context*

    Re\-initialize the SASL context\. Discards any internal state and permits the
    token to be reused\.

  - <a name='6'></a>__::SASL::cleanup__ *context*

    Release all resources associated with the SASL context\. The context token
    may not be used again after this procedure has been called\.

  - <a name='7'></a>__::SASL::mechanisms__ ?*type*? ?*minimum*?

    Returns a list of all the available SASL mechanisms\. The list is sorted by
    the mechanism preference value \(see __register__\) with the preferred
    mechanisms and the head of the list\. Any mechanism with a preference value
    less than the*minimum* \(which defaults to 0\) is removed from the returned
    list\. This permits a security threshold to be set\. Mechanisms with a
    preference less that 25 transmit authentication are particularly susceptible
    to eavesdropping and should not be provided unless a secure channel is in
    use \(eg: tls\)\.

    The *type* parameter may be one of *client* or *server* and defaults
    to *client*\. Only mechanisms that have an implementation matching the
    *type* are returned \(this permits servers to correctly declare support
    only for mechanisms that actually provide a server implementation\)\.

  - <a name='8'></a>__::SASL::register__ *mechanism* *preference* *clientproc* ?*serverproc*?

    New mechanisms can be added to the package by registering the mechanism name
    and the implementing procedures\. The server procedure is optional\. The
    preference value is an integer that is used to order the list returned by
    the __mechanisms__ command\. Higher values indicate a preferred
    mechanism\. If the mechanism is already registered then the recorded values
    are updated\.

# <a name='section3'></a>OPTIONS

  - __\-callback__

    Specify a command to be evaluated when the SASL mechanism requires
    information about the user\. The command is called with the current SASL
    context and a name specifying the information desired\. See
    [EXAMPLES](#section6)\.

  - __\-mechanism__

    Set the SASL mechanism to be used\. See __mechanisms__ for a list of
    supported authentication mechanisms\.

  - __\-service__

    Set the service type for this context\. Some mechanisms may make use of this
    parameter \(eg DIGEST\-MD5, GSSAPI and Kerberos\)\. If not set it defaults to an
    empty string\. If the __\-type__ is set to 'server' then this option
    should be set to a valid service identity\. Some examples of valid service
    names are smtp, ldap, beep and xmpp\.

  - __\-server__

    This option is used to set the server name used in SASL challenges when
    operating as a SASL server\.

  - __\-type__

    The context type may be one of 'client' or 'server'\. The default is to
    operate as a client application and respond to server challenges\. Mechanisms
    may be written to support server\-side SASL and setting this option will
    cause each __step__ to issue the next challenge\. A new context must be
    created for each incoming client connection when in server mode\.

# <a name='section4'></a>CALLBACK PROCEDURE

When the SASL framework requires any user details it will call the procedure
provided when the context was created with an argument that specfies the item of
information required\.

In all cases a single response string should be returned\.

  - login

    The callback procedure should return the users authorization identity\.
    Return an empty string unless this is to be different to the authentication
    identity\. Read \[1\] for a discussion about the specific meaning of
    authorization and authentication identities within SASL\.

  - username

    The callback procedure should return the users authentication identity\. Read
    \[1\] for a discussion about the specific meaning of authorization and
    authentication identities within SASL\.

  - password

    The callback procedure should return the password that matches the
    authentication identity as used within the current realm\.

    For server mechanisms the password callback should always be called with the
    authentication identity and the realm as the first two parameters\.

  - realm

    Some SASL mechanisms use realms to partition authentication identities\. The
    realm string is protocol dependent and is often the current DNS domain or in
    the case of the NTLM mechanism it is the Windows NT domain name\.

  - hostname

    Returns the client host name \- typically \[info host\]\.

# <a name='section5'></a>MECHANISMS

  - ANONYMOUS

    As used in FTP this mechanism only passes an email address for
    authentication\. The ANONYMOUS mechanism is specified in \[2\]\.

  - PLAIN

    This is the simplest mechanism\. The users authentication details are
    transmitted in plain text\. This mechanism should not be provided unless an
    encrypted link is in use \- typically after SSL or TLS has been negotiated\.

  - LOGIN

    The LOGIN \[1\] mechanism transmits the users details with base64 encoding\.
    This is no more secure than PLAIN and likewise should not be used without a
    secure link\.

  - CRAM\-MD5

    This mechanism avoids sending the users password over the network in plain
    text by hashing the password with a server provided random value \(known as a
    nonce\)\. A disadvantage of this mechanism is that the server must maintain a
    database of plaintext passwords for comparison\. CRAM\-MD5 was defined in \[4\]\.

  - DIGEST\-MD5

    This mechanism improves upon the CRAM\-MD5 mechanism by avoiding the need for
    the server to store plaintext passwords\. With digest authentication the
    server needs to store the MD5 digest of the users password which helps to
    make the system more secure\. As in CRAM\-MD5 the password is hashed with a
    server nonce and other data before being transmitted across the network\.
    Specified in \[3\]\.

  - OTP

    OTP is the One\-Time Password system described in RFC 2289 \[6\]\. This
    mechanism is secure against replay attacks and also avoids storing password
    or password equivalents on the server\. Only a digest of a seed and a
    passphrase is ever transmitted across the network\. Requires the
    __[otp](\.\./otp/otp\.md)__ package from tcllib and one or more of the
    cryptographic digest packages \(md5 or sha\-1 are the most commonly used\)\.

  - NTLM

    This is a proprietary protocol developed by Microsoft \[5\] and is in common
    use for authenticating users in a Windows network environment\. NTLM uses DES
    encryption and MD4 digests of the users password to authenticate a
    connection\. Certain weaknesses have been found in NTLM and thus there are a
    number of versions of the protocol\. As this mechanism has additional
    dependencies it is made available as a separate sub\-package\. To enable this
    mechanism your application must load the __[SASL::NTLM](ntlm\.md)__
    package\.

  - X\-GOOGLE\-TOKEN

    This is a proprietary protocol developed by Google and used for
    authenticating users for the Google Talk service\. This mechanism makes a
    pair of HTTP requests over an SSL channel and so this mechanism depends upon
    the availability of the tls and http packages\. To enable this mechanism your
    application must load the __[SASL::XGoogleToken](gtoken\.md)__
    package\. In addition you are recommended to make use of the autoproxy
    package to handle HTTP proxies reasonably transparently\.

  - SCRAM

    This is a protocol specified in RFC 5802 \[7\]\. To enable this mechanism your
    application must load the __[SASL::SCRAM](scram\.md)__ package\.

# <a name='section6'></a>EXAMPLES

See the examples subdirectory for more complete samples using SASL with network
protocols\. The following should give an idea how the SASL commands are to be
used\. In reality this should be event driven\. Each time the __step__ command
is called, the last server response should be provided as the command argument
so that the SASL mechanism can take appropriate action\.

    proc ClientCallback {context command args} {
        switch -exact -- $command {
            login    { return "" }
            username { return $::tcl_platform(user) }
            password { return "SecRet" }
            realm    { return "" }
            hostname { return [info host] }
            default  { return -code error unxpected }
        }
    }

    proc Demo {{mech PLAIN}} {
        set ctx [SASL::new -mechanism $mech -callback ClientCallback]
        set challenge ""
        while {1} {
            set more_steps [SASL::step $ctx challenge]
            puts "Send '[SASL::response $ctx]'"
            puts "Read server response into challenge var"
            if {!$more_steps} {break}
        }
        SASL::cleanup $ctx
    }

# <a name='section7'></a>REFERENCES

  1. Myers, J\. "Simple Authentication and Security Layer \(SASL\)", RFC 2222,
     October 1997\.
     \([http://www\.ietf\.org/rfc/rfc2222\.txt](http://www\.ietf\.org/rfc/rfc2222\.txt)\)

  1. Newman, C\. "Anonymous SASL Mechanism", RFC 2245, November 1997\.
     \([http://www\.ietf\.org/rfc/rfc2245\.txt](http://www\.ietf\.org/rfc/rfc2245\.txt)\)

  1. Leach, P\., Newman, C\. "Using Digest Authentication as a SASL Mechanism",
     RFC 2831, May 2000,
     \([http://www\.ietf\.org/rfc/rfc2831\.txt](http://www\.ietf\.org/rfc/rfc2831\.txt)\)

  1. Klensin, J\., Catoe, R\. and Krumviede, P\., "IMAP/POP AUTHorize Extension for
     Simple Challenge/Response" RFC 2195, September 1997\.
     \([http://www\.ietf\.org/rfc/rfc2195\.txt](http://www\.ietf\.org/rfc/rfc2195\.txt)\)

  1. No official specification is available\. However,
     [http://davenport\.sourceforge\.net/ntlm\.html](http://davenport\.sourceforge\.net/ntlm\.html)
     provides a good description\.

  1. Haller, N\. et al\., "A One\-Time Password System", RFC 2289, February 1998,
     \([http://www\.ieft\.org/rfc/rfc2289\.txt](http://www\.ieft\.org/rfc/rfc2289\.txt)\)

  1. Newman, C\. et al\., "Salted Challenge Response Authentication Mechanism
     \(SCRAM\) SASL and GSS\-API Mechanisms", RFC 5802, July 2010,
     \([http://www\.ieft\.org/rfc/rfc5802\.txt](http://www\.ieft\.org/rfc/rfc5802\.txt)\)

# <a name='section8'></a>AUTHORS

Pat Thoyts

# <a name='section9'></a>Bugs, Ideas, Feedback

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
[authentication](\.\./\.\./\.\./\.\./index\.md\#authentication)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005\-2006, Pat Thoyts <patthoyts@users\.sourceforge\.net>
