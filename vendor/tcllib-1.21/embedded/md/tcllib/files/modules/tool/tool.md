
[//000000001]: # (tool \- Standardized OO Framework for development)
[//000000002]: # (Generated from file 'tool\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (tool\(n\) 0\.4\.2 tcllib "Standardized OO Framework for development")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tool \- TclOO Library \(TOOL\) Framework

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Keywords](#section2)

  - [Public Object Methods](#section3)

  - [Private Object Methods](#section4)

  - [AUTHORS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require sha1  
package require dicttool  
package require oo::meta  
package require oo::dialect  

[tool::define __class\_method__ *arglist* *body*](#1)  
[tool::define __[array](\.\./\.\./\.\./\.\./index\.md\#array)__ *name* *contents*](#2)  
[tool::define __array\_ensemble__ *methodname* *varname* ?cases?](#3)  
[tool::define __dict\_ensemble__ *methodname* *varname* ?cases?](#4)  
[tool::define __[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *methodname* *arglist* *body*](#5)  
[tool::define __option__ *name* *dictopts*](#6)  
[tool::define __property__ ?branch? *field* *value*](#7)  
[tool::define __variable__ *name* *value*](#8)  
[*object* __cget__ *option*](#9)  
[*object* __configure__ ?keyvaluelist?](#10)  
[*object* __configure__ *field* *value* ?field? ?value? ?\.\.\.?](#11)  
[*object* __configurelist__ ?keyvaluelist?](#12)  
[*object* __forward__ *stub* *forward*](#13)  
[*object* __graft__ *stub* *forward*](#14)  
[*object* __InitializePublic__](#15)  
[*object* __Eval\_Script__ ?script?](#16)  
[*object* __Option\_Default__ *field*](#17)  

# <a name='description'></a>DESCRIPTION

This module implements the Tcl Object Oriented Library framework, or *TOOL*\.
It is intended to be a general purpose framework that is useable in its own
right, and easily extensible\.

TOOL defines a metaclass with provides several additional keywords to the TclOO
description langauge, default behaviors for its consituent objects, and top\-down
integration with the capabilities provided by the __oo::meta__ package\.

The TOOL metaclass was build with the __oo::dialect__ package, and thus can
be used as the basis for additional metaclasses\. As a metaclass, TOOL has it's
own "class" class, "object" class, and define namespace\.

    package require tool

    # tool::class workds just like oo::class
    tool::class create myclass {
    }

    # tool::define works just like oo::define
    tool::define myclass method noop {} {}

    # tool::define and tool::class understand additional keywords
    tool::define myclass array_ensemble mysettings mysettings {}

    # And tool interoperates with oo::define
    oo::define myclass method do_something {} { return something }

    # TOOL and TclOO objects are interchangeable
    oo::class create myooclass {
      superclass myclass
    }

Several manual pages go into more detail about specific keywords and methods\.

  - __tool::array\_ensemble__

  - __[tool::dict\_ensemble](tool\_dict\_ensemble\.md)__

  - __tool::method\_ensemble__

  - __tool::object__

  - __tool::option\_handling__

# <a name='section2'></a>Keywords

TOOL adds new \(or modifies\) keywords used in the definitions of classes\.
However, the new keywords are only available via calls to *tool::class create*
or *tool::define*

  - <a name='1'></a>tool::define __class\_method__ *arglist* *body*

    Defines a method for the class object itself\. This method will be passed on
    to descendents of the class, unlike __self method__\.

  - <a name='2'></a>tool::define __[array](\.\./\.\./\.\./\.\./index\.md\#array)__ *name* *contents*

    Declares a variable *name* which will be initialized as an array,
    populated with *contents* for objects of this class, as well as any
    objects for classes which are descendents of this class\.

  - <a name='3'></a>tool::define __array\_ensemble__ *methodname* *varname* ?cases?

    Declares a method ensemble *methodname* which will control access to
    variable *varname*\. Cases are a key/value list of method names and bodies
    which will be overlaid on top of the standard template\. See
    __tool::array\_ensemble__\.

    One method name is reserved: __initialize__\. __initialize__ Declares
    the initial values to be populated in the array, as a key/value list, and
    will not be expressed as a method for the ensemble\.

  - <a name='4'></a>tool::define __dict\_ensemble__ *methodname* *varname* ?cases?

    Declares a method ensemble *methodname* which will control access to
    variable *varname*\. Cases are a key/value list of method names and bodies
    which will be overlaid on top of the standard template\. See
    __[tool::dict\_ensemble](tool\_dict\_ensemble\.md)__\.

    One method name is reserved: __initialize__\. __initialize__ Declares
    the initial values to be populated in the array, as a key/value list, and
    will not be expressed as a method for the ensemble\.

  - <a name='5'></a>tool::define __[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *methodname* *arglist* *body*

    If *methodname* contains ::, the method is considered to be part of a
    method ensemble\. See __tool::method\_ensembles__\. Otherwise this command
    behaves exactly like the standard __oo::define__
    __[method](\.\./\.\./\.\./\.\./index\.md\#method)__ command\.

  - <a name='6'></a>tool::define __option__ *name* *dictopts*

    Declares an option\. *dictopts* is a key/value list defining parameters for
    the option\. See __tool::option\_handling__\.

    tool::class create myclass {
      option color {
        post-command: {puts [list %self%'s %field% is now %value%]}
        default: green
      }
    }
    myclass create foo
    foo configure color purple
    > foo's color is now purple

  - <a name='7'></a>tool::define __property__ ?branch? *field* *value*

    Defines a new leaf in the class metadata tree\. With no branch, the leaf will
    appear in the *const* section, accessible by either the object's
    __property__ method, or via __oo::meta::info__ *class* __get
    const__ *field*:

  - <a name='8'></a>tool::define __variable__ *name* *value*

    Declares a variable *name* which will be initialized with the value
    *value* for objects of this class, as well as any objects for classes
    which are descendents of this class\.

# <a name='section3'></a>Public Object Methods

The TOOL object mother of all classes defines several methods to enforces
consistent behavior throughout the framework\.

  - <a name='9'></a>*object* __cget__ *option*

    Return the value of this object's option *option*\. If the __property
    options\_strict__ is true for this class, calling an option which was not
    declared by the __option__ keyword will throw an error\. In all other
    cases if the value is present in the object's *options* array that value
    is returned\. If it does not exist, the object will attempt to retrieve a
    property of the same name\.

  - <a name='10'></a>*object* __configure__ ?keyvaluelist?

  - <a name='11'></a>*object* __configure__ *field* *value* ?field? ?value? ?\.\.\.?

    This command will inject new values into the objects *options* array,
    according to the rules as set forth by the option descriptions\. See
    __tool::option\_handling__ for details\. __configure__ will strip
    leading \-'s off of field names, allowing it to behave in a quasi\-backward
    compatible manner to tk options\.

  - <a name='12'></a>*object* __configurelist__ ?keyvaluelist?

    This command will inject new values into the objects *options* array,
    according to the rules as set forth by the option descriptions\. This command
    will perform validation and alternate storage rules\. It will not invoke
    trigger rules\. See __tool::option\_handling__ for details\.

  - <a name='13'></a>*object* __forward__ *stub* *forward*

    A passthrough to __oo:objdefine \[self\] forward__

  - <a name='14'></a>*object* __graft__ *stub* *forward*

    Delegates the *<stub>* method to the object or command designated by
    *forward*

    tool::object create A
    tool::object create B
    A graft buddy B
    A configure color red
    B configure color blue
    A cget color
    > red
    A <buddy> cget color
    > blue

# <a name='section4'></a>Private Object Methods

  - <a name='15'></a>*object* __InitializePublic__

    Consults the metadata for the class to ensure every array, option, and
    variable which has been declared but not initialized is initialized with the
    default value\. This method is called by the constructor and the morph
    method\. It is safe to invoke multiple times\.

  - <a name='16'></a>*object* __Eval\_Script__ ?script?

    Executes a block of text within the namespace of the object\. Lines that
    begin with a \# are ignored as comments\. Commands that begin with :: are
    interpreted as calling a global command\. All other Tcl commands that lack a
    "my" prefix are given one, to allow the script to exercise internal methods\.
    This method is intended for configuration scripts, where the object's
    methods are intepreting a domain specific language\.

    tool::class myclass {
      constructor script {
        my Eval_Script $script
      }
      method node {nodename info} {
        my variable node
        dict set node $nodename $info
      }
      method get {args} {
        my variable node
        return [dict get $node $args]
      }
    }
    myclass create movies {
      # This block of code is executed by the object
      node {The Day the Earth Stood Still} {
        date: 1952
        characters: {GORT Klatoo}
      }
    }
    movies get {The Day the Earth Stood Still} date:
    > 1952

  - <a name='17'></a>*object* __Option\_Default__ *field*

    Computes the default value for an option\. See __tool::option\_handling__\.

# <a name='section5'></a>AUTHORS

Sean Woods

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tcloo* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[TOOL](\.\./\.\./\.\./\.\./index\.md\#tool), [TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo),
[framework](\.\./\.\./\.\./\.\./index\.md\#framework)

# <a name='category'></a>CATEGORY

TclOO

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>
