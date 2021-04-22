
[//000000001]: # (irc \- Low Level Tcl IRC Interface)
[//000000002]: # (Generated from file 'irc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (irc\(n\) 0\.7\.0 tcllib "Low Level Tcl IRC Interface")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

irc \- Create IRC connection and interface\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Per\-connection Commands](#section2)

  - [Callback Commands](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require irc ?0\.7\.0?  

[__::irc::config__ ?key? ?value?](#1)  
[__::irc::connection__](#2)  
[__::irc::connections__](#3)  
[*net* __registerevent__ *event* *script*](#4)  
[*net* __getevent__ *event* *script*](#5)  
[*net* __eventexists__ *event* *script*](#6)  
[*net* __connect__ *hostname* ?port?](#7)  
[*net* __config__ ?key? ?value?](#8)  
[*net* __log__ *level* *message*](#9)  
[*net* __logname__](#10)  
[*net* __connected__](#11)  
[*net* __sockname__](#12)  
[*net* __peername__](#13)  
[*net* __socket__](#14)  
[*net* __user__ *username* *localhostname* *localdomainname* *userinfo*](#15)  
[*net* __nick__ *nick*](#16)  
[*net* __ping__ *target*](#17)  
[*net* __serverping__](#18)  
[*net* __join__ *channel* ?*key*?](#19)  
[*net* __part__ *channel* ?*message*?](#20)  
[*net* __quit__ ?*message*?](#21)  
[*net* __privmsg__ *target* *message*](#22)  
[*net* __notice__ *target* *message*](#23)  
[*net* __ctcp__ *target* *message*](#24)  
[*net* __kick__ *channel* *target* ?*message*?](#25)  
[*net* __mode__ *target* *args*](#26)  
[*net* __topic__ *channel* *message*](#27)  
[*net* __invite__ *channel* *target*](#28)  
[*net* __send__ *text*](#29)  
[*net* __destroy__](#30)  
[__who__ ?__address__?](#31)  
[__action__](#32)  
[__target__](#33)  
[__additional__](#34)  
[__header__](#35)  
[__msg__](#36)  

# <a name='description'></a>DESCRIPTION

This package provides low\-level commands to deal with the IRC protocol \(Internet
Relay Chat\) for immediate and interactive multi\-cast communication\.

  - <a name='1'></a>__::irc::config__ ?key? ?value?

    Sets configuration ?key? to ?value?\. The configuration keys currently
    defined are the boolean flags __logger__ and __debug__\.
    __logger__ makes __irc__ use the logger package for printing error\.
    __debug__ requires __logger__ and prints extra debug output\. If no
    ?key? or ?value? is given the current values are returned\.

  - <a name='2'></a>__::irc::connection__

    The command creates a new object to deal with an IRC connection\. Creating
    this IRC object does not automatically create the network connection\. It
    returns a new irc namespace command which can be used to interact with the
    new IRC connection\. NOTE: the old form of the connection command, which took
    a hostname and port as arguments, is deprecated\. Use __connect__ instead
    to specify this information\.

  - <a name='3'></a>__::irc::connections__

    Returns a list of all the current connections that were created with
    __connection__

# <a name='section2'></a>Per\-connection Commands

In the following list of available connection methods *net* represents a
connection command as returned by __::irc::connection__\.

  - <a name='4'></a>*net* __registerevent__ *event* *script*

    Registers a callback handler for the specific event\. Events available are
    those described in RFC 1459
    [http://www\.rfc\-editor\.org/rfc/rfc1459\.txt](http://www\.rfc\-editor\.org/rfc/rfc1459\.txt)\.
    In addition, there are several other events defined\. __defaultcmd__ adds
    a command that is called if no other callback is present\. __EOF__ is
    called if the connection signals an End of File condition\. The events
    __defaultcmd__, __defaultnumeric__, __defaultevent__, and
    __EOF__ are required\. *script* is executed in the connection
    namespace, which can take advantage of several commands \(see [Callback
    Commands](#section3) below\) to aid in the parsing of data\.

  - <a name='5'></a>*net* __getevent__ *event* *script*

    Returns the current handler for the event if one exists\. Otherwise an empty
    string is returned\.

  - <a name='6'></a>*net* __eventexists__ *event* *script*

    Returns a boolean value indicating the existence of the event handler\.

  - <a name='7'></a>*net* __connect__ *hostname* ?port?

    This causes the socket to be established\. __::irc::connection__ created
    the namespace and the commands to be used, but did not actually open the
    socket\. This is done here\. NOTE: the older form of 'connect' did not require
    the user to specify a hostname and port, which were specified with
    'connection'\. That form is deprecated\.

  - <a name='8'></a>*net* __config__ ?key? ?value?

    The same as __::irc::config__ but sets and gets options for the *net*
    connection only\.

  - <a name='9'></a>*net* __log__ *level* *message*

    If logger is turned on by __config__ this will write a log *message*
    at *level*\.

  - <a name='10'></a>*net* __logname__

    Returns the name of the logger instance if logger is turned on\.

  - <a name='11'></a>*net* __connected__

    Returns a boolean value indicating if this connection is connected to a
    server\.

  - <a name='12'></a>*net* __sockname__

    Returns a 3 element list consisting of the ip address, the hostname, and the
    port of the local end of the connection, if currently connected\.

  - <a name='13'></a>*net* __peername__

    Returns a 3 element list consisting of the ip address, the hostname, and the
    port of the remote end of the connection, if currently connected\.

  - <a name='14'></a>*net* __socket__

    Return the Tcl channel for the socket used by the connection\.

  - <a name='15'></a>*net* __user__ *username* *localhostname* *localdomainname* *userinfo*

    Sends USER command to server\. *username* is the username you want to
    appear\. *localhostname* is the host portion of your hostname,
    *localdomainname* is your domain name, and *userinfo* is a short
    description of who you are\. The 2nd and 3rd arguments are normally ignored
    by the IRC server\.

  - <a name='16'></a>*net* __nick__ *nick*

    NICK command\. *nick* is the nickname you wish to use for the particular
    connection\.

  - <a name='17'></a>*net* __ping__ *target*

    Send a CTCP PING to *target*\.

  - <a name='18'></a>*net* __serverping__

    PING the server\.

  - <a name='19'></a>*net* __join__ *channel* ?*key*?

    *channel* is the IRC channel to join\. IRC channels typically begin with a
    hashmark \("\#"\) or ampersand \("&"\)\.

  - <a name='20'></a>*net* __part__ *channel* ?*message*?

    Makes the client leave *channel*\. Some networks may support the optional
    argument *message*

  - <a name='21'></a>*net* __quit__ ?*message*?

    Instructs the IRC server to close the current connection\. The package will
    use a generic default if no *message* was specified\.

  - <a name='22'></a>*net* __privmsg__ *target* *message*

    Sends *message* to *target*, which can be either a channel, or another
    user, in which case their nick is used\.

  - <a name='23'></a>*net* __notice__ *target* *message*

    Sends a __notice__ with message *message* to *target*, which can be
    either a channel, or another user, in which case their nick is used\.

  - <a name='24'></a>*net* __ctcp__ *target* *message*

    Sends a CTCP of type *message* to *target*

  - <a name='25'></a>*net* __kick__ *channel* *target* ?*message*?

    Kicks the user *target* from the channel *channel* with a *message*\.
    The latter can be left out\.

  - <a name='26'></a>*net* __mode__ *target* *args*

    Sets the mode *args* on the target *target*\. *target* may be a
    channel, a channel user, or yourself\.

  - <a name='27'></a>*net* __topic__ *channel* *message*

    Sets the topic on *channel* to *message* specifying an empty string will
    remove the topic\.

  - <a name='28'></a>*net* __invite__ *channel* *target*

    Invites *target* to join the channel *channel*

  - <a name='29'></a>*net* __send__ *text*

    Sends *text* to the IRC server\.

  - <a name='30'></a>*net* __destroy__

    Deletes the connection and its associated namespace and information\.

# <a name='section3'></a>Callback Commands

These commands can be used within callbacks

  - <a name='31'></a>__who__ ?__address__?

    Returns the nick of the user who performed a command\. The optional keyword
    __address__ causes the command to return the user in the format
    "username@address"\.

  - <a name='32'></a>__action__

    Returns the action performed, such as KICK, PRIVMSG, MODE, etc\.\.\. Normally
    not useful, as callbacks are bound to a particular event\.

  - <a name='33'></a>__target__

    Returns the target of a particular command, such as the channel or user to
    whom a PRIVMSG is sent\.

  - <a name='34'></a>__additional__

    Returns a list of any additional arguments after the target\.

  - <a name='35'></a>__header__

    Returns the entire event header \(everything up to the :\) as a proper list\.

  - <a name='36'></a>__msg__

    Returns the message portion of the command \(the part after the :\)\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *irc* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

rfc 1459

# <a name='keywords'></a>KEYWORDS

[chat](\.\./\.\./\.\./\.\./index\.md\#chat), [irc](\.\./\.\./\.\./\.\./index\.md\#irc)

# <a name='category'></a>CATEGORY

Networking
