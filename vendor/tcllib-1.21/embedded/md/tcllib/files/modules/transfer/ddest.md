
[//000000001]: # (transfer::data::destination \- Data transfer facilities)
[//000000002]: # (Generated from file 'ddest\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::data::destination\(n\) 0\.2 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::data::destination \- Data destination

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Object command](#subsection1)

      - [Object methods](#subsection2)

      - [Options](#subsection3)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit ?1\.0?  
package require transfer::data::destination ?0\.2?  

[__transfer::data::destination__ *objectName* ?*options*\.\.\.?](#1)  
[*objectName* __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __put__ *chunk*](#4)  
[*objectName* __done__](#5)  
[*objectName* __valid__ *msgvar*](#6)  
[*objectName* __receive__ *channel* *done*](#7)  

# <a name='description'></a>DESCRIPTION

This package provides objects mainly describing the destination of a data
transfer\. They are also able to initiate the reception of information from a
channel into the described destination\.

# <a name='section2'></a>API

  - <a name='1'></a>__transfer::data::destination__ *objectName* ?*options*\.\.\.?

    This command creates a new data destination object with an associated Tcl
    command whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection1) and [Object
    methods](#subsection2)\. The set of supported *options* is explained in
    section [Options](#subsection3)\.

    The object command will be created under the current namespace if the
    *objectName* is not fully qualified, and in the specified namespace
    otherwise\. The fully qualified name of the object command is returned as the
    result of the command\.

## <a name='subsection1'></a>Object command

All objects created by the __::transfer::data::destination__ command have
the following general form:

  - <a name='2'></a>*objectName* __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection2) for
    the detailed specifications\.

## <a name='subsection2'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object\. Doing so while the object is busy with the
    reception of information from a channel will cause errors later on, when the
    reception completes and tries to access the now missing data structures of
    the destroyed object\.

  - <a name='4'></a>*objectName* __put__ *chunk*

    The main receptor method\. Saves the received *chunk* of data into the
    configured destination\. It has to be called for each piece of data received\.

  - <a name='5'></a>*objectName* __done__

    The secondary receptor method\. Finalizes the receiver\. It has to be called
    when the receiving channel signals EOF\. Afterward neither itself nor method
    __put__ can be called anymore\.

  - <a name='6'></a>*objectName* __valid__ *msgvar*

    This method checks the configuration of the object for validity\. It returns
    a boolean flag as result, whose value is __True__ if the object is
    valid, and __False__ otherwise\. In the latter case the variable whose
    name is stored in *msgvar* is set to an error message describing the
    problem found with the configuration\. Otherwise this variable is not
    touched\.

  - <a name='7'></a>*objectName* __receive__ *channel* *done*

    This method initiates the reception of data from the specified *channel*\.
    The received data will be stored into the configured destination, via calls
    to the methods __put__ and __done__\. When the reception completes
    the command prefix *done* is invoked, with the number of received
    characters appended to it as the sole additional argument\.

## <a name='subsection3'></a>Options

All data destinations support the options listed below\. It should be noted that
all are semi\-exclusive, each specifying a different type of destination and
associated information\. If these options are specified more than once then the
last option specified is used to actually configure the object\.

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

# <a name='section3'></a>Bugs, Ideas, Feedback

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
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
