
[//000000001]: # (pt::rde \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_rdengine\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::rde\(n\) 1\.1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::rde \- Parsing Runtime Support, PARAM based

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [Class API](#subsection1)

      - [Object API](#subsection2)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require pt::rde ?1\.1?  
package require snit  
package require struct::stack 1\.5  
package require pt::ast 1\.1  

[__::pt::rde__ *objectName*](#1)  
[*objectName* __destroy__](#2)  
[*objectName* __reset__ *chan*](#3)  
[*objectName* __complete__](#4)  
[*objectName* __chan__](#5)  
[*objectName* __line__](#6)  
[*objectName* __column__](#7)  
[*objectName* __current__](#8)  
[*objectName* __location__](#9)  
[*objectName* __locations__](#10)  
[*objectName* __ok__](#11)  
[*objectName* __value__](#12)  
[*objectName* __error__](#13)  
[*objectName* __errors__](#14)  
[*objectName* __tokens__ ?*from* ?*to*??](#15)  
[*objectName* __symbols__](#16)  
[*objectName* __known__](#17)  
[*objectName* __reducible__](#18)  
[*objectName* __asts__](#19)  
[*objectName* __ast__](#20)  
[*objectName* __position__ *loc*](#21)  
[*objectName* __i\_input\_next__ *msg*](#22)  
[*objectName* __i\_test\_alnum__](#23)  
[*objectName* __i\_test\_alpha__](#24)  
[*objectName* __i\_test\_ascii__](#25)  
[*objectName* __i\_test\_char__ *char*](#26)  
[*objectName* __i\_test\_ddigit__](#27)  
[*objectName* __i\_test\_digit__](#28)  
[*objectName* __i\_test\_graph__](#29)  
[*objectName* __i\_test\_lower__](#30)  
[*objectName* __i\_test\_print__](#31)  
[*objectName* __i\_test\_punct__](#32)  
[*objectName* __i\_test\_range__ *chars* *chare*](#33)  
[*objectName* __i\_test\_space__](#34)  
[*objectName* __i\_test\_upper__](#35)  
[*objectName* __i\_test\_wordchar__](#36)  
[*objectName* __i\_test\_xdigit__](#37)  
[*objectName* __i\_error\_clear__](#38)  
[*objectName* __i\_error\_push__](#39)  
[*objectName* __i\_error\_pop\_merge__](#40)  
[*objectName* __i\_error\_nonterminal__ *symbol*](#41)  
[*objectName* __i\_status\_ok__](#42)  
[*objectName* __i\_status\_fail__](#43)  
[*objectName* __i\_status\_negate__](#44)  
[*objectName* __i\_loc\_push__](#45)  
[*objectName* __i\_loc\_pop\_discard__](#46)  
[*objectName* __i\_loc\_pop\_rewind__](#47)  
[*objectName* __i:ok\_loc\_pop\_rewind__](#48)  
[*objectName* __i\_loc\_pop\_rewind/discard__](#49)  
[*objectName* __i\_symbol\_restore__ *symbol*](#50)  
[*objectName* __i\_symbol\_save__ *symbol*](#51)  
[*objectName* __i\_value\_clear__](#52)  
[*objectName* __i\_value\_clear/leaf__](#53)  
[*objectName* __i\_value\_clear/reduce__](#54)  
[*objectName* __i:ok\_ast\_value\_push__](#55)  
[*objectName* __i\_ast\_push__](#56)  
[*objectName* __i\_ast\_pop\_rewind__](#57)  
[*objectName* __i:fail\_ast\_pop\_rewind__](#58)  
[*objectName* __i\_ast\_pop\_rewind/discard__](#59)  
[*objectName* __i\_ast\_pop\_discard__](#60)  
[*objectName* __i\_ast\_pop\_discard/rewind__](#61)  
[*objectName* __i:ok\_continue__](#62)  
[*objectName* __i:fail\_continue__](#63)  
[*objectName* __i:fail\_return__](#64)  
[*objectName* __i:ok\_return__](#65)  
[*objectName* __si:void\_state\_push__](#66)  
[*objectName* __si:void2\_state\_push__](#67)  
[*objectName* __si:value\_state\_push__](#68)  
[*objectName* __si:void\_state\_merge__](#69)  
[*objectName* __si:void\_state\_merge\_ok__](#70)  
[*objectName* __si:value\_state\_merge__](#71)  
[*objectName* __si:value\_notahead\_start__](#72)  
[*objectName* __si:void\_notahead\_exit__](#73)  
[*objectName* __si:value\_notahead\_exit__](#74)  
[*objectName* __si:kleene\_abort__](#75)  
[*objectName* __si:kleene\_close__](#76)  
[*objectName* __si:voidvoid\_branch__](#77)  
[*objectName* __si:voidvalue\_branch__](#78)  
[*objectName* __si:valuevoid\_branch__](#79)  
[*objectName* __si:valuevalue\_branch__](#80)  
[*objectName* __si:voidvoid\_part__](#81)  
[*objectName* __si:voidvalue\_part__](#82)  
[*objectName* __si:valuevalue\_part__](#83)  
[*objectName* __si:value\_symbol\_start__ *symbol*](#84)  
[*objectName* __si:value\_void\_symbol\_start__ *symbol*](#85)  
[*objectName* __si:void\_symbol\_start__ *symbol*](#86)  
[*objectName* __si:void\_void\_symbol\_start__ *symbol*](#87)  
[*objectName* __si:reduce\_symbol\_end__ *symbol*](#88)  
[*objectName* __si:void\_leaf\_symbol\_end__ *symbol*](#89)  
[*objectName* __si:value\_leaf\_symbol\_end__ *symbol*](#90)  
[*objectName* __si:value\_clear\_symbol\_end__ *symbol*](#91)  
[*objectName* __si:void\_clear\_symbol\_end__ *symbol*](#92)  
[*objectName* __si:next\_char__ *tok*](#93)  
[*objectName* __si:next\_range__ *toks* *toke*](#94)  
[*objectName* __si:next\_alnum__](#95)  
[*objectName* __si:next\_alpha__](#96)  
[*objectName* __si:next\_ascii__](#97)  
[*objectName* __si:next\_ddigit__](#98)  
[*objectName* __si:next\_digit__](#99)  
[*objectName* __si:next\_graph__](#100)  
[*objectName* __si:next\_lower__](#101)  
[*objectName* __si:next\_print__](#102)  
[*objectName* __si:next\_punct__](#103)  
[*objectName* __si:next\_space__](#104)  
[*objectName* __si:next\_upper__](#105)  
[*objectName* __si:next\_wordchar__](#106)  
[*objectName* __si:next\_xdigit__](#107)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

This package provides a class whose instances provide the runtime support for
recursive descent parsers with backtracking, as is needed for the execution of,
for example, parsing expression grammars\. It implements the *[PackRat Machine
Specification](pt\_param\.md)*, as such that document is *required* reading
to understand both this manpage, and the package itself\. The description below
does make numerous shorthand references to the PARAM's instructions and the
various parts of its architectural state\.

The package resides in the Execution section of the Core Layer of Parser Tools\.

![](\.\./\.\./\.\./\.\./image/arch\_core\_transform\.png)

Note: This package not only has the standard Tcl implementation, but also an
accelerator, i\.e\. a C implementation, based on Critcl\.

## <a name='subsection1'></a>Class API

The package exports the API described here\.

  - <a name='1'></a>__::pt::rde__ *objectName*

    The command creates a new runtime object for a recursive descent parser with
    backtracking and returns the fully qualified name of the object command as
    its result\. The API of this object command is described in the section
    [Object API](#subsection2)\. It may be used to invoke various operations
    on the object\.

## <a name='subsection2'></a>Object API

All objects created by this package provide the following 63 methods for the
manipulation and querying of their state, which is, in essence the architectural
state of a PARAM\.

First some general methods and the state accessors\.

  - <a name='2'></a>*objectName* __destroy__

    This method destroys the object, releasing all claimed memory, and deleting
    the associated object command\.

  - <a name='3'></a>*objectName* __reset__ *chan*

    This method resets the state of the runtme to its defaults, preparing it for
    the parsing of the character in the channel *chan*, which becomes IN\.

    Note here that the Parser Tools are based on Tcl 8\.5\+\. In other words, the
    channel argument is not restricted to files, sockets, etc\. We have the full
    power of *reflected channels* available\.

    It should also be noted that the parser pulls the characters from the input
    stream as it needs them\. If a parser created by this package has to be
    operated in a push aka event\-driven manner it will be necessary to go to Tcl
    8\.6\+ and use the __[coroutine::auto](\.\./coroutine/coro\_auto\.md)__ to
    wrap it into a coroutine where __[read](\.\./\.\./\.\./\.\./index\.md\#read)__
    is properly changed for push\-operation\.

  - <a name='4'></a>*objectName* __complete__

    This method completes parsing, either returning the AST made from the
    elements of ARS, or throwing an error containing the current ER\.

  - <a name='5'></a>*objectName* __chan__

    This method returns the handle of the channel which is IN\.

  - <a name='6'></a>*objectName* __line__

    This method returns the line number for the position IN is currently at\.
    Note that this may not match with the line number for CL, due to
    backtracking\.

  - <a name='7'></a>*objectName* __column__

    This method returns the column for the position IN is currently at\. Note
    that this may not match with the column for CL, due to backtracking\.

  - <a name='8'></a>*objectName* __current__

    This method returns CC\.

  - <a name='9'></a>*objectName* __location__

    This method returns CL\.

  - <a name='10'></a>*objectName* __locations__

    This method returns the LS\. The topmost entry of the stack will be the first
    element of the returned list\.

  - <a name='11'></a>*objectName* __ok__

    This method returns ST\.

  - <a name='12'></a>*objectName* __value__

    This method returns SV\.

  - <a name='13'></a>*objectName* __error__

    This method returns ER\. This is either the empty string for an empty ER, or
    a list of 2 elements, the location the error is for, and a set of messages
    which specify which symbols were expected at the location\. The messages are
    encoded as one of the possible atomic parsing expressions \(special
    operators, terminal, range, and nonterminal operator\)\.

  - <a name='14'></a>*objectName* __errors__

    This method returns ES\. The topmost entry of the stack will be the first
    element of the returned list\. Each entry is encoded as described for
    __error__\.

  - <a name='15'></a>*objectName* __tokens__ ?*from* ?*to*??

    This method returns the part of TC for the range of locations of IN starting
    at *from* and ending at *to*\. If *to* is not specified it is taken as
    identical to *from*\. If neither argument is specified the whole of TC is
    returned\.

    Each token in the returned list is a list of three elements itself,
    containing the character at the location, and the associated line and column
    numbers, in this order\.

  - <a name='16'></a>*objectName* __symbols__

    This method returns a dictionary containing NC\. Keys are two\-element lists
    containing nonterminal symbol and location, in this order\. The values are
    4\-tuples containing CL, ST, ER, and SV, in this order\. ER is encoded as
    specified for the method __error__\.

  - <a name='17'></a>*objectName* __known__

    This method returns a list containing the keys of SC\. They are encoded in
    the same manner as is done by method __symbols__\.

  - <a name='18'></a>*objectName* __reducible__

    This method returns ARS\. The topmost entry of the stack will be the first
    element of the returned list

  - <a name='19'></a>*objectName* __asts__

    This method returns AS\. The topmost entry of the stack will be the first
    element of the returned list

  - <a name='20'></a>*objectName* __ast__

    This is a convenience method returning the topmost element of ARS\.

  - <a name='21'></a>*objectName* __position__ *loc*

    This method returns the line and column numbers for the specified location
    of IN, assuming that this location has already been reached during the
    parsing process\.

The following methods implement all PARAM instructions\. They all have the prefix
"i\_"\.

The control flow is mainly provided by Tcl's builtin commands, like __if__,
__while__, etc\., plus a few guarded variants of PARAM instructions and Tcl
commands\.\. That means that these instruction variants will do nothing if their
guard condition is not fulfilled\. They can be recognized by the prefix "i:ok\_"
and "i:fail\_", which denote the value ST has to have for the instruction to
execute\.

The instructions are listed in the same order they occur in the *[PackRat
Machine Specification](pt\_param\.md)*, with the guard variants listed after
their regular implementation, if any, or in their place\.

  - <a name='22'></a>*objectName* __i\_input\_next__ *msg*

    This method implements the PARAM instruction __input\_next__\.

  - <a name='23'></a>*objectName* __i\_test\_alnum__

    This method implements the PARAM instruction __test\_alnum__\.

  - <a name='24'></a>*objectName* __i\_test\_alpha__

    This method implements the PARAM instruction __test\_alpha__\.

  - <a name='25'></a>*objectName* __i\_test\_ascii__

    This method implements the PARAM instruction __test\_ascii__\.

  - <a name='26'></a>*objectName* __i\_test\_char__ *char*

    This method implements the PARAM instruction __test\_char__\.

  - <a name='27'></a>*objectName* __i\_test\_ddigit__

    This method implements the PARAM instruction __test\_ddigit__\.

  - <a name='28'></a>*objectName* __i\_test\_digit__

    This method implements the PARAM instruction __test\_digit__\.

  - <a name='29'></a>*objectName* __i\_test\_graph__

    This method implements the PARAM instruction __test\_graph__\.

  - <a name='30'></a>*objectName* __i\_test\_lower__

    This method implements the PARAM instruction __test\_lower__\.

  - <a name='31'></a>*objectName* __i\_test\_print__

    This method implements the PARAM instruction __test\_print__\.

  - <a name='32'></a>*objectName* __i\_test\_punct__

    This method implements the PARAM instruction __test\_punct__\.

  - <a name='33'></a>*objectName* __i\_test\_range__ *chars* *chare*

    This method implements the PARAM instruction __test\_range__\.

  - <a name='34'></a>*objectName* __i\_test\_space__

    This method implements the PARAM instruction __test\_space__\.

  - <a name='35'></a>*objectName* __i\_test\_upper__

    This method implements the PARAM instruction __test\_upper__\.

  - <a name='36'></a>*objectName* __i\_test\_wordchar__

    This method implements the PARAM instruction __test\_wordchar__\.

  - <a name='37'></a>*objectName* __i\_test\_xdigit__

    This method implements the PARAM instruction __test\_xdigit__\.

  - <a name='38'></a>*objectName* __i\_error\_clear__

    This method implements the PARAM instruction __error\_clear__\.

  - <a name='39'></a>*objectName* __i\_error\_push__

    This method implements the PARAM instruction __error\_push__\.

  - <a name='40'></a>*objectName* __i\_error\_pop\_merge__

    This method implements the PARAM instruction __error\_pop\_merge__\.

  - <a name='41'></a>*objectName* __i\_error\_nonterminal__ *symbol*

    This method implements the PARAM instruction __error\_nonterminal__\.

  - <a name='42'></a>*objectName* __i\_status\_ok__

    This method implements the PARAM instruction __status\_ok__\.

  - <a name='43'></a>*objectName* __i\_status\_fail__

    This method implements the PARAM instruction __status\_fail__\.

  - <a name='44'></a>*objectName* __i\_status\_negate__

    This method implements the PARAM instruction __status\_negate__\.

  - <a name='45'></a>*objectName* __i\_loc\_push__

    This method implements the PARAM instruction __loc\_push__\.

  - <a name='46'></a>*objectName* __i\_loc\_pop\_discard__

    This method implements the PARAM instruction __loc\_pop\_discard__\.

  - <a name='47'></a>*objectName* __i\_loc\_pop\_rewind__

    This method implements the PARAM instruction __loc\_pop\_rewind__\.

  - <a name='48'></a>*objectName* __i:ok\_loc\_pop\_rewind__

    This guarded method, a variant of __i\_loc\_pop\_rewind__, executes only
    for "ST == ok"\.

  - <a name='49'></a>*objectName* __i\_loc\_pop\_rewind/discard__

    This method is a convenient combination of control flow and the two PARAM
    instructions __loc\_pop\_rewind__ and __loc\_pop\_discard__\. The former
    is executed for "ST == fail", the latter for "ST == ok"\.

  - <a name='50'></a>*objectName* __i\_symbol\_restore__ *symbol*

    This method implements the PARAM instruction __symbol\_restore__\.

    The boolean result of the check is returned as the result of the method and
    can be used with standard Tcl control flow commands\.

  - <a name='51'></a>*objectName* __i\_symbol\_save__ *symbol*

    This method implements the PARAM instruction __symbol\_save__\.

  - <a name='52'></a>*objectName* __i\_value\_clear__

    This method implements the PARAM instruction __value\_clear__\.

  - <a name='53'></a>*objectName* __i\_value\_clear/leaf__

    This method is a convenient combination of control flow and the two PARAM
    instructions __value\_clear__ and __value\_leaf__\. The former is
    executed for "ST == fail", the latter for "ST == ok"\.

  - <a name='54'></a>*objectName* __i\_value\_clear/reduce__

    This method is a convenient combination of control flow and the two PARAM
    instructions __value\_clear__ and __value\_reduce__\. The former is
    executed for "ST == fail", the latter for "ST == ok"\.

  - <a name='55'></a>*objectName* __i:ok\_ast\_value\_push__

    This method implements a guarded variant of the the PARAM instruction
    __ast\_value\_push__, which executes only for "ST == ok"\.

  - <a name='56'></a>*objectName* __i\_ast\_push__

    This method implements the PARAM instruction __ast\_push__\.

  - <a name='57'></a>*objectName* __i\_ast\_pop\_rewind__

    This method implements the PARAM instruction __ast\_pop\_rewind__\.

  - <a name='58'></a>*objectName* __i:fail\_ast\_pop\_rewind__

    This guarded method, a variant of __i\_ast\_pop\_rewind__, executes only
    for "ST == fail"\.

  - <a name='59'></a>*objectName* __i\_ast\_pop\_rewind/discard__

    This method is a convenient combination of control flow and the two PARAM
    instructions __ast\_pop\_rewind__ and __ast\_pop\_discard__\. The former
    is executed for "ST == fail", the latter for "ST == ok"\.

  - <a name='60'></a>*objectName* __i\_ast\_pop\_discard__

    This method implements the PARAM instruction __ast\_pop\_discard__\.

  - <a name='61'></a>*objectName* __i\_ast\_pop\_discard/rewind__

    This method is a convenient combination of control flow and the two PARAM
    instructions __ast\_pop\_discard__ and __ast\_pop\_rewind__\. The former
    is executed for "ST == fail", the latter for "ST == ok"\.

  - <a name='62'></a>*objectName* __i:ok\_continue__

    This guarded method executes only for "ST == ok"\. Then it aborts the current
    iteration of the innermost loop in the calling Tcl procedure\.

  - <a name='63'></a>*objectName* __i:fail\_continue__

    This guarded method executes only for "ST == fail"\. Then it aborts the
    current iteration of the innermost loop in the calling Tcl procedure\.

  - <a name='64'></a>*objectName* __i:fail\_return__

    This guarded method executes only for "ST == fail"\. Then it aborts the
    calling Tcl procedure\.

  - <a name='65'></a>*objectName* __i:ok\_return__

    This guarded method executes only for "ST == ok"\. Then it aborts the calling
    Tcl procedure\.

The next set of methods are *super instructions*, meaning that each implements
a longer sequence of instructions commonly used in parsers\. The combinated
instructions of the previous set, i\.e\. those with names matching the pattern
"i\_\*/\*", are actually super instructions as well, albeit with limited scope,
handling 2 instructions with their control flow\. The upcoming set is much
broader in scope, folding as much as six or more PARAM instructions into a
single method call\.

In this we can see the reasoning behind their use well:

  1. By using less instructions the generated parsers become smaller, as the
     common parts are now truly part of the common runtime, and not explicitly
     written in the parser's code over and over again\.

  1. Using less instructions additionally reduces the overhead associated with
     calls into the runtime, i\.e\. the cost of method dispatch and of setting up
     the variable context\.

  1. Another effect of the super instructions is that their internals can be
     optimized as well, especially regarding control flow, and stack use, as the
     runtime internals are accessible to all instructions folded into the
     sequence\.

  - <a name='66'></a>*objectName* __si:void\_state\_push__

    This method combines

        i_loc_push
        i_error_clear
        i_error_push

    Parsers use it at the beginning of *void* sequences and choices with a
    *void* initial branch\.

  - <a name='67'></a>*objectName* __si:void2\_state\_push__

    This method combines

        i_loc_push
        i_error_clear
        i_error_push

    Parsers use it at the beginning of optional and repeated expressions\.

  - <a name='68'></a>*objectName* __si:value\_state\_push__

    This method combines

        i_ast_push
        i_loc_push
        i_error_clear
        i_error_push

    Parsers use it at the beginning of sequences generating an AST and choices
    with an initial branch generating an AST\.

  - <a name='69'></a>*objectName* __si:void\_state\_merge__

    This method combines

        i_error_pop_merge
        i_loc_pop_rewind/discard

    Parsers use it at the end of void sequences and choices whose last branch is
    void\.

  - <a name='70'></a>*objectName* __si:void\_state\_merge\_ok__

    This method combines

        i_error_pop_merge
        i_loc_pop_rewind/discard
        i_status_ok

    Parsers use it at the end of optional expressions

  - <a name='71'></a>*objectName* __si:value\_state\_merge__

    This method combines

        i_error_pop_merge
        i_ast_pop_rewind/discard
        i_loc_pop_rewind/discard

    Parsers use it at the end of sequences generating ASTs and choices whose
    last branch generates an AST

  - <a name='72'></a>*objectName* __si:value\_notahead\_start__

    This method combines

        i_loc_push
        i_ast_push

    Parsers use it at the beginning of negative lookahead predicates which
    generate ASTs\.

  - <a name='73'></a>*objectName* __si:void\_notahead\_exit__

    This method combines

        i_loc_pop_rewind
        i_status_negate

    Parsers use it at the end of void negative lookahead predicates\.

  - <a name='74'></a>*objectName* __si:value\_notahead\_exit__

    This method combines

        i_ast_pop_discard/rewind
        i_loc_pop_rewind
        i_status_negate

    Parsers use it at the end of negative lookahead predicates which generate
    ASTs\.

  - <a name='75'></a>*objectName* __si:kleene\_abort__

    This method combines

        i_loc_pop_rewind/discard
        i:fail_return

    Parsers use it to stop a positive repetition when its first, required,
    expression fails\.

  - <a name='76'></a>*objectName* __si:kleene\_close__

    This method combines

        i_error_pop_merge
        i_loc_pop_rewind/discard
        i:fail_status_ok
        i:fail_return

    Parsers use it at the end of repetitions\.

  - <a name='77'></a>*objectName* __si:voidvoid\_branch__

    This method combines

        i_error_pop_merge
        i:ok_loc_pop_discard
        i:ok_return
        i_loc_rewind
        i_error_push

    Parsers use it when transiting between branches of a choice when both are
    void\.

  - <a name='78'></a>*objectName* __si:voidvalue\_branch__

    This method combines

        i_error_pop_merge
        i:ok_loc_pop_discard
        i:ok_return
        i_ast_push
        i_loc_rewind
        i_error_push

    Parsers use it when transiting between branches of a choice when the failing
    branch is void, and the next to test generates an AST\.

  - <a name='79'></a>*objectName* __si:valuevoid\_branch__

    This method combines

        i_error_pop_merge
        i_ast_pop_rewind/discard
        i:ok_loc_pop_discard
        i:ok_return
        i_loc_rewind
        i_error_push

    Parsers use it when transiting between branches of a choice when the failing
    branch generates an AST, and the next to test is void\.

  - <a name='80'></a>*objectName* __si:valuevalue\_branch__

    This method combines

        i_error_pop_merge
        i_ast_pop_discard
        i:ok_loc_pop_discard
        i:ok_return
        i_ast_rewind
        i_loc_rewind
        i_error_push

    Parsers use it when transiting between branches of a choice when both
    generate ASTs\.

  - <a name='81'></a>*objectName* __si:voidvoid\_part__

    This method combines

        i_error_pop_merge
        i:fail_loc_pop_rewind
        i:fail_return
        i_error_push

    Parsers use it when transiting between parts of a sequence and both are
    void\.

  - <a name='82'></a>*objectName* __si:voidvalue\_part__

    This method combines

        i_error_pop_merge
        i:fail_loc_pop_rewind
        i:fail_return
        i_ast_push
        i_error_push

    Parsers use it when transiting between parts of a sequence and the
    sucessfully matched part is void, and after it an AST is generated\.

  - <a name='83'></a>*objectName* __si:valuevalue\_part__

    This method combines

        i_error_pop_merge
        i:fail_ast_pop_rewind
        i:fail_loc_pop_rewind
        i:fail_return
        i_error_push

    Parsers use it when transiting between parts of a sequence and both parts
    generate ASTs\.

  - <a name='84'></a>*objectName* __si:value\_symbol\_start__ *symbol*

    This method combines

        if/found? i_symbol_restore $symbol
        i:found:ok_ast_value_push
        i:found_return
        i_loc_push
        i_ast_push

    Parsers use it at the beginning of a nonterminal symbol generating an AST,
    whose right\-hand side may have generated an AST as well\.

  - <a name='85'></a>*objectName* __si:value\_void\_symbol\_start__ *symbol*

    This method combines

        if/found? i_symbol_restore $symbol
        i:found:ok_ast_value_push
        i:found_return
        i_loc_push
        i_ast_push

    Parsers use it at the beginning of a void nonterminal symbol whose
    right\-hand side may generate an AST\.

  - <a name='86'></a>*objectName* __si:void\_symbol\_start__ *symbol*

    This method combines

        if/found? i_symbol_restore $symbol
        i:found_return
        i_loc_push
        i_ast_push

    Parsers use it at the beginning of a nonterminal symbol generating an AST
    whose right\-hand side is void\.

  - <a name='87'></a>*objectName* __si:void\_void\_symbol\_start__ *symbol*

    This method combines

        if/found? i_symbol_restore $symbol
        i:found_return
        i_loc_push

    Parsers use it at the beginning of a void nonterminal symbol whose
    right\-hand side is void as well\.

  - <a name='88'></a>*objectName* __si:reduce\_symbol\_end__ *symbol*

    This method combines

        i_value_clear/reduce $symbol
        i_symbol_save        $symbol
        i_error_nonterminal  $symbol
        i_ast_pop_rewind
        i_loc_pop_discard
        i:ok_ast_value_push

    Parsers use it at the end of a non\-terminal symbol generating an AST using
    the AST generated by the right\-hand side as child\.

  - <a name='89'></a>*objectName* __si:void\_leaf\_symbol\_end__ *symbol*

    This method combines

        i_value_clear/leaf  $symbol
        i_symbol_save       $symbol
        i_error_nonterminal $symbol
        i_loc_pop_discard
        i:ok_ast_value_push

    Parsers use it at the end of a non\-terminal symbol generating an AST whose
    right\-hand side is void\.

  - <a name='90'></a>*objectName* __si:value\_leaf\_symbol\_end__ *symbol*

    This method combines

        i_value_clear/leaf  $symbol
        i_symbol_save       $symbol
        i_error_nonterminal $symbol
        i_loc_pop_discard
        i_ast_pop_rewind
        i:ok_ast_value_push

    Parsers use it at the end of a non\-terminal symbol generating an AST
    discarding the AST generated by the right\-hand side\.

  - <a name='91'></a>*objectName* __si:value\_clear\_symbol\_end__ *symbol*

    This method combines

        i_value_clear
        i_symbol_save       $symbol
        i_error_nonterminal $symbol
        i_loc_pop_discard
        i_ast_pop_rewind

    Parsers use it at the end of a void non\-terminal symbol, discarding the AST
    generated by the right\-hand side\.

  - <a name='92'></a>*objectName* __si:void\_clear\_symbol\_end__ *symbol*

    This method combines

        i_value_clear
        i_symbol_save       $symbol
        i_error_nonterminal $symbol
        i_loc_pop_discard

    Parsers use it at the end of a void non\-terminal symbol with a void
    right\-hand side\.

  - <a name='93'></a>*objectName* __si:next\_char__ *tok*

  - <a name='94'></a>*objectName* __si:next\_range__ *toks* *toke*

  - <a name='95'></a>*objectName* __si:next\_alnum__

  - <a name='96'></a>*objectName* __si:next\_alpha__

  - <a name='97'></a>*objectName* __si:next\_ascii__

  - <a name='98'></a>*objectName* __si:next\_ddigit__

  - <a name='99'></a>*objectName* __si:next\_digit__

  - <a name='100'></a>*objectName* __si:next\_graph__

  - <a name='101'></a>*objectName* __si:next\_lower__

  - <a name='102'></a>*objectName* __si:next\_print__

  - <a name='103'></a>*objectName* __si:next\_punct__

  - <a name='104'></a>*objectName* __si:next\_space__

  - <a name='105'></a>*objectName* __si:next\_upper__

  - <a name='106'></a>*objectName* __si:next\_wordchar__

  - <a name='107'></a>*objectName* __si:next\_xdigit__

    These methods all combine

        i_input_next $msg
        i:fail_return

    with the appropriate __i\_test\_xxx__ instruction\. Parsers use them for
    handling atomic expressions\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pt* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[EBNF](\.\./\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_),
[PEG](\.\./\.\./\.\./\.\./index\.md\#peg), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
