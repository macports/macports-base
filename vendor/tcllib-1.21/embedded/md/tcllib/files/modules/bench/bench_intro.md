
[//000000001]: # (bench\_intro \- Benchmarking/Performance tools)
[//000000002]: # (Generated from file 'bench\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bench\_intro\(n\) 1\.0 tcllib "Benchmarking/Performance tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bench\_intro \- bench introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [HISTORICAL NOTES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

The *[bench](bench\.md)* \(short for *benchmark tools*\), is a set of
related, yet different, entities which are working together for the easy
creation and execution of performance test suites, also known as benchmarks\.
These are

  1. A tcl based language for the declaration of test cases\. A test case is
     represented by a tcl command declaring the various parts needed to execute
     it, like setup, cleanup, the commands to test, etc\.

  1. A package providing the ability to execute test cases written in that
     language\.

Which of the more detailed documents are relevant to the reader of this
introduction depends on their role in the benchmarking process\.

  1. A *writer* of benchmarks has to understand the bench language itself\. A
     beginner to bench should read the more informally written *[bench
     language introduction](bench\_lang\_intro\.md)* first\. Having digested
     this the formal *[bench language specification](bench\_lang\_spec\.md)*
     should become understandable\. A writer experienced with bench may only need
     this last document from time to time, to refresh her memory\.

  1. A *user* of benchmark suites written in the *[bench](bench\.md)*
     language has to know which tools are available for use\. At the bottom level
     sits the package __[bench](bench\.md)__, providing the basic
     facilities to read and execute files containing benchmarks written in the
     bench language, and to manipulate benchmark results\.

# <a name='section2'></a>HISTORICAL NOTES

This module and package have been derived from Jeff Hobbs' __tclbench__
application for the benchmarking of the Tcl core and its ancestor
"runbench\.tcl"\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *bench* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[bench](bench\.md), bench\_lang\_faq,
[bench\_lang\_intro](bench\_lang\_intro\.md),
[bench\_lang\_spec](bench\_lang\_spec\.md)

# <a name='keywords'></a>KEYWORDS

[bench language](\.\./\.\./\.\./\.\./index\.md\#bench\_language),
[benchmark](\.\./\.\./\.\./\.\./index\.md\#benchmark),
[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[testing](\.\./\.\./\.\./\.\./index\.md\#testing)

# <a name='category'></a>CATEGORY

Benchmark tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
