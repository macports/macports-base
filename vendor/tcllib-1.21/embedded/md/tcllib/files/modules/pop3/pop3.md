
[//000000001]: # (pop3 \- Tcl POP3 Client Library)
[//000000002]: # (Generated from file 'pop3\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (pop3\(n\) 1\.10 tcllib "Tcl POP3 Client Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pop3 \- Tcl client for POP3 email protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [TLS Security Considerations](#section2)

  - [API](#section3)

  - [Secure mail transfer](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pop3 ?1\.10?  

[__::pop3::open__ ?__\-msex__ 0&#124;1? ?__\-retr\-mode__ retr&#124;list&#124;slow? ?__\-socketcmd__ cmdprefix? ?__\-stls__ 0&#124;1? ?__\-tls\-callback__ stls\-callback\-command? *host username password* ?*port*?](#1)  
[__::pop3::config__ *chan*](#2)  
[__::pop3::status__ *chan*](#3)  
[__::pop3::last__ *chan*](#4)  
[__::pop3::retrieve__ *chan startIndex* ?*endIndex*?](#5)  
[__::pop3::delete__ *chan startIndex* ?*endIndex*?](#6)  
[__::pop3::list__ *chan* ?*msg*?](#7)  
[__::pop3::top__ *chan* *msg* *n*](#8)  
[__::pop3::uidl__ *chan* ?*msg*?](#9)  
[__::pop3::capa__ *chan*](#10)  
[__::pop3::close__ *chan*](#11)  

# <a name='description'></a>DESCRIPTION

The __pop3__ package provides a simple Tcl\-only client library for the POP3
email protocol as specified in [RFC
1939](http://www\.rfc\-editor\.org/rfc/rfc1939\.txt)\. It works by opening the
standard POP3 socket on the server, transmitting the username and password, then
providing a Tcl API to access the POP3 protocol commands\. All server errors are
returned as Tcl errors \(thrown\) which must be caught with the Tcl __catch__
command\.

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

# <a name='section3'></a>API

  - <a name='1'></a>__::pop3::open__ ?__\-msex__ 0&#124;1? ?__\-retr\-mode__ retr&#124;list&#124;slow? ?__\-socketcmd__ cmdprefix? ?__\-stls__ 0&#124;1? ?__\-tls\-callback__ stls\-callback\-command? *host username password* ?*port*?

    Open a socket connection to the server specified by *host*, transmit the
    *username* and *password* as login information to the server\. The
    default port number is __110__, which can be overridden using the
    optional *port* argument\. The return value is a channel used by all of the
    other ::pop3 functions\.

    The command recognizes three options

      * __\-msex__ boolean

        Setting this option tells the package that the server we are talking to
        is an MS Exchange server \(which has some oddities we have to work
        around\)\. The default is __False__\.

      * __\-retr\-mode__ retr&#124;list&#124;slow

        The retrieval mode determines how exactly messages are read from the
        server\. The allowed values are __retr__, __list__ and
        __slow__\. The default is __retr__\. See __::pop3::retrieve__
        for more information\.

      * __\-socketcmd__ cmdprefix

        This option allows the user to overide the use of the builtin
        __[socket](\.\./\.\./\.\./\.\./index\.md\#socket)__ command with any
        API\-compatible command\. The envisioned main use is the securing of the
        new connection via SSL, through the specification of the command
        __tls::socket__\. This command is specially recognized as well,
        changing the default port of the connection to __995__\.

      * __\-stls__ boolean

        Setting this option tells the package to secure the connection using SSL
        or TLS\. It performs STARTTLS as described in IETF RFC 2595, it first
        opens a normal, unencrypted connection and then negotiates a SSLv3 or
        TLSv1 connection\. If the connection cannot be secured, the connection
        will be closed and an error will be returned

      * __\-tls\-callback__ stls\-callback\-command

        This option allows the user to overide the __tls::callback__ used
        during the __\-stls__ SSL/TLS handshake\. See the TLS manual for
        details on how to implement this callback\.

  - <a name='2'></a>__::pop3::config__ *chan*

    Returns the configuration of the pop3 connection identified by the channel
    handle *chan* as a serialized array\.

  - <a name='3'></a>__::pop3::status__ *chan*

    Query the server for the status of the mail spool\. The status is returned as
    a list containing two elements, the first is the number of email messages on
    the server and the second is the size \(in octets, 8 bit blocks\) of the
    entire mail spool\.

  - <a name='4'></a>__::pop3::last__ *chan*

    Query the server for the last email message read from the spool\. This value
    includes all messages read from all clients connecting to the login account\.
    This command may not be supported by the email server, in which case the
    server may return 0 or an error\.

  - <a name='5'></a>__::pop3::retrieve__ *chan startIndex* ?*endIndex*?

    Retrieve a range of messages from the server\. If the *endIndex* is not
    specified, only one message will be retrieved\. The return value is a list
    containing each message as a separate element\. See the *startIndex* and
    *endIndex* descriptions below\.

    The retrieval mode determines how exactly messages are read from the server\.
    The mode __retr__ assumes that the RETR command delivers the size of the
    message as part of the command status and uses this to read the message
    efficiently\. In mode __list__ RETR does not deliver the size, but the
    LIST command does and we use this to retrieve the message size before the
    actual retrieval, which can then be done efficiently\. In the last mode,
    __slow__, the system is unable to obtain the size of the message to
    retrieve in any manner and falls back to reading the message from the server
    line by line\.

    It should also be noted that the system checks upon the configured mode and
    falls back to the slower modes if the above assumptions are not true\.

  - <a name='6'></a>__::pop3::delete__ *chan startIndex* ?*endIndex*?

    Delete a range of messages from the server\. If the *endIndex* is not
    specified, only one message will be deleted\. Note, the indices are not
    reordered on the server, so if you delete message 1, then the first message
    in the queue is message 2 \(message index 1 is no longer valid\)\. See the
    *startIndex* and *endIndex* descriptions below\.

      * *startIndex*

        The *startIndex* may be an index of a specific message starting with
        the index 1, or it have any of the following values:

          + __start__

            This is a logical value for the first message in the spool,
            equivalent to the value 1\.

          + __next__

            The message immediately following the last message read, see
            __::pop3::last__\.

          + __end__

            The most recent message in the spool \(the end of the spool\)\. This is
            useful to retrieve only the most recent message\.

      * *endIndex*

        The *endIndex* is an optional parameter and defaults to the value
        "\-1", which indicates to only retrieve the one message specified by
        *startIndex*\. If specified, it may be an index of a specific message
        starting with the index "1", or it may have any of the following values:

          + __last__

            The message is the last message read by a POP3 client, see
            __::pop3::last__\.

          + __end__

            The most recent message in the spool \(the end of the spool\)\.

  - <a name='7'></a>__::pop3::list__ *chan* ?*msg*?

    Returns the scan listing of the mailbox\. If parameter *msg* is given, then
    the listing only for that message is returned\.

  - <a name='8'></a>__::pop3::top__ *chan* *msg* *n*

    Optional POP3 command, not all servers may support this\. __::pop3::top__
    retrieves headers of a message, specified by parameter *msg*, and number
    of *n* lines from the message body\.

  - <a name='9'></a>__::pop3::uidl__ *chan* ?*msg*?

    Optional POP3 command, not all servers may support this\.
    __::pop3::uidl__ returns the uid listing of the mailbox\. If the
    parameter *msg* is specified, then the listing only for that message is
    returned\.

  - <a name='10'></a>__::pop3::capa__ *chan*

    Optional POP3 command, not all servers may support this\.
    __::pop3::capa__ returns a list of the capabilities of the server\. TOP,
    SASL, UIDL, LOGIN\-DELAY and STLS are typical capabilities\. See IETF RFC
    2449\.

  - <a name='11'></a>__::pop3::close__ *chan*

    Gracefully close the connect after sending a POP3 QUIT command down the
    socket\.

# <a name='section4'></a>Secure mail transfer

A pop3 connection can be secured with SSL/TLS by requiring the package
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ and then using either the option
__\-socketcmd__ or the option __\-stls__ of the command
__pop3::open__\. The first method, option __\-socketcmd__, will force the
use of the __tls::socket__ command when opening the connection\. This is
suitable for POP3 servers which expect SSL connections only\. These will
generally be listening on port 995\.

    package require tls
    tls::init -cafile /path/to/ca/cert -keyfile ...

    # Create secured pop3 channel
    pop3::open -socketcmd tls::socket \
    	$thehost $theuser $thepassword

    ...

The second method, option __\-stls__, will connect to the standard POP3 port
and then perform an STARTTLS handshake\. This will only work for POP3 servers
which have this capability\. The package will confirm that the server supports
STARTTLS and the handshake was performed correctly before proceeding with
authentication\.

    package require tls
    tls::init -cafile /path/to/ca/cert -keyfile ...

    # Create secured pop3 channel
    pop3::open -stls 1 \
    	$thehost $theuser $thepassword

    ...

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pop3* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[email](\.\./\.\./\.\./\.\./index\.md\#email), [mail](\.\./\.\./\.\./\.\./index\.md\#mail),
[pop](\.\./\.\./\.\./\.\./index\.md\#pop), [pop3](\.\./\.\./\.\./\.\./index\.md\#pop3),
[rfc 1939](\.\./\.\./\.\./\.\./index\.md\#rfc\_1939),
[secure](\.\./\.\./\.\./\.\./index\.md\#secure), [ssl](\.\./\.\./\.\./\.\./index\.md\#ssl),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='category'></a>CATEGORY

Networking
