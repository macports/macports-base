
[//000000001]: # (uevent \- User events)
[//000000002]: # (Generated from file 'uevent\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (uevent\(n\) 0\.3\.1 tcllib "User events")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

uevent \- User events

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require uevent ?0\.3\.1?  
package require logger  

[__::uevent::bind__ *tag* *event* *command*](#1)  
[__[command](\.\./\.\./\.\./\.\./index\.md\#command)__ *tag* *event* *details*](#2)  
[__::uevent::unbind__ *token*](#3)  
[__::uevent::generate__ *tag* *event* ?*details*?](#4)  
[__::uevent::list__](#5)  
[__::uevent::list__ *tag*](#6)  
[__::uevent::list__ *tag* *event*](#7)  
[__::uevent::watch::tag::add__ *pattern* *command*](#8)  
[__\{\*\}command__ __bound__ *tag*](#9)  
[__\{\*\}command__ __unbound__ *tag*](#10)  
[__::uevent::watch::tag::remove__ *token*](#11)  
[__::uevent::watch::event::add__ *tag\_pattern* *event\_pattern* *command*](#12)  
[__\{\*\}command__ __bound__ *tag* *event*](#13)  
[__\{\*\}command__ __unbound__ *tag* *event*](#14)  
[__::uevent::watch::event::remove__ *token*](#15)  

# <a name='description'></a>DESCRIPTION

This package provides a general facility for the handling of user events\. Allows
the binding of arbitrary commands to arbitrary events on arbitrary tags, removal
of bindings, and event generation\.

The main difference to the event system built into the Tcl/Tk core is that the
latter can generate only virtual events, and only for widgets\. It is not
possible to use the builtin facilities to bind to events on arbitrary
\(pseudo\-\)objects, nor is it able to generate events for such\.

Here we can, by assuming that each object in question is represented by its own
tag\. Which is possible as we allow arbitrary tags\.

More differences:

  1. The package uses only a two\-level hierarchy, tags and events, to handle
     everything, whereas the Tcl/Tk system uses three levels, i\.e\. objects,
     tags, and events, with a n:m relationship between objects and tags\.

  1. This package triggers all bound commands for a tag/event combination, and
     they are independent of each other\. A bound command cannot force the event
     processing core to abort the processing of command coming after it\.

# <a name='section2'></a>API

The package exports eight commands, as specified below\. Note that when the
package is used from within Tcl 8\.5\+ all the higher commands are ensembles, i\.e\.
the :: separators can be replaceed by spaces\.

  - <a name='1'></a>__::uevent::bind__ *tag* *event* *command*

    Using this command registers the *command* prefix to be triggered when the
    *event* occurs for the *tag*\. The result of the command is an opaque
    token representing the binding\. Note that if the same combination of
    <*tag*,*event*,*command*> is used multiple times the same token is
    returned by every call\.

    The signature of the *command* prefix is

      * <a name='2'></a>__[command](\.\./\.\./\.\./\.\./index\.md\#command)__ *tag* *event* *details*

    where *details* contains the argument\(s\) of the event\. Its contents are
    event specific and have to be agreed upon between actual event generator and
    consumer\. This package simply transfers the information and does not perform
    any processing beyond that\.

  - <a name='3'></a>__::uevent::unbind__ *token*

    This command releases the event binding represented by the *token*\. The
    token has to be the result of a call to __::uevent::bind__\. The result
    of the command is the empty string\.

  - <a name='4'></a>__::uevent::generate__ *tag* *event* ?*details*?

    This command generates an *event* for the *tag*, triggering all commands
    bound to that combination\. The *details* argument is simply passed
    unchanged to all event handlers\. It is the responsibility of the code
    generating and consuming the event to have an agreement about the format and
    contents of the information carried therein\. The result of the command is
    the empty string\.

    Note that all bound commands are triggered, independently of each other\. The
    event handlers cannot assume a specific order\. They are also *not* called
    synchronously with the invokation of this command, but simply put into the
    event queue for processing when the system returns to the event loop\.

    Generating an event for an unknown tag, or for a <*tag*,*event*>
    combination which has no commands bound to it is allowed, such calls will be
    ignored\.

  - <a name='5'></a>__::uevent::list__

    In this form the command returns a list containing the names of all tags
    which have events with commands bound to them\.

  - <a name='6'></a>__::uevent::list__ *tag*

    In this format the command returns a list containing the names of all events
    for the *tag* with commands bound to them\. Specifying an unknown tag, i\.e\.
    a tag without event and commands, will cause the command to throw an error\.

  - <a name='7'></a>__::uevent::list__ *tag* *event*

    In this format the command returns a list containing all commands bound to
    the *event* for the *tag*\. Specifying an unknown tag or unknown event,
    will cause the command to throw an error\.

  - <a name='8'></a>__::uevent::watch::tag::add__ *pattern* *command*

    This command sets up a sort of reverse events\. Events generated, i\.e\. the
    *command* prefix invoked, when observers bind to and unbind from specific
    tags\.

    Note that the command prefix is only invoked twice per tag, first when the
    first command is bound to any event of the tag, and second when the last
    command bound to the tag is removed\.

    The signature of the *command* prefix is

      * <a name='9'></a>__\{\*\}command__ __bound__ *tag*

      * <a name='10'></a>__\{\*\}command__ __unbound__ *tag*

    The result of the command is a token representing the watcher\.

  - <a name='11'></a>__::uevent::watch::tag::remove__ *token*

    This command removes a watcher for \(un\)bind events on tags\.

    The result of the command is the empty string\.

  - <a name='12'></a>__::uevent::watch::event::add__ *tag\_pattern* *event\_pattern* *command*

    This command sets up a sort of reverse events\. Events generated, i\.e\. the
    *command* prefix invoked, when observers bind to and unbind from specific
    combinations of tags and events\.

    Note that the command prefix is only invoked twice per tag/event
    combination, first when the first command is bound to it, and second when
    the last command bound to the it is removed\.

    The signature of the *command* prefix is

      * <a name='13'></a>__\{\*\}command__ __bound__ *tag* *event*

      * <a name='14'></a>__\{\*\}command__ __unbound__ *tag* *event*

    The result of the command is a token representing the watcher\.

  - <a name='15'></a>__::uevent::watch::event::remove__ *token*

    This command removes a watcher for \(un\)bind events on tag/event
    combinations\.

    The result of the command is the empty string\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *uevent* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[hook\(n\)](\.\./hook/hook\.md)

# <a name='keywords'></a>KEYWORDS

[bind](\.\./\.\./\.\./\.\./index\.md\#bind), [event](\.\./\.\./\.\./\.\./index\.md\#event),
[generate event](\.\./\.\./\.\./\.\./index\.md\#generate\_event),
[hook](\.\./\.\./\.\./\.\./index\.md\#hook), [unbind](\.\./\.\./\.\./\.\./index\.md\#unbind)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2012 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
