
[//000000001]: # (blowfish \- Blowfish Block Cipher)
[//000000002]: # (Generated from file 'blowfish\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (blowfish\(n\) 1\.0\.5 tcllib "Blowfish Block Cipher")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

blowfish \- Implementation of the Blowfish block cipher

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [PROGRAMMING INTERFACE](#section3)

  - [MODES OF OPERATION](#section4)

  - [EXAMPLES](#section5)

  - [REFERENCES](#section6)

  - [AUTHORS](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require blowfish ?1\.0\.5?  

[__::blowfish::blowfish__ ?*\-mode \[ecb&#124;cbc\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-out channel*? ?*\-chunksize size*? ?*\-pad padchar*? \[ *\-in channel* &#124; ?*\-\-*? *data* \]](#1)  
[__::blowfish::Init__ *mode* *keydata* *iv*](#2)  
[__::blowfish::Encrypt__ *Key* *data*](#3)  
[__::blowfish::Decrypt__ *Key* *data*](#4)  
[__::blowfish::Reset__ *Key* *iv*](#5)  
[__::blowfish::Final__ *Key*](#6)  

# <a name='description'></a>DESCRIPTION

This package is an implementation in Tcl of the Blowfish algorithm developed by
Bruce Schneier \[1\]\. Blowfish is a 64\-bit block cipher designed to operate
quickly on 32 bit architectures and accepting a variable key length\. This
implementation supports ECB and CBC mode blowfish encryption\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::blowfish::blowfish__ ?*\-mode \[ecb&#124;cbc\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-out channel*? ?*\-chunksize size*? ?*\-pad padchar*? \[ *\-in channel* &#124; ?*\-\-*? *data* \]

    Perform the __blowfish__ algorithm on either the data provided by the
    argument or on the data read from the *\-in* channel\. If an *\-out*
    channel is given then the result will be written to this channel\.

    The *\-key* option must be given\. This parameter takes a binary string of
    variable length and is used to generate the __blowfish__ key schedule\.
    You should be aware that creating a key schedule is quite an expensive
    operation in blowfish so it is worth reusing the key where possible\. See
    __Reset__\.

    The *\-mode* and *\-dir* options are optional and default to cbc mode and
    encrypt respectively\. The initialization vector *\-iv* takes an 8 byte
    binary argument which defaults to 8 zeros\. See [MODES OF
    OPERATION](#section4) for more about available modes and their uses\.

    Blowfish is a 64\-bit block cipher\. This means that the data must be provided
    in units that are a multiple of 8 bytes\. The __blowfish__ command will
    by default add nul characters to pad the input data to a multiple of 8 bytes
    if necessary\. The programming api commands will never add padding and
    instead will raise an error if the input is not a multiple of the block
    size\. The *\-pad* option can be used to change the padding character or to
    disable padding if the empty string is provided as the argument\.

# <a name='section3'></a>PROGRAMMING INTERFACE

  - <a name='2'></a>__::blowfish::Init__ *mode* *keydata* *iv*

    Construct a new blowfish key schedule using the specified key data and the
    given initialization vector\. The initialization vector is not used with ECB
    mode but is important for CBC mode\. See [MODES OF OPERATION](#section4)
    for details about cipher modes\.

  - <a name='3'></a>__::blowfish::Encrypt__ *Key* *data*

    Use a prepared key acquired by calling __Init__ to encrypt the provided
    data\. The data argument should be a binary array that is a multiple of the
    block size of 8 bytes\. The result is a binary array the same size as the
    input of encrypted data\.

  - <a name='4'></a>__::blowfish::Decrypt__ *Key* *data*

    Decipher data using the key\. Note that the same key may be used to encrypt
    and decrypt data provided that the initialization vector is reset
    appropriately for CBC mode\.

  - <a name='5'></a>__::blowfish::Reset__ *Key* *iv*

    Reset the initialization vector\. This permits the programmer to re\-use a key
    and avoid the cost of re\-generating the key schedule where the same key data
    is being used multiple times\.

  - <a name='6'></a>__::blowfish::Final__ *Key*

    This should be called to clean up resources associated with *Key*\. Once
    this function has been called the key may not be used again\.

# <a name='section4'></a>MODES OF OPERATION

  - Electronic Code Book \(ECB\)

    ECB is the basic mode of all block ciphers\. Each block is encrypted
    independently and so identical plain text will produce identical output when
    encrypted with the same key\. Any encryption errors will only affect a single
    block however this is vulnerable to known plaintext attacks\.

  - Cipher Block Chaining \(CBC\)

    CBC mode uses the output of the last block encryption to affect the current
    block\. An initialization vector of the same size as the cipher block size is
    used to handle the first block\. The initialization vector should be chosen
    randomly and transmitted as the first block of the output\. Errors in
    encryption affect the current block and the next block after which the
    cipher will correct itself\. CBC is the most commonly used mode in software
    encryption\.

# <a name='section5'></a>EXAMPLES

    % blowfish::blowfish -hex -mode ecb -dir encrypt -key secret01 "hello, world!"
    d0d8f27e7a374b9e2dbd9938dd04195a

    set Key [blowfish::Init cbc $eight_bytes_key_data $eight_byte_iv]
    append ciphertext [blowfish::Encrypt $Key $plaintext]
    append ciphertext [blowfish::Encrypt $Key $additional_plaintext]
    blowfish::Final $Key

# <a name='section6'></a>REFERENCES

  1. Schneier, B\. "Applied Cryptography, 2nd edition", 1996, ISBN 0\-471\-11709\-9,
     pub\. John Wiley & Sons\.

# <a name='section7'></a>AUTHORS

Frank Pilhofer, Pat Thoyts

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *blowfish* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

3des, [des](\.\./des/des\.md), [rc4](\.\./rc4/rc4\.md)

# <a name='keywords'></a>KEYWORDS

[block cipher](\.\./\.\./\.\./\.\./index\.md\#block\_cipher),
[blowfish](\.\./\.\./\.\./\.\./index\.md\#blowfish),
[cryptography](\.\./\.\./\.\./\.\./index\.md\#cryptography),
[encryption](\.\./\.\./\.\./\.\./index\.md\#encryption),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>
