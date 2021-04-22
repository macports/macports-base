
[//000000001]: # (struct::pool \- Tcl Data Structures)
[//000000002]: # (Generated from file 'pool\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Erik Leunissen <e\.leunissen@hccnet\.nl>)
[//000000004]: # (struct::pool\(n\) 1\.2\.3 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

struct::pool \- Create and manipulate pool objects \(of discrete items\)

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [POOLS AND ALLOCATION](#section2)

  - [ITEMS](#section3)

  - [POOL OBJECT COMMAND](#section4)

  - [EXAMPLES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require struct::pool ?1\.2\.3?  

[__::struct::pool__ ?*poolName*? ?*maxsize*?](#1)  
[__poolName__ *option* ?*arg arg \.\.\.*?](#2)  
[*poolName* __add__ *itemName1* ?*itemName2 itemName3 \.\.\.*?](#3)  
[*poolName* __clear__ ?__\-force__?](#4)  
[*poolName* __destroy__ ?__\-force__?](#5)  
[*poolName* __info__ *type* ?*arg*?](#6)  
[*poolName* __maxsize__ ?*maxsize*?](#7)  
[*poolName* __release__ *itemName*](#8)  
[*poolName* __remove__ *itemName* ?__\-force__?](#9)  
[*poolName* __request__ itemVar ?options?](#10)  

# <a name='description'></a>DESCRIPTION

This package provides pool objects which can be used to manage finite
collections of discrete items\.

  - <a name='1'></a>__::struct::pool__ ?*poolName*? ?*maxsize*?

    Creates a new pool object\. If no *poolName* is supplied, then the new pool
    will be named pool__X__, where X is a positive integer\. The optional
    second argument *maxsize* has to be a positive integer indicating the
    maximum size of the pool; this is the maximum number of items the pool may
    hold\. The default for this value is __10__\.

    The pool object has an associated global Tcl command whose name is
    *poolName*\. This command may be used to invoke various configuration
    operations on the report\. It has the following general form:

      * <a name='2'></a>__poolName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.
        See section [POOL OBJECT COMMAND](#section4) for a detailed list of
        options and their behaviour\.

# <a name='section2'></a>POOLS AND ALLOCATION

The purpose of the pool command and the pool object command that it generates,
is to manage pools of discrete items\. Examples of a pool of discrete items are:

  - the seats in a cinema, theatre, train etc\.\. for which visitors/travelers can
    make a reservation;

  - the dynamic IP\-addresses that an ISP can dole out to subscribers;

  - a car rental's collection of cars, which can be rented by customers;

  - the class rooms in a school building, which need to be scheduled;

  - the database connections available to client\-threads in a web\-server
    application;

  - the books in a library that customers can borrow;

  - etc \.\.\.

The common denominator in the examples is that there is a more or less fixed
number of items \(seats, IP\-addresses, cars, \.\.\.\) that are supposed to be
allocated on a more or less regular basis\. An item can be allocated only once at
a time\. An item that is allocated, must be released before it can be
re\-allocated\. While several items in a pool are being allocated and released
continuously, the total number of items in the pool remains constant\.

Keeping track of which items are allocated, and by whom, is the purpose of the
pool command and its subordinates\.

*Pool parlance*: If we say that an item is *allocated*, it means that the
item is *busy*, *owned* or *occupied*; it is not available anymore\. If an
item is *free*, it is *available*\. Deallocating an item is equivalent to
setting free or releasing an item\. The person or entity to which the item has
been allotted is said to own the item\.

# <a name='section3'></a>ITEMS

*Discrete items*

The __[pool](\.\./\.\./\.\./\.\./index\.md\#pool)__ command is designed for
*discrete items only*\. Note that there are pools where allocation occurs on a
non\-discrete basis, for example computer memory\. There are also pools from which
the shares that are doled out are not expected to be returned, for example a
charity fund or a pan of soup from which you may receive a portion\. Finally,
there are even pools from which nothing is ever allocated or returned, like a
swimming pool or a cesspool\.

*Unique item names*

A pool cannot manage duplicate item names\. Therefore, items in a pool must have
unique names\.

*Item equivalence*

From the point of view of the manager of a pool, items are equivalent\. The
manager of a pool is indifferent about which entity/person occupies a given
item\. However, clients may have preferences for a particular item, based on some
item property they know\.

*Preferences*

A future owner may have a preference for a particular item\. Preference based
allocation is supported \(see the __\-prefer__ option to the request
subcommand\)\. A preference for a particular item is most likely to result from
variability among features associated with the items\. Note that the pool
commands themselves are not designed to manage such item properties\. If item
properties play a role in an application, they should be managed separately\.

# <a name='section4'></a>POOL OBJECT COMMAND

The following subcommands and corresponding arguments are available to any pool
object command\.

  - <a name='3'></a>*poolName* __add__ *itemName1* ?*itemName2 itemName3 \.\.\.*?

    This command adds the items on the command line to the pool\. If duplicate
    item names occur on the command line, an error is raised\. If one or more of
    the items already exist in the pool, this also is considered an error\.

  - <a name='4'></a>*poolName* __clear__ ?__\-force__?

    Removes all items from the pool\. If there are any allocated items at the
    time when the command is invoked, an error is raised\. This behaviour may be
    modified through the __\-force__ argument\. If it is supplied on the
    command line, the pool will be cleared regardless the allocation state of
    its items\.

  - <a name='5'></a>*poolName* __destroy__ ?__\-force__?

    Destroys the pool data structure, all associated variables and the
    associated pool object command\. By default, the command checks whether any
    items are still allocated and raises an error if such is the case\. This
    behaviour may be modified through the argument __\-force__\. If it is
    supplied on the command line, the pool data structure will be destroyed
    regardless allocation state of its items\.

  - <a name='6'></a>*poolName* __info__ *type* ?*arg*?

    Returns various information about the pool for further programmatic use\. The
    *type* argument indicates the type of information requested\. Only the type
    __allocID__ uses an additional argument\.

      * __allocID__ *itemName*

        returns the allocID of the item whose name is *itemName*\. Free items
        have an allocation id of __\-1__\.

      * __allitems__

        returns a list of all items in the pool\.

      * __allocstate__

        Returns a list of key\-value pairs, where the keys are the items and the
        values are the corresponding allocation id's\. Free items have an
        allocation id of __\-1__\.

      * __cursize__

        returns the current pool size, i\.e\. the number of items in the pool\.

      * __freeitems__

        returns a list of items that currently are not allocated\.

      * __maxsize__

        returns the maximum size of the pool\.

  - <a name='7'></a>*poolName* __maxsize__ ?*maxsize*?

    Sets or queries the maximum size of the pool, depending on whether the
    *maxsize* argument is supplied or not\. If *maxsize* is supplied, the
    maximum size of the pool will be set to that value\. If no argument is
    supplied, the current maximum size of the pool is returned\. In this variant,
    the command is an alias for:

    __poolName info maxsize__\.

    The *maxsize* argument has to be a positive integer\.

  - <a name='8'></a>*poolName* __release__ *itemName*

    Releases the item whose name is *itemName* that was allocated previously\.
    An error is raised if the item was not allocated at the time when the
    command was issued\.

  - <a name='9'></a>*poolName* __remove__ *itemName* ?__\-force__?

    Removes the item whose name is *itemName* from the pool\. If the item was
    allocated at the time when the command was invoked, an error is raised\. This
    behaviour may be modified through the optional argument __\-force__\. If
    it is supplied on the command line, the item will be removed regardless its
    allocation state\.

  - <a name='10'></a>*poolName* __request__ itemVar ?options?

    Handles a request for an item, taking into account a possible preference for
    a particular item\. There are two possible outcomes depending on the
    availability of items:

      1. The request is honoured, an item is allocated and the variable whose
         name is passed with the argument *itemVar* will be set to the name of
         the item that was allocated\. The command returns 1\.

      1. The request is denied\. No item is allocated\. The variable whose name is
         itemVar is not set\. Attempts to read *itemVar* may raise an error if
         the variable was not defined before issuing the request\. The command
         returns 0\.

    The return values from this command are meant to be inspected\. The examples
    below show how to do this\. Failure to check the return value may result in
    erroneous behaviour\. If no preference for a particular item is supplied
    through the option __\-prefer__ \(see below\), then all requests are
    honoured as long as items are available\.

    The following options are supported:

      * __\-allocID__ *allocID*

        If the request is honoured, an item will be allocated to the entity
        identified by allocID\. If the allocation state of an item is queried, it
        is this allocation ID that will be returned\. If the option
        __\-allocID__ is not supplied, the item will be given to and owned by
        __dummyID__\. Allocation id's may be anything except the value \-1,
        which is reserved for free items\.

      * __\-prefer__ *preferredItem*

        This option modifies the allocation strategy as follows: If the item
        whose name is *preferredItem* is not allocated at the time when the
        command is invoked, the request is honoured \(return value is 1\)\. If the
        item was allocated at the time when the command was invoked, the request
        is denied \(return value is 0\)\.

# <a name='section5'></a>EXAMPLES

Two examples are provided\. The first one mimics a step by step interactive tclsh
session, where each step is explained\. The second example shows the usage in a
server application that talks to a back\-end application\.

*Example 1*

This example presents an interactive tclsh session which considers the case of a
Car rental's collection of cars\. Ten steps explain its usage in chronological
order, from the creation of the pool, via the most important stages in the usage
of a pool, to the final destruction\.

*Note aside:*

In this example, brand names are used to label the various items\. However, a
brand name could be regarded as a property of an item\. Because the pool command
is not designed to manage properties of items, they need to be managed
separately\. In the latter case the items should be labeled with more neutral
names such as: car1, car2, car3 , etc \.\.\. and a separate database or array
should hold the brand names associated with the car labels\.

    1. Load the package into an interpreter
    % package require pool
    0.1

    2. Create a pool object called `CarPool' with a maximum size of 55 items (cars):
    % pool CarPool 55
    CarPool

    4. Add items to the pool:
    % CarPool add Toyota Trabant Chrysler1 Chrysler2 Volkswagen

    5. Somebody crashed the Toyota. Remove it from the pool as follows:
    % CarPool remove Toyota

    6. Acquired a new car for the pool. Add it as follows:
    % CarPool add Nissan

    7. Check whether the pool was adjusted correctly:
    % CarPool info allitems
    Trabant Chrysler1 Chrysler2 Volkswagen Nissan

Suspend the interactive session temporarily, and show the programmatic use of
the request subcommand:

    # Mrs. Swift needs a car. She doesn't have a preference for a
    # particular car. We'll issue a request on her behalf as follows:
    if { [CarPool request car -allocID "Mrs. Swift"] }  {
        # request was honoured, process the variable `car'
        puts "$car has been allocated to [CarPool info allocID $car]."
    } else {
        # request was denied
         puts "No car available."
    }

Note how the __if__ command uses the value returned by the __request__
subcommand\.

    # Suppose Mr. Wiggly has a preference for the Trabant:
    if { [CarPool request car -allocID "Mr. Wiggly" -prefer Trabant] }  {
        # request was honoured, process the variable `car'
        puts "$car has been allocated to [CarPool info allocID $car]."
    } else {
        # request was denied
         puts "The Trabant was not available."
    }

Resume the interactive session:

    8. When the car is returned then you can render it available by:
    % CarPool release Trabant

    9. When done, you delete the pool.
    % CarPool destroy
    Couldn't destroy `CarPool' because some items are still allocated.

    Oops, forgot that Mrs. Swift still occupies a car.

    10. We force the destruction of the pool as follows:
    % CarPool destroy -force

*Example 2*

This example describes the case from which the author's need for pool management
originated\. It is an example of a server application that receives requests from
client applications\. The client requests are dispatched onto a back\-end
application before being returned to the client application\. In many cases there
are a few equivalent instances of back\-end applications to which a client
request may be passed along\. The file descriptors that identify the channels to
these back\-end instances make up a pool of connections\. A particular connection
may be allocated to just one client request at a time\.

    # Create the pool of connections (pipes)
    set maxpipes 10
    pool Pipes $maxpipes
    for {set i 0} {$i < $maxpipes} {incr i} {
        set fd [open "|backendApplication" w+]
        Pipes add $fd
    }

    # A client request comes in. The request is identified as `clientX'.
    # Dispatch it onto an instance of a back-end application
    if { [Pipes request fd -allocID clientX] } {
        # a connection was allocated
        # communicate to the back-end application via the variable `fd'
        puts $fd "someInstruction"
        # ...... etc.
    } else {
        # all connections are currently occupied
        # store the client request in a queue for later processing,
        # or return a 'Server busy' message to the client.
    }

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *struct :: pool* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[discrete items](\.\./\.\./\.\./\.\./index\.md\#discrete\_items),
[finite](\.\./\.\./\.\./\.\./index\.md\#finite),
[pool](\.\./\.\./\.\./\.\./index\.md\#pool), [struct](\.\./\.\./\.\./\.\./index\.md\#struct)

# <a name='category'></a>CATEGORY

Data structures

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Erik Leunissen <e\.leunissen@hccnet\.nl>
