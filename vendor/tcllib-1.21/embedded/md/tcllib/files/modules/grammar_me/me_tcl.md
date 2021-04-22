
[//000000001]: # (grammar::me::tcl \- Grammar operations and usage)
[//000000002]: # (Generated from file 'me\_tcl\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::me::tcl\(n\) 0\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::me::tcl \- Virtual machine implementation I for parsing token streams

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [MACHINE STATE](#section3)

  - [MACHINE INSTRUCTIONS](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require grammar::me::tcl ?0\.1?  

[__::grammar::me::tcl__ __cmd__ *\.\.\.*](#1)  
[__::grammar::me::tcl__ __init__ *nextcmd* ?*tokmap*?](#2)  
[__::grammar::me::tcl__ __lc__ *location*](#3)  
[__::grammar::me::tcl__ __tok__ *from* ?*to*?](#4)  
[__::grammar::me::tcl__ __tokens__](#5)  
[__::grammar::me::tcl__ __sv__](#6)  
[__::grammar::me::tcl__ __ast__](#7)  
[__::grammar::me::tcl__ __astall__](#8)  
[__::grammar::me::tcl__ __ctok__](#9)  
[__::grammar::me::tcl__ __nc__](#10)  
[__::grammar::me::tcl__ __next__](#11)  
[__::grammar::me::tcl__ __ord__](#12)  
[__::grammar::me::tcl::ict\_advance__ *message*](#13)  
[__::grammar::me::tcl::ict\_match\_token__ *tok* *message*](#14)  
[__::grammar::me::tcl::ict\_match\_tokrange__ *tokbegin* *tokend* *message*](#15)  
[__::grammar::me::tcl::ict\_match\_tokclass__ *code* *message*](#16)  
[__::grammar::me::tcl::inc\_restore__ *nt*](#17)  
[__::grammar::me::tcl::inc\_save__ *nt* *startlocation*](#18)  
[__::grammar::me::tcl::iok\_ok__](#19)  
[__::grammar::me::tcl::iok\_fail__](#20)  
[__::grammar::me::tcl::iok\_negate__](#21)  
[__::grammar::me::tcl::icl\_get__](#22)  
[__::grammar::me::tcl::icl\_rewind__ *oldlocation*](#23)  
[__::grammar::me::tcl::ier\_get__](#24)  
[__::grammar::me::tcl::ier\_clear__](#25)  
[__::grammar::me::tcl::ier\_nonterminal__ *message* *location*](#26)  
[__::grammar::me::tcl::ier\_merge__ *olderror*](#27)  
[__::grammar::me::tcl::isv\_clear__](#28)  
[__::grammar::me::tcl::isv\_terminal__](#29)  
[__::grammar::me::tcl::isv\_nonterminal\_leaf__ *nt* *startlocation*](#30)  
[__::grammar::me::tcl::isv\_nonterminal\_range__ *nt* *startlocation*](#31)  
[__::grammar::me::tcl::isv\_nonterminal\_reduce__ *nt* *startlocation* ?*marker*?](#32)  
[__::grammar::me::tcl::ias\_push__](#33)  
[__::grammar::me::tcl::ias\_mark__](#34)  
[__::grammar::me::tcl::ias\_pop2mark__ *marker*](#35)  

# <a name='description'></a>DESCRIPTION

This package provides an implementation of the ME virtual machine\. Please go and
read the document __[grammar::me\_intro](me\_intro\.md)__ first if you do
not know what a ME virtual machine is\.

This implementation is tied very strongly to Tcl\. All the stacks in the machine
state are handled through the Tcl stack, all control flow is handled by Tcl
commands, and the remaining machine instructions are directly mapped to Tcl
commands\. Especially the matching of nonterminal symbols is handled by Tcl
procedures as well, essentially extending the machine implementation with custom
instructions\.

Further on the implementation handles only a single machine which is
uninteruptible during execution and hardwired for pull operation\. I\.e\. it
explicitly requests each new token through a callback, pulling them into its
state\.

A related package is
__[grammar::peg::interp](\.\./grammar\_peg/peg\_interp\.md)__ which provides
a generic interpreter / parser for parsing expression grammars \(PEGs\),
implemented on top of this implementation of the ME virtual machine\.

# <a name='section2'></a>API

The commands documented in this section do not implement any of the instructions
of the ME virtual machine\. They provide the facilities for the initialization of
the machine and the retrieval of important information\.

  - <a name='1'></a>__::grammar::me::tcl__ __cmd__ *\.\.\.*

    This is an ensemble command providing access to the commands listed in this
    section\. See the methods themselves for detailed specifications\.

  - <a name='2'></a>__::grammar::me::tcl__ __init__ *nextcmd* ?*tokmap*?

    This command \(re\)initializes the machine\. It returns the empty string\. This
    command has to be invoked before any other command of this package\.

    The command prefix *nextcmd* represents the input stream of characters and
    is invoked by the machine whenever the a new character from the stream is
    required\. The instruction for handling this is *ict\_advance*\. The callback
    has to return either the empty list, or a list of 4 elements containing the
    token, its lexeme attribute, and its location as line number and column
    index, in this order\. The empty list is the signal that the end of the input
    stream has been reached\. The lexeme attribute is stored in the terminal
    cache, but otherwise not used by the machine\.

    The optional dictionary *tokmap* maps from tokens to integer numbers\. If
    present the numbers impose an order on the tokens, which is subsequently
    used by *ict\_match\_tokrange* to determine if a token is in the specified
    range or not\. If no token map is specified the lexicographic order of th
    token names will be used instead\. This choice is especially asensible when
    using characters as tokens\.

  - <a name='3'></a>__::grammar::me::tcl__ __lc__ *location*

    This command converts the location of a token given as offset in the input
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

    After a call of __init__ the state used for the conversion is cleared,
    making further conversions impossible until the machine has read tokens
    again\.

  - <a name='4'></a>__::grammar::me::tcl__ __tok__ *from* ?*to*?

    This command returns a Tcl list containing the part of the input stream
    between the locations *from* and *to* \(both inclusive\)\. If *to* is not
    specified it will default to the value of *from*\.

    Each element of the returned list is a list of four elements, the token, its
    associated lexeme, line number, and column index, in this order\. In other
    words, each element has the same structure as the result of the *nextcmd*
    callback given to __::grammar::me::tcl::init__

    This command places the same restrictions on its location arguments as
    __::grammar::me::tcl::lc__\.

  - <a name='5'></a>__::grammar::me::tcl__ __tokens__

    This command returns the number of tokens currently known to the ME virtual
    machine\.

  - <a name='6'></a>__::grammar::me::tcl__ __sv__

    This command returns the current semantic value *SV* stored in the
    machine\. This is an abstract syntax tree as specified in the document
    __[grammar::me\_ast](me\_ast\.md)__, section __AST VALUES__\.

  - <a name='7'></a>__::grammar::me::tcl__ __ast__

    This method returns the abstract syntax tree currently at the top of the AST
    stack of the ME virtual machine\. This is an abstract syntax tree as
    specified in the document __[grammar::me\_ast](me\_ast\.md)__, section
    __AST VALUES__\.

  - <a name='8'></a>__::grammar::me::tcl__ __astall__

    This method returns the whole stack of abstract syntax trees currently known
    to the ME virtual machine\. Each element of the returned list is an abstract
    syntax tree as specified in the document
    __[grammar::me\_ast](me\_ast\.md)__, section __AST VALUES__\. The
    top of the stack resides at the end of the list\.

  - <a name='9'></a>__::grammar::me::tcl__ __ctok__

    This method returns the current token considered by the ME virtual machine\.

  - <a name='10'></a>__::grammar::me::tcl__ __nc__

    This method returns the contents of the nonterminal cache as a dictionary
    mapping from "__symbol__,__location__" to match information\.

  - <a name='11'></a>__::grammar::me::tcl__ __next__

    This method returns the next token callback as specified during
    initialization of the ME virtual machine\.

  - <a name='12'></a>__::grammar::me::tcl__ __ord__

    This method returns a dictionary containing the *tokmap* specified during
    initialization of the ME virtual machine\.
    ____::grammar::me::tcl::ok____ This variable contains the current
    match status *OK*\. It is provided as variable instead of a command because
    that makes access to this information faster, and the speed of access is
    considered very important here as this information is used constantly to
    determine the control flow\.

# <a name='section3'></a>MACHINE STATE

Please go and read the document __[grammar::me\_vm](me\_vm\.md)__ first for
a specification of the basic ME virtual machine and its state\.

This implementation manages the state described in that document, except for the
stacks minus the AST stack\. In other words, location stack, error stack, return
stack, and ast marker stack are implicitly managed through standard Tcl scoping,
i\.e\. Tcl variables in procedures, outside of this implementation\.

# <a name='section4'></a>MACHINE INSTRUCTIONS

Please go and read the document __[grammar::me\_vm](me\_vm\.md)__ first for
a specification of the basic ME virtual machine and its instruction set\.

This implementation maps all instructions to Tcl commands in the namespace
"::grammar::me::tcl", except for the stack related commands, nonterminal symbols
and control flow\. Here we simply list the commands and explain the differences
to the specified instructions, if there are any\. For their semantics see the
aforementioned specification\. The machine commands are *not* reachable through
the ensemble command __::grammar::me::tcl__\.

  - <a name='13'></a>__::grammar::me::tcl::ict\_advance__ *message*

    No changes\.

  - <a name='14'></a>__::grammar::me::tcl::ict\_match\_token__ *tok* *message*

    No changes\.

  - <a name='15'></a>__::grammar::me::tcl::ict\_match\_tokrange__ *tokbegin* *tokend* *message*

    If, and only if a token map was specified during initialization then the
    arguments are the numeric representations of the smallest and largest tokens
    in the range\. Otherwise they are the relevant tokens themselves and
    lexicographic comparison is used\.

  - <a name='16'></a>__::grammar::me::tcl::ict\_match\_tokclass__ *code* *message*

    No changes\.

  - <a name='17'></a>__::grammar::me::tcl::inc\_restore__ *nt*

    Instead of taking a branchlabel the command returns a boolean value\. The
    result will be __true__ if and only if cached information was found\. The
    caller has to perform the appropriate branching\.

  - <a name='18'></a>__::grammar::me::tcl::inc\_save__ *nt* *startlocation*

    The command takes the start location as additional argument, as it is
    managed on the Tcl stack, and not in the machine state\.

  - __icf\_ntcall__ *branchlabel*

  - __icf\_ntreturn__

    These two instructions are not mapped to commands\. They are control flow
    instructions and handled in Tcl\.

  - <a name='19'></a>__::grammar::me::tcl::iok\_ok__

    No changes\.

  - <a name='20'></a>__::grammar::me::tcl::iok\_fail__

    No changes\.

  - <a name='21'></a>__::grammar::me::tcl::iok\_negate__

    No changes\.

  - __icf\_jalways__ *branchlabel*

  - __icf\_jok__ *branchlabel*

  - __icf\_jfail__ *branchlabel*

  - __icf\_halt__

    These four instructions are not mapped to commands\. They are control flow
    instructions and handled in Tcl\.

  - <a name='22'></a>__::grammar::me::tcl::icl\_get__

    This command returns the current location *CL* in the input\. It replaces
    *icl\_push*\.

  - <a name='23'></a>__::grammar::me::tcl::icl\_rewind__ *oldlocation*

    The command takes the location as argument as it comes from the Tcl stack,
    not the machine state\.

  - __icl\_pop__

    Not mapped, the stacks are not managed by the package\.

  - <a name='24'></a>__::grammar::me::tcl::ier\_get__

    This command returns the current error state *ER*\. It replaces
    *ier\_push*\.

  - <a name='25'></a>__::grammar::me::tcl::ier\_clear__

    No changes\.

  - <a name='26'></a>__::grammar::me::tcl::ier\_nonterminal__ *message* *location*

    The command takes the location as argument as it comes from the Tcl stack,
    not the machine state\.

  - <a name='27'></a>__::grammar::me::tcl::ier\_merge__ *olderror*

    The command takes the second error state to merge as argument as it comes
    from the Tcl stack, not the machine state\.

  - <a name='28'></a>__::grammar::me::tcl::isv\_clear__

    No changes\.

  - <a name='29'></a>__::grammar::me::tcl::isv\_terminal__

    No changes\.

  - <a name='30'></a>__::grammar::me::tcl::isv\_nonterminal\_leaf__ *nt* *startlocation*

    The command takes the start location as argument as it comes from the Tcl
    stack, not the machine state\.

  - <a name='31'></a>__::grammar::me::tcl::isv\_nonterminal\_range__ *nt* *startlocation*

    The command takes the start location as argument as it comes from the Tcl
    stack, not the machine state\.

  - <a name='32'></a>__::grammar::me::tcl::isv\_nonterminal\_reduce__ *nt* *startlocation* ?*marker*?

    The command takes start location and marker as argument as it comes from the
    Tcl stack, not the machine state\.

  - <a name='33'></a>__::grammar::me::tcl::ias\_push__

    No changes\.

  - <a name='34'></a>__::grammar::me::tcl::ias\_mark__

    This command returns a marker for the current state of the AST stack *AS*\.
    The marker stack is not managed by the machine\.

  - <a name='35'></a>__::grammar::me::tcl::ias\_pop2mark__ *marker*

    The command takes the marker as argument as it comes from the Tcl stack, not
    the machine state\. It replaces *ias\_mpop*\.

# <a name='section5'></a>Bugs, Ideas, Feedback

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

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
