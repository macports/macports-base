
[//000000001]: # (crc32 \- Cyclic Redundancy Checks)
[//000000002]: # (Generated from file 'crc32\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts)
[//000000004]: # (crc32\(n\) 1\.3\.3 tcllib "Cyclic Redundancy Checks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

crc32 \- Perform a 32bit Cyclic Redundancy Check

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [OPTIONS](#section3)

  - [PROGRAMMING INTERFACE](#section4)

  - [EXAMPLES](#section5)

  - [AUTHORS](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require crc32 ?1\.3\.3?  

[__::crc::crc32__ ?\-format *format*? ?\-seed *value*? \[ *\-channel chan* &#124; *\-filename file* &#124; *message* \]](#1)  
[__::crc::Crc32Init__ ?*seed*?](#2)  
[__::crc::Crc32Update__ *token* *data*](#3)  
[__::crc::Crc32Final__ *token*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl implementation of the CRC\-32 algorithm based upon
information provided at http://www\.naaccr\.org/standard/crc32/document\.html If
either the __critcl__ package or the __Trf__ package are available then
a compiled version may be used internally to accelerate the checksum
calculation\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::crc::crc32__ ?\-format *format*? ?\-seed *value*? \[ *\-channel chan* &#124; *\-filename file* &#124; *message* \]

    The command takes either string data or a channel or file name and returns a
    checksum value calculated using the CRC\-32 algorithm\. The result is
    formatted using the *format*\(n\) specifier provided\. The default is to
    return the value as an unsigned integer \(format %u\)\.

# <a name='section3'></a>OPTIONS

  - \-channel *name*

    Return a checksum for the data read from a channel\. The command will read
    data from the channel until the __eof__ is true\. If you need to be able
    to process events during this calculation see the [PROGRAMMING
    INTERFACE](#section4) section

  - \-filename *name*

    This is a convenience option that opens the specified file, sets the
    encoding to binary and then acts as if the *\-channel* option had been
    used\. The file is closed on completion\.

  - \-format *string*

    Return the checksum using an alternative format template\.

  - \-seed *value*

    Select an alternative seed value for the CRC calculation\. The default is
    0xffffffff\. This can be useful for calculating the CRC for data structures
    without first converting the whole structure into a string\. The CRC of the
    previous member can be used as the seed for calculating the CRC of the next
    member\. Note that the crc32 algorithm includes a final XOR step\. If
    incremental processing is desired then this must be undone before using the
    output of the algorithm as the seed for further processing\. A simpler
    alternative is to use the [PROGRAMMING INTERFACE](#section4) which is
    intended for this mode of operation\.

# <a name='section4'></a>PROGRAMMING INTERFACE

The CRC\-32 package implements the checksum using a context variable to which
additional data can be added at any time\. This is expecially useful in an event
based environment such as a Tk application or a web server package\. Data to be
checksummed may be handled incrementally during a __fileevent__ handler in
discrete chunks\. This can improve the interactive nature of a GUI application
and can help to avoid excessive memory consumption\.

  - <a name='2'></a>__::crc::Crc32Init__ ?*seed*?

    Begins a new CRC32 context\. Returns a token ID that must be used for the
    remaining functions\. An optional seed may be specified if required\.

  - <a name='3'></a>__::crc::Crc32Update__ *token* *data*

    Add data to the checksum identified by token\. Calling *Crc32Update $token
    "abcd"* is equivalent to calling *Crc32Update $token "ab"* followed by
    *Crc32Update $token "cb"*\. See [EXAMPLES](#section5)\.

  - <a name='4'></a>__::crc::Crc32Final__ *token*

    Returns the checksum value and releases any resources held by this token\.
    Once this command completes the token will be invalid\. The result is a 32
    bit integer value\.

# <a name='section5'></a>EXAMPLES

    % crc::crc32 "Hello, World!"
    3964322768

    % crc::crc32 -format 0x%X "Hello, World!"
    0xEC4AC3D0

    % crc::crc32 -file crc32.tcl
    483919716

    % set tok [crc::Crc32Init]
    % crc::Crc32Update $tok "Hello, "
    % crc::Crc32Update $tok "World!"
    % crc::Crc32Final $tok
    3964322768

# <a name='section6'></a>AUTHORS

Pat Thoyts

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *crc* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[cksum\(n\)](cksum\.md), [crc16\(n\)](crc16\.md), [sum\(n\)](sum\.md)

# <a name='keywords'></a>KEYWORDS

[checksum](\.\./\.\./\.\./\.\./index\.md\#checksum),
[cksum](\.\./\.\./\.\./\.\./index\.md\#cksum), [crc](\.\./\.\./\.\./\.\./index\.md\#crc),
[crc32](\.\./\.\./\.\./\.\./index\.md\#crc32), [cyclic redundancy
check](\.\./\.\./\.\./\.\./index\.md\#cyclic\_redundancy\_check), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts
