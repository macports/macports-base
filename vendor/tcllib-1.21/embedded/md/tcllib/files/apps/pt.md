
[//000000001]: # (pt \- Parser Tools)
[//000000002]: # (Generated from file 'pt\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

pt \- Parser Tools Application

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Command Line](#section2)

  - [PEG Specification Language](#section3)

  - [JSON Grammar Exchange](#section4)

  - [C Parser Embedded In Tcl](#section5)

  - [C Parser](#section6)

  - [Snit Parser](#section7)

  - [TclOO Parser](#section8)

  - [Grammar Container](#section9)

  - [Example](#section10)

  - [Internals](#section11)

  - [Bugs, Ideas, Feedback](#section12)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

[__pt__ __generate__ *resultformat* ?*options\.\.\.*? *resultfile* *inputformat* *inputfile*](#1)  

# <a name='description'></a>DESCRIPTION

Are you lost ? Do you have trouble understanding this document ? In that case
please read the overview provided by the *[Introduction to Parser
Tools](\.\./modules/pt/pt\_introduction\.md)*\. This document is the entrypoint
to the whole system the current package is a part of\.

This document describes __pt__, the main application of the module, a
*[parser generator](\.\./\.\./\.\./index\.md\#parser\_generator)*\. Its intended
audience are people who wish to create a parser for some language of theirs\.
Should you wish to modify the application instead, please see the section about
the application's [Internals](#section11) for the basic references\.

It resides in the User Application Layer of Parser Tools\.

![](\.\./\.\./\.\./image/arch\_user\_app\.png)

# <a name='section2'></a>Command Line

  - <a name='1'></a>__pt__ __generate__ *resultformat* ?*options\.\.\.*? *resultfile* *inputformat* *inputfile*

    This sub\-command of the application reads the parsing expression grammar
    stored in the *inputfile* in the format *inputformat*, converts it to
    the *resultformat* under the direction of the \(format\-specific\) set of
    options specified by the user and stores the result in the *resultfile*\.

    The *inputfile* has to exist, while the *resultfile* may be created,
    overwriting any pre\-existing content of the file\. Any missing directory in
    the path to the *resultfile* will be created as well\.

    The exact form of the result for, and the set of options supported by the
    known result\-formats, are explained in the upcoming sections of this
    document, with the list below providing an index mapping between format name
    and its associated section\. In alphabetical order:

      * __c__

        A *resultformat*\. See section [C Parser](#section6)\.

      * __container__

        A *resultformat*\. See section [Grammar Container](#section9)\.

      * __critcl__

        A *resultformat*\. See section [C Parser Embedded In
        Tcl](#section5)\.

      * __json__

        A *input*\- and *resultformat*\. See section [JSON Grammar
        Exchange](#section4)\.

      * __oo__

        A *resultformat*\. See section [TclOO Parser](#section8)\.

      * __peg__

        A *input*\- and *resultformat*\. See section [PEG Specification
        Language](#section3)\.

      * __snit__

        A *resultformat*\. See section [Snit Parser](#section7)\.

Of the seven possible results four are parsers outright \(__c__,
__critcl__, __oo__, and __snit__\), one \(__container__\) provides
code which can be used in conjunction with a generic parser \(also known as a
grammar interpreter\), and the last two \(__json__ and __peg__\) are doing
double\-duty as input formats, allowing the transformation of grammars for
exchange, reformatting, and the like\.

The created parsers fall into three categories:

![](\.\./\.\./\.\./image/gen\_options\.png)

  - __Specialized parsers implemented in C__

    The fastest parsers are created when using the result formats __c__ and
    __critcl__\. The first returns the raw C code for the parser, while the
    latter wraps it into a Tcl package using *CriTcl*\.

    This makes the latter much easier to use than the former\. On the other hand,
    the former can be adapted to the users' requirements through a multitude of
    options, allowing for things like usage of the parser outside of a Tcl
    environment, something the __critcl__ format doesn't support\. As such
    the __c__ format is meant for more advanced users, or users with special
    needs\.

    A disadvantage of all the parsers in this section is the need to run them
    through a C compiler to make them actually executable\. This is not something
    everyone has the necessary tools for\. The parsers in the next section are
    for people under such restrictions\.

  - __Specialized parsers implemented in Tcl__

    As the parsers in this section are implemented in Tcl they are quite a bit
    slower than anything from the previous section\. On the other hand this
    allows them to be used in pure\-Tcl environments, or in environments which
    allow only a limited set of binary packages\. In the latter case it will be
    advantageous to lobby for the inclusion of the C\-based runtime support
    \(notes below\) into the environment to reduce the impact of Tcl's on the
    speed of these parsers\.

    The relevant formats are __snit__ and __oo__\. Both place their
    result into a Tcl package containing a __snit::type__, or TclOO
    __[class](\.\./\.\./\.\./index\.md\#class)__ respectively\.

    Of the supporting runtime, which is the package
    __[pt::rde](\.\./modules/pt/pt\_rdengine\.md)__, the user has to know
    nothing but that it does exist and that the parsers are dependent on it\.
    Knowledge of the API exported by the runtime for the parsers' consumption is
    *not* required by the parsers' users\.

  - __Interpreted parsing implemented in Tcl__

    The last category, grammar interpretation\. This means that an interpreter
    for parsing expression grammars takes the description of the grammar to
    parse input for, and uses it guide the parsing process\. This is the slowest
    of the available options, as the interpreter has to continually run through
    the configured grammar, whereas the specialized parsers of the previous
    sections have the relevant knowledge about the grammar baked into them\.

    The only places where using interpretation make sense is where the grammar
    for some input may be changed interactively by the user, as the
    interpretation allows for quick turnaround after each change, whereas the
    previous methods require the generation of a whole new parser, which is not
    as fast\. On the other hand, wherever the grammar to use is fixed, the
    previous methods are much more advantageous as the time to generate the
    parser is minuscule compared to the time the parser code is in use\.

    The relevant result format is __container__\. It \(quickly\) generates
    grammar descriptions \(instead of a full parser\) which match the API expected
    by ParserTools' grammar interpreter\. The latter is provided by the package
    __[pt::peg::interp](\.\./modules/pt/pt\_peg\_interp\.md)__\.

All the parsers generated by __critcl__, __snit__, and __oo__, and
the grammar interpreter share a common API for access to the actual parsing
functionality, making them all plug\-compatible\. It is described in the
*[Parser API](\.\./modules/pt/pt\_parser\_api\.md)* specification document\.

# <a name='section3'></a>PEG Specification Language

__peg__, a language for the specification of parsing expression grammars is
meant to be human readable, and writable as well, yet strict enough to allow its
processing by machine\. Like any computer language\. It was defined to make
writing the specification of a grammar easy, something the other formats found
in the Parser Tools do not lend themselves too\.

For either an introduction to or the formal specification of the language,
please go and read the *[PEG Language
Tutorial](\.\./modules/pt/pt\_peg\_language\.md)*\.

When used as a result\-format this format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-template__ string

    The value of this option is a string into which to put the generated text
    and the values of the other options\. The various locations for user\-data are
    expected to be specified with the placeholders listed below\. The default
    value is "__@code@__"\.

      * __@user@__

        To be replaced with the value of the option __\-user__\.

      * __@format@__

        To be replaced with the the constant __PEG__\.

      * __@file@__

        To be replaced with the value of the option __\-file__\.

      * __@name@__

        To be replaced with the value of the option __\-name__\.

      * __@code@__

        To be replaced with the generated text\.

# <a name='section4'></a>JSON Grammar Exchange

The __json__ format for parsing expression grammars was written as a data
exchange format not bound to Tcl\. It was defined to allow the exchange of
grammars with PackRat/PEG based parser generators for other languages\.

For the formal specification of the JSON grammar exchange format, please go and
read *[The JSON Grammar Exchange
Format](\.\./modules/pt/pt\_json\_language\.md)*\.

When used as a result\-format this format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-indented__ boolean

    If this option is set the system will break the generated JSON across lines
    and indent it according to its inner structure, with each key of a
    dictionary on a separate line\.

    If the option is not set \(the default\), the whole JSON object will be
    written on a single line, with minimum spacing between all elements\.

  - __\-aligned__ boolean

    If this option is set the system will ensure that the values for the keys in
    a dictionary are vertically aligned with each other, for a nice table
    effect\. To make this work this also implies that __\-indented__ is set\.

    If the option is not set \(the default\), the output is formatted as per the
    value of __indented__, without trying to align the values for dictionary
    keys\.

# <a name='section5'></a>C Parser Embedded In Tcl

The __critcl__ format is executable code, a parser for the grammar\. It is a
Tcl package with the actual parser implementation written in C and embedded in
Tcl via the __critcl__ package\.

This result\-format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-class__ string

    The value of this option is the name of the class to generate, without
    leading colons\. The default value is __CLASS__\.

    For a simple value __X__ without colons, like CLASS, the parser command
    will be __X__::__X__\. Whereas for a namespaced value __X::Y__
    the parser command will be __X::Y__\.

  - __\-package__ string

    The value of this option is the name of the package to generate\. The default
    value is __PACKAGE__\.

  - __\-version__ string

    The value of this option is the version of the package to generate\. The
    default value is __1__\.

# <a name='section6'></a>C Parser

The __c__ format is executable code, a parser for the grammar\. The parser
implementation is written in C and can be tweaked to the users' needs through a
multitude of options\.

The __critcl__ format, for example, is implemented as a canned configuration
of these options on top of the generator for __c__\.

This result\-format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-template__ string

    The value of this option is a string into which to put the generated text
    and the other configuration settings\. The various locations for user\-data
    are expected to be specified with the placeholders listed below\. The default
    value is "__@code@__"\.

      * __@user@__

        To be replaced with the value of the option __\-user__\.

      * __@format@__

        To be replaced with the the constant __C/PARAM__\.

      * __@file@__

        To be replaced with the value of the option __\-file__\.

      * __@name@__

        To be replaced with the value of the option __\-name__\.

      * __@code@__

        To be replaced with the generated Tcl code\.

    The following options are special, in that they will occur within the
    generated code, and are replaced there as well\.

      * __@statedecl@__

        To be replaced with the value of the option __state\-decl__\.

      * __@stateref@__

        To be replaced with the value of the option __state\-ref__\.

      * __@strings@__

        To be replaced with the value of the option __string\-varname__\.

      * __@self@__

        To be replaced with the value of the option __self\-command__\.

      * __@def@__

        To be replaced with the value of the option __fun\-qualifier__\.

      * __@ns@__

        To be replaced with the value of the option __namespace__\.

      * __@main@__

        To be replaced with the value of the option __main__\.

      * __@prelude@__

        To be replaced with the value of the option __prelude__\.

  - __\-state\-decl__ string

    A C string representing the argument declaration to use in the generated
    parsing functions to refer to the parsing state\. In essence type and
    argument name\. The default value is the string __RDE\_PARAM p__\.

  - __\-state\-ref__ string

    A C string representing the argument named used in the generated parsing
    functions to refer to the parsing state\. The default value is the string
    __p__\.

  - __\-self\-command__ string

    A C string representing the reference needed to call the generated parser
    function \(methods \.\.\.\) from another parser fonction, per the chosen
    framework \(template\)\. The default value is the empty string\.

  - __\-fun\-qualifier__ string

    A C string containing the attributes to give to the generated functions
    \(methods \.\.\.\), per the chosen framework \(template\)\. The default value is
    __static__\.

  - __\-namespace__ string

    The name of the C namespace the parser functions \(methods, \.\.\.\) shall reside
    in, or a general prefix to add to the function names\. The default value is
    the empty string\.

  - __\-main__ string

    The name of the main function \(method, \.\.\.\) to be called by the chosen
    framework \(template\) to start parsing input\. The default value is
    __\_\_main__\.

  - __\-string\-varname__ string

    The name of the variable used for the table of strings used by the generated
    parser, i\.e\. error messages, symbol names, etc\. The default value is
    __p\_string__\.

  - __\-prelude__ string

    A snippet of code to be inserted at the head of each generated parsing
    function\. The default value is the empty string\.

  - __\-indent__ integer

    The number of characters to indent each line of the generated code by\. The
    default value is __0__\.

  - __\-comments__ boolean

    A flag controlling the generation of code comments containing the original
    parsing expression a parsing function is for\. The default value is
    __on__\.

# <a name='section7'></a>Snit Parser

The __snit__ format is executable code, a parser for the grammar\. It is a
Tcl package holding a __snit::type__, i\.e\. a class, whose instances are
parsers for the input grammar\.

This result\-format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-class__ string

    The value of this option is the name of the class to generate, without
    leading colons\. Note, it serves double\-duty as the name of the package to
    generate too, if option __\-package__ is not specified, see below\. The
    default value is __CLASS__, applying if neither option __\-class__
    nor __\-package__ were specified\.

  - __\-package__ string

    The value of this option is the name of the package to generate, without
    leading colons\. Note, it serves double\-duty as the name of the class to
    generate too, if option __\-class__ is not specified, see above\. The
    default value is __PACKAGE__, applying if neither option
    __\-package__ nor __\-class__ were specified\.

  - __\-version__ string

    The value of this option is the version of the package to generate\. The
    default value is __1__\.

# <a name='section8'></a>TclOO Parser

The __oo__ format is executable code, a parser for the grammar\. It is a Tcl
package holding a __[TclOO](\.\./\.\./\.\./index\.md\#tcloo)__ class, whose
instances are parsers for the input grammar\.

This result\-format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-class__ string

    The value of this option is the name of the class to generate, without
    leading colons\. Note, it serves double\-duty as the name of the package to
    generate too, if option __\-package__ is not specified, see below\. The
    default value is __CLASS__, applying if neither option __\-class__
    nor __\-package__ were specified\.

  - __\-package__ string

    The value of this option is the name of the package to generate, without
    leading colons\. Note, it serves double\-duty as the name of the class to
    generate too, if option __\-class__ is not specified, see above\. The
    default value is __PACKAGE__, applying if neither option
    __\-package__ nor __\-class__ were specified\.

  - __\-version__ string

    The value of this option is the version of the package to generate\. The
    default value is __1__\.

# <a name='section9'></a>Grammar Container

The __container__ format is another form of describing parsing expression
grammars\. While data in this format is executable it does not constitute a
parser for the grammar\. It always has to be used in conjunction with the package
__[pt::peg::interp](\.\./modules/pt/pt\_peg\_interp\.md)__, a grammar
interpreter\.

The format represents grammars by a __snit::type__, i\.e\. class, whose
instances are API\-compatible to the instances of the
__[pt::peg::container](\.\./modules/pt/pt\_peg\_container\.md)__ package, and
which are preloaded with the grammar in question\.

This result\-format supports the following options:

  - __\-file__ string

    The value of this option is the name of the file or other entity from which
    the grammar came, for which the command is run\. The default value is
    __unknown__\.

  - __\-name__ string

    The value of this option is the name of the grammar we are processing\. The
    default value is __a\_pe\_grammar__\.

  - __\-user__ string

    The value of this option is the name of the user for which the command is
    run\. The default value is __unknown__\.

  - __\-mode__ __bulk__&#124;__incremental__

    The value of this option controls which methods of
    __[pt::peg::container](\.\./modules/pt/pt\_peg\_container\.md)__
    instances are used to specify the grammar, i\.e\. preload it into the
    container\. There are two legal values, as listed below\. The default is
    __bulk__\.

      * __bulk__

        In this mode the methods __start__, __add__, __modes__, and
        __rules__ are used to specify the grammar in a bulk manner, i\.e\. as
        a set of nonterminal symbols, and two dictionaries mapping from the
        symbols to their semantic modes and parsing expressions\.

        This mode is the default\.

      * __incremental__

        In this mode the methods __start__, __add__, __mode__, and
        __rule__ are used to specify the grammar piecemal, with each
        nonterminal having its own block of defining commands\.

  - __\-template__ string

    The value of this option is a string into which to put the generated code
    and the other configuration settings\. The various locations for user\-data
    are expected to be specified with the placeholders listed below\. The default
    value is "__@code@__"\.

      * __@user@__

        To be replaced with the value of the option __\-user__\.

      * __@format@__

        To be replaced with the the constant __CONTAINER__\.

      * __@file@__

        To be replaced with the value of the option __\-file__\.

      * __@name@__

        To be replaced with the value of the option __\-name__\.

      * __@mode@__

        To be replaced with the value of the option __\-mode__\.

      * __@code@__

        To be replaced with the generated code\.

# <a name='section10'></a>Example

In this section we are working a complete example, starting with a PEG grammar
and ending with running the parser generated from it over some input, following
the outline shown in the figure below:

![](\.\./\.\./\.\./image/flow\.png) Our grammar, assumed to the stored in the file
"calculator\.peg" is

    PEG calculator (Expression)
        Digit      <- '0'/'1'/'2'/'3'/'4'/'5'/'6'/'7'/'8'/'9'       ;
        Sign       <- '-' / '+'                                     ;
        Number     <- Sign? Digit+                                  ;
        Expression <- Term (AddOp Term)*                            ;
        MulOp      <- '*' / '/'                                     ;
        Term       <- Factor (MulOp Factor)*                        ;
        AddOp      <- '+'/'-'                                       ;
        Factor     <- '(' Expression ')' / Number                   ;
    END;

From this we create a snit\-based parser via

    pt generate snit calculator.tcl -class calculator -name calculator peg calculator.peg

which leaves us with the parser package and class written to the file
"calculator\.tcl"\. Assuming that this package is then properly installed in a
place where Tcl can find it we can now use this class via a script like

    package require calculator

    lassign $argv input
    set channel [open $input r]

    set parser [calculator]
    set ast [$parser parse $channel]
    $parser destroy
    close $channel

    ... now process the returned abstract syntax tree ...

where the abstract syntax tree stored in the variable will look like

    set ast {Expression 0 4
        {Factor 0 4
            {Term 0 2
                {Number 0 2
                    {Digit 0 0}
                    {Digit 1 1}
                    {Digit 2 2}
                }
            }
            {AddOp 3 3}
            {Term 4 4
                {Number 4 4
                    {Digit 4 4}
                }
            }
        }
    }

assuming that the input file and channel contained the text

    120+5

A more graphical representation of the tree would be

![](\.\./\.\./\.\./image/expr\_ast\.png) Regardless, at this point it is the user's
responsibility to work with the tree to reach whatever goal she desires\. I\.e\.
analyze it, transform it, etc\. The package
__[pt::ast](\.\./modules/pt/pt\_astree\.md)__ should be of help here,
providing commands to walk such ASTs structures in various ways\.

One important thing to note is that the parsers used here return a data
structure representing the structure of the input per the grammar underlying the
parser\. There are *no* callbacks during the parsing process, i\.e\. no *parsing
actions*, as most other parsers will have\.

Going back to the last snippet of code, the execution of the parser for some
input, note how the parser instance follows the specified *[Parser
API](\.\./modules/pt/pt\_parser\_api\.md)*\.

# <a name='section11'></a>Internals

This section is intended for users of the application which wish to modify or
extend it\. Users only interested in the generation of parsers can ignore it\.

The main functionality of the application is encapsulated in the package
__[pt::pgen](\.\./modules/pt/pt\_pgen\.md)__\. Please read it for more
information\.

# <a name='section12'></a>Bugs, Ideas, Feedback

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

[EBNF](\.\./\.\./\.\./index\.md\#ebnf), [LL\(k\)](\.\./\.\./\.\./index\.md\#ll\_k\_),
[PEG](\.\./\.\./\.\./index\.md\#peg), [TDPL](\.\./\.\./\.\./index\.md\#tdpl),
[context\-free languages](\.\./\.\./\.\./index\.md\#context\_free\_languages),
[expression](\.\./\.\./\.\./index\.md\#expression),
[grammar](\.\./\.\./\.\./index\.md\#grammar),
[matching](\.\./\.\./\.\./index\.md\#matching),
[parser](\.\./\.\./\.\./index\.md\#parser), [parsing
expression](\.\./\.\./\.\./index\.md\#parsing\_expression), [parsing expression
grammar](\.\./\.\./\.\./index\.md\#parsing\_expression\_grammar), [push down
automaton](\.\./\.\./\.\./index\.md\#push\_down\_automaton), [recursive
descent](\.\./\.\./\.\./index\.md\#recursive\_descent),
[state](\.\./\.\./\.\./index\.md\#state), [top\-down parsing
languages](\.\./\.\./\.\./index\.md\#top\_down\_parsing\_languages),
[transducer](\.\./\.\./\.\./index\.md\#transducer)

# <a name='category'></a>CATEGORY

Parsing and Grammars

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
