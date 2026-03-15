
[//000000001]: # (doctoc\_intro \- Documentation tools)
[//000000002]: # (Generated from file 'doctoc\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctoc\_intro\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctoc\_intro \- doctoc introduction

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

*[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* \(short for *documentation tables
of contents*\) stands for a set of related, yet different, entities which are
working together for the easy creation and transformation of tables of contents
for documentation\. These are

  1. A tcl based language for the semantic markup of a table of contents\. Markup
     is represented by Tcl commands\.

  1. A package providing the ability to read and transform texts written in that
     markup language\. It is important to note that the actual transformation of
     the input text is delegated to plugins\.

  1. An API describing the interface between the package above and a plugin\.

Which of the more detailed documents are relevant to the reader of this
introduction depends on their role in the documentation process\.

  1. A *writer* of documentation has to understand the markup language itself\.
     A beginner to doctoc should read the more informally written *[doctoc
     language introduction](doctoc\_lang\_intro\.md)* first\. Having digested
     this the formal *[doctoc language syntax](doctoc\_lang\_syntax\.md)*
     specification should become understandable\. A writer experienced with
     doctoc may only need the *[doctoc language command
     reference](doctoc\_lang\_cmdref\.md)* from time to time to refresh her
     memory\.

     While a document is written the __dtp__ application can be used to
     validate it, and after completion it also performs the conversion into the
     chosen system of visual markup, be it \*roff, HTML, plain text, wiki, etc\.
     The simpler __[dtplite](\.\./\.\./apps/dtplite\.md)__ application makes
     internal use of doctoc when handling directories of documentation,
     automatically generating a proper table of contents for them\.

  1. A *processor* of documentation written in the
     *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* markup language has to know
     which tools are available for use\.

     The main tool is the aforementioned __dtp__ application provided by
     Tcllib\. The simpler __[dtplite](\.\./\.\./apps/dtplite\.md)__ does not
     expose doctoc to the user\. At the bottom level, common to both
     applications, however sits the package __doctoools::toc__, providing
     the basic facilities to read and process files containing text in the
     doctoc format\.

  1. At last, but not least, *plugin writers* have to understand the
     interaction between the __[doctools::toc](doctoc\.md)__ package and
     its plugins, as described in the *[doctoc plugin API
     reference](doctoc\_plugin\_apiref\.md)*\.

# <a name='section2'></a>RELATED FORMATS

doctoc does not stand alone, it has two companion formats\. These are called
*[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)* and
*[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)*, and they are for the markup
of *keyword indices*, and general documentation, respectively\. They are
described in their own sets of documents, starting at the *[docidx
introduction](docidx\_intro\.md)* and the *[doctools
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

[docidx\_intro](docidx\_intro\.md),
[doctoc\_lang\_cmdref](doctoc\_lang\_cmdref\.md),
[doctoc\_lang\_faq](doctoc\_lang\_faq\.md),
[doctoc\_lang\_intro](doctoc\_lang\_intro\.md),
[doctoc\_lang\_syntax](doctoc\_lang\_syntax\.md),
[doctoc\_plugin\_apiref](doctoc\_plugin\_apiref\.md),
[doctools::toc](doctoc\.md), [doctools\_intro](doctools\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[markup](\.\./\.\./\.\./\.\./index\.md\#markup), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup), [table of
contents](\.\./\.\./\.\./\.\./index\.md\#table\_of\_contents),
[toc](\.\./\.\./\.\./\.\./index\.md\#toc)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
