
[//000000001]: # (bench::out::text \- Benchmarking/Performance tools)
[//000000002]: # (Generated from file 'bench\_wtext\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bench::out::text\(n\) 0\.1\.2 tcllib "Benchmarking/Performance tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bench::out::text \- bench::out::text \- Formatting benchmark results as human
readable text

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
package require bench::out::text ?0\.1\.2?  

[__::bench::out::text__ *bench\_result*](#1)  

# <a name='description'></a>DESCRIPTION

This package provides commands for fomatting of benchmark results into human
readable text\.

A reader interested in the generation or processing of such results should go
and read *[bench \- Processing benchmark suites](bench\.md)* instead\.

If the bench language itself is the actual interest please start with the
*[bench language introduction](bench\_lang\_intro\.md)* and then proceed from
there to the formal *[bench language specification](bench\_lang\_spec\.md)*\.

# <a name='section2'></a>PUBLIC API

  - <a name='1'></a>__::bench::out::text__ *bench\_result*

    This command formats the specified benchmark result for output to a file,
    socket, etc\. This specific command generates human readable text\.

    For other formatting styles see the packages __[bench](bench\.md)__
    and __[bench::out::csv](bench\_wcsv\.md)__ which provide commands to
    format benchmark results in raw form, or as importable CSV data,
    respectively\.

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

[bench](bench\.md), [bench::out::csv](bench\_wcsv\.md)

# <a name='keywords'></a>KEYWORDS

[benchmark](\.\./\.\./\.\./\.\./index\.md\#benchmark),
[formatting](\.\./\.\./\.\./\.\./index\.md\#formatting), [human
readable](\.\./\.\./\.\./\.\./index\.md\#human\_readable),
[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[testing](\.\./\.\./\.\./\.\./index\.md\#testing),
[text](\.\./\.\./\.\./\.\./index\.md\#text)

# <a name='category'></a>CATEGORY

Benchmark tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
