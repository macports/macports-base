
[//000000001]: # (cron \- cron)
[//000000002]: # (Generated from file 'cron\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (cron\(n\) 2\.1 tcllib "cron")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

cron \- Tool for automating the period callback of commands

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6  
package require cron ?2\.1?  

[__::cron::at__ *?processname?* *timecode* *command*](#1)  
[__::cron::cancel__ *processname*](#2)  
[__::cron::every__ *processname* *frequency* *command*](#3)  
[__::cron::in__ *?processname?* *timecode* *command*](#4)  
[__::cron::object\_coroutine__ *object* *coroutine* *?info?*](#5)  
[__::cron::sleep__ *milliseconds*](#6)  
[__::cron::task delete__ *process*](#7)  
[__::cron::task exists__ *process*](#8)  
[__::cron::task info__ *process*](#9)  
[__::cron::task set__ *process* *field* *value* *?field\.\.\.?* *?value\.\.\.?*](#10)  
[__::cron::wake__ *?who?*](#11)  
[__::cron::clock\_step__ *milliseconds*](#12)  
[__::cron::clock\_delay__ *milliseconds*](#13)  
[__::cron::clock\_sleep__ *seconds* *?offset?*](#14)  
[__::cron::clock\_set__ *newtime*](#15)  

# <a name='description'></a>DESCRIPTION

The __cron__ package provides a Pure\-tcl set of tools to allow programs to
schedule tasks to occur at regular intervals\. Rather than force each task to
issue it's own call to the event loop, the cron system mimics the cron utility
in Unix: on task periodically checks to see if something is to be done, and
issues all commands for a given time step at once\.

Changes in version 2\.0

While cron was originally designed to handle time scales > 1 second, the latest
version's internal understand time granularity down to the millisecond, making
it easier to integrate with other timed events\. Version 2\.0 also understands how
to properly integrate coroutines and objects\. It also adds a facility for an
external \(or script driven\) clock\. Note that vwait style events won't work very
well with an external clock\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__::cron::at__ *?processname?* *timecode* *command*

    This command registers a *command* to be called at the time specified by
    *timecode*\. If *timecode* is expressed as an integer, the timecode is
    assumed to be in unixtime\. All other inputs will be interpreted by __clock
    scan__ and converted to unix time\. This task can be modified by subsequent
    calls to this package's commands by referencing *processname*\. If
    *processname* exists, it will be replaced\. If *processname* is not
    given, one is generated and returned by the command\.

        ::cron::at start_coffee {Tomorrow at 9:00am}  {remote::exec::coffeepot power on}
        ::cron::at shutdown_coffee {Tomorrow at 12:00pm}  {remote::exec::coffeepot power off}

  - <a name='2'></a>__::cron::cancel__ *processname*

    This command unregisters the process *processname* and cancels any pending
    commands\. Note: processname can be a process created by either
    __::cron::at__ or __::cron::every__\.

        ::cron::cancel check_mail

  - <a name='3'></a>__::cron::every__ *processname* *frequency* *command*

    This command registers a *command* to be called at the interval of
    *frequency*\. *frequency* is given in seconds\. This task can be modified
    by subsequent calls to this package's commands by referencing
    *processname*\. If *processname* exists, it will be replaced\.

        ::cron::every check_mail 900  ::imap_client::check_mail
        ::cron::every backup_db  3600 {::backup_procedure ::mydb}

  - <a name='4'></a>__::cron::in__ *?processname?* *timecode* *command*

    This command registers a *command* to be called after a delay of time
    specified by *timecode*\. *timecode* is expressed as an seconds\. This
    task can be modified by subsequent calls to this package's commands by
    referencing *processname*\. If *processname* exists, it will be replaced\.
    If *processname* is not given, one is generated and returned by the
    command\.

  - <a name='5'></a>__::cron::object\_coroutine__ *object* *coroutine* *?info?*

    This command registers a *coroutine*, associated with *object* to be
    called given the parameters of *info*\. If now parameters are given, the
    coroutine is assumed to be an idle task which will self\-terminate\. *info*
    can be given in any form compadible with __::cron::task set__

  - <a name='6'></a>__::cron::sleep__ *milliseconds*

    When run within a coroutine, this command will register the coroutine for a
    callback at the appointed time, and immediately yield\.

    If the ::cron::time variable is > 0 this command will advance the internal
    time, 100ms at a time\.

    In all other cases this command will generate a fictious variable, generate
    an after call, and vwait the variable:

        set eventid [incr ::cron::eventcount]
        set var ::cron::event_#$eventid
        set $var 0
        ::after $ms "set $var 1"
        ::vwait $var
        ::unset $var

    Usage:

        ::cron::sleep 250

  - <a name='7'></a>__::cron::task delete__ *process*

    Delete the process specified the *process*

  - <a name='8'></a>__::cron::task exists__ *process*

    Returns true if *process* is registered with cron\.

  - <a name='9'></a>__::cron::task info__ *process*

    Returns a dict describing *process*\. See __::cron::task set__ for a
    description of the options\.

  - <a name='10'></a>__::cron::task set__ *process* *field* *value* *?field\.\.\.?* *?value\.\.\.?*

    If *process* does not exist, it is created\. Options Include:

      * __[command](\.\./\.\./\.\./\.\./index\.md\#command)__

        If __[coroutine](\.\./coroutine/tcllib\_coroutine\.md)__ is black, a
        global command which implements this process\. If
        __[coroutine](\.\./coroutine/tcllib\_coroutine\.md)__ is not black,
        the command to invoke to create or recreate the coroutine\.

      * __[coroutine](\.\./coroutine/tcllib\_coroutine\.md)__

        The name of the coroutine \(if any\) which implements this process\.

      * __frequency__

        If \-1, this process is terminated after the next event\. If 0 this
        process should be called during every idle event\. If positive, this
        process should generate events periodically\. The frequency is an integer
        number of milliseconds between events\.

      * __[object](\.\./\.\./\.\./\.\./index\.md\#object)__

        The object associated with this process or coroutine\.

      * __scheduled__

        If non\-zero, the absolute time from the epoch \(in milliseconds\) that
        this process will trigger an event\. If zero, and the __frequency__
        is also zero, this process is called every idle loop\.

      * __[running](\.\./\.\./\.\./\.\./index\.md\#running)__

        A boolean flag\. If true it indicates the process never returned or
        yielded during the event loop, and will not be called again until it
        does so\.

  - <a name='11'></a>__::cron::wake__ *?who?*

    Wake up cron, and arrange for its event loop to be run during the next Idle
    cycle\.

        ::cron::wake {I just did something important}

Several utility commands are provided that are used internally within cron and
for testing cron, but may or may not be useful in the general cases\.

  - <a name='12'></a>__::cron::clock\_step__ *milliseconds*

    Return a clock time absolute to the epoch which falls on the next border
    between one second and the next for the value of *milliseconds*

  - <a name='13'></a>__::cron::clock\_delay__ *milliseconds*

    Return a clock time absolute to the epoch which falls on the next border
    between one second and the next *milliseconds* in the future\.

  - <a name='14'></a>__::cron::clock\_sleep__ *seconds* *?offset?*

    Return a clock time absolute to the epoch which falls exactly *seconds* in
    the future\. If offset is given it may be positive or negative, and will
    shift the final time to before or after the second would flip\.

  - <a name='15'></a>__::cron::clock\_set__ *newtime*

    Sets the internal clock for cron\. This command will advance the time in
    100ms increment, triggering events, until the internal time catches up with
    *newtime*\.

    *newtime* is expressed in absolute milliseconds since the beginning of the
    epoch\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *odie* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[cron](\.\./\.\./\.\./\.\./index\.md\#cron), [odie](\.\./\.\./\.\./\.\./index\.md\#odie)

# <a name='category'></a>CATEGORY

System

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>
