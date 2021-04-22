
[//000000001]: # (transfer::receiver \- Data transfer facilities)
[//000000002]: # (Generated from file 'receiver\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::receiver\(n\) 0\.2 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::receiver \- Data source

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

      - [Options](#subsection4)

  - [Secure connections](#section3)

  - [TLS Security Considerations](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit ?1\.0?  
package require transfer::data::destination ?0\.2?  
package require transfer::connect ?0\.2?  
package require transfer::receiver ?0\.2?  

[__transfer::receiver__ *object* ?*options*\.\.\.?](#1)  
[__transfer::receiver__ __stream channel__ *chan* *host* *port* ?*arg*\.\.\.?](#2)  
[__transfer::receiver__ __stream file__ *path* *host* *port* ?*arg*\.\.\.?](#3)  
[*objectName* __method__ ?*arg arg \.\.\.*?](#4)  
[*objectName* __destroy__](#5)  
[*objectName* __start__](#6)  
[*objectName* __busy__](#7)  

# <a name='description'></a>DESCRIPTION

This package pulls data destinations and connection setup together into a
combined object for the reception of information coming in over a socket\. These
objects understand all the options from objects created by the packages
__[transfer::data::destination](ddest\.md)__ and
__[transfer::connect](connect\.md)__\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__transfer::receiver__ *object* ?*options*\.\.\.?

    This command creates a new receiver object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The set of supported *options* is explained in
    section [Options](#subsection4)\.

    The object command will be created under the current namespace if the
    *objectName* is not fully qualified, and in the specified namespace
    otherwise\. The fully qualified name of the object command is returned as the
    result of the command\.

  - <a name='2'></a>__transfer::receiver__ __stream channel__ *chan* *host* *port* ?*arg*\.\.\.?

    This method creates a fire\-and\-forget transfer for the data coming from the
    source at host/port \(details below\) and writing to the channel *chan*,
    starting at the current seek location\. The channel is configured to use
    binary translation and encoding for the transfer\. The channel is *not*
    closed when the transfer has completed\. This is left to the completion
    callback\.

    If both *host* and *port* are provided an __active__ connection to
    the data source is made\. If only a *port* is specified \(with *host* the
    empty string\) then a __passive__ connection is made instead, i\.e\. the
    receiver then waits for a conneciton by the transmitter\.

    Any arguments after the port are treated as options and are used to
    configure the internal receiver object\. See the section
    [Options](#subsection4) for a list of the supported options and their
    meaning\. *Note* however that the signature of the command prefix specified
    for the __\-command__ callback differs from the signature for the same
    option of the receiver object\. This callback is only given the number of
    bytes and transfered, and possibly an error message\. No reference to the
    internally used receiver object is made\.

    The result returned by the command is the empty string if it was set to make
    an *[active](\.\./\.\./\.\./\.\./index\.md\#active)* connection, and the port
    the internal receiver object is listening on otherwise, i\.e when it is
    configured to connect *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)*ly\. See
    also the package __[transfer::connect](connect\.md)__ and the
    description of the method __connect__ for where this behaviour comes
    from\.

  - <a name='3'></a>__transfer::receiver__ __stream file__ *path* *host* *port* ?*arg*\.\.\.?

    This method is like __stream channel__, except that the received data is
    written to the file *path*, replacing any prior content\.

## <a name='subsection2'></a>Object command

All objects created by the __::transfer::receiver__ command have the
following general form:

  - <a name='4'></a>*objectName* __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='5'></a>*objectName* __destroy__

    This method destroys the object\. Doing so while a reception is on progress
    will cause errors later on, when the reception completes and tries to access
    the now missing data structures of the destroyed object\.

  - <a name='6'></a>*objectName* __start__

    This method initiates the data reception, setting up the connection first
    and then copying the received information into the destination\. The method
    will throw an error if a reception is already/still in progress\. I\.e\. it is
    not possible to run two receptions in parallel, only in sequence\. Errors
    will also be thrown if the configuration of the data destination is invalid,
    or if no completion callback was specified\.

    The result returned by the method is the empty string for an object
    configured to make an *[active](\.\./\.\./\.\./\.\./index\.md\#active)*
    connection, and the port the object is listening on otherwise, i\.e when it
    is configured to connect *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)*ly\.
    See also the package __[transfer::connect](connect\.md)__ and the
    description of the method __connect__ for where this behaviour comes
    from\.

  - <a name='7'></a>*objectName* __busy__

    This method returns a boolean value telling us whether a reception is in
    progress \(__True__\), or not \(__False__\)\.

## <a name='subsection4'></a>Options

All receiver objects support the union of the options supported by their connect
and data destination components, plus one of their own\. See also the
documentation for the packages
__[transfer::data::destination](ddest\.md)__ and
__[transfer::connect](connect\.md)__\.

  - __\-command__ *cmdprefix*

    This option specifies the command to invoke when the reception of the
    information has been completed\. The arguments given to this command are the
    same as given to the completion callback of the command
    __transfer::copy::do__ provided by the package
    __[transfer::copy](copyops\.md)__\.

  - __\-mode__ *mode*

    This option specifies the mode the object is in\. It is optional and defaults
    to __active__ mode\. The two possible modes are:

      * __active__

        In this mode the two options __\-host__ and __\-port__ are
        relevant and specify the host and TCP port the object has to connect to\.
        The host is given by either name or IP address\.

      * __passive__

        In this mode the option __\-host__ has no relevance and is ignored
        should it be configured\. The only option the object needs is
        __\-port__, and it specifies the TCP port on which the listening
        socket is opened to await the connection from the partner\.

  - __\-host__ *hostname\-or\-ipaddr*

    This option specifies the host to connect to in
    *[active](\.\./\.\./\.\./\.\./index\.md\#active)* mode, either by name or
    ip\-address\. An object configured for
    *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* mode ignores this option\.

  - __\-port__ *int*

    For *[active](\.\./\.\./\.\./\.\./index\.md\#active)* mode this option specifies
    the port the object is expected to connect to\. For
    *[passive](\.\./\.\./\.\./\.\./index\.md\#passive)* mode however it is the port
    where the object creates the listening socket waiting for a connection\. It
    defaults to __0__, which allows the OS to choose the actual port to
    listen on\.

  - __\-socketcmd__ *command*

    This option allows the user to specify which command to use to open a
    socket\. The default is to use the builtin __::socket__\. Any compatible
    with that command is allowed\.

    The envisioned main use is the specfication of __tls::socket__\. I\.e\.
    this option allows the creation of secure transfer channels, without making
    this package explicitly dependent on the
    __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__ package\.

    See also section [Secure connections](#section3)\.

  - __\-encoding__ encodingname

  - __\-eofchar__ eofspec

  - __\-translation__ transspec

    These options are the same as are recognized by the builtin command
    __fconfigure__\. They provide the configuration to be set for the channel
    between the two partners after it has been established, but before the
    callback is invoked \(See method __connect__\)\.

  - __\-channel__ *handle*

    This option specifies that the destination of the data is a channel, and its
    associated argument is the handle of the channel to write the received data
    to\.

  - __\-file__ *path*

    This option specifies that the destination of the data is a file, and its
    associated argument is the path of the file to write the received data to\.

  - __\-variable__ *varname*

    This option specifies that the destination of the data is a variable, and
    its associated argument contains the name of the variable to write the
    received data to\. The variable is assumed to be global or namespaced,
    anchored at the global namespace\.

  - __\-progress__ *command*

    This option, if specified, defines a command to be invoked for each chunk of
    bytes received, allowing the user to monitor the progress of the reception
    of the data\. The callback is always invoked with one additional argument,
    the number of bytes received so far\.

# <a name='section3'></a>Secure connections

One way to secure connections made by objects of this package is to require the
package __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__ and then configure the
option __\-socketcmd__ to force the use of command __tls::socket__ to
open the socket\.

    # Load and initialize tls
    package require tls
    tls::init -cafile /path/to/ca/cert -keyfile ...

    # Create a connector with secure socket setup,
    transfer::receiver R -socketcmd tls::socket ...
    ...

# <a name='section4'></a>TLS Security Considerations

This package uses the __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package to
handle the security for __https__ urls and other socket connections\.

Policy decisions like the set of protocols to support and what ciphers to use
are not the responsibility of __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__, nor
of this package itself however\. Such decisions are the responsibility of
whichever application is using the package, and are likely influenced by the set
of servers the application will talk to as well\.

For example, in light of the recent [POODLE
attack](http://googleonlinesecurity\.blogspot\.co\.uk/2014/10/this\-poodle\-bites\-exploiting\-ssl\-30\.html)
discovered by Google many servers will disable support for the SSLv3 protocol\.
To handle this change the applications using
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ must be patched, and not this
package, nor __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ itself\. Such a patch
may be as simple as generally activating __tls1__ support, as shown in the
example below\.

    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *transfer* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[channel](\.\./\.\./\.\./\.\./index\.md\#channel),
[copy](\.\./\.\./\.\./\.\./index\.md\#copy), [data
destination](\.\./\.\./\.\./\.\./index\.md\#data\_destination),
[receiver](\.\./\.\./\.\./\.\./index\.md\#receiver),
[secure](\.\./\.\./\.\./\.\./index\.md\#secure), [ssl](\.\./\.\./\.\./\.\./index\.md\#ssl),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls),
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
