
[//000000001]: # (bench\_lang\_spec \- Documentation tools)
[//000000002]: # (Generated from file 'bench\_lang\_spec\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (bench\_lang\_spec\(n\) 1\.0 tcllib "Documentation tools")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

bench\_lang\_spec \- bench language specification

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

[__bench\_rm__ *path*\.\.\.](#1)  
[__bench\_tmpfile__](#2)  
[__[bench](bench\.md)__ *options*\.\.\.](#3)  

# <a name='description'></a>DESCRIPTION

This document specifies both names and syntax of all the commands which together
are the bench language, version 1\. As this document is intended to be a
reference the commands are listed in alphabetical order, and the descriptions
are relatively short\. A beginner should read the more informally written
*[bench language introduction](bench\_lang\_intro\.md)* first\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__bench\_rm__ *path*\.\.\.

    This command silently removes the files specified as its arguments and then
    returns the empty string as its result\. The command is *trusted*, there is
    no checking if the specified files are outside of whatever restricted area
    the benchmarks are run in\.

  - <a name='2'></a>__bench\_tmpfile__

    This command returns the path to a bench specific unique temporary file\. The
    uniqueness means that multiple calls will return different paths\. While the
    path may exist from previous runs, the command itself does *not* create
    aynthing\.

    The base location of the temporary files is platform dependent:

      * Unix, and indeterminate platform

        "/tmp"

      * Windows

        __$TEMP__

      * Anything else

        The current working directory\.

  - <a name='3'></a>__[bench](bench\.md)__ *options*\.\.\.

    This command declares a single benchmark\. Its result is the empty string\.
    All parts of the benchmark are declared via options, and their values\. The
    options can occur in any order\. The accepted options are:

      * __\-body__ script

        The argument of this option declares the body of the benchmark, the Tcl
        script whose performance we wish to measure\. This option, and
        __\-desc__, are the two required parts of each benchmark\.

      * __\-desc__ msg

        The argument of this option declares the name of the benchmark\. It has
        to be unique, or timing data from different benchmarks will be mixed
        together\.

        *Beware\!* This requirement is not checked when benchmarks are
        executed, and the system will silently produce bogus data\. This option,
        and __\-body__, are the two required parts of each benchmark\.

      * __\-ipost__ script

        The argument of this option declares a script which is run immediately
        *after* each iteration of the body\. Its responsibility is to release
        resources created by the body, or __\-ipre__\-bodym which we do not
        wish to live into the next iteration\.

      * __\-ipre__ script

        The argument of this option declares a script which is run immediately
        *before* each iteration of the body\. Its responsibility is to create
        the state of the system expected by the body so that we measure the
        right thing\.

      * __\-iterations__ num

        The argument of this option declares the maximum number of times to run
        the __\-body__ of the benchmark\. During execution this and the global
        maximum number of iterations are compared and the smaller of the two
        values is used\.

        This option should be used only for benchmarks which are expected or
        known to take a long time per run\. I\.e\. reduce the number of times they
        are run to keep the overall time for the execution of the whole
        benchmark within manageable limits\.

      * __\-post__ script

        The argument of this option declares a script which is run *after* all
        iterations of the body have been run\. Its responsibility is to release
        resources created by the body, or __\-pre__\-body\.

      * __\-pre__ script

        The argument of this option declares a script which is run *before*
        any of the iterations of the body are run\. Its responsibility is to
        create whatever resources are needed by the body to run without failing\.

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

[bench\_intro](bench\_intro\.md), [bench\_lang\_intro](bench\_lang\_intro\.md)

# <a name='keywords'></a>KEYWORDS

[bench language](\.\./\.\./\.\./\.\./index\.md\#bench\_language),
[benchmark](\.\./\.\./\.\./\.\./index\.md\#benchmark),
[performance](\.\./\.\./\.\./\.\./index\.md\#performance),
[specification](\.\./\.\./\.\./\.\./index\.md\#specification),
[testing](\.\./\.\./\.\./\.\./index\.md\#testing)

# <a name='category'></a>CATEGORY

Benchmark tools

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
