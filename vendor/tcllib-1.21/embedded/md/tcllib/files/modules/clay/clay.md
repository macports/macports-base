
[//000000001]: # (clay \- Clay Framework)
[//000000002]: # (Generated from file 'clay\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (clay\(n\) 0\.8\.6 tcllib "Clay Framework")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

clay \- A minimalist framework for large scale OO Projects

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [Structured Data](#subsection1)

      - [Clay Dialect](#subsection2)

      - [Method Delegation](#subsection3)

  - [Commands](#section2)

  - [Classes](#section3)

      - [Class clay::class](#subsection4)

      - [Class clay::object](#subsection5)

  - [AUTHORS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require uuid  
package require oo::dialect  

[proc __clay::PROC__ *name* *arglist* *body* ?*ninja* ____?](#1)  
[proc __clay::\_ancestors__ *resultvar* *class*](#2)  
[proc __clay::ancestors__ ?*args*?](#3)  
[proc __clay::args\_to\_dict__ ?*args*?](#4)  
[proc __clay::args\_to\_options__ ?*args*?](#5)  
[proc __clay::dynamic\_arguments__ *ensemble* *method* *arglist* ?*args*?](#6)  
[proc __clay::dynamic\_wrongargs\_message__ *arglist*](#7)  
[proc __clay::is\_dict__ *d*](#8)  
[proc __clay::is\_null__ *value*](#9)  
[proc __clay::leaf__ ?*args*?](#10)  
[proc __clay::K__ *a* *b*](#11)  
[proc __clay::noop__ ?*args*?](#12)  
[proc __clay::cleanup__](#13)  
[proc __clay::object\_create__ *objname* ?*class* ____?](#14)  
[proc __clay::object\_rename__ *object* *newname*](#15)  
[proc __clay::object\_destroy__ ?*args*?](#16)  
[proc __clay::path__ ?*args*?](#17)  
[proc __clay::putb__ ?*map*? *text*](#18)  
[proc __clay::script\_path__](#19)  
[proc __clay::NSNormalize__ *qualname*](#20)  
[proc __clay::uuid\_generate__ ?*args*?](#21)  
[proc __clay::uuid::generate\_tcl\_machinfo__](#22)  
[proc __clay::uuid::tostring__ *uuid*](#23)  
[proc __clay::uuid::fromstring__ *uuid*](#24)  
[proc __clay::uuid::equal__ *left* *right*](#25)  
[proc __clay::uuid__ *cmd* ?*args*?](#26)  
[proc __clay::tree::sanitize__ *dict*](#27)  
[proc __clay::tree::\_sanitizeb__ *path* *varname* *dict*](#28)  
[proc __clay::tree::storage__ *rawpath*](#29)  
[proc __clay::tree::dictset__ *varname* ?*args*?](#30)  
[proc __clay::tree::dictmerge__ *varname* ?*args*?](#31)  
[proc __clay::tree::merge__ ?*args*?](#32)  
[proc __dictargs::proc__ *name* *argspec* *body*](#33)  
[proc __dictargs::method__ *name* *argspec* *body*](#34)  
[proc __clay::dialect::Push__ *class*](#35)  
[proc __clay::dialect::Peek__](#36)  
[proc __clay::dialect::Pop__](#37)  
[proc __clay::dialect::create__ *name* ?*parent* ____?](#38)  
[proc __clay::dialect::NSNormalize__ *namespace* *qualname*](#39)  
[proc __clay::dialect::DefineThunk__ *target* ?*args*?](#40)  
[proc __clay::dialect::Canonical__ *namespace* *NSpace* *class*](#41)  
[proc __clay::dialect::Define__ *namespace* *class* ?*args*?](#42)  
[proc __clay::dialect::Aliases__ *namespace* ?*args*?](#43)  
[proc __clay::dialect::SuperClass__ *namespace* ?*args*?](#44)  
[proc __clay::dynamic\_methods__ *class*](#45)  
[proc __clay::dynamic\_methods\_class__ *thisclass*](#46)  
[proc __clay::define::Array__ *name* ?*values* ____?](#47)  
[proc __clay::define::Delegate__ *name* *info*](#48)  
[proc __clay::define::constructor__ *arglist* *rawbody*](#49)  
[proc __clay::define::Class\_Method__ *name* *arglist* *body*](#50)  
[proc __clay::define::class\_method__ *name* *arglist* *body*](#51)  
[proc __clay::define::clay__ ?*args*?](#52)  
[proc __clay::define::destructor__ *rawbody*](#53)  
[proc __clay::define::Dict__ *name* ?*values* ____?](#54)  
[proc __clay::define::Option__ *name* ?*args*?](#55)  
[proc __clay::define::Method__ *name* *argstyle* *argspec* *body*](#56)  
[proc __clay::define::Option\_Class__ *name* ?*args*?](#57)  
[proc __clay::define::Variable__ *name* ?*default* ____?](#58)  
[proc __clay::ensemble\_methodbody__ *ensemble* *einfo*](#59)  
[proc __clay::define::Ensemble__ *rawmethod* ?*args*?](#60)  
[proc __clay::event::cancel__ *self* ?*task* __\*__?](#61)  
[proc __clay::event::generate__ *self* *event* ?*args*?](#62)  
[proc __clay::event::nextid__](#63)  
[proc __clay::event::Notification\_list__ *self* *event* ?*stackvar* ____?](#64)  
[proc __clay::event::notify__ *rcpt* *sender* *event* *eventinfo*](#65)  
[proc __clay::event::process__ *self* *handle* *script*](#66)  
[proc __clay::event::schedule__ *self* *handle* *interval* *script*](#67)  
[proc __clay::event::subscribe__ *self* *who* *event*](#68)  
[proc __clay::event::unsubscribe__ *self* ?*args*?](#69)  
[proc __clay::singleton__ *name* *script*](#70)  
[method __clay ancestors__](#71)  
[method __clay dump__](#72)  
[method __clay find__ *path* ?__path\.\.\.__?](#73)  
[method __clay get__ *path* ?__path\.\.\.__?](#74)  
[method __clay GET__ *path* ?__path\.\.\.__?](#75)  
[method __clay merge__ *dict* ?__dict\.\.\.__?](#76)  
[method __clay replace__ *dictionary*](#77)  
[method __clay search__ *path* ?__path\.\.\.__?](#78)  
[method __clay set__ *path* ?__path\.\.\.__? *value*](#79)  
[method __clay ancestors__](#80)  
[method __clay cache__ *path* *value*](#81)  
[method __clay cget__ *field*](#82)  
[method __clay delegate__ ?*stub*? ?*object*?](#83)  
[method __clay dump__](#84)  
[method __clay ensemble\_map__](#85)  
[method __clay eval__ *script*](#86)  
[method __clay evolve__](#87)  
[method __clay exists__ *path* ?__path\.\.\.__?](#88)  
[method __clay flush__](#89)  
[method __clay forward__ *method* *object*](#90)  
[method __clay get__ *path* ?__path\.\.\.__?](#91)  
[method __clay leaf__ *path* ?__path\.\.\.__?](#92)  
[method __clay merge__ *dict* ?__dict\.\.\.__?](#93)  
[method __clay mixin__ *class* ?__class\.\.\.__?](#94)  
[method __clay mixinmap__ ?*stub*? ?*classes*?](#95)  
[method __clay provenance__ *path* ?__path\.\.\.__?](#96)  
[method __clay replace__ *dictionary*](#97)  
[method __clay search__ *path* *valuevar* *isleafvar*](#98)  
[method __clay source__ *filename*](#99)  
[method __clay set__ *path* ?__path\.\.\.__? *value*](#100)  
[method __InitializePublic__](#101)  

# <a name='description'></a>DESCRIPTION

Clay introduces a method ensemble to both __oo::class__ and
__oo::object__ called clay\. This ensemble handles all of the high level
interactions within the framework\. Clay stores structured data\. Clan manages
method delegation\. Clay has facilities to manage the complex interactions that
come about with mixins\.

The central concept is that inside of every object and class \(which are actually
objects too\) is a dict called clay\. What is stored in that dict is left to the
imagination\. But because this dict is exposed via a public method, we can share
structured data between object, classes, and mixins\.

## <a name='subsection1'></a>Structured Data

Clay uses a standardized set of method interactions and introspection that TclOO
already provides to perform on\-the\-fly searches\. On\-the\-fly searches mean that
the data is never stale, and we avoid many of the sorts of collisions that would
arise when objects start mixing in other classes during operation\.

The __clay__ methods for both classes and objects have a get and a set
method\. For objects, get will search through the local clay dict\. If the
requested leaf is not found, or the query is for a branch, the system will then
begin to poll the clay methods of all of the class that implements the object,
all of that classes’ ancestors, as well as all of the classes that have been
mixed into this object, and all of their ancestors\.

Intended branches on a tree end with a directory slash \(/\)\. Intended leaves are
left unadorned\. This is a guide for the tool that builds the search results to
know what parts of a dict are intended to be branches and which are intended to
be leaves\. For simple cases, branch marking can be ignored:

    ::oo::class create ::foo { }
    ::foo clay set property/ color blue
    ::foo clay set property/ shape round

    set A [::foo new]
    $A clay get property/
    {color blue shape round}

    $A clay set property/ shape square
    $A clay get property/
    {color blue shape square}

But when you start storing blocks of text, guessing what field is a dict and
what isn’t gets messy:

    ::foo clay set description {A generic thing of designated color and shape}

    $A clay get description
    {A generic thing of designated color and shape}

    Without a convention for discerning branches for leaves what should have been a value can be accidentally parsed as a dictionary, and merged with all of the other values that were never intended to be merge. Here is an example of it all going wrong:
    ::oo::class create ::foo { }
    # Add description as a leaf
    ::foo clay set description  {A generic thing of designated color and shape}
    # Add description as a branch
    ::foo clay set description/  {A generic thing of designated color and shape}

    ::oo::class create ::bar {
      superclass foo
    }
    # Add description as a leaf
    ::bar clay set description  {A drinking establishment of designated color and shape and size}
    # Add description as a branch
    ::bar clay set description/  {A drinking establishment of designated color and shape and size}

    set B [::bar new]
    # As a leaf we get the value verbatim from he nearest ancestor
    $B clay get description
      {A drinking establishment of designated color and shape and size}
    # As a branch we get a recursive merge
    $B clay get description/
    {A drinking establishment of designated color and size thing of}

## <a name='subsection2'></a>Clay Dialect

Clay is built using the oo::dialect module from Tcllib\. oo::dialect allows you
to either add keywords directly to clay, or to create your own metaclass and
keyword set using Clay as a foundation\. For details on the keywords and what
they do, consult the functions in the ::clay::define namespace\.

## <a name='subsection3'></a>Method Delegation

Method Delegation It is sometimes useful to have an external object that can be
invoked as if it were a method of the object\. Clay provides a delegate ensemble
method to perform that delegation, as well as introspect which methods are
delegated in that manner\. All delegated methods are marked with html\-like tag
markings \(< >\) around them\.

    ::clay::define counter {
      Variable counter 0
      method incr {{howmuch 1}} {
        my variable counter
        incr counter $howmuch
      }
      method value {} {
        my variable counter
        return $counter
      }
      method reset {} {
        my variable counter
        set counter 0
      }
    }
    ::clay::define example {
      variable buffer
      constructor {} {
        # Build a counter object
        set obj [namespace current]::counter
        ::counter create $obj
        # Delegate the counter
        my delegate <counter> $obj
      }
      method line {text} {
        my <counter> incr
        append buffer $text
      }
    }

    set A [example new]
    $A line {Who’s line is it anyway?}
    $A <counter> value
    1

# <a name='section2'></a>Commands

  - <a name='1'></a>proc __clay::PROC__ *name* *arglist* *body* ?*ninja* ____?

    Because many features in this package may be added as commands to future tcl
    cores, or be provided in binary form by packages, I need a declaritive way
    of saying *Create this command if there isn't one already*\. The *ninja*
    argument is a script to execute if the command is created by this mechanism\.

  - <a name='2'></a>proc __clay::\_ancestors__ *resultvar* *class*

  - <a name='3'></a>proc __clay::ancestors__ ?*args*?

  - <a name='4'></a>proc __clay::args\_to\_dict__ ?*args*?

  - <a name='5'></a>proc __clay::args\_to\_options__ ?*args*?

  - <a name='6'></a>proc __clay::dynamic\_arguments__ *ensemble* *method* *arglist* ?*args*?

  - <a name='7'></a>proc __clay::dynamic\_wrongargs\_message__ *arglist*

  - <a name='8'></a>proc __clay::is\_dict__ *d*

  - <a name='9'></a>proc __clay::is\_null__ *value*

  - <a name='10'></a>proc __clay::leaf__ ?*args*?

  - <a name='11'></a>proc __clay::K__ *a* *b*

  - <a name='12'></a>proc __clay::noop__ ?*args*?

    Perform a noop\. Useful in prototyping for commenting out blocks of code
    without actually having to comment them out\. It also makes a handy default
    for method delegation if a delegate has not been assigned yet\.

  - <a name='13'></a>proc __clay::cleanup__

    Process the queue of objects to be destroyed

  - <a name='14'></a>proc __clay::object\_create__ *objname* ?*class* ____?

  - <a name='15'></a>proc __clay::object\_rename__ *object* *newname*

  - <a name='16'></a>proc __clay::object\_destroy__ ?*args*?

    Mark an objects for destruction on the next cleanup

  - <a name='17'></a>proc __clay::path__ ?*args*?

  - <a name='18'></a>proc __clay::putb__ ?*map*? *text*

    Append a line of text to a variable\. Optionally apply a string mapping\.

  - <a name='19'></a>proc __clay::script\_path__

  - <a name='20'></a>proc __clay::NSNormalize__ *qualname*

  - <a name='21'></a>proc __clay::uuid\_generate__ ?*args*?

  - <a name='22'></a>proc __clay::uuid::generate\_tcl\_machinfo__

  - <a name='23'></a>proc __clay::uuid::tostring__ *uuid*

  - <a name='24'></a>proc __clay::uuid::fromstring__ *uuid*

    Convert a string representation of a uuid into its binary format\.

  - <a name='25'></a>proc __clay::uuid::equal__ *left* *right*

    Compare two uuids for equality\.

  - <a name='26'></a>proc __clay::uuid__ *cmd* ?*args*?

    uuid generate \-> string rep of a new uuid uuid equal uuid1 uuid2

  - <a name='27'></a>proc __clay::tree::sanitize__ *dict*

    Output a dictionary removing any \. entries added by
    __clay::tree::merge__

  - <a name='28'></a>proc __clay::tree::\_sanitizeb__ *path* *varname* *dict*

    Helper function for ::clay::tree::sanitize Formats the string representation
    for a dictionary element within a human readable stream of lines, and
    determines if it needs to call itself with further indentation to express a
    sub\-branch

  - <a name='29'></a>proc __clay::tree::storage__ *rawpath*

    Return the path as a storage path for clay::tree with all branch terminators
    removed\. This command will also break arguments up if they contain /\.

    Example:

    > clay::tree::storage {foo bar baz bang}
    foo bar baz bang
    > clay::tree::storage {foo bar baz bang/}
    foo bar baz bang
    > clay::tree::storage {foo bar baz bang:}
    foo bar baz bang:
    > clay::tree::storage {foo/bar/baz bang:}
    foo bar baz bang:
    > clay::tree::storage {foo/bar/baz/bang}
    foo bar baz bang

  - <a name='30'></a>proc __clay::tree::dictset__ *varname* ?*args*?

    Set an element with a recursive dictionary, marking all branches on the way
    down to the final element\. If the value does not exists in the nested
    dictionary it is added as a leaf\. If the value already exists as a branch
    the value given is merged if the value is a valid dict\. If the incoming
    value is not a valid dict, the value overrides the value stored, and the
    value is treated as a leaf from then on\.

    Example:

    > set r {}
    > ::clay::tree::dictset r option color default Green
    . {} option {. {} color {. {} default Green}}
    > ::clay::tree::dictset r option {Something not dictlike}
    . {} option {Something not dictlike}
    # Note that if the value is not a dict, and you try to force it to be
    # an error with be thrown on the merge
    > ::clay::tree::dictset r option color default Blue
    missing value to go with key

  - <a name='31'></a>proc __clay::tree::dictmerge__ *varname* ?*args*?

    A recursive form of dict merge, intended for modifying variables in place\.

    Example:

    > set mydict {sub/ {sub/ {description {a block of text}}}}
    > ::clay::tree::dictmerge mydict {sub/ {sub/ {field {another block of text}}}}]
    > clay::tree::print $mydict
    sub/ {
      sub/ {
        description {a block of text}
        field {another block of text}
      }
    }

  - <a name='32'></a>proc __clay::tree::merge__ ?*args*?

    A recursive form of dict merge

    A routine to recursively dig through dicts and merge adapted from
    http://stevehavelka\.com/tcl\-dict\-operation\-nested\-merge/

    Example:

    > set mydict {sub/ {sub/ {description {a block of text}}}}
    > set odict [clay::tree::merge $mydict {sub/ {sub/ {field {another block of text}}}}]
    > clay::tree::print $odict
    sub/ {
      sub/ {
        description {a block of text}
        field {another block of text}
      }
    }

  - <a name='33'></a>proc __dictargs::proc__ *name* *argspec* *body*

    Named Procedures as new command

  - <a name='34'></a>proc __dictargs::method__ *name* *argspec* *body*

  - <a name='35'></a>proc __clay::dialect::Push__ *class*

  - <a name='36'></a>proc __clay::dialect::Peek__

  - <a name='37'></a>proc __clay::dialect::Pop__

  - <a name='38'></a>proc __clay::dialect::create__ *name* ?*parent* ____?

    This proc will generate a namespace, a "mother of all classes", and a
    rudimentary set of policies for this dialect\.

  - <a name='39'></a>proc __clay::dialect::NSNormalize__ *namespace* *qualname*

    Support commands; not intended to be called directly\.

  - <a name='40'></a>proc __clay::dialect::DefineThunk__ *target* ?*args*?

  - <a name='41'></a>proc __clay::dialect::Canonical__ *namespace* *NSpace* *class*

  - <a name='42'></a>proc __clay::dialect::Define__ *namespace* *class* ?*args*?

    Implementation of the languages' define command

  - <a name='43'></a>proc __clay::dialect::Aliases__ *namespace* ?*args*?

  - <a name='44'></a>proc __clay::dialect::SuperClass__ *namespace* ?*args*?

  - <a name='45'></a>proc __clay::dynamic\_methods__ *class*

  - <a name='46'></a>proc __clay::dynamic\_methods\_class__ *thisclass*

  - <a name='47'></a>proc __clay::define::Array__ *name* ?*values* ____?

    New OO Keywords for clay

  - <a name='48'></a>proc __clay::define::Delegate__ *name* *info*

    An annotation that objects of this class interact with delegated methods\.
    The annotation is intended to be a dictionary, and the only reserved key is
    *description*, a human readable description\.

  - <a name='49'></a>proc __clay::define::constructor__ *arglist* *rawbody*

  - <a name='50'></a>proc __clay::define::Class\_Method__ *name* *arglist* *body*

    Specify the a method for the class object itself, instead of for objects of
    the class

  - <a name='51'></a>proc __clay::define::class\_method__ *name* *arglist* *body*

    And alias to the new Class\_Method keyword

  - <a name='52'></a>proc __clay::define::clay__ ?*args*?

  - <a name='53'></a>proc __clay::define::destructor__ *rawbody*

  - <a name='54'></a>proc __clay::define::Dict__ *name* ?*values* ____?

  - <a name='55'></a>proc __clay::define::Option__ *name* ?*args*?

    Define an option for the class

  - <a name='56'></a>proc __clay::define::Method__ *name* *argstyle* *argspec* *body*

  - <a name='57'></a>proc __clay::define::Option\_Class__ *name* ?*args*?

    Define a class of options All field / value pairs will be be inherited by an
    option that specify *name* as it class field\.

  - <a name='58'></a>proc __clay::define::Variable__ *name* ?*default* ____?

    This keyword can also be expressed:

    property variable NAME {default DEFAULT}

    Variables registered in the variable property are also initialized \(if
    missing\) when the object changes class via the *morph* method\.

  - <a name='59'></a>proc __clay::ensemble\_methodbody__ *ensemble* *einfo*

    Produce the body of an ensemble's public dispatch method ensemble is the
    name of the the ensemble\. einfo is a dictionary of methods for the ensemble,
    and each value is a script to execute on dispatch

    Example:

    ::clay::ensemble_methodbody foo {
      bar {tailcall my Foo_bar {*}$args}
      baz {tailcall my Foo_baz {*}$args}
      clock {return [clock seconds]}
      default {puts "You gave me $method"}
    }

  - <a name='60'></a>proc __clay::define::Ensemble__ *rawmethod* ?*args*?

  - <a name='61'></a>proc __clay::event::cancel__ *self* ?*task* __\*__?

    Cancel a scheduled event

  - <a name='62'></a>proc __clay::event::generate__ *self* *event* ?*args*?

    Generate an event Adds a subscription mechanism for objects to see who has
    recieved this event and prevent spamming or infinite recursion

  - <a name='63'></a>proc __clay::event::nextid__

  - <a name='64'></a>proc __clay::event::Notification\_list__ *self* *event* ?*stackvar* ____?

    Called recursively to produce a list of who recieves notifications

  - <a name='65'></a>proc __clay::event::notify__ *rcpt* *sender* *event* *eventinfo*

    Final delivery to intended recipient object

  - <a name='66'></a>proc __clay::event::process__ *self* *handle* *script*

    Evaluate an event script in the global namespace

  - <a name='67'></a>proc __clay::event::schedule__ *self* *handle* *interval* *script*

    Schedule an event to occur later

  - <a name='68'></a>proc __clay::event::subscribe__ *self* *who* *event*

    Subscribe an object to an event pattern

  - <a name='69'></a>proc __clay::event::unsubscribe__ *self* ?*args*?

    Unsubscribe an object from an event pattern

  - <a name='70'></a>proc __clay::singleton__ *name* *script*

    An object which is intended to be it's own class\.

# <a name='section3'></a>Classes

## <a name='subsection4'></a>Class  clay::class

__Methods__

  - <a name='71'></a>method __clay ancestors__

    Return this class and all ancestors in search order\.

  - <a name='72'></a>method __clay dump__

    Return a complete dump of this object's clay data, but only this object's
    clay data\.

  - <a name='73'></a>method __clay find__ *path* ?__path\.\.\.__?

    Pull a chunk of data from the clay system\. If the last element of *path*
    is a branch, returns a recursive merge of all data from this object and it's
    constituent classes of the data in that branch\. If the last element is a
    leaf, search this object for a matching leaf, or search all constituent
    classes for a matching leaf and return the first value found\. If no value is
    found, returns an empty string\. If a branch is returned the topmost \. entry
    is omitted\.

  - <a name='74'></a>method __clay get__ *path* ?__path\.\.\.__?

    Pull a chunk of data from the class's clay system\. If no value is found,
    returns an empty string\. If a branch is returned the topmost \. entry is
    omitted\.

  - <a name='75'></a>method __clay GET__ *path* ?__path\.\.\.__?

    Pull a chunk of data from the class's clay system\. If no value is found,
    returns an empty string\.

  - <a name='76'></a>method __clay merge__ *dict* ?__dict\.\.\.__?

    Recursively merge the dictionaries given into the object's local clay
    storage\.

  - <a name='77'></a>method __clay replace__ *dictionary*

    Replace the contents of the internal clay storage with the dictionary given\.

  - <a name='78'></a>method __clay search__ *path* ?__path\.\.\.__?

    Return the first matching value for the path in either this class's clay
    data or one of its ancestors

  - <a name='79'></a>method __clay set__ *path* ?__path\.\.\.__? *value*

    Merge the conents of __value__ with the object's clay storage at
    __path__\.

## <a name='subsection5'></a>Class  clay::object

clay::object This class is inherited by all classes that have options\.

__Methods__

  - <a name='80'></a>method __clay ancestors__

    Return the class this object belongs to, all classes mixed into this object,
    and all ancestors of those classes in search order\.

  - <a name='81'></a>method __clay cache__ *path* *value*

    Store VALUE in such a way that request in SEARCH for PATH will always return
    it until the cache is flushed

  - <a name='82'></a>method __clay cget__ *field*

    Pull a value from either the object's clay structure or one of its
    constituent classes that matches the field name\. The order of search us:

    1\. The as a value in local dict variable config

    2\. The as a value in local dict variable clay

    3\. As a leaf in any ancestor as a root of the clay tree

    4\. As a leaf in any ancestor as __const__ *field*

    5\. As a leaf in any ancestor as __option__ *field* __default__

  - <a name='83'></a>method __clay delegate__ ?*stub*? ?*object*?

    Introspect or control method delegation\. With no arguments, the method will
    return a key/value list of stubs and objects\. With just the *stub*
    argument, the method will return the object \(if any\) attached to the stub\.
    With a *stub* and an *object* this command will forward all calls to the
    method *stub* to the *object*\.

  - <a name='84'></a>method __clay dump__

    Return a complete dump of this object's clay data, as well as the data from
    all constituent classes recursively blended in\.

  - <a name='85'></a>method __clay ensemble\_map__

    Return a dictionary describing the method ensembles to be assembled for this
    object

  - <a name='86'></a>method __clay eval__ *script*

    Evaluated a script in the namespace of this object

  - <a name='87'></a>method __clay evolve__

    Trigger the __InitializePublic__ private method

  - <a name='88'></a>method __clay exists__ *path* ?__path\.\.\.__?

    Returns 1 if *path* exists in either the object's clay data\. Values
    greater than one indicate the element exists in one of the object's
    constituent classes\. A value of zero indicates the path could not be found\.

  - <a name='89'></a>method __clay flush__

    Wipe any caches built by the clay implementation

  - <a name='90'></a>method __clay forward__ *method* *object*

    A convenience wrapper for

    oo::objdefine [self] forward {*}$args

  - <a name='91'></a>method __clay get__ *path* ?__path\.\.\.__?

    Pull a chunk of data from the clay system\. If the last element of *path*
    is a branch \(ends in a slash /\), returns a recursive merge of all data from
    this object and it's constituent classes of the data in that branch\. If the
    last element is a leaf, search this object for a matching leaf, or search
    all constituent classes for a matching leaf and return the first value
    found\. If no value is found, returns an empty string\.

  - <a name='92'></a>method __clay leaf__ *path* ?__path\.\.\.__?

    A modified get which is tailored to pull only leaf elements

  - <a name='93'></a>method __clay merge__ *dict* ?__dict\.\.\.__?

    Recursively merge the dictionaries given into the object's local clay
    storage\.

  - <a name='94'></a>method __clay mixin__ *class* ?__class\.\.\.__?

    Perform \[oo::objdefine \[self\] mixin\] on this object, with a few additional
    rules: Prior to the call, for any class was previously mixed in, but not in
    the new result, execute the script registered to mixin/ unmap\-script \(if
    given\.\) For all new classes, that were not present prior to this call, after
    the native TclOO mixin is invoked, execute the script registered to mixin/
    map\-script \(if given\.\) Fall all classes that are now present and “mixed in”,
    execute the script registered to mixin/ react\-script \(if given\.\)

  - <a name='95'></a>method __clay mixinmap__ ?*stub*? ?*classes*?

    With no arguments returns the map of stubs and classes mixed into the
    current object\. When only stub is given, returns the classes mixed in on
    that stub\. When stub and classlist given, replace the classes currently on
    that stub with the given classes and invoke clay mixin on the new matrix of
    mixed in classes\.

  - <a name='96'></a>method __clay provenance__ *path* ?__path\.\.\.__?

    Return either __self__ if that path exists in the current object, or
    return the first class \(if any\) along the clay search path which contains
    that element\.

  - <a name='97'></a>method __clay replace__ *dictionary*

    Replace the contents of the internal clay storage with the dictionary given\.

  - <a name='98'></a>method __clay search__ *path* *valuevar* *isleafvar*

    Return true, and set valuevar to the value and isleafar to true for false if
    PATH was found in the cache\.

  - <a name='99'></a>method __clay source__ *filename*

    Source the given filename within the object's namespace

  - <a name='100'></a>method __clay set__ *path* ?__path\.\.\.__? *value*

    Merge the conents of __value__ with the object's clay storage at
    __path__\.

  - <a name='101'></a>method __InitializePublic__

    Instantiate variables\. Called on object creation and during clay mixin\.

# <a name='section4'></a>AUTHORS

Sean Woods

[mailto:<yoda@etoyoc\.com>](mailto:<yoda@etoyoc\.com>)

# <a name='section5'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *oo* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo), [oo](\.\./\.\./\.\./\.\./index\.md\#oo)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2018 Sean Woods <yoda@etoyoc\.com>
