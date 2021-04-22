
[//000000001]: # (nameserv::protocol \- Name service facility)
[//000000002]: # (Generated from file 'nns\_protocol\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nameserv::protocol\(n\) 0\.1 tcllib "Name service facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nameserv::protocol \- Name service facility, client/server protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Nano Name Service Protocol Version 1](#section2)

      - [Basic Layer](#subsection1)

      - [Message Layer](#subsection2)

  - [Nano Name Service Protocol Extension: Continuous Search](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__Bind__ *name* *data*](#1)  
[__Release__](#2)  
[__Search__ *pattern*](#3)  
[__ProtocolVersion__](#4)  
[__ProtocolFeatures__](#5)  
[__Search/Continuous/Start__ *tag* *pattern*](#6)  
[__Search/Continuous/Stop__ *tag*](#7)  
[__Search/Continuous/Change__ *tag* __add__&#124;__remove__ *response*](#8)  

# <a name='description'></a>DESCRIPTION

The packages __[nameserv::server](nns\_server\.md)__,
__[nameserv](nns\_client\.md)__, and
__[nameserv::common](nns\_common\.md)__ provide a simple unprotected name
service facility for use in small trusted environments\.

Please read *[Name service facility, introduction](nns\_intro\.md)* first\.

This document contains the specification of the network protocol which is used
by client and server to talk to each other, enabling implementations of the same
protocol in other languages\.

# <a name='section2'></a>Nano Name Service Protocol Version 1

This protocol defines the basic set of messages to be supported by a name
service, also called the *Core* feature\.

## <a name='subsection1'></a>Basic Layer

The basic communication between client and server is done using the
remote\-execution protocol specified by the Tcl package
__[comm](\.\./comm/comm\.md)__\. The relevant document specifying its
on\-the\-wire protocol can be found in *[comm\_wire](\.\./comm/comm\_wire\.md)*\.

All the scripts exchanged via this protocol are single commands in list form and
thus can be interpreted as plain messages instead of as Tcl commands\. The
commands/messages specified in the next section are the only commands understood
by the server\-side\. Command and variable substitutions are not allowed within
the messages, i\.e\. arguments have to be literal values\.

The protocol is synchronous\. I\.e\. for each message sent a response is expected,
and has to be generated\. All messages are sent by the client\. The server does
not sent messages, only responses to messages\.

## <a name='subsection2'></a>Message Layer

  - <a name='1'></a>__Bind__ *name* *data*

    The client sends this message when it registers itself at the service with a
    *name* and some associated *data*\. The server has to send an error
    response if the *name* is already in use\. Otherwise the response has to be
    an empty string\.

    The server has to accept multiple names for the same client\.

  - <a name='2'></a>__Release__

    The client sends this message to unregister all names it is known under at
    the service\. The response has to be an empty string, always\.

  - <a name='3'></a>__Search__ *pattern*

    The client sends this message to search the service for names matching the
    glob\-*pattern*\. The response has to be a dictionary containing the
    matching names as keys, and mapping them to the data associated with it at
    __Bind__\-time\.

  - <a name='4'></a>__ProtocolVersion__

    The client sends this message to query the service for the highest version
    of the name service protocol it supports\. The response has to be a positive
    integer number\.

    Servers supporting only *Nano Name Service Protocol Version 1* have to
    return __1__\.

  - <a name='5'></a>__ProtocolFeatures__

    The client sends this message to query the service for the features of the
    name service protocol it supports\. The response has to be a list containing
    feature names\.

    Servers supporting only *Nano Name Service Protocol Version 1* have to
    return __\{Core\}__\.

# <a name='section3'></a>Nano Name Service Protocol Extension: Continuous Search

This protocol defines an extended set of messages to be supported by a name
service, also called the *Search/Continuous* feature\. This feature defines
additional messages between client and server, and is otherwise identical to
version 1 of the protocol\. See the last section for the details of our
foundation\.

A service supporting this feature has to put the feature name
__Search/Continuous__ into the list of features returned by the message
*ProtocolFeatures*\.

For this extension the protocol is asynchronous\. No direct response is expected
for any of the messages in the extension\. Furthermore the server will start
sending messages on its own, instead of only responses to messages, and the
client has to be able to handle these notifications\.

  - <a name='6'></a>__Search/Continuous/Start__ *tag* *pattern*

    The client sends this message to start searching the service for names
    matching the glob\-*pattern*\. In contrast to the regular *Search* request
    this one asks the server to continuously monitor the database for the
    addition and removal of matching entries and to notify the client of all
    such changes\. The particular search is identified by the *tag*\.

    No direct response is expected, rather the clients expect to be notified of
    changes via explicit *Search/Continuous/Result* messages generated by the
    service\.

    It is further expected that the *tag* information is passed unchanged to
    the *Search/Continuous/Result* messages\. This tagging of the results
    enables clients to start multiple searches and distinguish between the
    different results\.

  - <a name='7'></a>__Search/Continuous/Stop__ *tag*

    The client sends this message to stop the continuous search identified by
    the *tag*\.

  - <a name='8'></a>__Search/Continuous/Change__ *tag* __add__&#124;__remove__ *response*

    This message is sent by the service to clients with active continuous
    searches to transfer found changes\. The first such message for a new
    continuous search has to contains the current set of matching entries\.

    To ensure this a service has to generate an __add__\-message with an
    empty *response* if there were no matching entries at the time\.

    The *response* has to be a dictionary containing the matching names as
    keys, and mapping them to the data associated with it at __Bind__\-time\.
    The argument coming before the response tells the client whether the names
    in the response were added or removed from the service\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *nameserv* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[comm\_wire\(n\)](\.\./comm/comm\_wire\.md), [nameserv\(n\)](nns\_client\.md),
[nameserv::server\(n\)](nns\_server\.md)

# <a name='keywords'></a>KEYWORDS

[comm](\.\./\.\./\.\./\.\./index\.md\#comm), [name
service](\.\./\.\./\.\./\.\./index\.md\#name\_service),
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
