
[//000000001]: # (nns\_intro \- Name service facility)
[//000000002]: # (Generated from file 'nns\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nns\_intro\(n\) 1\.0 tcllib "Name service facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nns\_intro \- Name service facility, introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Applications](#section2)

  - [Packages](#section3)

  - [Internals](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

*[nns](\.\./\.\./apps/nns\.md)* \(short for *nano nameservice*\) is a facility
built for the package __[comm](\.\./comm/comm\.md)__, adding a simple name
service to it\. It is also built on top of __[comm](\.\./comm/comm\.md)__,
using it for the exchange of messages between the client and server parts\.

This name service facility has nothing to do with the Internet's *Domain Name
System*, otherwise known as *[DNS](\.\./\.\./\.\./\.\./index\.md\#dns)*\. If the
reader is looking for a package dealing with that please see either of the
packages __[dns](\.\./dns/tcllib\_dns\.md)__ and __resolv__, both found
in Tcllib too\.

Tcllib provides 2 applications and 4 packages which are working together and
provide access to the facility at different levels\.

# <a name='section2'></a>Applications

The application __[nnsd](\.\./\.\./apps/nnsd\.md)__ provides a simple name
server which can be run by anybody anywhere on their system, as they see fit\. It
is also an example on the use of the server\-side package
__[nameserv::server](nns\_server\.md)__\.

Complementing this server is the __[nns](\.\./\.\./apps/nns\.md)__ client
application\. A possible, but no very sensible use would be to enter name/port
bindings into a server from a shell script\. Not sensible, as shell scripts
normally do not provide a __[comm](\.\./comm/comm\.md)__\-based service\.

The only case for this to make some sense would be in a shell script wrapped
around a Tcl script FOO which is using comm, to register the listening port used
by FOO\. However even there it would much more sensible to extend FOO to use the
nameservice directly\. And in regard on how to that
__[nns](\.\./\.\./apps/nns\.md)__ can be used as both example and template\.
Beyond that it may also be useful to perform nameservice queries from shell
scripts\.

The third application, __[nnslog](\.\./\.\./apps/nnslog\.md)__ is a stripped
down form of the __[nns](\.\./\.\./apps/nns\.md)__ client application\. It is
reduced to perform a continuous search for all changes and logs all received
events to stdout\.

Both clients use the __[nameserv::auto](nns\_auto\.md)__ package to
automatically hande the loss and restoration of the connection to the server\.

# <a name='section3'></a>Packages

The two main packages implementing the service are
__[nameserv](nns\_client\.md)__ and
__[nameserv::server](nns\_server\.md)__, i\.e\. client and server\. The
latter has not much of an API, just enough to start, stop, and configure it\. See
the application __[nnsd](\.\./\.\./apps/nnsd\.md)__ on how to use it\.

The basic client, in package __[nameserv](nns\_client\.md)__, provides the
main API to manipulate and query the service\. An example of its use is the
application __[nns](\.\./\.\./apps/nns\.md)__\.

The second client package, __[nameserv::auto](nns\_auto\.md)__ is API
compatible to the basic client, but provides the additional functionality that
it will automatically restore data like bound names when the connection to the
name service was lost and then reestablished\. I\.e\. it automatically detects the
loss of the server and re\-enters the data when the server comes back\.

The package __[nameserv::common](nns\_common\.md)__ is of no interest to
users\. It is an internal package containing code and definitions common to the
packages __[nameserv](nns\_client\.md)__ and
__[nameserv::server](nns\_server\.md)__\.

All packages use the __[uevent](\.\./uev/uevent\.md)__ package for the
reporting of special circumstances via events, and reserve the uevent\-tag
*[nameserv](nns\_client\.md)* for their exclusive use\. All their events will
be posted to that tag\.

# <a name='section4'></a>Internals

The document *[Name service facility, client/server
protocol](nns\_protocol\.md)* specifies the protocol used by the packages
__[nameserv](nns\_client\.md)__ and
__[nameserv::server](nns\_server\.md)__ to talk to each other\. It is of no
interest to users of either the packages or applications\.

Developers wishing to modify and/or extend or to just understand the internals
of the nameservice facility however are strongly advised to read it\.

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

[nameserv\(n\)](nns\_client\.md), [nameserv::auto\(n\)](nns\_auto\.md),
[nameserv::common\(n\)](nns\_common\.md),
[nameserv::protocol\(n\)](nns\_protocol\.md),
[nameserv::server\(n\)](nns\_server\.md), [nnsd\(n\)](\.\./\.\./apps/nnsd\.md),
nss\(n\)

# <a name='keywords'></a>KEYWORDS

[client](\.\./\.\./\.\./\.\./index\.md\#client), [name
service](\.\./\.\./\.\./\.\./index\.md\#name\_service),
[server](\.\./\.\./\.\./\.\./index\.md\#server)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
