
[//000000001]: # (smtpd \- Tcl SMTP Server Package)
[//000000002]: # (Generated from file 'smtpd\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (smtpd\(n\) 1\.5 tcllib "Tcl SMTP Server Package")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

smtpd \- Tcl SMTP server implementation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [SECURITY](#section2)

  - [TLS Security Considerations](#section3)

  - [COMMANDS](#section4)

  - [CALLBACKS](#section5)

  - [VARIABLES](#section6)

  - [AUTHOR](#section7)

  - [LICENSE](#section8)

  - [Bugs, Ideas, Feedback](#section9)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require smtpd ?1\.5?  

[__::smtpd::start__ ?*myaddr*? ?*port*?](#1)  
[__::smtpd::stop__](#2)  
[__::smptd::configure__ ?*option* *value*? ?*option* *value* *\.\.\.*?](#3)  
[__::smtpd::cget__ ?*option*?](#4)  

# <a name='description'></a>DESCRIPTION

The __smtpd__ package provides a simple Tcl\-only server library for the
Simple Mail Transfer Protocol as described in RFC 821
\([http://www\.rfc\-editor\.org/rfc/rfc821\.txt](http://www\.rfc\-editor\.org/rfc/rfc821\.txt)\)
and RFC 2821
\([http://www\.rfc\-editor\.org/rfc/rfc2821\.txt](http://www\.rfc\-editor\.org/rfc/rfc2821\.txt)\)\.
By default the server will bind to the default network address and the standard
SMTP port \(25\)\.

This package was designed to permit testing of Mail User Agent code from a
developers workstation\. *It does not attempt to deliver mail to your mailbox\.*
Instead users of this package are expected to write a procedure that will be
called when mail arrives\. Once this procedure returns, the server has nothing
further to do with the mail\.

# <a name='section2'></a>SECURITY

On Unix platforms binding to the SMTP port requires root privileges\. I would not
recommend running any script\-based server as root unless there is some method
for dropping root privileges immediately after the socket is bound\. Under
Windows platforms, it is not necessary to have root or administrator privileges
to bind low numbered sockets\. However, security on these platforms is weak
anyway\.

In short, this code should probably not be used as a permanently running Mail
Transfer Agent on an Internet connected server, even though we are careful not
to evaluate remote user input\. There are many other well tested and security
audited programs that can be used as mail servers for internet connected hosts\.

# <a name='section3'></a>TLS Security Considerations

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

# <a name='section4'></a>COMMANDS

  - <a name='1'></a>__::smtpd::start__ ?*myaddr*? ?*port*?

    Start the service listening on *port* or the default port 25\. If
    *myaddr* is given as a domain\-style name or numerical dotted\-quad IP
    address then the server socket will be bound to that network interface\. By
    default the server is bound to all network interfaces\. For example:

    set sock [::smtpd::start [info hostname] 0]

    will bind to the hosts internet interface on the first available port\.

    At present the package only supports a single instance of a SMTP server\.
    This could be changed if required at the cost of making the package a little
    more complicated to read\. If there is a good reason for running multiple
    SMTP services then it will only be necessary to fix the __options__
    array and the __::smtpd::stopped__ variable usage\.

    As the server code uses __fileevent__\(n\) handlers to process the input
    on sockets you will need to run the event loop\. This means either you should
    be running from within __wish__\(1\) or you should
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__\(n\) on the
    __::smtpd::stopped__ variable which is set when the server is stopped\.

  - <a name='2'></a>__::smtpd::stop__

    Halt the server and release the listening socket\. If the server has not been
    started then this command does nothing\. The __::smtpd::stopped__
    variable is set for use with
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__\(n\)\.

    It should be noted that stopping the server does not disconnect any
    currently active sessions as these are operating over an independent
    channel\. Only explicitly tracking and closing these sessions, or exiting the
    server process will close down all the running sessions\. This is similar to
    the usual unix daemon practice where the server performs a __fork__\(2\)
    and the client session continues on the child process\.

  - <a name='3'></a>__::smptd::configure__ ?*option* *value*? ?*option* *value* *\.\.\.*?

    Set configuration options for the SMTP server\. Most values are the name of a
    callback procedure to be called at various points in the SMTP protocol\. See
    the [CALLBACKS](#section5) section for details of the procedures\.

      * __\-banner__ *text*

        Text of a custom banner message\. The default banner is "tcllib smtpd
        1\.5"\. Note that changing the banner does not affect the bracketing text
        in the full greeting, printing status 220, server\-address, and
        timestamp\.

      * __\-validate\_host__ *proc*

        Callback to authenticate new connections based on the ip\-address of the
        client\.

      * __\-validate\_sender__ *proc*

        Callback to authenticate new connections based on the senders email
        address\.

      * __\-validate\_recipient__ *proc*

        Callback to validate and authorize a recipient email address

      * __\-deliverMIME__ *proc*

        Callback used to deliver mail as a mime token created by the tcllib
        __[mime](\.\./mime/mime\.md)__ package\.

      * __\-deliver__ *proc*

        Callback used to deliver email\. This option has no effect if the
        __\-deliverMIME__ option has been set\.

  - <a name='4'></a>__::smtpd::cget__ ?*option*?

    If no *option* is specified the command will return a list of all options
    and their current values\. If an option is specified it will return the value
    of that option\.

# <a name='section5'></a>CALLBACKS

  - __validate\_host__ callback

    This procedure is called with the clients ip address as soon as a connection
    request has been accepted and before any protocol commands are processed\. If
    you wish to deny access to a specific host then an error should be returned
    by this callback\. For example:

    proc validate_host {ipnum} {
       if {[string match "192.168.1.*" $ipnum]} {
          error "go away!"
       }
    }

    If access is denied the client will receive a standard message that includes
    the text of your error, such as:

    550 Access denied: I hate you.

    As per the SMTP protocol, the connection is not closed but we wait for the
    client to send a QUIT command\. Any other commands cause a __503 Bad
    Sequence__ error\.

  - __validate\_sender__ callback

    The validate\_sender callback is called with the senders mail address during
    processing of a MAIL command to allow you to accept or reject mail based
    upon the declared sender\. To reject mail you should throw an error\. For
    example, to reject mail from user "denied":

    proc validate_sender {address} {
       eval array set addr [mime::parseaddress $address]
       if {[string match "denied" $addr(local)]} {
            error "mailbox $addr(local) denied"
       }
       return
    }

    The content of any error message will not be passed back to the client\.

  - __validate\_recipient__ callback

    The validate\_recipient callback is similar to the validate\_sender callback
    and permits you to verify a local mailbox and accept mail for a local user
    address during RCPT command handling\. To reject mail, throw an error as
    above\. The error message is ignored\.

  - __deliverMIME__ callback

    The deliverMIME callback is called once a mail message has been successfully
    passed to the server\. A mime token is constructed from the sender,
    recipients and data and the users procedure it called with this single
    argument\. When the call returns, the mime token is cleaned up so if the user
    wishes to preserve the data she must make a copy\.

    proc deliverMIME {token} {
        set sender [lindex [mime::getheader $token From] 0]
        set recipients [lindex [mime::getheader $token To] 0]
        set mail "From $sender [clock format [clock seconds]]"
        append mail "\n" [mime::buildmessage $token]
        puts $mail
    }

  - __deliver__ callback

    The deliver callback is called once a mail message has been successfully
    passed to the server and there is no \-deliverMIME option set\. The procedure
    is called with the sender, a list of recipients and the text of the mail as
    a list of lines\. For example:

    proc deliver {sender recipients data} {
       set mail "From $sender  [clock format [clock seconds]]"
       append mail "\n" [join $data "\n"]
       puts "$mail"
    }

    Note that the DATA command will return an error if no sender or recipient
    has yet been defined\.

# <a name='section6'></a>VARIABLES

  - __::smtpd::stopped__

    This variable is set to __true__ during the __::smtpd::stop__
    command to permit the use of the
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__\(n\) command\.

# <a name='section7'></a>AUTHOR

Written by Pat Thoyts
[mailto:patthoyts@users\.sourceforge\.net](mailto:patthoyts@users\.sourceforge\.net)\.

# <a name='section8'></a>LICENSE

This software is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE\. See the file "license\.terms" for more details\.

# <a name='section9'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *smtpd* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[rfc 2821](\.\./\.\./\.\./\.\./index\.md\#rfc\_2821), [rfc
821](\.\./\.\./\.\./\.\./index\.md\#rfc\_821),
[services](\.\./\.\./\.\./\.\./index\.md\#services),
[smtp](\.\./\.\./\.\./\.\./index\.md\#smtp), [smtpd](\.\./\.\./\.\./\.\./index\.md\#smtpd),
[socket](\.\./\.\./\.\./\.\./index\.md\#socket),
[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; Pat Thoyts <patthoyts@users\.sourceforge\.net>
