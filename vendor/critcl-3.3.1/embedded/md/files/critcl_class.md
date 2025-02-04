
[//000000001]: # (critcl::class \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_class\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000004]: # (critcl::class\(n\) 1\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl::class \- CriTcl \- Code Gen \- C Classes

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Class Specification API](#section3)

      - [General configuration](#subsection1)

      - [Class lifetime management](#subsection2)

      - [Instance lifetime management](#subsection3)

      - [Class variables and methods](#subsection4)

      - [Instance variables and methods](#subsection5)

      - [Context dependent interactions](#subsection6)

  - [Example](#section4)

  - [Authors](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require critcl ?3\.2?  
package require critcl::class ?1\.1?  

[__::critcl::class::define__ *name* *script*](#1)  
[__include__ *path*](#2)  
[__support__ *code*](#3)  
[__type__ *name*](#4)  
[__classconstructor__ *body*](#5)  
[__classdestructor__ *body*](#6)  
[__constructor__ *body* ?*postbody*?](#7)  
[__destructor__ *body*](#8)  
[__classvariable__ *ctype* *name* ?*comment*? ?*constructor*? ?*destructor*?](#9)  
[__classmethod__ *name* __command__ *arguments* *body*](#10)  
[__classmethod__ *name* __proc__ *arguments* *resulttype* *body*](#11)  
[__classmethod__ *name* __as__ *funname* ?*arg*\.\.\.?](#12)  
[__insvariable__ *ctype* *name* ?*comment*? ?*constructor*? ?*destructor*?](#13)  
[__method__ *name* __command__ *arguments* *body*](#14)  
[__method__ *name* __proc__ *arguments* *resulttype* *body*](#15)  
[__method__ *name* __as__ *funname* ?*arg*\.\.\.?](#16)  
[__method\_introspection__](#17)  

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

This document is the reference manpage for the __critcl::class__ package\.
This package provides convenience commands for advanced functionality built on
top of the core\.

With it a user wishing to create a C level object with class and instance
commands can concentrate on specifying the class\- and instance\-variables and
\-methods in a manner similar to a TclOO class, while all the necessary
boilerplate around it is managed by this package\.

Its intended audience are mainly developers wishing to write Tcl packages with
embedded C code\.

This package resides in the Core Package Layer of CriTcl\.

![](\.\./image/arch\_core\.png)

# <a name='section2'></a>API

  - <a name='1'></a>__::critcl::class::define__ *name* *script*

    This is the main command to define a new class *name*, where *name* is
    the name of the Tcl command representing the class, i\.e\. the *class
    command*\. The *script* provides the specification of the class, i\.e\.
    information about included headers, class\- and instance variables, class\-
    and instance\-methods, etc\. See the section [Class Specification
    API](#section3) below for the detailed list of the available commands
    and their semantics\.

# <a name='section3'></a>Class Specification API

Here we documents all class specification commands available inside of the class
definition script argument of __::critcl::class::define__\.

## <a name='subsection1'></a>General configuration

  - <a name='2'></a>__include__ *path*

    This command specifies the path of a header file to include within the code
    generated for the class\. This is separate from the __support__ because
    the generated include directives will be put at the very beginning of the
    generated code\. This is done to allow the use of the imported declarations
    within the instance type, and elsewhere\.

    Calls to this command are cumulative\. It is of course possible to not use
    this command at all, for classes not making use of external definitions\.

    The result is the empty string\.

  - <a name='3'></a>__support__ *code*

    This command specifies supporting C code, i\.e\. any definitions \(types,
    functions, etc\.\) needed by the *whole* class and not fitting into class\-
    and instance\-methods\. The code is embedded at global level, outside of any
    function or other definition\.

    Calls to this command are cumulative\. It is of course possible to not use
    this command at all, for classes not requiring supporting code\.

    The result of the command is the empty string\.

  - <a name='4'></a>__type__ *name*

    This command specifies the name of an external C type to be used as the type
    of the instance structure\.

    Initialization and release of the structure with the given type are the
    responsibility of the user, through __constructor__ and
    __destructor__ code fragments\.

    *Attention:* Using this command precludes the use of regular class\- and
    instance variables\. It further precludes the use of
    __method\-introspection__ as well, as this make use of generated
    instance\-variables\.

    If class\- and/or instance\-variable have to be used in conjunction with an
    external C type, simply create and use a class\- or instance\-variable with
    that type\.

    The result of the command is the empty string\.

## <a name='subsection2'></a>Class lifetime management

  - <a name='5'></a>__classconstructor__ *body*

    This command specifies a C code block surrounding the initialization of the
    class variables, i\.e\. the fields of the class structure\. *Note* that
    allocation and release of the class structure itself is done by the system
    andf not the responsibility of the user\.

    For the initialization \(and release\) of a class variable it is recommended
    to use the *constructor* and *destructor* arguments of the variable's
    definition \(See command __classvariable__\) for this instead of using a
    separate __classconstructor__\.

    This is an optional command\. Using it more than once is allowed too and each
    use will add another C code fragment to use during construction\. I\.e\.
    multiple calls aggregate\.

    The C code blocks of multiple calls \(including the constructors of
    classvariable definitions\) are executed in order of specification\.

    The result of the command is the empty string\.

    The C code in *body* has access to the following environment:

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the class structure will be
        associated with\. It enables the generation of a Tcl error message should
        construction fail\.

      * __class__

        Pointer to the class structure to initialize\.

      * error

        A C code label the constructor can jump to should it have to signal a
        construction failure\. It is the responsibility of the constructor to
        release any variables already initialized before jumping to this label\.
        This also why the 'execution in order of specification' is documented
        and can be relied on\. It gives us the knowledge which other constructors
        have already been run and initialized what other fields\.

  - <a name='6'></a>__classdestructor__ *body*

    This command specifies a C code block surrounding the release of the class
    variables, i\.e\. the fields of the class structure\. *Note* that allocation
    and release of the class structure itself is done by the system and not the
    responsibility of the user\.

    For the initialization \(and release\) of a class variable it is recommended
    to use the *constructor* and *destructor* arguments of the variable's
    definition \(See command __classvariable__\) for this instead of using a
    separate __classconstructor__\.

    This is an optional command\. Using it more than once is allowed too and each
    use will add another C code fragment to use during construction\. I\.e\.
    multiple calls aggregate\.

    The C code blocks of multiple calls \(including the constructors of class
    variable definitions\) are executed in order of specification\.

    The result of the command is the empty string\.

    The C code in *body* has access to the same environment as the class
    constructor code blocks\.

## <a name='subsection3'></a>Instance lifetime management

  - <a name='7'></a>__constructor__ *body* ?*postbody*?

    This command specifies a C code block surrounding the initialization of the
    instance variables, i\.e\. the fields of the instance structure\. *Note* that
    allocation and release of the instance structure itself is done by the
    system and not the responsibility of the user\. *On the other hand*, if an
    external __type__ was specified for the instance structure, then
    instance variables are not possible, and the system has no knowledge of the
    type's structure\. In that case it is the responsibility of the *body* to
    allocate and free the structure itself too\.

    For the initialization \(and release\) of an instance variable it is
    recommended to use the *constructor* and *destructor* arguments of the
    variable's definition \(See command __insvariable__\) for this instead of
    using a separate __constructor__\.

    This is an optional command\. Using it more than once is allowed too and each
    use will add another C code fragment to use during construction\. I\.e\.
    multiple calls aggregate\.

    The C code blocks of multiple calls \(including the constructors of instance
    variable definitions\) are executed in order of specification\.

    The result of the command is the empty string\.

    The C code in *body* has access to the following environment:

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the instance structure will
        be associated with\. It enables the generation of a Tcl error message
        should construction fail\.

      * __instance__

        Pointer to the instance structure to initialize\.

      * error

        A C code label the constructor can jump to should it have to signal a
        construction failure\. It is the responsibility of the constructor to
        release any variables already initialized before jumping to this label\.
        This also why the 'execution in order of specification' is documented
        and can be relied on\. It gives us the knowledge which other constructors
        have already been run and initialized what other fields\.

    The C code in *postbody* is responsible for construction actions to be
    done after the primary construction was done and the Tcl\-level instance
    command was successfully created\. It has access to a slightly different
    environment:

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the instance structure will
        be associated with\. It enables the generation of a Tcl error message
        should construction fail\.

      * __instance__

        Pointer to the instance structure to initialize\.

      * __cmd__

        The Tcl\_Command token of the Tcl\-level instance command\.

      * __fqn__

        The fully qualified name of the instance command, stored in a Tcl\_Obj\*\.

  - <a name='8'></a>__destructor__ *body*

    This command specifies a C code block surrounding the release of the
    instance variables, i\.e\. the fields of the instance structure\. *Note* that
    allocation and release of the instance structure itself is done by the
    system and not the responsibility of the user\. *On the other hand*, if an
    external __type__ was specified for the instance structure, then
    instance variables are not possible, and the system has no knowledge of the
    type's structure\. In that case it is the responsibility of the *body* to
    allocate and free the structure itself too\.

    For the initialization \(and release\) of an instance variable it is
    recommended to use the *constructor* and *destructor* arguments of the
    variable's definition \(See command __insvariable__\) for this instead of
    using a separate __constructor__\.

    This is an optional command\. Using it more than once is allowed too and each
    use will add another C code fragment to use during construction\. I\.e\.
    multiple calls aggregate\.

    The C code blocks of multiple calls \(including the constructors of instance
    variable definitions\) are executed in order of specification\.

    The result of the command is the empty string\.

    The C code in *body* has access to the following environment:

      * __instance__

        Pointer to the instance structure to release\.

## <a name='subsection4'></a>Class variables and methods

  - <a name='9'></a>__classvariable__ *ctype* *name* ?*comment*? ?*constructor*? ?*destructor*?

    This command specifies a field in the class structure of the class\. Multiple
    fields can be specified, and are saved in the order specified\.

    *Attention:* Specification of a class variable precludes the use of an
    external C __type__ for the instance structure\.

    *Attention:* Specification of a class variable automatically causes the
    definition of an instance variable named __class__, pointing to the
    class structure\.

    Beyond the basic *name* and C type of the new variable the definition may
    also contain a *comment* describing it, and C code blocks to initialize
    and release the variable\. These are effectively local forms of the commands
    __classconstructor__ and __classdestructor__\. Please read their
    descriptions for details regarding the C environment available to the code\.

    The comment, if specified will be embedded into the generated C code for
    easier cross\-referencing from generated "\.c" file to class specification\.

  - <a name='10'></a>__classmethod__ *name* __command__ *arguments* *body*

    This command specifies a class method and the C code block implementing its
    functionality\. This is the first of three forms\. The method is specified
    like a __critcl::ccommand__, with a fixed set of C\-level arguments\. The
    *body* has to perform everything \(i\.e\. argument extraction, checking,
    result return, and of course the actual functionality\) by itself\.

    For this the *body* has access to

      * __class__

        Pointer to the class structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the class structure is
        associated with

      * __objc__

        The number of method arguments\.

      * __objv__

        The method arguments, as C array of Tcl\_Obj pointers\.

    The *arguments* of the definition are only a human readable form of the
    method arguments and syntax and are not used in the C code, except as
    comments put into the generated code\. Again, it is the responsibility of the
    *body* to check the number of arguments, extract them, check their types,
    etc\.

  - <a name='11'></a>__classmethod__ *name* __proc__ *arguments* *resulttype* *body*

    This command specifies a class method and the C code block implementing its
    functionality\. This is the second of three forms\. The method is specified
    like a __critcl::cproc__\. Contrary to the first variant here the
    *arguments* are computer readable, expected to be in the same format as
    the *arguments* of __critcl::cproc__\. The same is true for the
    *resulttype*\. The system automatically generates a wrapper doing argument
    checking and conversion, and result conversion, like for
    __critcl::cproc__\.

    The *body* has access to

      * __class__

        Pointer to the class structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the class structure is
        associated with

      * \.\.\.

        All *arguments* under their specified names and C types as per their
        definition\.

  - <a name='12'></a>__classmethod__ *name* __as__ *funname* ?*arg*\.\.\.?

    This command specifies a class method and the C code block implementing its
    functionality\. This is the third and last of three forms\.

    The class method is implemented by the external function *funname*, i\.e\. a
    function which is declared outside of the class code itself, or in a
    __support__ block\.

    It is assumed that the first four arguments of that function represent the
    parameters

      * __class__

        Pointer to the class structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the class structure is
        associated with

      * __objc__

        The number of method arguments\.

      * __objv__

        The method arguments, as C array of Tcl\_Obj pointers\.

    Any additional arguments specified will be added after these and are passed
    into the C code as is, i\.e\. are considered to be C expressions\.

## <a name='subsection5'></a>Instance variables and methods

  - <a name='13'></a>__insvariable__ *ctype* *name* ?*comment*? ?*constructor*? ?*destructor*?

    This command specifies a field in the instance structure of the class\.
    Multiple fields can be specified, and are saved in the order specified\.

    *Attention:* Specification of an instance variable precludes the use of an
    external C __type__ for the instance structure\.

    *Attention:* Specification of an instance variable automatically causes
    the definition of an instance variable of type __Tcl\_Command__, and
    named __cmd__, holding the token of the instance command, and the
    definition of an instance method named __destroy__\. This implicit
    instance variable is managed by the system\.

    Beyond the basic *name* and C type of the new variable the definition may
    also contain a *comment* describing it, and C code blocks to initialize
    and release the variable\. These are effectively local forms of the commands
    __constructor__ and __destructor__\. Please read their descriptions
    for details regarding the C environment available to the code\.

    The comment, if specified will be embedded into the generated C code for
    easier cross\-referencing from generated "\.c" file to class specification\.

  - <a name='14'></a>__method__ *name* __command__ *arguments* *body*

    This command specifies an instance method and the C code block implementing
    its functionality\. This is the first of three forms\. The method is specified
    like a __critcl::ccommand__, with a fixed set of C\-level arguments\. The
    *body* has to perform everything \(i\.e\. argument extraction, checking,
    result return, and of course the actual functionality\) by itself\.

    For this the *body* has access to

      * __instance__

        Pointer to the instance structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the instance structure is
        associated with

      * __objc__

        The number of method arguments\.

      * __objv__

        The method arguments, as C array of Tcl\_Obj pointers\.

    The *arguments* of the definition are only a human readable form of the
    method arguments and syntax and are not used in the C code, except as
    comments put into the generated code\. Again, it is the responsibility of the
    *body* to check the number of arguments, extract them, check their types,
    etc\.

  - <a name='15'></a>__method__ *name* __proc__ *arguments* *resulttype* *body*

    This command specifies an instance method and the C code block implementing
    its functionality\. This is the second of three forms\. The method is
    specified like a __critcl::cproc__\. Contrary to the first variant here
    the *arguments* are computer readable, expected to be in the same format
    as the *arguments* of __critcl::cproc__\. The same is true for the
    *resulttype*\. The system automatically generates a wrapper doing argument
    checking and conversion, and result conversion, like for
    __critcl::cproc__\.

    The *body* has access to

      * __instance__

        Pointer to the instance structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the instance structure is
        associated with

      * \.\.\.

        All *arguments* under their specified names and C types as per their
        definition\.

  - <a name='16'></a>__method__ *name* __as__ *funname* ?*arg*\.\.\.?

    This command specifies an instance method and the C code block implementing
    its functionality\. This is the third and last of three forms\.

    The instance method is implemented by the external function *funname*,
    i\.e\. a function which is declared outside of the instance code itself, or in
    a __support__ block\.

    It is assumed that the first four arguments of that function represent the
    parameters

      * __instance__

        Pointer to the instance structure\.

      * __interp__

        Pointer to the Tcl interpreter \(Tcl\_Interp\*\) the instance structure is
        associated with

      * __objc__

        The number of method arguments\.

      * __objv__

        The method arguments, as C array of Tcl\_Obj pointers\.

    Any additional arguments specified will be added after these and are passed
    into the C code as is, i\.e\. are considered to be C expressions\.

  - <a name='17'></a>__method\_introspection__

    This command generates one class\- and one instance\-method both of which will
    return a list of the instance methods of the class, and supporting
    structures, like the function to compute the information, and a class
    variable caching it\.

    The two methods and the class variable are all named __methods__\.

## <a name='subsection6'></a>Context dependent interactions

This section documents the various interactions between the specification
commands\. While these are are all documented with the individual commands here
they are pulled together to see at a glance\.

  1. If you are using the command __type__ to specify an external C type to
     use for the instance structure you are subject to the following constraints
     and rules:

       1) You cannot define your own instance variables\.

       1) You cannot define your own class variables\.

       1) You cannot use __method\_introspection__\.

       1) You have to allocate and release the instance structure on your own,
          through __constructor__ and __destructor__ code blocks\.

  1. If you declare class variables you are subject to the following constraints
     and rules:

       1) You cannot use __type__\.

       1) The system generates an instance variable __class__ for you, which
          points from instance to class structure\. This makes you also subject
          to the rules below, for instance variables\.

  1. If you declare instance variables \(possibly automatic, see above\) you are
     subject to following constraints and rules:

       1) You cannot use __type__\.

       1) The system generates and manages an instance variable __cmd__ for
          you, which holds the Tcl\_Command token of the instance command\.

       1) The system generates an instance method __destroy__ for you\.

       1) The system manages allocation and release of the instance structure
          for you\. You have to care only about the instance variables
          themselves\.

# <a name='section4'></a>Example

The example shown below is the specification of queue data structure, with most
of the method implementations and support code omitted to keep the size down\.

The full implementation can be found in the directory "examples/queue" of the
critcl source distribution/repository\.

    package require Tcl 8.6
    package require critcl 3.2

    critcl::buildrequirement {
        package require critcl::class ; # DSL, easy spec of Tcl class/object commands.
    }

    critcl::cheaders util.h

    critcl::class::define ::queuec {
        include util.h

        insvariable Tcl_Obj* unget {
    	List object unget elements
        } {
    	instance->unget = Tcl_NewListObj (0,NULL);
    	Tcl_IncrRefCount (instance->unget);
        } {
    	Tcl_DecrRefCount (instance->unget);
        }

        insvariable Tcl_Obj* queue {
    	List object holding the main queue
        } {
    	instance->queue = Tcl_NewListObj (0,NULL);
    	Tcl_IncrRefCount (instance->queue);
        } {
    	Tcl_DecrRefCount (instance->queue);
        }

        insvariable Tcl_Obj* append {
    	List object holding new elements
        } {
    	instance->append = Tcl_NewListObj (0,NULL);
    	Tcl_IncrRefCount (instance->append);
        } {
    	Tcl_DecrRefCount (instance->append);
        }

        insvariable int at {
    	Index of next element to return from the main queue
        } {
    	instance->at = 0;
        }

        support {... queue_peekget, queue_size, etc.}

        method clear {} {...}
        method destroy {...}

        method get  as queue_peekget 1
        method peek as queue_peekget 0

        method put {item ...}

        method size {} {
    	if ((objc != 2)) {
    	    Tcl_WrongNumArgs (interp, 2, objv, NULL);
    	    return TCL_ERROR;
    	}

    	Tcl_SetObjResult (interp, Tcl_NewIntObj (queue_size (instance, NULL, NULL, NULL)));
    	return TCL_OK;
        }

        method unget {item} {...}
    }

    package provide queuec 1

# <a name='section5'></a>Authors

Andreas Kupries

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such at
[https://github\.com/andreas\-kupries/critcl](https://github\.com/andreas\-kupries/critcl)\.
Please also report any ideas for enhancements you may have for either package
and/or documentation\.

# <a name='keywords'></a>KEYWORDS

[C class](\.\./index\.md\#c\_class), [C code](\.\./index\.md\#c\_code), [C
instance](\.\./index\.md\#c\_instance), [C object](\.\./index\.md\#c\_object),
[Embedded C Code](\.\./index\.md\#embedded\_c\_code), [code
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
