
[//000000001]: # (tcllib\_sources \- )
[//000000002]: # (Generated from file 'tcllib\_sources\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (tcllib\_sources\(n\) 1 tcllib "")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

tcllib\_sources \- Tcllib \- How To Get The Sources

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Source Location](#section2)

  - [Get archives for head and releases](#section3)

  - [Retrieval of arbitrary commits](#section4)

  - [Source Code Management](#section5)

# <a name='description'></a>DESCRIPTION

Welcome to Tcllib, the Tcl Standard Library\. Note that Tcllib is not a package
itself\. It is a collection of \(semi\-independent\)
*[Tcl](\.\./\.\./\.\./index\.md\#tcl)* packages that provide utility functions
useful to a large collection of Tcl programmers\.

The audience of this document is anyone wishing to either have just a look at
Tcllib's source code, or build the packages, or to extend and modify them\.

For builders and developers we additionally provide

  1. *[Tcllib \- The Installer's Guide](tcllib\_installer\.md)*\.

  1. *[Tcllib \- The Developer's Guide](tcllib\_devguide\.md)*\.

respectively\.

# <a name='section2'></a>Source Location

The official repository for Tcllib is found at
[http://core\.tcl\-lang\.org/tcllib](http://core\.tcl\-lang\.org/tcllib)\. This
repository is managed by the [Fossil SCM](http://www\.fossil\-scm\.org)\.

# <a name='section3'></a>Get archives for head and releases

This is done easiest by going to the [official
repository](http://core\.tcl\-lang\.org/tcllib) and following the links in the
*Releases* section at the top, immediately underneath the entry field for
searching the package documentation\.

# <a name='section4'></a>Retrieval of arbitrary commits

For anything beyond head state and releases the process is a bit more involved\.

If the commit id \(commit hash\) __\(\(ID\)\)__ of the revision of interest is
already known then links to the desired archives can be constructed using the
forms below:

    https://core.tcl-lang.org/tcllib/tarball/((ID))/Tcl+Library+Source+Code.tar.gz
    https://core.tcl-lang.org/tcllib/zip/((ID))/Tcl+Library+Source+Code.zip

Note that branch names can be used for the __\(\(ID\)\)__ also, this returns
archives containing the head revision of the named branch\.

The part of of the url after the __\(\(ID\)\)__ is the name of the file to
return and can be modified to suit\.

Without a known commit id the process is longer again:

  1. Go to the [official repository](http://core\.tcl\-lang\.org/tcllib)\.

  1. Find the login link/button in the top right corner of the page\.

  1. Log in as "anonymous", using the semi\-random password in the captcha\.

  1. Go to the "Timeline" following the link/button in the middle of the nav
     bar\.

  1. Choose the revision you wish to have\.

  1. Follow its link to its detailed information page\.

  1. On that page, choose either the "ZIP" or "Tarball" link to get a copy of
     this revision in the format of your choice\.

# <a name='section5'></a>Source Code Management

The sources are managed with the [Fossil SCM](http://www\.fossil\-scm\.org)\.
Binaries for popular platforms can be found directly at its [download
page](http://www\.fossil\-scm\.org/download\.html)\.

With that tool available the full history can be retrieved via:

    fossil clone  http://core.tcl-lang.org/tcllib  tcllib.fossil

followed by

    mkdir tcllib
    cd tcllib
    fossil open ../tcllib.fossil

to get a checkout of the head of the trunk\.
