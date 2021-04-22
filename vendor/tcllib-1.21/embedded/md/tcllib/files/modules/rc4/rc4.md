
[//000000001]: # (rc4 \- RC4 Stream Cipher)
[//000000002]: # (Generated from file 'rc4\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (rc4\(n\) 1\.1\.0 tcllib "RC4 Stream Cipher")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

rc4 \- Implementation of the RC4 stream cipher

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [PROGRAMMING INTERFACE](#section3)

  - [EXAMPLES](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require rc4 ?1\.1\.0?  

[__::rc4::rc4__ ?*\-hex*? *\-key keyvalue* ?*\-command lst*? ?*\-out channel*? \[ *\-in channel* &#124; *\-infile filename* &#124; *string* \]](#1)  
[__::rc4::RC4Init__ *keydata*](#2)  
[__::rc4::RC4__ *Key* *data*](#3)  
[__::rc4::RC4Final__ *Key*](#4)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the RC4 stream cipher developed by
Ron Rivest of RSA Data Security Inc\. The cipher was a trade secret of RSA but
was reverse\-engineered and published to the internet in 1994\. It is used in a
number of network protocols for securing communications\. To evade trademark
restrictions this cipher is sometimes known as ARCFOUR\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::rc4::rc4__ ?*\-hex*? *\-key keyvalue* ?*\-command lst*? ?*\-out channel*? \[ *\-in channel* &#124; *\-infile filename* &#124; *string* \]

    Perform the RC4 algorithm on either the data provided by the argument or on
    the data read from the *\-in* channel\. If an *\-out* channel is given then
    the result will be written to this channel\. Giving the *\-hex* option will
    return a hexadecimal encoded version of the result if not using an *\-out*
    channel\.

    The data to be processes can be specified either as a string argument to the
    rc4 command, or as a filename or a pre\-opened channel\. If the *\-infile*
    argument is given then the file is opened, the data read and processed and
    the file is closed\. If the *\-in* argument is given then data is read from
    the channel until the end of file\. The channel is not closed\. If the
    *\-out* argument is given then the processing result is written to this
    channel\.

    If *\-command* is provided then the rc4 command does not return anything\.
    Instead the command provided is called with the rc4 result data appended as
    the final parameter\. This is most useful when reading from Tcl channels as a
    fileevent is setup on the channel and the data processed in chunks

    Only one of *\-infile*, *\-in* or *string* should be given\.

# <a name='section3'></a>PROGRAMMING INTERFACE

  - <a name='2'></a>__::rc4::RC4Init__ *keydata*

    Initialize a new RC4 key\. The *keydata* is any amount of binary data and
    is used to initialize the cipher internal state\.

  - <a name='3'></a>__::rc4::RC4__ *Key* *data*

    Encrypt or decrypt the input data using the key obtained by calling
    __RC4Init__\.

  - <a name='4'></a>__::rc4::RC4Final__ *Key*

    This should be called to clean up resources associated with *Key*\. Once
    this function has been called the key is destroyed\.

# <a name='section4'></a>EXAMPLES

    % set keydata [binary format H* 0123456789abcdef]
    % rc4::rc4 -hex -key $keydata HelloWorld
    3cf1ae8b7f1c670b612f
    % rc4::rc4 -hex -key $keydata [binary format H* 3cf1ae8b7f1c670b612f]
    HelloWorld

    set Key [rc4::RC4Init "key data"]
    append ciphertext [rc4::RC4 $Key $plaintext]
    append ciphertext [rc4::RC4 $Key $additional_plaintext]
    rc4::RC4Final $Key

    proc ::Finish {myState data} {
        DoStuffWith $myState $data
    }
    rc4::rc4 -in $socket -command [list ::Finish $ApplicationState]

# <a name='section5'></a>AUTHORS

Pat Thoyts

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *rc4* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[aes\(n\)](\.\./aes/aes\.md), [blowfish\(n\)](\.\./blowfish/blowfish\.md),
[des\(n\)](\.\./des/des\.md)

# <a name='keywords'></a>KEYWORDS

[arcfour](\.\./\.\./\.\./\.\./index\.md\#arcfour), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[encryption](\.\./\.\./\.\./\.\./index\.md\#encryption),
[rc4](\.\./\.\./\.\./\.\./index\.md\#rc4),
[security](\.\./\.\./\.\./\.\./index\.md\#security), [stream
cipher](\.\./\.\./\.\./\.\./index\.md\#stream\_cipher)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>
