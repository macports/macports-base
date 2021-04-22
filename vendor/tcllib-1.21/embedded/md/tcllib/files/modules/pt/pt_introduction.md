
[//000000001]: # (pt\_introduction \- Parser Tools)
[//000000002]: # (Generated from file 'pt\_introduction\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pt\_introduction\(n\) 1 tcllib "Parser Tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pt\_introduction \- Introduction to Parser Tools

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Parser Tools Architecture](#section2)

      - [User Packages](#subsection1)

      - [Core Packages](#subsection2)

      - [Support Packages](#subsection3)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  

# <a name='description'></a>DESCRIPTION

Welcome to the Parser Tools, a system for the creation and manipulation of
parsers and the grammars driving them\.

What are your goals which drove you here ?

  1. Do you simply wish to create a parser for some language ?

     In that case have a look at our parser generator application,
     __[pt](\.\./\.\./apps/pt\.md)__, or, for a slightly deeper access, the
     package underneath it, __[pt::pgen](pt\_pgen\.md)__\.

  1. Do you wish to know more about the architecture of the system ?

     This is described in the section [Parser Tools
     Architecture](#section2), below

  1. Is your interest in the theoretical background upon which the packages and
     tools are build ?

     See the *[Introduction to Parsing Expression
     Grammars](pt\_peg\_introduction\.md)*\.

# <a name='section2'></a>Parser Tools Architecture

The system can be split into roughly three layers, as seen in the figure below

![](\.\./\.\./\.\./\.\./image/architecture\.png) These layers are, from high to low:

  1. At the top we have the application and the packages using the packages of
     the layer below to implement common usecases\. One example is the
     aforementioned __[pt::pgen](pt\_pgen\.md)__ which provides a parser
     generator\.

     The list of packages belonging to this layer can be found in section [User
     Packages](#subsection1)

  1. In this layer we have the packages which provide the core of the
     functionality for the whole system\. They are, in essence, a set of blocks
     which can be combined in myriad ways, like Lego \(tm\)\. The packages in the
     previous level are 'just' pre\-fabricated combinations to cover the most
     important use cases\.

     The list of packages belonging to this layer can be found in section [Core
     Packages](#subsection2)

  1. Last, but not least is the layer containing support packages providing
     generic functionality which not necessarily belong into the module\.

     The list of packages belonging to this layer can be found in section
     [Support Packages](#subsection3)

## <a name='subsection1'></a>User Packages

  - __[pt::pgen](pt\_pgen\.md)__

## <a name='subsection2'></a>Core Packages

This layer is further split into six sections handling the storage, import,
export, transformation, and execution of grammars, plus grammar specific support
packages\.

  - Storage

      * __[pt::peg::container](pt\_peg\_container\.md)__

  - Export

      * __[pt::peg::export](pt\_peg\_export\.md)__

      * __[pt::peg::export::container](pt\_peg\_export\_container\.md)__

      * __[pt::peg::export::json](pt\_peg\_export\_json\.md)__

      * __[pt::peg::export::peg](pt\_peg\_export\_peg\.md)__

      * __[pt::peg::to::container](pt\_peg\_to\_container\.md)__

      * __[pt::peg::to::json](pt\_peg\_to\_json\.md)__

      * __[pt::peg::to::peg](pt\_peg\_to\_peg\.md)__

      * __[pt::peg::to::param](pt\_peg\_to\_param\.md)__

      * __[pt::peg::to::tclparam](pt\_peg\_to\_tclparam\.md)__

      * __[pt::peg::to::cparam](pt\_peg\_to\_cparam\.md)__

  - Import

      * __[pt::peg::import](pt\_peg\_import\.md)__

      * __[pt::peg::import::container](pt\_peg\_import\_container\.md)__

      * __[pt::peg::import::json](pt\_peg\_import\_json\.md)__

      * __[pt::peg::import::peg](pt\_peg\_import\_peg\.md)__

      * __[pt::peg::from::container](pt\_peg\_from\_container\.md)__

      * __[pt::peg::from::json](pt\_peg\_from\_json\.md)__

      * __[pt::peg::from::peg](pt\_peg\_from\_peg\.md)__

  - Transformation

  - Execution

      * __[pt::peg::interp](pt\_peg\_interp\.md)__

      * __[pt::rde](pt\_rdengine\.md)__

  - Support

      * __[pt::tclparam::configuration::snit](pt\_tclparam\_config\_snit\.md)__

      * __[pt::tclparam::configuration::tcloo](pt\_tclparam\_config\_tcloo\.md)__

      * __[pt::cparam::configuration::critcl](pt\_cparam\_config\_critcl\.md)__

      * __[pt::ast](pt\_astree\.md)__

      * __[pt::pe](pt\_pexpression\.md)__

      * __[pt::peg](pt\_pegrammar\.md)__

## <a name='subsection3'></a>Support Packages

  - __[pt::peg::container::peg](pt\_peg\_container\_peg\.md)__

  - __text::write__

  - __configuration__

  - __paths__

  - __char__

# <a name='section3'></a>Bugs, Ideas, Feedback

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
