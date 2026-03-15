
[//000000001]: # (critcl\_howto\_install \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_howto\_install\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_howto\_install\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_howto\_install \- How To Install CriTcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Install The Requisites](#section2)

      - [Install A Working C Compiler](#subsection1)

      - [Install A Working Tcl Shell](#subsection2)

      - [Install Supporting Tcl Packages](#subsection3)

  - [Install The CriTcl Packages](#section3)

      - [Install On Unix](#subsection4)

      - [Install On Windows](#subsection5)

  - [Test The Installation](#section4)

  - [Authors](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

*[CriTcl](critcl\.md)* is installed in four major steps:

  1. [Install The Requisites](#section2)

  1. Follow the instructions on *[How To Get The CriTcl
     Sources](critcl\_howto\_sources\.md)*

  1. [Install The CriTcl Packages](#section3)

  1. [Test The Installation](#section4)

It is now possible to follow the instructions on *[How To Use
CriTcl](critcl\_howto\_use\.md)*\.

# <a name='section2'></a>Install The Requisites

This major step breaks down into three minor steps:

  1. [Install A Working C Compiler](#subsection1) and development
     environment\.

  1. [Install A Working Tcl Shell](#subsection2)

  1. [Install Supporting Tcl Packages](#subsection3)

## <a name='subsection1'></a>Install A Working C Compiler

While *[CriTcl](critcl\.md)* requires a working C compiler to both install
itself, and to process *[CriTcl](critcl\.md)*\-based packages installing
such is very much out of scope for this document\.

Please follow the instructions for the platform and system
*[CriTcl](critcl\.md)* is to be installed on\.

The important pieces of information are this:

  1. The path to the directory containing the C compiler binary has to be listed
     in the environment variable __PATH__, for *[CriTcl](critcl\.md)*
     to find it\.

  1. On Windows\(tm\) the environment variable __LIB__ has to be present and
     contain the paths of the directories holding Microsoft's libraries\. The
     standard *[CriTcl](critcl\.md)* configuration for this platform
     searches these paths to fine\-tune its settings based on available libraries
     and compiler version\.

Links of interest:

  - [http://www\.tldp\.org/HOWTO/HOWTO\-INDEX/programming\.html](http://www\.tldp\.org/HOWTO/HOWTO\-INDEX/programming\.html)

## <a name='subsection2'></a>Install A Working Tcl Shell

That a working installation of *[CriTcl](critcl\.md)* will require a
working installation of [Tcl](http://core\.tcl\-lang\.org/tcl) should be
obvious\.

Installing Tcl however is out of scope here, same as for installing a working C
compiler\.

There are too many options, starting from [building it from
scratch](http://core\.tcl\-lang\.org/tcl), installing what is provided by the
platform's package manager \([zypper](https://en\.opensuse\.org/Portal:Zypper),
[yum](https://access\.redhat\.com/solutions/9934),
[apt\-get](https://help\.ubuntu\.com/community/AptGet/Howto), and more\), to
using some vendor's [distribution](https://core\.tcl\-lang\.org/dist\.html)\.

A single piece of advice however\.

While *[CriTcl](critcl\.md)* currently supports running on Tcl 8\.4 and
higher, and the creation of packages for the same, the last release for this
version was in 2013 \(9 years ago at the time of writing\)\. Similarly, the last
release for Tcl 8\.5 was in 2016 \(6 years ago\)\. Both are official end of life\.

Given this I recommend to install and use Tcl 8\.6\.

## <a name='subsection3'></a>Install Supporting Tcl Packages

The implementation of *[CriTcl](critcl\.md)* uses and depends on

  1. __cmdline__

Depending on how Tcl was installed this package may be available already without
action, or not\. Invoke the command

    echo 'puts [package require cmdline]' | tclsh

to check if the package is present or not\. If it is present then its version
number will be printed, else the error message __can't find package
cmdline__ or similar\.

If it is not present install the package as per the instructions for the chosen
Tcl installation\.

*Note*, the package __cmdline__ may not exist as its own installable
package\. In such a case check if the chosen Tcl installation provides a
__tcllib__ package and install that\. This should install all the packages in
the Tcllib bundle, including __cmdline__\.

As a last fallback, go to [Tclib](http://core\.tcl\-lang\.org/tcllib) and
follow the instructions to install the bundle from scratch\.

# <a name='section3'></a>Install The CriTcl Packages

Note that this step has different instructions dependent on the platform
*[CriTcl](critcl\.md)* is to be installed on\. In other words, only one of
the sub sections applies, the other can be ignored\.

## <a name='subsection4'></a>Install On Unix

This section offers instructions for installing *[CriTcl](critcl\.md)* on
various kinds of Unix and Unix\-related systems, i\.e\. *Linux*, the various
*BSD*s, etc\. It especially covers *Mac OS X* as well\.

Use the instructions in section [Install On Windows](#subsection5) when
installing on a Windows platform and not using a unix\-like environment as
provided by tools like [MinGW](https://www\.mingw\-w64\.org),
[CygWin](https://www\.cygwin\.com/), [Git For
Windows](https://gitforwindows\.org),
[WSL](https://docs\.microsoft\.com/en\-us/windows/wsl/faq), etc\.

  1. Change the working directory to the top level directory of the
     *[CriTcl](critcl\.md)* checkout obtained by following the instructions
     of *[How To Get The CriTcl Sources](critcl\_howto\_sources\.md)*\.

  1. Verify that the file "build\.tcl" is marked executable\. Make it executable
     if it is not\.

  1. Invoke

    ./build.tcl install

     to perform the installation\.

     *Attention* This command uses default locations for the placement of the
     __[critcl](critcl\.md)__ application, the various packages, and
     header files\.

  1. Invoke

    ./build.tcl dirs

     to see the chosens paths before actually performing the installation\.

  1. Use the options listed below to change the paths used for installation as
     desired\. This is the same method as with __configure__ based packages\.

       - __\-\-prefix__ *path*

         Base path for non\-package files\.

       - __\-\-include\-dir__ *path*

         Destination path for header files\.

       - __\-\-exec\-prefix__ *path*

         Base path for applications and packages\.

       - __\-\-bin\-dir__ *path*

         Destination path for applications\.

       - __\-\-lib\-dir__ *path*

         Destination path for packages\.

     These options are especially necessary in all environments not using the
     semi\-standard "bin", "lib", "include" locations from __configure__\.

     As an example of such environments, Ubuntu \(and possibly Debian\) expect Tcl
     packages to be installed into the "/usr/share/tcltk" directory, therefore
     requiring the use of

    --lib-dir /usr/share/tcltk

     for proper installation\.

*Note* that this guide neither covers the details of the __install__
method, nor does it cover any of the other methods available through the
__build\.tcl__ tool of *[CriTcl](critcl\.md)*\. These can be found in the
*[CriTcl build\.tcl Tool Reference](critcl\_build\.md)*\.

## <a name='subsection5'></a>Install On Windows

This section offers instructions for installing *[CriTcl](critcl\.md)* on a
Windows \(tm\) host\. *Note* that environments as provided by tools like
[MinGW](https://www\.mingw\-w64\.org), [CygWin](https://www\.cygwin\.com/),
[Git For Windows](https://gitforwindows\.org),
[WSL](https://docs\.microsoft\.com/en\-us/windows/wsl/faq), etc\. are classed as
Unix\-like, and the instructions in section [Install On Unix](#subsection4)
apply\.

  1. In a DOS box, change the working directory to the top level directory of
     the *[CriTcl](critcl\.md)* checkout obtained by following the
     instructions of *[How To Get The CriTcl
     Sources](critcl\_howto\_sources\.md)*\.

  1. In the same DOS box, invoke

    tclsh.exe ./build.tcl install

     to perform the installation\.

     *Attention* This command uses default locations for the placement of the
     __[critcl](critcl\.md)__ application, the various packages, and
     header files\.

  1. Invoke

    tclsh.exe ./build.tcl dirs

     to see the chosens paths before actually performing the installation\.

  1. Use the options listed below to change the paths used for installation as
     desired\. This is the same method as with __configure__ based packages\.

       - __\-\-prefix__ *path*

         Base path for non\-package files\.

       - __\-\-include\-dir__ *path*

         Destination path for header files\.

       - __\-\-exec\-prefix__ *path*

         Base path for applications and packages\.

       - __\-\-bin\-dir__ *path*

         Destination path for applications\.

       - __\-\-lib\-dir__ *path*

         Destination path for packages\.

*Attention\!* The current installer does not put an extension on the
__[critcl](critcl\.md)__ application\. This forces users to either
explicitly choose the __tclsh__ to run the application, or manually rename
the installed file to "critcl\.tcl"\. The latter assumes that an association for
"\.tcl" is available, to either __tclsh__, or __wish__\.

*Note* that this guide neither covers the details of the __install__
method, nor does it cover any of the other methods available through the
__build\.tcl__ tool of *[CriTcl](critcl\.md)*\. These can be found in the
*[CriTcl build\.tcl Tool Reference](critcl\_build\.md)*\.

# <a name='section4'></a>Test The Installation

Installing *[CriTcl](critcl\.md)* contains an implicit test of its
functionality\.

One of its operation modes uses the MD5 hash internally to generate unique ids
for sources, as a means of detecting changes\. To make generation of such hashes
fast a *[CriTcl](critcl\.md)*\-based package for MD5 is installed as part of
the main installation process\.

In other words, after installing the core packages of
*[CriTcl](critcl\.md)* this partial installation is used to build the rest\.

This is possible because building a package from
*[CriTcl](critcl\.md)*\-based sources is the operation mode not using MD5,
therefore there is no circular dependency\.

For our purposes this however is also a self\-test of the system, verifying that
the core of *[CriTcl](critcl\.md)* works, as well as the C compiler\.

For additional testing simply move on to section __The First Package__ of
the guide on *[How To Use CriTcl](critcl\_howto\_use\.md)*\.

# <a name='section5'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section6'></a>Bugs, Ideas, Feedback

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
