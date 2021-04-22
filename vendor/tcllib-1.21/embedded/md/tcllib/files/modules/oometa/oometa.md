
[//000000001]: # (oometa \- Data registry for TclOO frameworks)
[//000000002]: # (Generated from file 'oometa\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (oometa\(n\) 0\.7\.1 tcllib "Data registry for TclOO frameworks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

oometa \- oo::meta A data registry for classess

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Usage](#section2)

  - [Concept](#section3)

  - [COMMANDS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__oo::meta::info__](#1)  
[__oo::meta::info branchget__ ?*key*? ?\.\.\.?](#2)  
[__oo::meta::info branchset__ ?*key\.\.\.*? *key* *value*](#3)  
[__oo::meta::info dump__ *class*](#4)  
[__oo::meta::info__ *class* __is__ *type* ?*args*?](#5)  
[__oo::meta::info__ *class* __[merge](\.\./\.\./\.\./\.\./index\.md\#merge)__ ?*dict*? ?*dict*? ?*\.\.\.*?](#6)  
[__oo::meta::info__ *class* __rebuild__](#7)  
[__oo::meta::metadata__ *class*](#8)  
[__oo::define meta__](#9)  
[__oo::class method meta__](#10)  
[__oo::object method meta__](#11)  
[__oo::object method meta cget__ ?*field*? ?*\.\.\.*? *field*](#12)  

# <a name='description'></a>DESCRIPTION

The __oo::meta__ package provides a data registry service for TclOO classes\.

# <a name='section2'></a>Usage

    oo::class create animal {
      meta set biodata animal: 1
    }
    oo::class create mammal {
      superclass animal
      meta set biodata mammal: 1
    }
    oo::class create cat {
      superclass mammal
      meta set biodata diet: carnivore
    }

    cat create felix
    puts [felix meta dump biodata]
    > animal: 1 mammal: 1 diet: carnivore

    felix meta set biodata likes: {birds mice}
    puts [felix meta get biodata]
    > animal: 1 mammal: 1 diet: carnivore likes: {bird mice}

    # Modify a class
    mammal meta set biodata metabolism: warm-blooded
    puts [felix meta get biodata]
    > animal: 1 mammal: 1 metabolism: warm-blooded diet: carnivore likes: {birds mice}

    # Overwrite class info
    felix meta set biodata mammal: yes
    puts [felix meta get biodata]
    > animal: 1 mammal: yes metabolism: warm-blooded diet: carnivore likes: {birds mice}

# <a name='section3'></a>Concept

The concept behind __oo::meta__ is that each class contributes a snippet of
*local* data\. When __oo::meta::metadata__ is called, the system walks
through the linear ancestry produced by __oo::meta::ancestors__, and
recursively combines all of that local data for all of a class' ancestors into a
single dict\. Instances of oo::object can also combine class data with a local
dict stored in the *meta* variable\.

# <a name='section4'></a>COMMANDS

  - <a name='1'></a>__oo::meta::info__

    __oo::meta::info__ is intended to work on the metadata of a class in a
    manner similar to if the aggregate pieces where assembled into a single
    dict\. The system mimics all of the standard dict commands, and addes the
    following:

  - <a name='2'></a>__oo::meta::info branchget__ ?*key*? ?\.\.\.?

    Returns a dict representation of the element at *args*, but with any
    trailing : removed from field names\.

    ::oo::meta::info $myclass set option color {default: green widget: colorselect}
    puts [::oo::meta::info $myclass get option color]
    > {default: green widget: color}
    puts [::oo::meta::info $myclass branchget option color]
    > {default green widget color}

  - <a name='3'></a>__oo::meta::info branchset__ ?*key\.\.\.*? *key* *value*

    Merges *dict* with any other information contaned at node ?*key\.\.\.*?,
    and adding a trailing : to all field names\.

    ::oo::meta::info $myclass branchset option color {default green widget colorselect}
    puts [::oo::meta::info $myclass get option color]
    > {default: green widget: color}

  - <a name='4'></a>__oo::meta::info dump__ *class*

    Returns the complete snapshot of a class metadata, as producted by
    __oo::meta::metadata__

  - <a name='5'></a>__oo::meta::info__ *class* __is__ *type* ?*args*?

    Returns a boolean true or false if the element ?*args*? would match
    __string is__ *type* *value*

    ::oo::meta::info $myclass set constant mammal 1
    puts [::oo::meta::info $myclass is true constant mammal]
    > 1

  - <a name='6'></a>__oo::meta::info__ *class* __[merge](\.\./\.\./\.\./\.\./index\.md\#merge)__ ?*dict*? ?*dict*? ?*\.\.\.*?

    Combines all of the arguments into a single dict, which is then stored as
    the new local representation for this class\.

  - <a name='7'></a>__oo::meta::info__ *class* __rebuild__

    Forces the meta system to destroy any cached representation of a class'
    metadata before the next access to __oo::meta::metadata__

  - <a name='8'></a>__oo::meta::metadata__ *class*

    Returns an aggregate picture of the metadata for *class*, combining its
    *local* data with the *local* data from its ancestors\.

  - <a name='9'></a>__oo::define meta__

    The package injects a command __oo::define::meta__ which works to
    provide a class in the process of definition access to
    __oo::meta::info__, but without having to look the name up\.

    oo::define myclass {
      meta set foo bar: baz
    }

  - <a name='10'></a>__oo::class method meta__

    The package injects a new method __meta__ into __oo::class__ which
    works to provide a class instance access to __oo::meta::info__\.

  - <a name='11'></a>__oo::object method meta__

    The package injects a new method __meta__ into __oo::object__\.
    __oo::object__ combines the data for its class \(as provided by
    __oo::meta::metadata__\), with a local variable *meta* to produce a
    local picture of metadata\. This method provides the following additional
    commands:

  - <a name='12'></a>__oo::object method meta cget__ ?*field*? ?*\.\.\.*? *field*

    Attempts to locate a singlar leaf, and return its value\. For single option
    lookups, this is faster than __my meta getnull__ ?*field*? ?*\.\.\.*?
    *field*\], because it performs a search instead directly instead of
    producing the recursive merge product between the class metadata, the local
    *meta* variable, and THEN performing the search\.

# <a name='section5'></a>Bugs, Ideas, Feedback

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

[TOOL](\.\./\.\./\.\./\.\./index\.md\#tool), [TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)

# <a name='category'></a>CATEGORY

TclOO

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015 Sean Woods <yoda@etoyoc\.com>
