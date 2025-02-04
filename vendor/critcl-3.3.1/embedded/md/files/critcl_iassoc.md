
[//000000001]: # (critcl::iassoc \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_iassoc\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::iassoc\(n\) 1\.2 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::iassoc \- CriTcl \- Code Gen \- Tcl Interp Associations

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
package require critcl::iassoc ?1\.2?  

[__::critcl::iassoc::def__ *name* *arguments* *struct* *constructor* *destructor*](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::iassoc__ package\.
This package provides convenience commands for advanced functionality built on
top of the critcl core\.

With it a user wishing to associate some data with a Tcl interpreter via Tcl's
__Tcl\_\(Get&#124;Set\)AssocData\(\)__ APIs can now concentrate on the data itself,
while all the necessary boilerplate around it is managed by this package\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::iassoc::def__ *name* *arguments* *struct* *constructor* *destructor*

    This command defines a C function with the given *name* which provides
    access to a structure associated with a Tcl interpreter\.

    The C code code fragment *struct* defines the elements of said structure,
    whereas the fragments *constructor* and *destructor* are C code blocks
    executed to initialize and release any dynamically allocated parts of this
    structure, when needed\. Note that the structure itself is managed by the
    system\.

    The new function takes a __Tcl\_Interp\*__ pointer refering to the
    interpreter whose structure we wish to obtain as the first argument, plus
    the specified *arguments* and returns a pointer to the associated
    structure, of type "*name*\_data" \(see below\)\.

    The *arguments* are a dictionary\-like list of C types and identifiers
    specifying additional arguments for the accessor function, and, indirectly,
    the *constructor* C code block\. This is useful for the supplication of
    initialization values, or the return of more complex error information in
    case of a construction failure\.

    The C types associated with the structure are derived from *name*, with
    "*name*\_data\_\_" the type of the structure itself, and "*name*\_data"
    representing a pointer to the structure\. The C code blocks can rely on the
    following C environments:

      * *constructor*

          + __data__

            Pointer to the structure \(type: *name*\_data\) to initialize\.

          + __interp__

            Pointer to the Tcl interpreter \(type: Tcl\_Interp\*\) the new structure
            will be associated with\.

          + error

            A C code label the constructor can jump to should it have to signal
            a construction failure\. It is the responsibility of the constructor
            to release any fields already initialized before jumping to this
            label\.

          + \.\.\.

            The names of the constructor arguments specified with *arguments*\.

      * *destructor*

          + __data__

            Pointer to the structure being released\.

          + __interp__

            Pointer to the Tcl interpreter the structure belonged to\.

# <a name='section3'></a>Example

The example shown below is the specification of a simple interpreter\-associated
counter\. The full example, with meta data and other incidentals, can be found in
the directory "examples/queue" of the critcl source distribution/repository\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::iassoc
    }

    critcl::iassoc::def icounter {} {
        int counter; /* The counter variable */
    } {
        data->counter = 0;
    } {
        /* Nothing to release */
    }

    critcl::ccode {
        ... function (...)
        {
             /* Access to the data ... */
             icounter_data D = icounter (interp /* ... any declared arguments, here, none */);
    	 ... D->counter ...
        }
    }
    # or, of course, 'cproc's, 'ccommand's etc.

    package provide icounter 1

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
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation),
[singleton](\.\./index\.md\#singleton)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2024 Andreas Kupries
