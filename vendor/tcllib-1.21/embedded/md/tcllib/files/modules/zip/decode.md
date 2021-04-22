
[//000000001]: # (zipfile::decode \- Zip archive handling)
[//000000002]: # (Generated from file 'decode\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008\-2022 Andreas Kupries)
[//000000004]: # (zipfile::decode\(n\) 0\.9 tcllib "Zip archive handling")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

zipfile::decode \- Access to zip archives

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require fileutil::decode 0\.2\.1  
package require Trf  
package require zlibtcl  
package require zipfile::decode ?0\.9?  

[__::zipfile::decode::archive__](#1)  
[__::zipfile::decode::close__](#2)  
[__::zipfile::decode::comment__ *adict*](#3)  
[__::zipfile::decode::content__ *archive*](#4)  
[__::zipfile::decode::copyfile__ *adict* *path* *dst*](#5)  
[__::zipfile::decode::files__ *adict*](#6)  
[__::zipfile::decode::getfile__ *zdict* *path*](#7)  
[__::zipfile::decode::hasfile__ *adict* *path*](#8)  
[__::zipfile::decode::filesize__ *zdict* *path*](#9)  
[__::zipfile::decode::filecomment__ *zdict* *path*](#10)  
[__::zipfile::decode::iszip__ *archive*](#11)  
[__::zipfile::decode::open__ *archive*](#12)  
[__::zipfile::decode::unzip__ *adict* *dstdir*](#13)  
[__::zipfile::decode::unzipfile__ *archive* *dstdir*](#14)  

# <a name='description'></a>DESCRIPTION

Note: packages Trf and zlibtcl are not required if TCL 8\.6 is available\. This
package provides commands to decompress and access the contents of zip archives\.

# <a name='section2'></a>API

  - <a name='1'></a>__::zipfile::decode::archive__

    This command decodes the last opened \(and not yet closed\) zip archive file\.
    The result of the command is a dictionary describing the contents of the
    archive\. The structure of this dictionary is not public\. Proper access
    should be made through the provided accessor commands of this package\.

  - <a name='2'></a>__::zipfile::decode::close__

    This command releases all state associated with the last call of
    __::zipfile::decode::open__\. The result of the command is the empty
    string\.

  - <a name='3'></a>__::zipfile::decode::comment__ *adict*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and returns the
    global comment of the archive\.

  - <a name='4'></a>__::zipfile::decode::content__ *archive*

    This is a convenience command which decodes the specified zip *archive*
    file and returns the list of paths found in it as its result\.

  - <a name='5'></a>__::zipfile::decode::copyfile__ *adict* *path* *dst*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and copies the
    decompressed contents of the file *path* in the archive to the the file
    *dst*\. An error is thrown if the file is not found in the archive\.

  - <a name='6'></a>__::zipfile::decode::files__ *adict*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and returns the
    list of files found in the archive\.

  - <a name='7'></a>__::zipfile::decode::getfile__ *zdict* *path*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and returns the
    decompressed contents of the file *path* in the archive\. An error is
    thrown if the file is not found in the archive\.

  - <a name='8'></a>__::zipfile::decode::hasfile__ *adict* *path*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and check if the
    specified *path* is found in the archive\. The result of the command is a
    boolean flag, __true__ if the path is found, and __false__
    otherwise\.

  - <a name='9'></a>__::zipfile::decode::filesize__ *zdict* *path*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and returns the
    decompressed size of the file *path* in the archive\. An error is thrown if
    the file is not found in the archive\.

  - <a name='10'></a>__::zipfile::decode::filecomment__ *zdict* *path*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and returns the
    per\-file comment of the file *path* in the archive\. An error is thrown if
    the file is not found in the archive\.

  - <a name='11'></a>__::zipfile::decode::iszip__ *archive*

    This command takes the path of a presumed zip *archive* file and returns a
    boolean flag as the result of the command telling us if it actually is a zip
    archive \(__true__\), or not \(__false__\)\.

  - <a name='12'></a>__::zipfile::decode::open__ *archive*

    This command takes the path of a zip *archive* file and prepares it for
    decoding\. The result of the command is the empty string\. All important
    information is stored in global state\. If multiple open calls are made one
    after the other only the state of the last call is available to the other
    commands\.

  - <a name='13'></a>__::zipfile::decode::unzip__ *adict* *dstdir*

    This command takes a dictionary describing the currently open zip archive
    file, as returned by __::zipfile::decode::archive__, and unpacks the
    archive in the given destination directory *dstdir*\. The result of the
    command is the empty string\.

  - <a name='14'></a>__::zipfile::decode::unzipfile__ *archive* *dstdir*

    This is a convenience command which unpacks the specified zip *archive*
    file in the given destination directory *dstdir*\.

    The result of the command is the empty string\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *zipfile* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[decompression](\.\./\.\./\.\./\.\./index\.md\#decompression),
[zip](\.\./\.\./\.\./\.\./index\.md\#zip)

# <a name='category'></a>CATEGORY

File

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008\-2022 Andreas Kupries
