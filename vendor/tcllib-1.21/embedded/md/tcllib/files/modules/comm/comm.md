
[//000000001]: # (comm \- Remote communication)
[//000000002]: # (Generated from file 'comm\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 1995\-1998 The Open Group\. All Rights Reserved\.)
[//000000004]: # (Copyright &copy; 2003\-2004 ActiveState Corporation\.)
[//000000005]: # (Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000006]: # (comm\(n\) 4\.7 tcllib "Remote communication")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

comm \- A remote communication facility for Tcl \(8\.5 and later\)

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [Commands](#subsection1)

      - [Eval Semantics](#subsection2)

      - [Multiple Channels](#subsection3)

      - [Channel Configuration](#subsection4)

      - [Id/port Assignments](#subsection5)

      - [Execution Environment](#subsection6)

      - [Remote Interpreters](#subsection7)

      - [Closing Connections](#subsection8)

      - [Callbacks](#subsection9)

      - [Unsupported](#subsection10)

      - [Security](#subsection11)

      - [Blocking Semantics](#subsection12)

      - [Asynchronous Result Generation](#subsection13)

      - [Compatibility](#subsection14)

  - [TLS Security Considerations](#section2)

  - [Author](#section3)

  - [License](#section4)

  - [Bugs](#section5)

  - [On Using Old Versions Of Tcl](#section6)

  - [Related Work](#section7)

  - [Bugs, Ideas, Feedback](#section8)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require comm ?4\.7?  

[__::comm::comm send__ ?\-async? ?\-command *callback*? *id* *cmd* ?*arg arg \.\.\.*?](#1)  
[__::comm::comm self__](#2)  
[__::comm::comm interps__](#3)  
[__::comm::comm connect__ ?*id*?](#4)  
[__::comm::comm new__ *chan* ?*name value \.\.\.*?](#5)  
[__::comm::comm channels__](#6)  
[__::comm::comm config__](#7)  
[__::comm::comm config__ *name*](#8)  
[__::comm::comm config__ ?*name* *value* *\.\.\.*?](#9)  
[__::comm::comm shutdown__ *id*](#10)  
[__::comm::comm abort__](#11)  
[__::comm::comm destroy__](#12)  
[__::comm::comm hook__ *event* ?__\+__? ?*script*?](#13)  
[__::comm::comm remoteid__](#14)  
[__::comm::comm\_send__](#15)  
[__::comm::comm return\_async__](#16)  
[__$future__ __return__ ?__\-code__ *code*? ?*value*?](#17)  
[__$future__ __configure__ ?__\-command__ ?*cmdprefix*??](#18)  
[__$future__ __cget__ __\-command__](#19)  

# <a name='description'></a>DESCRIPTION

The __comm__ command provides an inter\-interpreter remote execution facility
much like Tk's __send\(n\)__, except that it uses sockets rather than the X
server for the communication path\. As a result, __comm__ works with multiple
interpreters, works on Windows and Macintosh systems, and provides control over
the remote execution path\.

These commands work just like __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ and
__winfo interps__ :

    ::comm::comm send ?-async? id cmd ?arg arg ...?
    ::comm::comm interps

This is all that is really needed to know in order to use __comm__

## <a name='subsection1'></a>Commands

The package initializes __::comm::comm__ as the default *chan*\.

__comm__ names communication endpoints with an *id* unique to each
machine\. Before sending commands, the *id* of another interpreter is needed\.
Unlike Tk's send, __comm__ doesn't implicitly know the *id*'s of all the
interpreters on the system\. The following four methods make up the basic
__comm__ interface\.

  - <a name='1'></a>__::comm::comm send__ ?\-async? ?\-command *callback*? *id* *cmd* ?*arg arg \.\.\.*?

    This invokes the given command in the interpreter named by *id*\. The
    command waits for the result and remote errors are returned unless the
    __\-async__ or __\-command__ option is given\. If __\-async__ is
    given, send returns immediately and there is no further notification of
    result\. If __\-command__ is used, *callback* specifies a command to
    invoke when the result is received\. These options are mutually exclusive\.
    The callback will receive arguments in the form *\-option value*, suitable
    for __array set__\. The options are: *\-id*, the comm id of the
    interpreter that received the command; *\-serial*, a unique serial for each
    command sent to a particular comm interpreter; *\-chan*, the comm channel
    name; *\-code*, the result code of the command; *\-errorcode*, the
    errorcode, if any, of the command; *\-errorinfo*, the errorinfo, if any, of
    the command; and *\-result*, the return value of the command\. If connection
    is lost before a reply is received, the callback will be invoked with a
    connection lost message with \-code equal to \-1\. When __\-command__ is
    used, the command returns the unique serial for the command\.

  - <a name='2'></a>__::comm::comm self__

    Returns the *id* for this channel\.

  - <a name='3'></a>__::comm::comm interps__

    Returns a list of all the remote *id*'s to which this channel is
    connected\. __comm__ learns a new remote *id* when a command is first
    issued it, or when a remote *id* first issues a command to this comm
    channel\. __::comm::comm ids__ is an alias for this method\.

  - <a name='4'></a>__::comm::comm connect__ ?*id*?

    Whereas __::comm::comm send__ will automatically connect to the given
    *id*, this forces a connection to a remote *id* without sending a
    command\. After this, the remote *id* will appear in __::comm::comm
    interps__\.

## <a name='subsection2'></a>Eval Semantics

The evaluation semantics of __::comm::comm send__ are intended to match Tk's
__[send](\.\./\.\./\.\./\.\./index\.md\#send)__ *exactly*\. This means that
__comm__ evaluates arguments on the remote side\.

If you find that __::comm::comm send__ doesn't work for a particular
command, try the same thing with Tk's send and see if the result is different\.
If there is a problem, please report it\. For instance, there was had one report
that this command produced an error\. Note that the equivalent
__[send](\.\./\.\./\.\./\.\./index\.md\#send)__ command also produces the same
error\.

    % ::comm::comm send id llength {a b c}
    wrong # args: should be "llength list"
    % send name llength {a b c}
    wrong # args: should be "llength list"

The __eval__ hook \(described below\) can be used to change from
__[send](\.\./\.\./\.\./\.\./index\.md\#send)__'s double eval semantics to single
eval semantics\.

## <a name='subsection3'></a>Multiple Channels

More than one __comm__ channel \(or *listener*\) can be created in each Tcl
interpreter\. This allows flexibility to create full and restricted channels\. For
instance, *[hook](\.\./\.\./\.\./\.\./index\.md\#hook)* scripts are specific to the
channel they are defined against\.

  - <a name='5'></a>__::comm::comm new__ *chan* ?*name value \.\.\.*?

    This creates a new channel and Tcl command with the given channel name\. This
    new command controls the new channel and takes all the same arguments as
    __::comm::comm__\. Any remaining arguments are passed to the
    __config__ method\. The fully qualified channel name is returned\.

  - <a name='6'></a>__::comm::comm channels__

    This lists all the channels allocated in this Tcl interpreter\.

The default configuration parameters for a new channel are:

    "-port 0 -local 1 -listen 0 -silent 0"

The default channel __::comm::comm__ is created with:

    "::comm::comm new ::comm::comm -port 0 -local 1 -listen 1 -silent 0"

## <a name='subsection4'></a>Channel Configuration

The __config__ method acts similar to __fconfigure__ in that it sets or
queries configuration variables associated with a channel\.

  - <a name='7'></a>__::comm::comm config__

  - <a name='8'></a>__::comm::comm config__ *name*

  - <a name='9'></a>__::comm::comm config__ ?*name* *value* *\.\.\.*?

    When given no arguments, __config__ returns a list of all variables and
    their value With one argument, __config__ returns the value of just that
    argument\. With an even number of arguments, the given variables are set to
    the given values\.

These configuration variables can be changed \(descriptions of them are elsewhere
in this manual page\):

  - __\-listen__ ?*0&#124;1*?

  - __\-local__  ?*0&#124;1*?

  - __\-port__   ?*port*?

  - __\-silent__ ?*0&#124;1*?

  - __\-socketcmd__ ?*commandname*?

  - __\-interp__ ?*interpreter*?

  - __\-events__ ?*eventlist*?

These configuration variables are read only:

  - __\-chan__    *chan*

  - __\-serial__  *n*

  - __\-socket__  sock*In*

When __config__ changes the parameters of an existing channel \(with the
exception of __\-interp__ and __\-events__\), it closes and reopens the
listening socket\. An automatically assigned channel *id* will change when this
happens\. Recycling the socket is done by invoking __::comm::comm abort__,
which causes all active sends to terminate\.

## <a name='subsection5'></a>Id/port Assignments

__comm__ uses a TCP port for endpoint *id*\. The __interps__ \(or
__ids__\) method merely lists all the TCP ports to which the channel is
connected\. By default, each channel's *id* is randomly assigned by the
operating system \(but usually starts at a low value around 1024 and increases
each time a new socket is opened\)\. This behavior is accomplished by giving the
__\-port__ config option a value of 0\. Alternately, a specific TCP port
number may be provided for a given channel\. As a special case, comm contains
code to allocate a a high\-numbered TCP port \(>10000\) by using __\-port \{\}__\.
Note that a channel won't be created and initialized unless the specific port
can be allocated\.

As a special case, if the channel is configured with __\-listen 0__, then it
will not create a listening socket and will use an id of __0__ for itself\.
Such a channel is only good for outgoing connections \(although once a connection
is established, it can carry send traffic in both directions\)\. As another
special case, if the channel is configured with __\-silent 0__, then the
listening side will ignore connection attempts where the protocol negotiation
phase failed, instead of throwing an error\.

## <a name='subsection6'></a>Execution Environment

A communication channel in its default configuration will use the current
interpreter for the execution of all received scripts, and of the event scripts
associated with the various hooks\.

This insecure setup can be changed by the user via the two options
__\-interp__, and __\-events__\.

When __\-interp__ is set all received scripts are executed in the slave
interpreter specified as the value of the option\. This interpreter is expected
to exist before configuration\. I\.e\. it is the responsibility of the user to
create it\. However afterward the communication channel takes ownership of this
interpreter, and will destroy it when the communication channel is destroyed\.
Note that reconfiguration of the communication channel to either a different
interpreter or the empty string will release the ownership *without*
destroying the previously configured interpreter\. The empty string has a special
meaning, it restores the default behaviour of executing received scripts in the
current interpreter\.

*Also of note* is that replies and callbacks \(a special form of reply\) are
*not* considered as received scripts\. They are trusted, part of the internal
machinery of comm, and therefore always executed in the current interpreter\.

Even if an interpreter has been configured as the execution environment for
received scripts the event scripts associated with the various hooks will by
default still be executed in the current interpreter\. To change this use the
option __\-events__ to declare a list of the events whose scripts should be
executed in the declared interpreter as well\. The contents of this option are
ignored if the communication channel is configured to execute received scripts
in the current interpreter\.

## <a name='subsection7'></a>Remote Interpreters

By default, each channel is restricted to accepting connections from the local
system\. This can be overridden by using the __\-local 0__ configuration
option For such channels, the *id* parameter takes the form *\{ id host \}*\.

*WARNING*: The *host* must always be specified in the same form \(e\.g\., as
either a fully qualified domain name, plain hostname or an IP address\)\.

## <a name='subsection8'></a>Closing Connections

These methods give control over closing connections:

  - <a name='10'></a>__::comm::comm shutdown__ *id*

    This closes the connection to *id*, aborting all outstanding commands in
    progress\. Note that nothing prevents the connection from being immediately
    reopened by another incoming or outgoing command\.

  - <a name='11'></a>__::comm::comm abort__

    This invokes shutdown on all open connections in this comm channel\.

  - <a name='12'></a>__::comm::comm destroy__

    This aborts all connections and then destroys the this comm channel itself,
    including closing the listening socket\. Special code allows the default
    __::comm::comm__ channel to be closed such that the __::comm::comm__
    command it is not destroyed\. Doing so closes the listening socket,
    preventing both incoming and outgoing commands on the channel\. This sequence
    reinitializes the default channel:

    "::comm::comm destroy; ::comm::comm new ::comm::comm"

When a remote connection is lost \(because the remote exited or called
__shutdown__\), __comm__ can invoke an application callback\. This can be
used to cleanup or restart an ancillary process, for instance\. See the *lost*
callback below\.

## <a name='subsection9'></a>Callbacks

This is a mechanism for setting hooks for particular events:

  - <a name='13'></a>__::comm::comm hook__ *event* ?__\+__? ?*script*?

    This uses a syntax similar to Tk's
    __[bind](\.\./\.\./\.\./\.\./index\.md\#bind)__ command\. Prefixing *script*
    with a __\+__ causes the new script to be appended\. Without this, a new
    *script* replaces any existing script\. When invoked without a script, no
    change is made\. In all cases, the new hook script is returned by the
    command\.

    When an *event* occurs, the *script* associated with it is evaluated
    with the listed variables in scope and available\. The return code \(*not*
    the return value\) of the script is commonly used decide how to further
    process after the hook\.

    Common variables include:

      * __chan__

        the name of the comm channel \(and command\)

      * __id__

        the id of the remote in question

      * __fid__

        the file id for the socket of the connection

These are the defined *events*:

  - __connecting__

    Variables: __chan__, __id__

    This hook is invoked before making a connection to the remote named in
    *id*\. An error return \(via
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__\) will abort the connection
    attempt with the error\. Example:

    % ::comm::comm hook connecting {
        if {[string match {*[02468]} $id]} {
            error "Can't connect to even ids"
        }
    }
    % ::comm::comm send 10000 puts ok
    Connect to remote failed: Can't connect to even ids
    %

  - __connected__

    Variables: __chan__, __fid__, __id__, __host__, and
    __port__\.

    This hook is invoked immediately after making a remote connection to *id*,
    allowing arbitrary authentication over the socket named by *fid*\. An error
    return \(via __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ \) will close the
    connection with the error\. *host* and *port* are merely extracted from
    the *id*; changing any of these will have no effect on the connection,
    however\. It is also possible to substitute and replace *fid*\.

  - __incoming__

    Variables: __chan__, __fid__, __addr__, and __remport__\.

    Hook invoked when receiving an incoming connection, allowing arbitrary
    authentication over socket named by *fid*\. An error return \(via
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__\) will close the connection
    with the error\. Note that the peer is named by *remport* and *addr* but
    that the remote *id* is still unknown\. Example:

    ::comm::comm hook incoming {
        if {[string match 127.0.0.1 $addr]} {
            error "I don't talk to myself"
        }
    }

  - __eval__

    Variables: __chan__, __id__, __cmd__, and __buffer__\.

    This hook is invoked after collecting a complete script from a remote but
    *before* evaluating it\. This allows complete control over the processing
    of incoming commands\. *cmd* contains either __send__ or __async__\.
    *buffer* holds the script to evaluate\. At the time the hook is called,
    *$chan remoteid* is identical in value to *id*\.

    By changing *buffer*, the hook can change the script to be evaluated\. The
    hook can short circuit evaluation and cause a value to be immediately
    returned by using __[return](\.\./\.\./\.\./\.\./index\.md\#return)__
    *result* \(or, from within a procedure, __return \-code return__
    *result*\)\. An error return \(via
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__\) will return an error
    result, as is if the script caused the error\. Any other return will evaluate
    the script in *buffer* as normal\. For compatibility with 3\.2,
    __break__ and __return \-code break__ *result* is supported, acting
    similarly to __return \{\}__ and __return \-code return__ *result*\.

    Examples:

      1. augmenting a command

    % ::comm::comm send [::comm::comm self] pid
    5013
    % ::comm::comm hook eval {puts "going to execute $buffer"}
    % ::comm::comm send [::comm::comm self] pid
    going to execute pid
    5013

      1. short circuiting a command

    % ::comm::comm hook eval {puts "would have executed $buffer"; return 0}
    % ::comm::comm send [::comm::comm self] pid
    would have executed pid
    0

      1. Replacing double eval semantics

    % ::comm::comm send [::comm::comm self] llength {a b c}
    wrong # args: should be "llength list"
    % ::comm::comm hook eval {return [uplevel #0 $buffer]}
    return [uplevel #0 $buffer]
    % ::comm::comm send [::comm::comm self] llength {a b c}
    3

      1. Using a slave interpreter

    % interp create foo
    % ::comm::comm hook eval {return [foo eval $buffer]}
    % ::comm::comm send [::comm::comm self] set myvar 123
    123
    % set myvar
    can't read "myvar": no such variable
    % foo eval set myvar
    123

      1. Using a slave interpreter \(double eval\)

    % ::comm::comm hook eval {return [eval foo eval $buffer]}

      1. Subverting the script to execute

    % ::comm::comm hook eval {
        switch -- $buffer {
            a {return A-OK}
            b {return B-OK}
            default {error "$buffer is a no-no"}
        }
    }
    % ::comm::comm send [::comm::comm self] pid
    pid is a no-no
    % ::comm::comm send [::comm::comm self] a
    A-OK

  - __reply__

    Variables: __chan__, __id__, __buffer__, __ret__, and
    __return\(\)__\.

    This hook is invoked after collecting a complete reply script from a remote
    but *before* evaluating it\. This allows complete control over the
    processing of replies to sent commands\. The reply *buffer* is in one of
    the following forms

      * return result

      * return \-code code result

      * return \-code code \-errorinfo info \-errorcode ecode msg

    For safety reasons, this is decomposed\. The return result is in *ret*, and
    the return switches are in the return array:

      * *return\(\-code\)*

      * *return\(\-errorinfo\)*

      * *return\(\-errorcode\)*

    Any of these may be the empty string\. Modifying these four variables can
    change the return value, whereas modifying *buffer* has no effect\.

  - __callback__

    Variables: __chan__, __id__, __buffer__, __ret__, and
    __return\(\)__\.

    Similar to *reply*, but used for callbacks\.

  - __lost__

    Variables: __chan__, __id__, and __reason__\.

    This hook is invoked when the connection to __id__ is lost\. Return value
    \(or thrown error\) is ignored\. *reason* is an explanatory string indicating
    why the connection was lost\. Example:

    ::comm::comm hook lost {
        global myvar
        if {$myvar(id) == $id} {
            myfunc
            return
        }
    }

## <a name='subsection10'></a>Unsupported

These interfaces may change or go away in subsequence releases\.

  - <a name='14'></a>__::comm::comm remoteid__

    Returns the *id* of the sender of the last remote command executed on this
    channel\. If used by a proc being invoked remotely, it must be called before
    any events are processed\. Otherwise, another command may get invoked and
    change the value\.

  - <a name='15'></a>__::comm::comm\_send__

    Invoking this procedure will substitute the Tk
    __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ and __winfo interps__
    commands with these equivalents that use __::comm::comm__\.

    proc send {args} {
        eval ::comm::comm send $args
    }
    rename winfo tk_winfo
    proc winfo {cmd args} {
        if {![string match in* $cmd]} {
            return [eval [list tk_winfo $cmd] $args]
        }
        return [::comm::comm interps]
    }

## <a name='subsection11'></a>Security

Starting with version 4\.6 of the package an option __\-socketcmd__ is
supported, allowing the user of a comm channel to specify which command to use
when opening a socket\. Anything which is API\-compatible with the builtin
__::socket__ \(the default\) can be used\.

The envisioned main use is the specification of the __tls::socket__ command,
see package __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__, to secure the
communication\.

    # Load and initialize tls
    package require tls
    tls::init  -cafile /path/to/ca/cert -keyfile ...

    # Create secured comm channel
    ::comm::comm new SECURE -socketcmd tls::socket -listen 1
    ...

The sections [Execution Environment](#subsection6) and
[Callbacks](#subsection9) are also relevant to the security of the system,
providing means to restrict the execution to a specific environment, perform
additional authentication, and the like\.

## <a name='subsection12'></a>Blocking Semantics

There is one outstanding difference between __comm__ and
__[send](\.\./\.\./\.\./\.\./index\.md\#send)__\. When blocking in a synchronous
remote command, __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ uses an internal C
hook \(Tk\_RestrictEvents\) to the event loop to look ahead for send\-related events
and only process those without processing any other events\. In contrast,
__comm__ uses the __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__ command as
a semaphore to indicate the return message has arrived\. The difference is that a
synchronous __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ will block the
application and prevent all events \(including window related ones\) from being
processed, while a synchronous __::comm::comm send__ will block the
application but still allow other events to get processed\. In particular,
__after idle__ handlers will fire immediately when comm blocks\.

What can be done about this? First, note that this behavior will come from any
code using __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__ to block and wait for
an event to occur\. At the cost of multiple channel support, __comm__ could
be changed to do blocking I/O on the socket, giving send\-like blocking
semantics\. However, multiple channel support is a very useful feature of comm
that it is deemed too important to lose\. The remaining approaches involve a new
loadable module written in C \(which is somewhat against the philosophy of
__comm__\) One way would be to create a modified version of the
__[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__ command that allow the event
flags passed to Tcl\_DoOneEvent to be specified\. For __comm__, just the
TCL\_FILE\_EVENTS would be processed\. Another way would be to implement a
mechanism like Tk\_RestrictEvents, but apply it to the Tcl event loop \(since
__comm__ doesn't require Tk\)\. One of these approaches will be available in a
future __comm__ release as an optional component\.

## <a name='subsection13'></a>Asynchronous Result Generation

By default the result returned by a remotely invoked command is the result sent
back to the invoker\. This means that the result is generated synchronously, and
the server handling the call is blocked for the duration of the command\.

While this is tolerable as long as only short\-running commands are invoked on
the server long\-running commands, like database queries make this a problem\. One
command can prevent the processing requests of all other clients for an
arbitrary period of time\.

Before version 4\.5 of comm the only solution was to rewrite the server command
to use the Tcl builtin command __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__,
or one of its relatives like __tkwait__, to open a new event loop which
processes requests while the long\-running operation is executed\. This however
has its own perils, as this makes it possible to both overflow the Tcl stack
with a large number of event loop, and to have a newer requests block the return
of older ones, as the eventloop have to be unwound in the order of their
creation\.

The proper solution is to have the invoked command indicate to __comm__ that
it cannot or will not deliver an immediate, synchronous result, but will do so
later\. At that point the framework can put sending the actual result on hold and
continue processing requests using the main event loop\. No blocking, no nesting
of event loops\. At some future date the long running operation delivers the
result to comm, via the future object, which is then forwarded to the invoker as
usual\.

The necessary support for this solution has been added to comm since version
4\.5, in the form of the new method __return\_async__\.

  - <a name='16'></a>__::comm::comm return\_async__

    This command is used by a remotely invoked script to notify the comm channel
    which invoked it that the result to send back to the invoker is not
    generated synchronously\. If this command is not called the default/standard
    behaviour of comm is to send the synchronously generated result of the
    script itself to the invoker\.

    The result of __return\_async__ is an object\. This object, called a
    *future* is where the result of the script has to be delivered to when it
    becomes ready\. When that happens it will take all the necessary actions to
    deliver the result to the invoker of the script, and then destroy itself\.
    Should comm have lost the connection to the invoker while the result is
    being computed the future will not try to deliver the result it got, but
    just destroy itself\. The future can be configured with a command to call
    when the invoker is lost\. This enables the user to implement an early abort
    of the long\-running operation, should this be supported by it\.

    An example:

    # Procedure invoked by remote clients to run database operations.
    proc select {sql} {
        # Signal the async generation of the result

        set future [::comm::comm return_async]

        # Generate an async db operation and tell it where to deliver the result.

        set query [db query -command [list $future return] $sql]

        # Tell the database system which query to cancel if the connection
        # goes away while it is running.

        $future configure -command [list db cancel $query]

        # Note: The above will work without problem only if the async
        # query will nover run its completion callback immediately, but
        # only from the eventloop. Because otherwise the future we wish to
        # configure may already be gone. If that is possible use 'catch'
        # to prevent the error from propagating.
        return
    }

    The API of a future object is:

      * <a name='17'></a>__$future__ __return__ ?__\-code__ *code*? ?*value*?

        Use this method to tell the future that long\-running operation has
        completed\. Arguments are an optional return value \(defaults to the empty
        string\), and the Tcl return code \(defaults to OK\)\.

        The future will deliver this information to invoker, if the connection
        was not lost in the meantime, and then destroy itself\. If the connection
        was lost it will do nothing but destroy itself\.

      * <a name='18'></a>__$future__ __configure__ ?__\-command__ ?*cmdprefix*??

      * <a name='19'></a>__$future__ __cget__ __\-command__

        These methods allow the user to retrieve and set a command to be called
        if the connection the future belongs to has been lost\.

## <a name='subsection14'></a>Compatibility

__comm__ exports itself as a package\. The package version number is in the
form *major \. minor*, where the major version will only change when a
non\-compatible change happens to the API or protocol\. Minor bug fixes and
changes will only affect the minor version\. To load __comm__ this command is
usually used:

    package require comm 3

Note that requiring no version \(or a specific version\) can also be done\.

The revision history of __comm__ includes these releases:

  - 4\.6\.3

    Fixed ticket \[ced0d60fc9\]\. Added proper detection of eof on a socket,
    properly closing it\.

  - 4\.6\.2

    Fixed bugs 2972571 and 3066872, the first a misdetection of quoted brace
    after double backslash, the other a blocking gets making for an obvious
    \(hinsight\) DoS attack on comm channels\.

  - 4\.6\.1

    Changed the implementation of __comm::commCollect__ to emulate lindex's
    pre\-Tcl 8 behaviour, i\.e\. it was given the ability to parse out the first
    word of a list, even if the whole buffer is not a well\-formed list\. Without
    this change the first word could only be extracted if the whole buffer was a
    well\-formed list \(ever since Tcl 8\), and in a ver\-high\-load situation, i\.e\.
    a server sending lots and/or large commands very fast, this may never
    happen, eventually crashing the receiver when it runs out of memory\. With
    the change the receiver is always able to process the first word when it
    becomes well\-formed, regardless of the structure of the remainder of the
    buffer\.

  - 4\.6

    Added the option __\-socketcmd__ enabling users to override how a socket
    is opened\. The envisioned main use is the specification of the
    __tls::socket__ command, see package
    __[tls](\.\./\.\./\.\./\.\./index\.md\#tls)__, to secure the communication\.

  - 4\.5\.7

    Changed handling of ports already in use to provide a proper error message\.

  - 4\.5\.6

    Bugfix in the replacement for
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__, made robust against of
    variable names containing spaces\.

  - 4\.5\.5

    Bugfix in the handling of hooks, typo in variable name\.

  - 4\.5\.4

    Bugfix in the handling of the result received by the __send__ method\.
    Replaced an *after idle unset result* with an immediate __unset__,
    with the information saved to a local variable\.

    The __after idle__ can spill into a forked child process if there is no
    event loop between its setup and the fork\. This may bork the child if the
    next event loop is the __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__ of
    __comm__'s __send__ a few lines above the __after idle__, and
    the child used the same serial number for its next request\. In that case the
    parent's __after idle unset__ will delete the very array element the
    child is waiting for, unlocking the
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__, causing it to access a now
    missing array element, instead of the expected result\.

  - 4\.5\.3

    Bugfixes in the wrappers for the builtin
    __[update](\.\./\.\./\.\./\.\./index\.md\#update)__ and
    __[vwait](\.\./\.\./\.\./\.\./index\.md\#vwait)__ commands\.

  - 4\.5\.2

    Bugfix in the wrapper for the builtin
    __[update](\.\./\.\./\.\./\.\./index\.md\#update)__ command\.

  - 4\.5\.1

    Bugfixes in the handling of \-interp for regular scripts\. The handling of the
    buffer was wrong for scripts which are a single statement as list\. Fixed
    missing argument to new command __commSendReply__, introduced by version
    4\.5\. Affected debugging\.

  - 4\.5

    New server\-side feature\. The command invoked on the server can now switch
    comm from the standard synchronous return of its result to an asynchronous
    \(defered\) return\. Due to the use of snit to implement the *future* objects
    used by this feature from this version on comm requires at least Tcl 8\.3 to
    run\. Please read the section [Asynchronous Result
    Generation](#subsection13) for more details\.

  - 4\.4\.1

    Bugfix in the execution of hooks\.

  - 4\.4

    Bugfixes in the handling of \-interp for regular and hook scripts\. Bugfixes
    in channel cleanup\.

  - 4\.3\.1

    Introduced \-interp and \-events to enable easy use of a slave interp for
    execution of received scripts, and of event scripts\.

  - 4\.3

    Bugfixes, and introduces \-silent to allow the user to force the
    server/listening side to silently ignore connection attempts where the
    protocol negotiation failed\.

  - 4\.2

    Bugfixes, and most important, switched to utf\-8 as default encoding for full
    i18n without any problems\.

  - 4\.1

    Rewrite of internal code to remove old pseudo\-object model\. Addition of send
    \-command asynchronous callback option\.

  - 4\.0

    Per request by John LoVerso\. Improved handling of error for async invoked
    commands\.

  - 3\.7

    Moved into tcllib and placed in a proper namespace\.

  - 3\.6

    A bug in the looking up of the remoteid for a executed command could be
    triggered when the connection was closed while several asynchronous sends
    were queued to be executed\.

  - 3\.5

    Internal change to how reply messages from a
    __[send](\.\./\.\./\.\./\.\./index\.md\#send)__ are handled\. Reply messages
    are now decoded into the *value* to pass to
    __[return](\.\./\.\./\.\./\.\./index\.md\#return)__; a new return statement is
    then cons'd up to with this value\. Previously, the return code was passed in
    from the remote as a command to evaluate\. Since the wire protocol has not
    changed, this is still the case\. Instead, the reply handling code decodes
    the __reply__ message\.

  - 3\.4

    Added more source commentary, as well as documenting config variables in
    this man page\. Fixed bug were loss of connection would give error about a
    variable named __pending__ rather than the message about the lost
    connection\. __comm ids__ is now an alias for __comm interps__
    \(previously, it an alias for __comm chans__\)\. Since the method
    invocation change of 3\.0, break and other exceptional conditions were not
    being returned correctly from __comm send__\. This has been fixed by
    removing the extra level of indirection into the internal procedure
    __commSend__\. Also added propagation of the *errorCode* variable\. This
    means that these commands return exactly as they would with
    __[send](\.\./\.\./\.\./\.\./index\.md\#send)__:

    comm send id break
    catch {comm send id break}
    comm send id expr 1 / 0

    Added a new hook for reply messages\. Reworked method invocation to avoid the
    use of comm:\* procedures; this also cut the invocation time down by 40%\.
    Documented __comm config__ \(as this manual page still listed the defunct
    __comm init__\!\)

  - 3\.3

    Some minor bugs were corrected and the documentation was cleaned up\. Added
    some examples for hooks\. The return semantics of the __eval__ hook were
    changed\.

  - 3\.2

    A new wire protocol, version 3, was added\. This is backwards compatible with
    version 2 but adds an exchange of supported protocol versions to allow
    protocol negotiation in the future\. Several bugs with the hook
    implementation were fixed\. A new section of the man page on blocking
    semantics was added\.

  - 3\.1

    All the documented hooks were implemented\. __commLostHook__ was removed\.
    A bug in __comm new__ was fixed\.

  - 3\.0

    This is a new version of __comm__ with several major changes\. There is a
    new way of creating the methods available under the __comm__ command\.
    The __comm init__ method has been retired and is replaced by __comm
    configure__ which allows access to many of the well\-defined internal
    variables\. This also generalizes the options available to __comm new__\.
    Finally, there is now a protocol version exchanged when a connection is
    established\. This will allow for future on\-wire protocol changes\. Currently,
    the protocol version is set to 2\.

  - 2\.3

    __comm ids__ was renamed to __comm channels__\. General support for
    __comm hook__ was fully implemented, but only the *lost* hook exists,
    and it was changed to follow the general hook API\. __commLostHook__ was
    unsupported \(replaced by __comm hook lost__\) and __commLost__ was
    removed\.

  - 2\.2

    The *died* hook was renamed *lost*, to be accessed by
    __commLostHook__ and an early implementation of __comm lost hook__\.
    As such, __commDied__ is now __commLost__\.

  - 2\.1

    Unsupported method __comm remoteid__ was added\.

  - 2\.0

    __comm__ has been rewritten from scratch \(but is fully compatible with
    Comm 1\.0, without the requirement to use obTcl\)\.

# <a name='section2'></a>TLS Security Considerations

This package uses the __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package to
handle the security for __https__ urls and other socket connections\.

Policy decisions like the set of protocols to support and what ciphers to use
are not the responsibility of __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__, nor
of this package itself however\. Such decisions are the responsibility of
whichever application is using the package, and are likely influenced by the set
of servers the application will talk to as well\.

For example, in light of the recent [POODLE
attack](http://googleonlinesecurity\.blogspot\.co\.uk/2014/10/this\-poodle\-bites\-exploiting\-ssl\-30\.html)
discovered by Google many servers will disable support for the SSLv3 protocol\.
To handle this change the applications using
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ must be patched, and not this
package, nor __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ itself\. Such a patch
may be as simple as generally activating __tls1__ support, as shown in the
example below\.

    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...

# <a name='section3'></a>Author

John LoVerso, John@LoVerso\.Southborough\.MA\.US

*http://www\.opengroup\.org/~loverso/tcl\-tk/\#comm*

# <a name='section4'></a>License

Please see the file *comm\.LICENSE* that accompanied this source, or
[http://www\.opengroup\.org/www/dist\_client/caubweb/COPYRIGHT\.free\.html](http://www\.opengroup\.org/www/dist\_client/caubweb/COPYRIGHT\.free\.html)\.

This license for __comm__, new as of version 3\.2, allows it to be used for
free, without any licensing fee or royalty\.

# <a name='section5'></a>Bugs

  - If there is a failure initializing a channel created with __::comm::comm
    new__, then the channel should be destroyed\. Currently, it is left in an
    inconsistent state\.

  - There should be a way to force a channel to quiesce when changing the
    configuration\.

The following items can be implemented with the existing hooks and are listed
here as a reminder to provide a sample hook in a future version\.

  - Allow easier use of a slave interp for actual command execution \(especially
    when operating in "not local" mode\)\.

  - Add host list \(xhost\-like\) or "magic cookie" \(xauth\-like\) authentication to
    initial handshake\.

The following are outstanding todo items\.

  - Add an interp discovery and name\->port mapping\. This is likely to be in a
    separate, optional nameserver\. \(See also the related work, below\.\)

  - Fix the *\{id host\}* form so as not to be dependent upon canonical
    hostnames\. This requires fixes to Tcl to resolve hostnames\!

This man page is bigger than the source file\.

# <a name='section6'></a>On Using Old Versions Of Tcl

Tcl7\.5 under Windows contains a bug that causes the interpreter to hang when EOF
is reached on non\-blocking sockets\. This can be triggered with a command such as
this:

    "comm send $other exit"

Always make sure the channel is quiescent before closing/exiting or use at least
Tcl7\.6 under Windows\.

Tcl7\.6 on the Mac contains several bugs\. It is recommended you use at least
Tcl7\.6p2\.

Tcl8\.0 on UNIX contains a socket bug that can crash Tcl\. It is recommended you
use Tcl8\.0p1 \(or Tcl7\.6p2\)\.

# <a name='section7'></a>Related Work

Tcl\-DP provides an RPC\-based remote execution interface, but is a compiled Tcl
extension\. See
[http://www\.cs\.cornell\.edu/Info/Projects/zeno/Projects/Tcl\-DP\.html](http://www\.cs\.cornell\.edu/Info/Projects/zeno/Projects/Tcl\-DP\.html)\.

Michael Doyle <miked@eolas\.com> has code that implements the Tcl\-DP RPC
interface using standard Tcl sockets, much like __comm__\. The DpTcl package
is available at
[http://chiselapp\.com/user/gwlester/repository/DpTcl](http://chiselapp\.com/user/gwlester/repository/DpTcl)\.

Andreas Kupries <andreas\_kupries@users\.sourceforge\.net> uses __comm__ and
has built a simple nameserver as part of his Pool library\. See
[http://www\.purl\.org/net/akupries/soft/pool/index\.htm](http://www\.purl\.org/net/akupries/soft/pool/index\.htm)\.

# <a name='section8'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *comm* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

send\(n\)

# <a name='keywords'></a>KEYWORDS

[comm](\.\./\.\./\.\./\.\./index\.md\#comm),
[communication](\.\./\.\./\.\./\.\./index\.md\#communication),
[ipc](\.\./\.\./\.\./\.\./index\.md\#ipc),
[message](\.\./\.\./\.\./\.\./index\.md\#message), [remote
communication](\.\./\.\./\.\./\.\./index\.md\#remote\_communication), [remote
execution](\.\./\.\./\.\./\.\./index\.md\#remote\_execution),
[rpc](\.\./\.\./\.\./\.\./index\.md\#rpc), [secure](\.\./\.\./\.\./\.\./index\.md\#secure),
[send](\.\./\.\./\.\./\.\./index\.md\#send),
[socket](\.\./\.\./\.\./\.\./index\.md\#socket), [ssl](\.\./\.\./\.\./\.\./index\.md\#ssl),
[tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 1995\-1998 The Open Group\. All Rights Reserved\.  
Copyright &copy; 2003\-2004 ActiveState Corporation\.  
Copyright &copy; 2006\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
