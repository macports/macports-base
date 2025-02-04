
[//000000001]: # (critcl::literals \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_literals\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::literals\(n\) 1\.4 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::literals \- CriTcl \- Code Gen \- Constant string pools

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Example](#section3)

  - [Authors](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.2?  
package require critcl::literals ?1\.4?  

[__::critcl::literals::def__ *name* *definition* ?*mode*?](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::literals__ package\.
This package provides convenience commands for advanced functionality built on
top of both critcl core and package
__[critcl::iassoc](critcl\_iassoc\.md)__\.

Many packages will have a fixed set of string constants occuring in one or
places\. Most of them will be coded to create a new string __Tcl\_Obj\*__ from
a C __char\*__ every time the constant is needed, as this is easy to to,
despite the inherent waste of memory\.

This package was written to make declaration and management of string pools
which do not waste memory as easy as the wasteful solution, hiding all attendant
complexity from the user\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::literals::def__ *name* *definition* ?*mode*?

    This command defines a C function with the given *name* which provides
    access to a pool of constant strings with a Tcl interpreter\.

    The *definition* dictionary provides the mapping from the C\-level symbolic
    names to the string themselves\.

    The *mode*\-list configures the output somewhat\. The three allowed modes
    are __c__, __\+list__ and __tcl__\. All modes can be used
    together\. The default mode is __tcl__\. Using mode __\+list__ implies
    __tcl__ as well\.

    For mode __tcl__ the new function has two arguments, a
    __Tcl\_Interp\*__ pointer refering to the interpreter holding the string
    pool, and a code of type "*name*\_names" \(see below\), the symbolic name of
    the literal to return\. The result of the function is a __Tcl\_Obj\*__
    pointer to the requested string constant\.

    For mode __c__ the new function has one argument, a code of type
    "*name*\_names" \(see below\), the symbolic name of the literal to return\.
    The result of the function is a __const char\*__ pointer to the requested
    string constant\.

    For mode __\+list__ all of __tcl__ applies, plus an additional
    function is generated which takes three arguments, in order, a
    __Tcl\_Interp\*__ pointer refering to the interpreter holding the string
    pool, an __int__ holding the size of the last argument, and an array of
    type "*name*\_names" holding the codes \(see below\), the symbolic names of
    the literals to return\. The result of the function is a __Tcl\_Obj\*__
    pointer to a Tcl list holding the requested string constants\.

    The underlying string pool is automatically initialized on first access, and
    finalized on interpreter destruction\.

    The package generates multiple things \(declarations and definitions\) with
    names derived from *name*, which has to be a proper C identifier\.

      * *name*

        The mode __tcl__ function providing access to the string pool\. Its
        signature is

        > Tcl\_Obj\* *name* \(Tcl\_Interp\* interp, *name*\_names literal\);

      * *name*\_list

        The mode __\+list__ function providing multi\-access to the string
        pool\. Its signature is

        > Tcl\_Obj\* *name*\_list \(Tcl\_Interp\* interp, int c, *name*\_names\* literal\);

      * *name*\_cstr

        The mode __c__ function providing access to the string pool\. Its
        signature is

        > const char\* *name*\_cstr \(*name*\_names literal\);

      * *name*\_names

        A C enumeration type containing the symbolic names of the strings
        provided by the pool\.

      * *name*\.h

        A header file containing the declarations for the accessor functions and
        the enumeration type, for use by other parts of the system, if
        necessary\.

        The generated file is stored in a place where it will not interfere with
        the overall system outside of the package, yet also be available for
        easy inclusion by package files \(__csources__\)\.

      * *name*

        *New in version 1\.1*: For mode __tcl__ the command registers a new
        result\-type for __critcl::cproc__ with critcl, which takes an
        integer result from the function and converts it to the equivalent
        string in the pool for the script\.

# <a name='section3'></a>Example

The example shown below is the specification of the string pool pulled from the
draft work on a Tcl binding to Linux's inotify APIs\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::literals
    }

    critcl::literals::def tcl_inotify_strings {
        w_create	"create"
        w_directory	"directory"
        w_events	"events"
        w_file	"file"
        w_handler	"handler"
        w_remove	"remove"
    } {c tcl}

    # Declarations: tcl_inotify_strings.h
    # Type:         tcl_inotify_strings_names
    # Accessor:     Tcl_Obj*    tcl_inotify_strings      (Tcl_Interp*               interp,
    #                                                     tcl_inotify_strings_names literal);
    # Accessor:     const char* tcl_inotify_strings_cstr (tcl_inotify_strings_names literal);
    # ResultType:   tcl_inotify_strings

# <a name='section4'></a>Authors

Andreas Kupries

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such at
[https://github\.com/andreas\-kupries/critcl](https://github\.com/andreas\-kupries/critcl)\.
Please also report any ideas for enhancements you may have for either package
and/or documentation\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [Tcl Interp
Association](\.\./index\.md\#tcl\_interp\_association), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[literal pool](\.\./index\.md\#literal\_pool), [on demand
compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation),
[singleton](\.\./index\.md\#singleton), [string
pool](\.\./index\.md\#string\_pool)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2024 Andreas Kupries
