
[//000000001]: # (stooop \- Simple Tcl Only Object Oriented Programming)
[//000000002]: # (Generated from file 'stooop\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (stooop\(n\) 4\.4\.1 tcllib "Simple Tcl Only Object Oriented Programming")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

stooop \- Object oriented extension\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [DEBUGGING](#section2)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require stooop ?4\.4\.1?  

[__::stooop::class__ *name body*](#1)  
[__::stooop::new__ *class* ?*arg arg \.\.\.*?](#2)  
[__::stooop::delete__ *object* ?*object \.\.\.*?](#3)  
[__::stooop::virtual__ __proc__ *name* \{__this__ ?*arg arg \.\.\.*?\} ?*body*?](#4)  
[__::stooop::classof__ *object*](#5)  
[__::stooop::new__ *object*](#6)  
[__::stooop::printObjects__ ?*pattern*?](#7)  
[__::stooop::record__](#8)  
[__::stooop::report__ ?*pattern*?](#9)  

# <a name='description'></a>DESCRIPTION

This package provides commands to extend Tcl in an object oriented manner, using
a familiar C\+\+ like syntax and behaviour\. Stooop only introduces a few new
commands: __[class](\.\./\.\./\.\./\.\./index\.md\#class)__, __new__,
__delete__, __virtual__ and __classof__\. Along with a few coding
conventions, that is basically all you need to know to use stooop\. Stooop is
meant to be as simple to use as possible\.

This manual is very succinct and is to be used as a quick reminder for the
programmer, who should have read the thorough
[stooop\_man\.html](stooop\_man\.html) HTML documentation at this point\.

  - <a name='1'></a>__::stooop::class__ *name body*

    This command creates a class\. The body, similar in contents to a Tcl
    namespace \(which a class actually also is\), contains member procedure
    definitions\. Member procedures can also be defined outside the class body,
    by prefixing their name with __class::__, as you would proceed with
    namespace procedures\.

      * __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *class* \{__this__ ?*arg arg \.\.\.*?\} ?*base* \{?*arg arg \.\.\.*?\} \.\.\.? *body*

        This is the constructor procedure for the class\. It is invoked following
        a __new__ invocation on the class\. It must have the same name as the
        class and a first argument named __this__\. Any number of base
        classes specifications, including arguments to be passed to their
        constructor, are allowed before the actual body of the procedure\.

      * __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ ~*class* \{__this__\} *body*

        This is the destructor procedure for the class\. It is invoked following
        a __delete__ invocation\. Its name must be the concatenation of a
        single __~__ character followed by the class name \(as in C\+\+\)\. It
        must have a single argument named __this__\.

      * __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* \{__this__ ?*arg arg \.\.\.*?\} *body*

        This is a member procedure of the class, as its first argument is named
        __this__\. It allows a simple access of member data for the object
        referenced by __this__ inside the procedure\. For example:

            set ($this,data) 0

      * __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* \{?*arg arg \.\.\.*?\} *body*

        This is a static \(as in C\+\+\) member procedure of the class, as its first
        argument is not named __this__\. Static \(global\) class data can be
        accessed as in:

            set (data) 0

      * __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *class* \{__this copy__\} *body*

        This is the optional copy procedure for the class\. It must have the same
        name as the class and exactly 2 arguments named __this__ and
        __copy__\. It is invoked following a __new__ invocation on an
        existing object of the class\.

  - <a name='2'></a>__::stooop::new__ *class* ?*arg arg \.\.\.*?

    This command is used to create an object\. The first argument is the class
    name and is followed by the arguments needed by the corresponding class
    constructor\. A unique identifier for the object just created is returned\.

  - <a name='3'></a>__::stooop::delete__ *object* ?*object \.\.\.*?

    This command is used to delete one or several objects\. It takes one or more
    object identifiers as argument\(s\)\.

  - <a name='4'></a>__::stooop::virtual__ __proc__ *name* \{__this__ ?*arg arg \.\.\.*?\} ?*body*?

    The __virtual__ specifier may be used on member procedures to achieve
    dynamic binding\. A procedure in a base class can then be redefined
    \(overloaded\) in the derived class\(es\)\. If the base class procedure is
    invoked on an object, it is actually the derived class procedure which is
    invoked, if it exists\. If the base class procedure has no body, then it is
    considered to be a pure virtual and the derived class procedure is always
    invoked\.

  - <a name='5'></a>__::stooop::classof__ *object*

    This command returns the class of the existing object passed as single
    parameter\.

  - <a name='6'></a>__::stooop::new__ *object*

    This command is used to create an object by copying an existing object\. The
    copy constructor of the corresponding class is invoked if it exists,
    otherwise a simple copy of the copied object data members is performed\.

# <a name='section2'></a>DEBUGGING

  - Environment variables

      * __STOOOPCHECKDATA__

        Setting this variable to any true value will cause stooop to check for
        invalid member or class data access\.

      * __STOOOPCHECKPROCEDURES__

        Setting this variable to any true value will cause stooop to check for
        invalid member procedure arguments and pure interface classes
        instanciation\.

      * __STOOOPCHECKALL__

        Setting this variable to any true value will cause stooop to activate
        both procedure and data member checking\.

      * __STOOOPCHECKOBJECTS__

        Setting this variable to any true value will cause stooop to activate
        object checking\. The following stooop namespace procedures then become
        available for debugging: __printObjects__,
        __[record](\.\./\.\./\.\./\.\./index\.md\#record)__ and
        __[report](\.\./report/report\.md)__\.

      * __STOOOPTRACEPROCEDURES__

        Setting this environment variable to either __stdout__,
        __stderr__ or a file name, activates procedure tracing\. The stooop
        library will then output to the specified channel 1 line of
        informational text for each member procedure invocation\.

      * __STOOOPTRACEPROCEDURESFORMAT__

        Defines the trace procedures output format\. Defaults to __"class: %C,
        procedure: %p, object: %O, arguments: %a"__\.

      * __STOOOPTRACEDATA__

        Setting this environment variable to either __stdout__,
        __stderr__ or a file name, activates data tracing\. The stooop
        library will then output to the specified channel 1 line of
        informational text for each member data access\.

      * __STOOOPTRACEDATAFORMAT__

        Defines the trace data output format\. Defaults to __"class: %C,
        procedure: %p, array: %A, object: %O, member: %m, operation: %o, value:
        %v"__\.

      * __STOOOPTRACEDATAOPERATIONS__

        When tracing data output, by default, all read, write and unsetting
        accesses are reported, but the user can set this variable to any
        combination of the letters __r__, __w__, and __u__ for more
        specific tracing \(please refer to the
        __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ Tcl manual page for more
        information\)\.

      * __STOOOPTRACEALL__

        Setting this environment variable to either __stdout__,
        __stderr__ or a file name, enables both procedure and data tracing\.

  - <a name='7'></a>__::stooop::printObjects__ ?*pattern*?

    Prints an ordered list of existing objects, in creation order, oldest first\.
    Each output line contains the class name, object identifier and the
    procedure within which the creation occurred\. The optional pattern argument
    \(as in the Tcl __string match__ command\) can be used to limit the output
    to matching class names\.

  - <a name='8'></a>__::stooop::record__

    When invoked, a snapshot of all existing stooop objects is taken\. Reporting
    can then be used at a later time to see which objects were created or
    deleted in the interval\.

  - <a name='9'></a>__::stooop::report__ ?*pattern*?

    Prints the created and deleted objects since the __::stooop::record__
    procedure was invoked last\. If present, the pattern argument limits the
    output to matching class names\.

# <a name='section3'></a>EXAMPLES

Please see the full HTML documentation in
[stooop\_man\.html](stooop\_man\.html)\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *stooop* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[C\+\+](\.\./\.\./\.\./\.\./index\.md\#c\_), [class](\.\./\.\./\.\./\.\./index\.md\#class),
[object](\.\./\.\./\.\./\.\./index\.md\#object), [object
oriented](\.\./\.\./\.\./\.\./index\.md\#object\_oriented)

# <a name='category'></a>CATEGORY

Programming tools
