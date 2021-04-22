
[//000000001]: # (inifile \- Parsing of Windows INI files)
[//000000002]: # (Generated from file 'ini\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (inifile\(n\) 0\.3\.2 tcllib "Parsing of Windows INI files")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

inifile \- Parsing of Windows INI files

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require inifile ?0\.3\.2?  

[__::ini::open__ *file* ?__\-encoding__ *encoding*? ?*access*?](#1)  
[__::ini::close__ *ini*](#2)  
[__::ini::commit__ *ini*](#3)  
[__::ini::revert__ *ini*](#4)  
[__::ini::filename__ *ini*](#5)  
[__::ini::sections__ *ini*](#6)  
[__::ini::keys__ *ini* *section*](#7)  
[__::ini::get__ *ini* *section*](#8)  
[__::ini::exists__ *ini* *section* ?*key*?](#9)  
[__::ini::value__ *ini* *section* *key* ?*default*?](#10)  
[__::ini::set__ *ini* *section* *key* *value*](#11)  
[__::ini::delete__ *ini* *section* ?*key*?](#12)  
[__::ini::comment__ *ini* *section* ?*key*? ?*text*?](#13)  
[__::ini::commentchar__ ?char?](#14)  

# <a name='description'></a>DESCRIPTION

This package provides an interface for easy manipulation of Windows INI files\.

  - <a name='1'></a>__::ini::open__ *file* ?__\-encoding__ *encoding*? ?*access*?

    Opens an INI file and returns a handle that is used by other commands\.
    *access* is the same as the first form \(non POSIX\) of the __open__
    command, with the exception that mode __a__ is not supported\. The
    default mode is __r\+__\.

    The default *encoding* is the system encoding\.

  - <a name='2'></a>__::ini::close__ *ini*

    Close the specified handle\. If any changes were made and not written by
    __commit__ they are lost\.

  - <a name='3'></a>__::ini::commit__ *ini*

    Writes the file and all changes to disk\. The sections are written in
    arbitrary order\. The keys in a section are written in alphabetical order\. If
    the ini was opened in read only mode an error will be thrown\.

  - <a name='4'></a>__::ini::revert__ *ini*

    Rolls all changes made to the inifile object back to the last committed
    state\.

  - <a name='5'></a>__::ini::filename__ *ini*

    Returns the name of the file the *ini* object is associated with\.

  - <a name='6'></a>__::ini::sections__ *ini*

    Returns a list of all the names of the existing sections in the file handle
    specified\.

  - <a name='7'></a>__::ini::keys__ *ini* *section*

    Returns a list of all they key names in the section and file specified\.

  - <a name='8'></a>__::ini::get__ *ini* *section*

    Returns a list of key value pairs that exist in the section and file
    specified\.

  - <a name='9'></a>__::ini::exists__ *ini* *section* ?*key*?

    Returns a boolean value indicating the existance of the specified section as
    a whole or the specified key within that section\.

  - <a name='10'></a>__::ini::value__ *ini* *section* *key* ?*default*?

    Returns the value of the named key and section\. If specified, the default
    value will be returned if the key does not exist\. If the key does not exist
    and no default is specified an error will be thrown\.

  - <a name='11'></a>__::ini::set__ *ini* *section* *key* *value*

    Sets the value of the key in the specified section\. If the section does not
    exist then a new one is created\.

  - <a name='12'></a>__::ini::delete__ *ini* *section* ?*key*?

    Removes the key or the entire section and all its keys\. A section is not
    automatically deleted when it has no remaining keys\.

  - <a name='13'></a>__::ini::comment__ *ini* *section* ?*key*? ?*text*?

    Reads and modifies comments for sections and keys\. To write a section
    comment use an empty string for the *key*\. To remove all comments use an
    empty string for *text*\. *text* may consist of a list of lines or one
    single line\. Any embedded newlines in *text* are properly handled\.
    Comments may be written to nonexistant sections or keys and will not return
    an error\. Reading a comment from a nonexistant section or key will return an
    empty string\.

  - <a name='14'></a>__::ini::commentchar__ ?char?

    Reads and sets the comment character\. Lines that begin with this character
    are treated as comments\. When comments are written out each line is preceded
    by this character\. The default is __;__\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *inifile* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='category'></a>CATEGORY

Text processing
