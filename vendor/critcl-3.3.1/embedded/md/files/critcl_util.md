
[//000000001]: # (critcl::util \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_util\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::util\(n\) 1\.2 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::util \- CriTcl \- Utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Authors](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.2?  
package require critcl::util ?1\.2?  

[__::critcl::util::checkfun__ *name* ?*label*?](#1)  
[__::critcl::util::def__ *path* *define* ?*value*?](#2)  
[__::critcl::util::undef__ *path* *define*](#3)  
[__::critcl::util::locate__ *label* *paths* ?*cmd*?](#4)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::util__ package\.
This package provides convenience commands for advanced functionality built on
top of the core\. Its intended audience are mainly developers wishing to write
Tcl packages with embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::util::checkfun__ *name* ?*label*?

    This command checks the build\-time environment for the existence of the C
    function *name*\. It returns __true__ on success, and __false__
    otherwise\.

  - <a name='2'></a>__::critcl::util::def__ *path* *define* ?*value*?

    This command extends the specified configuration file *path* with a
    __\#define__ directive for the named *define*\. If the *value* is not
    specified it will default to __1__\.

    The result of the command is an empty string\.

    Note that the configuration file is maintained in the __critcl::cache__
    directory\.

  - <a name='3'></a>__::critcl::util::undef__ *path* *define*

    This command extends the specified configuration file *path* with an
    __\#undef__ directive for the named *define*\.

    The result of the command is an empty string\.

    Note that the configuration file is maintained in the __critcl::cache__
    directory\.

  - <a name='4'></a>__::critcl::util::locate__ *label* *paths* ?*cmd*?

    This command checks the build\-time environment for the existence of a file
    in a set of possible *paths*\.

    If the option *cmd* prefix is specified it will be called with the full
    path of a found file as its only argument to perform further checks\. A
    return value of __false__ will reject the path and continue the search\.

    The return value of the command is the found path, as listed in *paths*\.
    As a side effect the command will also print the found path, prefixed with
    the *label*, using __critcl::msg__\.

    Failure to find the path is reported via __critcl::error__, and a
    possible empty string as the result, if __critcl::error__ does not
    terminate execution\. A relative path is resolved relative to the directory
    containing the *CriTcl script*\.

# <a name='section3'></a>Authors

Andreas Kupries

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such at
[https://github\.com/andreas\-kupries/critcl](https://github\.com/andreas\-kupries/critcl)\.
Please also report any ideas for enhancements you may have for either package
and/or documentation\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2024 Andreas Kupries
