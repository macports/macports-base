
[//000000001]: # (grammar::fa::dexec \- Finite automaton operations and usage)
[//000000002]: # (Generated from file 'dexec\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (Copyright &copy; 2007 Bogdan <rftghost@users\.sourceforge\.net>)
[//000000005]: # (grammar::fa::dexec\(n\) 0\.2 tcllib "Finite automaton operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::fa::dexec \- Execute deterministic finite automatons

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [EXECUTOR METHODS](#section3)

  - [EXECUTOR CALLBACK](#section4)

  - [EXAMPLES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require grammar::fa::dexec ?0\.2?  

[__::grammar::fa::dexec__ *daName* *fa* ?__\-any__ *any*? ?__\-command__ *cmdprefix*?](#1)  
[__daName__ *option* ?*arg arg \.\.\.*?](#2)  
[*daName* __destroy__](#3)  
[*daName* __put__ *symbol*](#4)  
[*daName* __reset__](#5)  
[*daName* __state__](#6)  
[*cmdprefix* __error__ *code* *message*](#7)  
[*cmdprefix* __final__ *stateid*](#8)  
[*cmdprefix* __reset__](#9)  
[*cmdprefix* __state__ *stateid*](#10)  

# <a name='description'></a>DESCRIPTION

This package provides a class for executors constructed from deterministic
*finite automatons* \(DFA\)\. Executors are objects which are given a string of
symbols in a piecemal fashion, perform state transitions and report back when
they enter a final state, or find an error in the input\. For the actual creation
of the DFAs the executors are based on we have the packages
__[grammar::fa](fa\.md)__ and __[grammar::fa::op](faop\.md)__\.

The objects follow a push model\. Symbols are pushed into the executor, and when
something important happens, i\.e\. error occurs, a state transition, or a final
state is entered this will be reported via the callback specified via the option
__\-command__\. Note that conversion of this into a pull model where the
environment retrieves messages from the object and the object uses a callback to
ask for more symbols is a trivial thing\.

*Side note*: The acceptor objects provided by
__[grammar::fa::dacceptor](dacceptor\.md)__ could have been implemented
on top of the executors provided here, but were not, to get a bit more
performance \(we avoid a number of method calls and the time required for their
dispatch\)\.

# <a name='section2'></a>API

The package exports the API described here\.

  - <a name='1'></a>__::grammar::fa::dexec__ *daName* *fa* ?__\-any__ *any*? ?__\-command__ *cmdprefix*?

    Creates a new deterministic executor with an associated global Tcl command
    whose name is *daName*\. This command may be used to invoke various
    operations on the executor\. It has the following general form:

      * <a name='2'></a>__daName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.
        See section [EXECUTOR METHODS](#section3) for more explanations\.

        The executor will be based on the deterministic finite automaton stored
        in the object *fa*\. It will keep a copy of the relevant data of the FA
        in its own storage, in a form easy to use for its purposes\. This also
        means that changes made to the *fa* after the construction of the
        executor *will not* influence the executor\.

        If *any* has been specified, then the executor will convert all
        symbols in the input which are unknown to the base FA to that symbol
        before proceeding with the processing\.

# <a name='section3'></a>EXECUTOR METHODS

All executors provide the following methods for their manipulation:

  - <a name='3'></a>*daName* __destroy__

    Destroys the automaton, including its storage space and associated command\.

  - <a name='4'></a>*daName* __put__ *symbol*

    Takes the current state of the executor and the *symbol* and performs the
    appropriate state transition\. Reports any errors encountered via the command
    callback, as well as entering a final state of the underlying FA\.

    When an error is reported all further invokations of __put__ will do
    nothing, until the error condition has been cleared via an invokation of
    method __reset__\.

  - <a name='5'></a>*daName* __reset__

    Unconditionally sets the executor into the start state of the underlying FA\.
    This also clears any error condition __put__ may have encountered\.

  - <a name='6'></a>*daName* __state__

    Returns the current state of the underlying FA\. This allow for introspection
    without the need to pass data from the callback command\.

# <a name='section4'></a>EXECUTOR CALLBACK

The callback command *cmdprefix* given to an executor via the option
__\-command__ will be executed by the object at the global level, using the
syntax described below\. Note that *cmdprefix* is not simply the name of a
command, but a full command prefix\. In other words it may contain additional
fixed argument words beyond the command word\.

  - <a name='7'></a>*cmdprefix* __error__ *code* *message*

    The executor has encountered an error, and *message* contains a
    human\-readable text explaining the nature of the problem\. The *code* on
    the other hand is a fixed machine\-readable text\. The following error codes
    can be generated by executor objects\.

      * __BADSYM__

        An unknown symbol was found in the input\. This can happen if and only if
        no __\-any__ symbol was specified\.

      * __BADTRANS__

        The underlying FA has no transition for the current combination of input
        symbol and state\. In other words, the executor was not able to compute a
        new state for this combination\.

  - <a name='8'></a>*cmdprefix* __final__ *stateid*

    The executor has entered the final state *stateid*\.

  - <a name='9'></a>*cmdprefix* __reset__

    The executor was reset\.

  - <a name='10'></a>*cmdprefix* __state__ *stateid*

    The FA changed state due to a transition\. *stateid* is the new state\.

# <a name='section5'></a>EXAMPLES

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_fa* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[automaton](\.\./\.\./\.\./\.\./index\.md\#automaton),
[execution](\.\./\.\./\.\./\.\./index\.md\#execution), [finite
automaton](\.\./\.\./\.\./\.\./index\.md\#finite\_automaton),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [regular
expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression), [regular
grammar](\.\./\.\./\.\./\.\./index\.md\#regular\_grammar), [regular
languages](\.\./\.\./\.\./\.\./index\.md\#regular\_languages),
[running](\.\./\.\./\.\./\.\./index\.md\#running),
[state](\.\./\.\./\.\./\.\./index\.md\#state),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>  
Copyright &copy; 2007 Bogdan <rftghost@users\.sourceforge\.net>
