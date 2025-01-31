
[//000000001]: # (comm\_wire \- Remote communication)
[//000000002]: # (Generated from file 'comm\_wire\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Docs\. Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (comm\_wire\(n\) 3 tcllib "Remote communication")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

comm\_wire \- The comm wire protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Wire Protocol Version 3](#section2)

      - [Basic Layer](#subsection1)

      - [Basic Message Layer](#subsection2)

      - [Negotiation Messages \- Initial Handshake](#subsection3)

      - [Script/Command Messages](#subsection4)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require comm  

# <a name='description'></a>DESCRIPTION

The __[comm](comm\.md)__ command provides an inter\-interpreter remote
execution facility much like Tk's __send\(n\)__, except that it uses sockets
rather than the X server for the communication path\. As a result,
__[comm](comm\.md)__ works with multiple interpreters, works on Windows
and Macintosh systems, and provides control over the remote execution path\.

This document contains a specification of the various versions of the wire
protocol used by comm internally for the communication between its endpoints\. It
has no relevance to users of __[comm](comm\.md)__, only to developers who
wish to modify the package, write a compatible facility in a different language,
or some other facility based on the same protocol\.

# <a name='section2'></a>Wire Protocol Version 3

## <a name='subsection1'></a>Basic Layer

The basic encoding for *all* data is UTF\-8\. Because of this binary data,
including the NULL character, can be sent over the wire as is, without the need
for armoring it\.

## <a name='subsection2'></a>Basic Message Layer

On top of the [Basic Layer](#subsection1) we have a *message oriented*
exchange of data\. The totality of all characters written to the channel is a Tcl
list, with each element a separate
*[message](\.\./\.\./\.\./\.\./index\.md\#message)*, each itself a list\. The
messages in the overall list are separated by EOL\. Note that EOL characters can
occur within the list as well\. They can be distinguished from the
message\-separating EOL by the fact that the data from the beginning up to their
location is not a valid Tcl list\.

EOL is signaled through the linefeed character, i\.e __LF__, or, hex
__0x0a__\. This is following the unix convention for line\-endings\.

As a list each message is composed of *words*\. Their meaning depends on when
the message was sent in the overall exchange\. This is described in the upcoming
sections\.

## <a name='subsection3'></a>Negotiation Messages \- Initial Handshake

The command protocol is defined like this:

  - The first message send by a client to a server, when opening the connection,
    contains two words\. The first word is a list as well, and contains the
    versions of the wire protocol the client is willing to accept, with the most
    preferred version first\. The second word is the TCP port the client is
    listening on for connections to itself\. The value __0__ is used here to
    signal that the client will not listen for connections, i\.e\. that it is
    purely for sending commands, and not receiving them\.

  - The first message sent by the server to the client, in response to the
    message above contains only one word\. This word is a list, containing the
    string __vers__ as its first element, and the version of the wire
    protocol the server has selected from the offered versions as the second\.

## <a name='subsection4'></a>Script/Command Messages

All messages coming after the [initial handshake](#subsection3) consist of
three words\. These are an instruction, a transaction id, and the payload\. The
valid instructions are shown below\. The transaction ids are used by the client
to match any incoming replies to the command messages it sent\. This means that a
server has to copy the transaction id from a command message to the reply it
sends for that message\.

  - __send__

  - __async__

  - __command__

    The payload is the Tcl script to execute on the server\. It is actually a
    list containing the script fragments\. These fragment are
    __concat__enated together by the server to form the full script to
    execute on the server side\. This emulates the Tcl "eval" semantics\. In most
    cases it is best to have only one word in the list, a list containing the
    exact command\.

    Examples:

        (a)     {send 1 {{array get tcl_platform}}}
        (b)     {send 1 {array get tcl_platform}}
        (c)     {send 1 {array {get tcl_platform}}}

        are all valid representations of the same command. They are
        generated via

        (a')    send {array get tcl_platform}
        (b')    send array get tcl_platform
        (c')    send array {get tcl_platform}

        respectively

    Note that \(a\), generated by \(a'\), is the usual form, if only single commands
    are sent by the client\. For example constructed using
    __[list](\.\./\.\./\.\./\.\./index\.md\#list)__, if the command contains
    variable arguments\. Like

        send [list array get $the_variable]

    These three instructions all invoke the script on the server side\. Their
    difference is in the treatment of result values, and thus determines if a
    reply is expected\.

      * __send__

        A reply is expected\. The sender is waiting for the result\.

      * __async__

        No reply is expected, the sender has no interest in the result and is
        not waiting for any\.

      * __command__

        A reply is expected, but the sender is not waiting for it\. It has
        arranged to get a process\-internal notification when the result arrives\.

  - __reply__

    Like the previous three command, however the tcl script in the payload is
    highly restricted\. It has to be a syntactically valid Tcl
    __[return](\.\./\.\./\.\./\.\./index\.md\#return)__ command\. This contains
    result code, value, error code, and error info\.

    Examples:

        {reply 1 {return -code 0 {}}}
        {reply 1 {return -code 0 {osVersion 2.4.21-99-default byteOrder littleEndian machine i686 platform unix os Linux user andreask wordSize 4}}}

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *comm* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[comm](comm\.md)

# <a name='keywords'></a>KEYWORDS

[comm](\.\./\.\./\.\./\.\./index\.md\#comm),
[communication](\.\./\.\./\.\./\.\./index\.md\#communication),
[ipc](\.\./\.\./\.\./\.\./index\.md\#ipc),
[message](\.\./\.\./\.\./\.\./index\.md\#message), [remote
communication](\.\./\.\./\.\./\.\./index\.md\#remote\_communication), [remote
execution](\.\./\.\./\.\./\.\./index\.md\#remote\_execution),
[rpc](\.\./\.\./\.\./\.\./index\.md\#rpc), [socket](\.\./\.\./\.\./\.\./index\.md\#socket)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Docs\. Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
