
[//000000001]: # (markdown \- Markdown to HTML Converter)
[//000000002]: # (Generated from file 'markdown\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (markdown\(n\) 1\.2\.2 tcllib "Markdown to HTML Converter")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

markdown \- Converts Markdown text to HTML

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Supported markdown syntax](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require Markdown 1\.2\.2  
package require textutil ?0\.8?  

[__::Markdown::convert__ *markdown*](#1)  
[__::Markdown::register__ *langspec* *converter*](#2)  
[__::Markdown::get\_lang\_counter__](#3)  
[__::Markdown::reset\_lang\_counter__](#4)  

# <a name='description'></a>DESCRIPTION

The package __Markdown__ provides a command to convert Markdown annotated
text into HMTL\.

  - <a name='1'></a>__::Markdown::convert__ *markdown*

    This command takes in a block of Markdown text, and returns a block of HTML\.

    The converter supports two types of syntax highlighting for fenced code
    blocks: highlighting via a registered converter \(see
    __::Markdown::register__\), or pure JavaScript highlighting, e\.g\. via
    "highlight\.js", where the language specifier used in the markup is set as
    CSS class of the "code" element in the returned markup\.

  - <a name='2'></a>__::Markdown::register__ *langspec* *converter*

    Register a language specific converter for prettifying a code block \(e\.g\.
    syntax highlighting\)\. Markdown supports fenced code blocks with an optional
    language specifier \(e\.g\. "tcl"\)\. When the markdown parser processes such a
    code block and a converter for the specified langspec is registered, the
    converter is called with the raw code block as argument\. The converter is
    supposed to return the markup of the code block as result\. The specified
    converter can be an arbitrary Tcl command, the raw text block is added as
    last argument upon invocation\.

  - <a name='3'></a>__::Markdown::get\_lang\_counter__

    Return a dict of language specifier and number of occurrences in fenced code
    blocks\. This function can be used e\.g\. to detect, whether some CSS or
    JavaScript headers should be included for rendering without the need of
    postprocessing the rendered result\.

  - <a name='4'></a>__::Markdown::reset\_lang\_counter__

    Reset the language counters\.

# <a name='section2'></a>Supported markdown syntax

This markdown converter supports the original markdown by Gruber and Swartz \(see
their [syntax](https://daringfireball\.net/projects/markdown/syntax) page for
details\):

  - paragraphs

  - atx\- and setext\-style headers

  - blockquotes

  - emphasis and strong emphasis

  - unordered and ordered lists

  - inline\-style, reference\-style and automatic links

  - inline\- and reference\-style images

  - inline code

  - code blocks \(with four indent spaces or one tab\)

  - inline HTML

  - backslash escapes

  - horizontal rules

In addition, the following extended markdown sytax is supported, taken from PHP
Markdown Extra and GFM \(Github Flavoured Markdown\):

  - pipe tables

  - fenced code blocks \(with an optional language specifier\)

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *textutil* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='category'></a>CATEGORY

Text processing
