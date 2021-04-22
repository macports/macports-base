
[//000000001]: # (logger \- Object Oriented logging facility)
[//000000002]: # (Generated from file 'logger\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (logger\(n\) 0\.9\.4 tcllib "Object Oriented logging facility")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

logger \- System to control logging of events\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [IMPLEMENTATION](#section2)

  - [Logprocs and Callstack](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require logger ?0\.9\.4?  

[__logger::init__ *service*](#1)  
[__logger::import__ ?__\-all__? ?__\-force__? ?__\-prefix__ *prefix*? ?__\-namespace__ *namespace*? *service*](#2)  
[__logger::initNamespace__ *ns* ?*level*?](#3)  
[__logger::services__](#4)  
[__logger::enable__ *level*](#5)  
[__logger::disable__ *level*](#6)  
[__logger::setlevel__ *level*](#7)  
[__logger::levels__](#8)  
[__logger::servicecmd__ *service*](#9)  
[__$\{log\}::debug__ *message*](#10)  
[__$\{log\}::info__ *message*](#11)  
[__$\{log\}::notice__ *message*](#12)  
[__$\{log\}::warn__ *message*](#13)  
[__$\{log\}::error__ *message*](#14)  
[__$\{log\}::critical__ *message*](#15)  
[__$\{log\}::alert__ *message*](#16)  
[__$\{log\}::emergency__ *message*](#17)  
[__$\{log\}::setlevel__ *level*](#18)  
[__$\{log\}::enable__ *level*](#19)  
[__$\{log\}::disable__ *level*](#20)  
[__$\{log\}::lvlchangeproc__ *command*](#21)  
[__$\{log\}::lvlchangeproc__](#22)  
[__$\{log\}::logproc__ *level*](#23)  
[__$\{log\}::logproc__ *level* *command*](#24)  
[__$\{log\}::logproc__ *level* *argname* *body*](#25)  
[__$\{log\}::services__](#26)  
[__$\{log\}::servicename__](#27)  
[__$\{log\}::currentloglevel__](#28)  
[__$\{log\}::delproc__ *command*](#29)  
[__$\{log\}::delproc__](#30)  
[__$\{log\}::delete__](#31)  
[__$\{log\}::trace__ *command*](#32)  
[__$\{log\}::trace__ __on__](#33)  
[__$\{log\}::trace__ __off__](#34)  
[__$\{log\}::trace__ __status__ ?procName? ?\.\.\.?](#35)  
[__$\{log\}::trace__ __add__ *procName* ?\.\.\.?](#36)  
[__$\{log\}::trace__ __add__ ?\-ns? *nsName* ?\.\.\.?](#37)  
[__$\{log\}::trace__ __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *procName* ?\.\.\.?](#38)  
[__$\{log\}::trace__ __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ ?\-ns? *nsName* ?\.\.\.?](#39)  

# <a name='description'></a>DESCRIPTION

The __logger__ package provides a flexible system for logging messages from
different services, at priority levels, with different commands\.

To begin using the logger package, we do the following:

    package require logger
    set log [logger::init myservice]
    ${log}::notice "Initialized myservice logging"

    ... code ...

    ${log}::notice "Ending myservice logging"
    ${log}::delete

In the above code, after the package is loaded, the following things happen:

  - <a name='1'></a>__logger::init__ *service*

    Initializes the service *service* for logging\. The service names are
    actually Tcl namespace names, so they are separated with '::'\. The service
    name may not be the empty string or only ':'s\. When a logger service is
    initialized, it "inherits" properties from its parents\. For instance, if
    there were a service *foo*, and we did a __logger::init__ *foo::bar*
    \(to create a *bar* service underneath *foo*\), *bar* would copy the
    current configuration of the *foo* service, although it would of course,
    also be possible to then separately configure *bar*\. If a logger service
    is initialized and the parent does not yet exist, the parent is also
    created\. The new logger service is initialized with the default loglevel set
    with __logger::setlevel__\.

  - <a name='2'></a>__logger::import__ ?__\-all__? ?__\-force__? ?__\-prefix__ *prefix*? ?__\-namespace__ *namespace*? *service*

    Import the logger service commands into the current namespace\. Without the
    __\-all__ option only the commands corresponding to the log levels are
    imported\. If __\-all__ is given, all the __$\{log\}::cmd__ style
    commands are imported\. If the import would overwrite a command an error is
    returned and no command is imported\. Use the __\-force__ option to force
    the import and overwrite existing commands without complaining\. If the
    __\-prefix__ option is given, the commands are imported with the given
    *prefix* prepended to their names\. If the __\-namespace__ option is
    given, the commands are imported into the given namespace\. If the namespace
    does not exist, it is created\. If a namespace without a leading :: is given,
    it is interpreted as a child namespace to the current namespace\.

  - <a name='3'></a>__logger::initNamespace__ *ns* ?*level*?

    Convenience command for setting up a namespace for logging\. Creates a logger
    service named after the namespace *ns* \(a :: prefix is stripped\), imports
    all the log commands into the namespace, and sets the default logging level,
    either as specified by *level*, or inherited from a service in the parent
    namespace, or a hardwired default, __warn__\.

  - <a name='4'></a>__logger::services__

    Returns a list of all the available services\.

  - <a name='5'></a>__logger::enable__ *level*

    Globally enables logging at and "above" the given level\. Levels are
    __debug__, __info__, __notice__, __warn__, __error__,
    __critical__, __alert__, __emergency__\.

  - <a name='6'></a>__logger::disable__ *level*

    Globally disables logging at and "below" the given level\. Levels are those
    listed above\.

  - <a name='7'></a>__logger::setlevel__ *level*

    Globally enable logging at and "above" the given level\. Levels are those
    listed above\. This command changes the default loglevel for new loggers
    created with __logger::init__\.

  - <a name='8'></a>__logger::levels__

    Returns a list of the available log levels \(also listed above under
    __enable__\)\.

  - <a name='9'></a>__logger::servicecmd__ *service*

    Returns the __$\{log\}__ token created by __logger::init__ for this
    service\.

  - <a name='10'></a>__$\{log\}::debug__ *message*

  - <a name='11'></a>__$\{log\}::info__ *message*

  - <a name='12'></a>__$\{log\}::notice__ *message*

  - <a name='13'></a>__$\{log\}::warn__ *message*

  - <a name='14'></a>__$\{log\}::error__ *message*

  - <a name='15'></a>__$\{log\}::critical__ *message*

  - <a name='16'></a>__$\{log\}::alert__ *message*

  - <a name='17'></a>__$\{log\}::emergency__ *message*

    These are the commands called to actually log a message about an event\.
    __$\{log\}__ is the variable obtained from __logger::init__\.

  - <a name='18'></a>__$\{log\}::setlevel__ *level*

    Enable logging, in the service referenced by __$\{log\}__, and its
    children, at and above the level specified, and disable logging below it\.

  - <a name='19'></a>__$\{log\}::enable__ *level*

    Enable logging, in the service referenced by __$\{log\}__, and its
    children, at and above the level specified\. Note that this does *not*
    disable logging below this level, so you should probably use
    __setlevel__ instead\.

  - <a name='20'></a>__$\{log\}::disable__ *level*

    Disable logging, in the service referenced by __$\{log\}__, and its
    children, at and below the level specified\. Note that this does *not*
    enable logging above this level, so you should probably use __setlevel__
    instead\. Disabling the loglevel __emergency__ switches logging off for
    the service and its children\.

  - <a name='21'></a>__$\{log\}::lvlchangeproc__ *command*

  - <a name='22'></a>__$\{log\}::lvlchangeproc__

    Set the script to call when the log instance in question changes its log
    level\. If called without a command it returns the currently registered
    command\. The command gets two arguments appended, the old and the new
    loglevel\. The callback is invoked after all changes have been done\. If child
    loggers are affected, their callbacks are called before their parents
    callback\.

    proc lvlcallback {old new} {
        puts "Loglevel changed from $old to $new"
    }
    ${log}::lvlchangeproc lvlcallback

  - <a name='23'></a>__$\{log\}::logproc__ *level*

  - <a name='24'></a>__$\{log\}::logproc__ *level* *command*

  - <a name='25'></a>__$\{log\}::logproc__ *level* *argname* *body*

    This command comes in three forms \- the third, older one is deprecated and
    may be removed from future versions of the logger package\. The current set
    version takes one argument, a command to be executed when the level is
    called\. The callback command takes on argument, the text to be logged\. If
    called only with a valid level __logproc__ returns the name of the
    command currently registered as callback command\. __logproc__ specifies
    which command will perform the actual logging for a given level\. The logger
    package ships with default commands for all log levels, but with
    __logproc__ it is possible to replace them with custom code\. This would
    let you send your logs over the network, to a database, or anything else\.
    For example:

    proc logtoserver {txt} {
        variable socket
        puts $socket "Notice: $txt"
    }

    ${log}::logproc notice logtoserver

    Trace logs are slightly different: instead of a plain text argument, the
    argument provided to the logproc is a dictionary consisting of the
    __enter__ or __leave__ keyword along with another dictionary of
    details about the trace\. These include:

      * __proc__ \- Name of the procedure being traced\.

      * __level__ \- The stack level for the procedure invocation \(from
        __[info](\.\./\.\./\.\./\.\./index\.md\#info)__ __level__\)\.

      * __script__ \- The name of the file in which the procedure is defined,
        or an empty string if defined in interactive mode\.

      * __caller__ \- The name of the procedure calling the procedure being
        traced, or an empty string if the procedure was called from the global
        scope \(stack level 0\)\.

      * __procargs__ \- A dictionary consisting of the names of arguments to
        the procedure paired with values given for those arguments
        \(__enter__ traces only\)\.

      * __status__ \- The Tcl return code \(e\.g\. __ok__, __continue__,
        etc\.\) \(__leave__ traces only\)\.

      * __result__ \- The value returned by the procedure \(__leave__
        traces only\)\.

  - <a name='26'></a>__$\{log\}::services__

    Returns a list of the registered logging services which are children of this
    service\.

  - <a name='27'></a>__$\{log\}::servicename__

    Returns the name of this service\.

  - <a name='28'></a>__$\{log\}::currentloglevel__

    Returns the currently enabled log level for this service\. If no logging is
    enabled returns __none__\.

  - <a name='29'></a>__$\{log\}::delproc__ *command*

  - <a name='30'></a>__$\{log\}::delproc__

    Set the script to call when the log instance in question is deleted\. If
    called without a command it returns the currently registered command\. For
    example:

    ${log}::delproc [list closesock $logsock]

  - <a name='31'></a>__$\{log\}::delete__

    This command deletes a particular logging service, and its children\. You
    must call this to clean up the resources used by a service\.

  - <a name='32'></a>__$\{log\}::trace__ *command*

    This command controls logging of enter/leave traces for specified
    procedures\. It is used to enable and disable tracing, query tracing status,
    and specify procedures are to be traced\. Trace handlers are unregistered
    when tracing is disabled\. As a result, there is not performance impact to a
    library when tracing is disabled, just as with other log level commands\.

      proc tracecmd { dict } {
          puts $dict
      }

      set log [::logger::init example]
      ${log}::logproc trace tracecmd

      proc foo { args } {
          puts "In foo"
          bar 1
          return "foo_result"
      }

      proc bar { x } {
          puts "In bar"
          return "bar_result"
      }

      ${log}::trace add foo bar
      ${log}::trace on

      foo

    # Output:
    enter {proc ::foo level 1 script {} caller {} procargs {args {}}}
    In foo
    enter {proc ::bar level 2 script {} caller ::foo procargs {x 1}}
    In bar
    leave {proc ::bar level 2 script {} caller ::foo status ok result bar_result}
    leave {proc ::foo level 1 script {} caller {} status ok result foo_result}

  - <a name='33'></a>__$\{log\}::trace__ __on__

    Turns on trace logging for procedures registered through the
    __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __add__ command\. This is
    similar to the __enable__ command for other logging levels, but allows
    trace logging to take place at any level\. The trace logging mechanism takes
    advantage of the execution trace feature of Tcl 8\.4 and later\. The
    __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __on__ command will
    return an error if called from earlier versions of Tcl\.

  - <a name='34'></a>__$\{log\}::trace__ __off__

    Turns off trace logging for procedures registered for trace logging through
    the __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __add__ command\.
    This is similar to the __disable__ command for other logging levels, but
    allows trace logging to take place at any level\. Procedures are not
    unregistered, so logging for them can be turned back on with the
    __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __on__ command\. There is
    no overhead imposed by trace registration when trace logging is disabled\.

  - <a name='35'></a>__$\{log\}::trace__ __status__ ?procName? ?\.\.\.?

    This command returns a list of the procedures currently registered for trace
    logging, or a flag indicating whether or not a trace is registered for one
    or more specified procedures\.

  - <a name='36'></a>__$\{log\}::trace__ __add__ *procName* ?\.\.\.?

  - <a name='37'></a>__$\{log\}::trace__ __add__ ?\-ns? *nsName* ?\.\.\.?

    This command registers one or more procedures for logging of entry/exit
    traces\. Procedures can be specified via a list of procedure names or
    namespace names \(in which case all procedure within the namespace are
    targeted by the operation\)\. By default, each name is first interpreted as a
    procedure name or glob\-style search pattern, and if not found its
    interpreted as a namespace name\. The *\-ns* option can be used to force
    interpretation of all provided arguments as namespace names\. Procedures must
    be defined prior to registering them for tracing through the
    __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __add__ command\. Any
    procedure or namespace names/patterns that don't match any existing
    procedures will be silently ignored\.

  - <a name='38'></a>__$\{log\}::trace__ __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ *procName* ?\.\.\.?

  - <a name='39'></a>__$\{log\}::trace__ __[remove](\.\./\.\./\.\./\.\./index\.md\#remove)__ ?\-ns? *nsName* ?\.\.\.?

    This command unregisters one or more procedures so that they will no longer
    have trace logging performed, with the same matching rules as that of the
    __[trace](\.\./\.\./\.\./\.\./index\.md\#trace)__ __add__ command\.

# <a name='section2'></a>IMPLEMENTATION

The logger package is implemented in such a way as to optimize \(for Tcl 8\.4 and
newer\) log procedures which are disabled\. They are aliased to a proc which has
no body, which is compiled to a no op in bytecode\. This should make the
peformance hit minimal\. If you really want to pull out all the stops, you can
replace the $\{log\} token in your code with the actual namespace and command
\($\{log\}::warn becomes ::logger::tree::myservice::warn\), so that no variable
lookup is done\. This puts the performance of disabled logger commands very close
to no logging at all\.

The "object orientation" is done through a hierarchy of namespaces\. Using an
actual object oriented system would probably be a better way of doing things, or
at least provide for a cleaner implementation\.

The service "object orientation" is done with namespaces\.

# <a name='section3'></a>Logprocs and Callstack

The logger package takes extra care to keep the logproc out of the call stack\.
This enables logprocs to execute code in the callers scope by using uplevel or
linking to local variables by using upvar\. This may fire traces with all usual
side effects\.

    # Print caller and current vars in the calling proc
    proc log_local_var {txt} {
         set caller [info level -1]
         set vars [uplevel 1 info vars]
         foreach var [lsort $vars] {
            if {[uplevel 1 [list array exists $var]] == 1} {
            	lappend val $var <Array>
            } else {
            	lappend val $var [uplevel 1 [list set $var]]
            }
         }
         puts "$txt"
         puts "Caller: $caller"
         puts "Variables in callers scope:"
         foreach {var value} $val {
         	puts "$var = $value"
         }
    }

    # install as logproc
    ${log}::logproc debug log_local_var

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *logger* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[log](\.\./\.\./\.\./\.\./index\.md\#log), [log
level](\.\./\.\./\.\./\.\./index\.md\#log\_level),
[logger](\.\./\.\./\.\./\.\./index\.md\#logger),
[service](\.\./\.\./\.\./\.\./index\.md\#service)

# <a name='category'></a>CATEGORY

Programming tools
