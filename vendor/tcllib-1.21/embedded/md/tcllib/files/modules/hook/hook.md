
[//000000001]: # (hook \- Hooks)
[//000000002]: # (Generated from file 'hook\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010, by William H\. Duquette)
[//000000004]: # (hook\(n\) 0\.2 tcllib "Hooks")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

hook \- Hooks

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Concepts](#section2)

      - [Introduction](#subsection1)

      - [Bindings](#subsection2)

      - [Subjects and observers](#subsection3)

  - [Reference](#section3)

  - [Example](#section4)

  - [Credits](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require hook ?0\.2?  

[__hook__ __bind__ ?*subject*? ?*hook*? ?*observer*? ?*cmdPrefix*?](#1)  
[__hook__ __call__ *subject* *hook* ?*args*\.\.\.?](#2)  
[__hook__ __forget__ *object*](#3)  
[__hook__ __cget__ *option*](#4)  
[__hook__ __configure__ __option__ *value* \.\.\.](#5)  

# <a name='description'></a>DESCRIPTION

This package provides the __hook__ ensemble command, which implements the
Subject/Observer pattern\. It allows *subjects*, which may be *modules*,
*objects*, *widgets*, and so forth, to synchronously call *hooks* which
may be bound to an arbitrary number of subscribers, called *observers*\. A
subject may call any number of distinct hooks, and any number of observers can
bind callbacks to a particular hook called by a particular subject\. Hook
bindings can be queried and deleted\.

This man page is intended to be a reference only\.

# <a name='section2'></a>Concepts

## <a name='subsection1'></a>Introduction

Tcl modules usually send notifications to other modules in two ways: via Tk
events, and via callback options like the text widget's __\-yscrollcommand__
option\. Tk events are available only in Tk, and callback options require tight
coupling between the modules sending and receiving the notification\.

Loose coupling between sender and receiver is often desirable, however\. In
Model/View/Controller terms, a View can send a command \(stemming from user
input\) to the Controller, which updates the Model\. The Model can then call a
hook *to which all relevant* *Views subscribe\.* The Model is decoupled from
the Views, and indeed need not know whether any Views actually exist\. At
present, Tcl/Tk has no standard mechanism for implementing loose coupling of
this kind\. This package defines a new command, __hook__, which implements
just such a mechanism\.

## <a name='subsection2'></a>Bindings

The __hook__ command manages a collection of hook bindings\. A hook binding
has four elements:

  1. A *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)*: the name of the entity
     that will be calling the hook\.

  1. The *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)* itself\. A hook usually
     reflects some occurrence in the life of the
     *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)* that other entities might
     care to know about\. A *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)* has a name,
     and may also have arguments\. Hook names are arbitrary strings\. Each
     *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)* must document the names and
     arguments of the hooks it can call\.

  1. The name of the *[observer](\.\./\.\./\.\./\.\./index\.md\#observer)* that
     wishes to receive the *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)* from the
     *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)*\.

  1. A command prefix to which the *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)*
     arguments will be appended when the binding is executed\.

## <a name='subsection3'></a>Subjects and observers

For convenience, this document collectively refers to subjects and observers as
*objects*, while placing no requirements on how these *objects* are actually
implemented\. An object can be a __[TclOO](\.\./\.\./\.\./\.\./index\.md\#tcloo)__
or __[Snit](\.\./\.\./\.\./\.\./index\.md\#snit)__ or __XOTcl__ object, a Tcl
command, a namespace, a module, a pseudo\-object managed by some other object \(as
tags are managed by the Tk text widget\) or simply a well\-known name\.

Subject and observer names are arbitrary strings; however, as __hook__ might
be used at the package level, it's necessary to have conventions that avoid name
collisions between packages written by different people\.

Therefore, any subject or observer name used in core or package level code
should look like a Tcl command name, and should be defined in a namespace owned
by the package\. Consider, for example, an ensemble command __::foo__ that
creates a set of pseudo\-objects and uses __hook__ to send notifications\. The
pseudo\-objects have names that are not commands and exist in their own
namespace, rather like file handles do\. To avoid name collisions with subjects
defined by other packages, users of __hook__, these __::foo__ handles
should have names like __::foo::1__, __::foo::2__, and so on\.

Because object names are arbitrary strings, application code can use whatever
additional conventions are dictated by the needs of the application\.

# <a name='section3'></a>Reference

Hook provides the following commands:

  - <a name='1'></a>__hook__ __bind__ ?*subject*? ?*hook*? ?*observer*? ?*cmdPrefix*?

    This subcommand is used to create, update, delete, and query hook bindings\.

    Called with no arguments it returns a list of the subjects with hooks to
    which observers are currently bound\.

    Called with one argument, a *subject*, it returns a list of the subject's
    hooks to which observers are currently bound\.

    Called with two arguments, a *subject* and a *hook*, it returns a list
    of the observers which are currently bound to this *subject* and *hook*\.

    Called with three arguments, a *subject*, a *hook*, and an *observer*,
    it returns the binding proper, the command prefix to be called when the hook
    is called, or the empty string if there is no such binding\.

    Called with four arguments, it creates, updates, or deletes a binding\. If
    *cmdPrefix* is the empty string, it deletes any existing binding for the
    *subject*, *hook*, and *observer*; nothing is returned\. Otherwise,
    *cmdPrefix* must be a command prefix taking as many additional arguments
    as are documented for the *subject* and *hook*\. The binding is added or
    updated, and the observer is returned\.

    If the *observer* is the empty string, "", it will create a new binding
    using an automatically generated observer name of the form
    __::hook::ob__<__number__>\. The automatically generated name will be
    returned, and can be used to query, update, and delete the binding as usual\.
    If automated observer names are always used, the observer name effectively
    becomes a unique binding ID\.

    It is possible to call __hook bind__ to create or delete a binding to a
    *subject* and *hook* while in an observer binding for that same
    *subject* and *hook*\. The following rules determine what happens when

        hook bind $s $h $o $binding

    is called during the execution of

        hook call $s $h

      1. No binding is ever called after it is deleted\.

      1. When a binding is called, the most recently given command prefix is
         always used\.

      1. The set of observers whose bindings are to be called is determined when
         this method begins to execute, and does not change thereafter, except
         that deleted bindings are not called\.

    In particular:

      1. If __$o__s binding to __$s__ and __$h__ is deleted, and
         __$o__s binding has not yet been called during this execution of

             hook call $s $h

         it will not be called\. \(Note that it might already have been called;
         and in all likelihood, it is probably deleting itself\.\)

      1. If __$o__ changes the command prefix that's bound to __$s__ and
         __$h__, and if __$o__s binding has not yet been called during
         this execution of

             hook call $s $h

         the new binding will be called when the time comes\. \(But again, it is
         probably __$o__s binding that is is making the change\.\)

      1. If a new observer is bound to __$s__ and __$h__, its binding
         will not be called until the next invocation of

             hook call $s $h

  - <a name='2'></a>__hook__ __call__ *subject* *hook* ?*args*\.\.\.?

    This command is called when the named *subject* wishes to call the named
    *hook*\. All relevant bindings are called with the specified arguments in
    the global namespace\. Note that the bindings are called synchronously,
    before the command returns; this allows the *args* to include references
    to entities that will be cleaned up as soon as the hook has been called\.

    The order in which the bindings are called is not guaranteed\. If sequence
    among observers must be preserved, define one observer and have its bindings
    call the other callbacks directly in the proper sequence\.

    Because the __hook__ mechanism is intended to support loose coupling, it
    is presumed that the *subject* has no knowledge of the observers, nor any
    expectation regarding return values\. This has a number of implications:

      1. __hook call__ returns the empty string\.

      1. Normal return values from observer bindings are ignored\.

      1. Errors and other exceptional returns propagate normally by default\.
         This will rarely be what is wanted, because the subjects usually have
         no knowledge of the observers and will therefore have no particular
         competence at handling their errors\. That makes it an application
         issue, and so applications will usually want to define an
         __\-errorcommand__\.

    If the __\-errorcommand__ configuration option has a non\-empty value, its
    value will be invoked for all errors and other exceptional returns in
    observer bindings\. See __hook configure__, below, for more information
    on configuration options\.

  - <a name='3'></a>__hook__ __forget__ *object*

    This command deletes any existing bindings in which the named *object*
    appears as either the *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)* or the
    *[observer](\.\./\.\./\.\./\.\./index\.md\#observer)*\. Bindings deleted by this
    method will never be called again\. In particular,

      1. If an observer is forgotten during a call to __hook call__, any
         uncalled binding it might have had to the relevant subject and hook
         will *not* be called subsequently\.

      1. If a subject __$s__ is forgotten during a call to

             hook call $s $h

         then __hook call__ will return as soon as the current binding
         returns\. No further bindings will be called\.

  - <a name='4'></a>__hook__ __cget__ *option*

    This command returns the value of one of the __hook__ command's
    configuration options\.

  - <a name='5'></a>__hook__ __configure__ __option__ *value* \.\.\.

    This command sets the value of one or more of the __hook__ command's
    configuration options:

      * __\-errorcommand__ *cmdPrefix*

        If the value of this option is the empty string, "", then errors and
        other exception returns in binding scripts are propagated normally\.
        Otherwise, it must be a command prefix taking three additional
        arguments:

          1. a 4\-element list \{subject hook arglist observer\},

          1. the result string, and

          1. the return options dictionary\.

        Given this information, the __\-errorcommand__ can choose to log the
        error, call __interp bgerror__, delete the errant binding \(thus
        preventing the error from arising a second time\) and so forth\.

      * __\-tracecommand__ *cmdPrefix*

        The option's value should be a command prefix taking four arguments:

          1. a *[subject](\.\./\.\./\.\./\.\./index\.md\#subject)*,

          1. a *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)*,

          1. a list of the hook's argument values, and

          1. a list of *objects* the hook was called for\.

        The command will be called for each hook that is called\. This allows the
        application to trace hook execution for debugging purposes\.

# <a name='section4'></a>Example

The __::model__ module calls the <Update> hook in response to commands that
change the model's data:

    hook call ::model <Update>

The __\.view__ megawidget displays the model state, and needs to know about
model updates\. Consequently, it subscribes to the ::model's <Update> hook\.

    hook bind ::model <Update> .view [list .view ModelUpdate]

When the __::model__ calls the hook, the __\.view__s ModelUpdate
subcommand will be called\.

Later the __\.view__ megawidget is destroyed\. In its destructor, it tells the
*[hook](\.\./\.\./\.\./\.\./index\.md\#hook)* that it no longer exists:

    hook forget .view

All bindings involving __\.view__ are deleted\.

# <a name='section5'></a>Credits

Hook has been designed and implemented by William H\. Duquette\.

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *hook* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[uevent\(n\)](\.\./uev/uevent\.md)

# <a name='keywords'></a>KEYWORDS

[callback](\.\./\.\./\.\./\.\./index\.md\#callback),
[event](\.\./\.\./\.\./\.\./index\.md\#event), [hook](\.\./\.\./\.\./\.\./index\.md\#hook),
[observer](\.\./\.\./\.\./\.\./index\.md\#observer),
[producer](\.\./\.\./\.\./\.\./index\.md\#producer),
[publisher](\.\./\.\./\.\./\.\./index\.md\#publisher),
[subject](\.\./\.\./\.\./\.\./index\.md\#subject),
[subscriber](\.\./\.\./\.\./\.\./index\.md\#subscriber),
[uevent](\.\./\.\./\.\./\.\./index\.md\#uevent)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010, by William H\. Duquette
