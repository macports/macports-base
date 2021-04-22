
[//000000001]: # (md5crypt \- MD5\-based password encryption)
[//000000002]: # (Generated from file 'md5crypt\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (md5crypt\(n\) 1\.1\.0 tcllib "MD5\-based password encryption")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

md5crypt \- MD5\-based password encryption

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [SALT](#section3)

  - [EXAMPLES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require md5 2\.0  
package require md5crypt ?1\.1\.0?  

[__::md5crypt::md5crypt__ *password* *salt*](#1)  
[__::md5crypt::aprcrypt__ *password* *salt*](#2)  
[__::md5crypt::salt__ ?*length*?](#3)  

# <a name='description'></a>DESCRIPTION

This package provides an implementation of the MD5\-crypt password encryption
algorithm as pioneered by FreeBSD and currently in use as a replacement for the
unix crypt\(3\) function in many modern systems\. An implementation of the closely
related Apache MD5\-crypt is also available\. The output of these commands are
compatible with the BSD and OpenSSL implementation of md5crypt and the Apache 2
htpasswd program\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::md5crypt::md5crypt__ *password* *salt*

    Generate a BSD compatible md5\-encoded password hash from the plaintext
    password and a random salt \(see SALT\)\.

  - <a name='2'></a>__::md5crypt::aprcrypt__ *password* *salt*

    Generate an Apache compatible md5\-encoded password hash from the plaintext
    password and a random salt \(see SALT\)\.

  - <a name='3'></a>__::md5crypt::salt__ ?*length*?

    Generate a random salt string suitable for use with the __md5crypt__ and
    __aprcrypt__ commands\.

# <a name='section3'></a>SALT

The salt passed to either of the encryption schemes implemented here is checked
to see if it begins with the encryption scheme magic string \(either "$1$" for
MD5\-crypt or "$apr1$" for Apache crypt\)\. If so, this is removed\. The remaining
characters up to the next $ and up to a maximum of 8 characters are then used as
the salt\. The salt text should probably be restricted the set of ASCII
alphanumeric characters plus "\./" \(dot and forward\-slash\) \- this is to preserve
maximum compatability with the unix password file format\.

If a password is being generated rather than checked from a password file then
the __salt__ command may be used to generate a random salt\.

# <a name='section4'></a>EXAMPLES

    % md5crypt::md5crypt password 01234567
    $1$01234567$b5lh2mHyD2PdJjFfALlEz1

    % md5crypt::aprcrypt password 01234567
    $apr1$01234567$IXBaQywhAhc0d75ZbaSDp/

    % md5crypt::md5crypt password [md5crypt::salt]
    $1$dFmvyRmO$T.V3OmzqeEf3hqJp2WFcb.

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *md5crypt* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[md5](\.\./md5/md5\.md)

# <a name='keywords'></a>KEYWORDS

[hashing](\.\./\.\./\.\./\.\./index\.md\#hashing),
[md5](\.\./\.\./\.\./\.\./index\.md\#md5),
[md5crypt](\.\./\.\./\.\./\.\./index\.md\#md5crypt),
[message\-digest](\.\./\.\./\.\./\.\./index\.md\#message\_digest),
[security](\.\./\.\./\.\./\.\./index\.md\#security)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003, Pat Thoyts <patthoyts@users\.sourceforge\.net>
