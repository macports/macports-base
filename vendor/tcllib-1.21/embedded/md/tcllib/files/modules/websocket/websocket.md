
[//000000001]: # (websocket \- websocket client and server)
[//000000002]: # (Generated from file 'websocket\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (websocket\(n\) 1\.4\.2 tcllib "websocket client and server")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

websocket \- Tcl implementation of the websocket protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Callbacks](#section2)

  - [API](#section3)

  - [Examples](#section4)

  - [TLS Security Considerations](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require http 2\.7  
package require logger  
package require sha1  
package require base64  
package require websocket ?1\.4\.2?  

[__::websocket::open__ *url* *handler* ?*options*?](#1)  
[__::websocket::send__ *sock* *type* ?*msg*? ?*final*?](#2)  
[__::websocket::server__ *sock*](#3)  
[__::websocket::live__ *sock* *path* *cb* ?*proto*?](#4)  
[__::websocket::test__ *srvSock* *cliSock* *path* ?*hdrs*? ?*qry*?](#5)  
[__::websocket::upgrade__ *sock*](#6)  
[__::websocket::takeover__ *sock* *handler* ?*server*?](#7)  
[__::websocket::conninfo__ *sock* *what*](#8)  
[__::websocket::find__ ?*host*? ?*port*?](#9)  
[__::websocket::configure__ *sock* *args*](#10)  
[__::websocket::loglevel__ ?*loglvl*?](#11)  
[__::websocket::close__ *sock* ?*code*? ?*reason*?](#12)  

# <a name='description'></a>DESCRIPTION

NOTE: THIS DOCUMENTATION IS WORK IN PROGRESS\.\.\.

The websocket library is a pure Tcl implementation of the WebSocket
specification covering the needs of both clients and servers\. Websockets provide
a way to upgrade a regular HTTP connection into a long\-lived and continuous
binary or text communication between the client and the server\. The library
offers a high\-level interface to receive and send data as specified in RFC 6455
\(v\. 13 of the protocol\), relieving callers from all necessary protocol framing
and reassembly\. It implements the ping facility specified by the standard,
together with levers to control it\. Pings are server\-driven and ensure the
liveness of the connection across home \(NAT\) networks\. The library has a number
of introspection facilities to inquire about the current state of the
connection, but also to receive notifications of incoming pings, if necessary\.
Finally, the library contains a number of helper procedures to facilitate the
upgrading handshaking in existing web servers\.

Central to the library is the procedure __websocket::takeover__ that will
take over a regular socket and treat it as a WebSocket, thus performing all
necessary protocol framing, packetisation and reassembly in servers and clients\.
The procedure also takes a handler, a command that will be called back each time
a \(possibly reassembled\) packet from the remote end is ready for delivery at the
original caller\. While exported by the package, the command
__websocket::takeover__ is seldom called in applications, since the package
provides other commands that are specifically tuned for the needs of clients and
servers\.

Typically, clients will open a connection to a remote server by providing a
WebSocket URL \(*ws:* or *wss:* schemes\) and the handler described above to
the command __websocket::open__\. The opening procedure is a wrapper around
the latest http::geturl implementations: it arranges to keep the socket created
within the http library opened for reuse, but confiscates it from its \(internal\)
map of known sockets for its own use\.

Servers will start by registering themselves through the command
__::websocket::server__ and a number of handlers for paths using the command
__::websocket::live__\. Then for each incoming client connection, they should
test the incoming request to detect if it is an upgrade request using
__::websocket::test__ and perform the final handshake to place the socket
connection under the control of the websocket library and its central procedure
using __::websocket::upgrade__\.

Apart from these main commands, the package provides a number of commands for
introspection and basic operations on the websockets that it has under its
control\. As WebSockets connections are long\-lived, most remaining communication
with the library will be by way of callbacks, i\.e\. commands that are triggered
whenever important events within the library have occur, but mostly whenever
data has been received on a WebSocket\.

# <a name='section2'></a>Callbacks

A number of commands of the library take a handler handler command as an
argument, a command which will be called back upon reception of data, but also
upon important events within the library or events resulting from control
messages sent by the remote end\. For each callback being performed, the
following arguments will be appended:

  - *sock*

    The identifier of the WebSocket, as returned for example by
    __::websocket::open__

  - *type*

    A textual type describing the event or message content, can be one of the
    following

      * __text__

        Complete text message

      * __binary__

        Complete binary message

      * __ping__

        Incoming ping message

      * __connect__

        Notification of successful connection to server

      * __disconnect__

        Disconnection from remote end

      * __close__

        Pending closure of connection

  - *msg*

    Will contain the data of the message, whenever this is relevant, i\.e\. when
    the *type* is __text__, __binary__ or __ping__ and whenever
    there is data available\.

# <a name='section3'></a>API

  - <a name='1'></a>__::websocket::open__ *url* *handler* ?*options*?

    This command is used in clients to open a WebSocket to a remote
    websocket\-enabled HTTP server\. The URL provided as an argument in *url*
    should start with ws: or wss:, which are the WebSockets counterpart of http:
    and https:\. The *handler* is a command that will be called back on data
    reception or whenever important events occur during the life of the
    websocket\. __::websocket::open__ will return a socket which serves as
    both the identifier of the websocket and of the physical low\-level socket to
    the server\. This socket can be used in a number of other commands for
    introspection or for controlling the behaviour of the library\. Being
    essentially a wrapper around the __::http::geturl__ command, this
    command provides mostly the same set of dash\-led options than
    __::http::geturl__\. Documented below are the options that differ from
    __::http::geturl__ and which are specific to the WebSocket library\.

      * \-headers

        This option is supported, knowing that a number of headers will be
        automatically added internally in the library in order to be able to
        handshake the upgrading of the socket from a regular HTTP socket to a
        WebSocket with the server\.

      * \-validate

        This option is not supported as it has no real point for WebSockets\.

      * \-handler

        This option is used internally by the websocket library and cannot be
        used\.

      * \-command

        This option is used internally by the websocket library and cannot be
        used\.

      * \-protocol

        This option specifies a list of application protocols to handshake with
        the server\. This protocols might help the server triggering application
        specific features\.

      * \-timeout

        This option is supported, but will implemented as part of the library to
        enable a number of finalising cleanups\.

  - <a name='2'></a>__::websocket::send__ *sock* *type* ?*msg*? ?*final*?

    This command will send a fragment or a control message to the remote end of
    the WebSocket identified by *sock*\. The type of the message specified in
    *type* can either be an integer according to the specification or
    \(preferrably\) one of the following case insensitive strings: "text",
    "binary" or "ping"\. The content of the message to send to the remote end is
    contained in *msg* and message fragmentation is made possible by the
    setting the argument *final* to non\-true, knowing that the type of each
    fragment has then to be the same\. The command returns the number of bytes
    that were effectively sent, or \-1 on errors\. Serious errors, such as when
    *sock* does not identify a known WebSocket or when the connection is not
    stable yet will generate errors that must be catched\.

  - <a name='3'></a>__::websocket::server__ *sock*

    This command registers the \(accept\) socket *sock* as the identifier fo an
    HTTP server that is capable of doing WebSockets\. Paths onto which this
    server will listen for incoming connections should be declared using
    __::websocket::live__\.

  - <a name='4'></a>__::websocket::live__ *sock* *path* *cb* ?*proto*?

    This procedure registers callbacks that will be performed on a WebSocket
    compliant server registered with __::websocket::server__ whenever a
    client connects to a matching path and protocol\. *sock* is the listening
    socket of the websocket compliant server declared using
    __::websocket::server__\. *path* is a glob\-style path to match in
    client request, whenever this will occur\. *cb* is the command to callback
    \(see Callbacks\)\. *proto* is a glob\-style protocol name matcher\.

  - <a name='5'></a>__::websocket::test__ *srvSock* *cliSock* *path* ?*hdrs*? ?*qry*?

    This procedure will test if the connection from an incoming client on socket
    *cliSock* and on the path *path* is the opening of a WebSocket stream
    within a known server *srvSock*\. The incoming request is not upgraded at
    once, instead a \(temporary\) context for the incoming connection is created\.
    This allows server code to perform a number of actions, if necessary, before
    the WebSocket stream connection goes live\. The text is made by analysing the
    content of the headers *hdrs* which should contain a dictionary list of
    the HTTP headers of the incoming client connection\. The command will return
    __1__ if this is an incoming WebSocket upgrade request and __0__
    otherwise\.

  - <a name='6'></a>__::websocket::upgrade__ *sock*

    Upgrade the socket *sock* that had been deemed by
    __::websocket::test__ to be a WebSocket connection request to a true
    WebSocket as recognised by this library\. As a result, the necessary
    connection handshake will be sent to the client, and the command will
    arrange for relevant callbacks to be made during the life of the WebSocket,
    notably using the specifications described by __::websocket::live__\.

  - <a name='7'></a>__::websocket::takeover__ *sock* *handler* ?*server*?

    Take over the existing opened socket *sock* to implement sending and
    receiving WebSocket framing on top of the socket\. The procedure arranges for
    *handler* to be called back whenever messages, control messages or other
    important internal events are received or occured\. *server* defaults to
    __0__ and can be set to __1__ \(or a boolean that evaluates to true\)
    to specify that this is a WebSocket within a server\. Apart from
    specificities in the protocol, servers should ping their clients at regular
    intervals in order to keep the connection opened at all time\. When
    *server* is set to true, the library will arrange to send these pings
    automatically\.

  - <a name='8'></a>__::websocket::conninfo__ *sock* *what*

    Provides callers with some introspection facilities in order to get some
    semi\-internal information about an existing websocket connection\. Depending
    on the value of the *what* argument, the procedure returns the following
    piece of information:

      * __peername__

        Name \(preferred\) or IP of remote end\.

      * __sockname__

        or __name__ Name or IP of local end\.

      * __closed__

        __1__ if the connection is closed, __0__ otherwise

      * __client__

        __1__ if the connection is a client websocket, __0__ otherwise

      * __server__

        __1__ if the connection is a server websocket, __0__ otherwise

      * __type__

        __server__ if the connection is a server websocket, __client__
        otherwise\.

      * __handler__

        The handler command associated to the websocket

      * __state__

        The state of the websocket, which can be one of:

          + __CONNECTING__

            Connection to remote end is in progress\.

          + __CONNECTED__

            Connection is connected to remote end\.

          + __CLOSED__

            Connection is closed\.

  - <a name='9'></a>__::websocket::find__ ?*host*? ?*port*?

    Look among existing websocket connections for the ones that match the
    hostname and port number filters passed as parameters\. This lookup takes the
    remote end into account and the *host* argument is matched both against
    the hostname \(whenever available\) and the IP address of the remote end\. Both
    the *host* and *port* arguments are glob\-style string matching filters
    and default to __\*__, i\.e\. will match any host and/or port number\.

  - <a name='10'></a>__::websocket::configure__ *sock* *args*

    This command takes a number of dash\-led options \(and their values\) to
    configure the behaviour of an existing websocket connection\. The recognised
    options are the following \(they can be shortened to the lowest common
    denominator\):

      * __\-keepalive__

        is the number of seconds between each keepalive pings being sent along
        the connection\. A zero or negative number will effectively turn off the
        feature\. In servers, __\-keepalive__ defaults to 30 seconds, and in
        clients, no pings are initiated\.

      * __\-ping__

        is the text that is used during the automated pings\. This text defaults
        to the empty string, leading to an empty ping\.

  - <a name='11'></a>__::websocket::loglevel__ ?*loglvl*?

    Set or query the log level of the library, which defaults to error\. Logging
    is built on top of the logger module, and the library makes use of the
    following levels: __debug__, __info__, __notice__, __warn__
    and __error__\. When called with no argument, this procedure will simply
    return the current log level\. Otherwise *loglvl* should contain the
    desired log level\.

  - <a name='12'></a>__::websocket::close__ *sock* ?*code*? ?*reason*?

    Gracefully close a websocket that was directly or indirectly passed to
    __::websocket::takeover__\. The procedure will optionally send the
    *code* and describing *reason* as part of the closure handshake\. Good
    defaults are provided, so that reasons for a number of known codes will be
    sent back\. Only the first 125 characters of a reason string will be kept and
    sent as part of the handshake\. The known codes are:

      * __1000__

        Normal closure \(the default *code* when none provided\)\.

      * __1001__

        Endpoint going away

      * __1002__

        Protocol Error

      * __1003__

        Received incompatible data type

      * __1006__

        Abnormal closure

      * __1007__

        Received data not consistent with type

      * __1008__

        Policy violation

      * __1009__

        Received message too big

      * __1010__

        Missing extension

      * __1011__

        Unexpected condition

      * __1015__

        TLS handshake error

# <a name='section4'></a>Examples

The following example opens a websocket connection to the echo service, waits
400ms to ensure that the connection is really established and sends a single
textual message which should be echoed back by the echo service\. A real example
would probably use the __connect__ callback to know when connection to the
remote server has been establish and would only send data at that time\.

    package require websocket
    ::websocket::loglevel debug

    proc handler { sock type msg } {
        switch -glob -nocase -- $type {
    	co* {
    	    puts "Connected on $sock"
    	}
    	te* {
    	    puts "RECEIVED: $msg"
    	}
    	cl* -
    	dis* {
    	}
        }

    }

    proc test { sock } {
        puts "[::websocket::conninfo $sock type] from [::websocket::conninfo $sock sockname] to [::websocket::conninfo $sock peername]"

        ::websocket::send $sock text "Testing, testing..."
    }

    set sock [::websocket::open ws://echo.websocket.org/ handler]
    after 400 test $sock
    vwait forever

# <a name='section5'></a>TLS Security Considerations

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

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *websocket* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[http](\.\./\.\./\.\./\.\./index\.md\#http)

# <a name='keywords'></a>KEYWORDS

[http](\.\./\.\./\.\./\.\./index\.md\#http),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[net](\.\./\.\./\.\./\.\./index\.md\#net), [rfc
6455](\.\./\.\./\.\./\.\./index\.md\#rfc\_6455)

# <a name='category'></a>CATEGORY

Networking
