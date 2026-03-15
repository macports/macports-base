
[//000000001]: # (critcl\_devguide \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_devguide\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_devguide\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_devguide \- Guide To The CriTcl Internals

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Audience](#section2)

  - [Playing with CriTcl](#section3)

  - [Developing for CriTcl](#section4)

      - [Architecture & Concepts](#subsection1)

      - [Requirements](#subsection2)

      - [Directory structure](#subsection3)

  - [Authors](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

# <a name='section2'></a>Audience

This document is a guide for developers working on CriTcl, i\.e\. maintainers
fixing bugs, extending the package's functionality, etc\.

Please read

  1. *CriTcl \- License*,

  1. *CriTcl \- How To Get The Sources*, and

  1. *CriTcl \- The Installer's Guide*

first, if that was not done already\.

Here we assume that the sources are already available in a directory of the
readers choice, and that the reader not only know how to build and install them,
but also has all the necessary requisites to actually do so\. The guide to the
sources in particular also explains which source code management system is used,
where to find it, how to set it up, etc\.

# <a name='section3'></a>Playing with CriTcl

*Note* that the sources of CriTcl, should the reader have gotten them, also
contain several examples show\-casing various aspects of the system\. These
demonstration packages can all be found in the sub\-directory "examples/" of the
sources\.

Lots of smaller examples can be found in the document *Using CriTcl*, an
introduction to CriTcl by way of a of examples\. These focus more on specific
critcl commands than the overall picture shown by the large examples mentioned
in the previous paragraph\.

# <a name='section4'></a>Developing for CriTcl

## <a name='subsection1'></a>Architecture & Concepts

The system consists of two main layers, as seen in the figure below, plus a
support layer containing general packages the system uses during operation\.

![](\.\./image/architecture\.png)

  1. At the top we have an application built on top of the core packages,
     providing command line access to the second and third usage modes, i\.e\.
     *[Generate Package](\.\./index\.md\#generate\_package)* and *Generate TEA
     Package*\.

       - __[critcl](critcl\.md)__

       - __critcl::app__

  1. Below that is the core package providing the essential functionality of the
     system, plus various utility packages which make common tasks more
     convenient\.

       - __[critcl](critcl\.md)__

       - __[critcl::util](critcl\_util\.md)__

  1. Lastly a layer of supporting packages, mostly external to critcl\.

       - __md5__

         For this pure\-Tcl package to be fast users should get one of several
         possible accelerator packages:

           1) __tcllibc__

           1) __Trf__

           1) __md5c__

       - __cmdline__

       - __platform__

       - __stubs::container__

       - __stubs::reader__

       - __stubs::writer__

       - __stubs::gen__

       - __stubs::gen::init__

       - __stubs::gen::header__

       - __stubs::gen::decl__

       - __stubs::gen::macro__

       - __stubs::gen::slot__

       - __stubs::gen::lib__

## <a name='subsection2'></a>Requirements

To develop for critcl the following packages and applications must be available
in the environment\. These are all used by the __build\.tcl__ helper
application\.

  - __dtplite__

    A Tcl application provided by Tcllib, for the validation and conversion of
    *doctools*\-formatted text\.

  - __dia__

    A Tcl application provided by Tklib, for the validation and conversion of
    __diagram__\-formatted figures into raster images\.

    Do not confuse this with the Gnome __dia__ application, which is a
    graphical editor for figures and diagrams, and completely unrelated\.

  - __fileutil__

    A Tcl package provided by Tcllib, providing file system utilities\.

  - __vfs::mk4__, __vfs__

    Tcl packages written in C providing access to Tcl's VFS facilities, required
    for the generation of critcl starkits and starpacks\.

## <a name='subsection3'></a>Directory structure

  - Helpers

      * "build\.tcl"

        This helper application provides various operations needed by a
        developer for critcl, like regenerating the documentation, the figures,
        building and installing critcl, etc\.

        Running the command like

            ./build.tcl help

        will provide more details about the available operations and their
        arguments\.

  - Documentation

      * "doc/"

        This directory contains the documentation sources, for both the text,
        and the figures\. The texts are written in *doctools* format, whereas
        the figures are written for tklib's __dia__\(gram\) package and
        application\.

      * "embedded/"

        This directory contains the documentation converted to regular manpages
        \(nroff\) and HTML\. It is called embedded because these files, while
        derived, are part of the git repository, i\.e\. embedded into it\. This
        enables us to place these files where they are visible when serving the
        prject's web interface\.

  - Testsuite

      * "test/all\.tcl"

      * "test/testutilities\.tcl"

      * "test/\*\.test"

        These files are a standard testsuite based on Tcl's __tcltest__
        package, with some utility code snarfed from __Tcllib__\.

        This currently tests only some of the __stubs::\*__ packages\.

      * "test/\*\.tcl"

        These files \(except for "all\.tcl" and "testutilities\.tcl"\) are example
        files \(Tcl with embedded C\) which can be run through critcl for testing\.

        *TODO* for a maintainers: These should be converted into a proper test
        suite\.

  - Package Code, General structure

  - Package Code, Per Package

      * __[critcl](critcl\.md)__

          + "lib/critcl/critcl\.tcl"

            The Tcl code implementing the package\.

          + "lib/critcl/Config"

            The configuration file for the standard targets and their settings\.

          + "lib/critcl/critcl\_c/"

            Various C code snippets used by the package\. This directory also
            contains the copies of the Tcl header files used to compile the
            assembled C code, for the major brnaches of Tcl, i\.e\. 8\.4, 8\.5, and
            8\.6\.

      * __[critcl::util](critcl\_util\.md)__

          + "lib/critcl\-util/util\.tcl"

            The Tcl code implementing the package\.

      * __critcl::app__

          + "lib/app\-critcl/critcl\.tcl"

            The Tcl code implementing the package\.

      * __[critcl::iassoc](critcl\_iassoc\.md)__

          + "lib/critcl\-iassoc/iassoc\.tcl"

            The Tcl code implementing the package\.

          + "lib/critcl\-iassoc/iassoc\.h"

            C code template used by the package\.

      * __[critcl::class](critcl\_class\.md)__

          + "lib/critcl\-class/class\.tcl"

            The Tcl code implementing the package\.

          + "lib/critcl\-class/class\.h"

            C code template used by the package\.

      * __stubs::\*__

          + "lib/stubs/\*"

            A set of non\-public \(still\) packages which provide read and write
            access to and represent Tcl stubs tables\. These were created by
            taking the "genStubs\.tcl" helper application coming with the Tcl
            core sources apart along its internal logical lines\.

      * __critclf__

          + "lib/critclf/"

            Arjen Markus' work on a critcl/Fortran\. The code is outdated and has
            not been adapted to the changes in critcl version 3 yet\.

      * __md5__

      * __md5c__

      * __platform__

        These are all external packages whose code has been inlined in the
        repository for easier development \(less dependencies to pull\), and
        quicker deployment from the repository \(generation of starkit and
        \-pack\)\.

        *TODO* for maintainers: These should all be checked against their
        origin for updates and changes since they were inlined\.

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
