
[//000000001]: # (crc16 \- Cyclic Redundancy Checks)
[//000000002]: # (Generated from file 'crc16\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, 2017, Pat Thoyts)
[//000000004]: # (crc16\(n\) 1\.1\.4 tcllib "Cyclic Redundancy Checks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

crc16 \- Perform a 16bit Cyclic Redundancy Check

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
package require crc16 ?1\.1\.4?  

[__::crc::crc16__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*](#1)  
[__::crc::crc16__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*](#2)  
[__::crc::crc\-ccitt__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*](#3)  
[__::crc::crc\-ccitt__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*](#4)  
[__::crc::xmodem__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*](#5)  
[__::crc::xmodem__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*](#6)  

# <a name='description'></a>DESCRIPTION

This package provides a Tcl\-only implementation of the CRC algorithms based upon
information provided at http://www\.microconsultants\.com/tips/crc/crc\.txt There
are a number of permutations available for calculating CRC checksums and this
package can handle all of them\. Defaults are set up for the most common cases\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::crc::crc16__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*

  - <a name='2'></a>__::crc::crc16__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*

  - <a name='3'></a>__::crc::crc\-ccitt__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*

  - <a name='4'></a>__::crc::crc\-ccitt__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*

  - <a name='5'></a>__::crc::xmodem__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? __\-\-__ *message*

  - <a name='6'></a>__::crc::xmodem__ ?\-format *format*? ?\-seed *value*? ?\-implementation *procname*? \-filename *file*

    The command takes either string data or a file name and returns a checksum
    value calculated using the CRC algorithm\. The command used sets up the CRC
    polynomial, initial value and bit ordering for the desired standard checksum
    calculation\. The result is formatted using the *format*\(n\) specifier
    provided or as an unsigned integer \(%u\) by default\.

    A number of common polynomials are in use with the CRC algorithm and the
    most commonly used of these are included in this package\. For convenience
    each of these has a command alias in the crc namespace\.

    It is possible to implement the CRC\-32 checksum using this crc16 package as
    the implementation is sufficiently generic to extend to 32 bit checksums\. As
    an example this has been done already \- however this is not the fastest
    method to implement this algorithm in Tcl and a separate
    __[crc32](crc32\.md)__ package is available\.

# <a name='section3'></a>OPTIONS

  - \-filename *name*

    Return a checksum for the file contents instead of for parameter data\.

  - \-format *string*

    Return the checksum using an alternative format template\.

  - \-seed *value*

    Select an alternative seed value for the CRC calculation\. The default is 0
    for the CRC16 calculation and 0xFFFF for the CCITT version\. This can be
    useful for calculating the CRC for data structures without first converting
    the whole structure into a string\. The CRC of the previous member can be
    used as the seed for calculating the CRC of the next member\. It is also used
    for accumulating a checksum from fragments of a large message \(or file\)

  - \-implementation *procname*

    This hook is provided to allow users to provide their own implementation
    \(perhaps a C compiled extension\)\. The procedure specfied is called with two
    parameters\. The first is the data to be checksummed and the second is the
    seed value\. An integer is expected as the result\.

    The package provides some implementations of standard CRC polynomials for
    the XMODEM, CCITT and the usual CRC\-16 checksum\. For convenience, additional
    commands have been provided that make use of these implementations\.

  - \-\-

    Terminate option processing\. Please note that using the option termination
    flag is important when processing data from parameters\. If the binary data
    looks like one of the options given above then the data will be read as an
    option if this marker is not included\. Always use the *\-\-* option
    termination flag before giving the data argument\.

# <a name='section4'></a>EXAMPLES

    % crc::crc16 -- "Hello, World!"
    64077

    % crc::crc-ccitt -- "Hello, World!"
    26586

    % crc::crc16 -format 0x%X -- "Hello, World!"
    0xFA4D

    % crc::crc16 -file crc16.tcl
    51675

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

[cksum\(n\)](cksum\.md), [crc32\(n\)](crc32\.md), [sum\(n\)](sum\.md)

# <a name='keywords'></a>KEYWORDS

[checksum](\.\./\.\./\.\./\.\./index\.md\#checksum),
[cksum](\.\./\.\./\.\./\.\./index\.md\#cksum), [crc](\.\./\.\./\.\./\.\./index\.md\#crc),
[crc16](\.\./\.\./\.\./\.\./index\.md\#crc16),
[crc32](\.\./\.\./\.\./\.\./index\.md\#crc32), [cyclic redundancy
check](\.\./\.\./\.\./\.\./index\.md\#cyclic\_redundancy\_check), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, 2017, Pat Thoyts
