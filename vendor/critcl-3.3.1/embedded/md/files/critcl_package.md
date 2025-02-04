
[//000000001]: # (critcl\_package \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_package\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_package\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_package \- CriTcl Package Reference

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Embedded C Code](#subsection1)

      - [Stubs Table Management](#subsection2)

      - [Package Meta Data](#subsection3)

      - [Control & Interface](#subsection4)

      - [Introspection](#subsection5)

      - [Build Management](#subsection6)

      - [Result Cache Management](#subsection7)

      - [Build Configuration](#subsection8)

      - [Tool API](#subsection9)

      - [Advanced: Embedded C Code](#subsection10)

      - [Custom Build Configuration](#subsection11)

      - [Advanced: Location management](#subsection12)

      - [Advanced: Diversions](#subsection13)

      - [Advanced: File Generation](#subsection14)

  - [Concepts](#section3)

      - [Modes Of Operation/Use](#subsection15)

      - [Runtime Behaviour](#subsection16)

      - [File Mapping](#subsection17)

      - [Result Cache](#subsection18)

      - [Preloading functionality](#subsection19)

      - [Configuration Internals](#subsection20)

      - [Stubs Tables](#subsection21)

  - [Examples](#section4)

  - [Authors](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.3\.1?  
package require platform ?1\.0\.2?  
package require md5 ?2?  

[__::critcl::ccode__ *fragment*](#1)  
[__::critcl::ccommand__ *tclname* *cname*](#2)  
[__::critcl::ccommand__ *tclname* *arguments* *body* ?*option* *value*\.\.\.?](#3)  
[__::critcl::cdata__ *tclname* *data*](#4)  
[__::critcl::cconst__ *tclname* *resulttype* *value*](#5)  
[__::critcl::cdefines__ *list of glob patterns* ?*namespace*?](#6)  
[__::critcl::cproc__ *name* *arguments* *resulttype* *body* ?*option* *value*\.\.\.?](#7)  
[__::critcl::cproc__ *name* *arguments* *resulttype*](#8)  
[__::critcl::cinit__ *text* *externals*](#9)  
[__::critcl::include__ *path*](#10)  
[__::critcl::api__ __import__ *name* *version*](#11)  
[__::critcl::api__ __function__ *resulttype* *name* *arguments*](#12)  
[__::critcl::api__ __header__ ?*glob pattern*\.\.\.?](#13)  
[__::critcl::api__ __extheader__ ?*file*\.\.\.?](#14)  
[__::critcl::license__ *author* ?*text*\.\.\.?](#15)  
[__::critcl::summary__ *text*](#16)  
[__::critcl::description__ *text*](#17)  
[__::critcl::subject__ ?*key*\.\.\.?](#18)  
[__::critcl::meta__ *key* ?*word*\.\.\.?](#19)  
[__::critcl::meta?__ *key*](#20)  
[__::critcl::buildrequirement__ *script*](#21)  
[__::critcl::cheaders__ ?*arg*\.\.\.?](#22)  
[__::critcl::csources__ ?*glob pattern*\.\.\.?](#23)  
[__::critcl::clibraries__ ?*glob pattern*\.\.\.?](#24)  
[__::critcl::source__ *glob pattern*](#25)  
[__::critcl::tsources__ *glob pattern*\.\.\.](#26)  
[__::critcl::owns__ *glob pattern*\.\.\.](#27)  
[__::critcl::cflags__ ?*arg*\.\.\.?](#28)  
[__::critcl::ldflags__ ?*arg*\.\.\.?](#29)  
[__::critcl::framework__ ?*arg*\.\.\.?](#30)  
[__::critcl::tcl__ *version*](#31)  
[__::critcl::tk__](#32)  
[__::critcl::preload__ *lib*\.\.\.](#33)  
[__::critcl::debug__ *area*\.\.\.](#34)  
[__::critcl::check__ ?*label*? *text*](#35)  
[__::critcl::checklink__ ?*label*? *text*](#36)  
[__::critcl::msg__ ?__\-nonewline__? *msg*](#37)  
[__::critcl::print__ ?__\-nonewline__? ?*chan*? *msg*](#38)  
[__::critcl::compiled__](#39)  
[__::critcl::compiling__](#40)  
[__::critcl::done__](#41)  
[__::critcl::failed__](#42)  
[__::critcl::load__](#43)  
[__::critcl::config__ *option* ?*val*?](#44)  
[__::critcl::cache__ ?path?](#45)  
[__::critcl::clean\_cache__ ?*pattern*\.\.\.?](#46)  
[__::critcl::readconfig__ *path*](#47)  
[__::critcl::showconfig__ ?*chan*?](#48)  
[__::critcl::showallconfig__ ?*chan*?](#49)  
[__::critcl::chooseconfig__ *target* ?*nomatcherr*?](#50)  
[__::critcl::setconfig__ *target*](#51)  
[__::critcl::actualtarget__](#52)  
[__::critcl::buildforpackage__ ?*flag*?](#53)  
[__::critcl::cnothingtodo__ *file*](#54)  
[__::critcl::cresults__ ?*file*?](#55)  
[__::critcl::crosscheck__](#56)  
[__::critcl::error__ *msg*](#57)  
[__::critcl::knowntargets__](#58)  
[__::critcl::sharedlibext__](#59)  
[__::critcl::targetconfig__](#60)  
[__::critcl::buildplatform__](#61)  
[__::critcl::targetplatform__](#62)  
[__::critcl::cobjects__ ?*glob pattern*\.\.\.?](#63)  
[__::critcl::scan__ *path*](#64)  
[__::critcl::name2c__ *name*](#65)  
[__::critcl::argnames__ *arguments*](#66)  
[__::critcl::argcnames__ *arguments*](#67)  
[__::critcl::argcsignature__ *arguments*](#68)  
[__::critcl::argvardecls__ *arguments*](#69)  
[__::critcl::argconversion__ *arguments* ?*n*?](#70)  
[__::critcl::argoptional__ *arguments*](#71)  
[__::critcl::argdefaults__ *arguments*](#72)  
[__::critcl::argsupport__ *arguments*](#73)  
[__::critcl::userconfig__ __define__ *name* *description* *type* ?*default*?](#74)  
[__::critcl::userconfig__ __query__ *name*](#75)  
[__::critcl::userconfig__ __set__ *name* *value*](#76)  
[__::critcl::at::caller__](#77)  
[__::critcl::at::caller__ *offset*](#78)  
[__::critcl::at::caller__ *offset* *level*](#79)  
[__::critcl::at::here__](#80)  
[__::critcl::at::get\*__](#81)  
[__::critcl::at::get__](#82)  
[__::critcl::at::=__ *file* *line*](#83)  
[__::critcl::at::incr__ *n*\.\.\.](#84)  
[__::critcl::at::incrt__ *str*\.\.\.](#85)  
[__::critcl::at::caller\!__](#86)  
[__::critcl::at::caller\!__ *offset*](#87)  
[__::critcl::at::caller\!__ *offset* *level*](#88)  
[__::critcl::at::here\!__](#89)  
[__::critcl::collect\_begin__](#90)  
[__::critcl::collect\_end__](#91)  
[__::critcl::collect__ *script*](#92)  
[__::critcl::make__ *path* *contents*](#93)  
[__::preload__ *library*](#94)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

The __[critcl](critcl\.md)__ package is the core of the system\. For an
overview of the complete system, see *[Introduction To
CriTcl](critcl\.md)*\. For the usage of the standalone
__[critcl](critcl\.md)__ program, see *CriTcl Application*\. This core
package maybe be used to embed C code into Tcl scripts\. It also provides access
to the internals that other parts of the core use and which are of interest to
those wishing to understand the internal workings of the core and of the API it
provides to the *CriTcl Application*\. These advanced sections are marked as
such so that those simply wishing to use the package can skip them\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

A short note ahead of the documentation: Instead of repeatedly talking about "a
Tcl script with embbedded C code", or "a Tcl script containing CriTcl commands",
we call such a script a *CriTcl script*\. A file containing a *CriTcl script*
usually has the extension __\.tcl__ or __\.critcl__\.

## <a name='subsection1'></a>Embedded C Code

The following commands append C code fragments to the current module\. Fragments
appear in the module in the order they are appended, so the earlier fragments
\(variables, functions, macros, etc\.\) are visible to later fragments\.

  - <a name='1'></a>__::critcl::ccode__ *fragment*

    Appends the C code in *fragment* to the current module and returns the
    empty string\. See [Runtime Behaviour](#subsection16)\.

  - <a name='2'></a>__::critcl::ccommand__ *tclname* *cname*

    As documented below, except that *cname* is the name of a C function that
    already exists\.

  - <a name='3'></a>__::critcl::ccommand__ *tclname* *arguments* *body* ?*option* *value*\.\.\.?

    Appends the code to create a Tcl command named *tclname* and a
    corresponding C function whose body is *body* and which behaves as
    documented for Tcl's own
    [Tcl\_CreateObjCommand](https://www\.tcl\-lang\.org/man/tcl/TclLib/CrtObjCmd\.htm)\.

    *aguments* is a list of zero to four names for the standard arguments
    __clientdata__, __interp__, __objc__, and __objv__\. The
    standard default names are used in place of any missing names\. This is a
    more low\-level way than __critcl::cproc__ to define a command, as
    processing of the items in __objv__ is left to the author, affording
    complete control over the handling of the arguments to the command\. See
    section [Runtime Behaviour](#subsection16)\.

    Returns the empty string\.

    Each *option* may be one of:

      * __\-clientdata__ *c\-expression*

        Provides the client data for the new command\. __NULL__ by default\.

      * __\-delproc__ *c\-expression*

        Provides a function pointer of type
        [Tcl\_CmdDeleteProc](https://www\.tcl\-lang\.org/man/tcl/TclLib/CrtObjCmd\.htm)
        as the deletion function for the new command\. __NULL__ by default\.

      * __\-cname__ *boolean*

        If __false__ \(the default\), a name for the corresponding C function
        is automatically derived from the fully\-qualified *tclname*\.
        Otherwise, name of the C function is the last component of *tclname*\.

  - <a name='4'></a>__::critcl::cdata__ *tclname* *data*

    Appends the code to create a new Tcl command named *tclname* which returns
    *data* as a __ByteArray__ result\.

    Returns the empty string\.

  - <a name='5'></a>__::critcl::cconst__ *tclname* *resulttype* *value*

    Appends the code to create a new Tcl command named *tclname* which returns
    the constant *value* having the Tcl type *resulttype*\. *value* can be
    a C macro or a function *call* \(including the parentheses\) to any visible
    C function that does not take arguments\. Unlike __critcl::cdata__,
    *resulttype* can be any type known to __critcl::cproc__\. Its semantics
    are equivalent to:

        cproc $tclname {} $resulttype "return $value ;"

    This is more efficient than __critcl::cproc__ since there is no C
    function generated\.

    Returns the empty string\.

  - <a name='6'></a>__::critcl::cdefines__ *list of glob patterns* ?*namespace*?

    Arranges for *C enum* and *\#define* values that match one of the
    patterns in *glob patterns* to be created in the namespace *namespace*,
    each variable having the same as the corresponding C item\. The default
    namespace is the global namespace\. A pattern that matches nothing is
    ignored\.

    The Tcl variables are created when the module is compiled, using the
    preprocessor in order to properly find all matching C definitions\.

    Produces no C code\. The desired C definitions must already exist\.

  - <a name='7'></a>__::critcl::cproc__ *name* *arguments* *resulttype* *body* ?*option* *value*\.\.\.?

    Appends a function having *body* as its body, another shim function to
    perform the needed conversions, and the code to create a corresponding Tcl
    command named *tclname*\. Unlike __critcl::ccommand__ the arguments and
    result are typed, and CriTcl generates the code to convert between Tcl\_Obj
    values and C data types\. See also [Runtime Behaviour](#subsection16)\.

    Returns the empty string\.

      * string *option*

        Each may be one of:

          + __\-cname__ *boolean*

            If __false__ \(the default\), a name for the corresponding C
            function is automatically derived from the fully\-qualified
            *tclname*\. Otherwise, name of the C function is the last component
            of *tclname*\.

          + __\-pass\-cdata__ *boolean*

            If __false__ \(the default\), the shim function performing the
            conversion to and from Tcl level does not pass the ClientData as the
            first argument to the function\.

          + __\-arg\-offset__ *int*

            A non\-negative integer, __0__ by default, indicating the number
            of hidden arguments preceding the actual procedure arguments\. Used
            by higher\-order code generators where there are prefix arguments
            which are not directly seen by the function but which influence
            argument counting and extraction\.

      * string *resulttype*

        May be a predefined or a custom type\. See *[CriTcl cproc Type
        Reference](critcl\_cproc\.md)* for the full list of predefined types
        and how to extend them\. Unless otherwise noted, the Tcl return code is
        always __TCL\_OK__\.

      * list *arguments*

        Is a multi\-dictionary where each key is an argument type and its value
        is the argument name\. For example:

            int x int y

        Each argument name must be a valid C identifier\.

        If the name is a list containing two items, the first item is the name
        and the second item is the default value\. A limited form of variadic
        arguments can be accomplished using such default values\. For example:

            int {x 1}

        Here *x* is an optional argument of type __int__ with a default
        value of __1__\.

        Argument conversion is completely bypassed when the argument is not
        provided, so a custom converter doing validation does not get the chance
        to validate the default value\. In this case, the value should be checked
        in the body of the function\.

        Each argument type may be a predefined or custom type\. See *[CriTcl
        cproc Type Reference](critcl\_cproc\.md)* for the full list of
        predefined types and how to extend them\.

  - <a name='8'></a>__::critcl::cproc__ *name* *arguments* *resulttype*

    As documented below, but used when the C function named *name* already
    exists\.

  - <a name='9'></a>__::critcl::cinit__ *text* *externals*

    Appends the C code in *text* and *externals*, but only after all the
    other fragments appended by the previously\-listed commands regardless of
    their placement in the *CriTcl script* relative to this command\. Thus, all
    their content is visible\. See also [Runtime Behaviour](#subsection16)\.

    The C code in *text* is placed into the body of the initialization
    function of the shared library backing the *CriTcl script*, and is
    executed when this library is loaded into the interpreter\. It has access to
    the variable __Tcl\_Interp\* interp__ referencing the Tcl interpreter
    currently being initialized\.

    *externals* is placed outside and just before the initialization function,
    making it a good place for any external symbols required by initialization
    function, but which should not be accessible by any other parts of the C
    code\.

    Calls to this command are cumulative\.

    Returns the empty string\.

  - <a name='10'></a>__::critcl::include__ *path*

    This command is a convenient shorthand for

        critcl::code {
          #include <${path}>
        }

## <a name='subsection2'></a>Stubs Table Management

CriTcl versions 3 and later provide __critcl::api__ to create and manipulate
stubs tables, Tcl's dynamic linking mechanism handling the resolution of symbols
between C extensions\. See
[http://wiki\.tcl\-lang\.org/285](http://wiki\.tcl\-lang\.org/285) for an
introduction, and section [Stubs Tables](#subsection21) for the details of
CriTcl's particular variant\.

Importing stubs tables, i\.e\. APIs, from another extension:

  - <a name='11'></a>__::critcl::api__ __import__ *name* *version*

    Adds the following include directives into the *CriTcl script* *and*
    each of its companion "\.c" files:

      1. \#include <__name__/__name__Decls\.h>

      1. \#include <__name__/__name__StubLib\.h>

    Returns an error if "__name__" isn't in the search path for the
    compiler\. See __critcl::cheaders__ and the critcl application's
    __\-I__ and __\-includedir__ options\.

    *Important:* If __name__ is a fully\-qualified name in a non\-global
    namespace, e\.g\. "c::stack", the namespace separators "::" are converted into
    underscores \("\_"\) in path names, C code, etc\.

    __name__/__name__Decls\.h contains the stubs table type declarations,
    mapping macros, etc\., and may include package\-specific headers\. See
    __critcl::api header__, below\. An *\#include* directive is added at the
    beginning of the generated code for *CriTcl script* and at the beginning
    of each of its companion "\.c" files\.

    __name__/__name__StubLib\.h contains the stubs table variable
    definition and the function to initialize it\. An *\#include* directive for
    it is added to the initialization code for the *CriTcl script* , along
    with a call to the initializer function\.

    If "__name__/__name__\.decls" accompanies
    __name__/__name__Decls\.h, it should contain the external
    representation of the stubs table used to generate the headers\. The file is
    read and the internal representation of the stubs table returned for use by
    the importing package\. Otherwise, the empy string is returned\.

    One possible use would be the automatic generation of C code calling on the
    functions listed in the imported API\.

    When generating a TEA package the names of the imported APIs are used to
    declare __configure__ options with which the user can declare a
    non\-standard directory for the headers of the API\. Any API __name__ is
    translated into a single configure option
    __\-\-with\-__name__\-include__\.

Declaration and export of a stubs table, i\.e\. API, for the *CriTcl script*:

  - <a name='12'></a>__::critcl::api__ __function__ *resulttype* *name* *arguments*

    Adds to the public API of the *CriTcl script* the signature for the
    function named *name* and having the signature specified by *arguments*
    and *resulttype*\. Code is generated for a "\.decls" file, the corresponding
    public headers, and a stubs table usable by __critcl::api import__\.

    *arguments* is a multidict where each key is an argument type and its
    value is the argument name, and *resulttype* is a C type\.

  - <a name='13'></a>__::critcl::api__ __header__ ?*glob pattern*\.\.\.?

    Each file matching a *glob pattern* is copied into the directory
    containing the generated headers, and an *\#include* directive for it is
    added to "Decls\.h" for the *CriTcl script*\. Returns an error if a *glob
    pattern* matches nothing\.

    A pattern for a relative path is resolved relative to the directory
    containing the *CriTcl script*\.

  - <a name='14'></a>__::critcl::api__ __extheader__ ?*file*\.\.\.?

    Like __::critcl::api header__, but each *file* should exist in the
    external development environment\. An *\#include* directive is added to
    "__foo__Decls\.h", but *file* is not copied to the package header
    directory\. *file* is not a glob pattern as CriTcl has no context, i\.e
    directory, in which to expand such patterns\.

As with the headers for an imported API, an *\#include* directive is added to
the generated code for the *CriTcl script* and to each companion "\.c" file\.

In "compile & run" mode the generated header files and any companion headers are
placed in the [Result Cache](#subsection18) subdirectory for the *CriTcl
script*\. This directory is added to the include search path of any other
package importing this API and and building in mode "compile & run"\.

In "generate package" mode __\-includedir__ specifies the subdirectory in the
package to place the generated headers in\. This directory is added to the search
paths for header files, ensuring that a package importing an API finds it if the
package exporting that API used the same setting for __\-includedir__\.

In "generate TEA" mode the static scanner recognizes __critcl::api header__
as a source of companion files\. It also uses data from calls to __critcl::api
import__ to add support for __\-\-with\-__foo__\-include__ options into
the generated "configure\(\.in\)" so that a user may specify custom locations for
the headers of any imported API\.

## <a name='subsection3'></a>Package Meta Data

CriTcl versions 3 and later can create TEApot meta\-data to be placed into
"teapot\.txt" in a format suitable for use by the [TEApot
tools](http://docs\.activestate\.com/activetcl/8\.5/tpm/toc\.html)\.

In version 2, some meta data support was already present through
__::critcl::license__, but this was only used to generate "license\.txt"\.

  - <a name='15'></a>__::critcl::license__ *author* ?*text*\.\.\.?

    Ignored in "compile & run" mode\.

    In "generate package" mode provides information about the author of the
    package and the license for the package\.

    *text* arguments are concatenated to form the text of the license, which
    is written to "license\.terms" in the same directory as "pkgIndex\.tcl"\. If no
    *text* is provided the license is read from "license\.terms" in the same
    directory as the *CriTcl script*\.

    This information takes precedence over any information specified through the
    generic API __::critcl::meta__\. It is additionally placed into the meta
    data file "teapot\.txt" under the keys *as::author* and *license*\.

  - <a name='16'></a>__::critcl::summary__ *text*

    Ignored in "compile & run" mode\.

    In "generate package" mode places a short, preferably one\-line description
    of the package into the meta data file "teapot\.txt" under the key
    *summary*\. This information takes precedence over information specified
    through the generic API __::critcl::meta__\.

  - <a name='17'></a>__::critcl::description__ *text*

    Ignored in "compile & run" mode\.

    In "generate package" mode places a longer description of the package into
    the meta data file "teapot\.txt", under the key *description*\. The data
    specified by this command takes precedence over any information specified
    through the generic API __::critcl::meta__\.

  - <a name='18'></a>__::critcl::subject__ ?*key*\.\.\.?

    Ignored in "compile & run" mode\.

    In "generate package" mode places each *key* into the meta data file
    "teapot\.txt", under the key *subject*\. This information takes precedence
    over any information specified through the generic API
    __::critcl::meta__\.

    Calls to this command are cumulative\.

  - <a name='19'></a>__::critcl::meta__ *key* ?*word*\.\.\.?

    Provides arbitrary meta data outside of the following reserved keys:
    *as::author*, *as::build::date*, *description*, *license*, *name*,
    *platform*, *require* *subject*, *summary*, and *version*, Its
    behaviour is like __::critcl::subject__ in that it treats all keys as
    list of words, with each call providing one or more words for the key, and
    multiple calls extending the data for an existing key, if not reserved\.

    While it is possible to declare information for one of the reserved keys
    with this command such data is ignored when the final meta data is assembled
    and written\.

    Use the commands __::critcl::license__, __::critcl::summary__,
    __::critcl::description__ __::critcl::subject__, __package
    require__, and __package provide__ to declare data for the reserved
    keys\.

    The information for the reserved keys *as::build::date* and *platform*
    is automatically generated by __[critcl](critcl\.md)__ itself\.

  - <a name='20'></a>__::critcl::meta?__ *key*

    Returns the value in the metadata associated with *key*\.

    Used primarily to retrieve the name of the package from within utility
    packages having to adapt C code templates to their environment\. For example,
    __[critcl::class](critcl\_class\.md)__ uses does this\.

  - <a name='21'></a>__::critcl::buildrequirement__ *script*

    Provides control over the capturing of dependencies declared via __package
    require__\. *script* is evaluated and any dependencies declared within
    are ignored, i\.e\. not recorded in the meta data\.

## <a name='subsection4'></a>Control & Interface

These commands control the details of compilation and linking a *CriTcl
script*\. The information is used only to compile/link the object for the
*CriTcl script*\. For example, information for "FOO\.tcl" is kept separate from
information for "BAR\.tcl"\.

  - <a name='22'></a>__::critcl::cheaders__ ?*arg*\.\.\.?

    Provides additional header locations\.

    Each argument is a glob pattern\. If an argument begins with __\-__ it is
    an argument to the compiler\. Otherwise the parent directory of each matching
    path is a directory to be searched for header files\. Returns an error if a
    pattern matches no files\. A pattern for a relative path is resolved relative
    to the directory containing the *CriTcl script*\.

    __\#include__ lines are not automatically generated for matching header
    files\. Use __critcl::include__ or __critcl::ccode__ as necessary to
    add them\.

    Calls to this command are cumulative\.

  - <a name='23'></a>__::critcl::csources__ ?*glob pattern*\.\.\.?

    Matching paths become inputs to the compilation of the current object along
    with the sources for the current *CriTcl script*\. Returns an error if no
    paths match a pattern\. A pattern for a relative path is resolved relative to
    the directory containing the *CriTcl script*\.

    Calls to this command are cumulative\.

  - <a name='24'></a>__::critcl::clibraries__ ?*glob pattern*\.\.\.?

    provides the link step with additional libraries and library locations\. A
    *glob pattern* that begins with __\-__ is added as an argument to the
    linker\. Otherwise matching files are linked into the shared library\. Returns
    an error if no paths match a pattern\. A pattern for a relative path is
    resolved relative to the directory containing the *CriTcl script*\.

    Calls to this command are cumulative\.

  - <a name='25'></a>__::critcl::source__ *glob pattern*

    Evaluates as scripts the files matching each *glob pattern*\. Returns an
    error if there are no matching files\. A pattern for a relative path is
    resolved relative to the directory containing the *CriTcl script*\.

  - <a name='26'></a>__::critcl::tsources__ *glob pattern*\.\.\.

    Provides the information about additional Tcl script files to source when
    the shared library is loaded\.

    Matching paths are made available to the generated shared library when it is
    loaded for the current *CriTcl script*\. Returns an error if a pattern
    matches no files\. A pattern for a relative path is resolved relative to the
    directory containing the *CriTcl script*\.

    Calls to this command are cumulative\.

    After the shared library has been loaded, the declared files are sourced in
    the same order that they were provided as arguments\.

  - <a name='27'></a>__::critcl::owns__ *glob pattern*\.\.\.

    Ignored in "compile and run" and "generate package" modes\. In "generate TEA"
    mode each file matching a *glob pattern* is a file to be included in the
    TEA extension but that could not be ascertained as such from previous
    commands like __critcl::csources__ and __critcl::tsources__, either
    because of they were specified dynamically or because they were directly
    sourced\.

  - <a name='28'></a>__::critcl::cflags__ ?*arg*\.\.\.?

    Each *arg* is an argument to the compiler\.

    Calls to this command are cumulative\.

  - <a name='29'></a>__::critcl::ldflags__ ?*arg*\.\.\.?

    Each *arg* is an argument to the linker\.

    Calls to this command are cumulative\.

  - <a name='30'></a>__::critcl::framework__ ?*arg*\.\.\.?

    Each *arg* is the name of a framework to link on MacOS X\. This command is
    ignored if OS X is not the target so that frameworks can be specified
    unconditionally\.

    Calls to this command are cumulative\.

  - <a name='31'></a>__::critcl::tcl__ *version*

    Specifies the minimum version of the Tcl runtime to compile and link the
    package for\. The default is __8\.4__\.

  - <a name='32'></a>__::critcl::tk__

    Arranges to include the Tk headers and link to the Tk stubs\.

  - <a name='33'></a>__::critcl::preload__ *lib*\.\.\.

    Arranges for the external shared library *lib* to be loaded before the
    shared library for the *CriTcl script* is loaded\.

    Calls to this command are cumulative\.

    Each library *FOO* is searched for in the directories listed below, in the
    order listed\. The search stops at the first existing path\. Additional notes:

      * __platform__ is the placeholder for the target platform of the
        package\.

      * The extension "\.so" is the placeholder for whatever actual extension is
        used by the target platform for its shared libraries\.

      * The search is relative to the current working directory\.

    And now the paths, depending on the exact form of the library name:

      * FOO

          1. FOO\.so

          1. FOO/FOO\.so

          1. FOO/__platform__/FOO\.so

      * PATH/FOO

        The exact set searched depends on the existence of directory "PATH/FOO"\.
        If it exists, critcl searches

          1. FOO\.so

          1. PATH/FOO/FOO\.so

          1. PATH/FOO/__platform__/FOO\.so

        Otherwise it searches

          1. FOO\.so

          1. PATH/FOO\.so

          1. PATH/__platform__/FOO\.so

        instead\.

      * /PATH/FOO

        Even when specifying FOO with an absolute path the first path searched
        is relative to the current working directory\.

          1. FOO\.so

          1. /PATH/FOO\.so

          1. /PATH/__platform__/FOO\.so

    For developers who want to understand or modify the internals of the
    __[critcl](critcl\.md)__ package, [Preloading
    functionality](#subsection19) explains how preloading is implemented\.

  - <a name='34'></a>__::critcl::debug__ *area*\.\.\.

    Specifies what debugging features to activate\. Internally each area is
    translated into area\-specific flags for the compiler which are then handed
    over to __critcl::cflags__\.

      * __memory__

        Specifies Tcl memory debugging\.

      * __symbols__

        Specifies compilation and linking with debugging symbols for use by a
        debugger or other tool\.

      * __all__

        Specifies all available debugging\.

## <a name='subsection5'></a>Introspection

The following commands control compilation and linking\.

  - <a name='35'></a>__::critcl::check__ ?*label*? *text*

    Returns a __true__ if the C code in *text* compiles sucessfully, and
    __false__ otherwise\. Used to check for availability of features in the
    build environment\. If provided, *label* is used to uniquely mark the
    results in the generated log\.

  - <a name='36'></a>__::critcl::checklink__ ?*label*? *text*

    Like __critcl::check__ but also links the compiled objects, returning
    __true__ if the link is successful and __false__ otherwise\. If
    specified, *label* is used to uniquely mark the results in the generated
    log\.

  - <a name='37'></a>__::critcl::msg__ ?__\-nonewline__? *msg*

    Scripts using __critcl::check__ and __critcl::checklink__ can use
    this command to report results\. Does nothing in *[compile &
    run](\.\./index\.md\#compile\_run)* mode\. Tools like the *CriTcl
    Aplication* may redefine this command to implement their own message
    reporting\. For example, __critcl::app__ and any packages built on it
    print messages to *stdout*\.

  - <a name='38'></a>__::critcl::print__ ?__\-nonewline__? ?*chan*? *msg*

    Used by the CriTcl internals to report activity\. By default, effectively the
    same thing as __::puts__\. Tools directly using either the CriTcl package
    or the CriTcl application package may redefine this procedure to implement
    their own output functionality\.

    For example, the newest revisions of
    [Kettle](https://chiselapp\.com/user/andreas\_kupries/repository/Kettle/index)
    use this to highlight build warnings\.

  - <a name='39'></a>__::critcl::compiled__

    Returns __true__ if the current *CriTcl script* is already compiled
    and __false__ otherwise\.

    Enables a *CriTcl script* used as its own Tcl companion file \(see
    __critcl::tsources__\) to distinguish between being sourced for
    compilation in *[compile & run](\.\./index\.md\#compile\_run)* mode and
    being sourced from either the result of *[generate
    package](\.\./index\.md\#generate\_package)* mode or during the load phase of
    *[compile & run](\.\./index\.md\#compile\_run)* mode\. The result is
    __false__ in the first case and __true__ in the later two cases\.

  - <a name='40'></a>__::critcl::compiling__

    Returns __true__ if a working C compiler is available and __false__
    otherwise\.

  - <a name='41'></a>__::critcl::done__

    Returns __true__ when *CriTcl script* has been built and __false__
    otherwise\. Only useful from within a *CriTcl script*\. Enables the Tcl
    parts of a *CriTcl script* to distinguish between *prebuilt package*
    mode and *[compile & run](\.\./index\.md\#compile\_run)* mode\.

    See also [Modes Of Operation/Use](#subsection15)\.

  - <a name='42'></a>__::critcl::failed__

    Returns __true__ if the *CriTcl script* could not be built, and
    __false__ otherwise\. Forces the building of the package if it hasn't
    already been done, but not its loading\. Thus, a *CriTcl script* can check
    itself for availability of the compiled components\. Only useful from within
    a *CriTcl script*\.

  - <a name='43'></a>__::critcl::load__

    Like __critcl::failed__ except that it also forces the loading of the
    generated shared library, and that it returns __true__ on success and
    __false__ on failure\. Thus, a *CriTcl script* can check itself for
    availability of the compiled components\. Only useful from within a *CriTcl
    script*\.

## <a name='subsection6'></a>Build Management

The following command manages global settings, i\.e\. configuration options which
are independent of any *CriTcl script*\.

This command should not be needed to write a *CriTcl script*\. It is a
management command which is only useful to the *CriTcl Application* or similar
tools\.

  - <a name='44'></a>__::critcl::config__ *option* ?*val*?

    Sets and returns the following global configuration options:

      * __force__ bool

        When __false__ \(the default\), the C files are not built if there is
        a cached shared library\.

      * __lines__ bool

        When __true__ \(the default\), \#line directives are embedded into the
        generated C code\.

        This facility requires the use of a tclsh that provides __info
        frame__\. Otherwise, no *\#line* directives are emitted\. The command
        is supported by Tcl 8\.5 and higher\. It is also supported by Tcl 8\.4
        provided that it was compiled with the define __\-DTCL\_TIP280__\. An
        example of such is ActiveState's ActiveTcl\.

        Developers of higher\-level packages generating their own C code, either
        directly or indirectly through critcl, should also read section
        [Advanced: Location management](#subsection12) to see how critcl
        helps them in generating their directives\. Examples of such packages
        come with critcl itself\. See
        __[critcl::iassoc](critcl\_iassoc\.md)__ and
        __[critcl::class](critcl\_class\.md)__\.

      * __trace__ bool

        When __false__ \(the default\), no code tracing the entry and exit of
        CriTcl\-backed commands in the *CriTcl script* is inserted\. Insertion
        of such code implicitly activates the tracing facility in general\. See
        __[critcl::cutil](critcl\_cutil\.md)__\.

      * __I__ path

        A single global include path to use for all files\. Not set by default\.

      * __combine__ enum

          + __dynamic__ \(the default\)

            Object files have the suffix __\_pic__\.

          + __static__

            Object files have the suffix __\_stub__\.

          + __standalone__

            Object files have no suffix, and the generated C files are compiled
            without using Tcl/Tk stubs\. The result are object files usable for
            static linking into a *big shell*\.

      * __language__ string

      * __keepsrc__ bool

        When __false__ \(the default\), the generated "\.c" files are deleted
        after the "\.o" files have been built\.

      * __outdir__ directory

        The directory where to place a generated shared library\. By default, it
        is placed into the [Result Cache](#subsection18)\.

## <a name='subsection7'></a>Result Cache Management

The following commands control the [Result Cache](#subsection18)\. These
commands are not needed to simply write a *CriTcl script*\.

  - <a name='45'></a>__::critcl::cache__ ?path?

    Sets and returns the path to the directory for the package's result cache\.

    The default location is "~/\.critcl/\[platform::generic\]" and usually does not
    require any changes\.

  - <a name='46'></a>__::critcl::clean\_cache__ ?*pattern*\.\.\.?

    Cleans the result cache, i\.e\. removes any and all files and directories in
    it\. If one or more patterns are specified then only the files and
    directories matching them are removed\.

## <a name='subsection8'></a>Build Configuration

The following commands manage the build configuration, i\.e\. the per\-platform
information about compilers, linkers, and their commandline options\. These
commands are not needed to simply write a *CriTcl script*\.

  - <a name='47'></a>__::critcl::readconfig__ *path*

    Reads the build configuration file at *path* and configures the package
    using the information for the target platform\.

  - <a name='48'></a>__::critcl::showconfig__ ?*chan*?

    Converts the active build configuration into a human\-readable string and
    returns it, or if *chan* is provided prints the result to that channel\.

  - <a name='49'></a>__::critcl::showallconfig__ ?*chan*?

    Converts the set of all known build configurations from the currently active
    build configuration file last set with __critcl::readconfig__ into a
    string and returns it, or if *chan* is provided, prints it to that
    channel\.

  - <a name='50'></a>__::critcl::chooseconfig__ *target* ?*nomatcherr*?

    Matches *target* against all known targets, returning a list containing
    all the matching ones\. This search is first done on an exact basis, and then
    via glob matching\. If no known target matches the argument the default is to
    return an empty list\. However, if the boolean *nomatcherr* is specified
    and set an error is thrown using __critcl::error__ instead\.

  - <a name='51'></a>__::critcl::setconfig__ *target*

    Configures the package to use the settings of *target*\.

## <a name='subsection9'></a>Tool API

The following commands provide tools like *CriTcl Application* or similar with
deeper access to the package's internals\. These commands are not needed to
simply write a *CriTcl script*\.

  - <a name='52'></a>__::critcl::actualtarget__

    Returns the platform identifier for the target platform, i\.e\. the platform
    to build for\. Unlike __::critcl::targetplatform__ this is the true
    target, with any cross\-compilation information resolved\.

  - <a name='53'></a>__::critcl::buildforpackage__ ?*flag*?

    Signals whether the next file is to be built for inclusion into a package\.
    If not specified the *flag* defaults to __true__, i\.e\. building for a
    package\. This disables a number of things in the backend, namely the linking
    of that file into a shared library and the loading of that library\. It is
    expected that the build results are later wrapped into a larger collection\.

  - <a name='54'></a>__::critcl::cnothingtodo__ *file*

    Checks whether there is anything to build for *file*\.

  - <a name='55'></a>__::critcl::cresults__ ?*file*?

    Returns information about building *file*, or __info script__ If
    *file* is not provided\. The result in question is a dictionary containing
    the following items:

      * __clibraries__

        A list of external shared libraries and/or directories needed to link
        *file*\.

      * __ldflags__

        A list of linker flags needed to link *file*\.

      * __license__

        The text of the license for the package *file* is located in\.

      * __mintcl__

        The minimum version of Tcl required by the package *file* is in to run
        successfully\. A proper Tcl version number\.

      * __objects__

        A list of object files to link into *file*\.

      * __preload__

        A list of libraries to be preloaded in order to sucessfully load and use
        *file*\.

      * __tk__

        __true__ if *file* requires Tk and __false__ otherwise\.

      * __tsources__

        A list of companion "\.tcl" files to source in order to load and use the
        *CriTcl script* *file*\.

      * __log__

        The full build log generated by the compiler/linker, including command
        line data from critcl, and other things\.

      * __exl__

        The raw build log generated by the compiler/linker\. Contains the output
        generated by the invoked applications\.

  - <a name='56'></a>__::critcl::crosscheck__

    Determines whether the package is configured for cross\-compilation and
    prints a message to the standard error channel if so\.

  - <a name='57'></a>__::critcl::error__ *msg*

    Used to report internal errors\. The default implementation simply returns
    the error\. Tools like the *CriTcl Application* are allowed to redefine
    this procedure to perform their own way of error reporting\. There is one
    constraint they are not allowed to change: The procedure must *not return*
    to the caller\.

  - <a name='58'></a>__::critcl::knowntargets__

    Returns a list of the identifiers of all targets found during the last
    invocation of __critcl::readconfig__\.

  - <a name='59'></a>__::critcl::sharedlibext__

    Returns the file extension for shared libraries on the target platform\.

  - <a name='60'></a>__::critcl::targetconfig__

    Returns the identifier of the target to build for, as specified by either
    the user or the system\.

  - <a name='61'></a>__::critcl::buildplatform__

    Returns the identifier of the build platform, i\.e\. where the package is
    running on\.

  - <a name='62'></a>__::critcl::targetplatform__

    Returns the identifier of the target platform, i\.e\. the platform to compile
    for\. In contrast to __::critcl::actualtarget__ this may be the name of a
    cross\-compilation target\.

  - <a name='63'></a>__::critcl::cobjects__ ?*glob pattern*\.\.\.?

    Like __::critcl::clibraries__, but instead of matching libraries, each
    *glob pattern* matches object files to be linked into the shared object
    \(at compile time, not runtime\)\. If a *glob pattern* matches nothing an
    error is returned\. Not listed in [Control & Interface](#subsection4)
    because it is of no use to package writers\. Only tools like the *CriTcl
    Application* need it\.

    A pattern for a relative path is resolved relative to the directory
    containing the *CriTcl script*\.

    Calls to this command are cumulative\.

  - <a name='64'></a>__::critcl::scan__ *path*

    The main entry point to CriTcl's static code scanner\. Used by tools to
    implement processing modes like the assembly of a directory hierarchy
    containing a TEA\-lookalike buildystem, etc\.

    Scans *path* and returns a dictionary containing the following items:

      * version

        Package version\.

      * org

        Author\(ing organization\)\.

      * files

        List of the companion files, relative to the directory of the input
        file\.

  - <a name='65'></a>__::critcl::name2c__ *name*

    Given the Tcl\-level identifier *name*, returns a list containing the
    following details of its conversion to C:

      * Tcl namespace prefix

      * C namespace prefix

      * Tcl base name

      * C base name

    For use by utilities that provide Tcl commands without going through
    standard commands like __critcl::ccommand__ or __critcl::cproc__\.
    __[critcl::class](critcl\_class\.md)__ does this\.

## <a name='subsection10'></a>Advanced: Embedded C Code

For advanced use, the following commands used by __critcl::cproc__ itself
are exposed\.

  - <a name='66'></a>__::critcl::argnames__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of the corresponding user\-visible names\.

  - <a name='67'></a>__::critcl::argcnames__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of the corresponding C variable names for the user\-visible
    names\. The names returned here match the names used in the declarations and
    code returned by __::critcl::argvardecls__ and
    __::critcl::argconversion__\.

  - <a name='68'></a>__::critcl::argcsignature__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of the corresponding C parameter declarations\.

  - <a name='69'></a>__::critcl::argvardecls__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of the corresponding C variable declarations\. The names used
    in these declarations match the names returned by
    __::critcl::argcnames__\.

  - <a name='70'></a>__::critcl::argconversion__ *arguments* ?*n*?

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of C code fragments converting the user visible arguments
    found in the declaration from Tcl\_Obj\* to C types\. The names used in these
    statements match the names returned by __::critcl::argcnames__\.

    The generated code assumes that the procedure arguments start at index *n*
    of the __objv__ array\. The default is __1__\.

  - <a name='71'></a>__::critcl::argoptional__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of boolean values indicating which arguments are optional
    \(__true__\), and which are not \(__false__\)\.

  - <a name='72'></a>__::critcl::argdefaults__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list containing the default values for all optional arguments\.

  - <a name='73'></a>__::critcl::argsupport__ *arguments*

    Given an argument declaration as documented for __critcl::cproc__,
    returns a list of C code fragments needed to define the necessary supporting
    types\.

## <a name='subsection11'></a>Custom Build Configuration

This package provides one command for the management of package\-specific, i\.e\.
developer\-specified custom build configuration options\.

  - <a name='74'></a>__::critcl::userconfig__ __define__ *name* *description* *type* ?*default*?

    This command defines custom build configuration option, with
    *description*, *type* and optional *default* value\.

    The type can be either __bool__, or a list of values\.

      1. For __bool__ the default value, if specified, must be a boolean\. If
         it is not specified it defaults to __true__\.

      1. For a list of values the default value, if specified, must be a value
         found in this list\. If it is not specified it defaults to the first
         value of the list\.

    The *description* serves as in\-code documentation of the meaning of the
    option and is otherwise ignored\. When generating a TEA wrapper the
    description is used for the __configure__ option derived from the option
    declared by the command\.

    A boolean option __FOO__ are translated into a pair of configure
    options, __\-\-enable\-__FOO____ and __\-\-disable\-__FOO____,
    whereas an option whose *type* is a list of values is translated into a
    single configure option __\-\-with\-__FOO____\.

  - <a name='75'></a>__::critcl::userconfig__ __query__ *name*

    This command queries the database of custom build configuration option for
    the current "\.critcl" file and returns the chosen value\. This may be the
    default if no value was set via __::critcl::userconfig set__\.

    It is at this point that definitions and set values are brought together,
    with the latter validated against the definition\.

  - <a name='76'></a>__::critcl::userconfig__ __set__ *name* *value*

    This command is for use by a tool, like the __[critcl](critcl\.md)__
    application, to specify values for custom build configuration options\.

    At the time this command is used only the association between option name
    and value is recorded, and nothing else is done\. This behaviour is necessary
    as the system may not know if an option of the specified name exists when
    the command is invoked, nor its type\.

    Any and all validation is defered to when the value of an option is asked
    for via __::critcl::userconfig query__\.

    This means that it is possible to set values for any option we like, and the
    value will take effect only if such an option is both defined and used later
    on\.

## <a name='subsection12'></a>Advanced: Location management

First a small introduction for whose asking themselves 'what is location
management' ?

By default critcl embeds *\#line* directives into the generated C code so that
any errors, warnings and notes found by the C compiler during compilation will
refer to the "\.critcl" file the faulty code comes from, instead of the generated
"\.c" file\.

This facility requires the use of a tclsh that provides __info frame__\.
Otherwise, no *\#line* directives are emitted\. The command is supported by Tcl
8\.5 and higher\. It is also supported by Tcl 8\.4 provided that it was compiled
with the define __\-DTCL\_TIP280__\. An example of such is ActiveState's
ActiveTcl\.

Most users will not care about this feature beyond simply wanting it to work and
getting proper code references when reading compiler output\.

Developers of higher\-level packages generating their own C code however should
care about this, to ensure that their generated code contains proper references
as well\. Especially as this is key to separating bugs concerning code generated
by the package itself and bug in the user's code going into the package, if any\.

Examples of such packages come with critcl itself, see the implementation of
packages __[critcl::iassoc](critcl\_iassoc\.md)__ and
__[critcl::class](critcl\_class\.md)__\.

To help such developers eight commands are provided to manage such *location*
information\. These are listed below\.

A main concept is that they all operate on a single *stored location*,
setting, returning and clearing it\. Note that this location information is
completely independent of the generation of *\#line* directives within critcl
itself\.

  - <a name='77'></a>__::critcl::at::caller__

    This command stores the location of the caller of the current procedure as a
    tuple of file name and linenumber\. Any previously stored location is
    overwritten\. The result of the command is the empty string\.

  - <a name='78'></a>__::critcl::at::caller__ *offset*

    As above, the stored line number is modified by the specified offset\. In
    essence an implicit call of __critcl::at::incr__\.

  - <a name='79'></a>__::critcl::at::caller__ *offset* *level*

    As above, but the level the location information is taken from is modified
    as well\. Level __0__ is the caller, __\-1__ its caller, etc\.

  - <a name='80'></a>__::critcl::at::here__

    This command stores the current location in the current procedure as a tuple
    of file name and linenumber\. Any previously stored location is overwritten\.
    The result of the command is the empty string\.

    In terms of __::critcl::at::caller__ this is equivalent to

        critcl::at::caller 0 1

  - <a name='81'></a>__::critcl::at::get\*__

    This command takes the stored location and returns a formatted *\#line*
    directive ready for embedding into some C code\. The stored location is left
    untouched\. Note that the directive contains its own closing newline\.

    For proper nesting and use it is recommended that such directives are always
    added to the beginning of a code fragment\. This way, should deeper layers
    add their own directives these will come before ours and thus be inactive\.
    End result is that the outermost layer generating a directive will 'win',
    i\.e\. have its directive used\. As it should be\.

  - <a name='82'></a>__::critcl::at::get__

    This command is like the above, except that it also clears the stored
    location\.

  - <a name='83'></a>__::critcl::at::=__ *file* *line*

    This command allows the caller to set the stored location to anything they
    want, outside of critcl's control\. The result of the command is the empty
    string\.

  - <a name='84'></a>__::critcl::at::incr__ *n*\.\.\.

  - <a name='85'></a>__::critcl::at::incrt__ *str*\.\.\.

    These commands allow the user to modify the line number of the stored
    location, changing it incrementally\. The increment is specified as either a
    series of integer numbers \(__incr__\), or a series of strings to consider
    \(__incrt__\)\. In case of the latter the delta is the number of lines
    endings found in the strings\.

  - <a name='86'></a>__::critcl::at::caller\!__

  - <a name='87'></a>__::critcl::at::caller\!__ *offset*

  - <a name='88'></a>__::critcl::at::caller\!__ *offset* *level*

  - <a name='89'></a>__::critcl::at::here\!__

    These are convenience commands combining __caller__ and __here__
    with __get__\. I\.e\. they store the location and immediately return it
    formatted as proper *\#line* directive\. Also note that after their use the
    stored location is cleared\.

## <a name='subsection13'></a>Advanced: Diversions

Diversions are for higher\-level packages generating their own C code, to make
their use of critcl's commands generating [Embedded C Code](#subsection1)
easier\.

These commands normally generate all of their C code for the current "\.critcl"
file, which may not be what is wanted by a higher\-level package\.

With a diversion the generator output can be redirected into memory and from
there on then handled and processed as the caller desires before it is committed
to an actual "\.c" file\.

An example of such a package comes with critcl itself, see the implementation of
package __[critcl::class](critcl\_class\.md)__\.

To help such developers three commands are provided to manage diversions and the
collection of C code in memory\. These are:

  - <a name='90'></a>__::critcl::collect\_begin__

    This command starts the diversion of C code collection into memory\.

    The result of the command is the empty string\.

    Multiple calls are allowed, with each call opening a new nesting level of
    diversion\.

  - <a name='91'></a>__::critcl::collect\_end__

    This command end the diversion of C code collection into memory and returns
    the collected C code\.

    If multiple levels of diversion are open the call only closes and returns
    the data from the last level\.

    The command will throw an error if no diversion is active, indicating a
    mismatch in the pairing of __collect\_begin__ and __collect\_end__\.

  - <a name='92'></a>__::critcl::collect__ *script*

    This is a convenience command which runs the *script* under diversion and
    returns the collected C code, ensuring the correct pairing of
    __collect\_begin__ and __collect\_end__\.

## <a name='subsection14'></a>Advanced: File Generation

While file generation is related to the diversions explained in the previous
section they are not the same\. Even so, like diversions this feature is for
higher\-level packages generating their own C code\.

Three examples of utility packages using this facility comes with critcl itself\.
See the implementations of packages
__[critcl::literals](critcl\_literals\.md)__,
__[critcl::bitmap](critcl\_bitmap\.md)__, and
__[critcl::enum](critcl\_enum\.md)__\.

When splitting a package implementation into pieces it is often sensible to have
a number of pure C companion files containing low\-level code, yet these files
may require information about the code in the main "\.critcl" file\. Such
declarations are normally not exportable and using the stub table support does
not make sense, as this is completely internal to the package\.

With the file generation command below the main "\.critcl" file can generate any
number of header files for the C companions to pick up\.

  - <a name='93'></a>__::critcl::make__ *path* *contents*

    This command creates the file *path* in a location where the C companion
    files of the package are able to pick it up by simple inclusion of *path*
    during their compilation, without interfering with the outer system at all\.

    The generated file will contain the specified *contents*\.

# <a name='section3'></a>Concepts

## <a name='subsection15'></a>Modes Of Operation/Use

CriTcl can be used in three different modes of operation, called

  1. *[Compile & Run](\.\./index\.md\#compile\_run)*, and

  1. *[Generate Package](\.\./index\.md\#generate\_package)*

  1. *Generate TEA Package*

*[Compile & Run](\.\./index\.md\#compile\_run)* was the original mode and is
the default for *critcl\_pkg*\. Collects the C fragments from the *CriTcl
script*, builds them as needed, and caches the results to improve load times
later\.

The second mode, *[Generate Package](\.\./index\.md\#generate\_package)*, was
introduced to enable the creation of \(prebuilt\) deliverable packages which do
not depend on the existence of a build system, i\.e\. C compiler, on the target
machine\. This was originally done through the experimental __Critbind__
tool, and is now handled by the *CriTcl Application*, also named
__[critcl](critcl\.md)__\.

Newly introduced with CriTcl version 3 is *Generate TEA Package*\. This mode
constructs a directory hierarchy from the package which can later be built like
a regular TEA package, i\.e\. using

    .../configure --prefix ...
    make all isntall

Regarding the caching of results please read the section about the [Result
Cache](#subsection18) fore more details\.

## <a name='subsection16'></a>Runtime Behaviour

The default behaviour of critcl, the package is to defer the compilation,
linking, and loading of any C code as much as possible, given that this is an
expensive operation, mainly in the time required\. In other words, the C code
embedded into a "\.critcl" file is built only when the first C command or
procedure it provides is invoked\. This part of the system uses standard
functionality built into the Tcl core, i\.e\. the __auto\_index__ variable to
map from commands to scripts providing them and the __unknown__ command
using this information when the command is needed\.

A *limitation* of this behaviour is that it is not possible to just use
__info commands__ check for the existence of a critcl defined command\. It is
also necessary to search in the __auto\_index__ array, in case it has not
been build yet\.

This behaviour can be changed by using the control command __critcl::load__\.
When invoked, the building, including loading of the result, is forced\. After
this command has been invoked for a "\.critcl" file further definition of C code
in this file is not allowed any longer\.

## <a name='subsection17'></a>File Mapping

Each "\.critcl" file is backed by a single private "\.c" file containing that
code, plus the boilerplate necessary for its compilation and linking as a single
shared library\.

The [Embedded C Code](#subsection10) fragments appear in that file in the
exact same order they were defined in the "\.critcl" file, with one exception\.
The C code provided via __critcl::cinit__ is put after all other fragments\.
In other words all fragments have access to the symbols defined by earlier
fragments, and the __critcl::cinit__ fragment has access to all, regardless
of its placement in the "\.critcl" file\.

Note: A *limitation* of the current system is the near impossibility of C
level access between different critcl\-based packages\. The issue is not the
necessity of writing and sharing the proper __extern__ statements, but that
the management \(export and import\) of package\-specific stubs\-tables is not
supported\. This means that dependent parts have to be forcibly loaded before
their user, with all that entails\. See section [Runtime
Behaviour](#subsection16) for the relevant critcl limitation, and remember
that many older platforms do not support the necessary resolution of symbols,
the reason why stubs were invented for Tcl in the first place\.

## <a name='subsection18'></a>Result Cache

The compilation of C code is time\-consuming __[critcl](critcl\.md)__ not
only defers it as much as possible, as described in section [Runtime
Behaviour](#subsection16), but also caches the results\.

This means that on the first use of a "\.critcl" file "FOO\.tcl" the resulting
object file and shared library are saved into the cache, and on future uses of
the same file reused, i\.e\. loaded directly without requiring compilation,
provided that the contents of "FOO\.tcl" did not change\.

The change detection is based MD5 hashes\. A single hash is computed for each
"\.critcl" file, based on hashes for all C code fragments and configuration
options, i\.e\. everything which affects the resulting binary\.

As long as the input file doesn't change as per the hash a previously built
shared library found in the cache is reused, bypassing the compilation and link
stages\.

The command to manage the cache are found in section [Result Cache
Management](#subsection7)\. Note however that they are useful only to tools
based on the package, like the *CriTcl Application*\. Package writers have no
need of them\.

As a last note, the default directory for the cache is chosen based on the
chosen build target\. This means that the cache can be put on a shared \(network\)
filesystem without having to fear interference between machines of different
architectures\.

## <a name='subsection19'></a>Preloading functionality

The audience of this section are developers wishing to understand and possibly
modify the internals of critcl package and application\. Package writers can skip
this section\.

It explains how the preloading of external libraries is realized\.

Whenever a package declares libraries for preloading critcl will build a
supporting shared library providing a Tcl package named "preload"\. This package
is not distributed separately, but as part of the package requiring the preload
functionality\. This support package exports a single Tcl command

  - <a name='94'></a>__::preload__ *library*

    which is invoked once per libraries to preload, with the absolute path of
    that *library*\. The command then loads the *library*\.

    On windows the command will further use the Tcl command
    __::critcl::runtime::precopy__ to copy the *library* to the disk,
    should its path be in a virtual filesystem which doesn't directly support
    the loading of a shared library from it\.

The command __::critcl::runtime::precopy__ is provided by the file
"critcl\-rt\.tcl" in the generated package, as is the command
__::critcl::runtime::loadlib__ which generates the *ifneeded script*
expected by Tcl's package management\. This generated ifneeded script contains
the invocations of __::preload__\.

The C code for the supporting library is found in the file "critcl\_c/preload\.c",
which is part of the __[critcl](critcl\.md)__ package\.

The Tcl code for the supporting runtime "critcl\-rt\.tcl" is found in the file
"runtime\.tcl", which is part of the __critcl::app__ package\.

## <a name='subsection20'></a>Configuration Internals

The audience of this section are developers wishing to understand and possibly
modify the internals of critcl package and application\. Package writers can skip
this section\.

It explains the syntax of configuration files and the configuration keys used by
__[critcl](critcl\.md)__ to configure its build backend, i\.e\. how this
part of the system accesses compiler, linker, etc\.

It is recommended to open the file containing the standard configurations
\("path/to/critcl/Config"\) in the editor of your choice when reading this section
of the documentation, using it as an extended set of examples going beyond the
simple defaults shown here\.

First, the keys and the meaning of their values, plus examples drawn from the
standard configurations distributed with the package\. Note that when writing a
custom configuration it is not necessary to specify all the keys listed below,
but only those whose default values are wrong or insufficient for the platform
in question\.

  - version

    The command to print the compiler version number\. Defaults to

    gcc -v

  - compile

    The command to compile a single C source file to an object file\. Defaults to

    gcc -c -fPIC

  - debug\_memory

    The list of flags for the compiler to enable memory debugging in Tcl\.
    Defaults to

    -DTCL_MEM_DEBUG

  - debug\_symbols

    The list of flags for the compiler to add symbols to the object files and
    the resulting library\. Defaults to

    -g

  - include

    The compiler flag to add an include directory\. Defaults to

    -I

  - tclstubs

    The compiler flag to set USE\_TCL\_STUBS\. Defaults to

    -DUSE_TCL_STUBS

  - tkstubs

    The compiler flag to set USE\_TK\_STUBS\. Defaults to

    -DUSE_TK_STUBS

  - threadflags

    The list of compiler flags to enable a threaded build\. Defaults to

    -DUSE_THREAD_ALLOC=1 -D_REENTRANT=1 -D_THREAD_SAFE=1
    -DHAVE_PTHREAD_ATTR_SETSTACKSIZE=1 -DHAVE_READDIR_R=1
    -DTCL_THREADS=1

    \.

  - noassert

    The compiler flag to turn off assertions in Tcl code\. Defaults to

    -DNDEBUG

  - optimize

    The compiler flag to specify optimization level\. Defaults to

    -O2

  - output

    The compiler flags to set the output file of a compilation\. Defaults to

    -o [list $outfile]

    *NOTE* the use of Tcl commands and variables here\. At the time
    __[critcl](critcl\.md)__ uses the value of this key the value of the
    referenced variable is substituted into it\. The named variable is the only
    variable whose value is defined for this substitution\.

  - object

    The file extension for object files on the platform\. Defaults to

    .o

  - preproc\_define

    The command to preprocess a C source file without compiling it, but leaving
    \#define's in the output\. Defaults to

    gcc -E -dM

  - preproc\_enum

    See __preproc\_define__, except that \#define's are not left in the
    output\. Defaults to

    gcc -E

  - link

    The command to link one or more object files and create a shared library\.
    Defaults to

    gcc -shared

  - link\_preload

    The list of linker flags to use when dependent libraries are pre\-loaded\.
    Defaults to

    --unresolved-symbols=ignore-in-shared-libs

  - strip

    The flag to tell the linker to strip symbols from the shared library\.
    Defaults to

    -Wl,-s

  - ldoutput

    Like __output__, but for the linker\. Defaults to the value of
    __output__\.

  - link\_debug

    The list of linker flags needed to build a shared library with symbols\.
    Defaults to the empty string\. One platform requiring this are all variants
    of Windows, which uses

    -debug:full -debugtype:cv

  - link\_release

    The list of linker flags needed to build a shared library without symbols,
    i\.e\. a regular build\. Defaults to the empty string\. One platform requiring
    this are all variants of Windows, which uses

    -release -opt:ref -opt:icf,3 -ws:aggressive

  - sharedlibext

    The file extension for shared library files on the platform\. Defaults to

    [info sharedlibextension]

  - platform

    The identifier of the platform used in generated packages\. Defaults to

    [platform::generic]

  - target

    The presence of this key marks the configuration as a cross\-compilation
    target and the value is the actual platform identifier of the target\. No
    default\.

The syntax expected from configuration files is governed by the rules below\.
Again, it is recommended to open the file containing the standard configurations
\("path/to/critcl/Config"\) in the editor of your choice when reading this section
of the documentation, using it as an extended set of examples for the syntax>

  1. Each logical line of the configuration file consists of one or more
     physical lines\. In case of the latter the physical lines have to follow
     each other and all but the first must be marked by a trailing backslash\.
     This is the same marker for *continuation lines* as used by Tcl itself\.

  1. A \(logical\) line starting with the character "\#" \(modulo whitespace\) is a
     comment which runs until the end of the line, and is otherwise ignored\.

  1. A \(logical\) line starting with the word "if" \(modulo whitespace\) is
     interpreted as Tcl's __if__ command and executed as such\. I\.e\. this
     command has to follow Tcl's syntax for the command, which may stretch
     across multiple logical lines\. The command will be run in a save
     interpreter\.

  1. A \(logical\) line starting with the word "set" \(modulo whitespace\) is
     interpreted as Tcl's __set__ command and executed as such\. I\.e\. this
     command has to follow Tcl's syntax for the command, which may stretch
     across multiple logical lines\. The command will be run in a save
     interpreter\.

  1. A line of the form "*platform* __variable__ *value*" defines a
     platform specific configuration variable and value\. The __variable__
     has to be the name of one of the configuration keys listed earlier in this
     section, and the *platform* string identifies the platform the setting is
     for\. All settings with the same identification string form the
     *configuration block* for this platform\.

  1. A line of the special form "*platform* __when__ *expression*" marks
     the *platform* and all the settings in its *configuration block* as
     conditional on the *expression*\.

     If the build platform is not a prefix of *platform*, nor vice versa the
     whole block is ignored\. Otherwise the *expression* is evaluated via
     __expr__, in the same safe interpreter used to run any __set__ and
     __if__ commands found in the configuration file \(see above\)\.

     If the expression evaluates to __true__ this configuration block is
     considered to be the build platform fo the host and chosen as the default
     configuration\. An large example of of this feature is the handling of OS X
     found in the standard configuration file, where it selects the
     architectures to build based on the version of the operating system, the
     available SDK, etc\. I\.e\. it chooses whether the output is universal or not,
     and whether it is old\-style \(ix86 \+ ppc\) versus new\-style \(ix86 32\+64\) of
     universality\.

  1. A line of the special form "*platform* __copy__ *sourceplatform*"
     copies the configuration variables and values currently defined in the
     *configuration block* for *sourceplatform* to that of *platform*,
     overwriting existing values, and creating missing ones\. Variables of
     *platform* not defined by by *sourceplatform* are not touched\.

     The copied values can be overridden later in the configuration file\.
     Multiple __copy__ lines may exist for a platform and be intermixed with
     normal configuration definitions\. Only the last definition of a variable is
     used\.

  1. At last, a line of the form "__variable__ *value*" defines a default
     configuration variable and value\.

## <a name='subsection21'></a>Stubs Tables

This section is for developers of extensions not based on critcl, yet also
wishing to interface with stubs as they are understood and used by critcl,
either by exporting their own stubs table to a critcl\-based extension, or
importing a stubs table of a critcl\-based extension into their own\.

To this end we describe the stubs table information of a package __foo__\.

  1. Note that the differences in the capitalization of "foo", "Foo", "FOO",
     etc\. below demonstrate how to capitalize the actual package name in each
     context\.

  1. All relevant files must be available in a sub\-directory "foo" which can be
     found on the include search paths\.

  1. The above directory may contain a file "foo\.decls"\. If present it is
     assumed to contain the external representation of the stubs table the
     headers mentioned in the following items are based on\.

     critcl is able to use such a file to give the importing package
     programmatic access to the imported API, for automatic code generation and
     the like\.

  1. The above directory must contain a header file "fooDecls\.h"\. This file
     *declares* the exported API\. It is used by both exporting and importing
     packages\. It is usually generated and must contain \(in the order
     specified\):

       1) the declarations of the exported, i\.e\. public, functions of
          __foo__,

       1) the declaration of structure "FooStubs" for the stub table,

       1) the C preprocessor macros which route the invocations of the public
          functions through the stubs table\.

          These macros must be defined if, and only if, the C preprocessor macro
          USE\_FOO\_STUBS is defined\. Package __foo__ does not define this
          macro, as it is allowed to use the exported functions directly\. All
          importing packages however must define this macro, to ensure that they
          do *not* use any of the exported functions directly, but only
          through the stubs table\.

       1) If the exported functions need additional types for their proper
          declaration then these types should be put into a separate header file
          \(of arbitrary name\) and "fooDecls\.h" should contain an \#include
          directive to this header at the top\.

     A very reduced, yet also complete example, from a package for low\-level
     random number generator functions can be found at the end of this section\.

  1. The above directory must contain a header file "fooStubLib\.h"\. This file
     *defines* everything needed to use the API of __foo__\. Consequently
     it is used only by importing packages\. It is usually generated and must
     contain \(in the order specified\):

       1) An \#include directive for "tcl\.h", with USE\_TCL\_STUBS surely defined\.

       1) An \#include directive for "fooDecls\.h", with USE\_FOO\_STUBS surely
          defined\.

       1) A *definition* of the stubs table variable, i\.e\.

    const FooStubs* fooStubsPtr;

       1) A *definition* of the stubs initializer function, like

    char *
    Foo_InitStubs(Tcl_Interp *interp, CONST char *version, int exact)
    {
        /*
         * Boiler plate C code initalizing the stubs table variable,
         * i.e. "fooStubsPtr".
         */

        CONST char *actualVersion;

        actualVersion = Tcl_PkgRequireEx(interp, "foo", version,
    				     exact, (ClientData *) &fooStubsPtr);

        if (!actualVersion) {
    	return NULL;
        }

        if (!fooStubsPtr) {
    	Tcl_SetResult(interp,
    		      "This implementation of Foo does not support stubs",
    		      TCL_STATIC);
    	return NULL;
        }

        return (char*) actualVersion;
    }

     This header file must be included by an importing package *exactly once*,
     so that it contains only one definition of both stubs table and stubs
     initializer function\.

     The importing package's initialization function must further contain a
     statement like

    if (!Foo_InitStubs (ip, "1", 0)) {
        return TCL_ERROR;
    }

     which invokes __foo__'s stubs initializer function to set the local
     stub table up\.

     For a complete example of such a header file see below, at the end of this
     section\.

  1. The last item above, about "fooStubLib\.h" *differs* from the regular stub
     stable system used by Tcl\. The regular system assumes that a static library
     "libfoostub\.a" was installed by package __foo__, and links it\.

     IMVHO critcl's approach is simpler, using *only* header files found in a
     single location, vs\. header files and static library found in multiple,
     different locations\.

     A second simplification is that we avoid having to extend critcl's compiler
     backend with settings for the creation of static libraries\.

Below is a complete set of example header files, reduced, yet still complete,
from a package for low\-level random number generator functions:

  - "rngDecls\.h":

    #ifndef rng_DECLS_H
    #define rng_DECLS_H

    #include <tcl.h>

    /*
     * Exported function declarations:
     */

    /* 0 */
    EXTERN void rng_bernoulli(double p, int*v);

    typedef struct RngStubs {
        int magic;
        const struct RngStubHooks *hooks;

        void (*rng_bernoulli) (double p, int*v); /* 0 */
    } RngStubs;

    #ifdef __cplusplus
    extern "C" {
    #endif
    extern const RngStubs *rngStubsPtr;
    #ifdef __cplusplus
    }
    #endif

    #if defined(USE_RNG_STUBS)

    /*
     * Inline function declarations:
     */

    #define rng_bernoulli  (rngStubsPtr->rng_bernoulli) /* 0 */

    #endif /* defined(USE_RNG_STUBS) */
    #endif /* rng_DECLS_H */

  - "rngStubLib\.h":

    /*
     * rngStubLib.c --
     *
     * Stub object that will be statically linked into extensions that wish
     * to access rng.
     */

    #ifndef USE_TCL_STUBS
    #define USE_TCL_STUBS
    #endif
    #undef  USE_TCL_STUB_PROCS

    #include <tcl.h>

    #ifndef USE_RNG_STUBS
    #define USE_RNG_STUBS
    #endif
    #undef  USE_RNG_STUB_PROCS

    #include "rngDecls.h"

    /*
     * Ensure that Rng_InitStubs is built as an exported symbol.  The other stub
     * functions should be built as non-exported symbols.
     */

    #undef  TCL_STORAGE_CLASS
    #define TCL_STORAGE_CLASS DLLEXPORT

    const RngStubs* rngStubsPtr;

    /*
     *----------------------------------------------------------------------
     *
     * Rng_InitStubs --
     *
     * Checks that the correct version of Rng is loaded and that it
     * supports stubs. It then initialises the stub table pointers.
     *
     * Results:
     *  The actual version of Rng that satisfies the request, or
     *  NULL to indicate that an error occurred.
     *
     * Side effects:
     *  Sets the stub table pointers.
     *
     *----------------------------------------------------------------------
     */

    #ifdef Rng_InitStubs
    #undef Rng_InitStubs
    #endif

    char *
    Rng_InitStubs(Tcl_Interp *interp, CONST char *version, int exact)
    {
        CONST char *actualVersion;

        actualVersion = Tcl_PkgRequireEx(interp, "rng", version,
    				     exact, (ClientData *) &rngStubsPtr);
        if (!actualVersion) {
    	return NULL;
        }

        if (!rngStubsPtr) {
    	Tcl_SetResult(interp,
    		      "This implementation of Rng does not support stubs",
    		      TCL_STATIC);
    	return NULL;
        }

        return (char*) actualVersion;
    }

# <a name='section4'></a>Examples

See section "Embedding C" in *Using CriTcl*\.

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
