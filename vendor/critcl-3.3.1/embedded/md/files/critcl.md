
[//000000001]: # (critcl \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl \- Introduction To CriTcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [History & Motivation](#section2)

  - [Overview](#section3)

  - [Known Users](#section4)

  - [Tutorials \- Practical Study \- To Learn](#section5)

  - [Explanations \- Theoretical Knowledge \- To Understand](#section6)

  - [How\-To Guides \- Practical Work \- To Solve Problems](#section7)

  - [References \- Theoretical Work \- To Gain Knowlegde](#section8)

  - [Authors](#section9)

  - [Bugs, Ideas, Feedback](#section10)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *CriTcl*\), a system for
embedding and using C code from within [Tcl](http://core\.tcl\-lang\.org/tcl)
scripts\.

Adding C code to
[Tcl](http://core\.tcl\-lang\.org/tcl)/[Tk](http://core\.tcl\-lang\.org/tk)
has never been easier\.

Improve performance by rewriting the performance bottlenecks in C\.

Import the functionality of shared libraries into Tcl scripts\.

# <a name='section2'></a>History & Motivation

*CriTcl* started life as an experiment by *Jean\-Claude Wippler* and was a
self\-contained Tcl package to build C code into a Tcl/Tk extension on the fly\.
It was somewhat inspired by Brian Ingerson's *Inline* for *Perl*, but is
considerably more lightweight\.

It is for the last 5% to 10% when pure Tcl, which does go a long way, is not
sufficient anymore\. I\.e\. for

  1. when the last bits of performance are needed,

  1. access to 3rd party libraries,

  1. hiding critical pieces of your library or application, and

  1. simply needing features provided only by C\.

# <a name='section3'></a>Overview

To make the reader's topics of interest easy to find this documentation is
roughly organized by [Quadrants](https://documentation\.divio\.com/), i\.e\.

> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124; Study           &#124; Work  
> \-\-\-\-\-\-\-\-\-\-\- \+ \-\-\-\-\-\-\-\-\-\-\-\-\-\-\- \+ \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> Practical   &#124; [Tutorials](#section5)       &#124; [How\-To Guides](#section7)  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124; \(Learning\)      &#124; \(Problem solving\)  
> \-\-\-\-\-\-\-\-\-\-\- \+ \-\-\-\-\-\-\-\-\-\-\-\-\-\-\- \+ \-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-  
> Theoretical &#124; [Explanations](#section6)    &#124; [References](#section8)  
> &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#124; \(Understanding\) &#124; \(Knowledge\)

*Note*: At this point in time the documentation consists mainly of references,
and a few how\-to guides\. Tutorials and Explanations are in need of expansion,
this is planned\.

# <a name='section4'></a>Known Users

  - [AnKH](https://core\.tcl\-lang\.org/akupries/ankh)

  - [TclYAML](https://core\.tcl\.tk/akupries/tclyaml)

  - [Linenoise](https://github\.com/andreas\-kupries/tcl\-linenoise)

  - [KineTcl](https://core\.tcl\.tk/akupries/kinetcl)

  - [Inotify](https://chiselapp\.com/user/andreas\_kupries/repository/inotify)

  - [TclMarpa](https://core\.tcl\.tk/akupries/marpa)

  - [CRIMP](https://core\.tcl\.tk/akupries/crimp)

# <a name='section5'></a>Tutorials \- Practical Study \- To Learn

This section is currently empty\.

# <a name='section6'></a>Explanations \- Theoretical Knowledge \- To Understand

This section is currently empty\.

# <a name='section7'></a>How\-To Guides \- Practical Work \- To Solve Problems

  1. *[How To Get The CriTcl Sources](critcl\_howto\_sources\.md)*\.

  1. *[How To Install CriTcl](critcl\_howto\_install\.md)*\.

  1. *[How To Use CriTcl](critcl\_howto\_use\.md)* \- A light introduction
     through examples\.

  1. *NEW*: *[How To Adapt Critcl Packages for Tcl 9](critcl\_tcl9\.md)*\.

# <a name='section8'></a>References \- Theoretical Work \- To Gain Knowlegde

  1. *[The CriTcl License](critcl\_license\.md)*

  1. *[CriTcl Releases & Changes](critcl\_changes\.md)*

  1. *[CriTcl Application Reference](critcl\_application\.md)*

  1. *[CriTcl Package Reference](critcl\_package\.md)*

  1. *[CriTcl cproc Type Reference](critcl\_cproc\.md)*

  1. *[CriTcl \- Utilities](critcl\_util\.md)*

  1. *[CriTcl \- C\-level Utilities](critcl\_cutil\.md)*

  1. *[CriTcl \- C\-level Callback Utilities](critcl\_callback\.md)*

  1. *[CriTcl \- Wrap Support \- String/Integer mapping](critcl\_enum\.md)*

  1. *[CriTcl \- Wrap Support \- Bitset en\- and decoding](critcl\_bitmap\.md)*

  1. *[CriTcl \- Wrap Support \- Enum en\- and decoding](critcl\_emap\.md)*

  1. *[CriTcl \- Code Gen \- Constant string pools](critcl\_literals\.md)*

  1. *[CriTcl \- Code Gen \- Tcl Interp Associations](critcl\_iassoc\.md)*

  1. *[CriTcl \- Code Gen \- C Classes](critcl\_class\.md)*

  1. *[CriTcl Application Package
     Reference](critcl\_application\_package\.md)*

  1. *[Guide To The CriTcl Internals](critcl\_devguide\.md)*

# <a name='section9'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section10'></a>Bugs, Ideas, Feedback

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
