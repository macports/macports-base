
[//000000001]: # (snit \- Snit's Not Incr Tcl, OO system)
[//000000002]: # (Generated from file 'snit\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003\-2009, by William H\. Duquette)
[//000000004]: # (snit\(n\) 2\.3\.2 tcllib "Snit's Not Incr Tcl, OO system")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

snit \- Snit's Not Incr Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [SNIT VERSIONS](#section2)

  - [REFERENCE](#section3)

      - [Type and Widget Definitions](#subsection1)

      - [The Type Command](#subsection2)

      - [Standard Type Methods](#subsection3)

      - [The Instance Command](#subsection4)

      - [Standard Instance Methods](#subsection5)

      - [Commands for use in Object Code](#subsection6)

      - [Components and Delegation](#subsection7)

      - [Type Components and Delegation](#subsection8)

      - [The Tk Option Database](#subsection9)

      - [Macros and Meta\-programming](#subsection10)

      - [Validation Types](#subsection11)

      - [Defining Validation Types](#subsection12)

  - [CAVEATS](#section4)

  - [KNOWN BUGS](#section5)

  - [HISTORY](#section6)

  - [CREDITS](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require snit ?2\.3\.2?  

[__snit::type__ *name* *definition*](#1)  
[__typevariable__ *name* ?__\-array__? ?*value*?](#2)  
[__typemethod__ *name* *arglist* *body*](#3)  
[__typeconstructor__ *body*](#4)  
[__variable__ *name* ?__\-array__? ?*value*?](#5)  
[__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *name* *arglist* *body*](#6)  
[__option__ *namespec* ?*defaultValue*?](#7)  
[__option__ *namespec* ?*options\.\.\.*?](#8)  
[__constructor__ *arglist* *body*](#9)  
[__destructor__ *body*](#10)  
[__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* *args* *body*](#11)  
[__delegate__ __method__ *name* __to__ *comp* ?__as__ *target*?](#12)  
[__delegate__ __method__ *name* ?__to__ *comp*? __using__ *pattern*](#13)  
[__delegate__ __method__ __\*__ ?__to__ *comp*? ?__using__ *pattern*? ?__except__ *exceptions*?](#14)  
[__delegate__ __option__ *namespec* __to__ *comp*](#15)  
[__delegate__ __option__ *namespec* __to__ *comp* __as__ *target*](#16)  
[__delegate__ __option__ __\*__ __to__ *comp*](#17)  
[__delegate__ __option__ __\*__ __to__ *comp* __except__ *exceptions*](#18)  
[__component__ *comp* ?__\-public__ *method*? ?__\-inherit__ *flag*?](#19)  
[__delegate__ __typemethod__ *name* __to__ *comp* ?__as__ *target*?](#20)  
[__delegate__ __typemethod__ *name* ?__to__ *comp*? __using__ *pattern*](#21)  
[__delegate__ __typemethod__ __\*__ ?__to__ *comp*? ?__using__ *pattern*? ?__except__ *exceptions*?](#22)  
[__typecomponent__ *comp* ?__\-public__ *typemethod*? ?__\-inherit__ *flag*?](#23)  
[__pragma__ ?*options\.\.\.*?](#24)  
[__expose__ *comp*](#25)  
[__expose__ *comp* __as__ *method*](#26)  
[__onconfigure__ *name* *arglist* *body*](#27)  
[__oncget__ *name* *body*](#28)  
[__snit::widget__ *name* *definition*](#29)  
[__widgetclass__ *name*](#30)  
[__hulltype__ *type*](#31)  
[__snit::widgetadaptor__ *name* *definition*](#32)  
[__snit::typemethod__ *type* *name* *arglist* *body*](#33)  
[__snit::method__ *type* *name* *arglist* *body*](#34)  
[__snit::macro__ *name* *arglist* *body*](#35)  
[__snit::compile__ *which* *type* *body*](#36)  
[__$type__ *typemethod* *args*\.\.\.](#37)  
[__$type__ __create__ *name* ?*option* *value* \.\.\.?](#38)  
[__$type__ __info typevars__ ?*pattern*?](#39)  
[__$type__ __info typemethods__ ?*pattern*?](#40)  
[__$type__ __info args__ *method*](#41)  
[__$type__ __info body__ *method*](#42)  
[__$type__ __info default__ *method* *aname* *varname*](#43)  
[__$type__ __info instances__ ?*pattern*?](#44)  
[__$type__ __destroy__](#45)  
[__$object__ *method* *args\.\.\.*](#46)  
[__$object__ __configure__ ?*option*? ?*value*? \.\.\.](#47)  
[__$object__ __configurelist__ *optionlist*](#48)  
[__$object__ __cget__ *option*](#49)  
[__$object__ __destroy__](#50)  
[__$object__ __info type__](#51)  
[__$object__ __info vars__ ?*pattern*?](#52)  
[__$object__ __info typevars__ ?*pattern*?](#53)  
[__$object__ __info typemethods__ ?*pattern*?](#54)  
[__$object__ __info options__ ?*pattern*?](#55)  
[__$object__ __info methods__ ?*pattern*?](#56)  
[__$object__ __info args__ *method*](#57)  
[__$object__ __info body__ *method*](#58)  
[__$object__ __info default__ *method* *aname* *varname*](#59)  
[__mymethod__ *name* ?*args\.\.\.*?](#60)  
[__mytypemethod__ *name* ?*args\.\.\.*?](#61)  
[__myproc__ *name* ?*args\.\.\.*?](#62)  
[__myvar__ *name*](#63)  
[__mytypevar__ *name*](#64)  
[__from__ *argvName* *option* ?*defvalue*?](#65)  
[__install__ *compName* __using__ *objType* *objName* *args\.\.\.*](#66)  
[__installhull__ __using__ *widgetType* *args\.\.\.*](#67)  
[__installhull__ *name*](#68)  
[__variable__ *name*](#69)  
[__typevariable__ *name*](#70)  
[__varname__ *name*](#71)  
[__typevarname__ *name*](#72)  
[__codename__ *name*](#73)  
[__snit::boolean__ __validate__ ?*value*?](#74)  
[__snit::boolean__ *name*](#75)  
[__snit::double__ __validate__ ?*value*?](#76)  
[__snit::double__ *name* ?*option* *value*\.\.\.?](#77)  
[__snit::enum__ __validate__ ?*value*?](#78)  
[__snit::enum__ *name* ?*option* *value*\.\.\.?](#79)  
[__snit::fpixels__ __validate__ ?*value*?](#80)  
[__snit::fpixels__ *name* ?*option* *value*\.\.\.?](#81)  
[__snit::integer__ __validate__ ?*value*?](#82)  
[__snit::integer__ *name* ?*option* *value*\.\.\.?](#83)  
[__snit::listtype__ __validate__ ?*value*?](#84)  
[__snit::listtype__ *name* ?*option* *value*\.\.\.?](#85)  
[__snit::pixels__ __validate__ ?*value*?](#86)  
[__snit::pixels__ *name* ?*option* *value*\.\.\.?](#87)  
[__snit::stringtype__ __validate__ ?*value*?](#88)  
[__snit::stringtype__ *name* ?*option* *value*\.\.\.?](#89)  
[__snit::window__ __validate__ ?*value*?](#90)  
[__snit::window__ *name*](#91)  

# <a name='description'></a>DESCRIPTION

Snit is a pure Tcl object and megawidget system\. It's unique among Tcl object
systems in that it's based not on inheritance but on delegation\. Object systems
based on inheritance only allow you to inherit from classes defined using the
same system, which is limiting\. In Tcl, an object is anything that acts like an
object; it shouldn't matter how the object was implemented\. Snit is intended to
help you build applications out of the materials at hand; thus, Snit is designed
to be able to incorporate and build on any object, whether it's a hand\-coded
object, a __[Tk](\.\./\.\./\.\./\.\./index\.md\#tk)__ widget, an __[Incr
Tcl](\.\./\.\./\.\./\.\./index\.md\#incr\_tcl)__ object, a
__[BWidget](\.\./\.\./\.\./\.\./index\.md\#bwidget)__ or almost anything else\.

This man page is intended to be a reference only; see the accompanying
__[snitfaq](snitfaq\.md)__ for a gentler, more tutorial introduction to
Snit concepts\.

# <a name='section2'></a>SNIT VERSIONS

This man page covers both Snit 2\.2 and Snit 1\.3\. The primary difference between
the two versions is simply that Snit 2\.2 contains speed optimizations based on
new features of Tcl 8\.5; Snit 1\.3 supports all of Tcl 8\.3, 8\.4 and Tcl 8\.5\.
There are a few minor inconsistencies; they are flagged in the body of the man
page with the label "Snit 1\.x Incompatibility"; they are also discussed in the
__[snitfaq](snitfaq\.md)__\.

# <a name='section3'></a>REFERENCE

## <a name='subsection1'></a>Type and Widget Definitions

Snit provides the following commands for defining new types:

  - <a name='1'></a>__snit::type__ *name* *definition*

    Defines a new abstract data type called *name*\. If *name* is not a fully
    qualified command name, it is assumed to be a name in the namespace in which
    the __snit::type__ command was called \(usually the global namespace\)\. It
    returns the fully qualified name of the new type\.

    The type name is then a command that is used to create objects of the new
    type, along with other activities\.

    The __snit::type__ *definition* block is a script that may contain the
    following definitions:

      * <a name='2'></a>__typevariable__ *name* ?__\-array__? ?*value*?

        Defines a type variable with the specified *name*, and optionally the
        specified *value*\. Type variables are shared by all instances of the
        type\. If the __\-array__ option is included, then *value* should be
        a dictionary; it will be assigned to the variable using __array
        set__\.

      * <a name='3'></a>__typemethod__ *name* *arglist* *body*

        Defines a type method, a subcommand of the new type command, with the
        specified name, argument list, and body\. The *arglist* is a normal Tcl
        argument list and may contain default arguments and the __args__
        argument; however, it may not contain the argument names __type__,
        __self__, __selfns__, or __win__\.

        The variable __type__ is automatically defined in the *body* to
        the type's fully\-qualified name\. In addition, type variables are
        automatically visible in the *body* of every type method\.

        If the *name* consists of two or more tokens, Snit handles it
        specially:

            typemethod {a b} {arg} { puts "Got $arg" }

        This statement implicitly defines a type method called __a__ which
        has a subcommand __b__\. __b__ is called like this:

            $type a b "Hello, world!"

        __a__ may have any number of subcommands\. This makes it possible to
        define a hierarchical command structure; see
        __[method](\.\./\.\./\.\./\.\./index\.md\#method)__, below, for more
        examples\.

        Type methods can call commands from the namespace in which the type is
        defined without importing them, e\.g\., if the type name is
        __::parentns::typename__, then the type's type methods can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

        *Snit 1\.x Incompatibility:* In Snit 1\.x, the following following two
        calls to this type method are equivalent:

            $type a b "Hello, world!"
            $type {a b} "Hello, world!"

        In Snit 2\.2, the second form is invalid\.

      * <a name='4'></a>__typeconstructor__ *body*

        The type constructor's *body* is executed once when the type is first
        defined; it is typically used to initialize array\-valued type variables
        and to add entries to [The Tk Option Database](#subsection9)\.

        The variable __type__ is automatically defined in the *body*, and
        contains the type's fully\-qualified name\. In addition, type variables
        are automatically visible in the *body* of the type constructor\.

        A type may define at most one type constructor\.

        The type constructor can call commands from the namespace in which the
        type is defined without importing them, e\.g\., if the type name is
        __::parentns::typename__, then the type constructor can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

      * <a name='5'></a>__variable__ *name* ?__\-array__? ?*value*?

        Defines an instance variable, a private variable associated with each
        instance of this type, and optionally its initial value\. If the
        __\-array__ option is included, then *value* should be a
        dictionary; it will be assigned to the variable using __array set__\.

      * <a name='6'></a>__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ *name* *arglist* *body*

        Defines an instance method, a subcommand of each instance of this type,
        with the specified name, argument list and body\. The *arglist* is a
        normal Tcl argument list and may contain default arguments and the
        __args__ argument\.

        The method is implicitly passed the following arguments as well:
        __type__, which contains the fully\-qualified type name;
        __self__, which contains the current instance command name;
        __selfns__, which contains the name of the instance's private
        namespace; and __win__, which contains the original instance name\.
        Consequently, the *arglist* may not contain the argument names
        __type__, __self__, __selfns__, or __win__\.

        An instance method defined in this way is said to be *locally
        defined*\.

        Type and instance variables are automatically visible in all instance
        methods\. If the type has locally defined options, the __options__
        array is also visible\.

        If the *name* consists of two or more tokens, Snit handles it
        specially:

            method {a b} {} { ... }

        This statement implicitly defines a method called __a__ which has a
        subcommand __b__\. __b__ is called like this:

            $self a b "Hello, world!"

        __a__ may have any number of subcommands\. This makes it possible to
        define a hierarchical command structure:

            % snit::type dog {
                method {tail wag}   {} {return "Wag, wag"}
                method {tail droop} {} {return "Droop, droop"}
            }
            ::dog
            % dog spot
            ::spot
            % spot tail wag
            Wag, wag
            % spot tail droop
            Droop, droop
            %

        What we've done is implicitly defined a "tail" method with subcommands
        "wag" and "droop"\. Consequently, it's an error to define "tail"
        explicitly\.

        Methods can call commands from the namespace in which the type is
        defined without importing them, e\.g\., if the type name is
        __::parentns::typename__, then the type's methods can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

        *Snit 1\.x Incompatibility:* In Snit 1\.x, the following following two
        calls to this method are equivalent:

            $self a b "Hello, world!"
            $self {a b} "Hello, world!"

        In Snit 2\.2, the second form is invalid\.

      * <a name='7'></a>__option__ *namespec* ?*defaultValue*?

      * <a name='8'></a>__option__ *namespec* ?*options\.\.\.*?

        Defines an option for instances of this type, and optionally gives it an
        initial value\. The initial value defaults to the empty string if no
        *defaultValue* is specified\.

        An option defined in this way is said to be *locally defined*\.

        The *namespec* is a list defining the option's name, resource name,
        and class name, e\.g\.:

            option {-font font Font} {Courier 12}

        The option name must begin with a hyphen, and must not contain any upper
        case letters\. The resource name and class name are optional; if not
        specified, the resource name defaults to the option name, minus the
        hyphen, and the class name defaults to the resource name with the first
        letter capitalized\. Thus, the following statement is equivalent to the
        previous example:

            option -font {Courier 12}

        See [The Tk Option Database](#subsection9) for more information
        about resource and class names\.

        Options are normally set and retrieved using the standard instance
        methods __configure__ and __cget__; within instance code \(method
        bodies, etc\.\), option values are available through the __options__
        array:

            set myfont $options(-font)

        If the type defines any option handlers \(e\.g\.,
        __\-configuremethod__\), then it should probably use __configure__
        and __cget__ to access its options to avoid subtle errors\.

        The __option__ statement may include the following options:

          + __\-default__ *defvalue*

            Defines the option's default value; the option's default value will
            be "" otherwise\.

          + __\-readonly__ *flag*

            The *flag* can be any Boolean value recognized by Tcl\. If *flag*
            is true, then the option is read\-only\-\-it can only be set using
            __configure__ or __configurelist__ at creation time, i\.e\.,
            in the type's constructor\.

          + __\-type__ *type*

            Every locally\-defined option may define its validation type, which
            may be either the name of a validation type or a specification for a
            validation subtype

            For example, an option may declare that its value must be an integer
            by specifying __snit::integer__ as its validation type:

                option -number -type snit::integer

            It may also declare that its value is an integer between 1 and 10 by
            specifying a validation subtype:

                option -number -type {snit::integer -min 1 -max 10}

            If a validation type or subtype is defined for an option, then it
            will be used to validate the option's value whenever it is changed
            by the object's __configure__ or __configurelist__ methods\.
            In addition, all such options will have their values validated
            automatically immediately after the constructor executes\.

            Snit defines a family of validation types and subtypes, and it's
            quite simple to define new ones\. See [Validation
            Types](#subsection11) for the complete list, and [Defining
            Validation Types](#subsection12) for an explanation of how to
            define your own\.

          + __\-cgetmethod__ *methodName*

            Every locally\-defined option may define a __\-cgetmethod__; it is
            called when the option's value is retrieved using the __cget__
            method\. Whatever the method's *body* returns will be the return
            value of the call to __cget__\.

            The named method must take one argument, the option name\. For
            example, this code is equivalent to \(though slower than\) Snit's
            default handling of __cget__:

                option -font -cgetmethod GetOption
                method GetOption {option} {
                    return $options($option)
                }

            Note that it's possible for any number of options to share a
            __\-cgetmethod__\.

          + __\-configuremethod__ *methodName*

            Every locally\-defined option may define a __\-configuremethod__;
            it is called when the option's value is set using the
            __configure__ or __configurelist__ methods\. It is the named
            method's responsibility to save the option's value; in other words,
            the value will not be saved to the __options\(\)__ array unless
            the method saves it there\.

            The named method must take two arguments, the option name and its
            new value\. For example, this code is equivalent to \(though slower
            than\) Snit's default handling of __configure__:

                option -font -configuremethod SetOption
                method SetOption {option value} {
                    set options($option) $value
                }

            Note that it's possible for any number of options to share a single
            __\-configuremethod__\.

          + __\-validatemethod__ *methodName*

            Every locally\-defined option may define a __\-validatemethod__;
            it is called when the option's value is set using the
            __configure__ or __configurelist__ methods, just before the
            __\-configuremethod__ \(if any\)\. It is the named method's
            responsibility to validate the option's new value, and to throw an
            error if the value is invalid\.

            The named method must take two arguments, the option name and its
            new value\. For example, this code verifies that __\-flag__'s
            value is a valid Boolean value:

                option -font -validatemethod CheckBoolean
                method CheckBoolean {option value} {
                    if {![string is boolean -strict $value]} {
                        error "option $option must have a boolean value."
                    }
                }

            Note that it's possible for any number of options to share a single
            __\-validatemethod__\.

      * <a name='9'></a>__constructor__ *arglist* *body*

        The constructor definition specifies a *body* of code to be executed
        when a new instance is created\. The *arglist* is a normal Tcl argument
        list and may contain default arguments and the __args__ argument\.

        As with methods, the arguments __type__, __self__,
        __selfns__, and __win__ are defined implicitly, and all type and
        instance variables are automatically visible in its *body*\.

        If the *definition* doesn't explicitly define the constructor, Snit
        defines one implicitly\. If the type declares at least one option
        \(whether locally or by delegation\), the default constructor will be
        defined as follows:

            constructor {args} {
                $self configurelist $args
            }

        For standard Tk widget behavior, the argument list should be the single
        name __args__, as shown\.

        If the *definition* defines neither a constructor nor any options, the
        default constructor is defined as follows:

            constructor {} {}

        As with methods, the constructor can call commands from the namespace in
        which the type is defined without importing them, e\.g\., if the type name
        is __::parentns::typename__, then the constructor can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

      * <a name='10'></a>__destructor__ *body*

        The destructor is used to code any actions that must take place when an
        instance of the type is destroyed: typically, the destruction of
        anything created in the constructor\.

        The destructor takes no explicit arguments; as with methods, the
        arguments __type__, __self__, __selfns__, and __win__,
        are defined implicitly, and all type and instance variables are
        automatically visible in its *body*\. As with methods, the destructor
        can call commands from the namespace in which the type is defined
        without importing them, e\.g\., if the type name is
        __::parentns::typename__, then the destructor can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

      * <a name='11'></a>__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ *name* *args* *body*

        Defines a new Tcl procedure in the type's namespace\.

        The defined proc differs from a normal Tcl proc in that all type
        variables are automatically visible\. The proc can access instance
        variables as well, provided that it is passed __selfns__ \(with
        precisely that name\) as one of its arguments\.

        Although they are not implicitly defined for procs, the argument names
        __type__, __self__, and __win__ should be avoided\.

        As with methods and typemethods, procs can call commands from the
        namespace in which the type is defined without importing them, e\.g\., if
        the type name is __::parentns::typename__, then the proc can call
        __::parentns::someproc__ just as __someproc__\. *Snit 1\.x
        Incompatibility:* This does not work in Snit 1\.x, as it depends on
        __namespace path__, a new command in Tcl 8\.5\.

      * <a name='12'></a>__delegate__ __method__ *name* __to__ *comp* ?__as__ *target*?

        Delegates method *name* to component *comp*\. That is, when method
        *name* is called on an instance of this type, the method and its
        arguments will be passed to the named component's command instead\. That
        is, the following statement

            delegate method wag to tail

        is roughly equivalent to this explicitly defined method:

            method wag {args} {
                uplevel $tail wag $args
            }

        As with methods, the *name* may have multiple tokens; in this case,
        the last token of the name is assumed to be the name of the component's
        method\.

        The optional __as__ clause allows you to specify the delegated
        method name and possibly add some arguments:

            delegate method wagtail to tail as "wag briskly"

        A method cannot be both locally defined and delegated\.

        __Note:__ All forms of __delegate method__ can delegate to both
        instance components and type components\.

      * <a name='13'></a>__delegate__ __method__ *name* ?__to__ *comp*? __using__ *pattern*

        In this form of the __delegate__ statement, the __using__ clause
        is used to specify the precise form of the command to which method
        *name* name is delegated\. In this form, the __to__ clause is
        optional, since the chosen command might not involve any particular
        component\.

        The value of the __using__ clause is a list that may contain any or
        all of the following substitution codes; these codes are substituted
        with the described value to build the delegated command prefix\. Note
        that the following two statements are equivalent:

            delegate method wag to tail
            delegate method wag to tail using "%c %m"

        Each element of the list becomes a single element of the delegated
        command\-\-it is never reparsed as a string\.

        Substitutions:

          + __%%__

            This is replaced with a single "%"\. Thus, to pass the string "%c" to
            the command as an argument, you'd write "%%c"\.

          + __%c__

            This is replaced with the named component's command\.

          + __%m__

            This is replaced with the final token of the method *name*; if the
            method *name* has one token, this is identical to __%M__\.

          + __%M__

            This is replaced by the method *name*; if the *name* consists of
            multiple tokens, they are joined by space characters\.

          + __%j__

            This is replaced by the method *name*; if the *name* consists of
            multiple tokens, they are joined by underscores \("\_"\)\.

          + __%t__

            This is replaced with the fully qualified type name\.

          + __%n__

            This is replaced with the name of the instance's private namespace\.

          + __%s__

            This is replaced with the name of the instance command\.

          + __%w__

            This is replaced with the original name of the instance command; for
            Snit widgets and widget adaptors, it will be the Tk window name\. It
            remains constant, even if the instance command is renamed\.

      * <a name='14'></a>__delegate__ __method__ __\*__ ?__to__ *comp*? ?__using__ *pattern*? ?__except__ *exceptions*?

        The form __delegate method \*__ delegates all unknown method names to
        the specified *comp*onent\. The __except__ clause can be used to
        specify a list of *exceptions*, i\.e\., method names that will not be so
        delegated\. The __using__ clause is defined as given above\. In this
        form, the statement must contain the __to__ clause, the
        __using__ clause, or both\.

        In fact, the "\*" can be a list of two or more tokens whose last element
        is "\*", as in the following example:

            delegate method {tail *} to tail

        This implicitly defines the method __tail__ whose subcommands will
        be delegated to the __tail__ component\.

      * <a name='15'></a>__delegate__ __option__ *namespec* __to__ *comp*

      * <a name='16'></a>__delegate__ __option__ *namespec* __to__ *comp* __as__ *target*

      * <a name='17'></a>__delegate__ __option__ __\*__ __to__ *comp*

      * <a name='18'></a>__delegate__ __option__ __\*__ __to__ *comp* __except__ *exceptions*

        Defines a delegated option; the *namespec* is defined as for the
        __option__ statement\. When the __configure__,
        __configurelist__, or __cget__ instance method is used to set or
        retrieve the option's value, the equivalent __configure__ or
        __cget__ command will be applied to the component as though the
        option was defined with the following __\-configuremethod__ and
        __\-cgetmethod__:

            method ConfigureMethod {option value} {
                $comp configure $option $value
            }

            method CgetMethod {option} {
                return [$comp cget $option]
            }

        Note that delegated options never appear in the __options__ array\.

        If the __as__ clause is specified, then the *target* option name
        is used in place of *name*\.

        The form __delegate option \*__ delegates all unknown options to the
        specified *comp*onent\. The __except__ clause can be used to
        specify a list of *exceptions*, i\.e\., option names that will not be so
        delegated\.

        Warning: options can only be delegated to a component if it supports the
        __configure__ and __cget__ instance methods\.

        An option cannot be both locally defined and delegated\. TBD: Continue
        from here\.

      * <a name='19'></a>__component__ *comp* ?__\-public__ *method*? ?__\-inherit__ *flag*?

        Explicitly declares a component called *comp*, and automatically
        defines the component's instance variable\.

        If the __\-public__ option is specified, then the option is made
        public by defining a *method* whose subcommands are delegated to the
        component e\.g\., specifying __\-public mycomp__ is equivalent to the
        following:

            component mycomp
            delegate method {mymethod *} to mycomp

        If the __\-inherit__ option is specified, then *flag* must be a
        Boolean value; if *flag* is true then all unknown methods and options
        will be delegated to this component\. The name __\-inherit__ implies
        that instances of this new type inherit, in a sense, the methods and
        options of the component\. That is, __\-inherit yes__ is equivalent
        to:

            component mycomp
            delegate option * to mycomp
            delegate method * to mycomp

      * <a name='20'></a>__delegate__ __typemethod__ *name* __to__ *comp* ?__as__ *target*?

        Delegates type method *name* to type component *comp*\. That is, when
        type method *name* is called on this type, the type method and its
        arguments will be passed to the named type component's command instead\.
        That is, the following statement

            delegate typemethod lostdogs to pound

        is roughly equivalent to this explicitly defined method:

            typemethod lostdogs {args} {
                uplevel $pound lostdogs $args
            }

        As with type methods, the *name* may have multiple tokens; in this
        case, the last token of the name is assumed to be the name of the
        component's method\.

        The optional __as__ clause allows you to specify the delegated
        method name and possibly add some arguments:

            delegate typemethod lostdogs to pound as "get lostdogs"

        A type method cannot be both locally defined and delegated\.

      * <a name='21'></a>__delegate__ __typemethod__ *name* ?__to__ *comp*? __using__ *pattern*

        In this form of the __delegate__ statement, the __using__ clause
        is used to specify the precise form of the command to which type method
        *name* name is delegated\. In this form, the __to__ clause is
        optional, since the chosen command might not involve any particular type
        component\.

        The value of the __using__ clause is a list that may contain any or
        all of the following substitution codes; these codes are substituted
        with the described value to build the delegated command prefix\. Note
        that the following two statements are equivalent:

            delegate typemethod lostdogs to pound
            delegate typemethod lostdogs to pound using "%c %m"

        Each element of the list becomes a single element of the delegated
        command\-\-it is never reparsed as a string\.

        Substitutions:

          + __%%__

            This is replaced with a single "%"\. Thus, to pass the string "%c" to
            the command as an argument, you'd write "%%c"\.

          + __%c__

            This is replaced with the named type component's command\.

          + __%m__

            This is replaced with the final token of the type method *name*;
            if the type method *name* has one token, this is identical to
            __%M__\.

          + __%M__

            This is replaced by the type method *name*; if the *name*
            consists of multiple tokens, they are joined by space characters\.

          + __%j__

            This is replaced by the type method *name*; if the *name*
            consists of multiple tokens, they are joined by underscores \("\_"\)\.

          + __%t__

            This is replaced with the fully qualified type name\.

      * <a name='22'></a>__delegate__ __typemethod__ __\*__ ?__to__ *comp*? ?__using__ *pattern*? ?__except__ *exceptions*?

        The form __delegate typemethod \*__ delegates all unknown type method
        names to the specified type component\. The __except__ clause can be
        used to specify a list of *exceptions*, i\.e\., type method names that
        will not be so delegated\. The __using__ clause is defined as given
        above\. In this form, the statement must contain the __to__ clause,
        the __using__ clause, or both\.

        __Note:__ By default, Snit interprets __$type foo__, where
        __foo__ is not a defined type method, as equivalent to __$type
        create foo__, where __foo__ is the name of a new instance of the
        type\. If you use __delegate typemethod \*__, then the __create__
        type method must always be used explicitly\.

        The "\*" can be a list of two or more tokens whose last element is "\*",
        as in the following example:

            delegate typemethod {tail *} to tail

        This implicitly defines the type method __tail__ whose subcommands
        will be delegated to the __tail__ type component\.

      * <a name='23'></a>__typecomponent__ *comp* ?__\-public__ *typemethod*? ?__\-inherit__ *flag*?

        Explicitly declares a type component called *comp*, and automatically
        defines the component's type variable\. A type component is an arbitrary
        command to which type methods and instance methods can be delegated; the
        command's name is stored in a type variable\.

        If the __\-public__ option is specified, then the type component is
        made public by defining a *typemethod* whose subcommands are delegated
        to the type component, e\.g\., specifying __\-public mytypemethod__ is
        equivalent to the following:

            typecomponent mycomp
            delegate typemethod {mytypemethod *} to mycomp

        If the __\-inherit__ option is specified, then *flag* must be a
        Boolean value; if *flag* is true then all unknown type methods will be
        delegated to this type component\. \(See the note on "delegate typemethod
        \*", above\.\) The name __\-inherit__ implies that this type inherits,
        in a sense, the behavior of the type component\. That is, __\-inherit
        yes__ is equivalent to:

            typecomponent mycomp
            delegate typemethod * to mycomp

      * <a name='24'></a>__pragma__ ?*options\.\.\.*?

        The __pragma__ statement provides control over how Snit generates a
        type\. It takes the following options; in each case, *flag* must be a
        Boolean value recognized by Tcl, e\.g\., __0__, __1__,
        __yes__, __no__, and so on\.

        By setting the __\-hastypeinfo__, __\-hastypedestroy__, and
        __\-hasinstances__ pragmas to false and defining appropriate type
        methods, you can create an ensemble command without any extraneous
        behavior\.

          + __\-canreplace__ *flag*

            If false \(the default\) Snit will not create an instance of a
            __snit::type__ that has the same name as an existing command;
            this prevents subtle errors\. Setting this pragma to true restores
            the behavior of Snit V0\.93 and earlier versions\.

          + __\-hastypeinfo__ *flag*

            If true \(the default\), the generated type will have a type method
            called __[info](\.\./\.\./\.\./\.\./index\.md\#info)__ that is used
            for type introspection; the
            __[info](\.\./\.\./\.\./\.\./index\.md\#info)__ type method is
            documented below\. If false, it will not\.

          + __\-hastypedestroy__ *flag*

            If true \(the default\), the generated type will have a type method
            called __destroy__ that is used to destroy the type and all of
            its instances\. The __destroy__ type method is documented below\.
            If false, it will not\.

          + __\-hastypemethods__ *flag*

            If true \(the default\), the generated type's type command will have
            subcommands \(type methods\) as usual\. If false, the type command will
            serve only to create instances of the type; the first argument is
            the instance name\.

            This pragma and __\-hasinstances__ cannot both be set false\.

          + __\-hasinstances__ *flag*

            If true \(the default\), the generated type will have a type method
            called __create__ that is used to create instances of the type,
            along with a variety of instance\-related features\. If false, it will
            not\.

            This pragma and __\-hastypemethods__ cannot both be set false\.

          + __\-hasinfo__ *flag*

            If true \(the default\), instances of the generated type will have an
            instance method called __info__ that is used for instance
            introspection; the __info__ method is documented below\. If
            false, it will not\.

          + __\-simpledispatch__ *flag*

            This pragma is intended to make simple, heavily\-used abstract data
            types \(e\.g\., stacks and queues\) more efficient\.

            If false \(the default\), instance methods are dispatched normally\. If
            true, a faster dispatching scheme is used instead\. The speed comes
            at a price; with __\-simpledispatch yes__ you get the following
            limitations:

              - Methods cannot be delegated\.

              - __uplevel__ and __upvar__ do not work as expected: the
                caller's scope is two levels up rather than one\.

              - The option\-handling methods \(__cget__, __configure__,
                and __configurelist__\) are very slightly slower\.

      * <a name='25'></a>__expose__ *comp*

      * <a name='26'></a>__expose__ *comp* __as__ *method*

        __Deprecated\.__ To expose component *comp* publicly, use
        __component__'s __\-public__ option\.

      * <a name='27'></a>__onconfigure__ *name* *arglist* *body*

        __Deprecated\.__ Define __option__'s __\-configuremethod__
        option instead\.

        As of version 0\.95, the following definitions,

            option -myoption
            onconfigure -myoption {value} {
                # Code to save the option's value
            }

        are implemented as follows:

            option -myoption -configuremethod _configure-myoption
            method _configure-myoption {_option value} {
                # Code to save the option's value
            }

      * <a name='28'></a>__oncget__ *name* *body*

        __Deprecated\.__ Define __option__'s __\-cgetmethod__ option
        instead\.

        As of version 0\.95, the following definitions,

            option -myoption
            oncget -myoption {
                # Code to return the option's value
            }

        are implemented as follows:

            option -myoption -cgetmethod _cget-myoption
            method _cget-myoption {_option} {
                # Code to return the option's value
            }

  - <a name='29'></a>__snit::widget__ *name* *definition*

    This command defines a Snit megawidget type with the specified *name*\. The
    *definition* is defined as for __snit::type__\. A __snit::widget__
    differs from a __snit::type__ in these ways:

      * Every instance of a __snit::widget__ has an automatically\-created
        component called __hull__, which is normally a Tk frame widget\.
        Other widgets created as part of the megawidget will be created within
        this widget\.

        The hull component is initially created with the requested widget name;
        then Snit does some magic, renaming the hull component and installing
        its own instance command in its place\. The hull component's new name is
        saved in an instance variable called __hull__\.

      * The name of an instance must be valid Tk window name, and the parent
        window must exist\.

    A __snit::widget__ definition can include any of statements allowed in a
    __snit::type__ definition, and may also include the following:

      * <a name='30'></a>__widgetclass__ *name*

        Sets the __snit::widget__'s widget class to *name*, overriding the
        default\. See [The Tk Option Database](#subsection9) for more
        information\.

      * <a name='31'></a>__hulltype__ *type*

        Determines the kind of widget used as the __snit::widget__'s hull\.
        The *type* may be __frame__ \(the default\), __toplevel__,
        __labelframe__; the qualified equivalents of these,
        __tk::frame__, __tk::toplevel__, and __tk::labelframe__; or,
        if available, the equivalent Tile widgets: __ttk::frame__,
        __ttk::toplevel__, and __ttk::labelframe__\. In practice, any
        widget that supports the __\-class__ option can be used as a hull
        widget by __lappend__'ing its name to the variable
        __snit::hulltypes__\.

  - <a name='32'></a>__snit::widgetadaptor__ *name* *definition*

    This command defines a Snit megawidget type with the specified name\. It
    differs from __snit::widget__ in that the instance's __hull__
    component is not created automatically, but is created in the constructor
    and installed using the __installhull__ command\. Once the hull is
    installed, its instance command is renamed and replaced as with normal
    __snit::widget__s\. The original command is again accessible in the
    instance variable __hull__\.

    Note that in general it is not possible to change the *widget class* of a
    __snit::widgetadaptor__'s hull widget\.

    See [The Tk Option Database](#subsection9) for information on how
    __snit::widgetadaptor__s interact with the option database\.

  - <a name='33'></a>__snit::typemethod__ *type* *name* *arglist* *body*

    Defines a new type method \(or redefines an existing type method\) for a
    previously existing *type*\.

  - <a name='34'></a>__snit::method__ *type* *name* *arglist* *body*

    Defines a new instance method \(or redefines an existing instance method\) for
    a previously existing *type*\. Note that delegated instance methods can't
    be redefined\.

  - <a name='35'></a>__snit::macro__ *name* *arglist* *body*

    Defines a Snit macro with the specified *name*, *arglist*, and *body*\.
    Macros are used to define new type and widget definition statements in terms
    of the statements defined in this man page\.

    A macro is simply a Tcl proc that is defined in the slave interpreter used
    to compile type and widget definitions\. Thus, macros have access to all of
    the type and widget definition statements\. See [Macros and
    Meta\-programming](#subsection10) for more details\.

    The macro *name* cannot be the same as any standard Tcl command, or any
    Snit type or widget definition statement, e\.g\., you can't redefine the
    __[method](\.\./\.\./\.\./\.\./index\.md\#method)__ or __delegate__
    statements, or the standard __[set](\.\./\.\./\.\./\.\./index\.md\#set)__,
    __[list](\.\./\.\./\.\./\.\./index\.md\#list)__, or
    __[string](\.\./\.\./\.\./\.\./index\.md\#string)__ commands\.

  - <a name='36'></a>__snit::compile__ *which* *type* *body*

    Snit defines a type, widget, or widgetadaptor by "compiling" the definition
    into a Tcl script; this script is then evaluated in the Tcl interpreter,
    which actually defines the new type\.

    This command exposes the "compiler"\. Given a definition *body* for the
    named *type*, where *which* is __type__, __widget__, or
    __widgetadaptor__, __snit::compile__ returns a list of two elements\.
    The first element is the fully qualified type name; the second element is
    the definition script\.

    __snit::compile__ is useful when additional processing must be done on
    the Snit\-generated code\-\-if it must be instrumented, for example, or run
    through the TclDevKit compiler\. In addition, the returned script could be
    saved in a "\.tcl" file and used to define the type as part of an application
    or library, thus saving the compilation overhead at application start\-up\.
    Note that the same version of Snit must be used at run\-time as at
    compile\-time\.

## <a name='subsection2'></a>The Type Command

A type or widget definition creates a type command, which is used to create
instances of the type\. The type command has this form:

  - <a name='37'></a>__$type__ *typemethod* *args*\.\.\.

    The *typemethod* can be any of the [Standard Type
    Methods](#subsection3) \(e\.g\., __create__\), or any type method
    defined in the type definition\. The subsequent *args* depend on the
    specific *typemethod* chosen\.

    The type command is most often used to create new instances of the type;
    hence, the __create__ method is assumed if the first argument to the
    type command doesn't name a valid type method, unless the type definition
    includes __delegate typemethod \*__ or the __\-hasinstances__ pragma
    is set to false\.

    Furthermore, if the __\-hastypemethods__ pragma is false, then Snit type
    commands can be called with no arguments at all; in this case, the type
    command creates an instance with an automatically generated name\. In other
    words, provided that the __\-hastypemethods__ pragma is false and the
    type has instances, the following commands are equivalent:

        snit::type dog { ... }

        set mydog [dog create %AUTO%]
        set mydog [dog %AUTO%]
        set mydog [dog]

    This doesn't work for Snit widgets, for obvious reasons\.

    *Snit 1\.x Incompatibility:* In Snit 1\.x, the above behavior is available
    whether __\-hastypemethods__ is true \(the default\) or false\.

## <a name='subsection3'></a>Standard Type Methods

In addition to any type methods in the type's definition, all type and widget
commands will usually have at least the following subcommands:

  - <a name='38'></a>__$type__ __create__ *name* ?*option* *value* \.\.\.?

    Creates a new instance of the type, giving it the specified *name* and
    calling the type's constructor\.

    For __snit::type__s, if *name* is not a fully\-qualified command name,
    it is assumed to be a name in the namespace in which the call to
    __snit::type__ appears\. The method returns the fully\-qualified instance
    name\.

    For __snit::widget__s and __snit::widgetadaptor__s, *name* must be
    a valid widget name; the method returns the widget name\.

    So long as *name* does not conflict with any defined type method name the
    __create__ keyword may be omitted, unless the type definition includes
    __delegate typemethod \*__ or the __\-hasinstances__ pragma is set to
    false\.

    If the *name* includes the string __%AUTO%__, it will be replaced with
    the string __$type$counter__ where __$type__ is the type name and
    __$counter__ is a counter that increments each time __%AUTO%__ is
    used for this type\.

    By default, any arguments following the *name* will be a list of
    *option* names and their *value*s; however, a type's constructor can
    specify a different argument list\.

    As of Snit V0\.95, __create__ will throw an error if the *name* is the
    same as any existing command\-\-note that this was always true for
    __snit::widget__s and __snit::widgetadaptor__s\. You can restore the
    previous behavior using the __\-canreplace__ pragma\.

  - <a name='39'></a>__$type__ __info typevars__ ?*pattern*?

    Returns a list of the type's type variables \(excluding Snit internal
    variables\); all variable names are fully\-qualified\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

  - <a name='40'></a>__$type__ __info typemethods__ ?*pattern*?

    Returns a list of the names of the type's type methods\. If the type has
    hierarchical type methods, whether locally\-defined or delegated, only the
    first word of each will be included in the list\.

    If the type definition includes __delegate typemethod \*__, the list will
    include only the names of those implicitly delegated type methods that have
    been called at least once and are still in the type method cache\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

  - <a name='41'></a>__$type__ __info args__ *method*

    Returns a list containing the names of the arguments to the type's
    *method*, in order\. This method cannot be applied to delegated type
    methods\.

  - <a name='42'></a>__$type__ __info body__ *method*

    Returns the body of typemethod *method*\. This method cannot be applied to
    delegated type methods\.

  - <a name='43'></a>__$type__ __info default__ *method* *aname* *varname*

    Returns a boolean value indicating whether the argument *aname* of the
    type's *method* has a default value \(__true__\) or not \(__false__\)\.
    If the argument has a default its value is placed into the variable
    *varname*\.

  - <a name='44'></a>__$type__ __info instances__ ?*pattern*?

    Returns a list of the type's instances\. For __snit::type__s, it will be
    a list of fully\-qualified instance names; for __snit::widget__s, it will
    be a list of Tk widget names\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

    *Snit 1\.x Incompatibility:* In Snit 1\.x, the full multi\-word names of
    hierarchical type methods are included in the return value\.

  - <a name='45'></a>__$type__ __destroy__

    Destroys the type's instances, the type's namespace, and the type command
    itself\.

## <a name='subsection4'></a>The Instance Command

A Snit type or widget's __create__ type method creates objects of the type;
each object has a unique name that is also a Tcl command\. This command is used
to access the object's methods and data, and has this form:

  - <a name='46'></a>__$object__ *method* *args\.\.\.*

    The *method* can be any of the [Standard Instance
    Methods](#subsection5), or any instance method defined in the type
    definition\. The subsequent *args* depend on the specific *method*
    chosen\.

## <a name='subsection5'></a>Standard Instance Methods

In addition to any delegated or locally\-defined instance methods in the type's
definition, all Snit objects will have at least the following subcommands:

  - <a name='47'></a>__$object__ __configure__ ?*option*? ?*value*? \.\.\.

    Assigns new values to one or more options\. If called with one argument, an
    *option* name, returns a list describing the option, as Tk widgets do; if
    called with no arguments, returns a list of lists describing all options, as
    Tk widgets do\.

    Warning: This information will be available for delegated options only if
    the component to which they are delegated has a __configure__ method
    that returns this same kind of information\.

    Note: Snit defines this method only if the type has at least one option\.

  - <a name='48'></a>__$object__ __configurelist__ *optionlist*

    Like __configure__, but takes one argument, a list of options and their
    values\. It's mostly useful in the type constructor, but can be used
    anywhere\.

    Note: Snit defines this method only if the type has at least one option\.

  - <a name='49'></a>__$object__ __cget__ *option*

    Returns the option's value\.

    Note: Snit defines this method only if the type has at least one option\.

  - <a name='50'></a>__$object__ __destroy__

    Destroys the object, calling the __destructor__ and freeing all related
    memory\.

    *Note:* The __destroy__ method isn't defined for __snit::widget__
    or __snit::widgetadaptor__ objects; instances of these are destroyed by
    calling __[Tk](\.\./\.\./\.\./\.\./index\.md\#tk)__'s __destroy__ command,
    just as normal widgets are\.

  - <a name='51'></a>__$object__ __info type__

    Returns the instance's type\.

  - <a name='52'></a>__$object__ __info vars__ ?*pattern*?

    Returns a list of the object's instance variables \(excluding Snit internal
    variables\)\. The names are fully qualified\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

  - <a name='53'></a>__$object__ __info typevars__ ?*pattern*?

    Returns a list of the object's type's type variables \(excluding Snit
    internal variables\)\. The names are fully qualified\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

  - <a name='54'></a>__$object__ __info typemethods__ ?*pattern*?

    Returns a list of the names of the type's type methods\. If the type has
    hierarchical type methods, whether locally\-defined or delegated, only the
    first word of each will be included in the list\.

    If the type definition includes __delegate typemethod \*__, the list will
    include only the names of those implicitly delegated type methods that have
    been called at least once and are still in the type method cache\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

    *Snit 1\.x Incompatibility:* In Snit 1\.x, the full multi\-word names of
    hierarchical type methods are included in the return value\.

  - <a name='55'></a>__$object__ __info options__ ?*pattern*?

    Returns a list of the object's option names\. This always includes local
    options and explicitly delegated options\. If unknown options are delegated
    as well, and if the component to which they are delegated responds to
    __$object configure__ like Tk widgets do, then the result will include
    all possible unknown options that can be delegated to the component\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

    Note that the return value might be different for different instances of the
    same type, if component object types can vary from one instance to another\.

  - <a name='56'></a>__$object__ __info methods__ ?*pattern*?

    Returns a list of the names of the instance's methods\. If the type has
    hierarchical methods, whether locally\-defined or delegated, only the first
    word of each will be included in the list\.

    If the type definition includes __delegate method \*__, the list will
    include only the names of those implicitly delegated methods that have been
    called at least once and are still in the method cache\.

    If *pattern* is given, it's used as a __string match__ pattern; only
    names that match the pattern are returned\.

    *Snit 1\.x Incompatibility:* In Snit 1\.x, the full multi\-word names of
    hierarchical type methods are included in the return value\.

  - <a name='57'></a>__$object__ __info args__ *method*

    Returns a list containing the names of the arguments to the instance's
    *method*, in order\. This method cannot be applied to delegated methods\.

  - <a name='58'></a>__$object__ __info body__ *method*

    Returns the body of the instance's method *method*\. This method cannot be
    applied to delegated methods\.

  - <a name='59'></a>__$object__ __info default__ *method* *aname* *varname*

    Returns a boolean value indicating whether the argument *aname* of the
    instance's *method* has a default value \(__true__\) or not
    \(__false__\)\. If the argument has a default its value is placed into the
    variable *varname*\.

## <a name='subsection6'></a>Commands for use in Object Code

Snit defines the following commands for use in your object code: that is, for
use in type methods, instance methods, constructors, destructors, onconfigure
handlers, oncget handlers, and procs\. They do not reside in the ::snit::
namespace; instead, they are created with the type, and can be used without
qualification\.

  - <a name='60'></a>__mymethod__ *name* ?*args\.\.\.*?

    The __mymethod__ command is used for formatting callback commands to be
    passed to other objects\. It returns a command that when called will invoke
    method *name* with the specified arguments, plus of course any arguments
    added by the caller\. In other words, both of the following commands will
    cause the object's __dosomething__ method to be called when the
    __$button__ is pressed:

        $button configure -command [list $self dosomething myargument]

        $button configure -command [mymethod dosomething myargument]

    The chief distinction between the two is that the latter form will not break
    if the object's command is renamed\.

  - <a name='61'></a>__mytypemethod__ *name* ?*args\.\.\.*?

    The __mytypemethod__ command is used for formatting callback commands to
    be passed to other objects\. It returns a command that when called will
    invoke type method *name* with the specified arguments, plus of course any
    arguments added by the caller\. In other words, both of the following
    commands will cause the object's __dosomething__ type method to be
    called when __$button__ is pressed:

        $button configure -command [list $type dosomething myargument]

        $button configure -command [mytypemethod dosomething myargument]

    Type commands cannot be renamed, so in practice there's little difference
    between the two forms\. __mytypemethod__ is provided for parallelism with
    __mymethod__\.

  - <a name='62'></a>__myproc__ *name* ?*args\.\.\.*?

    The __myproc__ command is used for formatting callback commands to be
    passed to other objects\. It returns a command that when called will invoke
    the type proc *name* with the specified arguments, plus of course any
    arguments added by the caller\. In other words, both of the following
    commands will cause the object's __dosomething__ proc to be called when
    __$button__ is pressed:

        $button configure -command [list ${type}::dosomething myargument]

        $button configure -command [myproc dosomething myargument]

  - <a name='63'></a>__myvar__ *name*

    Given an instance variable name, returns the fully qualified name\. Use this
    if you're passing the variable to some other object, e\.g\., as a
    __\-textvariable__ to a Tk label widget\.

  - <a name='64'></a>__mytypevar__ *name*

    Given an type variable name, returns the fully qualified name\. Use this if
    you're passing the variable to some other object, e\.g\., as a
    __\-textvariable__ to a Tk label widget\.

  - <a name='65'></a>__from__ *argvName* *option* ?*defvalue*?

    The __from__ command plucks an option value from a list of options and
    their values, such as is passed into a type's __constructor__\.
    *argvName* must be the name of a variable containing such a list;
    *option* is the name of the specific option\.

    __from__ looks for *option* in the option list\. If it is found, it and
    its value are removed from the list, and the value is returned\. If
    *option* doesn't appear in the list, then the *defvalue* is returned\. If
    the option is locally\-defined option, and *defvalue* is not specified,
    then the option's default value as specified in the type definition will be
    returned instead\.

  - <a name='66'></a>__install__ *compName* __using__ *objType* *objName* *args\.\.\.*

    Creates a new object of type *objType* called *objName* and installs it
    as component *compName*, as described in [Components and
    Delegation](#subsection7)\. Any additional *args\.\.\.* are passed along
    with the name to the *objType* command\. If this is a __snit::type__,
    then the following two commands are equivalent:

        install myComp using myObjType $self.myComp args...

        set myComp [myObjType $self.myComp args...]

    Note that whichever method is used, *compName* must still be declared in
    the type definition using __component__, or must be referenced in at
    least one __delegate__ statement\.

    If this is a __snit::widget__ or __snit::widgetadaptor__, and if
    options have been delegated to component *compName*, then those options
    will receive default values from the Tk option database\. Note that it
    doesn't matter whether the component to be installed is a widget or not\. See
    [The Tk Option Database](#subsection9) for more information\.

    __install__ cannot be used to install type components; just assign the
    type component's command name to the type component's variable instead\.

  - <a name='67'></a>__installhull__ __using__ *widgetType* *args\.\.\.*

  - <a name='68'></a>__installhull__ *name*

    The constructor of a __snit::widgetadaptor__ must create a widget to be
    the object's hull component; the widget is installed as the hull component
    using this command\. Note that the installed widget's name must be
    __$win__\. This command has two forms\.

    The first form specifies the *widgetType* and the *args\.\.\.* \(that is,
    the hardcoded option list\) to use in creating the hull\. Given this form,
    __installhull__ creates the hull widget, and initializes any options
    delegated to the hull from the Tk option database\.

    In the second form, the hull widget has already been created; note that its
    name must be "$win"\. In this case, the Tk option database is *not* queried
    for any options delegated to the hull\. The longer form is preferred;
    however, the shorter form allows the programmer to adapt a widget created
    elsewhere, which is sometimes useful\. For example, it can be used to adapt a
    "page" widget created by a __BWidgets__ tabbed notebook or pages manager
    widget\.

    See [The Tk Option Database](#subsection9) for more information about
    __snit::widgetadaptor__s and the option database\.

  - <a name='69'></a>__variable__ *name*

    Normally, instance variables are defined in the type definition along with
    the options, methods, and so forth; such instance variables are
    automatically visible in all instance code \(e\.g\., method bodies\)\. However,
    instance code can use the __variable__ command to declare instance
    variables that don't appear in the type definition, and also to bring
    variables from other namespaces into scope in the usual way\.

    It's generally clearest to define all instance variables in the type
    definition, and omit declaring them in methods and so forth\.

    Note that this is an instance\-specific version of the standard Tcl
    __::variable__ command\.

  - <a name='70'></a>__typevariable__ *name*

    Normally, type variables are defined in the type definition, along with the
    instance variables; such type variables are automatically visible in all of
    the type's code\. However, type methods, instance methods and so forth can
    use __typevariable__ to declare type variables that don't appear in the
    type definition\.

    It's generally clearest to declare all type variables in the type
    definition, and omit declaring them in methods, type methods, etc\.

  - <a name='71'></a>__varname__ *name*

    __Deprecated\.__ Use __myvar__ instead\.

    Given an instance variable name, returns the fully qualified name\. Use this
    if you're passing the variable to some other object, e\.g\., as a
    __\-textvariable__ to a Tk label widget\.

  - <a name='72'></a>__typevarname__ *name*

    __Deprecated\.__ Use __mytypevar__ instead\.

    Given a type variable name, returns the fully qualified name\. Use this if
    you're passing the type variable to some other object, e\.g\., as a
    __\-textvariable__ to a Tk label widget\.

  - <a name='73'></a>__codename__ *name*

    __Deprecated\.__ Use __myproc__ instead\. Given the name of a proc
    \(but not a type or instance method\), returns the fully\-qualified command
    name, suitable for passing as a callback\.

## <a name='subsection7'></a>Components and Delegation

When an object includes other objects, as when a toolbar contains buttons or a
GUI object contains an object that references a database, the included object is
called a component\. The standard way to handle component objects owned by a Snit
object is to declare them using __component__, which creates a component
instance variable\. In the following example, a __dog__ object has a
__tail__ object:

    snit::type dog {
        component mytail

        constructor {args} {
            set mytail [tail %AUTO% -partof $self]
            $self configurelist $args
        }

        method wag {} {
            $mytail wag
        }
    }

    snit::type tail {
        option -length 5
        option -partof
        method wag {} { return "Wag, wag, wag."}
    }

Because the __tail__ object's name is stored in an instance variable, it's
easily accessible in any method\.

The __install__ command provides an alternate way to create and install the
component:

    snit::type dog {
        component mytail

        constructor {args} {
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }

        method wag {} {
            $mytail wag
        }
    }

For __snit::type__s, the two methods are equivalent; for
__snit::widget__s and __snit::widgetadaptor__s, the __install__
command properly initializes the widget's options by querying [The Tk Option
Database](#subsection9)\.

In the above examples, the __dog__ object's __wag__ method simply calls
the __tail__ component's __wag__ method\. In OO jargon, this is called
delegation\. Snit provides an easier way to do this:

    snit::type dog {
        delegate method wag to mytail

        constructor {args} {
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }
    }

The __delegate__ statement in the type definition implicitly defines the
instance variable __mytail__ to hold the component's name \(though it's good
form to use __component__ to declare it explicitly\); it also defines the
__dog__ object's __wag__ method, delegating it to the __mytail__
component\.

If desired, all otherwise unknown methods can be delegated to a specific
component:

        snit::type dog {
    	delegate method * to mytail

    	constructor {args} {
    	    set mytail [tail %AUTO% -partof $self]
    	    $self configurelist $args
    	}

    	method bark { return "Bark, bark, bark!" }
        }

In this case, a __dog__ object will handle its own __bark__ method; but
__wag__ will be passed along to __mytail__\. Any other method, being
recognized by neither __dog__ nor __tail__, will simply raise an error\.

Option delegation is similar to method delegation, except for the interactions
with the Tk option database; this is described in [The Tk Option
Database](#subsection9)\.

## <a name='subsection8'></a>Type Components and Delegation

The relationship between type components and instance components is identical to
that between type variables and instance variables, and that between type
methods and instance methods\. Just as an instance component is an instance
variable that holds the name of a command, so a type component is a type
variable that holds the name of a command\. In essence, a type component is a
component that's shared by every instance of the type\.

Just as __delegate method__ can be used to delegate methods to instance
components, as described in [Components and Delegation](#subsection7), so
__delegate typemethod__ can be used to delegate type methods to type
components\.

Note also that as of Snit 0\.95 __delegate method__ can delegate methods to
both instance components and type components\.

## <a name='subsection9'></a>The Tk Option Database

This section describes how Snit interacts with the Tk option database, and
assumes the reader has a working knowledge of the option database and its uses\.
The book *Practical Programming in Tcl and Tk* by Welch et al has a good
introduction to the option database, as does *Effective Tcl/Tk Programming*\.

Snit is implemented so that most of the time it will simply do the right thing
with respect to the option database, provided that the widget developer does the
right thing by Snit\. The body of this section goes into great deal about what
Snit requires\. The following is a brief statement of the requirements, for
reference\.

  - If the __snit::widget__'s default widget class is not what is desired,
    set it explicitly using __widgetclass__ in the widget definition\.

  - When defining or delegating options, specify the resource and class names
    explicitly when if the defaults aren't what you want\.

  - Use __installhull using__ to install the hull for
    __snit::widgetadaptor__s\.

  - Use __install__ to install all other components\.

The interaction of Tk widgets with the option database is a complex thing; the
interaction of Snit with the option database is even more so, and repays
attention to detail\.

__Setting the widget class:__ Every Tk widget has a widget class\. For Tk
widgets, the widget class name is the just the widget type name with an initial
capital letter, e\.g\., the widget class for __button__ widgets is "Button"\.

Similarly, the widget class of a __snit::widget__ defaults to the
unqualified type name with the first letter capitalized\. For example, the widget
class of

    snit::widget ::mylibrary::scrolledText { ... }

is "ScrolledText"\. The widget class can also be set explicitly using the
__widgetclass__ statement within the __snit::widget__ definition\.

Any widget can be used as the __hulltype__ provided that it supports the
__\-class__ option for changing its widget class name\. See the discussion of
the __hulltype__ command, above\. The user may pass __\-class__ to the
widget at instantion\.

The widget class of a __snit::widgetadaptor__ is just the widget class of
its hull widget; this cannot be changed unless the hull widget supports
__\-class__, in which case it will usually make more sense to use
__snit::widget__ rather than __snit::widgetadaptor__\.

__Setting option resource names and classes:__ In Tk, every option has three
names: the option name, the resource name, and the class name\. The option name
begins with a hyphen and is all lowercase; it's used when creating widgets, and
with the __configure__ and __cget__ commands\.

The resource and class names are used to initialize option default values by
querying the Tk option database\. The resource name is usually just the option
name minus the hyphen, but may contain uppercase letters at word boundaries; the
class name is usually just the resource name with an initial capital, but not
always\. For example, here are the option, resource, and class names for several
__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget options:

    -background         background         Background
    -borderwidth        borderWidth        BorderWidth
    -insertborderwidth  insertBorderWidth  BorderWidth
    -padx               padX               Pad

As is easily seen, sometimes the resource and class names can be inferred from
the option name, but not always\.

Snit options also have a resource name and a class name\. By default, these names
follow the rule given above: the resource name is the option name without the
hyphen, and the class name is the resource name with an initial capital\. This is
true for both locally\-defined options and explicitly delegated options:

        snit::widget mywidget {
            option -background
            delegate option -borderwidth to hull
            delegate option * to text
    	# ...
        }

In this case, the widget class name is "Mywidget"\. The widget has the following
options: __\-background__, which is locally defined, and
__\-borderwidth__, which is explicitly delegated; all other widgets are
delegated to a component called "text", which is probably a Tk
__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget\. If so, __mywidget__
has all the same options as a __[text](\.\./\.\./\.\./\.\./index\.md\#text)__
widget\. The option, resource, and class names are as follows:

    -background  background  Background
    -borderwidth borderwidth Borderwidth
    -padx        padX        Pad

Note that the locally defined option, __\-background__, happens to have the
same three names as the standard Tk __\-background__ option; and
__\-pad__, which is delegated implicitly to the __text__ component, has
the same three names for __mywidget__ as it does for the
__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget\. __\-borderwidth__, on
the other hand, has different resource and class names than usual, because the
internal word "width" isn't capitalized\. For consistency, it should be; this is
done as follows:

        snit::widget mywidget {
    	option -background
    	delegate option {-borderwidth borderWidth} to hull
    	delegate option * to text
    	# ...
        }

The class name will default to "BorderWidth", as expected\.

Suppose, however, that __mywidget__ also delegated __\-padx__ and
__\-pady__ to the hull\. In this case, both the resource name and the class
name must be specified explicitly:

        snit::widget mywidget {
    	option -background
    	delegate option {-borderwidth borderWidth} to hull
    	delegate option {-padx padX Pad} to hull
    	delegate option {-pady padY Pad} to hull
    	delegate option * to text
    	# ...
        }

__Querying the option database:__ If you set your widgetclass and option
names as described above, Snit will query the option database when each instance
is created, and will generally do the right thing when it comes to querying the
option database\. The remainder of this section goes into the gory details\.

__Initializing locally defined options:__ When an instance of a snit::widget
is created, its locally defined options are initialized as follows: each
option's resource and class names are used to query the Tk option database\. If
the result is non\-empty, it is used as the option's default; otherwise, the
default hardcoded in the type definition is used\. In either case, the default
can be overridden by the caller\. For example,

        option add *Mywidget.texture pebbled

        snit::widget mywidget {
    	option -texture smooth
    	# ...
        }

        mywidget .mywidget -texture greasy

Here, __\-texture__ would normally default to "smooth", but because of the
entry added to the option database it defaults to "pebbled"\. However, the caller
has explicitly overridden the default, and so the new widget will be "greasy"\.

__Initializing options delegated to the hull:__ A __snit::widget__'s
hull is a widget, and given that its class has been set it is expected to query
the option database for itself\. The only exception concerns options that are
delegated to it with a different name\. Consider the following code:

        option add *Mywidget.borderWidth 5
        option add *Mywidget.relief sunken
        option add *Mywidget.hullbackground red
        option add *Mywidget.background green

        snit::widget mywidget {
    	delegate option -borderwidth to hull
    	delegate option -hullbackground to hull as -background
    	delegate option * to hull
    	# ...
        }

        mywidget .mywidget

        set A [.mywidget cget -relief]
        set B [.mywidget cget -hullbackground]
        set C [.mywidget cget -background]
        set D [.mywidget cget -borderwidth]

The question is, what are the values of variables A, B, C and D?

The value of A is "sunken"\. The hull is a Tk frame that has been given the
widget class "Mywidget"; it will automatically query the option database and
pick up this value\. Since the __\-relief__ option is implicitly delegated to
the hull, Snit takes no action\.

The value of B is "red"\. The hull will automatically pick up the value "green"
for its __\-background__ option, just as it picked up the __\-relief__
value\. However, Snit knows that __\-hullbackground__ is mapped to the hull's
__\-background__ option; hence, it queries the option database for
__\-hullbackground__ and gets "red" and updates the hull accordingly\.

The value of C is also "red", because __\-background__ is implicitly
delegated to the hull; thus, retrieving it is the same as retrieving
__\-hullbackground__\. Note that this case is unusual; in practice,
__\-background__ would probably be explicitly delegated to some other
component\.

The value of D is "5", but not for the reason you think\. Note that as it is
defined above, the resource name for __\-borderwidth__ defaults to
"borderwidth", whereas the option database entry is "borderWidth"\. As with
__\-relief__, the hull picks up its own __\-borderwidth__ option before
Snit does anything\. Because the option is delegated under its own name, Snit
assumes that the correct thing has happened, and doesn't worry about it any
further\.

For __snit::widgetadaptor__s, the case is somewhat altered\. Widget adaptors
retain the widget class of their hull, and the hull is not created automatically
by Snit\. Instead, the __snit::widgetadaptor__ must call __installhull__
in its constructor\. The normal way to do this is as follows:

        snit::widgetadaptor mywidget {
    	# ...
    	constructor {args} {
    	    # ...
    	    installhull using text -foreground white
    	    #
    	}
    	#...
        }

In this case, the __installhull__ command will create the hull using a
command like this:

    set hull [text $win -foreground white]

The hull is a __[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget, so its
widget class is "Text"\. Just as with __snit::widget__ hulls, Snit assumes
that it will pick up all of its normal option values automatically; options
delegated from a different name are initialized from the option database in the
same way\.

__Initializing options delegated to other components:__ Non\-hull components
are matched against the option database in two ways\. First, a component widget
remains a widget still, and therefore is initialized from the option database in
the usual way\. Second, the option database is queried for all options delegated
to the component, and the component is initialized accordingly\-\-provided that
the __install__ command is used to create it\.

Before option database support was added to Snit, the usual way to create a
component was to simply create it in the constructor and assign its command name
to the component variable:

        snit::widget mywidget {
    	delegate option -background to myComp

    	constructor {args} {
    	    set myComp [text $win.text -foreground black]
    	}
        }

The drawback of this method is that Snit has no opportunity to initialize the
component properly\. Hence, the following approach is now used:

        snit::widget mywidget {
    	delegate option -background to myComp

    	constructor {args} {
    	    install myComp using text $win.text -foreground black
    	}
        }

The __install__ command does the following:

  - Builds a list of the options explicitly included in the __install__
    command \-\- in this case, __\-foreground__\.

  - Queries the option database for all options delegated explicitly to the
    named component\.

  - Creates the component using the specified command, after inserting into it a
    list of options and values read from the option database\. Thus, the
    explicitly included options \(__\-foreground__\) will override anything
    read from the option database\.

  - If the widget definition implicitly delegated options to the component using
    __delegate option \*__, then Snit calls the newly created component's
    __configure__ method to receive a list of all of the component's
    options\. From this Snit builds a list of options implicitly delegated to the
    component that were not explicitly included in the __install__ command\.
    For all such options, Snit queries the option database and configures the
    component accordingly\.

__Non\-widget components:__ The option database is never queried for
__snit::type__s, since it can only be queried given a Tk widget name\.
However, __snit::widget__s can have non\-widget components\. And if options
are delegated to those components, and if the __install__ command is used to
install those components, then they will be initialized from the option database
just as widget components are\.

## <a name='subsection10'></a>Macros and Meta\-programming

The __snit::macro__ command enables a certain amount of meta\-programming
with Snit classes\. For example, suppose you like to define properties: instance
variables that have set/get methods\. Your code might look like this:

    snit::type dog {
        variable mood happy

        method getmood {} {
            return $mood
        }

        method setmood {newmood} {
            set mood $newmood
        }
    }

That's nine lines of text per property\. Or, you could define the following
__snit::macro__:

    snit::macro property {name initValue} {
        variable $name $initValue

        method get$name {} "return $name"

        method set$name {value} "set $name \$value"
    }

Note that a __snit::macro__ is just a normal Tcl proc defined in the slave
interpreter used to compile type and widget definitions; as a result, it has
access to all the commands used to define types and widgets\.

Given this new macro, you can define a property in one line of code:

    snit::type dog {
        property mood happy
    }

Within a macro, the commands __variable__ and
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ refer to the Snit type\-definition
commands, not the standard Tcl commands\. To get the standard Tcl commands, use
__\_variable__ and __\_proc__\.

Because a single slave interpreter is used for compiling all Snit types and
widgets in the application, there's the possibility of macro name collisions\. If
you're writing a reuseable package using Snit, and you use some
__snit::macro__s, define them in your package namespace:

    snit::macro mypkg::property {name initValue} { ... }

    snit::type dog {
        mypkg::property mood happy
    }

This leaves the global namespace open for application authors\.

## <a name='subsection11'></a>Validation Types

A validation type is an object that can be used to validate Tcl values of a
particular kind\. For example, __snit::integer__ is used to validate that a
Tcl value is an integer\.

Every validation type has a __validate__ method which is used to do the
validation\. This method must take a single argument, the value to be validated;
further, it must do nothing if the value is valid, but throw an error if the
value is invalid:

    snit::integer validate 5     ;# Does nothing
    snit::integer validate 5.0   ;# Throws an error (not an integer!)

The __validate__ method will always return the validated value on success,
and throw the __\-errorcode__ INVALID on error\.

Snit defines a family of validation types, all of which are implemented as
__snit::type__'s\. They can be used as is; in addition, their instances serve
as parameterized subtypes\. For example, a probability is a number between 0\.0
and 1\.0 inclusive:

    snit::double probability -min 0.0 -max 1.0

The example above creates an instance of __snit::double__\-\-a validation
subtype\-\-called __probability__, which can be used to validate probability
values:

    probability validate 0.5   ;# Does nothing
    probability validate 7.9   ;# Throws an error

Validation subtypes can be defined explicitly, as in the above example; when a
locally\-defined option's __\-type__ is specified, they may also be created on
the fly:

    snit::enum ::dog::breed -values {mutt retriever sheepdog}

    snit::type dog {
        # Define subtypes on the fly...
        option -breed -type {
            snit::enum -values {mutt retriever sheepdog}
        }

        # Or use predefined subtypes...
        option -breed -type ::dog::breed
    }

Any object that has a __validate__ method with the semantics described above
can be used as a validation type; see [Defining Validation
Types](#subsection12) for information on how to define new ones\.

Snit defines the following validation types:

  - <a name='74'></a>__snit::boolean__ __validate__ ?*value*?

  - <a name='75'></a>__snit::boolean__ *name*

    Validates Tcl boolean values: 1, 0, __on__, __off__, __yes__,
    __no__, __true__, __false__\. It's possible to define
    subtypes\-\-that is, instances\-\-of __snit::boolean__, but as it has no
    options there's no reason to do so\.

  - <a name='76'></a>__snit::double__ __validate__ ?*value*?

  - <a name='77'></a>__snit::double__ *name* ?*option* *value*\.\.\.?

    Validates floating\-point values\. Subtypes may be created with the following
    options:

      * __\-min__ *min*

        Specifies a floating\-point minimum bound; a value is invalid if it is
        strictly less than *min*\.

      * __\-max__ *max*

        Specifies a floating\-point maximum bound; a value is invalid if it is
        strictly greater than *max*\.

  - <a name='78'></a>__snit::enum__ __validate__ ?*value*?

  - <a name='79'></a>__snit::enum__ *name* ?*option* *value*\.\.\.?

    Validates that a value comes from an enumerated list\. The base type is of
    little use by itself, as only subtypes actually have an enumerated list to
    validate against\. Subtypes may be created with the following options:

      * __\-values__ *list*

        Specifies a list of valid values\. A value is valid if and only if it's
        included in the list\.

  - <a name='80'></a>__snit::fpixels__ __validate__ ?*value*?

  - <a name='81'></a>__snit::fpixels__ *name* ?*option* *value*\.\.\.?

    *Tk programs only\.* Validates screen distances, in any of the forms
    accepted by __winfo fpixels__\. Subtypes may be created with the
    following options:

      * __\-min__ *min*

        Specifies a minimum bound; a value is invalid if it is strictly less
        than *min*\. The bound may be expressed in any of the forms accepted by
        __winfo fpixels__\.

      * __\-max__ *max*

        Specifies a maximum bound; a value is invalid if it is strictly greater
        than *max*\. The bound may be expressed in any of the forms accepted by
        __winfo fpixels__\.

  - <a name='82'></a>__snit::integer__ __validate__ ?*value*?

  - <a name='83'></a>__snit::integer__ *name* ?*option* *value*\.\.\.?

    Validates integer values\. Subtypes may be created with the following
    options:

      * __\-min__ *min*

        Specifies an integer minimum bound; a value is invalid if it is strictly
        less than *min*\.

      * __\-max__ *max*

        Specifies an integer maximum bound; a value is invalid if it is strictly
        greater than *max*\.

  - <a name='84'></a>__snit::listtype__ __validate__ ?*value*?

  - <a name='85'></a>__snit::listtype__ *name* ?*option* *value*\.\.\.?

    Validates Tcl lists\. Subtypes may be created with the following options:

      * __\-minlen__ *min*

        Specifies a minimum list length; the value is invalid if it has fewer
        than *min* elements\. Defaults to 0\.

      * __\-maxlen__ *max*

        Specifies a maximum list length; the value is invalid if it more than
        *max* elements\.

      * __\-type__ *type*

        Specifies the type of the list elements; *type* must be the name of a
        validation type or subtype\. In the following example, the value of
        __\-numbers__ must be a list of integers\.

    option -numbers -type {snit::listtype -type snit::integer}

        Note that this option doesn't support defining new validation subtypes
        on the fly; that is, the following code will not work \(yet, anyway\):

    option -numbers -type {
        snit::listtype -type {snit::integer -min 5}
    }

        Instead, define the subtype explicitly:

    snit::integer gt4 -min 5

    snit::type mytype {
        option -numbers -type {snit::listtype -type gt4}
    }

  - <a name='86'></a>__snit::pixels__ __validate__ ?*value*?

  - <a name='87'></a>__snit::pixels__ *name* ?*option* *value*\.\.\.?

    *Tk programs only\.* Validates screen distances, in any of the forms
    accepted by __winfo pixels__\. Subtypes may be created with the following
    options:

      * __\-min__ *min*

        Specifies a minimum bound; a value is invalid if it is strictly less
        than *min*\. The bound may be expressed in any of the forms accepted by
        __winfo pixels__\.

      * __\-max__ *max*

        Specifies a maximum bound; a value is invalid if it is strictly greater
        than *max*\. The bound may be expressed in any of the forms accepted by
        __winfo pixels__\.

  - <a name='88'></a>__snit::stringtype__ __validate__ ?*value*?

  - <a name='89'></a>__snit::stringtype__ *name* ?*option* *value*\.\.\.?

    Validates Tcl strings\. The base type is of little use by itself, since very
    Tcl value is also a valid string\. Subtypes may be created with the following
    options:

      * __\-minlen__ *min*

        Specifies a minimum string length; the value is invalid if it has fewer
        than *min* characters\. Defaults to 0\.

      * __\-maxlen__ *max*

        Specifies a maximum string length; the value is invalid if it has more
        than *max* characters\.

      * __\-glob__ *pattern*

        Specifies a __string match__ pattern; the value is invalid if it
        doesn't match the pattern\.

      * __\-regexp__ *regexp*

        Specifies a regular expression; the value is invalid if it doesn't match
        the regular expression\.

      * __\-nocase__ *flag*

        By default, both __\-glob__ and __\-regexp__ matches are
        case\-sensitive\. If __\-nocase__ is set to true, then both
        __\-glob__ and __\-regexp__ matches are case\-insensitive\.

  - <a name='90'></a>__snit::window__ __validate__ ?*value*?

  - <a name='91'></a>__snit::window__ *name*

    *Tk programs only\.* Validates Tk window names\. The value must cause
    __winfo exists__ to return true; otherwise, the value is invalid\. It's
    possible to define subtypes\-\-that is, instances\-\-of __snit::window__,
    but as it has no options at present there's no reason to do so\.

## <a name='subsection12'></a>Defining Validation Types

There are three ways to define a new validation type: as a subtype of one of
Snit's validation types, as a validation type command, and as a full\-fledged
validation type similar to those provided by Snit\. Defining subtypes of Snit's
validation types is described above, under [Validation
Types](#subsection11)\.

The next simplest way to create a new validation type is as a validation type
command\. A validation type is simply an object that has a __validate__
method; the __validate__ method must take one argument, a value, return the
value if it is valid, and throw an error with __\-errorcode__ INVALID if the
value is invalid\. This can be done with a simple
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__\. For example, the
__snit::boolean__ validate type could have been implemented like this:

    proc ::snit::boolean {"validate" value} {
        if {![string is boolean -strict $value]} {
            return -code error -errorcode INVALID  "invalid boolean \"$value\", should be one of: 1, 0, ..."
        }

        return $value
    }

A validation type defined in this way cannot be subtyped, of course; but for
many applications this will be sufficient\.

Finally, one can define a full\-fledged, subtype\-able validation type as a
__snit::type__\. Here's a skeleton to get you started:

    snit::type myinteger {
        # First, define any options you'd like to use to define
        # subtypes.  Give them defaults such that they won't take
        # effect if they aren't used, and marked them "read-only".
        # After all, you shouldn't be changing their values after
        # a subtype is defined.
        #
        # For example:

        option -min -default "" -readonly 1
        option -max -default "" -readonly 1

        # Next, define a "validate" type method which should do the
        # validation in the basic case.  This will allow the
        # type command to be used as a validation type.

        typemethod validate {value} {
            if {![string is integer -strict $value]} {
                return -code error -errorcode INVALID  "invalid value \"$value\", expected integer"
            }

            return $value
        }

        # Next, the constructor should validate the subtype options,
        # if any.  Since they are all readonly, we don't need to worry
        # about validating the options on change.

        constructor {args} {
            # FIRST, get the options
            $self configurelist $args

            # NEXT, validate them.

            # I'll leave this to your imagination.
        }

        # Next, define a "validate" instance method; its job is to
        # validate values for subtypes.

        method validate {value} {
            # First, call the type method to do the basic validation.
            $type validate $value

            # Now we know it's a valid integer.

            if {("" != $options(-min) && $value < $options(-min))  ||
                ("" != $options(-max) && $value > $options(-max))} {
                # It's out of range; format a detailed message about
                # the error, and throw it.

                set msg "...."

                return -code error -errorcode INVALID $msg
            }

            # Otherwise, if it's valid just return it.
            return $valid
        }
    }

And now you have a type that can be subtyped\.

The file "validate\.tcl" in the Snit distribution defines all of Snit's
validation types; you can find the complete implementation for
__snit::integer__ and the other types there, to use as examples for your own
types\.

# <a name='section4'></a>CAVEATS

If you have problems, find bugs, or new ideas you are hereby cordially invited
to submit a report of your problem, bug, or idea as explained in the section
[Bugs, Ideas, Feedback](#section8) below\.

Additionally, you might wish to join the Snit mailing list; see
[http://www\.wjduquette\.com/snit](http://www\.wjduquette\.com/snit) for
details\.

One particular area to watch is using __snit::widgetadaptor__ to adapt
megawidgets created by other megawidget packages; correct widget destruction
depends on the order of the <Destroy> bindings\. The wisest course is simply not
to do this\.

# <a name='section5'></a>KNOWN BUGS

  - Error stack traces returned by Snit 1\.x are extremely ugly and typically
    contain far too much information about Snit internals\. The error messages
    are much improved in Snit 2\.2\.

  - Also see the Project Trackers as explained in the section [Bugs, Ideas,
    Feedback](#section8) below\.

# <a name='section6'></a>HISTORY

During the course of developing Notebook \(See
[http://www\.wjduquette\.com/notebook](http://www\.wjduquette\.com/notebook)\),
my Tcl\-based personal notebook application, I found I was writing it as a
collection of objects\. I wasn't using any particular object\-oriented framework;
I was just writing objects in pure Tcl following the guidelines in my Guide to
Object Commands \(see
[http://www\.wjduquette\.com/tcl/objects\.html](http://www\.wjduquette\.com/tcl/objects\.html)\),
along with a few other tricks I'd picked up since\. And though it was working
well, it quickly became tiresome because of the amount of boilerplate code
associated with each new object type\.

So that was one thing\-\-tedium is a powerful motivator\. But the other thing I
noticed is that I wasn't using inheritance at all, and I wasn't missing it\.
Instead, I was using delegation: objects that created other objects and
delegated methods to them\.

And I said to myself, "This is getting tedious\.\.\.there has got to be a better
way\." And one afternoon, on a whim, I started working on Snit, an object system
that works the way Tcl works\. Snit doesn't support inheritance, but it's great
at delegation, and it makes creating megawidgets easy\.

If you have any comments or suggestions \(or bug reports\!\) don't hesitate to send
me e\-mail at [will@wjduquette\.com](will@wjduquette\.com)\. In addition,
there's a Snit mailing list; you can find out more about it at the Snit home
page \(see [http://www\.wjduquette\.com/snit](http://www\.wjduquette\.com/snit)\)\.

# <a name='section7'></a>CREDITS

Snit has been designed and implemented from the very beginning by William H\.
Duquette\. However, much credit belongs to the following people for using Snit
and providing me with valuable feedback: Rolf Ade, Colin McCormack, Jose
Nazario, Jeff Godfrey, Maurice Diamanti, Egon Pasztor, David S\. Cargo, Tom
Krehbiel, Michael Cleverly, Andreas Kupries, Marty Backe, Andy Goth, Jeff Hobbs,
Brian Griffin, Donal Fellows, Miguel Sofer, Kenneth Green, and Anton Kovalenko\.
If I've forgotten anyone, my apologies; let me know and I'll add your name to
the list\.

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *snit* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[BWidget](\.\./\.\./\.\./\.\./index\.md\#bwidget), [C\+\+](\.\./\.\./\.\./\.\./index\.md\#c\_),
[Incr Tcl](\.\./\.\./\.\./\.\./index\.md\#incr\_tcl),
[Snit](\.\./\.\./\.\./\.\./index\.md\#snit),
[adaptors](\.\./\.\./\.\./\.\./index\.md\#adaptors),
[class](\.\./\.\./\.\./\.\./index\.md\#class), [mega
widget](\.\./\.\./\.\./\.\./index\.md\#mega\_widget),
[object](\.\./\.\./\.\./\.\./index\.md\#object), [object
oriented](\.\./\.\./\.\./\.\./index\.md\#object\_oriented),
[type](\.\./\.\./\.\./\.\./index\.md\#type),
[widget](\.\./\.\./\.\./\.\./index\.md\#widget), [widget
adaptors](\.\./\.\./\.\./\.\./index\.md\#widget\_adaptors)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003\-2009, by William H\. Duquette
