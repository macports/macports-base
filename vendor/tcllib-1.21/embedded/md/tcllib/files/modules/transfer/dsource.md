
[//000000001]: # (transfer::data::source \- Data transfer facilities)
[//000000002]: # (Generated from file 'dsource\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::data::source\(n\) 0\.2 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::data::source \- Data source

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Package commands](#subsection1)

      - [Object command](#subsection2)

      - [Object methods](#subsection3)

      - [Options](#subsection4)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit ?1\.0?  
package require transfer::copy ?0\.2?  
package require transfer::data::source ?0\.2?  

[__transfer::data::source__ *objectName* ?*options*\.\.\.?](#1)  
[*objectName* __method__ ?*arg arg \.\.\.*?](#2)  
[*objectName* __destroy__](#3)  
[*objectName* __type__](#4)  
[*objectName* __data__](#5)  
[*objectName* __size__](#6)  
[*objectName* __valid__ *msgvar*](#7)  
[*objectName* __transmit__ *channel* *blocksize* *done*](#8)  

# <a name='description'></a>DESCRIPTION

This package provides objects mainly describing the origin of some data to
transfer\. They are also able to initiate transfers of the described information
to a channel using the foundation package
__[transfer::copy](copyops\.md)__\.

# <a name='section2'></a>API

## <a name='subsection1'></a>Package commands

  - <a name='1'></a>__transfer::data::source__ *objectName* ?*options*\.\.\.?

    This command creates a new data source object with an associated Tcl command
    whose name is *objectName*\. This
    *[object](\.\./\.\./\.\./\.\./index\.md\#object)* command is explained in full
    detail in the sections [Object command](#subsection2) and [Object
    methods](#subsection3)\. The set of supported *options* is explained in
    section [Options](#subsection4)\.

    The object command will be created under the current namespace if the
    *objectName* is not fully qualified, and in the specified namespace
    otherwise\. The fully qualified name of the object command is returned as the
    result of the command\.

## <a name='subsection2'></a>Object command

All objects created by the __::transfer::data::source__ command have the
following general form:

  - <a name='2'></a>*objectName* __method__ ?*arg arg \.\.\.*?

    The method __method__ and its *arg*'uments determine the exact
    behavior of the command\. See section [Object methods](#subsection3) for
    the detailed specifications\.

## <a name='subsection3'></a>Object methods

  - <a name='3'></a>*objectName* __destroy__

    This method destroys the object\. Doing so while a transfer initiated by the
    object is active is safe as all data required for the transfer itself was
    copied, and the completion of the transfer will not try to access the
    initiating object anymore\. i\.e\. the transfer is completely separate from the
    source object itself\.

  - <a name='4'></a>*objectName* __type__

    This method returns a string describing the type of the data the object is
    refering to\. The possible values and their meanings are:

      * __undefined__

        No data was specified at all, or it was specified incompletely\. The
        object does not know the type\.

      * __string__

        The data to transfer is contained in a string\.

      * __channel__

        The data to transfer is contained in a channel\.

  - <a name='5'></a>*objectName* __data__

    This method returns a value depending on the type of the data the object
    refers to, through which the data can be accessed\. The method throws an
    error if the type is __undefined__\. For type __string__ the returned
    result is the data itself, whereas for type __channel__ the returned
    result is the handle of the channel containing the data\.

  - <a name='6'></a>*objectName* __size__

    This method returns a value depending on the type of the data the object
    refers to, the size of the data\. The method throws an error if the type is
    __undefined__\. Return of a negative value signals that the object is
    unable to determine an absolute size upfront \(like for data in a channel\)\.

  - <a name='7'></a>*objectName* __valid__ *msgvar*

    This method checks the configuration of the object for validity\. It returns
    a boolean flag as result, whose value is __True__ if the object is
    valid, and __False__ otherwise\. In the latter case the variable whose
    name is stored in *msgvar* is set to an error message describing the
    problem found with the configuration\. Otherwise this variable is not
    touched\.

  - <a name='8'></a>*objectName* __transmit__ *channel* *blocksize* *done*

    This method initiates a transfer of the referenced data to the specified
    *channel*\. When the transfer completes the command prefix *done* is
    invoked, per the rules for the option __\-command__ of command
    __transfer::copy::do__ in the package
    __[transfer::copy](copyops\.md)__\. The *blocksize* specifies the
    size of the chunks to transfer in one go\. See the option __\-blocksize__
    of command __transfer::copy::do__ in the package
    __[transfer::copy](copyops\.md)__\.

## <a name='subsection4'></a>Options

All data sources support the options listed below\. It should be noted that the
first four options are semi\-exclusive, each specifying a different type of data
source and associated content\. If these options are specified more than once
then the last option specified is used to actually configure the object\.

  - __\-string__ *text*

    This option specifies that the source of the data is an immediate string,
    and its associated argument contains the string in question\.

  - __\-channel__ *handle*

    This option specifies that the source of the data is a channel, and its
    associated argument is the handle of the channel containing the data\.

  - __\-file__ *path*

    This option specifies that the source of the data is a file, and its
    associated argument is the path of the file containing the data\.

  - __\-variable__ *varname*

    This option specifies that the source of the data is a string stored in a
    variable, and its associated argument contains the name of the variable in
    question\. The variable is assumed to be global or namespaced, anchored at
    the global namespace\.

  - __\-size__ *int*

    This option specifies the size of the data transfer\. It is optional and
    defaults to \-1\. This value, and any other value less than zero signals to
    transfer all the data from the source\.

  - __\-progress__ *command*

    This option, if specified, defines a command to be invoked for each chunk of
    bytes transmitted, allowing the user to monitor the progress of the
    transmission of the data\. The callback is always invoked with one additional
    argument, the number of bytes transmitted so far\.

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
source](\.\./\.\./\.\./\.\./index\.md\#data\_source),
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
