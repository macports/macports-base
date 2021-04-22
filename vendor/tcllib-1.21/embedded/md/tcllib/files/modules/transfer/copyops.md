
[//000000001]: # (transfer::copy \- Data transfer facilities)
[//000000002]: # (Generated from file 'copyops\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (transfer::copy\(n\) 0\.2 tcllib "Data transfer facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

transfer::copy \- Data transfer foundation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require transfer::copy ?0\.2?  

[__transfer::copy::do__ __chan__&#124;__string__ *data* *outchannel* ?*options*\.\.\.?](#1)  
[__transfer::copy::chan__ *channel* *outchannel* ?*options*\.\.\.?](#2)  
[__transfer::copy::string__ *string* *outchannel* ?*options*\.\.\.?](#3)  
[__transfer::copy::doChan__ *channel* *outchannel* *optvar*](#4)  
[__transfer::copy::doString__ *string* *outchannel* *optvar*](#5)  
[__transfer::copy::options__ *outchannel* *optionlist* *optvar*](#6)  

# <a name='description'></a>DESCRIPTION

This package provides a number of commands for the asynchronous of information
contained in either a string or channel\. The main point of this package is that
the commands here provide a nicer callback API than the builtin command
__fcopy__, making the use of these facilities simpler than the builtin\.

# <a name='section2'></a>API

  - <a name='1'></a>__transfer::copy::do__ __chan__&#124;__string__ *data* *outchannel* ?*options*\.\.\.?

    This command transfers the information in *data* to the *outchannel*,
    according to the *options*\. The type of the information in *data* is
    determined by the first argument\.

    The options available to this command are the same as are available to the
    command __transfer::copy::options__, and explained there\.

      * __chan__

        The argument *data* contains the handle of a channel and the actual
        infomration to transfer is read from that channel\.

      * __string__

        The argument *data* contains a string and this is the information to
        be transfered\.

  - <a name='2'></a>__transfer::copy::chan__ *channel* *outchannel* ?*options*\.\.\.?

    This command is a shorter and more direct form for the command
    __transfer::copy::do chan__\.

  - <a name='3'></a>__transfer::copy::string__ *string* *outchannel* ?*options*\.\.\.?

    This command is a shorter and more direct form for the command
    __transfer::copy::do string__\.

  - <a name='4'></a>__transfer::copy::doChan__ *channel* *outchannel* *optvar*

    This command is an alternate form of __transfer::copy::chan__ which
    reads its options out of the array variable named by *optvar* instead of
    from a variable length argument list\.

  - <a name='5'></a>__transfer::copy::doString__ *string* *outchannel* *optvar*

    This command is an alternate form of __transfer::copy::string__ which
    reads its options out of the array variable named by *optvar* instead of
    from a variable length argument list\.

  - <a name='6'></a>__transfer::copy::options__ *outchannel* *optionlist* *optvar*

    This command is the option processor used by all the commands above which
    read their options from a variable length argument list\. It first reads
    default settings from the channel handle *outchannel*, then processes the
    list of options in *optionlist*, at last stores the results in the array
    variable named by *optvar*\. The contents of that variable are in a format
    which is directly understood by all the commands above which read their
    options out of an array variable\.

    The recognized options are:

      * __\-blocksize__ *int*

        This option specifies the size of the chunks to transfer in one
        operation\. It is optional and defaults to the value of
        __\-buffersize__ as configured for the output channel\.

        If specified its value has to be an integer number greater than zero\.

      * __\-command__ *commandprefix*

        This option specifies the completion callback of the operation\. This
        option has to be specified\. An error will be thrown if it is not, or if
        the empty list was specified as argument to it\.

        Its value has to be a command prefix, i\.e\. a list whose first word is
        the command to execute, followed by words containing fixed arguments\.
        When the callback is invoked one or two additional arguments are
        appended to the prefix\. The first argument is the number of bytes which
        were transfered\. The optional second argument is an error message and
        added if and only if an error occured during the the transfer\.

      * __\-progress__ *commandprefix*

        This option specifies the progress callback of the operation\. It is
        optional and defaults to the empty list\. This last possibility signals
        that no feedback was asked for and disabled it\.

        Its value has to be a command prefix, see above, __\-command__ for a
        more detailed explanation\. When the callback is invoked a single
        additional arguments is appended to the prefix\. This argument is the
        number of bytes which were transfered so far\.

      * __\-size__ *int*

        This option specifies the number of bytes to read from the input data
        and transfer\. It is optional and defaults to "Transfer everything"\. Its
        value has to be an integer number and any value less than zero has the
        same meaning, i\.e\. to transfer all available data\. Any other value is
        the amount of bytes to transfer\.

        All transfer commands will throw error an when their user tries to
        transfer more data than is available in the input\. This happens
        immediately, before the transfer is actually started, should the input
        be a string\. Otherwise the, i\.e\. for a channel as input, the error is
        thrown the moment the underflow condition is actually detected\.

      * __\-encoding__ *encodingname*

      * __\-eofchar__ *eofspec*

      * __\-translation__ *transspec*

        These options are the same as are recognized by the builtin command
        __fconfigure__ and provide the settings for the output channel which
        are to be active during the transfer, and only then\. I\.e\. the settings
        of the output channel before the transfer are saved, and restored at the
        end of a transfer, regardless of its success or failure\. None of these
        options are required, and they default to the settings of the output
        channel if not specified\.

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
[copy](\.\./\.\./\.\./\.\./index\.md\#copy),
[transfer](\.\./\.\./\.\./\.\./index\.md\#transfer)

# <a name='category'></a>CATEGORY

Transfer module

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
