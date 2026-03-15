
[//000000001]: # (critcl::bitmap \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_bitmap\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::bitmap\(n\) 1\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::bitmap \- CriTcl \- Wrap Support \- Bitset en\- and decoding

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
package require critcl::bitmap ?1\.1?  

[__::critcl::bitmap::def__ *name* *definition* ?*exclusions*?](#1)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::bitmap__ package\.
This package provides convenience commands for advanced functionality built on
top of both critcl core and package
__[critcl::iassoc](critcl\_iassoc\.md)__\.

C level libraries often use bit\-sets to encode many flags into a single value\.
Tcl bindings to such libraries now have the task of converting a Tcl
representation of such flags \(like a list of strings\) into such bit\-sets, and
back\. *Note* here that the C\-level information has to be something which
already exists\. The package does *not* create these values\. This is in
contrast to the package __[critcl::enum](critcl\_enum\.md)__ which creates
an enumeration based on the specified symbolic names\.

This package was written to make the declaration and management of such bit\-sets
and their associated conversions functions easy, hiding all attendant complexity
from the user\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::bitmap::def__ *name* *definition* ?*exclusions*?

    This command defines two C functions for the conversion of the *name*d
    bit\-set into Tcl lists, and vice versa\. The underlying mapping tables are
    automatically initialized on first access, and finalized on interpreter
    destruction\.

    The *definition* dictionary provides the mapping from the Tcl\-level
    symbolic names of the flags to their C expressions \(often the name of the
    macro specifying the actual value\)\. *Note* here that the C\-level
    information has to be something which already exists\. The package does
    *not* create these values\. This is in contrast to the package
    __[critcl::enum](critcl\_enum\.md)__ which creates an enumeration
    based on the specified symbolic names\.

    The optional *exlusion* list is for the flags/bit\-sets for which
    conversion from bit\-set to flag, i\.e\. decoding makes no sense\. One case for
    such, for example, are flags representing a combination of other flags\.

    The package generates multiple things \(declarations and definitions\) with
    names derived from *name*, which has to be a proper C identifier\.

      * *name*\_encode

        The function for encoding a Tcl list of strings into the equivalent
        bit\-set\. Its signature is

        > int *name*\_encode \(Tcl\_Interp\* interp, Tcl\_Obj\* flags, int\* result\);

        The return value of the function is a Tcl error code, i\.e\.
        __TCL\_OK__, __TCL\_ERROR__, etc\.

      * *name*\_decode

        The function for decoding a bit\-set into the equivalent Tcl list of
        strings\. Its signature is

        > Tcl\_Obj\* *name*\_decode \(Tcl\_Interp\* interp, int flags\);

      * *name*\.h

        A header file containing the declarations for the two conversion
        functions, for use by other parts of the system, if necessary\.

        The generated file is stored in a place where it will not interfere with
        the overall system outside of the package, yet also be available for
        easy inclusion by package files \(__csources__\)\.

      * *name*

        The name of a critcl argument type encapsulating the encoder function
        for use by __critcl::cproc__\.

      * *name*

        The name of a critcl result type encapsulating the decoder function for
        use by __critcl::cproc__\.

# <a name='section3'></a>Example

The example shown below is the specification of the event flags pulled from the
draft work on a Tcl binding to Linux's inotify APIs\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::bitmap
    }

    critcl::bitmap::def tcl_inotify_events {
        accessed       IN_ACCESS
        all            IN_ALL_EVENTS
        attribute      IN_ATTRIB
        closed         IN_CLOSE
        closed-nowrite IN_CLOSE_NOWRITE
        closed-write   IN_CLOSE_WRITE
        created        IN_CREATE
        deleted        IN_DELETE
        deleted-self   IN_DELETE_SELF
        dir-only       IN_ONLYDIR
        dont-follow    IN_DONT_FOLLOW
        modified       IN_MODIFY
        move           IN_MOVE
        moved-from     IN_MOVED_FROM
        moved-self     IN_MOVE_SELF
        moved-to       IN_MOVED_TO
        oneshot        IN_ONESHOT
        open           IN_OPEN
        overflow       IN_Q_OVERFLOW
        unmount        IN_UNMOUNT
    } {
        all closed move oneshot
    }

    # Declarations:          tcl_inotify_events.h
    # Encoder:      int      tcl_inotify_events_encode (Tcl_Interp* interp, Tcl_Obj* flags, int* result);
    # Decoder:      Tcl_Obj* tcl_inotify_events_decode (Tcl_Interp* interp, int flags);
    # crit arg-type          tcl_inotify_events
    # crit res-type          tcl_inotify_events

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
