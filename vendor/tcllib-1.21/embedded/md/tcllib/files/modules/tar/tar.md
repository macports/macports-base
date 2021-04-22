
[//000000001]: # (tar \- Tar file handling)
[//000000002]: # (Generated from file 'tar\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (tar\(n\) 0\.11 tcllib "Tar file handling")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tar \- Tar file creation, extraction & manipulation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [BEWARE](#section2)

  - [COMMANDS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require tar ?0\.11?  

[__::tar::contents__ *tarball* ?__\-chan__?](#1)  
[__::tar::stat__ *tarball* ?file? ?__\-chan__?](#2)  
[__::tar::untar__ *tarball* *args*](#3)  
[__::tar::get__ *tarball* *fileName* ?__\-chan__?](#4)  
[__::tar::create__ *tarball* *files* *args*](#5)  
[__::tar::add__ *tarball* *files* *args*](#6)  
[__::tar::remove__ *tarball* *files*](#7)  

# <a name='description'></a>DESCRIPTION

*Note*: Starting with version 0\.8 the tar reader commands \(contents, stats,
get, untar\) support the GNU LongName extension \(header type 'L'\) for large
paths\.

# <a name='section2'></a>BEWARE

For all commands, when using __\-chan__ \.\.\.

  1. It is assumed that the channel was opened for reading, and configured for
     binary input\.

  1. It is assumed that the channel position is at the beginning of a legal tar
     file\.

  1. The commands will *modify* the channel position as they perform their
     task\.

  1. The commands will *not* close the channel\.

  1. In other words, the commands leave the channel in a state very likely
     unsuitable for use by further __tar__ commands\. Still doing so will
     very likely results in errors, bad data, etc\. pp\.

  1. It is the responsibility of the user to seek the channel back to a suitable
     position\.

  1. When using a channel transformation which is not generally seekable, for
     example __gunzip__, then it is the responsibility of the user to \(a\)
     unstack the transformation before seeking the channel back to a suitable
     position, and \(b\) for restacking it after\.

# <a name='section3'></a>COMMANDS

  - <a name='1'></a>__::tar::contents__ *tarball* ?__\-chan__?

    Returns a list of the files contained in *tarball*\. The order is not
    sorted and depends on the order files were stored in the archive\.

    If the option __\-chan__ is present *tarball* is interpreted as an open
    channel\. It is assumed that the channel was opened for reading, and
    configured for binary input\. The command will *not* close the channel\.

  - <a name='2'></a>__::tar::stat__ *tarball* ?file? ?__\-chan__?

    Returns a nested dict containing information on the named ?file? in
    *tarball*, or all files if none is specified\. The top level are pairs of
    filename and info\. The info is a dict with the keys "__mode__
    __uid__ __gid__ __size__ __mtime__ __type__
    __linkname__ __uname__ __gname__ __devmajor__
    __devminor__"

        % ::tar::stat tarball.tar
        foo.jpg {mode 0644 uid 1000 gid 0 size 7580 mtime 811903867 type file linkname {} uname user gname wheel devmajor 0 devminor 0}

    If the option __\-chan__ is present *tarball* is interpreted as an open
    channel\. It is assumed that the channel was opened for reading, and
    configured for binary input\. The command will *not* close the channel\.

  - <a name='3'></a>__::tar::untar__ *tarball* *args*

    Extracts *tarball*\. *\-file* and *\-glob* limit the extraction to files
    which exactly match or pattern match the given argument\. No error is thrown
    if no files match\. Returns a list of filenames extracted and the file size\.
    The size will be null for non regular files\. Leading path seperators are
    stripped so paths will always be relative\.

      * __\-dir__ dirName

        Directory to extract to\. Uses __pwd__ if none is specified

      * __\-file__ fileName

        Only extract the file with this name\. The name is matched against the
        complete path stored in the archive including directories\.

      * __\-glob__ pattern

        Only extract files patching this glob style pattern\. The pattern is
        matched against the complete path stored in the archive\.

      * __\-nooverwrite__

        Dont overwrite files that already exist

      * __\-nomtime__

        Leave the file modification time as the current time instead of setting
        it to the value in the archive\.

      * __\-noperms__

        In Unix, leave the file permissions as the current umask instead of
        setting them to the values in the archive\.

      * __\-chan__

        If this option is present *tarball* is interpreted as an open channel\.
        It is assumed that the channel was opened for reading, and configured
        for binary input\. The command will *not* close the channel\.

        % foreach {file size} [::tar::untar tarball.tar -glob *.jpg] {
        puts "Extracted $file ($size bytes)"
        }

  - <a name='4'></a>__::tar::get__ *tarball* *fileName* ?__\-chan__?

    Returns the contents of *fileName* from the *tarball*\.

        % set readme [::tar::get tarball.tar doc/README] {
        % puts $readme
        }

    If the option __\-chan__ is present *tarball* is interpreted as an open
    channel\. It is assumed that the channel was opened for reading, and
    configured for binary input\. The command will *not* close the channel\.

    An error is thrown when *fileName* is not found in the tar archive\.

  - <a name='5'></a>__::tar::create__ *tarball* *files* *args*

    Creates a new tar file containing the *files*\. *files* must be specified
    as a single argument which is a proper list of filenames\.

      * __\-dereference__

        Normally __create__ will store links as an actual link pointing at a
        file that may or may not exist in the archive\. Specifying this option
        will cause the actual file point to by the link to be stored instead\.

      * __\-chan__

        If this option is present *tarball* is interpreted as an open channel\.
        It is assumed that the channel was opened for writing, and configured
        for binary output\. The command will *not* close the channel\.

        % ::tar::create new.tar [glob -nocomplain file*]
        % ::tar::contents new.tar
        file1 file2 file3

  - <a name='6'></a>__::tar::add__ *tarball* *files* *args*

    Appends *files* to the end of the existing *tarball*\. *files* must be
    specified as a single argument which is a proper list of filenames\.

      * __\-dereference__

        Normally __add__ will store links as an actual link pointing at a
        file that may or may not exist in the archive\. Specifying this option
        will cause the actual file point to by the link to be stored instead\.

      * __\-prefix__ string

        Normally __add__ will store files under exactly the name specified
        as argument\. Specifying a ?\-prefix? causes the *string* to be
        prepended to every name\.

      * __\-quick__

        The only sure way to find the position in the *tarball* where new
        files can be added is to read it from start, but if *tarball* was
        written with a "blocksize" of 1 \(as this package does\) then one can
        alternatively find this position by seeking from the end\. The ?\-quick?
        option tells __add__ to do the latter\.

  - <a name='7'></a>__::tar::remove__ *tarball* *files*

    Removes *files* from the *tarball*\. No error will result if the file
    does not exist in the tarball\. Directory write permission and free disk
    space equivalent to at least the size of the tarball will be needed\.

        % ::tar::remove new.tar {file2 file3}
        % ::tar::contents new.tar
        file3

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tar* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[archive](\.\./\.\./\.\./\.\./index\.md\#archive), [tape
archive](\.\./\.\./\.\./\.\./index\.md\#tape\_archive),
[tar](\.\./\.\./\.\./\.\./index\.md\#tar)

# <a name='category'></a>CATEGORY

File formats
