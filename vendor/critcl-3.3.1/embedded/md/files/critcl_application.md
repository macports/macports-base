
[//000000001]: # (critcl\_application \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_application\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_application\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_application \- CriTcl Application Reference

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Application Options](#section2)

  - [Package Structure](#section3)

  - [Authors](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__[critcl](critcl\.md)__ ?*option*\.\.\.? ?*file*\.\.\.?](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __[critcl](critcl\.md)__
command\. Its intended audience are people having to build packages using
__[critcl](critcl\.md)__ for deployment\. Writers of packages with
embedded C code can ignore this document\. If you are in need of an overview of
the whole system instead, please go and read the *[Introduction To
CriTcl](critcl\.md)*\.

This application resides in the Application Layer of CriTcl\.

![](\.\./image/arch\_application\.png)\. The application supports the following
general command line:

  - <a name='1'></a>__[critcl](critcl\.md)__ ?*option*\.\.\.? ?*file*\.\.\.?

    The exact set of options supported, their meaning, and interaction is
    detailed in section [Application Options](#section2) below\. For a
    larger set of examples please see section "Building CriTcl Packages" in the
    document about *Using CriTcl*\.

# <a name='section2'></a>Application Options

The following options are understood:

  - __\-v__

  - __\-\-version__

    Print the version to __stdout__ and exit\.

  - __\-I__ path

    Arranges for the compiler to search *path* for headers\. Uses of this
    option are cumulative\. Ignored when generating a TEA package \(see option
    __\-tea__ below\)\.

  - __\-L__ path

    Arranges for the linker to search *path*\. Uses of this option are
    cumulative\. Ignored when generating a TEA package \(see option __\-tea__
    below\)\.

  - __\-cache__ path

    Sets *path* as the directory to use as the result cache\. The default is
    "~/\.critcl/<platform>", or "~/\.critcl/<pid>\.<epoch>" when generating a
    package\. See option __\-pkg__, below\. Ignored when generating a TEA
    package \(see option __\-tea__ below\)\.

  - __\-clean__

    Arranges for all files and directories in the result cache to be deleted
    before compilation begins\.

    Ignored when generating a package because this mode starts out with a unique
    and empty result cache\. See option __\-pkg__, below\. Ignored when
    generating a TEA package \(see option __\-tea__ below\)\.

  - __\-config__ path

    Provides a custom configuration file\. By default a configuration included in
    the system core is used\. When specified multiple times the last value is
    used\. Ignored when generating a TEA package \(see option __\-tea__ below\)\.

  - __\-debug__ mode

    Activates one of the following debugging modes:

      * __memory__

        Track and report memory allocations made by the Tcl core\.

      * __symbols__

        Compile all "\.c" files with debugging symbols\.

      * __all__

        Both __memory__ and __symbols__\.

    Ignored when generating a TEA package \(see option __\-tea__ below\)\. Uses
    of this option are cumulative\.

  - __\-disable__ name

    Sets the value of the custom build configuration option *name* to
    __false__\. It is equivalent to "\-with\-*name* 0"\. Validated only if one
    of the input files for the *CriTcl script* actually defines and uses a
    custom build configuration option with that *name*\. Ignored when
    generating a TEA package \(see option __\-tea__ below\)\.

  - __\-enable__ name

    Sets the value of the custom build configuration option *name* to
    __true__\. It is equivalent to "\-with\-*name* 1"\. Validated only if one
    of the input files for the *CriTcl script* actually defines and uses a
    custom build configuration option with that *name*\. Ignored when
    generating a TEA package \(see option __\-tea__ below\)\.

  - __\-force__

    Forces compilation even if a shared library for the file already exists\.
    Unlike cleaning the cache, this is lazy in the destruction of files and only
    affects relevant files\.

    Ignored when generating a package \(see option __\-pkg__, below\), which
    starts out with a unique and empty result cache\. Ignored when generating a
    TEA package \(see option __\-tea__ below\)\.

  - __\-help__

    Prints a short description of command line syntax and options and then exits
    the application\.

  - __\-keep__

    Causes the system to cache compiled "\.c" files\. Also prevents the deletion
    of the unique result cache used by the run when generating a package \(see
    option __\-pkg__ below\), Intended for debugging of
    __[critcl](critcl\.md)__ itself, where it may be necessary to inspect
    the generated C code\. Ignored when generating a TEA package \(see option
    __\-tea__ below\)\.

  - __\-libdir__ directory

    Adds *directory* to the list of directories the linker searches for
    libraries in \(like __\-L__\)\. With __\-pkg__, generated packages are
    saved in *directory*\. When specified multiple times the last value is
    used\. The default is "lib", resolved relative to the current working
    directory\.

  - __\-includedir__ directory

    Adds *directory* to the list of directories the compiler searches for
    headers in\. With __\-pkg__, generated header files are saved in
    *directory*\. Uses of this option are cumulative\. The last value is used as
    the destination for generated header files\. The default is the relative
    directory "include", resolved relative to the current working directory\.
    Ignored when generating a TEA package \(see option __\-tea__ below\)\.

  - __\-pkg__

    Generates a package from the *CriTcl script* files\. Input files are
    processed first as usual, but are then bundled into a single library, with
    additional generated files to form the library into a standard Tcl package\.

    generation\. If both options, i\.e\. __\-pkg__ and __\-tea__ are
    specified the last one specified wins\.

    Options __\-clean__ and __\-force__ are ignored\. __\-libdir__ is
    relevant in both this and __\-tea__ mode\.

    The basename of the first file is the name of the package to generate\. If
    its file extension indicates a shared library \("\.so", "\.sl", "\.dylib", and
    "\.dll"\) it is also removed from the set of input files\. Each *CriTcl
    script* file is kept as part of the input\. A single file without a suffix
    is assumed to be a *CriTcl script*\. A file without a suffix, but other
    input files following is treated like the name of a shared library proper,
    and removed from the set of input files\.

    Examples:

        ... -pkg ... foo

        => Package name is: foo
        => Input file is:   foo.tcl

        ... -pkg ... foo bar.tcl

        => Package name is: foo
        => Input file is:   bar.tcl

        ... -pkg ... foo.tcl

        => Package name is: foo
        => Input file is:   foo.tcl

        ... -pkg ... foo.so bar.tcl

        => Package name is: foo
        => Input file is:   bar.tcl

  - __\-show__

    Prints the configuration of the chosen target to __stdout__ and then
    exits\. Set __\-target__, below\.

  - __\-showall__

    Prints the whole chosen configuration file to __stdout__ and then exits\.
    See __\-config__, above\.

  - __\-target__ name

    Overrides the default choice of build target\. Only the last occurrence of
    this option is used\. The named target must exist in the chosen configuration
    file\. Use __\-targets__ \(see below\) to get a list of the acceptable
    targets\. Use __\-config__ to select the configuration file\. Ignored when
    generating a TEA package \(see option __\-tea__ below\)\.

  - __\-targets__

    Prints the list of all known targets from the chosen configuration file to
    __stdout__ and then exits\. Use __\-config__ to select the
    configuration file\.

  - __\-tea__

    Like __\-pkg__, except no binaries are generated\. Creates a directory
    hierarchy containing the *CriTcl script*, its companion files, and a
    TEA\-conformant build system with most of the needed support code, including
    copies of the critcl packages\.

    If both __\-pkg__ and __\-tea__ are specified the last occurrence
    wins\.

    __\-I__, __\-L__, __\-clean__, __\-force__, __\-cache__,
    __\-includedir__, __\-enable__, __\-disable__, and
    __\-with\-__FOO____ are ignored\. In contrast, the option
    __\-libdir__ is relevant in both this and __\-pkg__ mode\.

    The basename of the first file is the name of the package to generate\. If
    its file extension indicates a shared library \("\.so", "\.sl", "\.dylib", and
    "\.dll"\) it is also removed from the set of input files\. Each *CriTcl
    script* file is kept as part of the input\. A single file without a suffix
    is assumed to be a *CriTcl script*\. A file without a suffix, but other
    input files following is treated like the name of a shared library proper,
    and removed from the set of input files\.

    Examples:

        ... -tea ... foo

        => Package name is: foo
        => Input file is:   foo.tcl

        ... -tea ... foo bar.tcl

        => Package name is: foo
        => Input file is:   bar.tcl

        ... -tea ... foo.tcl

        => Package name is: foo
        => Input file is:   foo.tcl

        ... -tea ... foo.so bar.tcl

        => Package name is: foo
        => Input file is:   bar.tcl

  - __\-with\-__name____ value

    This option sets the value of the custom build configuration option *name*
    to *value*\.

    The information is validated only if one of the "\.critcl" input files
    actually defines and uses a custom build configuration option with that
    *name*\. Ignored when generating a TEA package \(see option __\-tea__
    below\)\.

# <a name='section3'></a>Package Structure

Packages generated by critcl have the following basic structure:

    <TOP>
    +- pkgIndex.tcl
    +- critcl-rt.tcl
    +- license.terms (optional)
    |
    +- tcl (optional)
    |  +- <tsources files>
    |
    +- <platform>
       +- <shared library>

*Notes*

  1. The file "pkgIndex\.tcl" is the standard package index file expected by
     Tcl's package management\. It is sourced during a search for packages, and
     declares the package to Tcl with its files, and how to handle them\.

  1. The file "critcl\-rt\.tcl" is a helper file containing the common code used
     by "pkgIndex\.tcl" to perform its tasks\.

  1. The file "license\.terms" is optional and appears only if the "\.critcl" file
     the package is generated from used the command __critcl::license__ to
     declare package author and license\.

  1. All files declared with the command __critcl::tsources__ are put into
     the sub\-directory "tcl"\.

  1. The shared library generated by critcl is put into a platform\-specific
     sub\-directory\.

The whole structure, and especially the last point, enable us to later merge the
results \(for the same package, and version\) for multiple target platforms into a
single directory structure without conflict, by simply copying the top
directories over each other\. The only files which can conflict are in the <TOP>
and "tcl" directories, and for these we know that they are identical across
targets\. The result of such a merge would look like:

    <TOP>
    +- pkgIndex.tcl
    +- critcl-rt.tcl
    +- license.terms (optional)
    |
    +- tcl (optional)
    |  +- <tsources files>
    |
    +- <platform1>
    |  +- <shared library1>
    +- <platform2>
    |  +- <shared library2>
    ...
    +- <platformN>
       +- <shared libraryN>

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
