
[//000000001]: # (bench::in \- Benchmarking/Performance tools)
[//000000002]: # (Generated from file 'bench\_read\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bench::in\(n\) 0\.1 tcllib "Benchmarking/Performance tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bench::in \- bench::in \- Reading benchmark results

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PUBLIC API](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require csv  
package require bench::in ?0\.1?  

[__::bench::in::read__ *file*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides a command for reading benchmark results from files,
sockets, etc\.

A reader interested in the creation, processing or writing of such results
should go and read *[bench \- Processing benchmark suites](bench\.md)*
instead\.

If the bench language itself is the actual interest please start with the
*[bench language introduction](bench\_lang\_intro\.md)* and then proceed from
there to the formal *[bench language specification](bench\_lang\_spec\.md)*\.

# <a name='section2'></a>PUBLIC API

  - <a name='1'></a>__::bench::in::read__ *file*

    This command reads a benchmark result from the specified *file* and
    returns it as its result\. The command understands the three formats created
    by the commands

      * __bench::out::raw__

        Provided by package __[bench](bench\.md)__\.

      * __[bench::out::csv](bench\_wcsv\.md)__

        Provided by package __[bench::out::csv](bench\_wcsv\.md)__\.

      * __[bench::out::text](bench\_wtext\.md)__

        Provided by package __[bench::out::text](bench\_wtext\.md)__\.

    and automatically detects which format is used by the input file\.

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

[bench](bench\.md), [bench::out::csv](bench\_wcsv\.md),
[bench::out::text](bench\_wtext\.md), [bench\_intro](bench\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[benchmark](\.\./\.\./\.\./\.\./index\.md\#benchmark),
[csv](\.\./\.\./\.\./\.\./index\.md\#csv),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting), [human
readable](\.\./\.\./\.\./\.\./index\.md\#human\_readable),
[parsing](\.\./\.\./\.\./\.\./index\.md\#parsing),
[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[reading](\.\./\.\./\.\./\.\./index\.md\#reading),
[testing](\.\./\.\./\.\./\.\./index\.md\#testing),
[text](\.\./\.\./\.\./\.\./index\.md\#text)

# <a name='category'></a>CATEGORY

Benchmark tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
