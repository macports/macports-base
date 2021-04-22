
[//000000001]: # (grammar::me::cpu::core \- Grammar operations and usage)
[//000000002]: # (Generated from file 'me\_cpucore\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005\-2006 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me::cpu::core\(n\) 0\.2 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me::cpu::core \- ME virtual machine state manipulation

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [MATCH PROGRAM REPRESENTATION](#subsection1)

  - [CPU STATE](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require grammar::me::cpu::core ?0\.2?  

[__::grammar::me::cpu::core__ __disasm__ *asm*](#1)  
[__::grammar::me::cpu::core__ __asm__ *asm*](#2)  
[__::grammar::me::cpu::core__ __new__ *asm*](#3)  
[__::grammar::me::cpu::core__ __lc__ *state* *location*](#4)  
[__::grammar::me::cpu::core__ __tok__ *state* ?*from* ?*to*??](#5)  
[__::grammar::me::cpu::core__ __pc__ *state*](#6)  
[__::grammar::me::cpu::core__ __iseof__ *state*](#7)  
[__::grammar::me::cpu::core__ __at__ *state*](#8)  
[__::grammar::me::cpu::core__ __cc__ *state*](#9)  
[__::grammar::me::cpu::core__ __sv__ *state*](#10)  
[__::grammar::me::cpu::core__ __ok__ *state*](#11)  
[__::grammar::me::cpu::core__ __error__ *state*](#12)  
[__::grammar::me::cpu::core__ __lstk__ *state*](#13)  
[__::grammar::me::cpu::core__ __astk__ *state*](#14)  
[__::grammar::me::cpu::core__ __mstk__ *state*](#15)  
[__::grammar::me::cpu::core__ __estk__ *state*](#16)  
[__::grammar::me::cpu::core__ __rstk__ *state*](#17)  
[__::grammar::me::cpu::core__ __nc__ *state*](#18)  
[__::grammar::me::cpu::core__ __ast__ *state*](#19)  
[__::grammar::me::cpu::core__ __halted__ *state*](#20)  
[__::grammar::me::cpu::core__ __code__ *state*](#21)  
[__::grammar::me::cpu::core__ __eof__ *statevar*](#22)  
[__::grammar::me::cpu::core__ __put__ *statevar* *tok* *lex* *line* *col*](#23)  
[__::grammar::me::cpu::core__ __run__ *statevar* ?*n*?](#24)  

# <a name='description'></a>DESCRIPTION

This package provides an implementation of the ME virtual machine\. Please go and
read the document __[grammar::me\_intro](me\_intro\.md)__ first if you do
not know what a ME virtual machine is\.

This implementation represents each ME virtual machine as a Tcl value and
provides commands to manipulate and query such values to show the effects of
executing instructions, adding tokens, retrieving state, etc\.

The values fully follow the paradigm of Tcl that every value is a string and
while also allowing C implementations for a proper Tcl\_ObjType to keep all the
important data in native data structures\. Because of the latter it is
recommended to access the state values *only* through the commands of this
package to ensure that internal representation is not shimmered away\.

The actual structure used by all state values is described in section [CPU
STATE](#section3)\.

# <a name='section2'></a>API

The package directly provides only a single command, and all the functionality
is made available through its methods\.

  - <a name='1'></a>__::grammar::me::cpu::core__ __disasm__ *asm*

    This method returns a list containing a disassembly of the match
    instructions in *asm*\. The format of *asm* is specified in the section
    [MATCH PROGRAM REPRESENTATION](#subsection1)\.

    Each element of the result contains instruction label, instruction name, and
    the instruction arguments, in this order\. The label can be the empty string\.
    Jump destinations are shown as labels, strings and tokens unencoded\. Token
    names are prefixed with their numeric id, if, and only if a tokmap is
    defined\. The two components are separated by a colon\.

  - <a name='2'></a>__::grammar::me::cpu::core__ __asm__ *asm*

    This method returns code in the format as specified in section [MATCH
    PROGRAM REPRESENTATION](#subsection1) generated from ME assembly code
    *asm*, which is in the format as returned by the method __disasm__\.

  - <a name='3'></a>__::grammar::me::cpu::core__ __new__ *asm*

    This method creates state value for a ME virtual machine in its initial
    state and returns it as its result\.

    The argument *matchcode* contains a Tcl representation of the match
    instructions the machine has to execute while parsing the input stream\. Its
    format is specified in the section [MATCH PROGRAM
    REPRESENTATION](#subsection1)\.

    The *tokmap* argument taken by the implementation provided by the package
    __[grammar::me::tcl](me\_tcl\.md)__ is here hidden inside of the match
    instructions and therefore not needed\.

  - <a name='4'></a>__::grammar::me::cpu::core__ __lc__ *state* *location*

    This method takes the state value of a ME virtual machine and uses it to
    convert a location in the input stream \(as offset\) into a line number and
    column index\. The result of the method is a 2\-element list containing the
    two pieces in the order mentioned in the previous sentence\.

    *Note* that the method cannot convert locations which the machine has not
    yet read from the input stream\. In other words, if the machine has read 7
    characters so far it is possible to convert the offsets __0__ to
    __6__, but nothing beyond that\. This also shows that it is not possible
    to convert offsets which refer to locations before the beginning of the
    stream\.

    This utility allows higher levels to convert the location offsets found in
    the error status and the AST into more human readable data\.

  - <a name='5'></a>__::grammar::me::cpu::core__ __tok__ *state* ?*from* ?*to*??

    This method takes the state value of a ME virtual machine and returns a Tcl
    list containing the part of the input stream between the locations *from*
    and *to* \(both inclusive\)\. If *to* is not specified it will default to
    the value of *from*\. If *from* is not specified either the whole input
    stream is returned\.

    This method places the same restrictions on its location arguments as the
    method __lc__\.

  - <a name='6'></a>__::grammar::me::cpu::core__ __pc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current value of the stored program counter\.

  - <a name='7'></a>__::grammar::me::cpu::core__ __iseof__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current value of the stored eof flag\.

  - <a name='8'></a>__::grammar::me::cpu::core__ __at__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current location in the input stream\.

  - <a name='9'></a>__::grammar::me::cpu::core__ __cc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current token\.

  - <a name='10'></a>__::grammar::me::cpu::core__ __sv__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current semantic value stored in it\. This is an abstract syntax tree as
    specified in the document __[grammar::me\_ast](me\_ast\.md)__, section
    __AST VALUES__\.

  - <a name='11'></a>__::grammar::me::cpu::core__ __ok__ *state*

    This method takes the state value of a ME virtual machine and returns the
    match status stored in it\.

  - <a name='12'></a>__::grammar::me::cpu::core__ __error__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current error status stored in it\.

  - <a name='13'></a>__::grammar::me::cpu::core__ __lstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    location stack\.

  - <a name='14'></a>__::grammar::me::cpu::core__ __astk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    AST stack\.

  - <a name='15'></a>__::grammar::me::cpu::core__ __mstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    AST marker stack\.

  - <a name='16'></a>__::grammar::me::cpu::core__ __estk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    error stack\.

  - <a name='17'></a>__::grammar::me::cpu::core__ __rstk__ *state*

    This method takes the state value of a ME virtual machine and returns the
    subroutine return stack\.

  - <a name='18'></a>__::grammar::me::cpu::core__ __nc__ *state*

    This method takes the state value of a ME virtual machine and returns the
    nonterminal match cache as a dictionary\.

  - <a name='19'></a>__::grammar::me::cpu::core__ __ast__ *state*

    This method takes the state value of a ME virtual machine and returns the
    abstract syntax tree currently at the top of the AST stack stored in it\.
    This is an abstract syntax tree as specified in the document
    __[grammar::me\_ast](me\_ast\.md)__, section __AST VALUES__\.

  - <a name='20'></a>__::grammar::me::cpu::core__ __halted__ *state*

    This method takes the state value of a ME virtual machine and returns the
    current halt status stored in it, i\.e\. if the machine has stopped or not\.

  - <a name='21'></a>__::grammar::me::cpu::core__ __code__ *state*

    This method takes the state value of a ME virtual machine and returns the
    code stored in it, i\.e\. the instructions executed by the machine\.

  - <a name='22'></a>__::grammar::me::cpu::core__ __eof__ *statevar*

    This method takes the state value of a ME virtual machine as stored in the
    variable named by *statevar* and modifies it so that the eof flag inside
    is set\. This signals to the machine that whatever token are in the input
    queue are the last to be processed\. There will be no more\.

  - <a name='23'></a>__::grammar::me::cpu::core__ __put__ *statevar* *tok* *lex* *line* *col*

    This method takes the state value of a ME virtual machine as stored in the
    variable named by *statevar* and modifies it so that the token *tok* is
    added to the end of the input queue, with associated lexeme data *lex* and
    *line*/*col*umn information\.

    The operation will fail with an error if the eof flag of the machine has
    been set through the method __eof__\.

  - <a name='24'></a>__::grammar::me::cpu::core__ __run__ *statevar* ?*n*?

    This method takes the state value of a ME virtual machine as stored in the
    variable named by *statevar*, executes a number of instructions and stores
    the state resulting from their modifications back into the variable\.

    The execution loop will run until either

      * *n* instructions have been executed, or

      * a halt instruction was executed, or

      * the input queue is empty and the code is asking for more tokens to
        process\.

    If no limit *n* was set only the last two conditions are checked for\.

## <a name='subsection1'></a>MATCH PROGRAM REPRESENTATION

A match program is represented by nested Tcl list\. The first element, *asm*,
is a list of integer numbers, the instructions to execute, and their arguments\.
The second element, *[pool](\.\./\.\./\.\./\.\./index\.md\#pool)*, is a list of
strings, referenced by the instructions, for error messages, token names, etc\.
The third element, *tokmap*, provides ordering information for the tokens,
mapping their names to their numerical rank\. This element can be empty, forcing
lexicographic comparison when matching ranges\.

All ME instructions are encoded as integer numbers, with the mapping given
below\. A number of the instructions, those which handle error messages, have
been given an additional argument to supply that message explicitly instead of
having it constructed from token names, etc\. This allows the machine state to
store only the message ids instead of the full strings\.

Jump destination arguments are absolute indices into the *asm* element,
refering to the instruction to jump to\. Any string arguments are absolute
indices into the *[pool](\.\./\.\./\.\./\.\./index\.md\#pool)* element\. Tokens,
characters, messages, and token \(actually character\) classes to match are coded
as references into the *[pool](\.\./\.\./\.\./\.\./index\.md\#pool)* as well\.

  1. "__ict\_advance__ *message*"

  1. "__ict\_match\_token__ *tok* *message*"

  1. "__ict\_match\_tokrange__ *tokbegin* *tokend* *message*"

  1. "__ict\_match\_tokclass__ *code* *message*"

  1. "__inc\_restore__ *branchlabel* *nt*"

  1. "__inc\_save__ *nt*"

  1. "__icf\_ntcall__ *branchlabel*"

  1. "__icf\_ntreturn__"

  1. "__iok\_ok__"

  1. "__iok\_fail__"

  1. "__iok\_negate__"

  1. "__icf\_jalways__ *branchlabel*"

  1. "__icf\_jok__ *branchlabel*"

  1. "__icf\_jfail__ *branchlabel*"

  1. "__icf\_halt__"

  1. "__icl\_push__"

  1. "__icl\_rewind__"

  1. "__icl\_pop__"

  1. "__ier\_push__"

  1. "__ier\_clear__"

  1. "__ier\_nonterminal__ *message*"

  1. "__ier\_merge__"

  1. "__isv\_clear__"

  1. "__isv\_terminal__"

  1. "__isv\_nonterminal\_leaf__ *nt*"

  1. "__isv\_nonterminal\_range__ *nt*"

  1. "__isv\_nonterminal\_reduce__ *nt*"

  1. "__ias\_push__"

  1. "__ias\_mark__"

  1. "__ias\_mrewind__"

  1. "__ias\_mpop__"

# <a name='section3'></a>CPU STATE

A state value is a list containing the following elements, in the order listed
below:

  1. *code*: Match instructions, see [MATCH PROGRAM
     REPRESENTATION](#subsection1)\.

  1. *pc*: Program counter, *int*\.

  1. *halt*: Halt flag, *boolean*\.

  1. *eof*: Eof flag, *boolean*

  1. *tc*: Terminal cache, and input queue\. Structure see below\.

  1. *cl*: Current location, *int*\.

  1. *ct*: Current token, *[string](\.\./\.\./\.\./\.\./index\.md\#string)*\.

  1. *ok*: Match status, *boolean*\.

  1. *sv*: Semantic value, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *er*: Error status, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *ls*: Location stack, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *as*: AST stack, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *ms*: AST marker stack, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *es*: Error stack, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *rs*: Return stack, *[list](\.\./\.\./\.\./\.\./index\.md\#list)*\.

  1. *nc*: Nonterminal cache, *dictionary*\.

*tc*, the input queue of tokens waiting for processing and the terminal cache
containing the tokens already processing are one unified data structure simply
holding all tokens and their information, with the current location separating
that which has been processed from that which is waiting\. Each element of the
queue/cache is a list containing the token, its lexeme information, line number,
and column index, in this order\.

All stacks have their top element aat the end, i\.e\. pushing an item is
equivalent to appending to the list representing the stack, and popping it
removes the last element\.

*er*, the error status is either empty or a list of two elements, a location
in the input, and a list of messages, encoded as references into the
*[pool](\.\./\.\./\.\./\.\./index\.md\#pool)* element of the *code*\.

*nc*, the nonterminal cache is keyed by nonterminal name and location, each
value a four\-element list containing current location, match status, semantic
value, and error status, in this order\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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
