
[//000000001]: # (grammar::peg \- Grammar operations and usage)
[//000000002]: # (Generated from file 'peg\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (grammar::peg\(n\) 0\.1 tcllib "Grammar operations and usage")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::peg \- Create and manipulate parsing expression grammars

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

      - [TERMS & CONCEPTS](#subsection1)

      - [CONTAINER CLASS API](#subsection2)

      - [CONTAINER OBJECT API](#subsection3)

      - [PARSING EXPRESSIONS](#subsection4)

  - [PARSING EXPRESSION GRAMMARS](#section2)

  - [REFERENCES](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require snit  
package require grammar::peg ?0\.1?  

[__::grammar::peg__ *pegName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*?](#1)  
[*pegName* __destroy__](#2)  
[*pegName* __clear__](#3)  
[*pegName* __=__ *srcPEG*](#4)  
[*pegName* __\-\->__ *dstPEG*](#5)  
[*pegName* __serialize__](#6)  
[*pegName* __deserialize__ *serialization*](#7)  
[*pegName* __is valid__](#8)  
[*pegName* __start__ ?*pe*?](#9)  
[*pegName* __nonterminals__](#10)  
[*pegName* __nonterminal add__ *nt* *pe*](#11)  
[*pegName* __nonterminal delete__ *nt1* ?*nt2* \.\.\.?](#12)  
[*pegName* __nonterminal exists__ *nt*](#13)  
[*pegName* __nonterminal rename__ *nt* *ntnew*](#14)  
[*pegName* __nonterminal mode__ *nt* ?*mode*?](#15)  
[*pegName* __nonterminal rule__ *nt*](#16)  
[*pegName* __unknown nonterminals__](#17)  

# <a name='description'></a>DESCRIPTION

This package provides a container class for *parsing expression grammars*
\(Short: PEG\)\. It allows the incremental definition of the grammar, its
manipulation and querying of the definition\. The package neither provides
complex operations on the grammar, nor has it the ability to execute a grammar
definition for a stream of symbols\. Two packages related to this one are
__grammar::mengine__ and __grammar::peg::interpreter__\. The first of
them defines a general virtual machine for the matching of a character stream,
and the second implements an interpreter for parsing expression grammars on top
of that virtual machine\.

## <a name='subsection1'></a>TERMS & CONCEPTS

PEGs are similar to context\-free grammars, but not equivalent; in some cases
PEGs are strictly more powerful than context\-free grammars \(there exist PEGs for
some non\-context\-free languages\)\. The formal mathematical definition of parsing
expressions and parsing expression grammars can be found in section [PARSING
EXPRESSION GRAMMARS](#section2)\.

In short, we have *terminal symbols*, which are the most basic building blocks
for *sentences*, and *nonterminal symbols* with associated *parsing
expressions*, defining the grammatical structure of the sentences\. The two sets
of symbols are distinctive, and do not overlap\. When speaking about symbols the
word "symbol" is often left out\. The union of the sets of terminal and
nonterminal symbols is called the set of *symbols*\.

Here the set of *terminal symbols* is not explicitly managed, but implicitly
defined as the set of all characters\. Note that this means that we inherit from
Tcl the ability to handle all of Unicode\.

A pair of *nonterminal* and *[parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression)* is also called a
*grammatical rule*, or *rule* for short\. In the context of a rule the
nonterminal is often called the left\-hand\-side \(LHS\), and the parsing expression
the right\-hand\-side \(RHS\)\.

The *start expression* of a grammar is a parsing expression from which all the
sentences contained in the language specified by the grammar are *derived*\. To
make the understanding of this term easier let us assume for a moment that the
RHS of each rule, and the start expression, is either a sequence of symbols, or
a series of alternate parsing expressions\. In the latter case the rule can be
seen as a set of rules, each providing one alternative for the nonterminal\. A
parsing expression A' is now a derivation of a parsing expression A if we pick
one of the nonterminals N in the expression, and one of the alternative rules R
for N, and then replace the nonterminal in A with the RHS of the chosen rule\.
Here we can see why the terminal symbols are called such\. They cannot be
expanded any further, thus terminate the process of deriving new expressions\. An
example

    Rules
      (1)  A <- a B c
      (2a) B <- d B
      (2b) B <- e

    Some derivations, using starting expression A.

      A -/1/-> a B c -/2a/-> a d B c -/2b/-> a d e c

A derived expression containing only terminal symbols is a *sentence*\. The set
of all sentences which can be derived from the start expression is the
*language* of the grammar\.

Some definitions for nonterminals and expressions:

  1. A nonterminal A is called *reachable* if it is possible to derive a
     parsing expression from the start expression which contains A\.

  1. A nonterminal A is called *useful* if it is possible to derive a sentence
     from it\.

  1. A nonterminal A is called *recursive* if it is possible to derive a
     parsing expression from it which contains A, again\.

  1. The *FIRST set* of a nonterminal A contains all the symbols which can
     occur of as the leftmost symbol in a parsing expression derived from A\. If
     the FIRST set contains A itself then that nonterminal is called
     *left\-recursive*\.

  1. The *LAST set* of a nonterminal A contains all the symbols which can
     occur of as the rightmost symbol in a parsing expression derived from A\. If
     the LAST set contains A itself then that nonterminal is called
     *right\-recursive*\.

  1. The *FOLLOW set* of a nonterminal A contains all the symbols which can
     occur after A in a parsing expression derived from the start expression\.

  1. A nonterminal \(or parsing expression\) is called *nullable* if the empty
     sentence can be derived from it\.

And based on the above definitions for grammars:

  1. A grammar G is *recursive* if and only if it contains a nonterminal A
     which is recursive\. The terms *left\-* and *right\-recursive*, and
     *useful* are analogously defined\.

  1. A grammar is *minimal* if it contains only *reachable* and *useful*
     nonterminals\.

  1. A grammar is *wellformed* if it is not left\-recursive\. Such grammars are
     also *complete*, which means that they always succeed or fail on all
     input sentences\. For an incomplete grammar on the other hand input
     sentences exist for which an attempt to match them against the grammar will
     not terminate\.

  1. As we wish to allow ourselves to build a grammar incrementally in a
     container object we will encounter stages where the RHS of one or more
     rules reference symbols which are not yet known to the container\. Such a
     grammar we call *invalid*\. We cannot use the term *incomplete* as this
     term is already taken, see the last item\.

## <a name='subsection2'></a>CONTAINER CLASS API

The package exports the API described here\.

  - <a name='1'></a>__::grammar::peg__ *pegName* ?__=__&#124;__:=__&#124;__<\-\-__&#124;__as__&#124;__deserialize__ *src*?

    The command creates a new container object for a parsing expression grammar
    and returns the fully qualified name of the object command as its result\.
    The API the returned command is following is described in the section
    [CONTAINER OBJECT API](#subsection3)\. It may be used to invoke various
    operations on the container and the grammar within\.

    The new container, i\.e\. grammar will be empty if no *src* is specified\.
    Otherwise it will contain a copy of the grammar contained in the *src*\.
    The *src* has to be a container object reference for all operators except
    __deserialize__\. The __deserialize__ operator requires *src* to be
    the serialization of a parsing expression grammar instead\.

    An empty grammar has no nonterminal symbols, and the start expression is the
    empty expression, i\.e\. epsilon\. It is *valid*, but not *useful*\.

## <a name='subsection3'></a>CONTAINER OBJECT API

All grammar container objects provide the following methods for the manipulation
of their contents:

  - <a name='2'></a>*pegName* __destroy__

    Destroys the grammar, including its storage space and associated command\.

  - <a name='3'></a>*pegName* __clear__

    Clears out the definition of the grammar contained in *pegName*, but does
    *not* destroy the object\.

  - <a name='4'></a>*pegName* __=__ *srcPEG*

    Assigns the contents of the grammar contained in *srcPEG* to *pegName*,
    overwriting any existing definition\. This is the assignment operator for
    grammars\. It copies the grammar contained in the grammar object *srcPEG*
    over the grammar definition in *pegName*\. The old contents of *pegName*
    are deleted by this operation\.

    This operation is in effect equivalent to

    > *pegName* __deserialize__ \[*srcPEG* __serialize__\]

  - <a name='5'></a>*pegName* __\-\->__ *dstPEG*

    This is the reverse assignment operator for grammars\. It copies the
    automation contained in the object *pegName* over the grammar definition
    in the object *dstPEG*\. The old contents of *dstPEG* are deleted by this
    operation\.

    This operation is in effect equivalent to

    > *dstPEG* __deserialize__ \[*pegName* __serialize__\]

  - <a name='6'></a>*pegName* __serialize__

    This method serializes the grammar stored in *pegName*\. In other words it
    returns a tcl *value* completely describing that grammar\. This allows, for
    example, the transfer of grammars over arbitrary channels, persistence, etc\.
    This method is also the basis for both the copy constructor and the
    assignment operator\.

    The result of this method has to be semantically identical over all
    implementations of the __grammar::peg__ interface\. This is what will
    enable us to copy grammars between different implementations of the same
    interface\.

    The result is a list of four elements with the following structure:

      1. The constant string __grammar::peg__\.

      1. A dictionary\. Its keys are the names of all known nonterminal symbols,
         and their associated values are the parsing expressions describing
         their sentennial structure\.

      1. A dictionary\. Its keys are the names of all known nonterminal symbols,
         and their associated values hints to a matcher regarding the semantic
         values produced by the symbol\.

      1. The last item is a parsing expression, the *start expression* of the
         grammar\.

    Assuming the following PEG for simple mathematical expressions

    Digit      <- '0'/'1'/'2'/'3'/'4'/'5'/'6'/'7'/'8'/'9'
    Sign       <- '+' / '-'
    Number     <- Sign? Digit+
    Expression <- '(' Expression ')' / (Factor (MulOp Factor)*)
    MulOp      <- '*' / '/'
    Factor     <- Term (AddOp Term)*
    AddOp      <- '+'/'-'
    Term       <- Number

    a possible serialization is

    grammar::peg \
    {Expression {/ {x ( Expression )} {x Factor {* {x MulOp Factor}}}} \
     Factor     {x Term {* {x AddOp Term}}} \
     Term       Number \
     MulOp      {/ * /} \
     AddOp      {/ + -} \
     Number     {x {? Sign} {+ Digit}} \
     Sign       {/ + -} \
     Digit      {/ 0 1 2 3 4 5 6 7 8 9} \
    } \
    {Expression value     Factor     value \
     Term       value     MulOp      value \
     AddOp      value     Number     value \
     Sign       value     Digit      value \
    }
    Expression

    A possible one, because the order of the nonterminals in the dictionary is
    not relevant\.

  - <a name='7'></a>*pegName* __deserialize__ *serialization*

    This is the complement to __serialize__\. It replaces the grammar
    definition in *pegName* with the grammar described by the
    *serialization* value\. The old contents of *pegName* are deleted by this
    operation\.

  - <a name='8'></a>*pegName* __is valid__

    A predicate\. It tests whether the PEG in *pegName* is *valid*\. See
    section [TERMS & CONCEPTS](#subsection1) for the definition of this
    grammar property\. The result is a boolean value\. It will be set to
    __true__ if the PEG has the tested property, and __false__
    otherwise\.

  - <a name='9'></a>*pegName* __start__ ?*pe*?

    This method defines the *start expression* of the grammar\. It replaces the
    previously defined start expression with the parsing expression *pe*\. The
    method fails and throws an error if *pe* does not contain a valid parsing
    expression as specified in the section [PARSING
    EXPRESSIONS](#subsection4)\. In that case the existing start expression
    is not changed\. The method returns the empty string as its result\.

    If the method is called without an argument it will return the currently
    defined start expression\.

  - <a name='10'></a>*pegName* __nonterminals__

    Returns the set of all nonterminal symbols known to the grammar\.

  - <a name='11'></a>*pegName* __nonterminal add__ *nt* *pe*

    This method adds the nonterminal *nt* and its associated parsing
    expression *pe* to the set of nonterminal symbols and rules of the PEG
    contained in the object *pegName*\. The method fails and throws an error if
    either the string *nt* is already known as a symbol of the grammar, or if
    *pe* does not contain a valid parsing expression as specified in the
    section [PARSING EXPRESSIONS](#subsection4)\. In that case the current
    set of nonterminal symbols and rules is not changed\. The method returns the
    empty string as its result\.

  - <a name='12'></a>*pegName* __nonterminal delete__ *nt1* ?*nt2* \.\.\.?

    This method removes the named symbols *nt1*, *nt2* from the set of
    nonterminal symbols of the PEG contained in the object *pegName*\. The
    method fails and throws an error if any of the strings is not known as a
    nonterminal symbol\. In that case the current set of nonterminal symbols is
    not changed\. The method returns the empty string as its result\.

    The stored grammar becomes invalid if the deleted nonterminals are
    referenced by the RHS of still\-known rules\.

  - <a name='13'></a>*pegName* __nonterminal exists__ *nt*

    A predicate\. It tests whether the nonterminal symbol *nt* is known to the
    PEG in *pegName*\. The result is a boolean value\. It will be set to
    __true__ if the symbol *nt* is known, and __false__ otherwise\.

  - <a name='14'></a>*pegName* __nonterminal rename__ *nt* *ntnew*

    This method renames the nonterminal symbol *nt* to *ntnew*\. The method
    fails and throws an error if either *nt* is not known as a nonterminal, or
    if *ntnew* is a known symbol\. The method returns the empty string as its
    result\.

  - <a name='15'></a>*pegName* __nonterminal mode__ *nt* ?*mode*?

    This mode returns or sets the semantic mode associated with the nonterminal
    symbol *nt*\. If no *mode* is specified the current mode of the
    nonterminal is returned\. Otherwise the current mode is set to *mode*\. The
    method fails and throws an error if *nt* is not known as a nonterminal\.
    The grammar interpreter implemented by the package
    __grammar::peg::interpreter__ recognizes the following modes:

      * value

        The semantic value of the nonterminal is the abstract syntax tree
        created from the AST's of the RHS and a node for the nonterminal itself\.

      * match

        The semantic value of the nonterminal is an the abstract syntax tree
        consisting of single a node for the string matched by the RHS\. The ASTs
        generated by the RHS are discarded\.

      * leaf

        The semantic value of the nonterminal is an the abstract syntax tree
        consisting of single a node for the nonterminal itself\. The ASTs
        generated by the RHS are discarded\.

      * discard

        The nonterminal has no semantic value\. The ASTs generated by the RHS are
        discarded \(as well\)\.

  - <a name='16'></a>*pegName* __nonterminal rule__ *nt*

    This method returns the parsing expression associated with the nonterminal
    *nt*\. The method fails and throws an error if *nt* is not known as a
    nonterminal\.

  - <a name='17'></a>*pegName* __unknown nonterminals__

    This method returns a list containing the names of all nonterminal symbols
    which are referenced on the RHS of a grammatical rule, but have no rule
    definining their structure\. In other words, a list of the nonterminal
    symbols which make the grammar invalid\. The grammar is valid if this list is
    empty\.

## <a name='subsection4'></a>PARSING EXPRESSIONS

Various methods of PEG container objects expect a parsing expression as their
argument, or will return such\. This section specifies the format such parsing
expressions are in\.

  1. The string __epsilon__ is an atomic parsing expression\. It matches the
     empty string\.

  1. The string __alnum__ is an atomic parsing expression\. It matches any
     alphanumeric character\.

  1. The string __alpha__ is an atomic parsing expression\. It matches any
     alphabetical character\.

  1. The string __dot__ is an atomic parsing expression\. It matches any
     character\.

  1. The expression \[list t __x__\] is an atomic parsing expression\. It
     matches the terminal string __x__\.

  1. The expression \[list n __A__\] is an atomic parsing expression\. It
     matches the nonterminal __A__\.

  1. For parsing expressions __e1__, __e2__, \.\.\. the result of \[list /
     __e1__ __e2__ \.\.\. \] is a parsing expression as well\. This is the
     *ordered choice*, aka *prioritized choice*\.

  1. For parsing expressions __e1__, __e2__, \.\.\. the result of \[list x
     __e1__ __e2__ \.\.\. \] is a parsing expression as well\. This is the
     *sequence*\.

  1. For a parsing expression __e__ the result of \[list \* __e__\] is a
     parsing expression as well\. This is the *kleene closure*, describing zero
     or more repetitions\.

  1. For a parsing expression __e__ the result of \[list \+ __e__\] is a
     parsing expression as well\. This is the *positive kleene closure*,
     describing one or more repetitions\.

  1. For a parsing expression __e__ the result of \[list & __e__\] is a
     parsing expression as well\. This is the *and lookahead predicate*\.

  1. For a parsing expression __e__ the result of \[list \! __e__\] is a
     parsing expression as well\. This is the *not lookahead predicate*\.

  1. For a parsing expression __e__ the result of \[list ? __e__\] is a
     parsing expression as well\. This is the *optional input*\.

Examples of parsing expressions where already shown, in the description of the
method __serialize__\.

# <a name='section2'></a>PARSING EXPRESSION GRAMMARS

For the mathematically inclined, a PEG is a 4\-tuple \(VN,VT,R,eS\) where

  - VN is a set of *nonterminal symbols*,

  - VT is a set of *terminal symbols*,

  - R is a finite set of rules, where each rule is a pair \(A,e\), A in VN, and
    *[e](\.\./\.\./\.\./\.\./index\.md\#e)* a *[parsing
    expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression)*\.

  - eS is a parsing expression, the *start expression*\.

Further constraints are

  - The intersection of VN and VT is empty\.

  - For all A in VT exists exactly one pair \(A,e\) in R\. In other words, R is a
    function from nonterminal symbols to parsing expressions\.

Parsing expression are inductively defined via

  - The empty string \(epsilon\) is a parsing expression\.

  - A terminal symbol *a* is a parsing expression\.

  - A nonterminal symbol *A* is a parsing expression\.

  - *e1**e2* is a parsing expression for parsing expressions *e1* and
    *2*\. This is called *sequence*\.

  - *e1*/*e2* is a parsing expression for parsing expressions *e1* and
    *2*\. This is called *ordered choice*\.

  - *[e](\.\./\.\./\.\./\.\./index\.md\#e)*\* is a parsing expression for parsing
    expression *[e](\.\./\.\./\.\./\.\./index\.md\#e)*\. This is called
    *zero\-or\-more repetitions*, also known as *kleene closure*\.

  - *[e](\.\./\.\./\.\./\.\./index\.md\#e)*\+ is a parsing expression for parsing
    expression *[e](\.\./\.\./\.\./\.\./index\.md\#e)*\. This is called *one\-or\-more
    repetitions*, also known as *positive kleene closure*\.

  - \!*[e](\.\./\.\./\.\./\.\./index\.md\#e)* is a parsing expression for parsing
    expression *e1*\. This is called a *not lookahead predicate*\.

  - &*[e](\.\./\.\./\.\./\.\./index\.md\#e)* is a parsing expression for parsing
    expression *e1*\. This is called an *and lookahead predicate*\.

PEGs are used to define a grammatical structure for streams of symbols over VT\.
They are a modern phrasing of older formalisms invented by Alexander Birham\.
These formalisms were called TS \(TMG recognition scheme\), and gTS \(generalized
TS\)\. Later they were renamed to TPDL \(Top\-Down Parsing Languages\) and gTPDL
\(generalized TPDL\)\.

They can be easily implemented by recursive descent parsers with backtracking\.
This makes them relatives of LL\(k\) Context\-Free Grammars\.

# <a name='section3'></a>REFERENCES

  1. [The Packrat Parsing and Parsing Expression Grammars
     Page](http://www\.pdos\.lcs\.mit\.edu/~baford/packrat/), by Bryan Ford,
     Massachusetts Institute of Technology\. This is the main entry page to PEGs,
     and their realization through Packrat Parsers\.

  1. [Parsing Techniques \- A Practical Guide
     ](http://www\.cs\.vu\.nl/~dick/PTAPG\.html), an online book offering a
     clear, accessible, and thorough discussion of many different parsing
     techniques with their interrelations and applicabilities, including error
     recovery techniques\.

  1. [Compilers and Compiler Generators](http://scifac\.ru\.ac\.za/compilers/),
     an online book using CoCo/R, a generator for recursive descent parsers\.

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *grammar\_peg* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_), [TDPL](\.\./\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing), [parsing
expression](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2005 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
