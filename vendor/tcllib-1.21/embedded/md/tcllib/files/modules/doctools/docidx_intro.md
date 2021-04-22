
[//000000001]: # (docidx\_intro \- Documentation tools)
[//000000002]: # (Generated from file 'docidx\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (docidx\_intro\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

docidx\_intro \- docidx introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [RELATED FORMATS](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

*[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)* \(short for *documentation tables
of contents*\) stands for a set of related, yet different, entities which are
working together for the easy creation and transformation of keyword\-based
indices for documentation\. These are

  1. A tcl based language for the semantic markup of a keyword index\. Markup is
     represented by Tcl commands\.

  1. A package providing the ability to read and transform texts written in that
     markup language\. It is important to note that the actual transformation of
     the input text is delegated to plugins\.

  1. An API describing the interface between the package above and a plugin\.

Which of the more detailed documents are relevant to the reader of this
introduction depends on their role in the documentation process\.

  1. A *writer* of documentation has to understand the markup language itself\.
     A beginner to docidx should read the more informally written *[docidx
     language introduction](docidx\_lang\_intro\.md)* first\. Having digested
     this the formal *[docidx language syntax](docidx\_lang\_syntax\.md)*
     specification should become understandable\. A writer experienced with
     docidx may only need the *[docidx language command
     reference](docidx\_lang\_cmdref\.md)* from time to time to refresh her
     memory\.

     While a document is written the __dtp__ application can be used to
     validate it, and after completion it also performs the conversion into the
     chosen system of visual markup, be it \*roff, HTML, plain text, wiki, etc\.
     The simpler __[dtplite](\.\./\.\./apps/dtplite\.md)__ application makes
     internal use of docidx when handling directories of documentation,
     automatically generating a proper keyword index for them\.

  1. A *processor* of documentation written in the
     *[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)* markup language has to know
     which tools are available for use\.

     The main tool is the aforementioned __dtp__ application provided by
     Tcllib\. The simpler __[dtplite](\.\./\.\./apps/dtplite\.md)__ does not
     expose docidx to the user\. At the bottom level, common to both
     applications, however sits the package __doctoools::idx__, providing
     the basic facilities to read and process files containing text in the
     docidx format\.

  1. At last, but not least, *plugin writers* have to understand the
     interaction between the
     __[doctools::idx](\.\./doctools2idx/idx\_container\.md)__ package and
     its plugins, as described in the *[docidx plugin API
     reference](docidx\_plugin\_apiref\.md)*\.

# <a name='section2'></a>RELATED FORMATS

docidx does not stand alone, it has two companion formats\. These are called
*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* and
*[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)*, and they are for the markup
of *tables of contents*, and general documentation, respectively\. They are
described in their own sets of documents, starting at the *[doctoc
introduction](doctoc\_intro\.md)* and the *[doctools
introduction](doctools\_intro\.md)*, respectively\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *doctools* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[docidx\_lang\_cmdref](docidx\_lang\_cmdref\.md),
[docidx\_lang\_faq](docidx\_lang\_faq\.md),
[docidx\_lang\_intro](docidx\_lang\_intro\.md),
[docidx\_lang\_syntax](docidx\_lang\_syntax\.md),
[docidx\_plugin\_apiref](docidx\_plugin\_apiref\.md),
[doctoc\_intro](doctoc\_intro\.md),
[doctools::idx](\.\./doctools2idx/idx\_container\.md),
[doctools\_intro](doctools\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[index](\.\./\.\./\.\./\.\./index\.md\#index), [keyword
index](\.\./\.\./\.\./\.\./index\.md\#keyword\_index),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
