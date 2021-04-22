
[//000000001]: # (grammar::fa::dacceptor \- Finite automaton operations and usage)
[//000000002]: # (Generated from file 'dacceptor\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::fa::dacceptor\(n\) 0\.1\.1 tcllib "Finite automaton operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::fa::dacceptor \- Create and use deterministic acceptors

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [ACCEPTOR METHODS](#section3)

  - [EXAMPLES](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require struct::set  
package require grammar::fa::dacceptor ?0\.1\.1?  

[__::grammar::fa::dacceptor__ *daName* *fa* ?__\-any__ *any*?](#1)  
[__daName__ *option* ?*arg arg \.\.\.*?](#2)  
[*daName* __destroy__](#3)  
[*daName* __accept?__ *symbols*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a class for acceptors constructed from deterministic
*finite automatons* \(DFA\)\. Acceptors are objects which can be given a string
of symbols and tell if the DFA they are constructed from would *accept* that
string\. For the actual creation of the DFAs the acceptors are based on we have
the packages __[grammar::fa](fa\.md)__ and
__[grammar::fa::op](faop\.md)__\.

# <a name='section2'></a>API

The package exports the API described here\.

  - <a name='1'></a>__::grammar::fa::dacceptor__ *daName* *fa* ?__\-any__ *any*?

    Creates a new deterministic acceptor with an associated global Tcl command
    whose name is *daName*\. This command may be used to invoke various
    operations on the acceptor\. It has the following general form:

      * <a name='2'></a>__daName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.
        See section [ACCEPTOR METHODS](#section3) for more explanations\.

        The acceptor will be based on the deterministic finite automaton stored
        in the object *fa*\. It will keep a copy of the relevant data of the FA
        in its own storage, in a form easy to use for its purposes\. This also
        means that changes made to the *fa* after the construction of the
        acceptor *will not* influence the acceptor\.

        If *any* has been specified, then the acceptor will convert all
        symbols in the input which are unknown to the base FA to that symbol
        before proceeding with the processing\.

# <a name='section3'></a>ACCEPTOR METHODS

All acceptors provide the following methods for their manipulation:

  - <a name='3'></a>*daName* __destroy__

    Destroys the automaton, including its storage space and associated command\.

  - <a name='4'></a>*daName* __accept?__ *symbols*

    Takes the list of *symbols* and checks if the FA the acceptor is based on
    would accept it\. The result is a boolean value\. __True__ is returned if
    the symbols are accepted, and __False__ otherwise\. Note that bogus
    symbols in the input are either translated to the *any* symbol \(if
    specified\), or cause the acceptance test to simply fail\. No errors will be
    thrown\. The method will process only just that prefix of the input which is
    enough to fully determine \(non\-\)acceptance\.

# <a name='section4'></a>EXAMPLES

# <a name='section5'></a>Bugs, Ideas, Feedback

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

[acceptance](\.\./\.\./\.\./\.\./index\.md\#acceptance),
[acceptor](\.\./\.\./\.\./\.\./index\.md\#acceptor),
[automaton](\.\./\.\./\.\./\.\./index\.md\#automaton), [finite
automaton](\.\./\.\./\.\./\.\./index\.md\#finite\_automaton),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [regular
expression](\.\./\.\./\.\./\.\./index\.md\#regular\_expression), [regular
grammar](\.\./\.\./\.\./\.\./index\.md\#regular\_grammar), [regular
languages](\.\./\.\./\.\./\.\./index\.md\#regular\_languages),
[state](\.\./\.\./\.\./\.\./index\.md\#state),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2004 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
