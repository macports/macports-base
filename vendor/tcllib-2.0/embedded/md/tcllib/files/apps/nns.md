
[//000000001]: # (nns \- Name service facility)
[//000000002]: # (Generated from file 'nns\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nns\(n\) 1\.1 tcllib "Name service facility")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

nns \- Name service facility, Commandline Client Application

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [USE CASES](#subsection1)

      - [COMMAND LINE](#subsection2)

      - [OPTIONS](#subsection3)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__nns__ __bind__ ?__\-host__ *host*? ?__\-port__ *port*? *name* *data*](#1)  
[__nns__ __search__ ?__\-host__ *host*? ?__\-port__ *port*? ?__\-continuous__? ?*pattern*?](#2)  
[__nns__ __ident__ ?__\-host__ *host*? ?__\-port__ *port*?](#3)  
[__nns__ __who__](#4)  

# <a name='description'></a>DESCRIPTION

Please read *[Name service facility,
introduction](\.\./modules/nns/nns\_intro\.md)* first\.

The application described by this document, __nns__, is a simple command
line client for the nano name service facility provided by the Tcllib packages
__[nameserv](\.\./modules/nns/nns\_client\.md)__, and
__[nameserv::server](\.\./modules/nns/nns\_server\.md)__\. Beyond that the
application's sources also serve as an example of how to use the client package
__[nameserv](\.\./modules/nns/nns\_client\.md)__\. All abilities of a client
are covered, from configuration to registration of names to searching\.

This name service facility has nothing to do with the Internet's *Domain Name
System*, otherwise known as *[DNS](\.\./\.\./\.\./index\.md\#dns)*\. If the reader
is looking for a package dealing with that please see either of the packages
__[dns](\.\./modules/dns/tcllib\_dns\.md)__ and __resolv__, both found
in Tcllib too\.

## <a name='subsection1'></a>USE CASES

__nns__ was written with the following two main use cases in mind\.

  1. Registration of a name/data pair in the name service\.

  1. Searching the name service for entries matching a glob pattern\.

Beyond the above we also want to be able to identify the client, and get
information about the name service\.

## <a name='subsection2'></a>COMMAND LINE

  - <a name='1'></a>__nns__ __bind__ ?__\-host__ *host*? ?__\-port__ *port*? *name* *data*

    This form registers the *name*/*data* pair in the specified name
    service\. In this form the command will *not* exit to keep the registration
    alive\. The user has to kill it explicitly, either by sending a signal, or
    through the job\-control facilities of the shell in use\. It will especially
    survive the loss of the connection to the name service and reestablish the
    *name*/*data* pair when the connection is restored\.

    The options to specify the name service will be explained later, in section
    [OPTIONS](#subsection3)\.

  - <a name='2'></a>__nns__ __search__ ?__\-host__ *host*? ?__\-port__ *port*? ?__\-continuous__? ?*pattern*?

    This form searches the specified name service for entries matching the
    glob\-*pattern* and prints them to stdout, with each entry on its own line\.
    If no pattern is specified it defaults to __\*__, matching everything\.

    The options to specify the name service will be explained later, in section
    [OPTIONS](#subsection3)\.

    If the option __\-continuous__ is specified the client will not exit
    after performing the search, but start to continuously monitor the service
    for changes to the set of matching entries, appropriately updating the
    display as changes arrive\. In that form it will especially also survive the
    loss of the connection to the name service and reestablish the search when
    the connection is restored\.

  - <a name='3'></a>__nns__ __ident__ ?__\-host__ *host*? ?__\-port__ *port*?

    This form asks the specified name service for the version and features of
    the name service protocol it supports and prints the results to stdout\.

    The options to specify the name service will be explained later, in section
    [OPTIONS](#subsection3)\.

  - <a name='4'></a>__nns__ __who__

    This form prints name, version, and protocol version of the application to
    stdout\.

## <a name='subsection3'></a>OPTIONS

This section describes all the options available to the user of the application

  - __\-host__ name&#124;ipaddress

    If this option is not specified it defaults to __localhost__\. It
    specifies the name or ip\-address of the host the name service to talk to is
    running on\.

  - __\-port__ number

    If this option is not specified it defaults to __38573__\. It specifies
    the TCP port the name service to talk to is listening on for requests\.

# <a name='section2'></a>Bugs, Ideas, Feedback

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

[nameserv\(n\)](\.\./modules/nns/nns\_client\.md),
[nameserv::common\(n\)](\.\./modules/nns/nns\_common\.md)

# <a name='keywords'></a>KEYWORDS

[application](\.\./\.\./\.\./index\.md\#application),
[client](\.\./\.\./\.\./index\.md\#client), [name
service](\.\./\.\./\.\./index\.md\#name\_service)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
