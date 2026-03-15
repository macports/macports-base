
[//000000001]: # (critcl\_howto\_sources \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_howto\_sources\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_howto\_sources\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_howto\_sources \- How To Get The CriTcl Sources

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Install the Git Source Code Manager](#section2)

  - [Retrieve The Sources](#section3)

  - [Authors](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

The sources for *[CriTcl](critcl\.md)* are retrieved in two easy steps:

  1. [Install the Git Source Code Manager](#section2)

  1. [Retrieve The Sources](#section3)

It is now possible to follow the instructions on *[How To Install
CriTcl](critcl\_howto\_install\.md)*\.

# <a name='section2'></a>Install the Git Source Code Manager

*[CriTcl](critcl\.md)*'s sources are managed by the popular [Git
SCM](http://www\.git\-scm\.com)\.

Binaries of clients for popular platforms can be found at the [download
page](https://git\-scm\.com/downloads)\.

See also if your operating system's package manager provides clients and
associated tools for installation\. If so, follow the instructions for the
installation of such packages on your system\.

# <a name='section3'></a>Retrieve The Sources

  1. Choose a directory for the sources, and make it the working directory\.

  1. Invoke the command

     > git clone [http://andreas\-kupries\.github\.io/critcl](http://andreas\-kupries\.github\.io/critcl)

  1. The working directory now contains a sub\-directory "critcl" holding the
     sources of *[CriTcl](critcl\.md)*\.

# <a name='section4'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report them at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)\.
Ideas for enhancements you may have for either package, application, and/or the
documentation are also very welcome and should be reported at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)
as well\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [calling C code from
Tcl](\.\./index\.md\#calling\_c\_code\_from\_tcl), [code
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

Copyright &copy; Jean\-Claude Wippler  
Copyright &copy; Steve Landers  
Copyright &copy; 2011\-2024 Andreas Kupries
