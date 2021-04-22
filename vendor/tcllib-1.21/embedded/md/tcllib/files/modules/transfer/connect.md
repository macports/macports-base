
[//000000001]: # (transfer::connect \- Data transfer facilities)
[//000000002]: # (Generated from file 'connect\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::connect\(n\) 0\.2 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::connect \- Connection setup

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

      - [Options](#subsection4)

  - [Secure connections](#section3)

  - [TLS Security Considerations](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit ?1\.0?  
package require transfer::connect ?0\.2?  

[__transfer::connect__ *objectName* ?*options*\.\.\.?](#1)  
[*objectName* __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __connect__ *command*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides objects holding enough information to enable them to
either actively connect to a counterpart, or to passively wait for a connection
from said counterpart\. I\.e\. any object created by this packages is always in one
of two complementary modes, called *[active](\.\./\.\./\.\./\.\./index\.md\#active)*
\(the object initiates the connection\) and
*[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* \(the object receives the
connection\)\.

Of the two objects in a connecting pair one has to be configured for
*[active](\.\./\.\./\.\./\.\./index\.md\#active)* mode, and the other then has to be
configured for *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* mode\. This
establishes which of the two partners connects to whom \(the
*[active](\.\./\.\./\.\./\.\./index\.md\#active)* to the other\), or, who is waiting
on whom \(the *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* on the other\)\. Note
that this is completely independent of the direction of any data transmission
using the connection after it has been established\. An active object can, after
establishing the connection, either transmit or receive data\. Equivalently the
passive object can do the same after the waiting for its partner has ended\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__transfer::connect__ *objectName* ?*options*\.\.\.?

    This command creates a new connection object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The set of supported *options* is explained in
    section [Options](#subsection4)\.

    The object command will be created under the current namespace if the
    *objectName* is not fully qualified, and in the specified namespace
    otherwise\. The fully qualified name of the object command is returned as the
    result of the command\.

## <a name='subsection2'></a>Object command

All objects created by the __::transfer::connect__ command have the
following general form:

  - <a name='2'></a>*objectName* __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object\. This is safe to do for an
    *[active](\.\./\.\./\.\./\.\./index\.md\#active)* object when a connection has
    been started, as the completion callback is synchronous\. For a
    *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* object currently waiting for
    its partner to establish the connection however this is not safe and will
    cause errors later on, when the connection setup completes and tries to
    access the now missing data structures of the destroyed object\.

  - <a name='4'></a>*objectName* __connect__ *command*

    This method starts the connection setup per the configuration of the object\.
    When the connection is established the callback *command* will be invoked
    with one additional argument, the channel handle of the socket over which
    data can be transfered\.

    The detailed behaviour of the method depends on the configured mode\.

      * *[active](\.\./\.\./\.\./\.\./index\.md\#active)*

        The connection setup is done synchronously\. The object waits until the
        connection is established\. The method returns the empty string as its
        result\.

      * *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)*

        The connection setup is done asynchronously\. The method returns
        immediately after a listening socket has been set up\. The connection
        will be established in the background\. The method returns the port
        number of the listening socket, for use by the caller\. One important use
        is the transfer of this information to the counterpart so that it knows
        where it has to connect to\.

        This is necessary as the object might have been configured for port
        __0__, allowing the operating system to choose the actual port it
        will listen on\.

        The listening port is closed immediately when the connection was
        established by the partner, to keep the time interval small within which
        a third party can connect to the port too\. Even so it is recommended to
        use additional measures in the protocol outside of the connect and
        transfer object to ensure that a connection is not used with an
        unidentified/unauthorized partner One possibility for this is the use of
        SSL/TLS\. See the option __\-socketcmd__ and section [Secure
        connections](#section3) for information on how to do this\.

## <a name='subsection4'></a>Options

Connection objects support the set of options listed below\.

  - __\-mode__ *mode*

    This option specifies the mode the object is in\. It is optional and defaults
    to __active__ mode\. The two possible modes are:

      * __active__

        In this mode the two options __\-host__ and __\-port__ are
        relevant and specify the host and TCP port the object has to connect to\.
        The host is given by either name or IP address\.

      * __passive__

        In this mode the option __\-host__ has no relevance and is ignored
        should it be configured\. The only option the object needs is
        __\-port__, and it specifies the TCP port on which the listening
        socket is opened to await the connection from the partner\.

  - __\-host__ *hostname\-or\-ipaddr*

    This option specifies the host to connect to in
    *[active](\.\./\.\./\.\./\.\./index\.md\#active)* mode, either by name or
    ip\-address\. An object configured for
    *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* mode ignores this option\.

  - __\-port__ *int*

    For *[active](\.\./\.\./\.\./\.\./index\.md\#active)* mode this option specifies
    the port the object is expected to connect to\. For
    *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* mode however it is the port
    where the object creates the listening socket waiting for a connection\. It
    defaults to __0__, which allows the OS to choose the actual port to
    listen on\.

  - __\-socketcmd__ *command*

    This option allows the user to specify which command to use to open a
    socket\. The default is to use the builtin __::socket__\. Any compatible
    with that command is allowed\.

    The envisioned main use is the specfication of __tls::socket__\. I\.e\.
    this option allows the creation of secure transfer channels, without making
    this package explicitly dependent on the
    __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__ package\.

    See also section [Secure connections](#section3)\.

  - __\-encoding__ encodingname

  - __\-eofchar__ eofspec

  - __\-translation__ transspec

    These options are the same as are recognized by the builtin command
    __fconfigure__\. They provide the configuration to be set for the channel
    between the two partners after it has been established, but before the
    callback is invoked \(See method __connect__\)\.

# <a name='section3'></a>Secure connections

One way to secure connections made by objects of this package is to require the
package __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__ and then configure the
option __\-socketcmd__ to force the use of command __tls::socket__ to
open the socket\.

    # Load and initialize tls
    package require tls
    tls::init -cafile /path/to/ca/cert -keyfile ...

    # Create a connector with secure socket setup,
    transfer::connect C -socketcmd tls::socket ...
    ...

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

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *transfer* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[active](\.\./\.\./\.\./\.\./index\.md\#active),
[channel](\.\./\.\./\.\./\.\./index\.md\#channel),
[connection](\.\./\.\./\.\./\.\./index\.md\#connection),
[passive](\.\./\.\./\.\./\.\./index\.md\#passive),
[secure](\.\./\.\./\.\./\.\./index\.md\#secure), [ssl](\.\./\.\./\.\./\.\./index\.md\#ssl),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls),
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
