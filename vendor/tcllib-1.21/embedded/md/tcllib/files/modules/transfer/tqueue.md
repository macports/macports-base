
[//000000001]: # (transfer::copy::queue \- Data transfer facilities)
[//000000002]: # (Generated from file 'tqueue\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::copy::queue\(n\) 0\.1 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::copy::queue \- Queued transfers

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

  - [Options](#section3)

  - [Use](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit ?1\.0?  
package require struct::queue ?1\.4?  
package require transfer::copy ?0\.2?  
package require transfer::copy::queue ?0\.1?  

[__transfer::copy::queue__ *objectName* *outchannel* ?*options*\.\.\.?](#1)  
[*objectName* __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __busy__](#4)  
[*objectName* __pending__](#5)  
[*objectName* __put__ *request*](#6)  

# <a name='description'></a>DESCRIPTION

This package provides objects which serialize transfer requests for a single
channel by means of a fifo queue\. Accumulated requests are executed in order of
entrance, with the first request reaching an idle object starting the execution
in general\. New requests can be added while the object is active and are defered
until all requests entered before them have been completed successfully\.

When a request causes a transfer error execution stops and all requests coming
after it are not served\. Currently this means that their completion callbacks
are never triggered at all\.

*NOTE*: Not triggering the completion callbacks of the unserved requests after
an error stops the queue object is something I am not fully sure that it makes
sense\. It forces the user of the queue to remember the callbacks as well and run
them\. Because otherwise everything in the system which depends on getting a
notification about the status of a request will hang in the air\. I am slowly
convincing myself that it is more sensible to trigger the relevant completion
callbacks with an error message about the queue abort, and 0 bytes transfered\.

All transfer requests are of the form

    {type data options...}

where *type* is in \{__chan__, __string__\}, and *data* specifies the
information to transfer\. For __chan__ the data is the handle of the channel
containing the actual information to transfer, whereas for __string__
*data* contains directly the information to transfer\. The *options* are a
list of them and their values, and are the same as are accepted by the low\-level
copy operations of the package __[transfer::copy](copyops\.md)__\. Note
how just prepending the request with __transfer::copy::do__ and inserting a
channel handle in between *data* and *options* easily transforms it from a
pure data structure into a command whose evaluation will perform the request\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__transfer::copy::queue__ *objectName* *outchannel* ?*options*\.\.\.?

    This command creates a new queue object for the management of the channel
    *outchannel*, with an associated Tcl command whose name is *objectName*\.
    This *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in
    full detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The set of supported *options* is explained in
    section [Options](#section3)\.

    The object command will be created under the current namespace if the
    *objectName* is not fully qualified, and in the specified namespace
    otherwise\. The fully qualified name of the object command is returned as the
    result of the command\.

## <a name='subsection2'></a>Object command

All objects created by the __::transfer::copy::queue__ command have the
following general form:

  - <a name='2'></a>*objectName* __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object\. Doing so while the object is busy will
    cause errors later on, when the currently executed request completes and
    tries to access the now missing data structures of the destroyed object\.

  - <a name='4'></a>*objectName* __busy__

    This method returns a boolean value telling us if the object is currently
    serving a request \(i\.e\. *busy*, value __True__\), or not \(i\.e\.
    *[idle](\.\./\.\./\.\./\.\./index\.md\#idle)*, value __False__\)\.

  - <a name='5'></a>*objectName* __pending__

    This method returns the number of requests currently waiting in the queue
    for their execution\. A request currently served is not counted as waiting\.

  - <a name='6'></a>*objectName* __put__ *request*

    This method enters the transfer *request* into the object's queue of
    waiting requests\. If the object is *[idle](\.\./\.\./\.\./\.\./index\.md\#idle)*
    it will become *busy*, immediately servicing the request\. Otherwise
    servicing the new request will be defered until all preceding requests have
    been served\.

# <a name='section3'></a>Options

The only option known is __\-on\-status\-change__\. It is optional and defaults
to the empty list, disabling the reporting of status changes\. Otherwise its
argument is a command prefix which is invoked whenever the internal status of
the object changed\. The callback is invoked with two additional arguments, the
result of the methods __pending__ and __busy__, in this order\. This
allows any user to easily know, for example, when the object has processed all
outstanding requests\.

# <a name='section4'></a>Use

A possible application of this package and class is within a HTTP 1\.1 server,
managing the results waiting for transfer to the client\.

It should be noted that in this application the system also needs an additional
data structure which keeps track of outstanding results as they may come back in
a different order than the requests from the client, and releases them to the
actual queue in the proper order\.

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
[copy](\.\./\.\./\.\./\.\./index\.md\#copy), [queue](\.\./\.\./\.\./\.\./index\.md\#queue),
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
