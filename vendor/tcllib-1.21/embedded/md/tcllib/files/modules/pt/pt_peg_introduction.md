
[//000000001]: # (pt::pegrammar \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_peg\_introduction\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt::pegrammar\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt::pegrammar \- Introduction to Parsing Expression Grammars

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Formal definition](#section2)

  - [References](#section3)

  - [Bugs, Ideas, Feedback](#section4)

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

Welcome to the introduction to *[Parsing Expression
Grammar](\.\./\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar)*s \(short:
*[PEG](\.\./\.\./\.\./\.\./index\.md\#peg)*\), the formalism used by the Parser
Tools\. It is assumed that the reader has a basic knowledge of parsing theory,
i\.e\. *Context\-Free Grammars* \(short: *[CFG](\.\./\.\./\.\./\.\./index\.md\#cfg)*\),
*languages*, and associated terms like
*[LL\(k\)](\.\./\.\./\.\./\.\./index\.md\#ll\_k\_)*, *LR\(k\)*,
*[terminal](\.\./\.\./\.\./\.\./index\.md\#terminal)* and *nonterminal*
*symbols*, etc\. We do not intend to recapitulate such basic definitions or
terms like *useful*, *reachable*, \(left/right\) *recursive*, *nullable*,
first/last/follow sets, etc\. Please see the [References](#section3) at the
end instead if you are in need of places and books which provide such background
information\.

PEGs are formally very similar to CFGs, with terminal and nonterminal symbols,
start symbol, and rules defining the structure of each nonterminal symbol\. The
main difference lies in the choice\(sic\!\) of *choice* operators\. Where CFGs use
an *unordered choice* to represent alternatives PEGs use *prioritized
choice*\. Which is fancy way of saying that a parser has to try the first
alternative first and can try the other alternatives if only if it fails for the
first, and so on\.

On the CFG side this gives rise to LL\(k\) and LR\(k\) for making the choice
*deterministic* with a bounded *lookahead* of k terminal symbols, where LL
is in essence *topdown* aka *[recursive
descent](\.\./\.\./\.\./\.\./index\.md\#recursive\_descent)* parsing, and LR
*bottomup* aka *shift reduce* parsing\.

On the PEG side we can parse input with recursive descent and *backtracking*
of failed choices, the latter of which amounts to unlimited lookahead\. By
additionally recording the success or failure of nonterminals at the specific
locations they were tried at and reusing this information after backtracking we
can avoid the exponential blowup of running time usually associated with
backtracking and keep the parsing linear\. The memory requirements are of course
higher due to this cache, as we are trading space for time\.

This is the basic concept behind *packrat parsers*\.

A limitation pure PEGs share with LL\(k\) CFGs is that *left\-recursive* grammars
cannot be parsed, with the associated recursive descent parser entering an
infinite recursion\. This limitation is usually overcome by extending pure PEGs
with explicit operators to specify repetition, zero or more, and one or more,
or, formally spoken, for the *kleene closure* and *positive kleene closure*\.
This is what the Parser Tools are doing\.

Another extension, specific to Parser Tools, is a set of operators which map
more or less directly to various character classes built into Tcl, i\.e\. the
classes reachable via __string is__\.

The remainder of this document consists of the formal definition of PEGs for the
mathematically inclined, and an appendix listing references to places with more
information on PEGs specifically, and parsing in general\.

# <a name='section2'></a>Formal definition

For the mathematically inclined, a Parsing Expression Grammar is a 4\-tuple
\(VN,VT,R,eS\) where

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

Parsing expressions are inductively defined via

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

# <a name='section3'></a>References

  1. [The Packrat Parsing and Parsing Expression Grammars
     Page](http://www\.pdos\.lcs\.mit\.edu/~baford/packrat/), by Bryan Ford,
     Massachusetts Institute of Technology\. This is the main entry page to PEGs,
     and their realization through Packrat Parsers\.

  1. [http://en\.wikipedia\.org/wiki/Parsing\_expression\_grammar](http://en\.wikipedia\.org/wiki/Parsing\_expression\_grammar)
     Wikipedia's entry about Parsing Expression Grammars\.

  1. [Parsing Techniques \- A Practical Guide
     ](http://www\.cs\.vu\.nl/~dick/PTAPG\.html), an online book offering a
     clear, accessible, and thorough discussion of many different parsing
     techniques with their interrelations and applicabilities, including error
     recovery techniques\.

  1. [Compilers and Compiler Generators](http://scifac\.ru\.ac\.za/compilers/),
     an online book using CoCo/R, a generator for recursive descent parsers\.

# <a name='section4'></a>Bugs, Ideas, Feedback

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
