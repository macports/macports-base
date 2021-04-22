
[//000000001]: # (wip \- Word Interpreter)
[//000000002]: # (Generated from file 'wip\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007\-2010 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (wip\(n\) 2\.2 tcllib "Word Interpreter")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

wip \- Word Interpreter

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [GENERAL BEHAVIOUR](#section2)

  - [CLASS API](#section3)

  - [OBJECT API](#section4)

  - [EXAMPLES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require wip ?2\.2?  
package require snit ?1\.3?  
package require struct::set  

[__::wip__ *wipName* *engine* *arg*\.\.\.](#1)  
[__def__ *name*](#2)  
[__def__ *name* *method\_prefix*](#3)  
[__wipName__ *option* ?*arg arg \.\.\.*?](#4)  
[__wip::dsl__ ?*suffix*?](#5)  
[*wipName* __def__ *name* ?*method\_prefix*?](#6)  
[*wipName* __defl__ *names*](#7)  
[*wipName* __defd__ *dict*](#8)  
[*wipName* __deflva__ *name*\.\.\.](#9)  
[*wipName* __defdva__ \(*name* *method\_prefix*\)\.\.\.](#10)  
[*wipName* __undefl__ *names*](#11)  
[*wipName* __undefva__ *name*\.\.\.](#12)  
[*wipName* __unknown__ *cmdprefix*](#13)  
[*wipName* __runl__ *wordlist*](#14)  
[*wipName* __run__ *word*\.\.\.](#15)  
[*wipName* __run\_next__](#16)  
[*wipName* __run\_next\_while__ *acceptable*](#17)  
[*wipName* __run\_next\_until__ *rejected*](#18)  
[*wipName* __run\_next\_if__ *acceptable*](#19)  
[*wipName* __run\_next\_ifnot__ *rejected*](#20)  
[*wipName* __next__](#21)  
[*wipName* __peek__](#22)  
[*wipName* __peekall__](#23)  
[*wipName* __insertl__ *at* *wordlist*](#24)  
[*wipName* __replacel__ *wordlist*](#25)  
[*wipName* __pushl__ *wordlist*](#26)  
[*wipName* __addl__ *wordlist*](#27)  
[*wipName* __insert__ *at* *word*\.\.\.](#28)  
[*wipName* __replace__ *word*\.\.\.](#29)  
[*wipName* __push__ *word*\.\.\.](#30)  
[*wipName* __add__ *word*\.\.\.](#31)  

# <a name='description'></a>DESCRIPTION

This package provides a micro interpreter for lists of words\. Domain specific
languages based on this will have a bit of a Forth feel, with the input stream
segmented into words and any other structuring left to whatever the language
desired\. Note that we have here in essence only the core dispatch loop, and no
actual commands whatsoever, making this definitely only a Forth feel and not an
actual Forth\.

The idea is derived from Colin McCormack's
__[treeql](\.\./treeql/treeql\.md)__ processor, modified to require less
boiler plate within the command implementations, at the expense of, likely,
execution speed\. In addition the interface between processor core and commands
is more complex too\.

# <a name='section2'></a>GENERAL BEHAVIOUR

Word interpreters have a mappping from the names of the language commands they
shall recognize to the methods in the engine to invoke for them, and possibly
fixed arguments for these methods\. This mapping is largely static, however it is
possible to change it during the execution of a word list \(= program\)\.

At the time a language command is defined the word interpreter will use
__[snit](\.\./snit/snit\.md)__'s introspection capabilities to determine
the number of arguments expected by the method of the egnine, and together with
the number of fixed arguments supplied in the method prefix of the mapping it
then knows how many arguments the language command is expecting\. This is the
command's *arity*\. Variable\-argument methods \(i\.e\. with the last argument
named *args*\) are *not* allowed and will cause the word interpreter to throw
an error at definition time\.

Note that while I said __[snit](\.\./snit/snit\.md)__'s abilities the
engine object can be written in any way, as long as it understands the method
__info args__, which takes a method name and returns the list of arguments
for that method\.

When executing a list of words \(aka program\) the first word is always taken as
the name of a language command, and the next words as its arguments, per the
*arity* of the command\. Command and argument words are removed from the list
and then associated method of the engine is executed with the argument words\.
The process then repeats using the then\-first word of the list\.

Note that the methods implementing the language commands may have full access to
the list of words and are allowed to manipulate as they see fit\.

  1. This means, for example, that while we cannot specify variable\-argument
     methods directly they can consume words after their fixed arguments before
     returning to the execution loop\. This may be under the control of their
     fixed arguments\.

  1. Another possibility is the use of method __run\_next__ and its variants
     to execute commands coming after the current command, changing the order of
     execution\.

  1. Execution can be further changed by use of the program accessor methods
     which allow a command implementation to modify the remaining list of words
     \(insert, replace, prepend, append words\) without executing them
     immediately\.

  1. At last the basic __run__ methods save and restore an existing list of
     words when used, enabling recursive use from within command
     implementations\.

# <a name='section3'></a>CLASS API

The main command of the package is:

  - <a name='1'></a>__::wip__ *wipName* *engine* *arg*\.\.\.

    The command creates a new word interpreter object with an associated global
    Tcl command whose name is *wipName*\. If however the string __%AUTO%__
    was used as object name the package will generate its own unique name for
    the object\.

    The *engine* is the object the word interpreter will dispatch all
    recognized commands to, and the *arg*uments are a word list which defines
    an initial mapping from language words to engine methods\.

    The recognized language of this word list is

      * <a name='2'></a>__def__ *name*

        Defines *name* as command of the language, to be mapped to a method of
        the *engine* having the same name\.

      * <a name='3'></a>__def__ *name* *method\_prefix*

        Defines *name* as command of the language, to be mapped to the method
        of the *engine* named in the *method\_prefix*\.

    The returned command may be used to invoke various operations on the object\.
    It has the following general form:

      * <a name='4'></a>__wipName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

The package additionally exports the command:

  - <a name='5'></a>__wip::dsl__ ?*suffix*?

    This command is for use within snit types which wish to use one or more wip
    interpreters as a component\. Use within the type definition installs most of
    the boilerplate needed to setup and use a word interpreter\.

    It installs a component named *wip*, and a method __wip\_setup__ for
    initializing it\. This method has to be called from within the constructor of
    the type using the word interpreter\. If further installs a series of
    procedures which make the object API of the word interpreter directly
    available to the type's methods, without having to specify the component\.

    *Note* that this does and cannot install the language to interpret, i\.e\.
    the mapping from words to engine methods\.

    It is possible to instantiate multiple word interpreter components within a
    type by using different suffices as arguments to the command\. In that case
    the name of the component changes to 'wip\___$suffix__', the setup
    command becomes 'wip\___$suffix__\_setup' and all the procedures also get
    the suffix '\___$suffix__'\.

# <a name='section4'></a>OBJECT API

The following commands are possible for word interpreter objects:

  - <a name='6'></a>*wipName* __def__ *name* ?*method\_prefix*?

    Defines a language command *name* and maps it to the method named in the
    engine's *method\_prefix*\. If the *method\_prefix* name is not specified
    it is simply the name of the language command\.

  - <a name='7'></a>*wipName* __defl__ *names*

    Defines a series of language commands, specified through the list of
    *names*, all of which are mapped to engine methods of the same name\.

  - <a name='8'></a>*wipName* __defd__ *dict*

    Defines a series of language commands, specified through the dictionary
    *dict* of names and method prefixes\.

  - <a name='9'></a>*wipName* __deflva__ *name*\.\.\.

    As method __defl__, however the list of names is specified through
    multiple arguments\.

  - <a name='10'></a>*wipName* __defdva__ \(*name* *method\_prefix*\)\.\.\.

    As method __defd__, however the dictionary of names and method prefixes
    is specified through multiple arguments\.

  - <a name='11'></a>*wipName* __undefl__ *names*

    Removes the named series of language commands from the mapping\.

  - <a name='12'></a>*wipName* __undefva__ *name*\.\.\.

    As method __undefl__, however the list of names is specified through
    multiple arguments\.

  - <a name='13'></a>*wipName* __unknown__ *cmdprefix*

    Sets the handler for unknown words to *cmdprefix*\. This command prefix
    takes one argument, the current word, and either throws some error, or
    returns the result of executing the word, as defined by the handler\. The
    default handler simply throws an error\.

  - <a name='14'></a>*wipName* __runl__ *wordlist*

    Treats the list of words in *wordlist* as a program and executes the
    contained command one by one\. The result of the command executed last is
    returned as the result of this command\.

    The *wordlist* is stored in the object for access by the other
    *run*\-methods, and the general program accessor methods \(see below\)\. A
    previously stored wordlist is saved during the execution of this method and
    restored before it returns\. This enables the recursive execution of word
    lists within word lists\.

  - <a name='15'></a>*wipName* __run__ *word*\.\.\.

    As method __runl__, however the list of words to execute is specified
    through multiple arguments\.

  - <a name='16'></a>*wipName* __run\_next__

    Low\-level method\. Determines the next word in the list of words, and its
    arguments, and then executes it\. The result of the executed word is the
    result of this method\.

    Exposed for use within command implementations\. The methods __run__ and
    __runl__ use it to execute words until their word list is exhausted\.

  - <a name='17'></a>*wipName* __run\_next\_while__ *acceptable*

    Low\-level method\. Invokes the method __run\_next__ as long as the next
    word is in the set of *acceptable* words, and the program is not empty\.
    The result of the command executed last is returned as the result of this
    command\.

    Exposed for use within command implementations to change the order of
    execution\.

  - <a name='18'></a>*wipName* __run\_next\_until__ *rejected*

    Low\-level method\. Invokes the method __run\_next__ until the next word is
    in the set of *rejected* words, and the program is not empty\. The result
    of the command executed last is returned as the result of this command\.

    Exposed for use within command implementations to change the order of
    execution\.

  - <a name='19'></a>*wipName* __run\_next\_if__ *acceptable*

    Low\-level method\. Invokes the method __run\_next__ if the next word is in
    the set of *acceptable* words, and the program is not empty\. The result of
    the command executed last is returned as the result of this command\.

    Exposed for use within command implementations to change the order of
    execution\.

  - <a name='20'></a>*wipName* __run\_next\_ifnot__ *rejected*

    Low\-level method\. Invokes the method __run\_next__ if the next word is
    not in the set of *rejected* words, and the program is not empty\. The
    result of the command executed last is returned as the result of this
    command\.

    Exposed for use within command implementations to change the order of
    execution\.

  - <a name='21'></a>*wipName* __next__

    Returns the next word in the programm\. The word is also removed\.

  - <a name='22'></a>*wipName* __peek__

    Returns the next word in the programm without removing it

  - <a name='23'></a>*wipName* __peekall__

    Returns the remaining programm in toto\.

  - <a name='24'></a>*wipName* __insertl__ *at* *wordlist*

    Basic programm accessor method\. Inserts the specified *wordlist* into the
    program, just before the word at position *at*\. Positions are counted from
    __zero__\.

  - <a name='25'></a>*wipName* __replacel__ *wordlist*

    Basic programm accessor method\. Replaces the whole stored program with the
    specified *wordlist*\.

  - <a name='26'></a>*wipName* __pushl__ *wordlist*

    Program accessor method\. The specified *wordlist* is added to the front of
    the remaining program\. Equivalent to

        $wip insertl 0 $wordlist

  - <a name='27'></a>*wipName* __addl__ *wordlist*

    Program accessor method\. The specified *wordlist* is appended at the end
    of the remaining program\. Equivalent to

        $wip insertl end $wordlist

  - <a name='28'></a>*wipName* __insert__ *at* *word*\.\.\.

    Like method __insertl__, except the words are specified through multiple
    arguments\.

  - <a name='29'></a>*wipName* __replace__ *word*\.\.\.

    Like method __setl__, except the words are specified through multiple
    arguments\.

  - <a name='30'></a>*wipName* __push__ *word*\.\.\.

    Like method __pushl__, except the words are specified through multiple
    arguments\.

  - <a name='31'></a>*wipName* __add__ *word*\.\.\.

    Like method __addl__, except the words are specified through multiple
    arguments\.

# <a name='section5'></a>EXAMPLES

No examples yet\.

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *wip* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[interpreter](\.\./\.\./\.\./\.\./index\.md\#interpreter),
[list](\.\./\.\./\.\./\.\./index\.md\#list), [word](\.\./\.\./\.\./\.\./index\.md\#word)

# <a name='category'></a>CATEGORY

Programming tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007\-2010 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
