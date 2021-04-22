
[//000000001]: # (zipfile::encode \- Zip archive handling)
[//000000002]: # (Generated from file 'encode\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2008\-2009 Andreas Kupries)
[//000000004]: # (zipfile::encode\(n\) 0\.4 tcllib "Zip archive handling")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

zipfile::encode \- Generation of zip archives

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Class API](#section2)

  - [Instance API](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require logger  
package require Trf  
package require crc32  
package require snit  
package require zlibtcl  
package require fileutil  
package require zipfile::encode ?0\.4?  

[__::zipfile::encode__ ?*objectName*?](#1)  
[__<encoder>__ __comment:__ *text*](#2)  
[__<encoder>__ __file:__ *dst* *owned* *src* ?*noCompress*?](#3)  
[__<encoder>__ __write__ *archive*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a class for the generation of zip archives\.

# <a name='section2'></a>Class API

  - <a name='1'></a>__::zipfile::encode__ ?*objectName*?

    The class command constructs encoder instances, i\.e\. objects\. The result of
    the command is the fully\-qualified name of the instance command\.

    If no *objectName* is specified the class will generate and use an
    automatic name\. If the *objectName* was specified, but is not fully
    qualified the command will be created in the current namespace\.

# <a name='section3'></a>Instance API

  - <a name='2'></a>__<encoder>__ __comment:__ *text*

    This method specifies the text of the global comment for the archive\. The
    result of the method is the empty string\. In case of multiple calls to this
    method for the same encoder the data from the last call prevails over all
    previous texts\.

  - <a name='3'></a>__<encoder>__ __file:__ *dst* *owned* *src* ?*noCompress*?

    This method adds a new file to the archive\. The contents of the file are
    found in the filesystem at *src*, and will be stored in the archive under
    path *dst*\. If the file is declared as *owned* by the archive the
    original file will be deleted when the archive is constructed and written\.
    If *noCompress* is set to __true__ the file will not be compressed on
    writing\. Otherwise \(the default\) the file is compressed if it is
    advantageous\. The result of the method is an empty string\.

  - <a name='4'></a>__<encoder>__ __write__ *archive*

    This method takes the global comment and all added files, encodes them as a
    zip archive and stores the result at path *archive* in the filesystem\. All
    added files which were owned by the archive are deleted at this point\. On
    the issue of ordering, the files are added to the archive in the same order
    as they were specified via __file:__\. *Note* that this behaviour is
    new for version 0\.4 and higher\. Before 0\.4 no specific order was documented\.
    It was lexicographically sorted\. The change was made to support
    __[zip](\.\./\.\./\.\./\.\./index\.md\#zip)__\-based file formats which require
    a specific order of files in the archive, for example "\.epub"\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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

[compression](\.\./\.\./\.\./\.\./index\.md\#compression),
[zip](\.\./\.\./\.\./\.\./index\.md\#zip)

# <a name='category'></a>CATEGORY

File

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2008\-2009 Andreas Kupries
