
[//000000001]: # (grammar::fa \- Finite automaton operations and usage)
[//000000002]: # (Generated from file 'fa\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2004\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::fa\(n\) 0\.4 tcllib "Finite automaton operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::fa \- Create and manipulate finite automatons

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [FA METHODS](#section3)

  - [EXAMPLES](#section4)

  - [FINITE AUTOMATONS](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit 1\.3  
package require struct::list  
package require struct::set  
package require grammar::fa::op ?0\.2?  
package require grammar::fa ?0\.4?  

[__::grammar::fa__ *faName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*&#124;__fromRegex__ *re* ?*over*??](#1)  
[__faName__ *option* ?*arg arg \.\.\.*?](#2)  
[*faName* __destroy__](#3)  
[*faName* __clear__](#4)  
[*faName* __=__ *srcFA*](#5)  
[*faName* __\-\->__ *dstFA*](#6)  
[*faName* __serialize__](#7)  
[*faName* __deserialize__ *serialization*](#8)  
[*faName* __states__](#9)  
[*faName* __state__ __add__ *s1* ?*s2* \.\.\.?](#10)  
[*faName* __state__ __delete__ *s1* ?*s2* \.\.\.?](#11)  
[*faName* __state__ __exists__ *s*](#12)  
[*faName* __state__ __rename__ *s* *snew*](#13)  
[*faName* __startstates__](#14)  
[*faName* __start__ __add__ *s1* ?*s2* \.\.\.?](#15)  
[*faName* __start__ __remove__ *s1* ?*s2* \.\.\.?](#16)  
[*faName* __start?__ *s*](#17)  
[*faName* __start?set__ *stateset*](#18)  
[*faName* __finalstates__](#19)  
[*faName* __final__ __add__ *s1* ?*s2* \.\.\.?](#20)  
[*faName* __final__ __remove__ *s1* ?*s2* \.\.\.?](#21)  
[*faName* __final?__ *s*](#22)  
[*faName* __final?set__ *stateset*](#23)  
[*faName* __symbols__](#24)  
[*faName* __symbols@__ *s* ?*d*?](#25)  
[*faName* __symbols@set__ *stateset*](#26)  
[*faName* __symbol__ __add__ *sym1* ?*sym2* \.\.\.?](#27)  
[*faName* __symbol__ __delete__ *sym1* ?*sym2* \.\.\.?](#28)  
[*faName* __symbol__ __rename__ *sym* *newsym*](#29)  
[*faName* __symbol__ __exists__ *sym*](#30)  
[*faName* __next__ *s* *sym* ?__\-\->__ *next*?](#31)  
[*faName* __\!next__ *s* *sym* ?__\-\->__ *next*?](#32)  
[*faName* __nextset__ *stateset* *sym*](#33)  
[*faName* __is__ __deterministic__](#34)  
[*faName* __is__ __complete__](#35)  
[*faName* __is__ __useful__](#36)  
[*faName* __is__ __epsilon\-free__](#37)  
[*faName* __reachable\_states__](#38)  
[*faName* __unreachable\_states__](#39)  
[*faName* __reachable__ *s*](#40)  
[*faName* __useful\_states__](#41)  
[*faName* __unuseful\_states__](#42)  
[*faName* __useful__ *s*](#43)  
[*faName* __epsilon\_closure__ *s*](#44)  
[*faName* __reverse__](#45)  
[*faName* __complete__](#46)  
[*faName* __remove\_eps__](#47)  
[*faName* __trim__ ?*what*?](#48)  
[*faName* __determinize__ ?*mapvar*?](#49)  
[*faName* __minimize__ ?*mapvar*?](#50)  
[*faName* __complement__](#51)  
[*faName* __kleene__](#52)  
[*faName* __optional__](#53)  
[*faName* __union__ *fa* ?*mapvar*?](#54)  
[*faName* __intersect__ *fa* ?*mapvar*?](#55)  
[*faName* __difference__ *fa* ?*mapvar*?](#56)  
[*faName* __concatenate__ *fa* ?*mapvar*?](#57)  
[*faName* __fromRegex__ *regex* ?*over*?](#58)  

# <a name='description'></a>DESCRIPTION

This package provides a container class for *finite automatons* \(Short: FA\)\.
It allows the incremental definition of the automaton, its manipulation and
querying of the definition\. While the package provides complex operations on the
automaton \(via package __[grammar::fa::op](faop\.md)__\), it does not have
the ability to execute a definition for a stream of symbols\. Use the packages
__[grammar::fa::dacceptor](dacceptor\.md)__ and
__[grammar::fa::dexec](dexec\.md)__ for that\. Another package related to
this is __grammar::fa::compiler__\. It turns a FA into an executor class
which has the definition of the FA hardwired into it\. The output of this package
is configurable to suit a large number of different implementation languages and
paradigms\.

For more information about what a finite automaton is see section [FINITE
AUTOMATONS](#section5)\.

# <a name='section2'></a>API

The package exports the API described here\.

  - <a name='1'></a>__::grammar::fa__ *faName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*&#124;__fromRegex__ *re* ?*over*??

    Creates a new finite automaton with an associated global Tcl command whose
    name is *faName*\. This command may be used to invoke various operations on
    the automaton\. It has the following general form:

      * <a name='2'></a>__faName__ *option* ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.
        See section [FA METHODS](#section3) for more explanations\. The new
        automaton will be empty if no *src* is specified\. Otherwise it will
        contain a copy of the definition contained in the *src*\. The *src*
        has to be a FA object reference for all operators except
        __deserialize__ and __fromRegex__\. The __deserialize__
        operator requires *src* to be the serialization of a FA instead, and
        __fromRegex__ takes a regular expression in the form a of a syntax
        tree\. See __::grammar::fa::op::fromRegex__ for more detail on that\.

# <a name='section3'></a>FA METHODS

All automatons provide the following methods for their manipulation:

  - <a name='3'></a>*faName* __destroy__

    Destroys the automaton, including its storage space and associated command\.

  - <a name='4'></a>*faName* __clear__

    Clears out the definition of the automaton contained in *faName*, but does
    *not* destroy the object\.

  - <a name='5'></a>*faName* __=__ *srcFA*

    Assigns the contents of the automaton contained in *srcFA* to *faName*,
    overwriting any existing definition\. This is the assignment operator for
    automatons\. It copies the automaton contained in the FA object *srcFA*
    over the automaton definition in *faName*\. The old contents of *faName*
    are deleted by this operation\.

    This operation is in effect equivalent to

    > *faName* __deserialize__ \[*srcFA* __serialize__\]

  - <a name='6'></a>*faName* __\-\->__ *dstFA*

    This is the reverse assignment operator for automatons\. It copies the
    automation contained in the object *faName* over the automaton definition
    in the object *dstFA*\. The old contents of *dstFA* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *dstFA* __deserialize__ \[*faName* __serialize__\]

  - <a name='7'></a>*faName* __serialize__

    This method serializes the automaton stored in *faName*\. In other words it
    returns a tcl *value* completely describing that automaton\. This allows,
    for example, the transfer of automatons over arbitrary channels,
    persistence, etc\. This method is also the basis for both the copy
    constructor and the assignment operator\.

    The result of this method has to be semantically identical over all
    implementations of the __grammar::fa__ interface\. This is what will
    enable us to copy automatons between different implementations of the same
    interface\.

    The result is a list of three elements with the following structure:

      1. The constant string __grammar::fa__\.

      1. A list containing the names of all known input symbols\. The order of
         elements in this list is not relevant\.

      1. The last item in the list is a dictionary, however the order of the
         keys is important as well\. The keys are the states of the serialized
         FA, and their order is the order in which to create the states when
         deserializing\. This is relevant to preserve the order relationship
         between states\.

         The value of each dictionary entry is a list of three elements
         describing the state in more detail\.

           1) A boolean flag\. If its value is __true__ then the state is a
              start state, otherwise it is not\.

           1) A boolean flag\. If its value is __true__ then the state is a
              final state, otherwise it is not\.

           1) The last element is a dictionary describing the transitions for
              the state\. The keys are symbols \(or the empty string\), and the
              values are sets of successor states\.

    Assuming the following FA \(which describes the life of a truck driver in a
    very simple way :\)

        Drive -- yellow --> Brake -- red --> (Stop) -- red/yellow --> Attention -- green --> Drive
        (...) is the start state.

    a possible serialization is

        grammar::fa \
        {yellow red green red/yellow} \
        {Drive     {0 0 {yellow     Brake}} \
         Brake     {0 0 {red        Stop}} \
         Stop      {1 0 {red/yellow Attention}} \
         Attention {0 0 {green      Drive}}}

    A possible one, because I did not care about creation order here

  - <a name='8'></a>*faName* __deserialize__ *serialization*

    This is the complement to __serialize__\. It replaces the automaton
    definition in *faName* with the automaton described by the
    *serialization* value\. The old contents of *faName* are deleted by this
    operation\.

  - <a name='9'></a>*faName* __states__

    Returns the set of all states known to *faName*\.

  - <a name='10'></a>*faName* __state__ __add__ *s1* ?*s2* \.\.\.?

    Adds the states *s1*, *s2*, et cetera to the FA definition in
    *faName*\. The operation will fail any of the new states is already
    declared\.

  - <a name='11'></a>*faName* __state__ __delete__ *s1* ?*s2* \.\.\.?

    Deletes the state *s1*, *s2*, et cetera, and all associated information
    from the FA definition in *faName*\. The latter means that the information
    about in\- or outbound transitions is deleted as well\. If the deleted state
    was a start or final state then this information is invalidated as well\. The
    operation will fail if the state *s* is not known to the FA\.

  - <a name='12'></a>*faName* __state__ __exists__ *s*

    A predicate\. It tests whether the state *s* is known to the FA in
    *faName*\. The result is a boolean value\. It will be set to __true__ if
    the state *s* is known, and __false__ otherwise\.

  - <a name='13'></a>*faName* __state__ __rename__ *s* *snew*

    Renames the state *s* to *snew*\. Fails if *s* is not a known state\.
    Also fails if *snew* is already known as a state\.

  - <a name='14'></a>*faName* __startstates__

    Returns the set of states which are marked as *start* states, also known
    as *initial* states\. See [FINITE AUTOMATONS](#section5) for
    explanations what this means\.

  - <a name='15'></a>*faName* __start__ __add__ *s1* ?*s2* \.\.\.?

    Mark the states *s1*, *s2*, et cetera in the FA *faName* as *start*
    \(aka *initial*\)\.

  - <a name='16'></a>*faName* __start__ __remove__ *s1* ?*s2* \.\.\.?

    Mark the states *s1*, *s2*, et cetera in the FA *faName* as *not
    start* \(aka *not accepting*\)\.

  - <a name='17'></a>*faName* __start?__ *s*

    A predicate\. It tests if the state *s* in the FA *faName* is *start*
    or not\. The result is a boolean value\. It will be set to __true__ if the
    state *s* is *start*, and __false__ otherwise\.

  - <a name='18'></a>*faName* __start?set__ *stateset*

    A predicate\. It tests if the set of states *stateset* contains at least
    one start state\. They operation will fail if the set contains an element
    which is not a known state\. The result is a boolean value\. It will be set to
    __true__ if a start state is present in *stateset*, and __false__
    otherwise\.

  - <a name='19'></a>*faName* __finalstates__

    Returns the set of states which are marked as
    *[final](\.\./\.\./\.\./\.\./index\.md\#final)* states, also known as
    *accepting* states\. See [FINITE AUTOMATONS](#section5) for
    explanations what this means\.

  - <a name='20'></a>*faName* __final__ __add__ *s1* ?*s2* \.\.\.?

    Mark the states *s1*, *s2*, et cetera in the FA *faName* as
    *[final](\.\./\.\./\.\./\.\./index\.md\#final)* \(aka *accepting*\)\.

  - <a name='21'></a>*faName* __final__ __remove__ *s1* ?*s2* \.\.\.?

    Mark the states *s1*, *s2*, et cetera in the FA *faName* as *not
    final* \(aka *not accepting*\)\.

  - <a name='22'></a>*faName* __final?__ *s*

    A predicate\. It tests if the state *s* in the FA *faName* is
    *[final](\.\./\.\./\.\./\.\./index\.md\#final)* or not\. The result is a boolean
    value\. It will be set to __true__ if the state *s* is
    *[final](\.\./\.\./\.\./\.\./index\.md\#final)*, and __false__ otherwise\.

  - <a name='23'></a>*faName* __final?set__ *stateset*

    A predicate\. It tests if the set of states *stateset* contains at least
    one final state\. They operation will fail if the set contains an element
    which is not a known state\. The result is a boolean value\. It will be set to
    __true__ if a final state is present in *stateset*, and __false__
    otherwise\.

  - <a name='24'></a>*faName* __symbols__

    Returns the set of all symbols known to the FA *faName*\.

  - <a name='25'></a>*faName* __symbols@__ *s* ?*d*?

    Returns the set of all symbols for which the state *s* has transitions\. If
    the empty symbol is present then *s* has epsilon transitions\. If two
    states are specified the result is the set of symbols which have transitions
    from *s* to *t*\. This set may be empty if there are no transitions
    between the two specified states\.

  - <a name='26'></a>*faName* __symbols@set__ *stateset*

    Returns the set of all symbols for which at least one state in the set of
    states *stateset* has transitions\. In other words, the union of
    \[*faName* __symbols@__ __s__\] for all states __s__ in
    *stateset*\. If the empty symbol is present then at least one state
    contained in *stateset* has epsilon transitions\.

  - <a name='27'></a>*faName* __symbol__ __add__ *sym1* ?*sym2* \.\.\.?

    Adds the symbols *sym1*, *sym2*, et cetera to the FA definition in
    *faName*\. The operation will fail any of the symbols is already declared\.
    The empty string is not allowed as a value for the symbols\.

  - <a name='28'></a>*faName* __symbol__ __delete__ *sym1* ?*sym2* \.\.\.?

    Deletes the symbols *sym1*, *sym2* et cetera, and all associated
    information from the FA definition in *faName*\. The latter means that all
    transitions using the symbols are deleted as well\. The operation will fail
    if any of the symbols is not known to the FA\.

  - <a name='29'></a>*faName* __symbol__ __rename__ *sym* *newsym*

    Renames the symbol *sym* to *newsym*\. Fails if *sym* is not a known
    symbol\. Also fails if *newsym* is already known as a symbol\.

  - <a name='30'></a>*faName* __symbol__ __exists__ *sym*

    A predicate\. It tests whether the symbol *sym* is known to the FA in
    *faName*\. The result is a boolean value\. It will be set to __true__ if
    the symbol *sym* is known, and __false__ otherwise\.

  - <a name='31'></a>*faName* __next__ *s* *sym* ?__\-\->__ *next*?

    Define or query transition information\.

    If *next* is specified, then the method will add a transition from the
    state *s* to the *successor* state *next* labeled with the symbol
    *sym* to the FA contained in *faName*\. The operation will fail if *s*,
    or *next* are not known states, or if *sym* is not a known symbol\. An
    exception to the latter is that *sym* is allowed to be the empty string\.
    In that case the new transition is an *epsilon transition* which will not
    consume input when traversed\. The operation will also fail if the
    combination of \(*s*, *sym*, and *next*\) is already present in the FA\.

    If *next* was not specified, then the method will return the set of states
    which can be reached from *s* through a single transition labeled with
    symbol *sym*\.

  - <a name='32'></a>*faName* __\!next__ *s* *sym* ?__\-\->__ *next*?

    Remove one or more transitions from the Fa in *faName*\.

    If *next* was specified then the single transition from the state *s* to
    the state *next* labeled with the symbol *sym* is removed from the FA\.
    Otherwise *all* transitions originating in state *s* and labeled with
    the symbol *sym* will be removed\.

    The operation will fail if *s* and/or *next* are not known as states\. It
    will also fail if a non\-empty *sym* is not known as symbol\. The empty
    string is acceptable, and allows the removal of epsilon transitions\.

  - <a name='33'></a>*faName* __nextset__ *stateset* *sym*

    Returns the set of states which can be reached by a single transition
    originating in a state in the set *stateset* and labeled with the symbol
    *sym*\.

    In other words, this is the union of \[*faName* next __s__ *symbol*\]
    for all states __s__ in *stateset*\.

  - <a name='34'></a>*faName* __is__ __deterministic__

    A predicate\. It tests whether the FA in *faName* is a deterministic FA or
    not\. The result is a boolean value\. It will be set to __true__ if the FA
    is deterministic, and __false__ otherwise\.

  - <a name='35'></a>*faName* __is__ __complete__

    A predicate\. It tests whether the FA in *faName* is a complete FA or not\.
    A FA is complete if it has at least one transition per state and symbol\.
    This also means that a FA without symbols, or states is also complete\. The
    result is a boolean value\. It will be set to __true__ if the FA is
    deterministic, and __false__ otherwise\.

    Note: When a FA has epsilon\-transitions transitions over a symbol for a
    state S can be indirect, i\.e\. not attached directly to S, but to a state in
    the epsilon\-closure of S\. The symbols for such indirect transitions count
    when computing completeness\.

  - <a name='36'></a>*faName* __is__ __useful__

    A predicate\. It tests whether the FA in *faName* is an useful FA or not\. A
    FA is useful if all states are *reachable* and *useful*\. The result is a
    boolean value\. It will be set to __true__ if the FA is deterministic,
    and __false__ otherwise\.

  - <a name='37'></a>*faName* __is__ __epsilon\-free__

    A predicate\. It tests whether the FA in *faName* is an epsilon\-free FA or
    not\. A FA is epsilon\-free if it has no epsilon transitions\. This definition
    means that all deterministic FAs are epsilon\-free as well, and
    epsilon\-freeness is a necessary pre\-condition for deterministic'ness\. The
    result is a boolean value\. It will be set to __true__ if the FA is
    deterministic, and __false__ otherwise\.

  - <a name='38'></a>*faName* __reachable\_states__

    Returns the set of states which are reachable from a start state by one or
    more transitions\.

  - <a name='39'></a>*faName* __unreachable\_states__

    Returns the set of states which are not reachable from any start state by
    any number of transitions\. This is

        [faName states] - [faName reachable_states]

  - <a name='40'></a>*faName* __reachable__ *s*

    A predicate\. It tests whether the state *s* in the FA *faName* can be
    reached from a start state by one or more transitions\. The result is a
    boolean value\. It will be set to __true__ if the state can be reached,
    and __false__ otherwise\.

  - <a name='41'></a>*faName* __useful\_states__

    Returns the set of states which are able to reach a final state by one or
    more transitions\.

  - <a name='42'></a>*faName* __unuseful\_states__

    Returns the set of states which are not able to reach a final state by any
    number of transitions\. This is

        [faName states] - [faName useful_states]

  - <a name='43'></a>*faName* __useful__ *s*

    A predicate\. It tests whether the state *s* in the FA *faName* is able
    to reach a final state by one or more transitions\. The result is a boolean
    value\. It will be set to __true__ if the state is useful, and
    __false__ otherwise\.

  - <a name='44'></a>*faName* __epsilon\_closure__ *s*

    Returns the set of states which are reachable from the state *s* in the FA
    *faName* by one or more epsilon transitions, i\.e transitions over the
    empty symbol, transitions which do not consume input\. This is called the
    *epsilon closure* of *s*\.

  - <a name='45'></a>*faName* __reverse__

  - <a name='46'></a>*faName* __complete__

  - <a name='47'></a>*faName* __remove\_eps__

  - <a name='48'></a>*faName* __trim__ ?*what*?

  - <a name='49'></a>*faName* __determinize__ ?*mapvar*?

  - <a name='50'></a>*faName* __minimize__ ?*mapvar*?

  - <a name='51'></a>*faName* __complement__

  - <a name='52'></a>*faName* __kleene__

  - <a name='53'></a>*faName* __optional__

  - <a name='54'></a>*faName* __union__ *fa* ?*mapvar*?

  - <a name='55'></a>*faName* __intersect__ *fa* ?*mapvar*?

  - <a name='56'></a>*faName* __difference__ *fa* ?*mapvar*?

  - <a name='57'></a>*faName* __concatenate__ *fa* ?*mapvar*?

  - <a name='58'></a>*faName* __fromRegex__ *regex* ?*over*?

    These methods provide more complex operations on the FA\. Please see the
    same\-named commands in the package __[grammar::fa::op](faop\.md)__
    for descriptions of what they do\.

# <a name='section4'></a>EXAMPLES

# <a name='section5'></a>FINITE AUTOMATONS

For the mathematically inclined, a FA is a 5\-tuple \(S,Sy,St,Fi,T\) where

  - S is a set of *states*,

  - Sy a set of *input symbols*,

  - St is a subset of S, the set of *start* states, also known as *initial*
    states\.

  - Fi is a subset of S, the set of *[final](\.\./\.\./\.\./\.\./index\.md\#final)*
    states, also known as *accepting*\.

  - T is a function from S x \(Sy \+ epsilon\) to \{S\}, the *transition function*\.
    Here __epsilon__ denotes the empty input symbol and is distinct from all
    symbols in Sy; and \{S\} is the set of subsets of S\. In other words, T maps a
    combination of State and Input \(which can be empty\) to a set of *successor
    states*\.

In computer theory a FA is most often shown as a graph where the nodes represent
the states, and the edges between the nodes encode the transition function: For
all n in S' = T \(s, sy\) we have one edge between the nodes representing s and n
resp\., labeled with sy\. The start and accepting states are encoded through
distinct visual markers, i\.e\. they are attributes of the nodes\.

FA's are used to process streams of symbols over Sy\.

A specific FA is said to *accept* a finite stream sy\_1 sy\_2 \.\.\. sy\_n if there
is a path in the graph of the FA beginning at a state in St and ending at a
state in Fi whose edges have the labels sy\_1, sy\_2, etc\. to sy\_n\. The set of all
strings accepted by the FA is the *language* of the FA\. One important
equivalence is that the set of languages which can be accepted by an FA is the
set of *[regular languages](\.\./\.\./\.\./\.\./index\.md\#regular\_languages)*\.

Another important concept is that of deterministic FAs\. A FA is said to be
*deterministic* if for each string of input symbols there is exactly one path
in the graph of the FA beginning at the start state and whose edges are labeled
with the symbols in the string\. While it might seem that non\-deterministic FAs
to have more power of recognition, this is not so\. For each non\-deterministic FA
we can construct a deterministic FA which accepts the same language \(\-\->
Thompson's subset construction\)\.

While one of the premier applications of FAs is in
*[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing)*, especially in the
*[lexer](\.\./\.\./\.\./\.\./index\.md\#lexer)* stage \(where symbols == characters\),
this is not the only possibility by far\.

Quite a lot of processes can be modeled as a FA, albeit with a possibly large
set of states\. For these the notion of accepting states is often less or not
relevant at all\. What is needed instead is the ability to act to state changes
in the FA, i\.e\. to generate some output in response to the input\. This
transforms a FA into a *finite transducer*, which has an additional set OSy of
*output symbols* and also an additional *output function* O which maps from
"S x \(Sy \+ epsilon\)" to "\(Osy \+ epsilon\)", i\.e a combination of state and input,
possibly empty to an output symbol, or nothing\.

For the graph representation this means that edges are additional labeled with
the output symbol to write when this edge is traversed while matching input\.
Note that for an application "writing an output symbol" can also be "executing
some code"\.

Transducers are not handled by this package\. They will get their own package in
the future\.

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

Copyright &copy; 2004\-2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
