
[//000000001]: # (multiplexer \- One\-to\-many communication with sockets\.)
[//000000002]: # (Generated from file 'multiplexer\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (multiplexer\(n\) 0\.2 tcllib "One\-to\-many communication with sockets\.")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

multiplexer \- One\-to\-many communication with sockets\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require logger  
package require multiplexer ?0\.2?  

[__::multiplexer::create__](#1)  
[__$\{multiplexer\_instance\}::Init__ *port*](#2)  
[__$\{multiplexer\_instance\}::Config__ *key* *value*](#3)  
[__$\{multiplexer\_instance\}::AddFilter__ *cmdprefix*](#4)  
[__cmdprefix__ *data* *chan* *clientaddress* *clientport*](#5)  
[__$\{multiplexer\_instance\}::AddAccessFilter__ *cmdprefix*](#6)  
[__cmdprefix__ *chan* *clientaddress* *clientport*](#7)  
[__$\{multiplexer\_instance\}::AddExitFilter__ *cmdprefix*](#8)  
[__cmdprefix__ *chan* *clientaddress* *clientport*](#9)  

# <a name='description'></a>DESCRIPTION

The __multiplexer__ package provides a generic system for one\-to\-many
communication utilizing sockets\. For example, think of a chat system where one
user sends a message which is then broadcast to all the other connected users\.

It is possible to have different multiplexers running concurrently\.

  - <a name='1'></a>__::multiplexer::create__

    The __create__ command creates a new multiplexer 'instance'\. For
    example:

        set mp [::multiplexer::create]

    This instance can then be manipulated like so:

        ${mp}::Init 35100

  - <a name='2'></a>__$\{multiplexer\_instance\}::Init__ *port*

    This starts the multiplexer listening on the specified port\.

  - <a name='3'></a>__$\{multiplexer\_instance\}::Config__ *key* *value*

    Use __Config__ to configure the multiplexer instance\. Configuration
    options currently include:

      * __sendtoorigin__

        A boolean flag\. If __true__, the sender will receive a copy of the
        sent message\. Defaults to __false__\.

      * __debuglevel__

        Sets the debug level to use for the multiplexer instance, according to
        those specified by the __[logger](\.\./log/logger\.md)__ package
        \(debug, info, notice, warn, error, critical\)\.

  - <a name='4'></a>__$\{multiplexer\_instance\}::AddFilter__ *cmdprefix*

    Command to add a filter for data that passes through the multiplexer
    instance\. The registered *cmdprefix* is called when data arrives at a
    multiplexer instance\. If there is more than one filter command registered at
    the instance they will be called in the order of registristation, and each
    filter will get the result of the preceding filter as its argument\. The
    first filter gets the incoming data as its argument\. The result returned by
    the last filter is the data which will be broadcast to all clients of the
    multiplexer instance\. The command prefix is called as

      * <a name='5'></a>__cmdprefix__ *data* *chan* *clientaddress* *clientport*

        Takes the incoming *data*, modifies it, and returns that as its
        result\. The last three arguments contain information about the client
        which sent the data to filter: The channel connecting us to the client,
        its ip\-address, and its ip\-port\.

  - <a name='6'></a>__$\{multiplexer\_instance\}::AddAccessFilter__ *cmdprefix*

    Command to add an access filter\. The registered *cmdprefix* is called when
    a new client socket tries to connect to the multixer instance\. If there is
    more than one access filter command registered at the instance they will be
    called in the order of registristation\. If any of the called commands
    returns __\-1__ the access to the multiplexer instance is denied and the
    client channel is closed immediately\. Any other result grants the client
    access to the multiplexer instance\. The command prefix is called as

      * <a name='7'></a>__cmdprefix__ *chan* *clientaddress* *clientport*

        The arguments contain information about the client which tries to
        connected to the instance: The channel connecting us to the client, its
        ip\-address, and its ip\-port\.

  - <a name='8'></a>__$\{multiplexer\_instance\}::AddExitFilter__ *cmdprefix*

    Adds filter to be run when client socket generates an EOF condition\. The
    registered *cmdprefix* is called when a client socket of the multixer
    signals EOF\. If there is more than one exit filter command registered at the
    instance they will be called in the order of registristation\. Errors thrown
    by an exit filter are ignored, but logged\. Any result returned by an exit
    filter is ignored\. The command prefix is called as

      * <a name='9'></a>__cmdprefix__ *chan* *clientaddress* *clientport*

        The arguments contain information about the client which signaled the
        EOF: The channel connecting us to the client, its ip\-address, and its
        ip\-port\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *multiplexer* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[chat](\.\./\.\./\.\./\.\./index\.md\#chat),
[multiplexer](\.\./\.\./\.\./\.\./index\.md\#multiplexer)

# <a name='category'></a>CATEGORY

Programming tools
