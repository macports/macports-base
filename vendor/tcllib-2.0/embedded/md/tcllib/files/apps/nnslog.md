
[//000000001]: # (nnslog \- Name service facility)
[//000000002]: # (Generated from file 'nnslog\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nnslog\(n\) 1\.0 tcllib "Name service facility")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

nnslog \- Name service facility, Commandline Logging Client Application

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

[__nnslog__ ?__\-host__ *host*? ?__\-port__ *port*?](#1)  

# <a name='description'></a>DESCRIPTION

Please read *[Name service facility,
introduction](\.\./modules/nns/nns\_intro\.md)* first\.

The application described by this document, __nnslog__, is a simple command
line client for the nano name service facility provided by the Tcllib packages
__[nameserv](\.\./modules/nns/nns\_client\.md)__, and
__[nameserv::server](\.\./modules/nns/nns\_server\.md)__\.

It essentially implements "__[nns](nns\.md)__ search \-continuous \*", but
uses a different output formatting\. Instead of continuously showing the current
contents of the server in the terminal it simply logs all received add/remove
events to __stdout__\.

This name service facility has nothing to do with the Internet's *Domain Name
System*, otherwise known as *[DNS](\.\./\.\./\.\./index\.md\#dns)*\. If the reader
is looking for a package dealing with that please see either of the packages
__[dns](\.\./modules/dns/tcllib\_dns\.md)__ and __resolv__, both found
in Tcllib too\.

## <a name='subsection1'></a>USE CASES

__nnslog__ was written with the following main use case in mind\.

  1. Monitoring the name service for all changes and logging them in a text
     terminal\.

## <a name='subsection2'></a>COMMAND LINE

  - <a name='1'></a>__nnslog__ ?__\-host__ *host*? ?__\-port__ *port*?

    The command connects to the specified name service, sets up a search for all
    changes and then prints all received events to stdout, with each events on
    its own line\. The command will not exit until it is explicitly terminated by
    the user\. It will especially survive the loss of the connection to the name
    service and reestablish the search and log when the connection is restored\.

    The options to specify the name service will be explained later, in section
    [OPTIONS](#subsection3)\.

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

Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
