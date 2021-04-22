
[//000000001]: # (nmea \- NMEA protocol implementation)
[//000000002]: # (Generated from file 'nmea\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006\-2009, Aaron Faupell <afaupell@users\.sourceforge\.net>)
[//000000004]: # (nmea\(n\) 1\.0\.0 tcllib "NMEA protocol implementation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nmea \- Process NMEA data

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require nmea ?1\.0\.0?  

[__::nmea::input__ *sentence*](#1)  
[__::nmea::open\_port__ *port* ?speed?](#2)  
[__::nmea::close\_port__](#3)  
[__::nmea::configure\_port__ *settings*](#4)  
[__::nmea::open\_file__ *file* ?rate?](#5)  
[__::nmea::close\_file__](#6)  
[__::nmea::do\_line__](#7)  
[__::nmea::rate__](#8)  
[__::nmea::log__ ?file?](#9)  
[__::nmea::checksum__ *data*](#10)  
[__::nmea::write__ *sentence* *data*](#11)  
[__::nmea::event__ *setence* ?command?](#12)  

# <a name='description'></a>DESCRIPTION

This package provides a standard interface for writing software which recieves
NMEA standard input data\. It allows for reading data from COM ports, files, or
programmatic input\. It also supports the checksumming and logging of incoming
data\. After parsing, input is dispatched to user defined handler commands for
processing\. To define a handler, see the
__[event](\.\./\.\./\.\./\.\./index\.md\#event)__ command\. There are no GPS
specific functions in this package\. NMEA data consists of a sentence type,
followed by a list of data\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::nmea::input__ *sentence*

    Processes and dispatches the supplied sentence\. If *sentence* contains no
    commas it is treated as a Tcl list, otherwise it must be standard comma
    delimited NMEA data, with an optional checksum and leading __$__\.

        nmea::input {$GPGSA,A,3,04,05,,09,12,,,24,,,,,2.5,1.3,2.1*39}
        nmea::input [list GPGSA A 3 04 05  09 12 "" "" 24 "" "" ""  2.5 1.3 2.1]

  - <a name='2'></a>__::nmea::open\_port__ *port* ?speed?

    Open the specified COM port and read NMEA sentences when available\. Port
    speed is set to 4800bps by default or to *speed*\.

  - <a name='3'></a>__::nmea::close\_port__

    Close the com port connection if one is open\.

  - <a name='4'></a>__::nmea::configure\_port__ *settings*

    Changes the current port settings\. *settings* has the same format as
    fconfigure \-mode\.

  - <a name='5'></a>__::nmea::open\_file__ *file* ?rate?

    Open file *file* and read NMEA sentences, one per line, at the rate
    specified by ?rate? in milliseconds\. The file format may omit the leading
    __$__ and/or the checksum\. If rate is <= 0 \(the default\) then lines will
    only be processed when a call to __do\_line__ is made\.

  - <a name='6'></a>__::nmea::close\_file__

    Close the open file if one exists\.

  - <a name='7'></a>__::nmea::do\_line__

    If there is a currently open file, this command will read and process a
    single line from it\. Returns the number of lines read\.

  - <a name='8'></a>__::nmea::rate__

    Sets the rate at which lines are processed from the open file, in
    milliseconds\. The rate remains consistant across files, there does not need
    to be a file currently open to use this command\. Set to 0 to disable
    automatic line processing\.

  - <a name='9'></a>__::nmea::log__ ?file?

    Starts or stops input logging\. If a file name is specified then all NMEA
    data recieved on the open port will be logged to the ?file? in append mode\.
    If file is an empty string then any logging will be stopped\. If no file is
    specified then returns a boolean value indicating if logging is currently
    enabled\. Data written to the port by __write__, data read from files, or
    input made using __input__, is not logged\.

  - <a name='10'></a>__::nmea::checksum__ *data*

    Returns the checksum of the supplied data\.

  - <a name='11'></a>__::nmea::write__ *sentence* *data*

    If there is a currently open port, this command will write the specified
    sentence and data to the port in proper NMEA checksummed format\.

  - <a name='12'></a>__::nmea::event__ *setence* ?command?

    Registers a handler proc for a given NMEA *sentence*\. There may be at most
    one handler per sentence, any existing handler is replaced\. If no command is
    specified, returns the name of the current handler for the given *setence*
    or an empty string if none exists\. In addition to the incoming sentences
    there are 2 builtin types, EOF and DEFAULT\. The handler for the DEFAULT
    setence is invoked if there is not a specific handler for that sentence\. The
    EOF handler is invoked when End Of File is reached on the open file or port\.

    The handler procedures, with the exception of the builtin types,must take
    exactly one argument, which is a list of the data values\. The DEFAULT
    handler should have two arguments, the sentence type and the data values\.
    The EOF handler has no arguments\.

        nmea::event gpgsa parse_sat_detail
        nmea::event default handle_unknown

        proc parse_sat_detail {data} {
            puts [lindex $data 1]
        }

        proc handle_unknown {name data} {
            puts "unknown data type $name"
        }

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *nmea* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[gps](\.\./\.\./\.\./\.\./index\.md\#gps), [nmea](\.\./\.\./\.\./\.\./index\.md\#nmea)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006\-2009, Aaron Faupell <afaupell@users\.sourceforge\.net>
