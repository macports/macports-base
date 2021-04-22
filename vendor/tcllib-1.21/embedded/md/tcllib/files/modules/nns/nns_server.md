
[//000000001]: # (nameserv::server \- Name service facility)
[//000000002]: # (Generated from file 'nns\_server\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nameserv::server\(n\) 0\.3\.2 tcllib "Name service facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nameserv::server \- Name service facility, Server

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [OPTIONS](#section3)

  - [HISTORY](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require nameserv::server ?0\.3\.2?  
package require comm  
package require interp  
package require logger  

[__::nameserv::server::start__](#1)  
[__::nameserv::server::stop__](#2)  
[__::nameserv::server::active?__](#3)  
[__::nameserv::server::cget__ __\-option__](#4)  
[__::nameserv::server::configure__](#5)  
[__::nameserv::server::configure__ __\-option__](#6)  
[__::nameserv::server::configure__ __\-option__ *value*\.\.\.](#7)  

# <a name='description'></a>DESCRIPTION

Please read *[Name service facility, introduction](nns\_intro\.md)* first\.

This package provides an implementation of the serviver side of the name service
facility queried by the client provided by the package
__[nameserv](nns\_client\.md)__\. All information required by the server
will be held in memory\. There is no persistent state\.

This service is built in top of and for the package
__[comm](\.\./comm/comm\.md)__\. It has nothing to do with the Internet's
Domain Name System\. If the reader is looking for a package dealing with that
please see Tcllib's packages __[dns](\.\./dns/tcllib\_dns\.md)__ and
__resolv__\.

This server supports the *Core* protocol feature, and since version 0\.3 the
*Search/Continuous* feature as well\.

# <a name='section2'></a>API

The package exports five commands, as specified below:

  - <a name='1'></a>__::nameserv::server::start__

    This command starts the server and causes it to listen on the configured
    port\. From now on clients are able to connect and make requests\. The result
    of the command is the empty string\.

    Note that any incoming requests will only be handled if the application the
    server is part of does enter an event loop after this command has been run\.

  - <a name='2'></a>__::nameserv::server::stop__

    Invoking this command stops the server and releases all information it had\.
    Existing connections are shut down, and no new connections will be accepted
    any longer\. The result of the command is the empty string\.

  - <a name='3'></a>__::nameserv::server::active?__

    This command returns a boolean value indicating the state of the server\. The
    result will be __true__ if the server is active, i\.e\. has been started,
    and __false__ otherwise\.

  - <a name='4'></a>__::nameserv::server::cget__ __\-option__

    This command returns the currently configured value for the specified
    __\-option__\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section3)\.

  - <a name='5'></a>__::nameserv::server::configure__

    In this form the command returns a dictionary of all supported options, and
    their current values\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section3)\.

  - <a name='6'></a>__::nameserv::server::configure__ __\-option__

    In this form the command is an alias for "__::nameserv::server::cget__
    __\-option__"\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section3)\.

  - <a name='7'></a>__::nameserv::server::configure__ __\-option__ *value*\.\.\.

    In this form the command is used to configure one or more of the supported
    options\. At least one option has to be specified, and each option is
    followed by its new value\. The list of supported options and their meaning
    can be found in section [OPTIONS](#section3)\.

    This form can be used only if the server is not active, i\.e\. has not been
    started yet, or has been stopped\. While the server is active it cannot be
    reconfigured\.

# <a name='section3'></a>OPTIONS

The options supported by the server are for the specification of the TCP port to
listen on, and whether to accept non\-local connections or not\. They are:

  - __\-localonly__ *bool*

    This option specifies whether to accept only local connections \(\-localonly
    1\) or remote connections as well \(\-localonly 0\)\. The default is to accept
    only local connections\.

  - __\-port__ *number*

    This option specifies the port the name service will listen on after it has
    been started\. It has to be a positive integer number \(> 0\) not greater than
    65536 \(unsigned short\)\. The initial default is the number returned by the
    command __::nameserv::server::common::port__, as provided by the package
    __::nameserv::server::common__\.

# <a name='section4'></a>HISTORY

  - 0\.3

    Extended the server with the ability to perform asynchronous and continuous
    searches\.

  - 0\.2

    Changed name of \-local switch to \-localonly\.

  - 0\.1

    Initial implementation of the server\.

# <a name='section5'></a>Bugs, Ideas, Feedback

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

nameserv::client\(n\), [nameserv::common\(n\)](nns\_common\.md)

# <a name='keywords'></a>KEYWORDS

[name service](\.\./\.\./\.\./\.\./index\.md\#name\_service),
[server](\.\./\.\./\.\./\.\./index\.md\#server)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
