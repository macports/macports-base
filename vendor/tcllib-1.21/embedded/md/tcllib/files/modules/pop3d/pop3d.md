
[//000000001]: # (pop3d \- Tcl POP3 Server Package)
[//000000002]: # (Generated from file 'pop3d\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2005 Reinhard Max  <max@suse\.de>)
[//000000005]: # (pop3d\(n\) 1\.1\.0 tcllib "Tcl POP3 Server Package")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pop3d \- Tcl POP3 server implementation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Options](#section2)

  - [Authentication](#section3)

  - [Mailboxes](#section4)

  - [Secure mail transfer](#section5)

  - [References](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require pop3d ?1\.1\.0?  

[__::pop3d::new__ ?*serverName*?](#1)  
[__serverName__ *option* ?*arg arg \.\.\.*?](#2)  
[*serverName* __up__](#3)  
[*serverName* __down__](#4)  
[*serverName* __destroy__ ?*mode*?](#5)  
[*serverName* __configure__](#6)  
[*serverName* __configure__ *\-option*](#7)  
[*serverName* __configure__ *\-option value*\.\.\.](#8)  
[*serverName* __cget__ *\-option*](#9)  
[*serverName* __conn__ list](#10)  
[*serverName* __conn__ state *id*](#11)  
[*authCmd* __exists__ *name*](#12)  
[*authCmd* __lookup__ *name*](#13)  
[*storageCmd* __dele__ *mbox* *msgList*](#14)  
[*storageCmd* __lock__ *mbox*](#15)  
[*storageCmd* __unlock__ *mbox*](#16)  
[*storageCmd* __size__ *mbox* ?*msgId*?](#17)  
[*storageCmd* __stat__ *mbox*](#18)  
[*storageCmd* __get__ *mbox* *msgId*](#19)  

# <a name='description'></a>DESCRIPTION

  - <a name='1'></a>__::pop3d::new__ ?*serverName*?

    This command creates a new server object with an associated global Tcl
    command whose name is *serverName*\.

The command __serverName__ may be used to invoke various operations on the
server\. It has the following general form:

  - <a name='2'></a>__serverName__ *option* ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

A pop3 server can be started on any port the caller has permission for from the
operating system\. The default port will be 110, which is the port defined by the
standard specified in RFC 1939
\([http://www\.rfc\-editor\.org/rfc/rfc1939\.txt](http://www\.rfc\-editor\.org/rfc/rfc1939\.txt)\)\.
After creating, configuring and starting a the server object will listen for and
accept connections on that port and handle them according to the POP3 protocol\.

*Note:* The server provided by this module will handle only the basic protocol
by itself\. For the higher levels of user authentication and handling of the
actual mailbox contents callbacks will be invoked\.

The following commands are possible for server objects:

  - <a name='3'></a>*serverName* __up__

    After this call the server will listen for connections on its configured
    port\.

  - <a name='4'></a>*serverName* __down__

    After this call the server will stop listening for connections\. This does
    not affect existing connections\.

  - <a name='5'></a>*serverName* __destroy__ ?*mode*?

    Destroys the server object\. Currently open connections are handled depending
    on the chosen mode\. The provided *mode*s are:

      * __kill__

        Destroys the server immediately, and forcefully closes all currently
        open connections\. This is the default mode\.

      * __defer__

        Stops the server from accepting new connections and will actually
        destroy it only after the last of the currently open connections for the
        server is closed\.

  - <a name='6'></a>*serverName* __configure__

    Returns a list containing all options and their current values in a format
    suitable for use by the command __array set__\. The options themselves
    are described in section [Options](#section2)\.

  - <a name='7'></a>*serverName* __configure__ *\-option*

    Returns the current value of the specified option\. This is an alias for the
    method __cget__\. The options themselves are described in section
    [Options](#section2)\.

  - <a name='8'></a>*serverName* __configure__ *\-option value*\.\.\.

    Sets the specified option to the provided value\. The options themselves are
    described in section [Options](#section2)\.

  - <a name='9'></a>*serverName* __cget__ *\-option*

    Returns the current value of the specified option\. The options themselves
    are described in section [Options](#section2)\.

  - <a name='10'></a>*serverName* __conn__ list

    Returns a list containing the ids of all connections currently open\.

  - <a name='11'></a>*serverName* __conn__ state *id*

    Returns a list suitable for \[__array set__\] containing the state of the
    connection referenced by *id*\.

# <a name='section2'></a>Options

The following options are available to pop3 server objects\.

  - __\-port__ *port*

    Defines the *port* to listen on for new connections\. Default is 110\. This
    option is a bit special\. If *port* is set to "0" the server, or rather the
    operating system, will select a free port on its own\. When querying
    __\-port__ the id of this chosen port will be returned\. Changing the port
    while the server is up will neither change the returned value, nor will it
    change on which port the server is listening on\. Only after resetting the
    server via a call to __down__ followed by a call to __up__ will the
    new port take effect\. It is at that time that the value returned when
    querying __\-port__ will change too\.

  - __\-auth__ *command*

    Defines a *command* prefix to call whenever the authentication of a user
    is required\. If no such command is specified the server will reject all
    users\. The interface which has to be provided by the command prefix is
    described in section [Authentication](#section3)\.

  - __\-storage__ *command*

    Defines a *command* prefix to call whenever the handling of mailbox
    contents is required\. If no such command is specified the server will claim
    that all mailboxes are empty\. The interface which has to be provided by the
    command prefix is described in section [Mailboxes](#section4)\.

  - __\-socket__ *command*

    Defines a *command* prefix to call for opening the listening socket\. This
    can be used to make the pop3 server listen on a SSL socket as provided by
    the __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__ package, see the command
    __tls::socket__\.

# <a name='section3'></a>Authentication

Here we describe the interface which has to be provided by the authentication
callback so that pop3 servers following the interface of this module are able to
use it\.

  - <a name='12'></a>*authCmd* __exists__ *name*

    This method is given a user*name* and has to return a boolean value
    telling whether or not the specified user exists\.

  - <a name='13'></a>*authCmd* __lookup__ *name*

    This method is given a user*name* and has to return a two\-element list
    containing the password for this user and a storage reference, in this
    order\.

    The storage reference is passed unchanged to the storage callback, see
    sections [Options](#section2) and [Mailboxes](#section4) for
    either the option defining it and or the interface to provide, respectively\.

# <a name='section4'></a>Mailboxes

Here we describe the interface which has to be provided by the storage callback
so that pop3 servers following the interface of this module are able to use it\.
The *mbox* argument is the storage reference as returned by the __lookup__
method of the authentication command, see section
[Authentication](#section3)\.

  - <a name='14'></a>*storageCmd* __dele__ *mbox* *msgList*

    Deletes the messages whose numeric ids are contained in the *msgList* from
    the mailbox specified via *mbox*\.

  - <a name='15'></a>*storageCmd* __lock__ *mbox*

    This method locks the specified mailbox for use by a single connection to
    the server\. This is necessary to prevent havoc if several connections to the
    same mailbox are open\. The complementary method is __unlock__\. The
    command will return true if the lock could be set successfully or false if
    not\.

  - <a name='16'></a>*storageCmd* __unlock__ *mbox*

    This is the complementary method to __lock__, it revokes the lock on the
    specified mailbox\.

  - <a name='17'></a>*storageCmd* __size__ *mbox* ?*msgId*?

    Determines the size of the message specified through its id in *msgId*, in
    bytes, and returns this number\. The command will return the size of the
    whole maildrop if no message id was specified\.

  - <a name='18'></a>*storageCmd* __stat__ *mbox*

    Determines the number of messages in the specified mailbox and returns this
    number\.

  - <a name='19'></a>*storageCmd* __get__ *mbox* *msgId*

    Returns a handle for the specified message\. This handle is a mime token
    following the interface described in the documentation of package
    __[mime](\.\./mime/mime\.md)__\. The pop3 server will use the
    functionality of the mime token to send the mail to the requestor at the
    other end of a pop3 connection\.

# <a name='section5'></a>Secure mail transfer

The option __\-socket__ \(see [Options](#section2)\) enables users of the
package to override how the server opens its listening socket\. The envisioned
main use is the specification of the __tls::socket__ command, see package
__[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__, to secure the communication\.

    package require tls
    tls::init \
    	...

    pop3d::new S -socket tls::socket
    ...

# <a name='section6'></a>References

  1. [RFC 1939](http://www\.rfc\-editor\.org/rfc/rfc1939\.txt)

  1. [RFC 2449](http://www\.rfc\-editor\.org/rfc/rfc2449\.txt)

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pop3d* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[network](\.\./\.\./\.\./\.\./index\.md\#network),
[pop3](\.\./\.\./\.\./\.\./index\.md\#pop3),
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol), [rfc
1939](\.\./\.\./\.\./\.\./index\.md\#rfc\_1939),
[secure](\.\./\.\./\.\./\.\./index\.md\#secure), [ssl](\.\./\.\./\.\./\.\./index\.md\#ssl),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2005 Reinhard Max  <max@suse\.de>
