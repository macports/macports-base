
[//000000001]: # (bench\_lang\_intro \- Benchmarking/Performance tools)
[//000000002]: # (Generated from file 'bench\_lang\_intro\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bench\_lang\_intro\(n\) 1\.0 tcllib "Benchmarking/Performance tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bench\_lang\_intro \- bench language introduction

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

      - [Fundamentals](#subsection1)

      - [Basics](#subsection2)

      - [Pre\- and postprocessing](#subsection3)

      - [Advanced pre\- and postprocessing](#subsection4)

  - [FURTHER READING](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

This document is an informal introduction to version 1 of the bench language
based on a multitude of examples\. After reading this a benchmark writer should
be ready to understand the formal *[bench language
specification](bench\_lang\_spec\.md)*\.

## <a name='subsection1'></a>Fundamentals

In the broadest terms possible the *[bench
language](\.\./\.\./\.\./\.\./index\.md\#bench\_language)* is essentially Tcl, plus a
number of commands to support the declaration of benchmarks\. A document written
in this language is a Tcl script and has the same syntax\.

## <a name='subsection2'></a>Basics

One of the most simplest benchmarks which can be written in bench is

    bench -desc LABEL -body {
        set a b
    }

This code declares a benchmark named __LABEL__ which measures the time it
takes to assign a value to a variable\. The Tcl code doing this assignment is the
__\-body__ of the benchmark\.

## <a name='subsection3'></a>Pre\- and postprocessing

Our next example demonstrates how to declare *initialization* and
*[cleanup](\.\./\.\./\.\./\.\./index\.md\#cleanup)* code, i\.e\. code computing
information for the use of the __\-body__, and for releasing such resources
after the measurement is done\. They are the __\-pre__\- and the
__\-post__\-body, respectively\.

In our example, directly drawn from the benchmark suite of Tcllib's
__[aes](\.\./aes/aes\.md)__ package, the concrete initialization code
constructs the key schedule used by the encryption command whose speed we
measure, and the cleanup code releases any resources bound to that schedule\.

> bench \-desc "AES\-$\{len\} ECB encryption core" __\-pre__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;set key \[aes::Init ecb $k $i\]  
> \} \-body \{  
> &nbsp;&nbsp;&nbsp;&nbsp;aes::Encrypt $key $p  
> \} __\-post__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;aes::Final $key  
> \}

## <a name='subsection4'></a>Advanced pre\- and postprocessing

Our last example again deals with initialization and cleanup code\. To see the
difference to the regular initialization and cleanup discussed in the last
section it is necessary to know a bit more about how bench actually measures the
speed of the the __\-body__\.

Instead of running the __\-body__ just once the system actually executes the
__\-body__ several hundred times and then returns the average of the found
execution times\. This is done to remove environmental effects like machine load
from the result as much as possible, with outliers canceling each other out in
the average\.

The drawback of doing things this way is that when we measure operations which
are not idempotent we will most likely not measure the time for the operation we
want, but of the state\(s\) the system is in after the first iteration, a mixture
of things we have no interest in\.

Should we wish, for example, to measure the time it takes to include an element
into a set, with the element not yet in the set, and the set having specific
properties like being a shared Tcl\_Obj, then the first iteration will measure
the time for this\. *However* all subsequent iterations will measure the time
to include an element which is already in the set, and the Tcl\_Obj holding the
set will not be shared anymore either\. In the end the timings taken for the
several hundred iterations of this state will overwhelm the time taken from the
first iteration, the only one which actually measured what we wanted\.

The advanced initialization and cleanup codes, __\-ipre__\- and the
__\-ipost__\-body respectively, are present to solve this very problem\. While
the regular initialization and cleanup codes are executed before and after the
whole series of iterations the advanced codes are executed before and after each
iteration of the body, without being measured themselves\. This allows them to
bring the system into the exact state the body wishes to measure\.

Our example, directly drawn from the benchmark suite of Tcllib's
__[struct::set](\.\./struct/struct\_set\.md)__ package, is for exactly the
example we used above to demonstrate the necessity for the advanced
initialization and cleanup\. Its concrete initialization code constructs a
variable refering to a set with specific properties \(The set has a string
representation, which is shared\) affecting the speed of the inclusion command,
and the cleanup code releases the temporary variables created by this
initialization\.

> bench \-desc "set include, missing <SC> x$times $n" __\-ipre__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;set A $sx\($times,$n\)  
> &nbsp;&nbsp;&nbsp;&nbsp;set B $A  
> \} \-body \{  
> &nbsp;&nbsp;&nbsp;&nbsp;struct::set include A x  
> \} __\-ipost__ \{  
> &nbsp;&nbsp;&nbsp;&nbsp;unset A B  
> \}

# <a name='section2'></a>FURTHER READING

Now that this document has been digested the reader, assumed to be a *writer*
of benchmarks, he should be fortified enough to be able to understand the formal
*bench language specfication*\. It will also serve as the detailed
specification and cheat sheet for all available commands and their syntax\.

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

[bench\_intro](bench\_intro\.md), [bench\_lang\_spec](bench\_lang\_spec\.md)

# <a name='keywords'></a>KEYWORDS

[bench language](\.\./\.\./\.\./\.\./index\.md\#bench\_language),
[benchmark](\.\./\.\./\.\./\.\./index\.md\#benchmark),
[examples](\.\./\.\./\.\./\.\./index\.md\#examples),
[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[testing](\.\./\.\./\.\./\.\./index\.md\#testing)

# <a name='category'></a>CATEGORY

Benchmark tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
