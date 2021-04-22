
[//000000001]: # (grammar::aycock \- Aycock\-Horspool\-Earley parser generator for Tcl)
[//000000002]: # (Generated from file 'aycock\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2006 by Kevin B\. Kenny <kennykb@acm\.org>)
[//000000004]: # (Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>)
[//000000005]: # (grammar::aycock\(n\) 1\.0 tcllib "Aycock\-Horspool\-Earley parser generator for Tcl")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

grammar::aycock \- Aycock\-Horspool\-Earley parser generator for Tcl

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [OBJECT COMMAND](#section3)

  - [DESCRIPTION](#section4)

  - [EXAMPLE](#section5)

  - [KEYWORDS](#section6)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require grammar::aycock ?1\.0?  

[__::aycock::parser__ *grammar* ?__\-verbose__?](#1)  
[*parserName* __parse__ *symList* *valList* ?*clientData*?](#2)  
[*parserName* __destroy__](#3)  
[*parserName* __terminals__](#4)  
[*parserName* __nonterminals__](#5)  
[*parserName* __save__](#6)  

# <a name='description'></a>DESCRIPTION

The __grammar::aycock__ package implements a parser generator for the class
of parsers described in John Aycock and R\. Nigel Horspool\. Practical Earley
Parsing\. *The Computer Journal,* *45*\(6\):620\-630, 2002\.
[http://citeseerx\.ist\.psu\.edu/viewdoc/summary?doi=10\.1\.1\.12\.4254](http://citeseerx\.ist\.psu\.edu/viewdoc/summary?doi=10\.1\.1\.12\.4254)

# <a name='section2'></a>PROCEDURES

The __grammar::aycock__ package exports the single procedure:

  - <a name='1'></a>__::aycock::parser__ *grammar* ?__\-verbose__?

    Generates a parser for the given *grammar*, and returns its name\. If the
    optional __\-verbose__ flag is given, dumps verbose information relating
    to the generated parser to the standard output\. The returned parser is an
    object that accepts commands as shown in [OBJECT COMMAND](#section3)
    below\.

# <a name='section3'></a>OBJECT COMMAND

  - <a name='2'></a>*parserName* __parse__ *symList* *valList* ?*clientData*?

    Invokes a parser returned from __::aycock::parser__\. *symList* is a
    list of grammar symbols representing the terminals in an input string, and
    *valList* is a list of their semantic values\. The result is the semantic
    value of the entire string when parsed\.

  - <a name='3'></a>*parserName* __destroy__

    Destroys a parser constructed by __::aycock::parser__\.

  - <a name='4'></a>*parserName* __terminals__

    Returns a list of terminal symbols that may be presented in the *symList*
    argument to the __parse__ object command\.

  - <a name='5'></a>*parserName* __nonterminals__

    Returns a list of nonterminal symbols that were defined in the parser's
    grammar\.

  - <a name='6'></a>*parserName* __save__

    Returns a Tcl script that will reconstruct the parser without needing all
    the mechanism of the parser generator at run time\. The reconstructed parser
    depends on a set of commands in the package
    __grammar::aycock::runtime__, which is also automatically loaded when
    the __grammar::aycock__ package is loaded\.

# <a name='section4'></a>DESCRIPTION

The __grammar::aycock::parser__ command accepts a grammar expressed as a Tcl
list\. The list must be structured as the concatenation of a set of *rule*s\.
Each *rule* comprises a variable number of elements in the list:

  - The name of the nonterminal symbol that the rule reduces\.

  - The literal string, __::=__

  - Zero or more names of terminal or nonterminal symbols that comprise the
    right\-hand\-side of the rule\.

  - Finally, a Tcl script to execute when the rule is reduced\. Within the given
    script, a variable called __\___ contains a list of the semantic values
    of the symbols on the right\-hand side\. The value returned by the script is
    expected to be the semantic value of the left\-hand side\. If the
    *clientData* parameter was passed to the __parse__ method, it is
    available in a variable called __clientData__\. It is permissible for the
    script to be the empty string\. In this case, the semantic value of the rule
    will be the same as the semantic value of the first symbol on the right\-hand
    side\. If the right\-hand side is also empty, the semantic value will be the
    empty string\.

Parsing is done with an Earley parser, which is not terribly efficient in speed
or memory consumption, but which deals effectively with ambiguous grammars\. For
this reason, the __grammar::aycock__ package is perhaps best adapted to
natural\-language processing or the parsing of extraordinarily complex languages
in which ambiguity can be tolerated\.

# <a name='section5'></a>EXAMPLE

The following code demonstrates a trivial desk calculator, admitting only
__\+__, __\*__ and parentheses as its operators\. It also shows the format
in which the lexical analyzer is expected to present terminal symbols to the
parser\.

    set p [aycock::parser {
        start ::= E {}
        E ::= E + T {expr {[lindex $_ 0] + [lindex $_ 2]}}
        E ::= T {}
        T ::= T * F {expr {[lindex $_ 0] * [lindex $_ 2]}}
        T ::= F {}
        F ::= NUMBER {}
        F ::= ( E ) {lindex $_ 1}
    }]
    puts [$p parse {(  NUMBER +  NUMBER )  *  ( NUMBER +  NUMBER ) }  {{} 2      {} 3      {} {} {} 7     {} 1      {}}]
    $p destroy

The example, when run, prints __40__\.

# <a name='section6'></a>KEYWORDS

Aycock, Earley, Horspool, parser, compiler

# <a name='keywords'></a>KEYWORDS

[ambiguous](\.\./\.\./\.\./\.\./index\.md\#ambiguous),
[aycock](\.\./\.\./\.\./\.\./index\.md\#aycock),
[earley](\.\./\.\./\.\./\.\./index\.md\#earley),
[grammar](\.\./\.\./\.\./\.\./index\.md\#grammar),
[horspool](\.\./\.\./\.\./\.\./index\.md\#horspool),
[parser](\.\./\.\./\.\./\.\./index\.md\#parser),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[transducer](\.\./\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Grammars and finite automata

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2006 by Kevin B\. Kenny <kennykb@acm\.org>
Redistribution permitted under the terms of the Open Publication License <http://www\.opencontent\.org/openpub/>
