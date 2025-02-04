
[//000000001]: # (critcl::enum \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_enum\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::enum\(n\) 1\.2 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::enum \- CriTcl \- Wrap Support \- String/Integer mapping

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
package require critcl::enum ?1\.2?  

[__::critcl::enum::def__ *name* *definition* ?*mode*?](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::enum__ package\.
This package provides convenience commands for advanced functionality built on
top of both critcl core and package
__[critcl::literals](critcl\_literals\.md)__\.

It is an extended form of string pool which not only converts integer values
into Tcl\-level strings, but also handles the reverse direction, converting from
strings to the associated integer values\.

It essentially provides a bi\-directional mapping between a C enumeration type
and a set of strings, one per enumeration value\. *Note* that the C enumeration
in question is created by the definition\. It is not possible to use the symbols
of an existing enumeration type\.

This package was written to make the declaration and management of such mappings
easy\. It uses a string pool for one of the directions, using its ability to
return shared literals and conserve memory\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::enum::def__ *name* *definition* ?*mode*?

    This command defines two C functions for the conversion between C values and
    Tcl\_Obj'ects, with named derived from *name*\.

    The *definition* dictionary provides the mapping from the specified
    C\-level symbolic names to the strings themselves\.

    The *mode*\-list configures the output somewhat\. The two allowed modes are
    __\+list__ and __tcl__\. All modes can be used together\. The default
    mode is __tcl__\. Using mode __\+list__ implies __tcl__ as well\.

    For mode __tcl__ the new function has two arguments, a
    __Tcl\_Interp\*__ pointer refering to the interpreter holding the string
    pool, and a code of type "*name*\_pool\_names" \(see below\), the symbolic
    name of the string to return\. The result of the function is a
    __Tcl\_Obj\*__ pointer to the requested string constant\.

    For mode __\+list__ all of __tcl__ applies, plus an additional
    function is generated which takes three arguments, in order: a
    __Tcl\_Interp\*__ pointer refering to the interpreter holding the string
    pool, an __int__ holding the size of the last argument, and an array of
    type "*name*\_pool\_names" holding the codes \(see below\), the symbolic names
    of the strings to return\. The result of the function is a __Tcl\_Obj\*__
    pointer to a Tcl list holding the requested string constants\.

    The underlying string pool is automatically initialized on first access, and
    finalized on interpreter destruction\.

    The package generates multiple things \(declarations and definitions\) with
    names derived from *name*, which has to be a proper C identifier\.

      * *name*\_pool\_names

        The C enumeration type containing the specified symbolic names\.

      * *name*\_ToObj

        The function converting from integer value to Tcl string\. Its signature
        is

        > Tcl\_Obj\* *name*\_ToObj \(Tcl\_Interp\* interp, *name*\_names literal\);

      * *name*\_ToObjList

        The mode __\+list__ function converting from integer array to Tcl
        list of strings\. Its signature is

        > Tcl\_Obj\* *name*\_ToObjList \(Tcl\_Interp\* interp, int c, *name*\_names\* literal\);

      * *name*\_GetFromObj

        The function converting from Tcl string to integer value\. Its signature
        is

        > int *name*\_GetFromObj \(Tcl\_Interp\* interp, Tcl\_Obj\* obj, int flags, int\* literal\);

        The *flags* are like for __Tcl\_GetIndexFromObj__\.

      * *name*\.h

        A header file containing the declarations for the converter functions,
        for use by other parts of the system, if necessary\.

        The generated file is stored in a place where it will not interfere with
        the overall system outside of the package, yet also be available for
        easy inclusion by package files \(__csources__\)\.

      * *name*

        At the level of critcl itself the command registers a new result\-type
        for __critcl::cproc__, which takes an integer result from the
        function and converts it to the equivalent string in the pool for the
        script\.

      * *name*

        At the level of critcl itself the command registers a new argument\-type
        for __critcl::cproc__, which takes a Tcl string and converts it to
        the equivalent integer for delivery to the function\.

# <a name='section3'></a>Example

The example shown below is the specification for a set of actions, methods, and
the like, a function may take as argument\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::enum
    }

    critcl::enum::def action {
        w_create	"create"
        w_directory	"directory"
        w_events	"events"
        w_file	"file"
        w_handler	"handler"
        w_remove	"remove"
    }

    # Declarations: action.h
    # Type:         action_names
    # Accessor:     Tcl_Obj* action_ToObj (Tcl_Interp* interp, int literal);
    # Accessor:     int action_GetFromObj (Tcl_Interp* interp, Tcl_Obj* o, int flags, int* literal);
    # ResultType:   action
    # ArgType:      action

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
[conversion](\.\./index\.md\#conversion), [dynamic code
generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [int to string
mapping](\.\./index\.md\#int\_to\_string\_mapping),
[linker](\.\./index\.md\#linker), [literal pool](\.\./index\.md\#literal\_pool),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation),
[singleton](\.\./index\.md\#singleton), [string
pool](\.\./index\.md\#string\_pool), [string to int
mapping](\.\./index\.md\#string\_to\_int\_mapping)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2024 Andreas Kupries
