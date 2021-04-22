
[//000000001]: # (switched \- Simple Tcl Only Object Oriented Programming)
[//000000002]: # (Generated from file 'switched\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (switched\(n\) 2\.2\.1 tcllib "Simple Tcl Only Object Oriented Programming")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

switched \- switch/option management\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require switched ?2\.2\.1?  

[__<switched>__ __complete__ *this*](#1)  
[__<switched>__ __options__ *this*](#2)  
[__<switched>__ __set\-__option____ *this* *value*](#3)  

# <a name='description'></a>DESCRIPTION

The __switched__ class serves as base class for user classes with switch /
option configuration procedures\. It provides facilities for managing options
through a simple interface\.

For example:

    set vehicle [new car -length 4.5 -width 2 -power 100 -fuel diesel]
    puts "my car was running on [switched::cget $vehicle -fuel]"
    switched::configure $vehicle -power 40 -fuel electricity
    puts "but is now running on clean [switched::cget $vehicle -fuel]"

Of course, as you might have guessed, the __car__ class is derived from the
__switched__ class\. Let us see how it works:

    class car {
        proc car {this args} switched {$args} {
            # car specific initialization code here
            switched::complete $this
        }
        ...
    }

The switched class constructor takes the optional configuration option / value
pairs as parameters\. The switched class layer then completely manages the
switched options: it checks their validity, stores their values and provides a
clean interface to the user layer configuration setting procedures\.

The switched class members available to the programmer are:

  - <a name='1'></a>__<switched>__ __complete__ *this*

    This procedure is used to tell the switched layer that the derived class
    object \(a car in the examples\) is completely built\. At that time, the
    initial configuration of the switched object occurs, using default option
    values \(see procedure __options__\) eventually overridden by construction
    time values, passed at the time of the __new__ operator invocation\. This
    procedure must be called only once, usually around or at the end of the
    derived class constructor\. \(*Note*: Also check the __complete__ data
    member later in this chapter\)\.

  - <a name='2'></a>__<switched>__ __options__ *this*

    This procedure must return the configuration description for *all* options
    that the switched object will accept\. It is a pure virtual member procedure
    and therefore its implementation is *mandatory* in the derived class
    layer\. The procedure must return a list of lists\. Each list pertains to a
    single option and is composed of the switch name, the default value for the
    option and an optional initial value\. For example:

    class car {
        ...
        proc options {this} {
            return [list [list -fuel petrol petrol] [list -length {} {}] [list -power {} {}] [list -width {} {}] ]
        }
        proc set-fuel {this value} {
            ...
        }
        ...
    }

    In this case, 4 options are specified: __fuel__, __length__,
    __power__ and __width__\. The default and initial values for the
    __fuel__ option are identical and set to __petrol__\. For the other
    options, values are all empty\.

    For each option, there must be a corresponding __set\-__option____
    procedure defined in the derived class layer\. For example, since we defined
    a __fuel__ option, there is a __set\-fuel__ procedure in the car
    class\. The parameters always are the object identifier \(since this is not a
    static procedure, but rather a dynamically defined virtual one\), followed by
    the new value for the option\. A __set\-__option____ procedure is only
    invoked if the new value differs from the current one \(a caching scheme for
    improving performance\), or if there is no initial value set in the
    __options__ procedure for that option\.

    In this procedure, if the initial value differs from the default value or is
    omitted, then initial configuration is forced and the corresponding
    __set\-__option____ procedure is invoked by the switched
    __complete__ procedure located at the end of the derived class
    constructor\. For example:

    class car {
        ...
        proc options {this} {
            return [list [list -fuel petrol] [list -length {} {}] [list -power 100 50] [list -width {} {}] ]
        }
        ...
    }

    In this case, configuration is forced on the __fuel__ and __power__
    options, that is the corresponding __set\-__option____ procedures
    will be invoked when the switched object is constructed \(see
    __set\-__option____ procedures documentation below\)\.

    For the __fuel__ option, since there is no initial value, the
    __set\-__fuel____ procedure is called with the default value
    \(__petrol__\) as argument\. For the __power__ option, since the
    initial value differs from the default value, the __set\-__power____
    procedure is called with the initial value as argument \(__50__\)\.

    For the other options, since the initial values \(last elements of the option
    lists\) are identical to their default values, the corresponding
    __set\-__option____ procedures will not be invoked\. It is the
    programmer's responsibility to insure that the initial option values are
    correct\.

  - <a name='3'></a>__<switched>__ __set\-__option____ *this* *value*

    These procedures may be viewed as dynamic virtual functions\. There must be
    one implementation per supported option, as returned by the __options__
    procedure\. For example:

    class car {
        ...
        proc options {this} {
            return [list ...
                [list -width {} {}] ]
        }
        ...
        proc set-width {this value} {
            ...
        }
        ...
    }

    Since the __\-width__ option was listed in the __options__ procedure,
    a __set\-width__ procedure implementation is provided, which of course
    would proceed to set the width of the car \(and would modify the looks of a
    graphical representation, for example\)\.

    As you add a supported __option__ in the list returned by the
    __options__ procedure, the corresponding __set\-__option____
    procedure may be called as soon as the switched object is complete, which
    occurs when the switched level __complete__ procedure is invoked\. For
    example:

    class car {
        proc car {this args} switched {args} {
            ...
            switched::complete $this
       }
        ...
        proc options {this} {
            return [list [list -fuel petrol] [list -length 4.5] [list -power 350] [list -width 1.8] ]
        }
        proc set-fuel {this value} {
            ...
        }
        proc set-length {this value} {
            ...
        }
        proc set-power {this value} {
            ...
        }
        proc set-width {this value} {
            ...
        }
    }

    new car

    In this case, a new car is created with no options, which causes the car
    constructor to be called, which in turns calls the switched level
    __complete__ procedure after the car object layer is completely
    initialized\. At this point, since there are no initial values in any option
    list in the options procedure, the __set\-fuel__ procedure is called with
    its default value of __petrol__ as parameter, followed by the
    __set\-length__ call with __4\.5__ value, __set\-power__ with
    __350__ value and finally with __set\-width__ with __1\.8__ as
    parameter\. This is a good way to test the __set\-__option____
    procedures when debugging, and when done, just fill\-in the initial option
    values\.

    The switched layer checks that an option is valid \(that is, listed in the
    __options__ procedure\) but obviously does not check the validity of the
    value passed to the __set\-__option____ procedure, which should throw
    an error \(for example by using the Tcl error command\) if the value is
    invalid\.

    The switched layer also keeps track of the options current values, so that a
    __set\-__option____ procedure is called only when the corresponding
    option value passed as parameter is different from the current value \(see
    __\-option__ data members description\)\.

  - __\-option__

    The __\-option__ data member is an options current value\. There is one
    for each option listed in the options procedure\. It is a read\-only value
    which the switched layer checks against when an option is changed\. It is
    rarely used at the layer derived from switched, except in the few cases,
    such as in the following example:

    ...
    proc car::options {this} {
        return {
            ...
            {-manufacturer {} {}}
            ...
        }
    }

    proc car::set-manufacturer {this value} {}

    proc car::printData {this} {
        puts "manufacturer: $switched::($this,-manufacturer)"
        ...
    }

    In this case, the manufacturer's name is stored at the switched layer level
    \(this is why the set\-manufacturer procedure has nothing to do\) and later
    retrieved in the printData procedure\.

  - __complete__

    The __complete__ data member \(not to be confused with the
    __complete__ procedure\) is a boolean\. Its initial value is __false__
    and it is set to __true__ at the very end of the switched
    __complete__ procedure\. It becomes useful when some options should be
    set at construction time only and not dynamically, as the following example
    shows:

    proc car::set-width {this value} {
        if {$switched::($this,complete)} {
            error {option -width cannot be set dynamically}
        }
        ...
    }

# <a name='section2'></a>Bugs, Ideas, Feedback

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
