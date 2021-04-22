
[//000000001]: # (fileutil::magic::cfront \- file utilities)
[//000000002]: # (Generated from file 'cfront\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (fileutil::magic::cfront\(n\) 1\.2\.0 tcllib "file utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

fileutil::magic::cfront \- Generator core for compiler of magic\(5\) files

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require fileutil::magic::cfront ?1\.2\.0?  
package require fileutil::magic::cgen ?1\.2\.0?  
package require fileutil::magic::rt ?1\.2\.0?  
package require struct::list  
package require fileutil  

[__::fileutil::magic::cfront::compile__ *path*\.\.\.](#1)  
[__::fileutil::magic::cfront::procdef__ *procname* *path*\.\.\.](#2)  
[__::fileutil::magic::cfront::install__ *path*\.\.\.](#3)  

# <a name='description'></a>DESCRIPTION

This package provides the frontend of a compiler of magic\(5\) files into
recognizers based on the __[fileutil::magic::rt](rtcore\.md)__ recognizer
runtime package\. For the generator backed used by this compiler see the package
__[fileutil::magic::cgen](cgen\.md)__\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::fileutil::magic::cfront::compile__ *path*\.\.\.

    This command takes the paths of one or more files and directories and
    compiles all the files, and the files in all the directories into a single
    analyzer for all the file types specified in these files\. It returns a list
    whose first item is a list per\-file dictionaries of analyzer scripts and
    whose second item is a list of analyzer commands\.

    All the files have to be in the format specified by magic\(5\)\.

    The result of the command is a Tcl script containing the generated
    recognizer\.

  - <a name='2'></a>__::fileutil::magic::cfront::procdef__ *procname* *path*\.\.\.

    This command behaves like __::fileutil::magic::cfront::compile__ with
    regard to the specified path arguments, then wraps the resulting recognizer
    script into a procedure named *procname*, puts code setting up the
    namespace of *procname* in front, and returns the resulting script\.

  - <a name='3'></a>__::fileutil::magic::cfront::install__ *path*\.\.\.

    This command uses __::fileutil::magic::cfront::procdef__ to compile each
    of the paths into a recognizer procedure and installs the result in the
    current interpreter\.

    The name of each new procedure is derived from the name of the
    file/directory used in its creation, with file/directory "FOO" causing the
    creation of procedure __::fileutil::magic::/FOO::run__\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *fileutil :: magic* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

file\(1\), [fileutil](\.\./fileutil/fileutil\.md), magic\(5\)

# <a name='keywords'></a>KEYWORDS

[file recognition](\.\./\.\./\.\./\.\./index\.md\#file\_recognition), [file
type](\.\./\.\./\.\./\.\./index\.md\#file\_type), [file
utilities](\.\./\.\./\.\./\.\./index\.md\#file\_utilities),
[mime](\.\./\.\./\.\./\.\./index\.md\#mime), [type](\.\./\.\./\.\./\.\./index\.md\#type)

# <a name='category'></a>CATEGORY

Programming tools
