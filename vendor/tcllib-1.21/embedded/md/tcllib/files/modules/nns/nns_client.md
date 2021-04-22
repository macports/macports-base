
[//000000001]: # (nameserv \- Name service facility)
[//000000002]: # (Generated from file 'nns\_client\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (nameserv\(n\) 0\.4\.2 tcllib "Name service facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nameserv \- Name service facility, Client

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [CONNECTION HANDLING](#section3)

  - [EVENTS](#section4)

  - [OPTIONS](#section5)

  - [ASYNCHRONOUS AND CONTINUOUS SEARCHES](#section6)

  - [HISTORY](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require nameserv ?0\.4\.2?  
package require comm  
package require logger  

[__::nameserv::bind__ *name* *data*](#1)  
[__::nameserv::release__](#2)  
[__::nameserv::search__ ?__\-async__&#124;__\-continuous__? ?*pattern*?](#3)  
[__::nameserv::protocol__](#4)  
[__::nameserv::server\_protocol__](#5)  
[__::nameserv::server\_features__](#6)  
[__::nameserv::cget__ __\-option__](#7)  
[__::nameserv::configure__](#8)  
[__::nameserv::configure__ __\-option__](#9)  
[__::nameserv::configure__ __\-option__ *value*\.\.\.](#10)  
[__$result__ __destroy__](#11)  
[__$result__ __filled__](#12)  
[__$result__ __get__ *name*](#13)  
[__$result__ __names__](#14)  
[__$result__ __size__](#15)  
[__$result__ __getall__ ?*pattern*?](#16)  

# <a name='description'></a>DESCRIPTION

Please read *[Name service facility, introduction](nns\_intro\.md)* first\.

This package provides a client for the name service facility implemented by the
package __[nameserv::server](nns\_server\.md)__\.

This service is built in top of and for the package
__[comm](\.\./comm/comm\.md)__\. It has nothing to do with the Internet's
Domain Name System\. If the reader is looking for a package dealing with that
please see Tcllib's packages __[dns](\.\./dns/tcllib\_dns\.md)__ and
__resolv__\.

# <a name='section2'></a>API

The package exports eight commands, as specified below:

  - <a name='1'></a>__::nameserv::bind__ *name* *data*

    The caller of this command registers the given *name* as its name in the
    configured name service, and additionally associates a piece of *data*
    with it\. The service does nothing with this information beyond storing it
    and delivering it as part of search results\. The meaning is entirely up to
    the applications using the name service\.

    A generally useful choice would for example be an identifier for a
    communication endpoint managed by the package
    __[comm](\.\./comm/comm\.md)__\. Anybody retrieving the name becomes
    immediately able to talk to this endpoint, i\.e\. the registering application\.

    Of further importance is that a caller can register itself under more than
    one name, and each name can have its own piece of *data*\.

    Note that the name service, and thwerefore this command, will throw an error
    if the chosen name is already registered\.

  - <a name='2'></a>__::nameserv::release__

    Invoking this command releases all names \(and their data\) registered by all
    previous calls to __::nameserv::bind__ of this client\. Note that the
    name service will run this command implicitly when it loses the connection
    to this client\.

  - <a name='3'></a>__::nameserv::search__ ?__\-async__&#124;__\-continuous__? ?*pattern*?

    This command searches the name service for all registered names matching the
    specified glob\-*pattern*\. If not specified the pattern defaults to
    __\*__, matching everything\. The result of the command is a dictionary
    mapping the matching names to the data associated with them at
    *[bind](\.\./\.\./\.\./\.\./index\.md\#bind)*\-time\.

    If either option __\-async__ or __\-continuous__ were specified the
    result of this command changes and becomes the Tcl command of an object
    holding the actual result\. These two options are supported if and only if
    the service the client is connected to supports the protocol feature
    *Search/Continuous*\.

    For __\-async__ the result object is asynchronously filled with the
    entries matching the pattern at the time of the search and then not modified
    any more\. The option __\-continuous__ extends this behaviour by
    additionally continuously monitoring the service for the addition and
    removal of entries which match the pattern, and updating the object's
    contents appropriately\.

    *Note* that the caller is responsible for configuring the object with a
    callback for proper notification when the current result \(or further
    changes\) arrive\.

    For more information about this object see section [ASYNCHRONOUS AND
    CONTINUOUS SEARCHES](#section6)\.

  - <a name='4'></a>__::nameserv::protocol__

    This command returns the highest version of the name service protocol
    supported by the package\.

  - <a name='5'></a>__::nameserv::server\_protocol__

    This command returns the highest version of the name service protocol
    supported by the name service the client is currently connected to\.

  - <a name='6'></a>__::nameserv::server\_features__

    This command returns a list containing the names of the features of the name
    service protocol which are supported by the name service the client is
    currently connected to\.

  - <a name='7'></a>__::nameserv::cget__ __\-option__

    This command returns the currently configured value for the specified
    __\-option__\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section5)\.

  - <a name='8'></a>__::nameserv::configure__

    In this form the command returns a dictionary of all supported options, and
    their current values\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section5)\.

  - <a name='9'></a>__::nameserv::configure__ __\-option__

    In this form the command is an alias for "__::nameserv::cget__
    __\-option__"\. The list of supported options and their meaning can be
    found in section [OPTIONS](#section5)\.

  - <a name='10'></a>__::nameserv::configure__ __\-option__ *value*\.\.\.

    In this form the command is used to configure one or more of the supported
    options\. At least one option has to be specified, and each option is
    followed by its new value\. The list of supported options and their meaning
    can be found in section [OPTIONS](#section5)\.

    This form can be used only as long as the client has not contacted the name
    service yet\. After contact has been made reconfiguration is not possible
    anymore\. This means that this form of the command is for the initalization
    of the client before it use\. The command forcing a contact with the name
    service are

      * __[bind](\.\./\.\./\.\./\.\./index\.md\#bind)__

      * __release__

      * __search__

      * __server\_protocol__

      * __server\_features__

# <a name='section3'></a>CONNECTION HANDLING

The client automatically connects to the service when one of the commands below
is run for the first time, or whenever one of the commands is run after the
connection was lost, when it was lost\.

  - __[bind](\.\./\.\./\.\./\.\./index\.md\#bind)__

  - __release__

  - __search__

  - __server\_protocol__

  - __server\_features__

Since version 0\.2 of the client it will generate an event when the connection is
lost, allowing higher layers to perform additional actions\. This is done via the
support package __[uevent](\.\./uev/uevent\.md)__\. This and all other name
service related packages hereby reserve the uevent\-tag *nameserv*\. All their
events will be posted to that tag\.

# <a name='section4'></a>EVENTS

This package generates only one event, *lost\-connection*\. The detail
information provided to that event is a Tcl dictionary\. The only key contained
in the dictionnary is __reason__, and its value will be a string describing
why the connection was lost\. This string is supplied by the underlying
communication package, i\.e\. __[comm](\.\./comm/comm\.md)__\.

# <a name='section5'></a>OPTIONS

The options supported by the client are for the specification of which name
service to contact, i\.e\. of the location of the name service\. They are:

  - __\-host__ *name*&#124;*ipaddress*

    This option specifies the host name service to contact is running on, either
    by *name*, or by *ipaddress*\. The initial default is __localhost__,
    i\.e\. it is expected to contact a name service running on the same host as
    the application using this package\.

  - __\-port__ *number*

    This option specifies the port the name service to contact is listening on\.
    It has to be a positive integer number \(> 0\) not greater than 65536
    \(unsigned short\)\. The initial default is the number returned by the command
    __::nameserv::common::port__, as provided by the package
    __::nameserv::common__\.

# <a name='section6'></a>ASYNCHRONOUS AND CONTINUOUS SEARCHES

Asynchronous and continuous searches are invoked by using either option
__\-async__ or __\-continuous__ as argument to the command
__::nameserv::search__\.

*Note* that these two options are supported if and only if the service the
client is connected to supports the protocol feature *Search/Continuous*\. The
service provided by the package __::nameserv::server__ does this since
version 0\.3\.

For such searches the result of the search command is the Tcl command of an
object holding the actual result\. The API provided by these objects is:

  - Options:

      * __\-command__ *command\_prefix*

        This option has to be set if a user of the result object wishes to get
        asynchronous notifications when the search result or changes to it
        arrive\.

        *Note* that while it is possible to poll for the arrival of the
        initial search result via the method __filled__, and for subsequent
        changes by comparing the output of method __getall__ against a saved
        copy, this is not the recommended behaviour\. Setting the
        __\-command__ callback and processing the notifications as they
        arrive is much more efficient\.

        The *command\_prefix* is called with two arguments, the type of change,
        and the data of the change\. The type is either __add__ or
        __remove__, indicating new data, or deleted data, respectively\. The
        data of the change is always a dictionary listing the added/removed
        names and their associated data\.

        The first change reported for a search is always the set of matching
        entries at the time of the search\.

  - Methods:

      * <a name='11'></a>__$result__ __destroy__

        Destroys the object and cancels any continuous monitoring of the service
        the object may have had active\.

      * <a name='12'></a>__$result__ __filled__

        The result is a boolean value indicating whether the search result has
        already arrived \(__True__\), or not \(__False__\)\.

      * <a name='13'></a>__$result__ __get__ *name*

        Returns the data associated with the given *name* at
        *[bind](\.\./\.\./\.\./\.\./index\.md\#bind)*\-time\.

      * <a name='14'></a>__$result__ __names__

        Returns a list containing all names known to the object at the time of
        the invokation\.

      * <a name='15'></a>__$result__ __size__

        Returns an integer value specifying the size of the result at the time
        of the invokation\.

      * <a name='16'></a>__$result__ __getall__ ?*pattern*?

        Returns a dictionary containing the search result at the time of the
        invokation, mapping the matching names to the data associated with them
        at *[bind](\.\./\.\./\.\./\.\./index\.md\#bind)*\-time\.

# <a name='section7'></a>HISTORY

  - 0\.3\.1

    Fixed SF Bug 1954771\.

  - 0\.3

    Extended the client with the ability to perform asynchronous and continuous
    searches\.

  - 0\.2

    Extended the client with the ability to generate events when it loses its
    connection to the name service\. Based on package
    __[uevent](\.\./uev/uevent\.md)__\.

  - 0\.1

    Initial implementation of the client\.

# <a name='section8'></a>Bugs, Ideas, Feedback

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

[nameserv::common\(n\)](nns\_common\.md),
[nameserv::server\(n\)](nns\_server\.md)

# <a name='keywords'></a>KEYWORDS

[client](\.\./\.\./\.\./\.\./index\.md\#client), [name
service](\.\./\.\./\.\./\.\./index\.md\#name\_service)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
