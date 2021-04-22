
[//000000001]: # (tie \- Tcl Data Structures)
[//000000002]: # (Generated from file 'tie\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2021 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (tie\(n\) 1\.2 tcllib "Tcl Data Structures")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

tie \- Array persistence

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [USING TIES](#section2)

      - [TIE API](#subsection1)

      - [STANDARD DATA SOURCE TYPES](#subsection2)

  - [CREATING NEW DATA SOURCES](#section3)

      - [DATA SOURCE OBJECTS](#subsection3)

      - [REGISTERING A NEW DATA SOURCE CLASS](#subsection4)

      - [DATA SOURCE CLASS](#subsection5)

      - [DATA SOURCE OBJECT API](#subsection6)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require tie ?1\.2?  

[__::tie::tie__ *arrayvarname* *options*\.\.\. *dstype* *dsname*\.\.\.](#1)  
[__::tie::untie__ *arrayvarname* ?*token*?](#2)  
[__::tie::info__ __ties__ *arrayvarname*](#3)  
[__::tie::info__ __types__](#4)  
[__::tie::info__ __type__ *dstype*](#5)  
[__::tie::register__ *dsclasscmd* __as__ *dstype*](#6)  
[__dsclasscmd__ *objname* ?*dsname*\.\.\.?](#7)  
[__ds__ __destroy__](#8)  
[__ds__ __names__](#9)  
[__ds__ __size__](#10)  
[__ds__ __get__](#11)  
[__ds__ __set__ *dict*](#12)  
[__ds__ __unset__ ?*pattern*?](#13)  
[__ds__ __setv__ *index* *value*](#14)  
[__ds__ __unsetv__ *index*](#15)  
[__ds__ __getv__ *index*](#16)  

# <a name='description'></a>DESCRIPTION

The __tie__ package provides a framework for the creation of persistent Tcl
array variables\. It should be noted that the provided mechanism is generic
enough to also allow its usage for the distribution of the contents of Tcl
arrays over multiple threads and processes, i\.e\. communication\.

This, persistence and communication, is accomplished by *tying*\) a Tcl array
variable to a *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\. Examples
of data sources are other Tcl arrays and files\.

It should be noted that a single Tcl array variable can be tied to more than one
*[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\. It is this feature
which allows the framework to be used for communication as well\. Just tie
several Tcl arrays in many client processes to a Tcl array in a server and all
changes to any of them will be distributed to all\. Less centralized variants of
this are of course possible as well\.

# <a name='section2'></a>USING TIES

## <a name='subsection1'></a>TIE API

This section describes the basic API used to establish and remove ties between
Tcl array variables and data sources\. This interface is the only one a casual
user has to be concerned about\. The following sections about the various
internal interfaces can be safely skipped\.

  - <a name='1'></a>__::tie::tie__ *arrayvarname* *options*\.\.\. *dstype* *dsname*\.\.\.

    This command establishes a tie between the Tcl array whose name is provided
    by the argument *arrayvarname* and the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* identified by the *dstype*
    and its series of *dsname* arguments\. All changes made to the Tcl array
    after this command returns will be saved to the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* for safekeeping \(or
    distribution\)\.

    The result of the command is always a token which identifies the new tie\.
    This token can be used later to destroy this specific tie\.

      * varname *arrayvarname* \(in\)

        The name of the Tcl array variable to connect the new tie to\.

      * name&#124;command *dstype* \(in\)

        This argument specifies the type of the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* we wish to access\. The
        *dstype* can be one of __log__, __array__,
        __remotearray__, __file__, __growfile__, or __dsource__;
        in addition, the programmer can register additional data source types\.
        Each *dstype* is followed by one or more arguments that identify the
        *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* to which the
        array is to be tied\.

      * string *dsname* \(in\)

        The series of *dsname* arguments coming after the *dstype*
        identifies the *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*
        we wish to connect to, and has to be appropriate for the chosen type\.

    The command understands a number of additional options which guide the
    process of setting up the connection between Tcl array and *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\.

      * __\-open__

        The Tcl array for the new tie is *loaded* from the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*, and the previously
        existing contents of the Tcl array are erased\. Care is taken to *not*
        erase the previous contents should the creation of the tie fail\.

        This option and the option __\-save__ exclude each other\. If neither
        this nor option __\-save__ are specified then this option is assumed
        as default\.

      * __\-save__

        The Tcl array for the new tie is *saved* to the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*, and the previously
        existing contents of the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* are erased\.

        This option and the option __\-open__ exclude each other\. If neither
        this nor option __\-open__ are specified then option __\-open__ is
        assumed as default\.

      * __\-merge__

        Using this option prevents the erasure of any previously existing
        content and merges the data instead\. It can be specified in conjunction
        with either __\-open__ or __\-save__\. They determine how data
        existing in both Tcl array and *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*, i\.e duplicates, are
        dealt with\.

        When used with __\-open__ data in the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* has precedence\. In other
        words, for duplicates the data in the *[data
        source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* is loaded into the Tcl
        array\.

        When used with __\-save__ data in the Tcl array has precedence\. In
        other words, for duplicates the data in the Tcl array is saved into the
        *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\.

  - <a name='2'></a>__::tie::untie__ *arrayvarname* ?*token*?

    This command dissolves one or more ties associated with the Tcl array named
    by *arrayvarname*\. If no *token* is specified then all ties to that Tcl
    array are dissolved\. Otherwise only the tie the token stands for is removed,
    if it is actually connected to the array\. Trying to remove a specific tie
    not belonging to the provided array will cause an error\.

    It should be noted that while severing a tie will destroy management
    information internal to the package the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* which was handled by the tie
    will not be touched, only closed\.

    After the command returns none of changes made to the array will be saved to
    the *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* anymore\.

    The result of the command is an empty string\.

      * varname *arrayname* \(in\)

        The name of a Tcl array variable which may have ties\.

      * handle *token* \(in\)

        A handle representing a specific tie\. This argument is optional\.

  - <a name='3'></a>__::tie::info__ __ties__ *arrayvarname*

    This command returns a list of ties associated with the Tcl array variable
    named by *arrayvarname*\. The result list will be empty if the variable has
    no ties associated with it\.

  - <a name='4'></a>__::tie::info__ __types__

    This command returns a dictionary of registered types, and the class
    commands they are associated with\.

  - <a name='5'></a>__::tie::info__ __type__ *dstype*

    This command returns the fully resolved class command for a type name\. This
    means that the command will follow a chain of type definitions ot its end\.

## <a name='subsection2'></a>STANDARD DATA SOURCE TYPES

This package provides the six following types as examples and standard data
sources\.

  - __log__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* does not
    maintain any actual data, nor persistence\. It does not accept any
    identifying arguments\. All changes are simply logged to __stdout__\.

  - __array__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* uses a regular
    Tcl array as the origin of the persistent data\. It accepts a single
    identifying argument, the name of this Tcl array\. All changes are mirrored
    to that array\.

  - __remotearray__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* is similar to
    __array__\. The difference is that the Tcl array to which we are
    mirroring is not directly accessible, but through a
    __[send](\.\./\.\./\.\./\.\./index\.md\#send)__\-like command\.

    It accepts three identifying arguments, the name of the other Tcl array, the
    command prefix for the __[send](\.\./\.\./\.\./\.\./index\.md\#send)__\-like
    accessor command, and an identifier for the remote entity hosting the array,
    in this order\. All changes are mirrored to that array, via the command
    prefix\. All commands will be executed in the context of the global
    namespace\.

    __[send](\.\./\.\./\.\./\.\./index\.md\#send)__\-like means that the command
    prefix has to have __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ syntax and
    semantics\. I\.e\. it is a channel over which we can send arbitrary commands to
    some other entity\. The remote array *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* however uses only the
    commands __[set](\.\./\.\./\.\./\.\./index\.md\#set)__, __unset__,
    __array exists__, __array names__, __array set__, and __array
    get__ to retrieve and set values in the remote array\.

    The command prefix and the entity id are separate to allow the data source
    to use options like __\-async__ when assembling the actual commands\.

    Examples of command prefixes, listed with the id of the remote entity,
    without options\. In reality only the part before the id is the command
    prefix:

      * __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ *tkname*

        The Tcl array is in a remote interpreter and is accessed via Tk's X
        communication\.

      * __comm::comm send__ *hostportid*

        The Tcl array is in a remote interpreter and is accessed through a
        socket\.

      * __thread::send__ *threadid*

        The Tcl array is in a remote interpreter in a different thread of this
        process\.

  - __file__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* uses a single
    file as origin of the persistent data\. It accepts a single identifying
    argument, the path to this file\. The file has to be both readable and
    writable\. It may not exist, the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* will create it in that case\.
    This \(and only this\) situation will require that the directory for the file
    exists and is writable as well\.

    All changes are saved in the file, as proper Tcl commands, one command per
    operation\. In other words, the file will always contain a proper Tcl script\.

    If the file exists when the tie using it is set up, then it will be
    compacted, i\.e\. superfluous operations are removed, if the operations log
    stored in it contains either at least one operation clearing the whole
    array, or at least 1\.5 times more operations than entries in the loaded
    array\.

  - __growfile__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* is like
    __file__ in terms of the storage medium for the array data, and how it
    is configured\. In constrast to the former it however assumes and ensures
    that the tied array will never shrink\. I\.e\. the creation of new array
    entries, and the modification of existing entries is allowed, but the
    deletion of entries is not, and causes the data source to throw errors\.

    This restriction allows us to simplify both file format and access to the
    file radically\. For one, the file is read only once and the internal cache
    cannot be invalidated\. Second, writing data is reduced to a simple append,
    and no compaction step is necessary\. The format of the contents is the
    string representation of a dictionary which can be incrementally extended
    forever at the end\.

  - __dsource__

    This *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* uses an
    explicitly specified *data source object* as the source for the persistent
    data\. It accepts a single identifying argument, the command prefix, i\.e\.
    object command\.

    To use this type it is necessary to know how the framework manages ties and
    what [data source objects](#subsection3) are\.

    All changes are delegated to the specified object\.

# <a name='section3'></a>CREATING NEW DATA SOURCES

This section is of no interest to the casual user of ties\. Only developers
wishing to create new data sources have to know the information provided herein\.

## <a name='subsection3'></a>DATA SOURCE OBJECTS

All ties are represented internally by an in\-memory object which mediates
between the tie framework and the specific *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*, like an array, file, etc\. This
is the *data source object*\.

Its class, the [data source class](#subsection5) is *not* generic, but
specific to the type of the *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\. Writing a new *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* requires us to write such a
class, and then registering it with the framework as a new type\.

The following subsections describe the various APIs a [data source
class](#subsection5) and the objects it generates will have to follow to be
compatible with the tie framework\.

Data source objects are normally automatically created and destroyed by the
framework when a tie is created, or removed\. This management can be explicitly
bypassed through the usage of the "dsource" type\. The *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* for this type is a *data source
object* itself, and this object is outside of the scope of the tie framework
and not managed by it\. In other words, this type allows the creation of ties
which talk to pre\-existing *data source object*s, and these objects will
survive the removal of the ties using them as well\.

## <a name='subsection4'></a>REGISTERING A NEW DATA SOURCE CLASS

After a [data source class](#subsection5) has been written it is necessary
to register it as a new type with the framework\.

  - <a name='6'></a>__::tie::register__ *dsclasscmd* __as__ *dstype*

    Using this command causes the tie framework to remember the class command
    *dsclasscmd* of a [data source class](#subsection5) under the type
    name *dstype*\.

    After the call the argument *dstype* of the basic user command
    __::tie::tie__ will accept *dstype* as a type name and translate it
    internally to the appropriate class command for the creation of [data
    source objects](#subsection3) for the new *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\.

## <a name='subsection5'></a>DATA SOURCE CLASS

Each data source class is represented by a single command, also called the
*class command*, or *object creation command*\. Its syntax is

  - <a name='7'></a>__dsclasscmd__ *objname* ?*dsname*\.\.\.?

    The first argument of the class command is the name of the *data source
    object* to create\. The framework itself will always supply the string
    __%AUTO%__, to signal that the class command has to generate not only
    the object, but the object name as well\.

    This is followed by a series of arguments identifying the data source the
    new object is for\. These are the same *dsname* arguments which are given
    to the basic user command __::tie::tie__\. Their actual meaning is
    dependent on the *data source class*\.

    The result of the class command has to be the fully\-qualified name of the
    new *data source object*, i\.e\. the name of the *object command*\. The
    interface this command has to follow is described in the section [DATA
    SOURCE OBJECT API](#subsection6)

## <a name='subsection6'></a>DATA SOURCE OBJECT API

Please read the section [DATA SOURCE CLASS](#subsection5) first, to know
how to generate new *object commands*\.

Each *object command* for a *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* object has to provide at least
the methods listed below for proper inter\-operation with the tie framework\. Note
that the names of most of the methods match the subcommands of the builtin
__[array](\.\./\.\./\.\./\.\./index\.md\#array)__ command\.

  - <a name='8'></a>__ds__ __destroy__

    This method is called when the object __ds__ is destroyed\. It now has to
    release all its internal resources associated with the external data source\.

  - <a name='9'></a>__ds__ __names__

    This command has to return a list containing the names of all keys found in
    the *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the object talks
    to\. This is equivalent to __array names__\.

  - <a name='10'></a>__ds__ __size__

    This command has to return an integer number specifying the number of keys
    found in the *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the
    object talks to\. This is equivalent to __array size__\.

  - <a name='11'></a>__ds__ __get__

    This command has to return a dictionary containing the data found in the
    *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the object talks to\.
    This is equivalent to __array get__\.

  - <a name='12'></a>__ds__ __set__ *dict*

    This command takes a dictionary and adds its contents to the data source the
    object talks to\. This is equivalent to __array set__\.

  - <a name='13'></a>__ds__ __unset__ ?*pattern*?

    This command takes a pattern and removes all elements whose keys matching it
    from the *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)*\. If no
    pattern is specified it defaults to __\*__, causing the removal of all
    elements\. This is nearly equivalent to __array unset__\.

  - <a name='14'></a>__ds__ __setv__ *index* *value*

    This command has to save the *value* in the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the object talks to, under
    the key *index*\.

    The result of the command is ignored\. If an error is thrown then this error
    will show up as error of the set operation which caused the method call\.

  - <a name='15'></a>__ds__ __unsetv__ *index*

    This command has to remove the value under the key *index* from the
    *[data source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the object talks to\.

    The result of the command is ignored\. If an error is thrown then this error
    will show up as error of the unset operation which caused the method call\.

  - <a name='16'></a>__ds__ __getv__ *index*

    This command has to return the value for the key *index* in the *[data
    source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* the object talks to\.

And here a small table comparing the *[data
source](\.\./\.\./\.\./\.\./index\.md\#data\_source)* methods to the regular Tcl
commands for accessing an array\.

    Regular Tcl             Data source
    -----------             -----------
    array names a           ds names
    array size  a           ds size
    array get   a           ds get
    array set   a dict      ds set   dict
    array unset a pattern   ds unset ?pattern?
    -----------             -----------
    set a($idx) $val        ds setv   idx val
    unset a($idx)           ds unsetv idx
    $a($idx)                ds getv   idx
    -----------             -----------

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *tie* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[array](\.\./\.\./\.\./\.\./index\.md\#array),
[database](\.\./\.\./\.\./\.\./index\.md\#database),
[file](\.\./\.\./\.\./\.\./index\.md\#file),
[metakit](\.\./\.\./\.\./\.\./index\.md\#metakit),
[persistence](\.\./\.\./\.\./\.\./index\.md\#persistence),
[tie](\.\./\.\./\.\./\.\./index\.md\#tie), [untie](\.\./\.\./\.\./\.\./index\.md\#untie)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004\-2021 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
