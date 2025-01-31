
[//000000001]: # (snitfaq \- Snit's Not Incr Tcl, OO system)
[//000000002]: # (Generated from file 'snitfaq\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2003\-2006, by William H\. Duquette)
[//000000004]: # (snitfaq\(n\) 2\.2 tcllib "Snit's Not Incr Tcl, OO system")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

snitfaq \- Snit Frequently Asked Questions

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [OVERVIEW](#section2)

      - [What is this document?](#subsection1)

      - [What is Snit?](#subsection2)

      - [What version of Tcl does Snit require?](#subsection3)

      - [Where can I download Snit?](#subsection4)

      - [What are Snit's goals?](#subsection5)

      - [How is Snit different from other OO frameworks?](#subsection6)

      - [What can I do with Snit?](#subsection7)

  - [SNIT VERSIONS](#section3)

      - [Which version of Snit should I use?](#subsection8)

      - [How do I select the version of Snit I want to use?](#subsection9)

      - [How are Snit 1\.3 and Snit 2\.2 incompatible?](#subsection10)

      - [Are there other differences between Snit 1\.x and Snit
        2\.2?](#subsection11)

  - [OBJECTS](#section4)

      - [What is an object?](#subsection12)

      - [What is an abstract data type?](#subsection13)

      - [What kinds of abstract data types does Snit
        provide?](#subsection14)

      - [What is a snit::type?](#subsection15)

      - [What is a snit::widget?, the short story](#subsection16)

      - [What is a snit::widgetadaptor?, the short story](#subsection17)

      - [How do I create an instance of a snit::type?](#subsection18)

      - [How do I refer to an object indirectly?](#subsection19)

      - [How can I generate the object name automatically?](#subsection20)

      - [Can types be renamed?](#subsection21)

      - [Can objects be renamed?](#subsection22)

      - [How do I destroy a Snit object?](#subsection23)

  - [INSTANCE METHODS](#section5)

      - [What is an instance method?](#subsection24)

      - [How do I define an instance method?](#subsection25)

      - [How does a client call an instance method?](#subsection26)

      - [How does an instance method call another instance
        method?](#subsection27)

      - [Are there any limitations on instance method
        names?](#subsection28)

      - [What is a hierarchical method?](#subsection29)

      - [How do I define a hierarchical method?](#subsection30)

      - [How do I call hierarchical methods?](#subsection31)

      - [How do I make an instance method private?](#subsection32)

      - [Are there any limitations on instance method
        arguments?](#subsection33)

      - [What implicit arguments are passed to each instance
        method?](#subsection34)

      - [What is $type?](#subsection35)

      - [What is $self?](#subsection36)

      - [What is $selfns?](#subsection37)

      - [What is $win?](#subsection38)

      - [How do I pass an instance method as a callback?](#subsection39)

      - [How do I delegate instance methods to a component?](#subsection40)

  - [INSTANCE VARIABLES](#section6)

      - [What is an instance variable?](#subsection41)

      - [How is a scalar instance variable defined?](#subsection42)

      - [How is an array instance variable defined?](#subsection43)

      - [What happens if I don't initialize an instance
        variable?](#subsection44)

      - [Are there any limitations on instance variable
        names?](#subsection45)

      - [Do I need to declare my instance variables in my
        methods?](#subsection46)

      - [How do I pass an instance variable's name to another
        object?](#subsection47)

      - [How do I make an instance variable public?](#subsection48)

  - [OPTIONS](#section7)

      - [What is an option?](#subsection49)

      - [How do I define an option?](#subsection50)

      - [How can a client set options at object creation?](#subsection51)

      - [How can a client retrieve an option's value?](#subsection52)

      - [How can a client set options after object
        creation?](#subsection53)

      - [How should an instance method access an option
        value?](#subsection54)

      - [How can I make an option read\-only?](#subsection55)

      - [How can I catch accesses to an option's value?](#subsection56)

      - [What is a \-cgetmethod?](#subsection57)

      - [How can I catch changes to an option's value?](#subsection58)

      - [What is a \-configuremethod?](#subsection59)

      - [How can I validate an option's value?](#subsection60)

      - [What is a \-validatemethod?](#subsection61)

  - [TYPE VARIABLES](#section8)

      - [What is a type variable?](#subsection62)

      - [How is a scalar type variable defined?](#subsection63)

      - [How is an array\-valued type variable defined?](#subsection64)

      - [What happens if I don't initialize a type
        variable?](#subsection65)

      - [Are there any limitations on type variable names?](#subsection66)

      - [Do I need to declare my type variables in my
        methods?](#subsection67)

      - [How do I pass a type variable's name to another
        object?](#subsection68)

      - [How do I make a type variable public?](#subsection69)

  - [TYPE METHODS](#section9)

      - [What is a type method?](#subsection70)

      - [How do I define a type method?](#subsection71)

      - [How does a client call a type method?](#subsection72)

      - [Are there any limitations on type method names?](#subsection73)

      - [How do I make a type method private?](#subsection74)

      - [Are there any limitations on type method
        arguments?](#subsection75)

      - [How does an instance or type method call a type
        method?](#subsection76)

      - [How do I pass a type method as a callback?](#subsection77)

      - [Can type methods be hierarchical?](#subsection78)

  - [PROCS](#section10)

      - [What is a proc?](#subsection79)

      - [How do I define a proc?](#subsection80)

      - [Are there any limitations on proc names?](#subsection81)

      - [How does a method call a proc?](#subsection82)

      - [How can I pass a proc to another object as a
        callback?](#subsection83)

  - [TYPE CONSTRUCTORS](#section11)

      - [What is a type constructor?](#subsection84)

      - [How do I define a type constructor?](#subsection85)

  - [CONSTRUCTORS](#section12)

      - [What is a constructor?](#subsection86)

      - [How do I define a constructor?](#subsection87)

      - [What does the default constructor do?](#subsection88)

      - [Can I choose a different set of arguments for the
        constructor?](#subsection89)

      - [Are there any limitations on constructor
        arguments?](#subsection90)

      - [Is there anything special about writing the
        constructor?](#subsection91)

  - [DESTRUCTORS](#section13)

      - [What is a destructor?](#subsection92)

      - [How do I define a destructor?](#subsection93)

      - [Are there any limitations on destructor arguments?](#subsection94)

      - [What implicit arguments are passed to the
        destructor?](#subsection95)

      - [Must components be destroyed explicitly?](#subsection96)

      - [Is there any special about writing a destructor?](#subsection97)

  - [COMPONENTS](#section14)

      - [What is a component?](#subsection98)

      - [How do I declare a component?](#subsection99)

      - [How is a component named?](#subsection100)

      - [Are there any limitations on component names?](#subsection101)

      - [What is an owned component?](#subsection102)

      - [What does the install command do?](#subsection103)

      - [Must owned components be created in the
        constructor?](#subsection104)

      - [Are there any limitations on component object
        names?](#subsection105)

      - [Must I destroy the components I own?](#subsection106)

      - [Can I expose a component's object command as part of my
        interface?](#subsection107)

      - [How do I expose a component's object command?](#subsection108)

  - [TYPE COMPONENTS](#section15)

      - [What is a type component?](#subsection109)

      - [How do I declare a type component?](#subsection110)

      - [How do I install a type component?](#subsection111)

      - [Are there any limitations on type component
        names?](#subsection112)

  - [DELEGATION](#section16)

      - [What is delegation?](#subsection113)

      - [How can I delegate a method to a component
        object?](#subsection114)

      - [Can I delegate to a method with a different name?](#subsection115)

      - [Can I delegate to a method with additional
        arguments?](#subsection116)

      - [Can I delegate a method to something other than an
        object?](#subsection117)

      - [How can I delegate a method to a type component
        object?](#subsection118)

      - [How can I delegate a type method to a type component
        object?](#subsection119)

      - [How can I delegate an option to a component
        object?](#subsection120)

      - [Can I delegate to an option with a different
        name?](#subsection121)

      - [How can I delegate any unrecognized method or option to a component
        object?](#subsection122)

      - [How can I delegate all but certain methods or options to a
        component?](#subsection123)

      - [Can a hierarchical method be delegated?](#subsection124)

  - [WIDGETS](#section17)

      - [What is a snit::widget?](#subsection125)

      - [How do I define a snit::widget?](#subsection126)

      - [How do snit::widgets differ from snit::types?](#subsection127)

      - [What is a hull component?](#subsection128)

      - [How can I set the hull type for a snit::widget?](#subsection129)

      - [How should I name widgets which are components of a
        snit::widget?](#subsection130)

  - [WIDGET ADAPTORS](#section18)

      - [What is a snit::widgetadaptor?](#subsection131)

      - [How do I define a snit::widgetadaptor?](#subsection132)

      - [Can I adapt a widget created elsewhere in the
        program?](#subsection133)

      - [Can I adapt another megawidget?](#subsection134)

  - [THE TK OPTION DATABASE](#section19)

      - [What is the Tk option database?](#subsection135)

      - [Do snit::types use the Tk option database?](#subsection136)

      - [What is my snit::widget's widget class?](#subsection137)

      - [What is my snit::widgetadaptor's widget class?](#subsection138)

      - [What are option resource and class names?](#subsection139)

      - [What are the resource and class names for my megawidget's
        options?](#subsection140)

      - [How does Snit initialize my megawidget's locally\-defined
        options?](#subsection141)

      - [How does Snit initialize delegated options?](#subsection142)

      - [How does Snit initialize options delegated to the
        hull?](#subsection143)

      - [How does Snit initialize options delegated to other
        components?](#subsection144)

      - [What happens if I install a non\-widget as a component of
        widget?](#subsection145)

  - [ENSEMBLE COMMANDS](#section20)

      - [What is an ensemble command?](#subsection146)

      - [How can I create an ensemble command using Snit?](#subsection147)

      - [How can I create an ensemble command using an instance of a
        snit::type?](#subsection148)

      - [How can I create an ensemble command using a
        snit::type?](#subsection149)

  - [PRAGMAS](#section21)

      - [What is a pragma?](#subsection150)

      - [How do I set a pragma?](#subsection151)

      - [How can I get rid of the "info" type method?](#subsection152)

      - [How can I get rid of the "destroy" type method?](#subsection153)

      - [How can I get rid of the "create" type method?](#subsection154)

      - [How can I get rid of type methods altogether?](#subsection155)

      - [Why can't I create an object that replaces an old object with the same
        name?](#subsection156)

      - [How can I make my simple type run faster?](#subsection157)

  - [MACROS](#section22)

      - [What is a macro?](#subsection158)

      - [What are macros good for?](#subsection159)

      - [How do I do conditional compilation?](#subsection160)

      - [How do I define new type definition syntax?](#subsection161)

      - [Are there are restrictions on macro names?](#subsection162)

  - [Bugs, Ideas, Feedback](#section23)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

# <a name='section2'></a>OVERVIEW

## <a name='subsection1'></a>What is this document?

This is an atypical FAQ list, in that few of the questions are frequently asked\.
Rather, these are the questions I think a newcomer to Snit should be asking\.
This file is not a complete reference to Snit, however; that information is in
the __[snit](snit\.md)__ man page\.

## <a name='subsection2'></a>What is Snit?

Snit is a framework for defining abstract data types and megawidgets in pure
Tcl\. The name "Snit" stands for "Snit's Not Incr Tcl", signifying that Snit
takes a different approach to defining objects than does Incr Tcl, the best
known object framework for Tcl\. Had I realized that Snit would become at all
popular, I'd probably have chosen something else\.

The primary purpose of Snit is to be *object glue*\-\-to help you compose
diverse objects from diverse sources into types and megawidgets with clean,
convenient interfaces so that you can more easily build your application\.

Snit isn't about theoretical purity or minimalist design; it's about being able
to do powerful things easily and consistently without having to think about
them\-\-so that you can concentrate on building your application\.

Snit isn't about implementing thousands of nearly identical carefully\-specified
lightweight thingamajigs\-\-not as individual Snit objects\. Traditional Tcl
methods will be much faster, and not much more complicated\. But Snit *is*
about implementing a clean interface to manage a collection of thousands of
nearly identical carefully\-specified lightweight thingamajigs \(e\.g\., think of
the text widget and text tags, or the canvas widget and canvas objects\)\. Snit
lets you hide the details of just how those thingamajigs are stored\-\-so that you
can ignore it, and concentrate on building your application\.

Snit isn't a way of life, a silver bullet, or the Fountain of Youth\. It's just a
way of managing complexity\-\-and of managing some of the complexity of managing
complexity\-\-so that you can concentrate on building your application\.

## <a name='subsection3'></a>What version of Tcl does Snit require?

Snit 1\.3 requires Tcl 8\.3 or later; Snit 2\.2 requires Tcl 8\.5 or later\. See
[SNIT VERSIONS](#section3) for the differences between Snit 1\.3 and Snit
2\.2\.

## <a name='subsection4'></a>Where can I download Snit?

Snit is part of Tcllib, the standard Tcl library, so you might already have it\.
It's also available at the Snit Home Page,
[http://www\.wjduquette\.com/snit](http://www\.wjduquette\.com/snit)\.

## <a name='subsection5'></a>What are Snit's goals?

  - A Snit object should be at least as efficient as a hand\-coded Tcl object
    \(see
    [http://www\.wjduquette\.com/tcl/objects\.html](http://www\.wjduquette\.com/tcl/objects\.html)\)\.

  - The fact that Snit was used in an object's implementation should be
    transparent \(and irrelevant\) to clients of that object\.

  - Snit should be able to encapsulate objects from other sources, particularly
    Tk widgets\.

  - Snit megawidgets should be \(to the extent possible\) indistinguishable in
    interface from Tk widgets\.

  - Snit should be Tclish\-\-that is, rather than trying to emulate C\+\+,
    Smalltalk, or anything else, it should try to emulate Tcl itself\.

  - It should have a simple, easy\-to\-use, easy\-to\-remember syntax\.

## <a name='subsection6'></a>How is Snit different from other OO frameworks?

Snit is unique among Tcl object systems in that it is based not on inheritance
but on delegation\. Object systems based on inheritance only allow you to inherit
from classes defined using the same system, and that's a shame\. In Tcl, an
object is anything that acts like an object; it shouldn't matter how the object
was implemented\. I designed Snit to help me build applications out of the
materials at hand; thus, Snit is designed to be able to incorporate and build on
any object, whether it's a hand\-coded object, a Tk widget, an Incr Tcl object, a
BWidget or almost anything else\.

Note that you can achieve the effect of inheritance using
[COMPONENTS](#section14) and [DELEGATION](#section16)\-\-and you can
inherit from anything that looks like a Tcl object\.

## <a name='subsection7'></a>What can I do with Snit?

Using Snit, a programmer can:

  - Create abstract data types and Tk megawidgets\.

  - Define instance variables, type variables, and Tk\-style options\.

  - Define constructors, destructors, instance methods, type methods, procs\.

  - Assemble a type out of component types\. Instance methods and options can be
    delegated to the component types automatically\.

# <a name='section3'></a>SNIT VERSIONS

## <a name='subsection8'></a>Which version of Snit should I use?

The current Snit distribution includes two versions, Snit 1\.3 and Snit 2\.2\. The
reason that both are included is that Snit 2\.2 takes advantage of a number of
new features of Tcl 8\.5 to improve run\-time efficiency; as a side\-effect, the
ugliness of Snit's error messages and stack traces has been reduced
considerably\. The cost of using Snit 2\.2, of course, is that you must target Tcl
8\.5\.

Snit 1\.3, on the other hand, lacks Snit 2\.2's optimizations, but requires only
Tcl 8\.3 and later\.

In short, if you're targetting Tcl 8\.3 or 8\.4 you should use Snit 1\.3\. If you
can afford to target Tcl 8\.5, you should definitely use Snit 2\.2\. If you will be
targetting both, you can use Snit 1\.3 exclusively, or \(if your code is
unaffected by the minor incompatibilities between the two versions\) you can use
Snit 1\.3 for Tcl 8\.4 and Snit 2\.2 for Tcl 8\.5\.

## <a name='subsection9'></a>How do I select the version of Snit I want to use?

To always use Snit 1\.3 \(or a later version of Snit 1\.x\), invoke Snit as follows:

    package require snit 1.3

To always use Snit 2\.2 \(or a later version of Snit 2\.x\), say this instead:

    package require snit 2.2

Note that if you request Snit 2\.2 explicitly, your application will halt with
Tcl 8\.4, since Snit 2\.2 is unavailable for Tcl 8\.4\.

If you wish your application to always use the latest available version of Snit,
don't specify a version number:

    package require snit

Tcl will find and load the latest version that's available relative to the
version of Tcl being used\. In this case, be careful to avoid using any
incompatible features\.

## <a name='subsection10'></a>How are Snit 1\.3 and Snit 2\.2 incompatible?

To the extent possible, Snit 2\.2 is intended to be a drop\-in replacement for
Snit 1\.3\. Unfortunately, some incompatibilities were inevitable because Snit 2\.2
uses Tcl 8\.5's new __namespace ensemble__ mechanism to implement subcommand
dispatch\. This approach is much faster than the mechanism used in Snit 1\.3, and
also results in much better error messages; however, it also places new
constraints on the implementation\.

There are four specific incompatibilities between Snit 1\.3 and Snit 2\.2\.

  - Snit 1\.3 supports implicit naming of objects\. Suppose you define a new
    __snit::type__ called __dog__\. You can create instances of
    __dog__ in three ways:

    dog spot               ;# Explicit naming
    set obj1 [dog %AUTO%]  ;# Automatic naming
    set obj2 [dog]         ;# Implicit naming

    In Snit 2\.2, type commands are defined using the __namespace ensemble__
    mechanism; and __namespace ensemble__ doesn't allow an ensemble command
    to be called without a subcommand\. In short, using __namespace
    ensemble__ there's no way to support implicit naming\.

    All is not lost, however\. If the type has no type methods, then the type
    command is a simple command rather than an ensemble, and __namespace
    ensemble__ is not used\. In this case, implicit naming is still possible\.

    In short, you can have implicit naming if you're willing to do without type
    methods \(including the standard type methods, like __$type info__\)\. To
    do so, use the __\-hastypemethods__ pragma:

    pragma -hastypemethods 0

  - Hierarchical methods and type methods are implemented differently in Snit
    2\.2\.

    A hierarchical method is an instance method which has subcommands; these
    subcommands are themselves methods\. The Tk text widget's __tag__ command
    and its subcommands are examples of hierarchical methods\. You can implement
    such subcommands in Snit simply by including multiple words in the method
    names:

    method {tag configure} {tag args} { ... }

    method {tag cget} {tag option} {...}

    Here we've implicitly defined a __tag__ method which has two
    subcommands, __configure__ and __cget__\.

    In Snit 1\.3, hierarchical methods could be called in two ways:

    $obj tag cget -myoption      ;# The good way
    $obj {tag cget} -myoption    ;# The weird way

    In the second call, we see that a hierarchical method or type method is
    simply one whose name contains multiple words\.

    In Snit 2\.2 this is no longer the case, and the "weird" way of calling
    hierarchical methods and type methods no longer works\.

  - The third incompatibility derives from the second\. In Snit 1\.3, hierarchical
    methods were also simply methods whose name contains multiple words\. As a
    result, __$obj info methods__ returned the full names of all
    hierarchical methods\. In the example above, the list returned by __$obj
    info methods__ would include __tag configure__ and __tag cget__
    but not __tag__, since __tag__ is defined only implicitly\.

    In Snit 2\.2, hierarchical methods and type methods are no longer simply ones
    whose name contains multiple words; in the above example, the list returned
    by __$obj info methods__ would include __tag__ but not __tag
    configure__ or __tag cget__\.

  - The fourth incompatibility is due to a new feature\. Snit 2\.2 uses the new
    __namespace path__ command so that a type's code can call any command
    defined in the type's parent namespace without qualification or importation\.
    For example, suppose you have a package called __mypackage__ which
    defines a number of commands including a type, __::mypackage::mytype__\.
    Thanks to __namespace path__, the type's code can call any of the other
    commands defined in __::mypackage::__\.

    This is extremely convenient\. However, it also means that commands defined
    in the parent namespace, __::mypackage::__ can block the type's access
    to identically named commands in the global namespace\. This can lead to
    bugs\. For example, Tcllib includes a type called __::tie::std::file__\.
    This type's code calls the standard
    __[file](\.\./\.\./\.\./\.\./index\.md\#file)__ command\. When run with Snit
    2\.2, the code broke\-\- the type's command, __::tie::std::file__, is
    itself a command in the type's parent namespace, and so instead of calling
    the standard __[file](\.\./\.\./\.\./\.\./index\.md\#file)__ command, the type
    found itself calling itself\.

## <a name='subsection11'></a>Are there other differences between Snit 1\.x and Snit 2\.2?

Yes\.

  - Method dispatch is considerably faster\.

  - Many error messages and stack traces are cleaner\.

  - The __\-simpledispatch__ pragma is obsolete, and ignored if present\. In
    Snit 1\.x, __\-simpledispatch__ substitutes a faster mechanism for method
    dispatch, at the cost of losing certain features\. Snit 2\.2 method dispatch
    is faster still in all cases, so __\-simpledispatch__ is no longer
    needed\.

  - In Snit 2\.2, a type's code \(methods, type methods, etc\.\) can call commands
    from the type's parent namespace without qualifying or importing them, i\.e\.,
    type __::parentns::mytype__'s code can call __::parentns::someproc__
    as just __someproc__\.

    This is extremely useful when a type is defined as part of a larger package,
    and shares a parent namespace with the rest of the package; it means that
    the type can call other commands defined by the package without any extra
    work\.

    This feature depends on the new Tcl 8\.5 __namespace path__ command,
    which is why it hasn't been implemented for V1\.x\. V1\.x code can achieve
    something similar by placing

    namespace import [namespace parent]::*

    in a type constructor\. This is less useful, however, as it picks up only
    those commands which have already been exported by the parent namespace at
    the time the type is defined\.

# <a name='section4'></a>OBJECTS

## <a name='subsection12'></a>What is an object?

A full description of object\-oriented programming is beyond the scope of this
FAQ, obviously\. In simple terms, an object is an instance of an abstract data
type\-\-a coherent bundle of code and data\. There are many ways to represent
objects in Tcl/Tk; the best known examples are the Tk widgets\.

A Tk widget is an object; it is represented by a Tcl command\. The object's
methods are subcommands of the Tcl command\. The object's properties are options
accessed using the __configure__ and __cget__ methods\. Snit uses the
same conventions as Tk widgets do\.

## <a name='subsection13'></a>What is an abstract data type?

In computer science terms, an abstract data type is a complex data structure
along with a set of operations\-\-a stack, a queue, a binary tree, etc\-\-that is to
say, in modern terms, an object\. In systems that include some form of
inheritance the word *[class](\.\./\.\./\.\./\.\./index\.md\#class)* is usually used
instead of *abstract data type*, but as Snit doesn't implement inheritance as
it's ordinarily understood the older term seems more appropriate\. Sometimes this
is called *object\-based* programming as opposed to object\-oriented
programming\. Note that you can easily create the effect of inheritance using
[COMPONENTS](#section14) and [DELEGATION](#section16)\.

In Snit, as in Tk, a *[type](\.\./\.\./\.\./\.\./index\.md\#type)* is a command that
creates instances \-\- objects \-\- which belong to the type\. Most types define some
number of *options* which can be set at creation time, and usually can be
changed later\.

Further, an *instance* is also a Tcl command\-\-a command that gives access to
the operations which are defined for that abstract data type\. Conventionally,
the operations are defined as subcommands of the instance command\. For example,
to insert text into a Tk text widget, you use the text widget's __insert__
subcommand:

    # Create a text widget and insert some text in it.
    text .mytext -width 80 -height 24
    .mytext insert end "Howdy!"

In this example, __[text](\.\./\.\./\.\./\.\./index\.md\#text)__ is the
*[type](\.\./\.\./\.\./\.\./index\.md\#type)* command and __\.mytext__ is the
*instance* command\.

In Snit, object subcommands are generally called [INSTANCE
METHODS](#section5)\.

## <a name='subsection14'></a>What kinds of abstract data types does Snit provide?

Snit allows you to define three kinds of abstract data type:

  - __snit::type__

  - __snit::widget__

  - __snit::widgetadaptor__

## <a name='subsection15'></a>What is a snit::type?

A __snit::type__ is a non\-GUI abstract data type, e\.g\., a stack or a queue\.
__snit::type__s are defined using the __snit::type__ command\. For
example, if you were designing a kennel management system for a dog breeder,
you'd need a dog type\.

    % snit::type dog {
        # ...
    }
    ::dog
    %

This definition defines a new command \(__::dog__, in this case\) that can be
used to define dog objects\.

An instance of a __snit::type__ can have [INSTANCE METHODS](#section5),
[INSTANCE VARIABLES](#section6), [OPTIONS](#section7), and
[COMPONENTS](#section14)\. The type itself can have [TYPE
METHODS](#section9), [TYPE VARIABLES](#section8), [TYPE
COMPONENTS](#section15), and [PROCS](#section10)\.

## <a name='subsection16'></a>What is a snit::widget?, the short story

A __snit::widget__ is a Tk megawidget built using Snit; it is very similar
to a __snit::type__\. See [WIDGETS](#section17)\.

## <a name='subsection17'></a>What is a snit::widgetadaptor?, the short story

A __snit::widgetadaptor__ uses Snit to wrap an existing widget type \(e\.g\., a
Tk label\), modifying its interface to a lesser or greater extent\. It is very
similar to a __snit::widget__\. See [WIDGET ADAPTORS](#section18)\.

## <a name='subsection18'></a>How do I create an instance of a snit::type?

You create an instance of a __snit::type__ by passing the new instance's
name to the type's create method\. In the following example, we create a
__dog__ object called __spot__\.

    % snit::type dog {
        # ....
    }
    ::dog
    % dog create spot
    ::spot
    %

In general, the __create__ method name can be omitted so long as the
instance name doesn't conflict with any defined [TYPE METHODS](#section9)\.
\(See [TYPE COMPONENTS](#section15) for the special case in which this
doesn't work\.\) So the following example is identical to the previous example:

    % snit::type dog {
        # ....
    }
    ::dog
    % dog spot
    ::spot
    %

This document generally uses the shorter form\.

If the __dog__ type defines [OPTIONS](#section7), these can usually be
given defaults at creation time:

    % snit::type dog {
        option -breed mongrel
        option -color brown

        method bark {} { return "$self barks." }
    }
    ::dog
    % dog create spot -breed dalmation -color spotted
    ::spot
    % spot cget -breed
    dalmation
    % spot cget -color
    spotted
    %

Once created, the instance name now names a new Tcl command that is used to
manipulate the object\. For example, the following code makes the dog bark:

    % spot bark
    ::spot barks.
    %

## <a name='subsection19'></a>How do I refer to an object indirectly?

Some programmers prefer to save the object name in a variable, and reference it
that way\. For example,

    % snit::type dog { ... }
    ::dog
    % set d [dog spot -breed dalmation -color spotted]
    ::spot
    % $d cget -breed
    dalmation
    % $d bark
    ::spot barks.
    %

If you prefer this style, you might prefer to have Snit generate the instance's
name automatically\.

## <a name='subsection20'></a>How can I generate the object name automatically?

If you'd like Snit to generate an object name for you, use the __%AUTO%__
keyword as the requested name:

    % snit::type dog { ... }
    ::dog
    % set d [dog %AUTO%]
    ::dog2
    % $d bark
    ::dog2 barks.
    %

The __%AUTO%__ keyword can be embedded in a longer string:

    % set d [dog obj_%AUTO%]
    ::obj_dog4
    % $d bark
    ::obj_dog4 barks.
    %

## <a name='subsection21'></a>Can types be renamed?

Tcl's __rename__ command renames other commands\. It's a common technique in
Tcl to modify an existing command by renaming it and defining a new command with
the original name; the new command usually calls the renamed command\.

__snit::type__ commands, however, should never be renamed; to do so breaks
the connection between the type and its objects\.

## <a name='subsection22'></a>Can objects be renamed?

Tcl's __rename__ command renames other commands\. It's a common technique in
Tcl to modify an existing command by renaming it and defining a new command with
the original name; the new command usually calls the renamed command\.

All Snit objects \(including *widgets* and *widgetadaptors*\) can be renamed,
though this flexibility has some consequences:

  - In an instance method, the implicit argument __self__ will always
    contain the object's current name, so instance methods can always call other
    instance methods using __$self__\.

  - If the object is renamed, however, then __$self__'s value will change\.
    Therefore, don't use __$self__ for anything that will break if
    __$self__ changes\. For example, don't pass a callback command to another
    object like this:

    .btn configure -command [list $self ButtonPress]

    You'll get an error if __\.btn__ calls your command after your object is
    renamed\.

  - Instead, your object should define its callback command like this:

    .btn configure -command [mymethod ButtonPress]

    The __mymethod__ command returns code that will call the desired method
    safely; the caller of the callback can add additional arguments to the end
    of the command as usual\.

  - Every object has a private namespace; the name of this namespace is
    available in method bodies, etc\., as the value of the implicit argument
    __selfns__\. This value is constant for the life of the object\. Use
    __$selfns__ instead of __$self__ if you need a unique token to
    identify the object\.

  - When a __snit::widget__'s instance command is renamed, its Tk window
    name remains the same \-\- and is still extremely important\. Consequently, the
    Tk window name is available in method bodies as the value of the implicit
    argument __win__\. This value is constant for the life of the object\.
    When creating child windows, it's best to use __$win\.child__ rather than
    __$self\.child__ as the name of the child window\.

## <a name='subsection23'></a>How do I destroy a Snit object?

Any Snit object of any type can be destroyed by renaming it to the empty string
using the Tcl __rename__ command\.

Snit megawidgets \(i\.e\., instances of __snit::widget__ and
__snit::widgetadaptor__\) can be destroyed like any other widget: by using
the Tk __destroy__ command on the widget or on one of its ancestors in the
window hierarchy\.

Every instance of a __snit::type__ has a __destroy__ method:

    % snit::type dog { ... }
    ::dog
    % dog spot
    ::spot
    % spot bark
    ::spot barks.
    % spot destroy
    % spot barks
    invalid command name "spot"
    %

Finally, every Snit type has a type method called __destroy__; calling it
destroys the type and all of its instances:

    % snit::type dog { ... }
    ::dog
    % dog spot
    ::spot
    % spot bark
    ::spot barks.
    % dog destroy
    % spot bark
    invalid command name "spot"
    % dog fido
    invalid command name "dog"
    %

# <a name='section5'></a>INSTANCE METHODS

## <a name='subsection24'></a>What is an instance method?

An instance method is a procedure associated with a specific object and called
as a subcommand of the object's command\. It is given free access to all of the
object's type variables, instance variables, and so forth\.

## <a name='subsection25'></a>How do I define an instance method?

Instance methods are defined in the type definition using the
__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ statement\. Consider the
following code that might be used to add dogs to a computer simulation:

    % snit::type dog {
        method bark {} {
            return "$self barks."
        }

        method chase {thing} {
            return "$self chases $thing."
        }
    }
    ::dog
    %

A dog can bark, and it can chase things\.

The __[method](\.\./\.\./\.\./\.\./index\.md\#method)__ statement looks just like
a normal Tcl __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__, except that it
appears in a __snit::type__ definition\. Notice that every instance method
gets an implicit argument called __self__; this argument contains the
object's name\. \(There's more on implicit method arguments below\.\)

## <a name='subsection26'></a>How does a client call an instance method?

The method name becomes a subcommand of the object\. For example, let's put a
simulated dog through its paces:

    % dog spot
    ::spot
    % spot bark
    ::spot barks.
    % spot chase cat
    ::spot chases cat.
    %

## <a name='subsection27'></a>How does an instance method call another instance method?

If method A needs to call method B on the same object, it does so just as a
client does: it calls method B as a subcommand of the object itself, using the
object name stored in the implicit argument __self__\.

Suppose, for example, that our dogs never chase anything without barking at
them:

    % snit::type dog {
        method bark {} {
            return "$self barks."
        }

        method chase {thing} {
            return "$self chases $thing.  [$self bark]"
        }
    }
    ::dog
    % dog spot
    ::spot
    % spot bark
    ::spot barks.
    % spot chase cat
    ::spot chases cat.  ::spot barks.
    %

## <a name='subsection28'></a>Are there any limitations on instance method names?

Not really, so long as you avoid the standard instance method names:
__configure__, __configurelist__, __cget__, __destroy__, and
__info__\. Also, method names consisting of multiple words define
hierarchical methods\.

## <a name='subsection29'></a>What is a hierarchical method?

An object's methods are subcommands of the object's instance command\.
Hierarchical methods allow an object's methods to have subcommands of their own;
and these can in turn have subcommands, and so on\. This allows the programmer to
define a tree\-shaped command structure, such as is used by many of the Tk
widgets\-\-the subcommands of the Tk __[text](\.\./\.\./\.\./\.\./index\.md\#text)__
widget's __tag__ method are hierarchical methods\.

## <a name='subsection30'></a>How do I define a hierarchical method?

Define methods whose names consist of multiple words\. These words define the
hierarchy implicitly\. For example, the following code defines a __tag__
method with subcommands __cget__ and __configure__:

    snit::widget mytext {
        method {tag configure} {tag args} { ... }

        method {tag cget} {tag option} {...}
    }

Note that there is no explicit definition for the __tag__ method; it is
implicit in the definition of __tag configure__ and __tag cget__\. If you
tried to define __tag__ explicitly in this example, you'd get an error\.

## <a name='subsection31'></a>How do I call hierarchical methods?

As subcommands of subcommands\.

    % mytext .text
    .text
    % .text tag configure redtext -foreground red -background black
    % .text tag cget redtext -foreground
    red
    %

## <a name='subsection32'></a>How do I make an instance method private?

It's often useful to define private methods, that is, instance methods intended
to be called only by other methods of the same object\.

Snit doesn't implement any access control on instance methods, so all methods
are *de facto* public\. Conventionally, though, the names of public methods
begin with a lower\-case letter, and the names of private methods begin with an
upper\-case letter\.

For example, suppose our simulated dogs only bark in response to other stimuli;
they never bark just for fun\. So the __bark__ method becomes __Bark__ to
indicate that it is private:

    % snit::type dog {
        # Private by convention: begins with uppercase letter.
        method Bark {} {
            return "$self barks."
        }

        method chase {thing} {
            return "$self chases $thing. [$self Bark]"
        }
    }
    ::dog
    % dog fido
    ::fido
    % fido chase cat
    ::fido chases cat. ::fido barks.
    %

## <a name='subsection33'></a>Are there any limitations on instance method arguments?

Method argument lists are defined just like normal Tcl
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ argument lists; in particular,
they can include arguments with default values and the __args__ argument\.

However, every method also has a number of implicit arguments provided by Snit
in addition to those explicitly defined\. The names of these implicit arguments
may not used to name explicit arguments\.

## <a name='subsection34'></a>What implicit arguments are passed to each instance method?

The arguments implicitly passed to every method are __type__,
__selfns__, __win__, and __self__\.

## <a name='subsection35'></a>What is $type?

The implicit argument __type__ contains the fully qualified name of the
object's type:

    % snit::type thing {
        method mytype {} {
            return $type
        }
    }
    ::thing
    % thing something
    ::something
    % something mytype
    ::thing
    %

## <a name='subsection36'></a>What is $self?

The implicit argument __self__ contains the object's fully qualified name\.

If the object's command is renamed, then __$self__ will change to match in
subsequent calls\. Thus, your code should not assume that __$self__ is
constant unless you know for sure that the object will never be renamed\.

    % snit::type thing {
        method myself {} {
            return $self
        }
    }
    ::thing
    % thing mutt
    ::mutt
    % mutt myself
    ::mutt
    % rename mutt jeff
    % jeff myself
    ::jeff
    %

## <a name='subsection37'></a>What is $selfns?

Each Snit object has a private namespace in which to store its [INSTANCE
VARIABLES](#section6) and [OPTIONS](#section7)\. The implicit argument
__selfns__ contains the name of this namespace; its value never changes, and
is constant for the life of the object, even if the object's name changes:

    % snit::type thing {
        method myNameSpace {} {
            return $selfns
        }
    }
    ::thing
    % thing jeff
    ::jeff
    % jeff myNameSpace
    ::thing::Snit_inst3
    % rename jeff mutt
    % mutt myNameSpace
    ::thing::Snit_inst3
    %

The above example reveals how Snit names an instance's private namespace;
however, you should not write code that depends on the specific naming
convention, as it might change in future releases\.

## <a name='subsection38'></a>What is $win?

The implicit argument __win__ is defined for all Snit methods, though it
really makes sense only for those of [WIDGETS](#section17) and [WIDGET
ADAPTORS](#section18)\. __$win__ is simply the original name of the
object, whether it's been renamed or not\. For widgets and widgetadaptors, it is
also therefore the name of a Tk window\.

When a __snit::widgetadaptor__ is used to modify the interface of a widget
or megawidget, it must rename the widget's original command and replace it with
its own\.

Thus, using __win__ whenever the Tk window name is called for means that a
__snit::widget__ or __snit::widgetadaptor__ can be adapted by a
__snit::widgetadaptor__\. See [WIDGETS](#section17) for more
information\.

## <a name='subsection39'></a>How do I pass an instance method as a callback?

It depends on the context\.

Suppose in my application I have a __dog__ object named __fido__, and I
want __fido__ to bark when a Tk button called __\.bark__ is pressed\. In
this case, I create the callback command in the usual way, using
__[list](\.\./\.\./\.\./\.\./index\.md\#list)__:

    button .bark -text "Bark!" -command [list fido bark]

In typical Tcl style, we use a callback to hook two independent components
together\. But suppose that the __dog__ object has a graphical interface and
owns the button itself? In this case, the __dog__ must pass one of its own
instance methods to the button it owns\. The obvious thing to do is this:

    % snit::widget dog {
        constructor {args} {
            #...
            button $win.barkbtn -text "Bark!" -command [list $self bark]
            #...
        }
    }
    ::dog
    %

\(Note that in this example, our __dog__ becomes a __snit::widget__,
because it has GUI behavior\. See [WIDGETS](#section17) for more\.\) Thus, if
we create a __dog__ called __\.spot__, it will create a Tk button called
__\.spot\.barkbtn__; when pressed, the button will call __$self bark__\.

Now, this will work\-\-provided that __\.spot__ is never renamed to something
else\. But surely renaming widgets is abnormal? And so it is\-\-unless
__\.spot__ is the hull component of a __snit::widgetadaptor__\. If it is,
then it will be renamed, and __\.spot__ will become the name of the
__snit::widgetadaptor__ object\. When the button is pressed, the command
__$self bark__ will be handled by the __snit::widgetadaptor__, which
might or might not do the right thing\.

There's a safer way to do it, and it looks like this:

    % snit::widget dog {
        constructor {args} {
            #...
            button $win.barkbtn -text "Bark!" -command [mymethod bark]
            #...
        }
    }
    ::dog
    %

The command __mymethod__ takes any number of arguments, and can be used like
__[list](\.\./\.\./\.\./\.\./index\.md\#list)__ to build up a callback command;
the only difference is that __mymethod__ returns a form of the command that
won't change even if the instance's name changes\.

On the other hand, you might prefer to allow a widgetadaptor to override a
method such that your renamed widget will call the widgetadaptor's method
instead of its own\. In this case, using __\[list $self bark\]__ will do what
you want\.\.\.but this is a technique which should be used only in carefully
controlled circumstances\.

## <a name='subsection40'></a>How do I delegate instance methods to a component?

See [DELEGATION](#section16)\.

# <a name='section6'></a>INSTANCE VARIABLES

## <a name='subsection41'></a>What is an instance variable?

An instance variable is a private variable associated with some particular Snit
object\. Instance variables can be scalars or arrays\.

## <a name='subsection42'></a>How is a scalar instance variable defined?

Scalar instance variables are defined in the type definition using the
__variable__ statement\. You can simply name it, or you can initialize it
with a value:

    snit::type mytype {
        # Define variable "greeting" and initialize it with "Howdy!"
        variable greeting "Howdy!"
    }

## <a name='subsection43'></a>How is an array instance variable defined?

Array instance variables are also defined in the type definition using the
__variable__ command\. You can initialize them at the same time by specifying
the __\-array__ option:

    snit::type mytype {
        # Define array variable "greetings"
        variable greetings -array {
            formal "Good Evening"
            casual "Howdy!"
        }
    }

## <a name='subsection44'></a>What happens if I don't initialize an instance variable?

Variables do not really exist until they are given values\. If you do not
initialize a variable when you define it, then you must be sure to assign a
value to it \(in the constructor, say, or in some method\) before you reference
it\.

## <a name='subsection45'></a>Are there any limitations on instance variable names?

Just a few\.

First, every Snit object has a built\-in instance variable called
__options__, which should never be redefined\.

Second, all names beginning with "Snit\_" are reserved for use by Snit internal
code\.

Third, instance variable names containing the namespace delimiter \(__::__\)
are likely to cause great confusion\.

## <a name='subsection46'></a>Do I need to declare my instance variables in my methods?

No\. Once you've defined an instance variable in the type definition, it can be
used in any instance code \(instance methods, the constructor, and the
destructor\) without declaration\. This differs from normal Tcl practice, in which
all non\-local variables in a proc need to be declared\.

There is a speed penalty to having all instance variables implicitly available
in all instance code\. Even though your code need not declare the variables
explicitly, Snit must still declare them, and that takes time\. If you have ten
instance variables, a method that uses none of them must still pay the
declaration penalty for all ten\. In most cases, the additional runtime cost is
negligible\. If extreme cases, you might wish to avoid it; there are two methods
for doing so\.

The first is to define a single instance variable, an array, and store all of
your instance data in the array\. This way, you're only paying the declaration
penalty for one variable\-\-and you probably need the variable most of the time
anyway\. This method breaks down if your instance variables include multiple
arrays; in Tcl 8\.5, however, the __[dict](\.\./\.\./\.\./\.\./index\.md\#dict)__
command might come to your rescue\.

The second method is to declare your instance variables explicitly in your
instance code, while *not* including them in the type definition:

    snit::type dog {
        constructor {} {
            variable mood

            set mood happy
        }

        method setmood {newMood} {
            variable mood

            set mood $newMood
        }

        method getmood {} {
            variable mood

            return $mood
        }
    }

This allows you to ensure that only the required variables are included in each
method, at the cost of longer code and run\-time errors when you forget to
declare a variable you need\.

## <a name='subsection47'></a>How do I pass an instance variable's name to another object?

In Tk, it's common to pass a widget a variable name; for example, Tk label
widgets have a __\-textvariable__ option which names the variable which will
contain the widget's text\. This allows the program to update the label's value
just by assigning a new value to the variable\.

If you naively pass the instance variable name to the label widget, you'll be
confused by the result; Tk will assume that the name names a global variable\.
Instead, you need to provide a fully\-qualified variable name\. From within an
instance method or a constructor, you can fully qualify the variable's name
using the __myvar__ command:

    snit::widget mywidget {
        variable labeltext ""

        constructor {args} {
            # ...

            label $win.label -textvariable [myvar labeltext]

            # ...
        }
    }

## <a name='subsection48'></a>How do I make an instance variable public?

Practically speaking, you don't\. Instead, you'll implement public variables as
[OPTIONS](#section7)\. Alternatively, you can write [INSTANCE
METHODS](#section5) to set and get the variable's value\.

# <a name='section7'></a>OPTIONS

## <a name='subsection49'></a>What is an option?

A type's options are the equivalent of what other object\-oriented languages
would call public member variables or properties: they are data values which can
be retrieved and \(usually\) set by the clients of an object\.

Snit's implementation of options follows the Tk model fairly exactly, except
that __snit::type__ objects usually don't interact with [THE TK OPTION
DATABASE](#section19); __snit::widget__ and __snit::widgetadaptor__
objects, on the other hand, always do\.

## <a name='subsection50'></a>How do I define an option?

Options are defined in the type definition using the __option__ statement\.
Consider the following type, to be used in an application that manages a list of
dogs for a pet store:

    snit::type dog {
        option -breed -default mongrel
        option -color -default brown
        option -akc   -default 0
        option -shots -default 0
    }

According to this, a dog has four notable properties: a breed, a color, a flag
that says whether it's pedigreed with the American Kennel Club, and another flag
that says whether it has had its shots\. The default dog, evidently, is a brown
mutt\.

There are a number of options you can specify when defining an option; if
__\-default__ is the only one, you can omit the word __\-default__ as
follows:

    snit::type dog {
        option -breed mongrel
        option -color brown
        option -akc   0
        option -shots 0
    }

If no __\-default__ value is specified, the option's default value will be
the empty string \(but see [THE TK OPTION DATABASE](#section19)\)\.

The Snit man page refers to options like these as "locally defined" options\.

## <a name='subsection51'></a>How can a client set options at object creation?

The normal convention is that the client may pass any number of options and
their values after the object's name at object creation\. For example, the
__::dog__ command defined in the previous answer can now be used to create
individual dogs\. Any or all of the options may be set at creation time\.

    % dog spot -breed beagle -color "mottled" -akc 1 -shots 1
    ::spot
    % dog fido -shots 1
    ::fido
    %

So __::spot__ is a pedigreed beagle; __::fido__ is a typical mutt, but
his owners evidently take care of him, because he's had his shots\.

*Note:* If the type defines a constructor, it can specify a different
object\-creation syntax\. See [CONSTRUCTORS](#section12) for more
information\.

## <a name='subsection52'></a>How can a client retrieve an option's value?

Retrieve option values using the __cget__ method:

    % spot cget -color
    mottled
    % fido cget -breed
    mongrel
    %

## <a name='subsection53'></a>How can a client set options after object creation?

Any number of options may be set at one time using the __configure__
instance method\. Suppose that closer inspection shows that ::fido is not a brown
mongrel, but rather a rare Arctic Boar Hound of a lovely dun color:

    % fido configure -color dun -breed "Arctic Boar Hound"
    % fido cget -color
    dun
    % fido cget -breed
    Arctic Boar Hound

Alternatively, the __configurelist__ method takes a list of options and
values; occasionally this is more convenient:

    % set features [list -color dun -breed "Arctic Boar Hound"]
    -color dun -breed {Arctic Boar Hound}
    % fido configurelist $features
    % fido cget -color
    dun
    % fido cget -breed
    Arctic Boar Hound
    %

In Tcl 8\.5, the __\*__ keyword can be used with __configure__ in this
case:

    % set features [list -color dun -breed "Arctic Boar Hound"]
    -color dun -breed {Arctic Boar Hound}
    % fido configure {*}$features
    % fido cget -color
    dun
    % fido cget -breed
    Arctic Boar Hound
    %

The results are the same\.

## <a name='subsection54'></a>How should an instance method access an option value?

There are two ways an instance method can set and retrieve an option's value\.
One is to use the __configure__ and __cget__ methods, as shown below\.

    % snit::type dog {
        option -weight 10

        method gainWeight {} {
            set wt [$self cget -weight]
            incr wt
            $self configure -weight $wt
        }
    }
    ::dog
    % dog fido
    ::fido
    % fido cget -weight
    10
    % fido gainWeight
    % fido cget -weight
    11
    %

Alternatively, Snit provides a built\-in array instance variable called
__options__\. The indices are the option names; the values are the option
values\. The method __gainWeight__ can thus be rewritten as follows:

    method gainWeight {} {
        incr options(-weight)
    }

As you can see, using the __options__ variable involves considerably less
typing and is the usual way to do it\. But if you use __\-configuremethod__ or
__\-cgetmethod__ \(described in the following answers\), you might wish to use
the __configure__ and __cget__ methods anyway, just so that any special
processing you've implemented is sure to get done\. Also, if the option is
delegated to a component then __configure__ and __cget__ are the only
way to access it without accessing the component directly\. See
[DELEGATION](#section16) for more information\.

## <a name='subsection55'></a>How can I make an option read\-only?

Define the option with __\-readonly yes__\.

Suppose you've got an option that determines how instances of your type are
constructed; it must be set at creation time, after which it's constant\. For
example, a dog never changes its breed; it might or might not have had its
shots, and if not can have them at a later time\. __\-breed__ should be
read\-only, but __\-shots__ should not be\.

    % snit::type dog {
        option -breed -default mongrel -readonly yes
        option -shots -default no
    }
    ::dog
    % dog fido -breed retriever
    ::fido
    % fido configure -shots yes
    % fido configure -breed terrier
    option -breed can only be set at instance creation
    %

## <a name='subsection56'></a>How can I catch accesses to an option's value?

Define a __\-cgetmethod__ for the option\.

## <a name='subsection57'></a>What is a \-cgetmethod?

A __\-cgetmethod__ is a method that's called whenever the related option's
value is queried via the __cget__ instance method\. The handler can compute
the option's value, retrieve it from a database, or do anything else you'd like
it to do\.

Here's what the default behavior would look like if written using a
__\-cgetmethod__:

    snit::type dog {
        option -color -default brown -cgetmethod GetOption

        method GetOption {option} {
            return $options($option)
        }
    }

Any instance method can be used, provided that it takes one argument, the name
of the option whose value is to be retrieved\.

## <a name='subsection58'></a>How can I catch changes to an option's value?

Define a __\-configuremethod__ for the option\.

## <a name='subsection59'></a>What is a \-configuremethod?

A __\-configuremethod__ is a method that's called whenever the related option
is given a new value via the __configure__ or __configurelist__ instance
methods\. The method can pass the value on to some other object, store it in a
database, or do anything else you'd like it to do\.

Here's what the default configuration behavior would look like if written using
a __\-configuremethod__:

    snit::type dog {
        option -color -default brown -configuremethod SetOption

        method SetOption {option value} {
            set options($option) $value
        }
    }

Any instance method can be used, provided that it takes two arguments, the name
of the option and the new value\.

Note that if your method doesn't store the value in the __options__ array,
the __options__ array won't get updated\.

## <a name='subsection60'></a>How can I validate an option's value?

Define a __\-validatemethod__\.

## <a name='subsection61'></a>What is a \-validatemethod?

A __\-validatemethod__ is a method that's called whenever the related option
is given a new value via the __configure__ or __configurelist__ instance
methods\. It's the method's responsibility to determine whether the new value is
valid, and throw an error if it isn't\. The __\-validatemethod__, if any, is
called before the value is stored in the __options__ array; in particular,
it's called before the __\-configuremethod__, if any\.

For example, suppose an option always takes a Boolean value\. You can ensure that
the value is in fact a valid Boolean like this:

    % snit::type dog {
        option -shots -default no -validatemethod BooleanOption

        method BooleanOption {option value} {
            if {![string is boolean -strict $value]} {
                error "expected a boolean value, got \"$value\""
            }
        }
    }
    ::dog
    % dog fido
    % fido configure -shots yes
    % fido configure -shots NotABooleanValue
    expected a boolean value, got "NotABooleanValue"
    %

Note that the same __\-validatemethod__ can be used to validate any number of
boolean options\.

Any method can be a __\-validatemethod__ provided that it takes two
arguments, the option name and the new option value\.

# <a name='section8'></a>TYPE VARIABLES

## <a name='subsection62'></a>What is a type variable?

A type variable is a private variable associated with a Snit type rather than
with a particular instance of the type\. In C\+\+ and Java, the term *static
member variable* is used for the same notion\. Type variables can be scalars or
arrays\.

## <a name='subsection63'></a>How is a scalar type variable defined?

Scalar type variables are defined in the type definition using the
__typevariable__ statement\. You can simply name it, or you can initialize it
with a value:

    snit::type mytype {
        # Define variable "greeting" and initialize it with "Howdy!"
        typevariable greeting "Howdy!"
    }

Every object of type __mytype__ now has access to a single variable called
__greeting__\.

## <a name='subsection64'></a>How is an array\-valued type variable defined?

Array\-valued type variables are also defined using the __typevariable__
command; to initialize them, include the __\-array__ option:

    snit::type mytype {
        # Define typearray variable "greetings"
        typevariable greetings -array {
            formal "Good Evening"
            casual "Howdy!"
        }
    }

## <a name='subsection65'></a>What happens if I don't initialize a type variable?

Variables do not really exist until they are given values\. If you do not
initialize a variable when you define it, then you must be sure to assign a
value to it \(in the type constructor, say\) before you reference it\.

## <a name='subsection66'></a>Are there any limitations on type variable names?

Type variable names have the same restrictions as the names of [INSTANCE
VARIABLES](#section6) do\.

## <a name='subsection67'></a>Do I need to declare my type variables in my methods?

No\. Once you've defined a type variable in the type definition, it can be used
in [INSTANCE METHODS](#section5) or [TYPE METHODS](#section9) without
declaration\. This differs from normal Tcl practice, in which all non\-local
variables in a proc need to be declared\.

Type variables are subject to the same speed/readability tradeoffs as instance
variables; see [Do I need to declare my instance variables in my
methods?](#subsection46)

## <a name='subsection68'></a>How do I pass a type variable's name to another object?

In Tk, it's common to pass a widget a variable name; for example, Tk label
widgets have a __\-textvariable__ option which names the variable which will
contain the widget's text\. This allows the program to update the label's value
just by assigning a new value to the variable\.

If you naively pass a type variable name to the label widget, you'll be confused
by the result; Tk will assume that the name names a global variable\. Instead,
you need to provide a fully\-qualified variable name\. From within an instance
method or a constructor, you can fully qualify the type variable's name using
the __mytypevar__ command:

    snit::widget mywidget {
        typevariable labeltext ""

        constructor {args} {
            # ...

            label $win.label -textvariable [mytypevar labeltext]

            # ...
        }
    }

## <a name='subsection69'></a>How do I make a type variable public?

There are two ways to do this\. The preferred way is to write a pair of [TYPE
METHODS](#section9) to set and query the type variable's value\.

Type variables are stored in the type's namespace, which has the same name as
the type itself\. Thus, you can also publicize the type variable's name in your
documentation so that clients can access it directly\. For example,

    snit::type mytype {
        typevariable myvariable
    }

    set ::mytype::myvariable "New Value"

# <a name='section9'></a>TYPE METHODS

## <a name='subsection70'></a>What is a type method?

A type method is a procedure associated with the type itself rather than with
any specific instance of the type, and called as a subcommand of the type
command\.

## <a name='subsection71'></a>How do I define a type method?

Type methods are defined in the type definition using the __typemethod__
statement:

    snit::type dog {
        # List of pedigreed dogs
        typevariable pedigreed

        typemethod pedigreedDogs {} {
            return $pedigreed
        }
    }

Suppose the __dog__ type maintains a list of the names of the dogs that have
pedigrees\. The __pedigreedDogs__ type method returns this list\.

The __typemethod__ statement looks just like a normal Tcl
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__, except that it appears in a
__snit::type__ definition\. Notice that every type method gets an implicit
argument called __type__, which contains the fully\-qualified type name\.

## <a name='subsection72'></a>How does a client call a type method?

The type method name becomes a subcommand of the type's command\. For example,
assuming that the constructor adds each pedigreed dog to the list of
__pedigreedDogs__,

    snit::type dog {
        option -pedigreed 0

        # List of pedigreed dogs
        typevariable pedigreed

        typemethod pedigreedDogs {} {
            return $pedigreed
        }

        # ...
    }

    dog spot -pedigreed 1
    dog fido

    foreach dog [dog pedigreedDogs] { ... }

## <a name='subsection73'></a>Are there any limitations on type method names?

Not really, so long as you avoid the standard type method names: __create__,
__destroy__, and __info__\.

## <a name='subsection74'></a>How do I make a type method private?

It's sometimes useful to define private type methods, that is, type methods
intended to be called only by other type or instance methods of the same object\.

Snit doesn't implement any access control on type methods; by convention, the
names of public methods begin with a lower\-case letter, and the names of private
methods begin with an upper\-case letter\.

Alternatively, a Snit __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ can be used
as a private type method; see [PROCS](#section10)\.

## <a name='subsection75'></a>Are there any limitations on type method arguments?

Method argument lists are defined just like normal Tcl proc argument lists; in
particular, they can include arguments with default values and the __args__
argument\.

However, every type method is called with an implicit argument called
__type__ that contains the name of the type command\. In addition, type
methods should by convention avoid using the names of the arguments implicitly
defined for [INSTANCE METHODS](#section5)\.

## <a name='subsection76'></a>How does an instance or type method call a type method?

If an instance or type method needs to call a type method, it should use
__$type__ to do so:

    snit::type dog {

        typemethod pedigreedDogs {} { ... }

        typemethod printPedigrees {} {
            foreach obj [$type pedigreedDogs] { ... }
        }
    }

## <a name='subsection77'></a>How do I pass a type method as a callback?

It's common in Tcl to pass a snippet of code to another object, for it to call
later\. Because types cannot be renamed, you can just use the type name, or, if
the callback is registered from within a type method, __type__\. For example,
suppose we want to print a list of pedigreed dogs when a Tk button is pushed:

    button .btn -text "Pedigrees" -command [list dog printPedigrees]
    pack .btn

Alternatively, from a method or type method you can use the __mytypemethod__
command, just as you would use __mymethod__ to define a callback command for
[INSTANCE METHODS](#section5)\.

## <a name='subsection78'></a>Can type methods be hierarchical?

Yes, you can define hierarchical type methods in just the same way as you can
define hierarchical instance methods\. See [INSTANCE METHODS](#section5) for
more\.

# <a name='section10'></a>PROCS

## <a name='subsection79'></a>What is a proc?

A Snit __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ is really just a Tcl proc
defined within the type's namespace\. You can use procs for private code that
isn't related to any particular instance\.

## <a name='subsection80'></a>How do I define a proc?

Procs are defined by including a __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__
statement in the type definition:

    snit::type mytype {
        # Pops and returns the first item from the list stored in the
        # listvar, updating the listvar
       proc pop {listvar} { ... }

       # ...
    }

## <a name='subsection81'></a>Are there any limitations on proc names?

Any name can be used, so long as it does not begin with __Snit\___; names
beginning with __Snit\___ are reserved for Snit's own use\. However, the wise
programmer will avoid __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ names
\(__[set](\.\./\.\./\.\./\.\./index\.md\#set)__,
__[list](\.\./\.\./\.\./\.\./index\.md\#list)__, __if__, etc\.\) that would
shadow standard Tcl command names\.

__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__ names, being private, should begin
with a capital letter according to convention; however, as there are typically
no public __[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__s in the type's namespace
it doesn't matter much either way\.

## <a name='subsection82'></a>How does a method call a proc?

Just like it calls any Tcl command\. For example,

    snit::type mytype {
        # Pops and returns the first item from the list stored in the
        # listvar, updating the listvar
        proc pop {listvar} { ... }

        variable requestQueue {}

        # Get one request from the queue and process it.
        method processRequest {} {
            set req [pop requestQueue]
        }
    }

## <a name='subsection83'></a>How can I pass a proc to another object as a callback?

The __myproc__ command returns a callback command for the
__[proc](\.\./\.\./\.\./\.\./index\.md\#proc)__, just as __mymethod__ does for
a method\.

# <a name='section11'></a>TYPE CONSTRUCTORS

## <a name='subsection84'></a>What is a type constructor?

A type constructor is a body of code that initializes the type as a whole,
rather like a C\+\+ static initializer\. The body of a type constructor is executed
once when the type is defined, and never again\.

A type can have at most one type constructor\.

## <a name='subsection85'></a>How do I define a type constructor?

A type constructor is defined by using the __typeconstructor__ statement in
the type definition\. For example, suppose the type uses an array\-valued type
variable as a look\-up table, and the values in the array have to be computed at
start\-up\.

    % snit::type mytype {
        typevariable lookupTable

        typeconstructor {
            array set lookupTable {key value...}
        }
    }

# <a name='section12'></a>CONSTRUCTORS

## <a name='subsection86'></a>What is a constructor?

In object\-oriented programming, an object's constructor is responsible for
initializing the object completely at creation time\. The constructor receives
the list of options passed to the __snit::type__ command's __create__
method and can then do whatever it likes\. That might include computing instance
variable values, reading data from files, creating other objects, updating type
and instance variables, and so forth\.

The constructor's return value is ignored \(unless it's an error, of course\)\.

## <a name='subsection87'></a>How do I define a constructor?

A constructor is defined by using the __constructor__ statement in the type
definition\. Suppose that it's desired to keep a list of all pedigreed dogs\. The
list can be maintained in a type variable and retrieved by a type method\.
Whenever a dog is created, it can add itself to the list\-\-provided that it's
registered with the American Kennel Club\.

    % snit::type dog {
        option -akc 0

        typevariable akcList {}

        constructor {args} {
            $self configurelist $args

            if {$options(-akc)} {
                lappend akcList $self
            }
        }

        typemethod akclist {} {
            return $akcList
        }
    }
    ::dog
    % dog spot -akc 1
    ::spot
    % dog fido
    ::fido
    % dog akclist
    ::spot
    %

## <a name='subsection88'></a>What does the default constructor do?

If you don't provide a constructor explicitly, you get the default constructor,
which is identical to the explicitly\-defined constructor shown here:

    snit::type dog {
        constructor {args} {
            $self configurelist $args
        }
    }

When the constructor is called, __args__ will be set to the list of
arguments that follow the object's name\. The constructor is allowed to interpret
this list any way it chooses; the normal convention is to assume that it's a
list of option names and values, as shown in the example above\. If you simply
want to save the option values, you should use the __configurelist__ method,
as shown\.

## <a name='subsection89'></a>Can I choose a different set of arguments for the constructor?

Yes, you can\. For example, suppose we wanted to be sure that the breed was
explicitly stated for every dog at creation time, and couldn't be changed
thereafter\. One way to do that is as follows:

    % snit::type dog {
        variable breed

        option -color brown
        option -akc 0

        constructor {theBreed args} {
            set breed $theBreed
            $self configurelist $args
        }

        method breed {} { return $breed }
    }
    ::dog
    % dog spot dalmatian -color spotted -akc 1
    ::spot
    % spot breed
    dalmatian

The drawback is that this syntax is non\-standard, and may limit the
compatibility of your new type with other people's code\. For example, Snit
assumes that it can create [COMPONENTS](#section14) using the standard
creation syntax\.

## <a name='subsection90'></a>Are there any limitations on constructor arguments?

Constructor argument lists are subject to the same limitations as those on
instance method argument lists\. It has the same implicit arguments, and can
contain default values and the __args__ argument\.

## <a name='subsection91'></a>Is there anything special about writing the constructor?

Yes\. Writing the constructor can be tricky if you're delegating options to
components, and there are specific issues relating to __snit::widget__s and
__snit::widgetadaptor__s\. See [DELEGATION](#section16),
[WIDGETS](#section17), [WIDGET ADAPTORS](#section18), and [THE TK
OPTION DATABASE](#section19)\.

# <a name='section13'></a>DESTRUCTORS

## <a name='subsection92'></a>What is a destructor?

A destructor is a special kind of method that's called when an object is
destroyed\. It's responsible for doing any necessary clean\-up when the object
goes away: destroying [COMPONENTS](#section14), closing files, and so
forth\.

## <a name='subsection93'></a>How do I define a destructor?

Destructors are defined by using the __destructor__ statement in the type
definition\.

Suppose we're maintaining a list of pedigreed dogs; then we'll want to remove
dogs from it when they are destroyed\.

    snit::type dog {
        option -akc 0

        typevariable akcList {}

        constructor {args} {
            $self configurelist $args

            if {$options(-akc)} {
                lappend akcList $self
            }
        }

        destructor {
            set ndx [lsearch $akcList $self]

            if {$ndx != -1} {
                set akcList [lreplace $akcList $ndx $ndx]
            }
        }

        typemethod akclist {} {
            return $akcList
        }
    }

## <a name='subsection94'></a>Are there any limitations on destructor arguments?

Yes; a destructor has no explicit arguments\.

## <a name='subsection95'></a>What implicit arguments are passed to the destructor?

The destructor gets the same implicit arguments that are passed to [INSTANCE
METHODS](#section5): __type__, __selfns__, __win__, and
__self__\.

## <a name='subsection96'></a>Must components be destroyed explicitly?

Yes and no\.

Any Tk widgets created by a __snit::widget__ or __snit::widgetadaptor__
will be destroyed automatically by Tk when the megawidget is destroyed, in
keeping with normal Tk behavior \(destroying a parent widget destroys the whole
tree\)\.

Components of normal __snit::types__, on the other hand, are never destroyed
automatically, nor are non\-widget components of Snit megawidgets\. If your object
creates them in its constructor, then it should generally destroy them in its
destructor\.

## <a name='subsection97'></a>Is there any special about writing a destructor?

Yes\. If an object's constructor throws an error, the object's destructor will be
called to clean up; this means that the object might not be completely
constructed when the destructor is called\. This can cause the destructor to
throw its own error; the result is usually misleading, confusing, and unhelpful\.
Consequently, it's important to write your destructor so that it's fail\-safe\.

For example, a __dog__ might create a __tail__ component; the component
will need to be destroyed\. But suppose there's an error while processing the
creation options\-\-the destructor will be called, and there will be no
__tail__ to destroy\. The simplest solution is generally to catch and ignore
any errors while destroying components\.

    snit::type dog {
        component tail

        constructor {args} {
            $self configurelist $args

            set tail [tail %AUTO%]
        }

        destructor {
            catch {$tail destroy}
        }
    }

# <a name='section14'></a>COMPONENTS

## <a name='subsection98'></a>What is a component?

Often an object will create and manage a number of other objects\. A Snit
megawidget, for example, will often create a number of Tk widgets\. These objects
are part of the main object; it is composed of them, so they are called
components of the object\.

But Snit also has a more precise meaning for [COMPONENT](#section14)\. The
components of a Snit object are those objects to which methods or options can be
delegated\. \(See [DELEGATION](#section16) for more information about
delegation\.\)

## <a name='subsection99'></a>How do I declare a component?

First, you must decide what role a component plays within your object, and give
the role a name\. Then, you declare the component using its role name and the
__component__ statement\. The __component__ statement declares an
*instance variable* which is used to store the component's command name when
the component is created\.

For example, suppose your __dog__ object creates a __tail__ object \(the
better to wag with, no doubt\):

    snit::type dog {
        component mytail

        constructor {args} {
            # Create and save the component's command
            set mytail [tail %AUTO% -partof $self]
            $self configurelist $args
        }

        method wag {} {
            $mytail wag
        }
    }

As shown here, it doesn't matter what the __tail__ object's real name is;
the __dog__ object refers to it by its component name\.

The above example shows one way to delegate the __wag__ method to the
__mytail__ component; see [DELEGATION](#section16) for an easier way\.

## <a name='subsection100'></a>How is a component named?

A component has two names\. The first name is that of the component variable;
this represents the role the component object plays within the Snit object\. This
is the component name proper, and is the name used to refer to the component
within Snit code\. The second name is the name of the actual component object
created by the Snit object's constructor\. This second name is always a Tcl
command name, and is referred to as the component's object name\.

In the example in the previous question, the component name is __mytail__;
the __mytail__ component's object name is chosen automatically by Snit since
__%AUTO%__ was used when the component object was created\.

## <a name='subsection101'></a>Are there any limitations on component names?

Yes\. __snit::widget__ and __snit::widgetadaptor__ objects have a special
component called the __hull__ component; thus, the name __hull__ should
be used for no other purpose\.

Otherwise, since component names are in fact instance variable names they must
follow the rules for [INSTANCE VARIABLES](#section6)\.

## <a name='subsection102'></a>What is an owned component?

An *owned* component is a component whose object command's lifetime is
controlled by the __snit::type__ or __snit::widget__\.

As stated above, a component is an object to which our object can delegate
methods or options\. Under this definition, our object will usually create its
component objects, but not necessarily\. Consider the following: a dog object has
a tail component; but tail knows that it's part of the dog:

    snit::type dog {
        component mytail

        constructor {args} {
            set mytail [tail %AUTO% -partof $self]
            $self configurelist $args
        }

        destructor {
            catch {$mytail destroy}
        }

        delegate method wagtail to mytail as wag

        method bark {} {
            return "$self barked."
        }
    }

     snit::type tail {
         component mydog
         option -partof -readonly yes

         constructor {args} {
             $self configurelist $args
             set mydog $options(-partof)
         }

         method wag {} {
             return "Wag, wag."
         }

         method pull {} {
             $mydog bark
         }
     }

Thus, if you ask a dog to wag its tail, it tells its tail to wag; and if you
pull the dog's tail, the tail tells the dog to bark\. In this scenario, the tail
is a component of the dog, and the dog is a component of the tail, but the dog
owns the tail and not the other way around\.

## <a name='subsection103'></a>What does the install command do?

The __install__ command creates an owned component using a specified
command, and assigns the result to the component's instance variable\. For
example:

    snit::type dog {
        component mytail

        constructor {args} {
            # set mytail [tail %AUTO% -partof $self]
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }
    }

In a __snit::type__'s code, the __install__ command shown above is
equivalent to the __set mytail__ command that's commented out\. In a
__snit::widget__'s or __snit::widgetadaptor__'s, code, however, the
__install__ command also queries [THE TK OPTION DATABASE](#section19)
and initializes the new component's options accordingly\. For consistency, it's a
good idea to get in the habit of using __install__ for all owned components\.

## <a name='subsection104'></a>Must owned components be created in the constructor?

No, not necessarily\. In fact, there's no reason why an object can't destroy and
recreate a component multiple times over its own lifetime\.

## <a name='subsection105'></a>Are there any limitations on component object names?

Yes\.

Component objects which are Tk widgets or megawidgets must have valid Tk window
names\.

Component objects which are not widgets or megawidgets must have fully\-qualified
command names, i\.e\., names which include the full namespace of the command\. Note
that Snit always creates objects with fully qualified names\.

Next, the object names of components and owned by your object must be unique\.
This is no problem for widget components, since widget names are always unique;
but consider the following code:

    snit::type tail { ... }

    snit::type dog {
        delegate method wag to mytail

        constructor {} {
            install mytail using tail mytail
        }
    }

This code uses the component name, __mytail__, as the component object name\.
This is not good, and here's why: Snit instance code executes in the Snit type's
namespace\. In this case, the __mytail__ component is created in the
__::dog::__ namespace, and will thus have the name __::dog::mytail__\.

Now, suppose you create two dogs\. Both dogs will attempt to create a tail called
__::dog::mytail__\. The first will succeed, and the second will fail, since
Snit won't let you create an object if its name is already a command\. Here are
two ways to avoid this situation:

First, if the component type is a __snit::type__ you can specify
__%AUTO%__ as its name, and be guaranteed to get a unique name\. This is the
safest thing to do:

    install mytail using tail %AUTO%

If the component type isn't a __snit::type__ you can create the component in
the object's instance namespace:

    install mytail using tail ${selfns}::mytail

Make sure you pick a unique name within the instance namespace\.

## <a name='subsection106'></a>Must I destroy the components I own?

That depends\. When a parent widget is destroyed, all child widgets are destroyed
automatically\. Thus, if your object is a __snit::widget__ or
__snit::widgetadaptor__ you don't need to destroy any components that are
widgets, because they will generally be children or descendants of your
megawidget\.

If your object is an instance of __snit::type__, though, none of its owned
components will be destroyed automatically, nor will be non\-widget components of
a __snit::widget__ be destroyed automatically\. All such owned components
must be destroyed explicitly, or they won't be destroyed at all\.

## <a name='subsection107'></a>Can I expose a component's object command as part of my interface?

Yes, and there are two ways to do it\. The most appropriate way is usually to use
[DELEGATION](#section16)\. Delegation allows you to pass the options and
methods you specify along to particular components\. This effectively hides the
components from the users of your type, and ensures good encapsulation\.

However, there are times when it's appropriate, not to mention simpler, just to
make the entire component part of your type's public interface\.

## <a name='subsection108'></a>How do I expose a component's object command?

When you declare the component, specify the __component__ statement's
__\-public__ option\. The value of this option is the name of a method which
will be delegated to your component's object command\.

For example, supposed you've written a combobox megawidget which owns a listbox
widget, and you want to make the listbox's entire interface public\. You can do
it like this:

    snit::widget combobox {
         component listbox -public listbox

         constructor {args} {
             install listbox using listbox $win.listbox ....
         }
    }

    combobox .mycombo
    .mycombo listbox configure -width 30

Your comobox widget, __\.mycombo__, now has a __listbox__ method which
has all of the same subcommands as the listbox widget itself\. Thus, the above
code sets the listbox component's width to 30\.

Usually you'll let the method name be the same as the component name; however,
you can name it anything you like\.

# <a name='section15'></a>TYPE COMPONENTS

## <a name='subsection109'></a>What is a type component?

A type component is a component that belongs to the type itself instead of to a
particular instance of the type\. The relationship between components and type
components is the same as the relationship between [INSTANCE
VARIABLES](#section6) and [TYPE VARIABLES](#section8)\. Both [INSTANCE
METHODS](#section5) and [TYPE METHODS](#section9) can be delegated to
type components\.

Once you understand [COMPONENTS](#section14) and
[DELEGATION](#section16), type components are just more of the same\.

## <a name='subsection110'></a>How do I declare a type component?

Declare a type component using the __typecomponent__ statement\. It takes the
same options \(__\-inherit__ and __\-public__\) as the __component__
statement does, and defines a type variable to hold the type component's object
command\.

Suppose in your model you've got many dogs, but only one veterinarian\. You might
make the veterinarian a type component\.

    snit::type veterinarian { ... }

    snit::type dog {
        typecomponent vet

        # ...
    }

## <a name='subsection111'></a>How do I install a type component?

Just use the __[set](\.\./\.\./\.\./\.\./index\.md\#set)__ command to assign the
component's object command to the type component\. Because types \(even
__snit::widget__ types\) are not widgets, and do not have options anyway, the
extra features of the __install__ command are not needed\.

You'll usually install type components in the type constructor, as shown here:

    snit::type veterinarian { ... }

    snit::type dog {
        typecomponent vet

        typeconstructor {
            set vet [veterinarian %AUTO%]
        }
    }

## <a name='subsection112'></a>Are there any limitations on type component names?

Yes, the same as on [INSTANCE VARIABLES](#section6), [TYPE
VARIABLES](#section8), and normal [COMPONENTS](#section14)\.

# <a name='section16'></a>DELEGATION

## <a name='subsection113'></a>What is delegation?

Delegation, simply put, is when you pass a task you've been given to one of your
assistants\. \(You do have assistants, don't you?\) Snit objects can do the same
thing\. The following example shows one way in which the __dog__ object can
delegate its __wag__ method and its __\-taillength__ option to its
__tail__ component\.

    snit::type dog {
        variable mytail

        option -taillength -configuremethod SetTailOption -cgetmethod GetTailOption

        method SetTailOption {option value} {
             $mytail configure $option $value
        }

        method GetTailOption {option} {
             $mytail cget $option
        }

        method wag {} {
            $mytail wag
        }

        constructor {args} {
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }

    }

This is the hard way to do it, by it demonstrates what delegation is all about\.
See the following answers for the easy way to do it\.

Note that the constructor calls the __configurelist__ method
__[after](\.\./\.\./\.\./\.\./index\.md\#after)__ it creates its __tail__;
otherwise, if __\-taillength__ appeared in the list of __args__ we'd get
an error\.

## <a name='subsection114'></a>How can I delegate a method to a component object?

Delegation occurs frequently enough that Snit makes it easy\. Any method can be
delegated to any component or type component by placing a single
__delegate__ statement in the type definition\. \(See
[COMPONENTS](#section14) and [TYPE COMPONENTS](#section15) for more
information about component names\.\)

For example, here's a much better way to delegate the __dog__ object's
__wag__ method:

    % snit::type dog {
        delegate method wag to mytail

        constructor {} {
            install mytail using tail %AUTO%
        }
    }
    ::dog
    % snit::type tail {
        method wag {} { return "Wag, wag, wag."}
    }
    ::tail
    % dog spot
    ::spot
    % spot wag
    Wag, wag, wag.

This code has the same effect as the code shown under the previous question:
when a __dog__'s __wag__ method is called, the call and its arguments
are passed along automatically to the __tail__ object\.

Note that when a component is mentioned in a __delegate__ statement, the
component's instance variable is defined implicitly\. However, it's still good
practice to declare it explicitly using the __component__ statement\.

Note also that you can define a method name using the
__[method](\.\./\.\./\.\./\.\./index\.md\#method)__ statement, or you can define
it using __delegate__; you can't do both\.

## <a name='subsection115'></a>Can I delegate to a method with a different name?

Suppose you wanted to delegate the __dog__'s __wagtail__ method to the
__tail__'s __wag__ method\. After all you wag the tail, not the dog\. It's
easily done:

    snit::type dog {
        delegate method wagtail to mytail as wag

        constructor {args} {
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }
    }

## <a name='subsection116'></a>Can I delegate to a method with additional arguments?

Suppose the __tail__'s __wag__ method takes as an argument the number of
times the tail should be wagged\. You want to delegate the __dog__'s
__wagtail__ method to the __tail__'s __wag__ method, specifying that
the tail should be wagged exactly three times\. This is easily done, too:

    snit::type dog {
        delegate method wagtail to mytail as {wag 3}
        # ...
    }

    snit::type tail {
        method wag {count} {
            return [string repeat "Wag " $count]
        }
        # ...
    }

## <a name='subsection117'></a>Can I delegate a method to something other than an object?

Normal method delegation assumes that you're delegating a method \(a subcommand
of an object command\) to a method of another object \(a subcommand of a different
object command\)\. But not all Tcl objects follow Tk conventions, and not
everything you'd to which you'd like to delegate a method is necessary an
object\. Consequently, Snit makes it easy to delegate a method to pretty much
anything you like using the __delegate__ statement's __using__ clause\.

Suppose your dog simulation stores dogs in a database, each dog as a single
record\. The database API you're using provides a number of commands to manage
records; each takes the record ID \(a string you choose\) as its first argument\.
For example, __saverec__ saves a record\. If you let the record ID be the
name of the dog object, you can delegate the dog's __save__ method to the
__saverec__ command as follows:

    snit::type dog {
        delegate method save using {saverec %s}
    }

The __%s__ is replaced with the instance name when the __save__ method
is called; any additional arguments are the appended to the resulting command\.

The __using__ clause understands a number of other %\-conversions; in
addition to the instance name, you can substitute in the method name
\(__%m__\), the type name \(__%t__\), the instance namespace \(__%n__\),
the Tk window name \(__%w__\), and, if a component or typecomponent name was
given in the __delegate__ statement, the component's object command
\(__%c__\)\.

## <a name='subsection118'></a>How can I delegate a method to a type component object?

Just exactly as you would to a component object\. The __delegate method__
statement accepts both component and type component names in its __to__
clause\.

## <a name='subsection119'></a>How can I delegate a type method to a type component object?

Use the __delegate typemethod__ statement\. It works like __delegate
method__, with these differences: first, it defines a type method instead of
an instance method; second, the __using__ clause ignores the __%s__,
__%n__, and __%w__ %\-conversions\.

Naturally, you can't delegate a type method to an instance component\.\.\.Snit
wouldn't know which instance should receive it\.

## <a name='subsection120'></a>How can I delegate an option to a component object?

The first question in this section \(see [DELEGATION](#section16)\) shows one
way to delegate an option to a component; but this pattern occurs often enough
that Snit makes it easy\. For example, every __tail__ object has a
__\-length__ option; we want to allow the creator of a __dog__ object to
set the tail's length\. We can do this:

    % snit::type dog {
        delegate option -length to mytail

        constructor {args} {
            install mytail using tail %AUTO% -partof $self
            $self configurelist $args
        }
    }
    ::dog
    % snit::type tail {
        option -partof
        option -length 5
    }
    ::tail
    % dog spot -length 7
    ::spot
    % spot cget -length
    7

This produces nearly the same result as the __\-configuremethod__ and
__\-cgetmethod__ shown under the first question in this section: whenever a
__dog__ object's __\-length__ option is set or retrieved, the underlying
__tail__ object's option is set or retrieved in turn\.

Note that you can define an option name using the __option__ statement, or
you can define it using __delegate__; you can't do both\.

## <a name='subsection121'></a>Can I delegate to an option with a different name?

In the previous answer we delegated the __dog__'s __\-length__ option
down to its __tail__\. This is, of course, wrong\. The dog has a length, and
the tail has a length, and they are different\. What we'd really like to do is
give the __dog__ a __\-taillength__ option, but delegate it to the
__tail__'s __\-length__ option:

    snit::type dog {
        delegate option -taillength to mytail as -length

        constructor {args} {
            set mytail [tail %AUTO% -partof $self]
            $self configurelist $args
        }
    }

## <a name='subsection122'></a>How can I delegate any unrecognized method or option to a component object?

It may happen that a Snit object gets most of its behavior from one of its
components\. This often happens with __snit::widgetadaptors__, for example,
where we wish to slightly the modify the behavior of an existing widget\. To
carry on with our __dog__ example, however, suppose that we have a
__snit::type__ called __animal__ that implements a variety of animal
behaviors\-\-moving, eating, sleeping, and so forth\. We want our __dog__
objects to inherit these same behaviors, while adding dog\-like behaviors of its
own\. Here's how we can give a __dog__ methods and options of its own while
delegating all other methods and options to its __animal__ component:

    snit::type dog {
        delegate option * to animal
        delegate method * to animal

        option -akc 0

        constructor {args} {
            install animal using animal %AUTO% -name $self
            $self configurelist $args
        }

        method wag {} {
            return "$self wags its tail"
        }
    }

That's it\. A __dog__ is now an __animal__ that has a __\-akc__ option
and can __wag__ its tail\.

Note that we don't need to specify the full list of method names or option names
that __animal__ will receive\. It gets anything __dog__ doesn't
recognize\-\-and if it doesn't recognize it either, it will simply throw an error,
just as it should\.

You can also delegate all unknown type methods to a type component using
__delegate typemethod \*__\.

## <a name='subsection123'></a>How can I delegate all but certain methods or options to a component?

In the previous answer, we said that every __dog__ is an __animal__ by
delegating all unknown methods and options to the __animal__ component\. But
what if the __animal__ type has some methods or options that we'd like to
suppress?

One solution is to explicitly delegate all the options and methods, and forgo
the convenience of __delegate method \*__ and __delegate option \*__\. But
if we wish to suppress only a few options or methods, there's an easier way:

    snit::type dog {
        delegate option * to animal except -numlegs
        delegate method * to animal except {fly climb}

        # ...

        constructor {args} {
            install animal using animal %AUTO% -name $self -numlegs 4
            $self configurelist $args
        }

        # ...
    }

Dogs have four legs, so we specify that explicitly when we create the
__animal__ component, and explicitly exclude __\-numlegs__ from the set
of delegated options\. Similarly, dogs can neither __fly__ nor __climb__,
so we exclude those __animal__ methods as shown\.

## <a name='subsection124'></a>Can a hierarchical method be delegated?

Yes; just specify multiple words in the delegated method's name:

    snit::type tail {
        method wag {} {return "Wag, wag"}
        method droop {} {return "Droop, droop"}
    }

    snit::type dog {
        delegate method {tail wag} to mytail
        delegate method {tail droop} to mytail

        # ...

        constructor {args} {
            install mytail using tail %AUTO%
            $self configurelist $args
        }

        # ...
    }

Unrecognized hierarchical methods can also be delegated; the following code
delegates all subcommands of the "tail" method to the "mytail" component:

    snit::type dog {
        delegate method {tail *} to mytail

        # ...
    }

# <a name='section17'></a>WIDGETS

## <a name='subsection125'></a>What is a snit::widget?

A __snit::widget__ is the Snit version of what Tcl programmers usually call
a *megawidget*: a widget\-like object usually consisting of one or more Tk
widgets all contained within a Tk frame\.

A __snit::widget__ is also a special kind of __snit::type__\. Just about
everything in this FAQ list that relates to __snit::types__ also applies to
__snit::widgets__\.

## <a name='subsection126'></a>How do I define a snit::widget?

__snit::widgets__ are defined using the __snit::widget__ command, just
as __snit::types__ are defined by the __snit::type__ command\.

The body of the definition can contain all of the same kinds of statements, plus
a couple of others which will be mentioned below\.

## <a name='subsection127'></a>How do snit::widgets differ from snit::types?

  - The name of an instance of a __snit::type__ can be any valid Tcl command
    name, in any namespace\. The name of an instance of a __snit::widget__
    must be a valid Tk widget name, and its parent widget must already exist\.

  - An instance of a __snit::type__ can be destroyed by calling its
    __destroy__ method\. Instances of a __snit::widget__ have no destroy
    method; use the Tk __destroy__ command instead\.

  - Every instance of a __snit::widget__ has one predefined component called
    its __hull__ component\. The hull is usually a Tk
    __[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__ or __toplevel__ widget;
    any other widgets created as part of the __snit::widget__ will usually
    be contained within the hull\.

  - __snit::widget__s can have their options receive default values from
    [THE TK OPTION DATABASE](#section19)\.

## <a name='subsection128'></a>What is a hull component?

Snit can't create a Tk widget object; only Tk can do that\. Thus, every instance
of a __snit::widget__ must be wrapped around a genuine Tk widget; this Tk
widget is called the *hull component*\. Snit effectively piggybacks the
behavior you define \(methods, options, and so forth\) on top of the hull
component so that the whole thing behaves like a standard Tk widget\.

For __snit::widget__s the hull component must be a Tk widget that defines
the __\-class__ option\.

__snit::widgetadaptor__s differ from __snit::widget__s chiefly in that
any kind of widget can be used as the hull component; see [WIDGET
ADAPTORS](#section18)\.

## <a name='subsection129'></a>How can I set the hull type for a snit::widget?

A __snit::widget__'s hull component will usually be a Tk
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__ widget; however, it may be any
Tk widget that defines the __\-class__ option\. You can explicitly choose the
hull type you prefer by including the __hulltype__ command in the widget
definition:

    snit::widget mytoplevel {
        hulltype toplevel

        # ...
    }

If no __hulltype__ command appears, the hull will be a
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__\.

By default, Snit recognizes the following hull types: the Tk widgets
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__, __labelframe__,
__toplevel__, and the Tile widgets __ttk::frame__,
__ttk::labelframe__, and __ttk::toplevel__\. To enable the use of some
other kind of widget as the hull type, you can __lappend__ the widget
command to the variable __snit::hulltypes__ \(always provided the widget
defines the __\-class__ option\. For example, suppose Tk gets a new widget
type called a __prettyframe__:

    lappend snit::hulltypes prettyframe

    snit::widget mywidget {
        hulltype prettyframe

        # ...
    }

## <a name='subsection130'></a>How should I name widgets which are components of a snit::widget?

Every widget, whether a genuine Tk widget or a Snit megawidget, has to have a
valid Tk window name\. When a __snit::widget__ is first created, its instance
name, __self__, is a Tk window name; however, if the __snit::widget__ is
used as the hull component by a __snit::widgetadaptor__ its instance name
will be changed to something else\. For this reason, every __snit::widget__
method, constructor, destructor, and so forth is passed another implicit
argument, __win__, which is the window name of the megawidget\. Any children
should be named using __win__ as the root\.

Thus, suppose you're writing a toolbar widget, a frame consisting of a number of
buttons placed side\-by\-side\. It might look something like this:

    snit::widget toolbar {
        delegate option * to hull

        constructor {args} {
            button $win.open -text Open -command [mymethod open]
            button $win.save -text Save -command [mymethod save]

            # ....

            $self configurelist $args

        }
    }

See also the question on renaming objects, toward the top of this file\.

# <a name='section18'></a>WIDGET ADAPTORS

## <a name='subsection131'></a>What is a snit::widgetadaptor?

A __snit::widgetadaptor__ is a kind of __snit::widget__\. Whereas a
__snit::widget__'s hull is automatically created and is always a Tk frame, a
__snit::widgetadaptor__ can be based on any Tk widget\-\-or on any Snit
megawidget, or even \(with luck\) on megawidgets defined using some other package\.

It's called a *widget adaptor* because it allows you to take an existing
widget and customize its behavior\.

## <a name='subsection132'></a>How do I define a snit::widgetadaptor?

Use the __snit::widgetadaptor__ command\. The definition for a
__snit::widgetadaptor__ looks just like that for a __snit::type__ or
__snit::widget__, except that the constructor must create and install the
hull component\.

For example, the following code creates a read\-only text widget by the simple
device of turning its __insert__ and __delete__ methods into no\-ops\.
Then, we define new methods, __ins__ and __del__, which get delegated to
the hull component as __insert__ and __delete__\. Thus, we've adapted the
text widget and given it new behavior while still leaving it fundamentally a
text widget\.

    ::snit::widgetadaptor rotext {

        constructor {args} {
            # Create the text widget; turn off its insert cursor
            installhull using text -insertwidth 0

            # Apply any options passed at creation time.
            $self configurelist $args
        }

        # Disable the text widget's insert and delete methods, to
        # make this readonly.
        method insert {args} {}
        method delete {args} {}

        # Enable ins and del as synonyms, so the program can insert and
        # delete.
        delegate method ins to hull as insert
        delegate method del to hull as delete

        # Pass all other methods and options to the real text widget, so
        # that the remaining behavior is as expected.
        delegate method * to hull
        delegate option * to hull
    }

The most important part is in the constructor\. Whereas __snit::widget__
creates the hull for you, __snit::widgetadaptor__ cannot \-\- it doesn't know
what kind of widget you want\. So the first thing the constructor does is create
the hull component \(a Tk text widget in this case\), and then installs it using
the __installhull__ command\.

*Note:* There is no instance command until you create one by installing a hull
component\. Any attempt to pass methods to __$self__ prior to calling
__installhull__ will fail\.

## <a name='subsection133'></a>Can I adapt a widget created elsewhere in the program?

Yes\.

At times, it can be convenient to adapt a pre\-existing widget instead of
creating your own\. For example, the Bwidget __PagesManager__ widget manages
a set of __[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__ widgets, only one of
which is visible at a time\. The application chooses which
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__ is visible\. All of the These
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__s are created by the
__PagesManager__ itself, using its __add__ method\. It's convenient to
adapt these frames to do what we'd like them to do\.

In a case like this, the Tk widget will already exist when the
__snit::widgetadaptor__ is created\. Snit provides an alternate form of the
__installhull__ command for this purpose:

    snit::widgetadaptor pageadaptor {
        constructor {args} {
            # The widget already exists; just install it.
            installhull $win

            # ...
        }
    }

## <a name='subsection134'></a>Can I adapt another megawidget?

Maybe\. If the other megawidget is a __snit::widget__ or
__snit::widgetadaptor__, then yes\. If it isn't then, again, maybe\. You'll
have to try it and see\. You're most likely to have trouble with widget
destruction\-\-you have to make sure that your megawidget code receives the
__<Destroy>__ event before the megawidget you're adapting does\.

# <a name='section19'></a>THE TK OPTION DATABASE

## <a name='subsection135'></a>What is the Tk option database?

The Tk option database is a database of default option values maintained by Tk
itself; every Tk application has one\. The concept of the option database derives
from something called the X Windows resource database; however, the option
database is available in every Tk implementation, including those which do not
use the X Windows system \(e\.g\., Microsoft Windows\)\.

Full details about the Tk option database are beyond the scope of this document;
both *Practical Programming in Tcl and Tk* by Welch, Jones, and Hobbs, and
*Effective Tcl/Tk Programming* by Harrison and McClennan\., have good
introductions to it\.

Snit is implemented so that most of the time it will simply do the right thing
with respect to the option database, provided that the widget developer does the
right thing by Snit\. The body of this section goes into great deal about what
Snit requires\. The following is a brief statement of the requirements, for
reference\.

  - If the widget's default widget class is not what is desired, set it
    explicitly using the __widgetclass__ statement in the widget definition\.

  - When defining or delegating options, specify the resource and class names
    explicitly when necessary\.

  - Use the __installhull using__ command to create and install the hull for
    __snit::widgetadaptor__s\.

  - Use the __install__ command to create and install all components which
    are widgets\.

  - Use the __install__ command to create and install components which
    aren't widgets if you'd like them to receive option values from the option
    database\.

The interaction of Tk widgets with the option database is a complex thing; the
interaction of Snit with the option database is even more so, and repays
attention to detail\.

## <a name='subsection136'></a>Do snit::types use the Tk option database?

No, they don't; querying the option database requires a Tk window name, and
__snit::type__s don't have one\.

If you create an instance of a __snit::type__ as a component of a
__snit::widget__ or __snit::widgetadaptor__, on the other hand, and if
any options are delegated to the component, and if you use __install__ to
create and install it, then the megawidget will query the option database on the
__snit::type__'s behalf\. This might or might not be what you want, so take
care\.

## <a name='subsection137'></a>What is my snit::widget's widget class?

Every Tk widget has a "widget class": a name that is used when adding option
settings to the database\. For Tk widgets, the widget class is the same as the
widget command name with an initial capital\. For example, the widget class of
the Tk __button__ widget is __Button__\.

Similarly, the widget class of a __snit::widget__ defaults to the
unqualified type name with the first letter capitalized\. For example, the widget
class of

    snit::widget ::mylibrary::scrolledText { ... }

is __ScrolledText__\.

The widget class can also be set explicitly using the __widgetclass__
statement within the __snit::widget__ definition:

    snit::widget ::mylibrary::scrolledText {
        widgetclass Text

        # ...
    }

The above definition says that a __scrolledText__ megawidget has the same
widget class as an ordinary __[text](\.\./\.\./\.\./\.\./index\.md\#text)__
widget\. This might or might not be a good idea, depending on how the rest of the
megawidget is defined, and how its options are delegated\.

## <a name='subsection138'></a>What is my snit::widgetadaptor's widget class?

The widget class of a __snit::widgetadaptor__ is just the widget class of
its hull widget; Snit has no control over this\.

Note that the widget class can be changed only for
__[frame](\.\./\.\./\.\./\.\./index\.md\#frame)__ and __toplevel__ widgets,
which is why these are the valid hull types for __snit::widget__s\.

Try to use __snit::widgetadaptor__s only to make small modifications to
another widget's behavior\. Then, it will usually not make sense to change the
widget's widget class anyway\.

## <a name='subsection139'></a>What are option resource and class names?

Every Tk widget option has three names: the option name, the resource name, and
the class name\. The option name begins with a hyphen and is all lowercase; it's
used when creating widgets, and with the __configure__ and __cget__
commands\.

The resource and class names are used to initialize option default values by
querying the option database\. The resource name is usually just the option name
minus the hyphen, but may contain uppercase letters at word boundaries; the
class name is usually just the resource name with an initial capital, but not
always\. For example, here are the option, resource, and class names for several
Tk __[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget options:

    -background         background         Background
    -borderwidth        borderWidth        BorderWidth
    -insertborderwidth  insertBorderWidth  BorderWidth
    -padx               padX               Pad

As is easily seen, sometimes the resource and class names can be inferred from
the option name, but not always\.

## <a name='subsection140'></a>What are the resource and class names for my megawidget's options?

For options implicitly delegated to a component using __delegate option \*__,
the resource and class names will be exactly those defined by the component\. The
__configure__ method returns these names, along with the option's default
and current values:

    % snit::widget mytext {
        delegate option * to text

        constructor {args} {
            install text using text .text
            # ...
        }

        # ...
    }
    ::mytext
    % mytext .text
    .text
    % .text configure -padx
    -padx padX Pad 1 1
    %

For all other options \(whether locally defined or explicitly delegated\), the
resource and class names can be defined explicitly, or they can be allowed to
have default values\.

By default, the resource name is just the option name minus the hyphen; the the
class name is just the option name with an initial capital letter\. For example,
suppose we explicitly delegate "\-padx":

    % snit::widget mytext {
        option -myvalue 5

        delegate option -padx to text
        delegate option * to text

        constructor {args} {
            install text using text .text
            # ...
        }

        # ...
    }
    ::mytext
    % mytext .text
    .text
    % .text configure -myvalue
    -myvalue myvalue Myvalue 5 5
    % .text configure -padx
    -padx padx Padx 1 1
    %

Here the resource and class names are chosen using the default rules\. Often
these rules are sufficient, but in the case of "\-padx" we'd most likely prefer
that the option's resource and class names are the same as for the built\-in Tk
widgets\. This is easily done:

    % snit::widget mytext {
        delegate option {-padx padX Pad} to text

        # ...
    }
    ::mytext
    % mytext .text
    .text
    % .text configure -padx
    -padx padX Pad 1 1
    %

## <a name='subsection141'></a>How does Snit initialize my megawidget's locally\-defined options?

The option database is queried for each of the megawidget's locally\-defined
options, using the option's resource and class name\. If the result isn't "",
then it replaces the default value given in widget definition\. In either case,
the default can be overridden by the caller\. For example,

    option add *Mywidget.texture pebbled

    snit::widget mywidget {
        option -texture smooth
        # ...
    }

    mywidget .mywidget -texture greasy

Here, __\-texture__ would normally default to "smooth", but because of the
entry added to the option database it defaults to "pebbled"\. However, the caller
has explicitly overridden the default, and so the new widget will be "greasy"\.

## <a name='subsection142'></a>How does Snit initialize delegated options?

That depends on whether the options are delegated to the hull, or to some other
component\.

## <a name='subsection143'></a>How does Snit initialize options delegated to the hull?

A __snit::widget__'s hull is a widget, and given that its class has been set
it is expected to query the option database for itself\. The only exception
concerns options that are delegated to it with a different name\. Consider the
following code:

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

The value of A is "sunken"\. The hull is a Tk frame which has been given the
widget class __Mywidget__; it will automatically query the option database
and pick up this value\. Since the __\-relief__ option is implicitly delegated
to the hull, Snit takes no action\.

The value of B is "red"\. The hull will automatically pick up the value "green"
for its __\-background__ option, just as it picked up the __\-relief__
value\. However, Snit knows that __\-hullbackground__ is mapped to the hull's
__\-background__ option; hence, it queries the option database for
__\-hullbackground__ and gets "red" and updates the hull accordingly\.

The value of C is also "red", because __\-background__ is implicitly
delegated to the hull; thus, retrieving it is the same as retrieving
__\-hullbackground__\. Note that this case is unusual; the __\-background__
option should probably have been excluded using the delegate statement's
__except__ clause, or \(more likely\) delegated to some other component\.

The value of D is "5", but not for the reason you think\. Note that as it is
defined above, the resource name for __\-borderwidth__ defaults to
__borderwidth__, whereas the option database entry is __borderWidth__,
in accordance with the standard Tk naming for this option\. As with
__\-relief__, the hull picks up its own __\-borderwidth__ option before
Snit does anything\. Because the option is delegated under its own name, Snit
assumes that the correct thing has happened, and doesn't worry about it any
further\. To avoid confusion, the __\-borderwidth__ option should have been
delegated like this:

    delegate option {-borderwidth borderWidth BorderWidth} to hull

For __snit::widgetadaptor__s, the case is somewhat altered\. Widget adaptors
retain the widget class of their hull, and the hull is not created automatically
by Snit\. Instead, the __snit::widgetadaptor__ must call __installhull__
in its constructor\. The normal way to do this is as follows:

    snit::widgetadaptor mywidget {
        # ...
        constructor {args} {
            # ...
            installhull using text -foreground white
            # ...
        }
        # ...
    }

In this case, the __installhull__ command will create the hull using a
command like this:

    set hull [text $win -foreground white]

The hull is a __[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget, so its
widget class is __Text__\. Just as with __snit::widget__ hulls, Snit
assumes that it will pick up all of its normal option values automatically,
without help from Snit\. Options delegated from a different name are initialized
from the option database in the same way as described above\.

In earlier versions of Snit, __snit::widgetadaptor__s were expected to call
__installhull__ like this:

    installhull [text $win -foreground white]

This form still works\-\-but Snit will not query the option database as described
above\.

## <a name='subsection144'></a>How does Snit initialize options delegated to other components?

For hull components, Snit assumes that Tk will do most of the work
automatically\. Non\-hull components are somewhat more complicated, because they
are matched against the option database twice\.

A component widget remains a widget still, and is therefore initialized from the
option database in the usual way\. A
__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget remains a
__[text](\.\./\.\./\.\./\.\./index\.md\#text)__ widget whether it is a component
of a megawidget or not, and will be created as such\.

But then, the option database is queried for all options delegated to the
component, and the component is initialized accordingly\-\-provided that the
__install__ command is used to create it\.

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
    command\-\-in this case, __\-foreground__\.

  - Queries the option database for all options delegated explicitly to the
    named component\.

  - Creates the component using the specified command, after inserting into it a
    list of options and values read from the option database\. Thus, the
    explicitly included options \(like __\-foreground__\) will override
    anything read from the option database\.

  - If the widget definition implicitly delegated options to the component using
    __delegate option \*__, then Snit calls the newly created component's
    __configure__ method to receive a list of all of the component's
    options\. From this Snit builds a list of options implicitly delegated to the
    component which were not explicitly included in the __install__ command\.
    For all such options, Snit queries the option database and configures the
    component accordingly\.

You don't really need to know all of this; just use __install__ to install
your components, and Snit will try to do the right thing\.

## <a name='subsection145'></a>What happens if I install a non\-widget as a component of widget?

A __snit::type__ never queries the option database\. However, a
__snit::widget__ can have non\-widget components\. And if options are
delegated to those components, and if the __install__ command is used to
install those components, then they will be initialized from the option database
just as widget components are\.

However, when used within a megawidget, __install__ assumes that the created
component uses a reasonably standard widget\-like creation syntax\. If it doesn't,
don't use __install__\.

# <a name='section20'></a>ENSEMBLE COMMANDS

## <a name='subsection146'></a>What is an ensemble command?

An ensemble command is a command with subcommands\. Snit objects are all ensemble
commands; however, the term more usually refers to commands like the standard
Tcl commands __[string](\.\./\.\./\.\./\.\./index\.md\#string)__,
__[file](\.\./\.\./\.\./\.\./index\.md\#file)__, and __clock__\. In a sense,
these are singleton objects\-\-there's only one instance of them\.

## <a name='subsection147'></a>How can I create an ensemble command using Snit?

There are two ways\-\-as a __snit::type__, or as an instance of a
__snit::type__\.

## <a name='subsection148'></a>How can I create an ensemble command using an instance of a snit::type?

Define a type whose [INSTANCE METHODS](#section5) are the subcommands of
your ensemble command\. Then, create an instance of the type with the desired
name\.

For example, the following code uses [DELEGATION](#section16) to create a
work\-alike for the standard __[string](\.\./\.\./\.\./\.\./index\.md\#string)__
command:

    snit::type ::mynamespace::mystringtype {
        delegate method * to stringhandler

        constructor {} {
            set stringhandler string
        }
    }

    ::mynamespace::mystringtype mystring

We create the type in a namespace, so that the type command is hidden; then we
create a single instance with the desired name\-\- __mystring__, in this case\.

This method has two drawbacks\. First, it leaves the type command floating about\.
More seriously, your shiny new ensemble command will have __info__ and
__destroy__ subcommands that you probably have no use for\. But read on\.

## <a name='subsection149'></a>How can I create an ensemble command using a snit::type?

Define a type whose [TYPE METHODS](#section9) are the subcommands of your
ensemble command\.

For example, the following code uses [DELEGATION](#section16) to create a
work\-alike for the standard __[string](\.\./\.\./\.\./\.\./index\.md\#string)__
command:

    snit::type mystring {
        delegate typemethod * to stringhandler

        typeconstructor {
            set stringhandler string
        }
    }

Now the type command itself is your ensemble command\.

This method has only one drawback, and though it's major, it's also
surmountable\. Your new ensemble command will have __create__, __info__
and __destroy__ subcommands you don't want\. And worse yet, since the
__create__ method can be implicit, users of your command will accidentally
be creating instances of your __mystring__ type if they should mispell one
of the subcommands\. The command will succeed\-\-the first time\-\-but won't do
what's wanted\. This is very bad\.

The work around is to set some [PRAGMAS](#section21), as shown here:

    snit::type mystring {
        pragma -hastypeinfo    no
        pragma -hastypedestroy no
        pragma -hasinstances   no

        delegate typemethod * to stringhandler

        typeconstructor {
            set stringhandler string
        }
    }

Here we've used the __pragma__ statement to tell Snit that we don't want the
__info__ typemethod or the __destroy__ typemethod, and that our type has
no instances; this eliminates the __create__ typemethod and all related
code\. As a result, our ensemble command will be well\-behaved, with no unexpected
subcommands\.

# <a name='section21'></a>PRAGMAS

## <a name='subsection150'></a>What is a pragma?

A pragma is an option you can set in your type definitions that affects how the
type is defined and how it works once it is defined\.

## <a name='subsection151'></a>How do I set a pragma?

Use the __pragma__ statement\. Each pragma is an option with a value; each
time you use the __pragma__ statement you can set one or more of them\.

## <a name='subsection152'></a>How can I get rid of the "info" type method?

Set the __\-hastypeinfo__ pragma to __no__:

    snit::type dog {
        pragma -hastypeinfo no
        # ...
    }

Snit will refrain from defining the __info__ type method\.

## <a name='subsection153'></a>How can I get rid of the "destroy" type method?

Set the __\-hastypedestroy__ pragma to __no__:

    snit::type dog {
        pragma -hastypedestroy no
        # ...
    }

Snit will refrain from defining the __destroy__ type method\.

## <a name='subsection154'></a>How can I get rid of the "create" type method?

Set the __\-hasinstances__ pragma to __no__:

    snit::type dog {
        pragma -hasinstances no
        # ...
    }

Snit will refrain from defining the __create__ type method; if you call the
type command with an unknown method name, you'll get an error instead of a new
instance of the type\.

This is useful if you wish to use a __snit::type__ to define an ensemble
command rather than a type with instances\.

Pragmas __\-hastypemethods__ and __\-hasinstances__ cannot both be false
\(or there'd be nothing left\)\.

## <a name='subsection155'></a>How can I get rid of type methods altogether?

Normal Tk widget type commands don't have subcommands; all they do is create
widgets\-\-in Snit terms, the type command calls the __create__ type method
directly\. To get the same behavior from Snit, set the __\-hastypemethods__
pragma to __no__:

    snit::type dog {
        pragma -hastypemethods no
        #...
    }

    # Creates ::spot
    dog spot

    # Tries to create an instance called ::create
    dog create spot

Pragmas __\-hastypemethods__ and __\-hasinstances__ cannot both be false
\(or there'd be nothing left\)\.

## <a name='subsection156'></a>Why can't I create an object that replaces an old object with the same name?

Up until Snit 0\.95, you could use any name for an instance of a
__snit::type__, even if the name was already in use by some other object or
command\. You could do the following, for example:

    snit::type dog { ... }

    dog proc

You now have a new dog named "proc", which is probably not something that you
really wanted to do\. As a result, Snit now throws an error if your chosen
instance name names an existing command\. To restore the old behavior, set the
__\-canreplace__ pragma to __yes__:

    snit::type dog {
        pragma -canreplace yes
        # ...
    }

## <a name='subsection157'></a>How can I make my simple type run faster?

In Snit 1\.x, you can set the __\-simpledispatch__ pragma to __yes__\.

Snit 1\.x method dispatch is both flexible and fast, but the flexibility comes
with a price\. If your type doesn't require the flexibility, the
__\-simpledispatch__ pragma allows you to substitute a simpler dispatch
mechanism that runs quite a bit faster\. The limitations are these:

  - Methods cannot be delegated\.

  - __uplevel__ and __upvar__ do not work as expected: the caller's
    scope is two levels up rather than one\.

  - The option\-handling methods \(__cget__, __configure__, and
    __configurelist__\) are very slightly slower\.

In Snit 2\.2, the __\-simpledispatch__ macro is obsolete, and ignored; all
Snit 2\.2 method dispatch is faster than Snit 1\.x's __\-simpledispatch__\.

# <a name='section22'></a>MACROS

## <a name='subsection158'></a>What is a macro?

A Snit macro is nothing more than a Tcl proc that's defined in the Tcl
interpreter used to compile Snit type definitions\.

## <a name='subsection159'></a>What are macros good for?

You can use Snit macros to define new type definition syntax, and to support
conditional compilation\.

## <a name='subsection160'></a>How do I do conditional compilation?

Suppose you want your type to use a fast C extension if it's available;
otherwise, you'll fallback to a slower Tcl implementation\. You want to define
one set of methods in the first case, and another set in the second case\. But
how can your type definition know whether the fast C extension is available or
not?

It's easily done\. Outside of any type definition, define a macro that returns 1
if the extension is available, and 0 otherwise:

    if {$gotFastExtension} {
        snit::macro fastcode {} {return 1}
    } else {
        snit::macro fastcode {} {return 0}
    }

Then, use your macro in your type definition:

    snit::type dog {

        if {[fastcode]} {
            # Fast methods
            method bark {} {...}
            method wagtail {} {...}
        } else {
            # Slow methods
            method bark {} {...}
            method wagtail {} {...}
        }
    }

## <a name='subsection161'></a>How do I define new type definition syntax?

Use a macro\. For example, your __snit::widget__'s __\-background__ option
should be propagated to a number of component widgets\. You could implement that
like this:

    snit::widget mywidget {
        option -background -default white -configuremethod PropagateBackground

        method PropagateBackground {option value} {
            $comp1 configure $option $value
            $comp2 configure $option $value
            $comp3 configure $option $value
        }
    }

For one option, this is fine; if you've got a number of options, it becomes
tedious and error prone\. So package it as a macro:

    snit::macro propagate {option "to" components} {
        option $option -configuremethod Propagate$option

        set body "\n"

        foreach comp $components {
            append body "\$$comp configure $option \$value\n"
        }

        method Propagate$option {option value} $body
    }

Then you can use it like this:

    snit::widget mywidget {
        option -background default -white
        option -foreground default -black

        propagate -background to {comp1 comp2 comp3}
        propagate -foreground to {comp1 comp2 comp3}
    }

## <a name='subsection162'></a>Are there are restrictions on macro names?

Yes, there are\. You can't redefine any standard Tcl commands or Snit type
definition statements\. You can use any other command name, including the name of
a previously defined macro\.

If you're using Snit macros in your application, go ahead and name them in the
global namespace, as shown above\. But if you're using them to define types or
widgets for use by others, you should define your macros in the same namespace
as your types or widgets\. That way, they won't conflict with other people's
macros\.

If my fancy __snit::widget__ is called __::mylib::mywidget__, for
example, then I should define my __propagate__ macro as
__::mylib::propagate__:

    snit::macro mylib::propagate {option "to" components} { ... }

    snit::widget ::mylib::mywidget {
        option -background default -white
        option -foreground default -black

        mylib::propagate -background to {comp1 comp2 comp3}
        mylib::propagate -foreground to {comp1 comp2 comp3}
    }

# <a name='section23'></a>Bugs, Ideas, Feedback

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
[adaptors](\.\./\.\./\.\./\.\./index\.md\#adaptors),
[class](\.\./\.\./\.\./\.\./index\.md\#class), [mega
widget](\.\./\.\./\.\./\.\./index\.md\#mega\_widget),
[object](\.\./\.\./\.\./\.\./index\.md\#object), [object
oriented](\.\./\.\./\.\./\.\./index\.md\#object\_oriented),
[widget](\.\./\.\./\.\./\.\./index\.md\#widget), [widget
adaptors](\.\./\.\./\.\./\.\./index\.md\#widget\_adaptors)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2003\-2006, by William H\. Duquette
