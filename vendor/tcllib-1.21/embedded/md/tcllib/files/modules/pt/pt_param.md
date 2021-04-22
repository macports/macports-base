
[//000000001]: # (pt::param \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_param\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::param\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::param \- PackRat Machine Specification

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Architectural State](#section2)

  - [Instruction Set](#section3)

      - [Input Handling](#subsection1)

      - [Character Processing](#subsection2)

      - [Error Handling](#subsection3)

      - [Status Control](#subsection4)

      - [Location Handling](#subsection5)

      - [Nonterminal Execution](#subsection6)

      - [Value Construction](#subsection7)

      - [AST Construction](#subsection8)

      - [Control Flow](#subsection9)

  - [Interaction of the Instructions with the Architectural
    State](#section4)

  - [Bugs, Ideas, Feedback](#section5)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](pt\_introduction\.md)*\. This document is the entrypoint to the whole
system the current package is a part of\.

Welcome to the PackRat Machine \(short:
*[PARAM](\.\./\.\./\.\./\.\./index\.md\#param)*\), a virtual machine geared towards
the support of recursive descent parsers, especially packrat parsers\. Towards
this end it has features like the caching and reuse of partial results, the
caching of the encountered input, and the ability to backtrack in both input and
AST creation\.

This document specifies the machine in terms of its architectural state and
instruction set\.

# <a name='section2'></a>Architectural State

Any PARAM implementation has to manage at least the following state:

  - *Input* \(IN\)

    This is the channel the characters to process are read from\.

    This part of the machine's state is used and modified by the instructions
    defined in the section [Input Handling](#subsection1)\.

  - *Current Character* \(CC\)

    The character from the *input* currently tested against its possible
    alternatives\.

    This part of the machine's state is used and modified by the instructions
    defined in the section [Character Processing](#subsection2)\.

  - *Current Location* \(CL\)

    The location of the *current character* in the *input*, as offset
    relative to the beginning of the input\. Character offsets are counted from
    __0__\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Character Processing](#subsection2),
    [Location Handling](#subsection5), and [Nonterminal
    Execution](#subsection6)\.

  - *Location Stack* \(LS\)

    A stack of locations in the *input*, saved for possible backtracking\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Character Processing](#subsection2),
    [Location Handling](#subsection5), and [Nonterminal
    Execution](#subsection6)\.

  - *Status* \(ST\)

    The status of the last attempt of testing the *input*, indicating either
    success or failure\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Status Control](#subsection4), [Character
    Processing](#subsection2), and [Nonterminal
    Execution](#subsection6)\.

  - *Semantic Value* \(SV\)

    The current semantic value, either empty, or a node for AST constructed from
    the input\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Value Construction](#subsection7), and [AST
    Construction](#subsection8)\.

  - *AST Reduction Stack* \(ARS\)

    The stack of partial ASTs constructed during the processing of nonterminal
    symbols\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Value Construction](#subsection7), and [AST
    Construction](#subsection8)\.

  - *AST Stack* \(AS\)

    The stack of reduction stacks, saved for possible backtracking\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Value Construction](#subsection7), and [AST
    Construction](#subsection8)\.

  - *Error Status* \(ER\)

    The machine's current knowledge of errors\. This is either empty, or set to a
    pair of location in the input and the set of messages for that location\.

    *Note* that this part of the machine's state can be set even if the last
    test of the *current character* was successful\. For example, the
    \*\-operator \(matching a sub\-expression zero or more times\) in a PEG is always
    successful, even if it encounters a problem further in the input and has to
    backtrack\. Such problems must not be forgotten when continuing the parsing\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Error Handling](#subsection3), [Character
    Processing](#subsection2), and [Nonterminal
    Execution](#subsection6)\.

  - *Error Stack* \(ES\)

    The stack of error stati, saved for backtracking\. This enables the machine
    to merge current and older error stati when performing backtracking in
    choices after an failed match\.

    This part of the machine's state is used and modified by the instructions
    defined in the sections [Error Handling](#subsection3), [Character
    Processing](#subsection2), and [Nonterminal
    Execution](#subsection6)\.

  - *Nonterminal Cache* \(NC\)

    A cache of machine states keyed by pairs name of nonterminal symbol and
    location in the input\. Each pair \(N, L\) is associated with a 4\-tuple holding
    the values to use for CL, ST, SV, and ER after the nonterminal N was parsed
    starting from the location L\. It is a performance aid for backtracking
    parsers, allowing them to avoid an expensive reparsing of complex
    nonterminal symbols if they have been encountered before at a given
    location\.

    The key location is where machine started the attempt to match the named
    nonterminal symbol, and the location in the saved 4\-tuple is where machine
    ended up after the attempt completed, independent of the success of the
    attempt\.

    This part of the machine's state is used and modified by the instructions
    defined in the section [Nonterminal Execution](#subsection6)\.

  - *Terminal Cache* \(TC\)

    A cache of characters read from IN, with their location in IN as pair of
    line and column, keyed by the location in IN, this time as character offset
    from the beginning of IN\. It is a performance aid for backtracking parsers,
    allowing them to avoid a possibly expensive rereading of characters from IN,
    or even enabling backtracking at, i\.e\. in the case of IN not randomly
    seekable\.

    This part of the machine's state is used and modified by the instructions
    defined in the section [Input Handling](#subsection1)\.

# <a name='section3'></a>Instruction Set

With the machine's architectural state specified it is now possible to specify
the instruction set operating on that state and to be implemented by any
realization of the PARAM\. The 37 instructions are grouped roughly by the state
they influence and/or query during their execution\.

## <a name='subsection1'></a>Input Handling

The instructions in this section mainly access IN, pulling the characters to
process into the machine\.

  - __input\_next__ *msg*

    This method reads the next character, i\.e\. the character after CL, from IN\.
    If successful this character becomes CC, CL is advanced by one, ES is
    cleared, and the operation is recorded as a success in ST\.

    The operation may read the character from IN if the next character is not
    yet known to TC\. If successful the new character is stored in TC, with its
    location \(line, column\), and the operation otherwise behaves as specified
    above\. Future reads from the same location, possible due to backtracking,
    will then be satisfied from TC instead of IN\.

    If, on the other hand, the end of IN was reached, the operation is recorded
    as failed in ST, CL is left unchanged, and the pair of CL and *msg*
    becomes the new ES\.

## <a name='subsection2'></a>Character Processing

The instructions in this section mainly access CC, testing it against character
classes, ranges, and individual characters\.

  - __test\_alnum__

    This instruction implements the special PE operator "alnum", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_alpha__

    This instruction implements the special PE operator "alpha", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_ascii__

    This instruction implements the special PE operator "ascii", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_char__ *char*

    This instruction implements the character matching operator, i\.e\. it checks
    if CC is *char*\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_ddigit__

    This instruction implements the special PE operator "ddigit", which checks
    if CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_digit__

    This instruction implements the special PE operator "digit", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_graph__

    This instruction implements the special PE operator "graph", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_lower__

    This instruction implements the special PE operator "lower", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_print__

    This instruction implements the special PE operator "print", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_punct__

    This instruction implements the special PE operator "punct", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_range__ *chars* *chare*

    This instruction implements the range matching operator, i\.e\. it checks if
    CC falls into the interval of characters spanned up by the two characters
    from *chars* to *chare*, both inclusive\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_space__

    This instruction implements the special PE operator "space", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_upper__

    This instruction implements the special PE operator "upper", which checks if
    CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_wordchar__

    This instruction implements the special PE operator "wordchar", which checks
    if CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

  - __test\_xdigit__

    This instruction implements the special PE operator "xdigit", which checks
    if CC falls into the character class of the same name, or not\.

    Success and failure of the test are both recorded directly in ST\. Success
    further clears ES, wheras failure sets the pair of CL and expected input
    \(encoded as a leaf parsing expression\) as the new ES and then rewinds CL by
    one character, preparing the machine for another parse attempt by a possible
    alternative\.

## <a name='subsection3'></a>Error Handling

The instructions in this section mainly access ER and ES\.

  - __error\_clear__

    This instruction clears ER\.

  - __error\_push__

    This instruction makes a copy of ER and pushes it on ES\.

  - __error\_pop\_merge__

    This instruction takes the topmost entry of ES and merges the error status
    it contains with ES, making the result the new ES\.

    The merge is governed by four rules, with the merge result

      1. Empty if both states are empty\.

      1. The non\-empty state if only one of the two states is non\-empty\.

      1. The state with the larger location, if the two states specify different
         locations\.

      1. The pair of the location shared by the two states, and the set\-union of
         their messages for states at the same location\.

  - __error\_nonterminal__ *symbol*

    This is a guarded instruction\. It does nothing if either ES is empty, or if
    the location in ES is not just past the last location saved in LS\. Otherwise
    it sets the pair of that location and the nonterminal *symbol* as the new
    ES\.

    *Note*: In the above "just past" means "that location plus one", or also
    "the location of the next character after that location"\.

## <a name='subsection4'></a>Status Control

The instructions in this section directly manipulate ST\.

  - __status\_ok__

    This instruction sets ST to __true__, recording a success\.

  - __status\_fail__

    This instruction sets ST to __false__, recording a failure\.

  - __status\_negate__

    This instruction negates ST, turning a failure into a success and vice
    versa\.

## <a name='subsection5'></a>Location Handling

The instructions in this section access CL and LS\.

  - __loc\_push__

    This instruction makes a copy of CL and pushes it on LS\.

  - __loc\_pop\_discard__

    This instructions pops the last saved location from LS\.

  - __loc\_pop\_rewind__

    This instruction pops the last saved location from LS and restores it as CL\.

## <a name='subsection6'></a>Nonterminal Execution

The instructions in this section access and manipulate NC\.

  - __symbol\_restore__ *symbol*

    This instruction checks if NC contains data for the nonterminal *symbol*
    at CL, or not\. The result of the instruction is a boolean flag, with
    __True__ indicating that data was found in the cache\. In that case the
    instruction has further updated the architectural state of the machine with
    the cached information, namely CL, ST, ER, and SV\.

    The method with which the instruction's result is transformed into control
    flow is left undefined and the responsibility of the implementation\.

  - __symbol\_save__ *symbol*

    This instructions saves the current settings of CL, ST, ER, and SV in NC,
    using the pair of nonterminal *symbol* and the last location saved in LS
    as key\.

## <a name='subsection7'></a>Value Construction

The instructions in this section manipulate SV\.

  - __value\_clear__

    This instruction clears SV\.

  - __value\_leaf__ *symbol*

    This instruction constructs an AST node for *symbol* covering the range of
    IN from one character after the last location saved on LS to CL and stores
    it in SV\. \.\.\.

  - __value\_reduce__ *symbol*

    This instruction generally behaves like __value\_nonterminal\_leaf__,
    except that it takes all AST nodes on ARS, if any, and makes them the
    children of the new node, with the last node saved on ARS becoming the
    right\-most / last child\. Note that ARS is not modfied by this operation\.

## <a name='subsection8'></a>AST Construction

The instructions in this section manipulate ARS and AS\.

  - __ast\_value\_push__

    This instruction makes a copy of SV and pushes it on ARS\.

  - __ast\_push__

    This instruction pushes the current state of ARS on AS and then clears ARS\.

  - __ast\_pop\_rewind__

    This instruction pops the last entry saved on AS and restores it as the new
    state of ARS\.

  - __ast\_pop\_discard__

    This instruction pops the last entry saved on AS\.

## <a name='subsection9'></a>Control Flow

Normally this section would contain the specifications of the control flow
instructions of the PARAM, i\.e\. \(un\)conditional jumps and the like\. However,
this part of the PARAM is intentionally left unspecified\. This allows the
implementations to freely choose how to implement control flow\.

The implementation of this machine in Parser Tools, i\.e the package
__[pt::rde](pt\_rdengine\.md)__, is not only coded in Tcl, but also relies
on Tcl commands to provide it with control flow \(instructions\)\.

# <a name='section4'></a>Interaction of the Instructions with the Architectural State

    Instruction		Inputs				Outputs
    ======================= =======================		====================
    ast_pop_discard		AS			->	AS
    ast_pop_rewind		AS			->	AS, ARS
    ast_push		ARS, AS			->	AS
    ast_value_push		SV, ARS			->	ARS
    ======================= =======================		====================
    error_clear		-			->	ER
    error_nonterminal sym	ER, LS			->	ER
    error_pop_merge   	ES, ER			->	ER
    error_push		ES, ER			->	ES
    ======================= =======================		====================
    input_next msg		IN			->	TC, CL, CC, ST, ER
    ======================= =======================		====================
    loc_pop_discard		LS			->	LS
    loc_pop_rewind		LS			->	LS, CL
    loc_push		CL, LS			->	LS
    ======================= =======================		====================
    status_fail		-			->	ST
    status_negate		ST			->	ST
    status_ok		-			->	ST
    ======================= =======================		====================
    symbol_restore sym	NC			->	CL, ST, ER, SV
    symbol_save    sym	CL, ST, ER, SV LS	->	NC
    ======================= =======================		====================
    test_alnum  		CC			->	ST, ER
    test_alpha		CC			->	ST, ER
    test_ascii		CC			->	ST, ER
    test_char char		CC			->	ST, ER
    test_ddigit		CC			->	ST, ER
    test_digit		CC			->	ST, ER
    test_graph		CC			->	ST, ER
    test_lower		CC			->	ST, ER
    test_print		CC			->	ST, ER
    test_punct		CC			->	ST, ER
    test_range chars chare	CC			->	ST, ER
    test_space		CC			->	ST, ER
    test_upper		CC			->	ST, ER
    test_wordchar		CC			->	ST, ER
    test_xdigit		CC			->	ST, ER
    ======================= =======================		====================
    value_clear		-			->	SV
    value_leaf symbol	LS, CL			->	SV
    value_reduce symbol	ARS, LS, CL		->	SV
    ======================= =======================		====================

# <a name='section5'></a>Bugs, Ideas, Feedback

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
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer), [virtual
machine](\.\./\.\./\.\./\.\./index\.md\#virtual\_machine)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
