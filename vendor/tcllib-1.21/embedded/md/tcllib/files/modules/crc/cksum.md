
[//000000001]: # (cksum \- Cyclic Redundancy Checks)
[//000000002]: # (Generated from file 'cksum\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts)
[//000000004]: # (cksum\(n\) 1\.1\.4 tcllib "Cyclic Redundancy Checks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

cksum \- Calculate a cksum\(1\) compatible checksum

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
package require cksum ?1\.1\.4?  

[__::crc::cksum__ ?*\-format format*? ?*\-chunksize size*? \[ *\-channel chan* &#124; *\-filename file* &#124; *string* \]](#1)  
[__::crc::CksumInit__](#2)  
[__::crc::CksumUpdate__ *token* *data*](#3)  
[__::crc::CksumFinal__ *token*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl implementation of the cksum\(1\) algorithm based upon
information provided at in the GNU implementation of this program as part of the
GNU Textutils 2\.0 package\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::crc::cksum__ ?*\-format format*? ?*\-chunksize size*? \[ *\-channel chan* &#124; *\-filename file* &#124; *string* \]

    The command takes string data or a channel or file name and returns a
    checksum value calculated using the __cksum\(1\)__ algorithm\. The result
    is formatted using the *format*\(n\) specifier provided or as an unsigned
    integer \(%u\) by default\.

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

# <a name='section4'></a>PROGRAMMING INTERFACE

The cksum package implements the checksum using a context variable to which
additional data can be added at any time\. This is expecially useful in an event
based environment such as a Tk application or a web server package\. Data to be
checksummed may be handled incrementally during a __fileevent__ handler in
discrete chunks\. This can improve the interactive nature of a GUI application
and can help to avoid excessive memory consumption\.

  - <a name='2'></a>__::crc::CksumInit__

    Begins a new cksum context\. Returns a token ID that must be used for the
    remaining functions\. An optional seed may be specified if required\.

  - <a name='3'></a>__::crc::CksumUpdate__ *token* *data*

    Add data to the checksum identified by token\. Calling *CksumUpdate $token
    "abcd"* is equivalent to calling *CksumUpdate $token "ab"* followed by
    *CksumUpdate $token "cb"*\. See [EXAMPLES](#section5)\.

  - <a name='4'></a>__::crc::CksumFinal__ *token*

    Returns the checksum value and releases any resources held by this token\.
    Once this command completes the token will be invalid\. The result is a 32
    bit integer value\.

# <a name='section5'></a>EXAMPLES

    % crc::cksum "Hello, World!"
    2609532967

    % crc::cksum -format 0x%X "Hello, World!"
    0x9B8A5027

    % crc::cksum -file cksum.tcl
    1828321145

    % set tok [crc::CksumInit]
    % crc::CksumUpdate $tok "Hello, "
    % crc::CksumUpdate $tok "World!"
    % crc::CksumFinal $tok
    2609532967

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

[crc32\(n\)](crc32\.md), [sum\(n\)](sum\.md)

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
