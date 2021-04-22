
[//000000001]: # (grammar::fa::op \- Finite automaton operations and usage)
[//000000002]: # (Generated from file 'faop\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::fa::op\(n\) 0\.4 tcllib "Finite automaton operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::fa::op \- Operations on finite automatons

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [EXAMPLES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require struct::list  
package require struct::set  
package require grammar::fa::op ?0\.4\.1?  

[__::grammar::fa::op::constructor__ *cmd*](#1)  
[__::grammar::fa::op::reverse__ *fa*](#2)  
[__::grammar::fa::op::complete__ *fa* ?*sink*?](#3)  
[__::grammar::fa::op::remove\_eps__ *fa*](#4)  
[__::grammar::fa::op::trim__ *fa* ?*what*?](#5)  
[__::grammar::fa::op::determinize__ *fa* ?*mapvar*?](#6)  
[__::grammar::fa::op::minimize__ *fa* ?*mapvar*?](#7)  
[__::grammar::fa::op::complement__ *fa*](#8)  
[__::grammar::fa::op::kleene__ *fa*](#9)  
[__::grammar::fa::op::optional__ *fa*](#10)  
[__::grammar::fa::op::union__ *fa* *fb* ?*mapvar*?](#11)  
[__::grammar::fa::op::intersect__ *fa* *fb* ?*mapvar*?](#12)  
[__::grammar::fa::op::difference__ *fa* *fb* ?*mapvar*?](#13)  
[__::grammar::fa::op::concatenate__ *fa* *fb* ?*mapvar*?](#14)  
[__::grammar::fa::op::fromRegex__ *fa* *regex* ?*over*?](#15)  
[__::grammar::fa::op::toRegexp__ *fa*](#16)  
[__::grammar::fa::op::toRegexp2__ *fa*](#17)  
[__::grammar::fa::op::toTclRegexp__ *regexp* *symdict*](#18)  
[__::grammar::fa::op::simplifyRegexp__ *regexp*](#19)  

# <a name='description'></a>DESCRIPTION

This package provides a number of complex operations on finite automatons
\(Short: FA\), as provided by the package __[grammar::fa](fa\.md)__\. The
package does not provide the ability to create and/or manipulate such FAs, nor
the ability to execute a FA for a stream of symbols\. Use the packages
__[grammar::fa](fa\.md)__ and __grammar::fa::interpreter__ for that\.
Another package related to this is __grammar::fa::compiler__ which turns a
FA into an executor class which has the definition of the FA hardwired into it\.

For more information about what a finite automaton is see section *FINITE
AUTOMATONS* in package __[grammar::fa](fa\.md)__\.

# <a name='section2'></a>API

The package exports the API described here\. All commands modify their first
argument\. I\.e\. whatever FA they compute is stored back into it\. Some of the
operations will construct an automaton whose states are all new, but related to
the states in the source automaton\(s\)\. These operations take variable names as
optional arguments where they will store mappings which describe the
relationship\(s\)\. The operations can be loosely partitioned into structural and
language operations\. The latter are defined in terms of the language the
automaton\(s\) accept, whereas the former are defined in terms of the structural
properties of the involved automaton\(s\)\. Some operations are both\. *Structure
operations*

  - <a name='1'></a>__::grammar::fa::op::constructor__ *cmd*

    This command has to be called by the user of the package before any other
    operations is performed, to establish a command which can be used to
    construct a FA container object\. If this is not done several operations will
    fail as they are unable to construct internal and transient containers to
    hold state and/or partial results\.

    Any container class using this package for complex operations should set its
    own class command as the constructor\. See package
    __[grammar::fa](fa\.md)__ for an example\.

  - <a name='2'></a>__::grammar::fa::op::reverse__ *fa*

    Reverses the *fa*\. This is done by reversing the direction of all
    transitions and swapping the sets of *start* and
    *[final](\.\./\.\./\.\./\.\./index\.md\#final)* states\. The language of *fa*
    changes unpredictably\.

  - <a name='3'></a>__::grammar::fa::op::complete__ *fa* ?*sink*?

    Completes the *fa* *complete*, but nothing is done if the *fa* is
    already *complete*\. This implies that only the first in a series of
    multiple consecutive complete operations on *fa* will perform anything\.
    The remainder will be null operations\.

    The language of *fa* is unchanged by this operation\.

    This is done by adding a single new state, the *sink*, and transitions
    from all other states to that sink for all symbols they have no transitions
    for\. The sink itself is made complete by adding loop transitions for all
    symbols\.

    Note: When a FA has epsilon\-transitions transitions over a symbol for a
    state S can be indirect, i\.e\. not attached directly to S, but to a state in
    the epsilon\-closure of S\. The symbols for such indirect transitions count
    when computing completeness of a state\. In other words, these indirectly
    reached symbols are *not* missing\.

    The argument *sink* provides the name for the new state and most not be
    present in the *fa* if specified\. If the name is not specified the command
    will name the state "sink__n__", where __n__ is set so that there
    are no collisions with existing states\.

    Note that the sink state is *not useful* by definition\. In other words,
    while the FA becomes complete, it is also *not useful* in the strict sense
    as it has a state from which no final state can be reached\.

  - <a name='4'></a>__::grammar::fa::op::remove\_eps__ *fa*

    Removes all epsilon\-transitions from the *fa* in such a manner the the
    language of *fa* is unchanged\. However nothing is done if the *fa* is
    already *epsilon\-free*\. This implies that only the first in a series of
    multiple consecutive complete operations on *fa* will perform anything\.
    The remainder will be null operations\.

    *Note:* This operation may cause states to become unreachable or not
    useful\. These states are not removed by this operation\. Use
    __::grammar::fa::op::trim__ for that instead\.

  - <a name='5'></a>__::grammar::fa::op::trim__ *fa* ?*what*?

    Removes unwanted baggage from *fa*\. The legal values for *what* are
    listed below\. The command defaults to __\!reachable&#124;\!useful__ if no
    specific argument was given\.

      * __\!reachable__

        Removes all states which are not reachable from a start state\.

      * __\!useful__

        Removes all states which are unable to reach a final state\.

      * __\!reachable&\!useful__

      * __\!\(reachable&#124;useful\)__

        Removes all states which are not reachable from a start state and are
        unable to reach a final state\.

      * __\!reachable&#124;\!useful__

      * __\!\(reachable&useful\)__

        Removes all states which are not reachable from a start state or are
        unable to reach a final state\.

  - <a name='6'></a>__::grammar::fa::op::determinize__ *fa* ?*mapvar*?

    Makes the *fa* deterministic without changing the language accepted by the
    *fa*\. However nothing is done if the *fa* is already *deterministic*\.
    This implies that only the first in a series of multiple consecutive
    complete operations on *fa* will perform anything\. The remainder will be
    null operations\.

    The command will store a dictionary describing the relationship between the
    new states of the resulting dfa and the states of the input nfa in
    *mapvar*, if it has been specified\. Keys of the dictionary are the handles
    for the states of the resulting dfa, values are sets of states from the
    input nfa\.

    *Note*: An empty dictionary signals that the command was able to make the
    *fa* deterministic without performing a full subset construction, just by
    removing states and shuffling transitions around \(As part of making the FA
    epsilon\-free\)\.

    *Note*: The algorithm fails to make the FA deterministic in the technical
    sense if the FA has no start state\(s\), because determinism requires the FA
    to have exactly one start states\. In that situation we make a best effort;
    and the missing start state will be the only condition preventing the
    generated result from being *deterministic*\. It should also be noted that
    in this case the possibilities for trimming states from the FA are also
    severely reduced as we cannot declare states unreachable\.

  - <a name='7'></a>__::grammar::fa::op::minimize__ *fa* ?*mapvar*?

    Creates a FA which accepts the same language as *fa*, but has a minimal
    number of states\. Uses Brzozowski's method to accomplish this\.

    The command will store a dictionary describing the relationship between the
    new states of the resulting minimal fa and the states of the input fa in
    *mapvar*, if it has been specified\. Keys of the dictionary are the handles
    for the states of the resulting minimal fa, values are sets of states from
    the input fa\.

    *Note*: An empty dictionary signals that the command was able to minimize
    the *fa* without having to compute new states\. This should happen if and
    only if the input FA was already minimal\.

    *Note*: If the algorithm has no start or final states to work with then
    the result might be technically minimal, but have a very unexpected
    structure\. It should also be noted that in this case the possibilities for
    trimming states from the FA are also severely reduced as we cannot declare
    states unreachable\.

*Language operations* All operations in this section require that all input
FAs have at least one start and at least one final state\. Otherwise the language
of the FAs will not be defined, making the operation senseless \(as it operates
on the languages of the FAs in a defined manner\)\.

  - <a name='8'></a>__::grammar::fa::op::complement__ *fa*

    Complements *fa*\. This is possible if and only if *fa* is *complete*
    and *deterministic*\. The resulting FA accepts the complementary language
    of *fa*\. In other words, all inputs not accepted by the input are accepted
    by the result, and vice versa\.

    The result will have all states and transitions of the input, and different
    final states\.

  - <a name='9'></a>__::grammar::fa::op::kleene__ *fa*

    Applies Kleene's closure to *fa*\. The resulting FA accepts all strings
    __S__ for which we can find a natural number __n__ \(0 inclusive\) and
    strings __A1__ \.\.\. __An__ in the language of *fa* such that
    __S__ is the concatenation of __A1__ \.\.\. __An__\. In other words,
    the language of the result is the infinite union over finite length
    concatenations over the language of *fa*\.

    The result will have all states and transitions of the input, and new start
    and final states\.

  - <a name='10'></a>__::grammar::fa::op::optional__ *fa*

    Makes the *fa* optional\. In other words it computes the FA which accepts
    the language of *fa* and the empty the word \(epsilon\) as well\.

    The result will have all states and transitions of the input, and new start
    and final states\.

  - <a name='11'></a>__::grammar::fa::op::union__ *fa* *fb* ?*mapvar*?

    Combines the FAs *fa* and *fb* such that the resulting FA accepts the
    union of the languages of the two FAs\.

    The result will have all states and transitions of the two input FAs, and
    new start and final states\. All states of *fb* which exist in *fa* as
    well will be renamed, and the *mapvar* will contain a mapping from the old
    states of *fb* to the new ones, if present\.

    It should be noted that the result will be non\-deterministic, even if the
    inputs are deterministic\.

  - <a name='12'></a>__::grammar::fa::op::intersect__ *fa* *fb* ?*mapvar*?

    Combines the FAs *fa* and *fb* such that the resulting FA accepts the
    intersection of the languages of the two FAs\. In other words, the result
    will accept a word if and only if the word is accepted by both *fa* and
    *fb*\. The result will be useful, but not necessarily deterministic or
    minimal\.

    The command will store a dictionary describing the relationship between the
    new states of the resulting fa and the pairs of states of the input FAs in
    *mapvar*, if it has been specified\. Keys of the dictionary are the handles
    for the states of the resulting fa, values are pairs of states from the
    input FAs\. Pairs are represented by lists\. The first element in each pair
    will be a state in *fa*, the second element will be drawn from *fb*\.

  - <a name='13'></a>__::grammar::fa::op::difference__ *fa* *fb* ?*mapvar*?

    Combines the FAs *fa* and *fb* such that the resulting FA accepts the
    difference of the languages of the two FAs\. In other words, the result will
    accept a word if and only if the word is accepted by *fa*, but not by
    *fb*\. This can also be expressed as the intersection of *fa* with the
    complement of *fb*\. The result will be useful, but not necessarily
    deterministic or minimal\.

    The command will store a dictionary describing the relationship between the
    new states of the resulting fa and the pairs of states of the input FAs in
    *mapvar*, if it has been specified\. Keys of the dictionary are the handles
    for the states of the resulting fa, values are pairs of states from the
    input FAs\. Pairs are represented by lists\. The first element in each pair
    will be a state in *fa*, the second element will be drawn from *fb*\.

  - <a name='14'></a>__::grammar::fa::op::concatenate__ *fa* *fb* ?*mapvar*?

    Combines the FAs *fa* and *fb* such that the resulting FA accepts the
    cross\-product of the languages of the two FAs\. I\.e\. a word W will be
    accepted by the result if there are two words A and B accepted by *fa*,
    and *fb* resp\. and W is the concatenation of A and B\.

    The result FA will be non\-deterministic\.

  - <a name='15'></a>__::grammar::fa::op::fromRegex__ *fa* *regex* ?*over*?

    Generates a non\-deterministic FA which accepts the same language as the
    regular expression *regex*\. If the *over* is specified it is treated as
    the set of symbols the regular expression and the automaton are defined
    over\. The command will compute the set from the "S" constructors in
    *regex* when *over* was not specified\. This set is important if and only
    if the complement operator "\!" is used in *regex* as the complementary
    language of an FA is quite different for different sets of symbols\.

    The regular expression is represented by a nested list, which forms a syntax
    tree\. The following structures are legal:

      * \{S x\}

        Atomic regular expression\. Everything else is constructed from these\.
        Accepts the __S__ymbol "x"\.

      * \{\. A1 A2 \.\.\.\}

        Concatenation operator\. Accepts the concatenation of the regular
        expressions __A1__, __A2__, etc\.

        *Note* that this operator accepts zero or more arguments\. With zero
        arguments the represented language is *epsilon*, the empty word\.

      * \{&#124; A1 A2 \.\.\.\}

        Choice operator, also called "Alternative"\. Accepts all input accepted
        by at least one of the regular expressions __A1__, __A2__, etc\.
        In other words, the union of __A1__, __A2__\.

        *Note* that this operator accepts zero or more arguments\. With zero
        arguments the represented language is the *empty* language, the
        language without words\.

      * \{& A1 A2 \.\.\.\}

        Intersection operator, logical and\. Accepts all input accepted which is
        accepted by all of the regular expressions __A1__, __A2__, etc\.
        In other words, the intersection of __A1__, __A2__\.

      * \{? A\}

        Optionality operator\. Accepts the empty word and anything from the
        regular expression __A__\.

      * \{\* A\}

        Kleene closure\. Accepts the empty word and any finite concatenation of
        words accepted by the regular expression __A__\.

      * \{\+ A\}

        Positive Kleene closure\. Accepts any finite concatenation of words
        accepted by the regular expression __A__, but not the empty word\.

      * \{\! A\}

        Complement operator\. Accepts any word not accepted by the regular
        expression __A__\. Note that the complement depends on the set of
        symbol the result should run over\. See the discussion of the argument
        *over* before\.

  - <a name='16'></a>__::grammar::fa::op::toRegexp__ *fa*

    This command generates and returns a regular expression which accepts the
    same language as the finite automaton *fa*\. The regular expression is in
    the format as described above, for __::grammar::fa::op::fromRegex__\.

  - <a name='17'></a>__::grammar::fa::op::toRegexp2__ *fa*

    This command has the same functionality as
    __::grammar::fa::op::toRegexp__, but uses a different algorithm to
    simplify the generated regular expressions\.

  - <a name='18'></a>__::grammar::fa::op::toTclRegexp__ *regexp* *symdict*

    This command generates and returns a regular expression in Tcl syntax for
    the regular expression *regexp*, if that is possible\. *regexp* is in the
    same format as expected by __::grammar::fa::op::fromRegex__\.

    The command will fail and throw an error if *regexp* contains
    complementation and intersection operations\.

    The argument *symdict* is a dictionary mapping symbol names to pairs of
    *syntactic type* and Tcl\-regexp\. If a symbol occurring in the *regexp*
    is not listed in this dictionary then single\-character symbols are
    considered to designate themselves whereas multiple\-character symbols are
    considered to be a character class name\.

  - <a name='19'></a>__::grammar::fa::op::simplifyRegexp__ *regexp*

    This command simplifies a regular expression by applying the following
    algorithm first to the main expression and then recursively to all
    sub\-expressions:

      1. Convert the expression into a finite automaton\.

      1. Minimize the automaton\.

      1. Convert the automaton back to a regular expression\.

      1. Choose the shorter of original expression and expression from the
         previous step\.

# <a name='section3'></a>EXAMPLES

# <a name='section4'></a>Bugs, Ideas, Feedback

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

Copyright &copy; 2004\-2008 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
