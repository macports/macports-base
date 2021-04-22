
[//000000001]: # (doctools2idx\_introduction \- Documentation tools)
[//000000002]: # (Generated from file 'idx\_introduction\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (doctools2idx\_introduction\(n\) 2\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

doctools2idx\_introduction \- DocTools \- Keyword indices

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Related formats](#section2)

  - [Package Overview](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

*[docidx](\.\./\.\./\.\./\.\./index\.md\#docidx)* \(short for *documentation
indices*\) stands for a set of related, yet different, entities which are
working together for the easy creation and transformation of keyword indices for
documentation\.

These are

  1. A tcl based language for the semantic markup of a keyword index\. Markup is
     represented by Tcl commands\. Beginners should start with the *[docidx
     language introduction](\.\./doctools/docidx\_lang\_intro\.md)*\. The formal
     specification is split over two documents, one dealing with the *[docidx
     language syntax](\.\./doctools/docidx\_lang\_syntax\.md)*, the other a
     *[docidx language command
     reference](\.\./doctools/docidx\_lang\_cmdref\.md)*\.

  1. A set of packages for the programmatic manipulation of keyword indices in
     memory, and their conversion between various formats, reading and writing\.
     The aforementioned markup language is one of the formats which can be both
     read from and written to\.

  1. The system for the conversion of indices is based on a plugin mechanism,
     for this we have two APIs describing the interface between the packages
     above and the import/export plugins\.

Which of the more detailed documents are relevant to the reader of this
introduction depends on their role in the documentation process\.

  1. A *writer* of documentation has to understand the markup language itself\.
     A beginner to docidx should read the more informally written *[docidx
     language introduction](\.\./doctools/docidx\_lang\_intro\.md)* first\. Having
     digested this the formal *[docidx language
     syntax](\.\./doctools/docidx\_lang\_syntax\.md)* specification should become
     understandable\. A writer experienced with docidx may only need the
     *[docidx language command
     reference](\.\./doctools/docidx\_lang\_cmdref\.md)* from time to time to
     refresh her memory\.

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
     applications, however we find the three packages providing the basic
     facilities to handle keyword indices, i\.e\. import from textual formats,
     programmatic manipulation in memory, and export to textual formats\. These
     are

       - __[doctools::idx](idx\_container\.md)__

         Programmatic manipulation of keyword indices in memory\.

       - __[doctools::idx::import](idx\_import\.md)__

         Import of keyword indices from various textual formats\. The set of
         supported formats is extensible through plugin packages\.

       - __[doctools::idx::export](idx\_export\.md)__

         Export of keyword indices to various textual formats\. The set of
         supported formats is extensible through plugin packages\.

     See also section [Package Overview](#section3) for an overview of the
     dependencies between these and other, supporting packages\.

  1. At last, but not least, *plugin writers* have to understand the
     interaction between the import and export packages and their plugins\. These
     APIs are described in the documentation for the two relevant packages, i\.e\.

       - __[doctools::idx::import](idx\_import\.md)__

       - __[doctools::idx::export](idx\_export\.md)__

# <a name='section2'></a>Related formats

The docidx format does not stand alone, it has two companion formats\. These are
called *[doctoc](\.\./\.\./\.\./\.\./index\.md\#doctoc)* and
*[doctools](\.\./\.\./\.\./\.\./index\.md\#doctools)*, and they are intended for the
markup of *tables of contents*, and of general documentation, respectively\.
They are described in their own sets of documents, starting at the *DocTools \-
Tables Of Contents* and the *DocTools \- General*, respectively\.

# <a name='section3'></a>Package Overview

                                        ~~~~~~~~~~~ doctools::idx ~~~~~~~~~~~
                                       ~~                   |               ~~
                    doctools::idx::export ~~~~~~~~~~~~~~~~~ | ~~~~~~~~~~~~~ doctools::idx::import
                            |                               |                       |
            +---------------+-------------------------+     |    +------------------+---------------+-----------------------+---------------+
            |               |                         |     |    |                  |               |                       |               |
    struct::map             =                         |     |    |                  =       doctools::include       struct::map      fileutil::paths
                            |                         |     |    |                  |
                    doctools::idx::export::<*>        |     |    |          doctools::idx::import::<*>
                            docidx                    |     |    |                  docidx, json
                            json                      |     |    |                  |           \
                            html                      |     |    |          doctools::idx::parse \
                            nroff                     |     |    |                  |             \
                            wiki                      |     |    |  +---------------+              json
                            text                      |     |    |  |               |
                                                    doctools::idx::structure        |
                                                                                    |
                                                                            +-------+---------------+
                                                                            |                       |
              doctools::html  doctools::html::cssdefaults           doctools::tcl::parse    doctools::msgcat
                    |                                                                               |
              doctools::text  doctools::nroff::man_macros                                           =
                                                                                                    |
                                                                                            doctools::msgcat::idx::<*>
                                                                                                    c, en, de, fr
                                                                                                    (fr == en for now)
            ~~      Interoperable objects, without actual package dependencies
            --      Package dependency, higher requires lower package
            =       Dynamic dependency through plugin system
            <*>     Multiple packages following the given form of naming.

# <a name='section4'></a>Bugs, Ideas, Feedback

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

[docidx\_intro](\.\./doctools/docidx\_intro\.md),
[doctoc\_intro](\.\./doctools/doctoc\_intro\.md),
[doctools](\.\./doctools/doctools\.md), doctools2doc\_introduction,
[doctools2toc\_introduction](\.\./doctools2toc/toc\_introduction\.md),
[doctools\_lang\_cmdref](\.\./doctools/doctools\_lang\_cmdref\.md),
[doctools\_lang\_faq](\.\./doctools/doctools\_lang\_faq\.md),
[doctools\_lang\_intro](\.\./doctools/doctools\_lang\_intro\.md),
[doctools\_lang\_syntax](\.\./doctools/doctools\_lang\_syntax\.md),
[doctools\_plugin\_apiref](\.\./doctools/doctools\_plugin\_apiref\.md)

# <a name='keywords'></a>KEYWORDS

[conversion](\.\./\.\./\.\./\.\./index\.md\#conversion),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting),
[index](\.\./\.\./\.\./\.\./index\.md\#index), [keyword
index](\.\./\.\./\.\./\.\./index\.md\#keyword\_index),
[markup](\.\./\.\./\.\./\.\./index\.md\#markup),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[plugin](\.\./\.\./\.\./\.\./index\.md\#plugin), [semantic
markup](\.\./\.\./\.\./\.\./index\.md\#semantic\_markup)

# <a name='category'></a>CATEGORY

Documentation tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2009 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
