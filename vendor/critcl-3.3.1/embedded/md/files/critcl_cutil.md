
[//000000001]: # (critcl::cutil \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_cutil\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::cutil\(n\) 0\.3 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::cutil \- CriTcl \- C\-level Utilities

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Allocation](#section3)

  - [Assertions](#section4)

  - [Tracing](#section5)

  - [Authors](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.2?  
package require critcl::cutil ?0\.3?  

[__::critcl::cutil::alloc__](#1)  
[__::critcl::cutil::assertions__ ?*enable*?](#2)  
[__::critcl::cutil::tracer__ ?*enable*?](#3)  
[__type\* ALLOC \(type\)__](#4)  
[__type\* ALLOC\_PLUS \(type, int n\)__](#5)  
[__type\* NALLOC \(type, int n\)__](#6)  
[__type\* REALLOC \(type\* var, type, int n\)__](#7)  
[__void FREE \(type\* var\)__](#8)  
[__void STREP \(Tcl\_Obj\* o, char\* s, int len\)__](#9)  
[__void STREP\_DS \(Tcl\_Obj\* o, Tcl\_DString\* ds\)__](#10)  
[__void STRDUP \(varname, char\* str\)__](#11)  
[__void ASSERT \(expression, char\* message__](#12)  
[__void ASSERT\_BOUNDS \(int index, int size\)__](#13)  
[__void STOPAFTER\(n\)__](#14)  
[__TRACE\_ON__](#15)  
[__TRACE\_OFF__](#16)  
[__TRACE\_TAG\_ON  \(identifier\)__](#17)  
[__TRACE\_TAG\_OFF \(identifier\)__](#18)  
[__void TRACE\_FUNC__](#19)  
[__void TRACE\_TAG\_FUNC \(tag\)__](#20)  
[__void TRACE\_FUNC\_VOID__](#21)  
[__void TRACE\_TAG\_FUNC\_VOID \(tag\)__](#22)  
[__void TRACE\_RETURN\_VOID__](#23)  
[__void TRACE\_TAG\_RETURN\_VOID \(tag\)__](#24)  
[__any TRACE\_RETURN     \(     char\* format, any x\)__](#25)  
[__any TRACE\_TAG\_RETURN \(tag, char\* format, any x\)__](#26)  
[__void TRACE     \(     char\* format, \.\.\.\)__](#27)  
[__void TRACE\_TAG \(tag, char\* format, \.\.\.\)__](#28)  
[__void TRACE\_HEADER \(int indent\)__](#29)  
[__void TRACE\_TAG\_HEADER \(tag, int indent\)__](#30)  
[__void TRACE\_CLOSER__](#31)  
[__void TRACE\_TAG\_CLOSER \(tag\)__](#32)  
[__void TRACE\_ADD          \(const char\* format, \.\.\.\)__](#33)  
[__void TRACE\_TAG\_ADD \(tag, const char\* format, \.\.\.\)__](#34)  
[__void TRACE\_PUSH\_SCOPE \(const char\* name\)__](#35)  
[__void TRACE\_PUSH\_FUNC__](#36)  
[__void TRACE\_PUSH\_POP__](#37)  
[__TRACE\_TAG\_VAR \(tag\)__](#38)  
[__TRACE\_RUN \(code\);__](#39)  
[__TRACE\_DO \(code\);__](#40)  
[__TRACE\_TAG\_DO \(tag, code\);__](#41)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::cutil__ package\.
This package encapsulates a number of C\-level utilites for easier writing of
memory allocations, assertions, and narrative tracing and provides convenience
commands to make these utilities accessible to critcl projects\. Its intended
audience are mainly developers wishing to write Tcl packages with embedded C
code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png) The reason for this is that the main
__[critcl](critcl\.md)__ package makes use of the facilities for
narrative tracing when __critcl::config trace__ is set, to instrument
commands and procedures\.

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::cutil::alloc__

    This command provides a number C\-preprocessor macros which make the writing
    of memory allocations for structures and arrays of structures easier\.

    When run the header file "critcl\_alloc\.h" is directly made available to the
    "\.critcl" file containing the command, and becomes available for use in
    __\#include__ directives of companion C code declared via
    __critcl::csources__\.

    The macros definitions and their signatures are:

        type* ALLOC (type)
        type* ALLOC_PLUS (type, int n)
        type* NALLOC (type, int n)
        type* REALLOC (type* var, type, int n)
        void  FREE (type* var)

        void STREP    (Tcl_Obj* o, char* s, int len);
        void STREP_DS (Tcl_Obj* o, Tcl_DString* ds);
        void STRDUP   (varname, char* str);

    The details of the semantics are explained in section
    [Allocation](#section3)\.

    The result of the command is an empty string\.

  - <a name='2'></a>__::critcl::cutil::assertions__ ?*enable*?

    This command provides a number C\-preprocessor macros for the writing of
    assertions in C code\.

    When invoked the header file "critcl\_assert\.h" is directly made available to
    the "\.critcl" file containing the command, and becomes available for use in
    __\#include__ directives of companion C code declared via
    __critcl::csources__\.

    The macro definitions and their signatures are

        void ASSERT (expression, char* message);
        void ASSERT_BOUNDS (int index, int size);

        void STOPAFTER (int n);

    Note that these definitions are conditional on the existence of the macro
    __CRITCL\_ASSERT__\. Without a __critcl::cflags \-DCRITCL\_ASSERT__ all
    assertions in the C code are quiescent and not compiled into the object
    file\. In other words, assertions can be \(de\)activated at will during build
    time, as needed by the user\.

    For convenience this is controlled by *enable*\. By default \(__false__\)
    the facility available, but not active\. Using __true__ not only makes it
    available, but activates it as well\.

    The details of the semantics are explained in section
    [Assertions](#section4)\.

    The result of the command is an empty string\.

  - <a name='3'></a>__::critcl::cutil::tracer__ ?*enable*?

    This command provides a number C\-preprocessor macros for tracing C\-level
    internals\.

    When invoked the header file "critcl\_trace\.h" is directly made available to
    the "\.critcl" file containing the command, and becomes available for use in
    __\#include__ directives of companion C code declared via
    __critcl::csources__\. Furthermore the "\.c" file containing the runtime
    support is added to the set of C companion files

    The macro definitions and their signatures are

        /* (de)activation of named logical streams.
         * These are declarators, not statements.
         */

        TRACE_ON;
        TRACE_OFF;
        TRACE_TAG_ON  (tag_identifier);
        TRACE_TAG_OFF (tag_identifier);

        /*
         * Higher level trace statements (convenience commands)
         */

        void TRACE_FUNC   (const char* format, ...);
        void TRACE_FUNC_VOID;
        any  TRACE_RETURN (const char* format, any x);
        void TRACE_RETURN_VOID;
        void TRACE (const char* format, ...);

        /*
         * Low-level trace statements the higher level ones above
         * are composed from. Scope management and output management.
         */

        void TRACE_PUSH_SCOPE (const char* scope);
        void TRACE_PUSH_FUNC;
        void TRACE_POP;

        void TRACE_HEADER (int indent);
        void TRACE_ADD (const char* format, ...);
        void TRACE_CLOSER;

        /*
         * Convert tag to the underlying status variable.
         */

        TRACE_TAG_VAR (tag)

        /*
         * Conditional use of arbitrary code.
         */

        TRACE_RUN (code);
        TRACE_DO (code);
        TRACE_TAG_DO (code);

    Note that these definitions are conditional on the existence of the macro
    __CRITCL\_TRACER__\. Without a __critcl::cflags \-DCRITCL\_TRACER__ all
    trace functionality in the C code is quiescent and not compiled into the
    object file\. In other words, tracing can be \(de\)activated at will during
    build time, as needed by the user\.

    For convenience this is controlled by *enable*\. By default \(__false__\)
    the facility available, but not active\. Using __true__ not only makes it
    available, but activates it as well\. Further note that the command
    __critcl::config__ now accepts a boolean option __trace__\. Setting
    it activates enter/exit tracing in all commands based on
    __critcl::cproc__, with proper printing of arguments and results\. This
    implicitly activates the tracing facility in general\.

    The details of the semantics are explained in section
    [Tracing](#section5)

    The result of the command is an empty string\.

# <a name='section3'></a>Allocation

  - <a name='4'></a>__type\* ALLOC \(type\)__

    This macro allocates a single element of the given *type* and returns a
    pointer to that memory\.

  - <a name='5'></a>__type\* ALLOC\_PLUS \(type, int n\)__

    This macro allocates a single element of the given *type*, plus an
    additional *n* bytes after the structure and returns a pointer to that
    memory\.

    This is for variable\-sized structures of\. An example of such could be a
    generic list element structure which stores management information in the
    structure itself, and the value/payload immediately after, in the same
    memory block\.

  - <a name='6'></a>__type\* NALLOC \(type, int n\)__

    This macro allocates *n* elements of the given *type* and returns a
    pointer to that memory\.

  - <a name='7'></a>__type\* REALLOC \(type\* var, type, int n\)__

    This macro expands or shrinks the memory associated with the C variable
    *var* of type *type* to hold *n* elements of the type\. It returns a
    pointer to that memory\. Remember, a reallocation may move the data to a new
    location in memory to satisfy the request\. Returning a pointer instead of
    immediately assigning it to the *var* allows the user to validate the new
    pointer before trying to use it\.

  - <a name='8'></a>__void FREE \(type\* var\)__

    This macro releases the memory referenced by the pointer variable *var*\.

  - <a name='9'></a>__void STREP \(Tcl\_Obj\* o, char\* s, int len\)__

    This macro properly sets the string representation of the Tcl object *o*
    to a copy of the string *s*, expected to be of length *len*\.

  - <a name='10'></a>__void STREP\_DS \(Tcl\_Obj\* o, Tcl\_DString\* ds\)__

    This macro properly sets the string representation of the Tcl object *o*
    to a copy of the string held by the __DString__ *ds*\.

  - <a name='11'></a>__void STRDUP \(varname, char\* str\)__

    This macro duplicates the string *str* into the heap and stores the result
    into the named __char\*__ variable *var*\.

# <a name='section4'></a>Assertions

  - <a name='12'></a>__void ASSERT \(expression, char\* message__

    This macro tests the *expression* and panics if it does not hold\. The
    specified *message* is used as part of the panic\. The *message* has to
    be a static string, it cannot be a variable\.

  - <a name='13'></a>__void ASSERT\_BOUNDS \(int index, int size\)__

    This macro ensures that the *index* is in the range __0__ to
    __size\-1__\.

  - <a name='14'></a>__void STOPAFTER\(n\)__

    This macro throws a panic after it is called *n* times\. Note, each
    separate instance of the macro has its own counter\.

# <a name='section5'></a>Tracing

All output is printed to __stdout__\.

  - <a name='15'></a>__TRACE\_ON__

  - <a name='16'></a>__TRACE\_OFF__

  - <a name='17'></a>__TRACE\_TAG\_ON  \(identifier\)__

  - <a name='18'></a>__TRACE\_TAG\_OFF \(identifier\)__

    These "commands" are actually declarators, for use outside of functions\.
    They \(de\)activate specific logical streams, named either explicitly by the
    user, or implicitly, refering to the current file\.

    For example:

        TRACE_TAG_ON (lexer_in);

    All high\- and low\-level trace commands producing output have the controlling
    tag as an implicit argument\. The scope management commands do not take tags\.

  - <a name='19'></a>__void TRACE\_FUNC__

  - <a name='20'></a>__void TRACE\_TAG\_FUNC \(tag\)__

  - <a name='21'></a>__void TRACE\_FUNC\_VOID__

  - <a name='22'></a>__void TRACE\_TAG\_FUNC\_VOID \(tag\)__

    Use these macros at the beginning of a C function to record entry into it\.
    The name of the entered function is an implicit argument \(__\_\_func\_\___\),
    forcing users to have a C99 compiler\.\.

    The tracer's runtime maintains a stack of active functions and expects that
    function return is signaled by either __TRACE\_RETURN__,
    __TRACE\_RETURN\_VOID__, or the equivalent forms taking a tag\.

  - <a name='23'></a>__void TRACE\_RETURN\_VOID__

  - <a name='24'></a>__void TRACE\_TAG\_RETURN\_VOID \(tag\)__

    Use these macros instead of

        return

    to return from a void function\. Beyond returning from the function this also
    signals the same to the tracer's runtime, popping the last entered function
    from its stack of active functions\.

  - <a name='25'></a>__any TRACE\_RETURN     \(     char\* format, any x\)__

  - <a name='26'></a>__any TRACE\_TAG\_RETURN \(tag, char\* format, any x\)__

    Use this macro instead of

        return x

    to return from a non\-void function\. Beyond returning from the function with
    value *x* this also signals the same to the tracer's runtime, popping the
    last entered function from its stack of active functions\. The *format* is
    expected to be a proper formatting string for __printf__ and analogues,
    able to stringify *x*\.

  - <a name='27'></a>__void TRACE     \(     char\* format, \.\.\.\)__

  - <a name='28'></a>__void TRACE\_TAG \(tag, char\* format, \.\.\.\)__

    This macro is the trace facilities' equivalent of __printf__, printing
    arbitrary data under the control of the *format*\.

    The printed text is closed with a newline, and indented as per the stack of
    active functions\.

  - <a name='29'></a>__void TRACE\_HEADER \(int indent\)__

  - <a name='30'></a>__void TRACE\_TAG\_HEADER \(tag, int indent\)__

    This is the low\-level macro which prints the beginning of a trace line\. This
    prefix consists of physical location \(file name and line number\), if
    available, indentation as per the stack of active scopes \(if activated\), and
    the name of the active scope\.

  - <a name='31'></a>__void TRACE\_CLOSER__

  - <a name='32'></a>__void TRACE\_TAG\_CLOSER \(tag\)__

    This is the low\-level macro which prints the end of a trace line\.

  - <a name='33'></a>__void TRACE\_ADD          \(const char\* format, \.\.\.\)__

  - <a name='34'></a>__void TRACE\_TAG\_ADD \(tag, const char\* format, \.\.\.\)__

    This is the low\-level macro which adds formatted data to the line\.

  - <a name='35'></a>__void TRACE\_PUSH\_SCOPE \(const char\* name\)__

  - <a name='36'></a>__void TRACE\_PUSH\_FUNC__

  - <a name='37'></a>__void TRACE\_PUSH\_POP__

    These are the low\-level macros for scope management\. The first two forms
    push a new scope on the stack of active scopes, and the last forms pops the
    last scope pushed\.

  - <a name='38'></a>__TRACE\_TAG\_VAR \(tag\)__

    Helper macro converting from a tag identifier to the name of the underlying
    status variable\.

  - <a name='39'></a>__TRACE\_RUN \(code\);__

    Conditionally insert the *code* at compile time when the tracing facility
    is activated\.

  - <a name='40'></a>__TRACE\_DO \(code\);__

  - <a name='41'></a>__TRACE\_TAG\_DO \(tag, code\);__

    Insert the *code* at compile time when the tracing facility is activated,
    and execute the same when either the implicit tag for the file or the
    user\-specified tag is active\.

# <a name='section6'></a>Authors

Andreas Kupries

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such at
[https://github\.com/andreas\-kupries/critcl](https://github\.com/andreas\-kupries/critcl)\.
Please also report any ideas for enhancements you may have for either package
and/or documentation\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [code
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

Copyright &copy; 2011\-2024 Andreas Kupries
