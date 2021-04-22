
[//000000001]: # (aes \- Advanced Encryption Standard \(AES\))
[//000000002]: # (Generated from file 'aes\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2012\-2014, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000005]: # (aes\(n\) 1\.2\.1 tcllib "Advanced Encryption Standard \(AES\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

aes \- Implementation of the AES block cipher

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

package require Tcl 8\.5  
package require aes ?1\.2\.1?  

[__::aes::aes__ ?*\-mode \[ecb&#124;cbc\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-hex*? ?*\-out channel*? ?*\-chunksize size*? \[ *\-in channel* &#124; ?__\-\-__? *data* \]](#1)  
[__::aes::Init__ *mode* *keydata* *iv*](#2)  
[__::aes::Encrypt__ *Key* *data*](#3)  
[__::aes::Decrypt__ *Key* *data*](#4)  
[__::aes::Reset__ *Key* *iv*](#5)  
[__::aes::Final__ *Key*](#6)  

# <a name='description'></a>DESCRIPTION

This is an implementation in Tcl of the Advanced Encryption Standard \(AES\) as
published by the U\.S\. National Institute of Standards and Technology \[1\]\. AES is
a 128\-bit block cipher with a variable key size of 128, 192 or 256 bits\. This
implementation supports ECB and CBC modes\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::aes::aes__ ?*\-mode \[ecb&#124;cbc\]*? ?*\-dir \[encrypt&#124;decrypt\]*? *\-key keydata* ?*\-iv vector*? ?*\-hex*? ?*\-out channel*? ?*\-chunksize size*? \[ *\-in channel* &#124; ?__\-\-__? *data* \]

    Perform the __aes__ algorithm on either the data provided by the
    argument or on the data read from the *\-in* channel\. If an *\-out*
    channel is given then the result will be written to this channel\.

    The *\-key* option must be given\. This parameter takes a binary string of
    either 16, 24 or 32 bytes in length and is used to generate the key
    schedule\.

    The *\-mode* and *\-dir* options are optional and default to cbc mode and
    encrypt respectively\. The initialization vector *\-iv* takes a 16 byte
    binary argument which defaults to all zeros\. See [MODES OF
    OPERATION](#section4) for more about available modes and their uses\.

    AES is a 128\-bit block cipher\. This means that the data must be provided in
    units that are a multiple of 16 bytes\.

# <a name='section3'></a>PROGRAMMING INTERFACE

Internal state is maintained in an opaque structure that is returned from the
__Init__ function\. In ECB mode the state is not affected by the input but
for CBC mode some input dependent state is maintained and may be reset by
calling the __Reset__ function with a new initialization vector value\.

  - <a name='2'></a>__::aes::Init__ *mode* *keydata* *iv*

    Construct a new AES key schedule using the specified key data and the given
    initialization vector\. The initialization vector is not used with ECB mode
    but is important for CBC mode\. See [MODES OF OPERATION](#section4) for
    details about cipher modes\.

  - <a name='3'></a>__::aes::Encrypt__ *Key* *data*

    Use a prepared key acquired by calling __Init__ to encrypt the provided
    data\. The data argument should be a binary array that is a multiple of the
    AES block size of 16 bytes\. The result is a binary array the same size as
    the input of encrypted data\.

  - <a name='4'></a>__::aes::Decrypt__ *Key* *data*

    Decipher data using the key\. Note that the same key may be used to encrypt
    and decrypt data provided that the initialization vector is reset
    appropriately for CBC mode\.

  - <a name='5'></a>__::aes::Reset__ *Key* *iv*

    Reset the initialization vector\. This permits the programmer to re\-use a key
    and avoid the cost of re\-generating the key schedule where the same key data
    is being used multiple times\.

  - <a name='6'></a>__::aes::Final__ *Key*

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
    encryption\. This is the default mode of operation for this module\.

# <a name='section5'></a>EXAMPLES

    % set nil_block [string repeat \\0 16]
    % aes::aes -hex -mode cbc -dir encrypt -key $nil_block $nil_block
    66e94bd4ef8a2c3b884cfa59ca342b2e

    set Key [aes::Init cbc $sixteen_bytes_key_data $sixteen_byte_iv]
    append ciphertext [aes::Encrypt $Key $plaintext]
    append ciphertext [aes::Encrypt $Key $additional_plaintext]
    aes::Final $Key

# <a name='section6'></a>REFERENCES

  1. "Advanced Encryption Standard", Federal Information Processing Standards
     Publication 197, 2001
     \([http://csrc\.nist\.gov/publications/fips/fips197/fips\-197\.pdf](http://csrc\.nist\.gov/publications/fips/fips197/fips\-197\.pdf)\)

# <a name='section7'></a>AUTHORS

Thorsten Schloermann, Pat Thoyts

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *aes* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[blowfish\(n\)](\.\./blowfish/blowfish\.md), [des\(n\)](\.\./des/des\.md),
[md5\(n\)](\.\./md5/md5\.md), [sha1\(n\)](\.\./sha1/sha1\.md)

# <a name='keywords'></a>KEYWORDS

[aes](\.\./\.\./\.\./\.\./index\.md\#aes), [block
cipher](\.\./\.\./\.\./\.\./index\.md\#block\_cipher), [data
integrity](\.\./\.\./\.\./\.\./index\.md\#data\_integrity),
[encryption](\.\./\.\./\.\./\.\./index\.md\#encryption),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005, Pat Thoyts <patthoyts@users\.sourceforge\.net>  
Copyright &copy; 2012\-2014, Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
