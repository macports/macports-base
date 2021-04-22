
[//000000001]: # (nameserv::auto \- Name service facility)
[//000000002]: # (Generated from file 'nns\_auto\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nameserv::auto\(n\) 0\.3 tcllib "Name service facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nameserv::auto \- Name service facility, Client Extension

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [OPTIONS](#section3)

  - [EVENTS](#section4)

  - [DESIGN](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require nameserv::auto ?0\.3?  
package require nameserv  

# <a name='description'></a>DESCRIPTION

Please read the document *[Name service facility,
introduction](nns\_intro\.md)* first\.

This package provides the *exact* same API as is provided by package
__[nameserv](nns\_client\.md)__, i\.e\. the regular name service client\. It
differs from the former by taking measures to ensure that longer\-lived data,
i\.e\. bound names, continuous and unfullfilled async searches, survive the loss
of the connection to the name server as much as is possible\.

This means that the bound names and continuous and unfullfilled async searches
are remembered client\-side and automatically re\-entered into the server when the
connection comes back after its loss\. For bound names there is one important
limitation to such restoration: It is possible that a name of this client was
bound by a different client while the connection was gone\. Such names are fully
lost, and the best the package can and will do is to inform the user of this\.

# <a name='section2'></a>API

The user\-visible API is mainly identical to the API of
__[nameserv](nns\_client\.md)__ and is therefore not described here\.
Please read the documentation of __[nameserv](nns\_client\.md)__\.

The differences are explained below, in the sections [OPTIONS](#section3)
and [EVENTS](#section4)\.

# <a name='section3'></a>OPTIONS

This package supports all the options of package
__[nameserv](nns\_client\.md)__, plus one more\. The additional option
allows the user to specify the time interval between attempts to restore a lost
connection\.

  - __\-delay__ *milliseconds*

    The value of this option is an integer value > 0 which specifies the
    interval to wait between attempts to restore a lost connection, in
    milliseconds\. The default value is __1000__, i\.e\. one second\.

# <a name='section4'></a>EVENTS

This package generates all of the events of package
__[nameserv](nns\_client\.md)__, plus two more\. Both events are generated
for the tag *[nameserv](nns\_client\.md)*\.

  - *lost\-name*

    This event is generated when a bound name is truly lost, i\.e\. could not be
    restored after the temporary loss of the connection to the name server\. It
    indicates that a different client took ownership of the name while this
    client was out of contact\.

    The detail information of the event will be a Tcl dictionary containing two
    keys, __name__, and __data__\. Their values hold all the information
    about the lost name\.

  - *re\-connection*

    This event is generated when the connection to the server is restored\. The
    remembered data has been restored when the event is posted\.

    The event has no detail information\.

# <a name='section5'></a>DESIGN

The package is implemented on top of the regular nameservice client, i\.e\.
package __[nameserv](nns\_client\.md)__\. It detects the loss of the
connection by listening for *lost\-connection* events, on the tag
*[nameserv](nns\_client\.md)*\.

It reacts to such events by starting a periodic timer and trying to reconnect to
the server whenver this timer triggers\. On success the timer is canceled, a
*re\-connection* event generated, and the package proceeds to re\-enter the
remembered bound names and continuous searches\.

Another loss of the connection, be it during or after re\-entering the remembered
information simply restarts the timer and subsequent reconnection attempts\.

# <a name='section6'></a>Bugs, Ideas, Feedback

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

[nameserv\(n\)](nns\_client\.md)

# <a name='keywords'></a>KEYWORDS

[automatic](\.\./\.\./\.\./\.\./index\.md\#automatic),
[client](\.\./\.\./\.\./\.\./index\.md\#client), [name
service](\.\./\.\./\.\./\.\./index\.md\#name\_service),
[reconnect](\.\./\.\./\.\./\.\./index\.md\#reconnect),
[restore](\.\./\.\./\.\./\.\./index\.md\#restore)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
