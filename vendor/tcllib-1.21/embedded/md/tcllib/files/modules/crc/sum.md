
[//000000001]: # (sum \- Cyclic Redundancy Checks)
[//000000002]: # (Generated from file 'sum\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (sum\(n\) 1\.1\.2 tcllib "Cyclic Redundancy Checks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

sum \- Calculate a sum\(1\) compatible checksum

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [OPTIONS](#section3)

  - [EXAMPLES](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require sum ?1\.1\.2?  

[__::crc::sum__ ?*\-bsd* &#124; *\-sysv*? ?*\-format fmt*? ?*\-chunksize size*? \[ *\-filename file* &#124; *\-channel chan* &#124; *string* \]](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl\-only implementation of the sum\(1\) command which
calculates a 16 bit checksum value from the input data\. The BSD sum algorithm is
used by default but the SysV algorithm is also available\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::crc::sum__ ?*\-bsd* &#124; *\-sysv*? ?*\-format fmt*? ?*\-chunksize size*? \[ *\-filename file* &#124; *\-channel chan* &#124; *string* \]

    The command takes string data or a file name or a channel and returns a
    checksum value calculated using the __sum\(1\)__ algorithm\. The result is
    formatted using the *format*\(n\) specifier provided or as an unsigned
    integer \(%u\) by default\.

# <a name='section3'></a>OPTIONS

  - \-sysv

    The SysV algorithm is fairly naive\. The byte values are summed and any
    overflow is discarded\. The lowest 16 bits are returned as the checksum\.
    Input with the same content but different ordering will give the same
    result\.

  - \-bsd

    This algorithm is similar to the SysV version but includes a bit rotation
    step which provides a dependency on the order of the data values\.

  - \-filename *name*

    Return a checksum for the file contents instead of for parameter data\.

  - \-channel *chan*

    Return a checksum for the contents of the specified channel\. The channel
    must be open for reading and should be configured for binary translation\.
    The channel will no be closed on completion\.

  - \-chunksize *size*

    Set the block size used when reading data from either files or channels\.
    This value defaults to 4096\.

  - \-format *string*

    Return the checksum using an alternative format template\.

# <a name='section4'></a>EXAMPLES

    % crc::sum "Hello, World!"
    37287

    % crc::sum -format 0x%X "Hello, World!"
    0x91A7

    % crc::sum -file sum.tcl
    13392

# <a name='section5'></a>AUTHORS

Pat Thoyts

# <a name='section6'></a>Bugs, Ideas, Feedback

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

[cksum\(n\)](cksum\.md), [crc32\(n\)](crc32\.md), sum\(1\)

# <a name='keywords'></a>KEYWORDS

[checksum](\.\./\.\./\.\./\.\./index\.md\#checksum),
[cksum](\.\./\.\./\.\./\.\./index\.md\#cksum), [crc](\.\./\.\./\.\./\.\./index\.md\#crc),
[crc32](\.\./\.\./\.\./\.\./index\.md\#crc32), [cyclic redundancy
check](\.\./\.\./\.\./\.\./index\.md\#cyclic\_redundancy\_check), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[security](\.\./\.\./\.\./\.\./index\.md\#security),
[sum](\.\./\.\./\.\./\.\./index\.md\#sum)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts <patthoyts@users\.sourceforge\.net>
