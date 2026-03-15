
[//000000001]: # (critcl::emap \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_emap\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::emap\(n\) 1\.3 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::emap \- CriTcl \- Wrap Support \- Enum en\- and decoding

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
package require critcl::emap ?1\.3?  

[__::critcl::emap::def__ *name* *definition* ?__\-nocase__? ?__\-mode__ *mode*?](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::emap__ package\.
This package provides convenience commands for advanced functionality built on
top of both critcl core and package
__[critcl::iassoc](critcl\_iassoc\.md)__\.

C level libraries often use enumerations or integer values to encode
information, like the state of a system\. Tcl bindings to such libraries now have
the task of converting a Tcl representation, i\.e\. a string into such state, and
back\. *Note* here that the C\-level information has to be something which
already exists\. The package does *not* create these values\. This is in
contrast to the package __[critcl::enum](critcl\_enum\.md)__ which creates
an enumeration based on the specified symbolic names\.

This package was written to make the declaration and management of such
enumerations and their associated conversions functions easy, hiding all
attendant complexity from the user\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::emap::def__ *name* *definition* ?__\-nocase__? ?__\-mode__ *mode*?

    This command defines C functions for the conversion of the *name*d state
    code into a Tcl string, and vice versa\. The underlying mapping tables are
    automatically initialized on first access \(if not fully constant\), and
    finalized on interpreter destruction\.

    The *definition* dictionary provides the mapping from the Tcl\-level
    symbolic names of the state to their C expressions \(often the name of the
    macro specifying the actual value\)\. *Note* here that the C\-level
    information has to be something which already exists\. The package does
    *not* create these values\. This is in contrast to the package
    __[critcl::enum](critcl\_enum\.md)__ which creates an enumeration
    based on the specified symbolic names\.

    Further note that multiple strings can be mapped to the same C expression\.
    When converting to Tcl the first string for the mapping is returned\. An
    important thing to know: If all C expressions are recognizable as integer
    numbers and their covered range is not too large \(at most 50\) the package
    will generate code using direct and fast mapping tables instead of using a
    linear search\.

    If the option __\-nocase__ is specified then the encoder will match
    strings case\-insensitively, and the decoder will always return a lower\-case
    string, regardless of the string's case in the *definition*\.

    If the option __\-mode__ is specified its contents will interpreted as a
    list of access modes to support\. The two allowed modes are __c__ and
    __tcl__\. Both modes can be used together\. The default mode is
    __tcl__\.

    The package generates multiple things \(declarations and definitions\) with
    names derived from *name*, which has to be a proper C identifier\. Some of
    the things are generated conditional on the chosen *mode*s\.

      * *name*\_encode

        The __tcl__\-mode function for encoding a Tcl string into the
        equivalent state code\. Its signature is

        > int *name*\_encode \(Tcl\_Interp\* interp, Tcl\_Obj\* state, int\* result\);

        The return value of the function is a Tcl error code, i\.e\.
        __TCL\_OK__, __TCL\_ERROR__, etc\.

      * *name*\_encode\_cstr

        The __c__\-mode function for encoding a C string into the equivalent
        state code\. Its signature is

        > int *name*\_encode\_cstr \(const char\* state\);

        The return value of the function is the encoded state, or \-1 if the
        argument is not a vlaid state\.

      * *name*\_decode

        The __tcl__\-mode function for decoding a state code into the
        equivalent Tcl string\. Its signature is

        > Tcl\_Obj\* *name*\_decode \(Tcl\_Interp\* interp, int state\);

      * *name*\_decode\_cstr

        The __c__\-mode function for decoding a state code into the
        equivalent C string\. Its signature is

        > const char\* *name*\_decode\_cstr \(int state\);

        The return value of the function is the C string for the state, or
        __NULL__ if the *state* argument does not contain a valid state
        value\.

      * *name*\.h

        A header file containing the declarations for the conversion functions,
        for use by other parts of the system, if necessary\.

        The generated file is stored in a place where it will not interfere with
        the overall system outside of the package, yet also be available for
        easy inclusion by package files \(__csources__\)\.

      * *name*

        For mode __tcl__ the command registers a new argument\-type for
        __critcl::cproc__ with critcl, encapsulating the encoder function\.

      * *name*

        For mode __tcl__ the command registers a new result\-type for
        __critcl::cproc__ with critcl, encapsulating the decoder function\.

# <a name='section3'></a>Example

The example shown below is the specification for the possible modes of entry
\(normal, no feedback, stars\) used by the Tcl binding to the linenoise library\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::emap
    }

    critcl::emap::def hiddenmode {
                no  0 n 0 off 0 false 0 0 0
        all   1 yes 1 y 1 on  1 true  1 1 1
        stars 2
    } -nocase

    # Declarations: hiddenmode.h
    # Encoder:      int      hiddenmode_encode (Tcl_Interp* interp, Tcl_Obj* state, int* result);
    # Decoder:      Tcl_Obj* hiddenmode_decode (Tcl_Interp* interp, int state);
    # ResultType:   hiddenmode
    # ArgumentType: hiddenmode

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
Association](\.\./index\.md\#tcl\_interp\_association),
[bitmask](\.\./index\.md\#bitmask), [bitset](\.\./index\.md\#bitset), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation),
[flags](\.\./index\.md\#flags), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation),
[singleton](\.\./index\.md\#singleton)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2011\-2024 Andreas Kupries
