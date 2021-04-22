
[//000000001]: # (uuid \- uuid)
[//000000002]: # (Generated from file 'uuid\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (uuid\(n\) 1\.0\.6 tcllib "uuid")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uuid \- UUID generation and comparison

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLES](#section3)

  - [REFERENCES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require uuid ?1\.0\.6?  

[__::uuid::uuid generate__](#1)  
[__::uuid::uuid equal__ *id1* *id2*](#2)  

# <a name='description'></a>DESCRIPTION

This package provides a generator of universally unique identifiers \(UUID\) also
known as globally unique identifiers \(GUID\)\. This implementation follows the
draft specification from \(1\) although this is actually an expired draft
document\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::uuid::uuid generate__

    Creates a type 4 uuid by MD5 hashing a number of bits of variant data
    including the time and hostname\. Returns the string representation of the
    new uuid\.

  - <a name='2'></a>__::uuid::uuid equal__ *id1* *id2*

    Compares two uuids and returns true if both arguments are the same uuid\.

# <a name='section3'></a>EXAMPLES

    % uuid::uuid generate
    b12dc22c-5c36-41d2-57da-e29d0ef5839c

# <a name='section4'></a>REFERENCES

  1. Paul J\. Leach, "UUIDs and GUIDs", February 1998\.
     \([http://www\.opengroup\.org/dce/info/draft\-leach\-uuids\-guids\-01\.txt](http://www\.opengroup\.org/dce/info/draft\-leach\-uuids\-guids\-01\.txt)\)

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *uuid* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[GUID](\.\./\.\./\.\./\.\./index\.md\#guid), [UUID](\.\./\.\./\.\./\.\./index\.md\#uuid)

# <a name='category'></a>CATEGORY

Hashes, checksums, and encryption

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004, Pat Thoyts <patthoyts@users\.sourceforge\.net>
