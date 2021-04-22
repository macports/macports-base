
[//000000001]: # (grammar::me::cpu \- Grammar operations and usage)
[//000000002]: # (Generated from file 'me\_cpu\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me::cpu\(n\) 0\.2 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me::cpu \- Virtual machine implementation II for parsing token streams

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [CLASS API](#subsection1)

      - [OBJECT API](#subsection2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require grammar::me::cpu ?0\.2?  

[__::grammar::me::cpu__ *meName* *matchcode*](#1)  
[__meName__ __option__ ?*arg arg \.\.\.*?](#2)  
[*meName* __lc__ *location*](#3)  
[*meName* __tok__ ?*from* ?*to*??](#4)  
[*meName* __pc__ *state*](#5)  
[*meName* __iseof__ *state*](#6)  
[*meName* __at__ *state*](#7)  
[*meName* __cc__ *state*](#8)  
[*meName* __sv__](#9)  
[*meName* __ok__](#10)  
[*meName* __error__](#11)  
[*meName* __lstk__ *state*](#12)  
[*meName* __astk__ *state*](#13)  
[*meName* __mstk__ *state*](#14)  
[*meName* __estk__ *state*](#15)  
[*meName* __rstk__ *state*](#16)  
[*meName* __nc__ *state*](#17)  
[*meName* __ast__](#18)  
[*meName* __halted__](#19)  
[*meName* __code__](#20)  
[*meName* __eof__](#21)  
[*meName* __put__ *tok* *lex* *line* *col*](#22)  
[*meName* __putstring__ *string* *lvar* *cvar*](#23)  
[*meName* __run__ ?*n*?](#24)  
[*meName* __pull__ *nextcmd*](#25)  
[*meName* __reset__](#26)  
[*meName* __destroy__](#27)  

# <a name='description'></a>DESCRIPTION

This package provides an implementation of the ME virtual machine\. Please go and
read the document __[grammar::me\_intro](me\_intro\.md)__ first if you do
not know what a ME virtual machine is\.

This implementation provides an object\-based API and the machines are not truly
tied to Tcl\. A C implementation of the same API is quite possible\.

Internally the package actually uses the value\-based machine manipulation
commands as provided by the package
__[grammar::me::cpu::core](me\_cpucore\.md)__ to perform its duties\.

# <a name='section2'></a>API

## <a name='subsection1'></a>CLASS API

The package directly provides only a single command for the construction of ME
virtual machines\.

  - <a name='1'></a>__::grammar::me::cpu__ *meName* *matchcode*

    The command creates a new ME machine object with an associated global Tcl
    command whose name is *meName*\. This command may be used to invoke various
    operations on the machine\. It has the following general form:

      * <a name='2'></a>__meName__ __option__ ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

    The argument *matchcode* contains the match instructions the machine has
    to execute while parsing the input stream\. Please read section __MATCH
    CODE REPRESENTATION__ of the documentation for the package
    __[grammar::me::cpu::core](me\_cpucore\.md)__ for the specification of
    the structure of this value\.

    The *tokmap* argument taken by the implementation provided by the package
    __[grammar::me::tcl](me\_tcl\.md)__ is here hidden inside of the match
    instructions and therefore not needed\.

## <a name='subsection2'></a>OBJECT API

All ME virtual machine objects created by the class command specified in section
[CLASS API](#subsection1) support the methods listed below\.

The machines provided by this package provide methods for operation in both
push\- and pull\-styles\. Push\-style means that tokens are pushed into the machine
state when they arrive, triggering further execution until they are consumed\. In
other words, this allows the machine to be suspended and resumed at will and an
arbitrary number of times, the quasi\-parallel operation of several machines, and
the operation as part of the event loop\.

  - <a name='3'></a>*meName* __lc__ *location*

    This method converts the location of a token given as offset in the input
    stream into the associated line number and column index\. The result of the
    command is a 2\-element list containing the two values, in the order
    mentioned in the previous sentence\. This allows higher levels to convert the
    location information found in the error status and the generated AST into
    more human readable data\.

    *Note* that the command is not able to convert locations which have not
    been reached by the machine yet\. In other words, if the machine has read 7
    tokens the command is able to convert the offsets __0__ to __6__,
    but nothing beyond that\. This also shows that it is not possible to convert
    offsets which refer to locations before the beginning of the stream\.

  - <a name='4'></a>*meName* __tok__ ?*from* ?*to*??

    This method returns a Tcl list containing the part of the input stream
    between the locations *from* and *to* \(both inclusive\)\. If *to* is not
    specified it will default to the value of *from*\. If *from* is not
    specified either the whole input stream is returned\.

    Each element of the returned list is a list of four elements, the token, its
    associated lexeme, line number, and column index, in this order\. This
    command places the same restrictions on its location arguments as the method
    __lc__\.

  - <a name='5'></a>*meName* __pc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current value of the stored program counter\.

  - <a name='6'></a>*meName* __iseof__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current value of the stored eof flag\.

  - <a name='7'></a>*meName* __at__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current location in the input stream\.

  - <a name='8'></a>*meName* __cc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current token\.

  - <a name='9'></a>*meName* __sv__

    This command returns the current semantic value *SV* stored in the
    machine\. This is an abstract syntax tree as specified in the document
    __[grammar::me\_ast](me\_ast\.md)__, section __AST VALUES__\.

  - <a name='10'></a>*meName* __ok__

    This method returns the current match status *OK*\.

  - <a name='11'></a>*meName* __error__

    This method returns the current error status *ER*\.

  - <a name='12'></a>*meName* __lstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    location stack\.

  - <a name='13'></a>*meName* __astk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    AST stack\.

  - <a name='14'></a>*meName* __mstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    AST marker stack\.

  - <a name='15'></a>*meName* __estk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    error stack\.

  - <a name='16'></a>*meName* __rstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    subroutine return stack\.

  - <a name='17'></a>*meName* __nc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    nonterminal match cache as a dictionary\.

  - <a name='18'></a>*meName* __ast__

    This method returns the current top entry of the AST stack *AS*\. This is
    an abstract syntax tree as specified in the document
    __[grammar::me\_ast](me\_ast\.md)__, section __AST VALUES__\.

  - <a name='19'></a>*meName* __halted__

    This method returns a boolean value telling the caller whether the engine
    has halted execution or not\. Halt means that no further matching is
    possible, and the information retrieved via the other method is final\.
    Attempts to __run__ the engine will be ignored, until a __reset__ is
    made\.

  - <a name='20'></a>*meName* __code__

    This method returns the *code* information used to construct the object\.
    In other words, the match program executed by the machine\.

  - <a name='21'></a>*meName* __eof__

    This method adds an end of file marker to the end of the input stream\. This
    signals the machine that the current contents of the input queue are the
    final parts of the input and nothing will come after\. Attempts to put more
    characters into the queue will fail\.

  - <a name='22'></a>*meName* __put__ *tok* *lex* *line* *col*

    This method adds the token *tok* to the end of the input stream, with
    associated lexeme data *lex* and *line*/*col*umn information\.

  - <a name='23'></a>*meName* __putstring__ *string* *lvar* *cvar*

    This method adds each individual character in the *string* as a token to
    the end of the input stream, from first to last\. The lexemes will be empty
    and the line/col information is computed based on the characters encountered
    and the data in the variables *lvar* and *cvar*\.

  - <a name='24'></a>*meName* __run__ ?*n*?

    This methods causes the engine to execute match instructions until either

      * *n* instructions have been executed, or

      * a halt instruction was executed, or

      * the input queue is empty and the code is asking for more tokens to
        process\.

    If no limit *n* was set only the last two conditions are checked for\.

  - <a name='25'></a>*meName* __pull__ *nextcmd*

    This method implements pull\-style operation of the machine\. It causes it to
    execute match instructions until either a halt instruction is reached, or
    the command prefix *nextcmd* ceases to deliver more tokens\.

    The command prefix *nextcmd* represents the input stream of characters and
    is invoked by the machine whenever the a new character from the stream is
    required\. The instruction for handling this is *ict\_advance*\. The callback
    has to return either the empty list, or a list of 4 elements containing the
    token, its lexeme attribute, and its location as line number and column
    index, in this order\. The empty list is the signal that the end of the input
    stream has been reached\. The lexeme attribute is stored in the terminal
    cache, but otherwise not used by the machine\.

    The end of the input stream for this method does not imply that method
    __eof__ is called for the machine as a whole\. By avoiding this and still
    asking for an explicit call of the method it is possible to mix push\- and
    pull\-style operation during the lifetime of the machine\.

  - <a name='26'></a>*meName* __reset__

    This method resets the machine to its initial state, discarding any state it
    may have\.

  - <a name='27'></a>*meName* __destroy__

    This method deletes the object and releases all resurces it claimed\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_me* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005\-2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
