
[//000000001]: # (tcllib\_releasemgr \- )
[//000000002]: # (Generated from file 'tcllib\_releasemgr\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (tcllib\_releasemgr\(n\) 1 tcllib "")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

tcllib\_releasemgr \- Tcllib \- The Release Manager's Guide

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Tools](#section2)

  - [Tasks](#section3)

      - [Start a release candidate](#subsection1)

      - [Ready the candidate](#subsection2)

      - [Make it official](#subsection3)

      - [Distribute the release](#subsection4)

# <a name='description'></a>DESCRIPTION

Welcome to Tcllib, the Tcl Standard Library\. Note that Tcllib is not a package
itself\. It is a collection of \(semi\-independent\)
*[Tcl](\.\./\.\./\.\./index\.md\#tcl)* packages that provide utility functions
useful to a large collection of Tcl programmers\.

The audience of this document is the release manager for Tcllib, their deputies,
and anybody else interested in the task of creating an official release of
Tcllib for distribution\.

Please read *[Tcllib \- How To Get The Sources](tcllib\_sources\.md)* first,
if that was not done already\. Here we assume that the sources are already
available in a directory of your choice\.

# <a name='section2'></a>Tools

The "sak\.tcl" script in the toplevel directory of a Tcllib checkout is the one
tool used by the release manager to perform its [Tasks](#section3)\.

The main commands to be used are

    sak.tcl validate
    sak.tcl test run
    sak.tcl review
    sak.tcl readme
    sak.tcl localdoc
    sak.tcl release

More detail will be provided in the explanations of the various
[Tasks](#section3)\.

# <a name='section3'></a>Tasks

## <a name='subsection1'></a>Start a release candidate

todo: open a candidate for release

## <a name='subsection2'></a>Ready the candidate

todo: test, validate and check that the candidate is worthy of release fix
testsuites, possibly fix packages, documentation regenerate docs coordinate with
package maintainers wrt fixes big thing: going over the packages, classify
changes since last release to generate a nice readme\.

## <a name='subsection3'></a>Make it official

todo: finalize release, make candidate official

## <a name='subsection4'></a>Distribute the release

With the release made it has to be published and the world notified of its
existence\.

  1. Create a proper fossil event for the release, via
     [http://core\.tcl\-lang\.org/tcllib/eventedit](http://core\.tcl\-lang\.org/tcllib/eventedit)\.

     An [existing
     event](http://core\.tcl\-lang\.org/tcllib/event/dac0ddcd2e990234143196b4dc438fe01e7b9817)
     should be used as template\.

  1. Update a number of web locations:

       1) [Home
          page](http://core\.tcl\-lang\.org/tcllib/doc/trunk/embedded/index\.md)

       1) [Downloads](http://core\.tcl\-lang\.org/tcllib/wiki?name=Downloads)

       1) [Past
          Releases](http://core\.tcl\-lang\.org/tcllib/wiki?name=Past\+Releases)

       1) [http://www\.tcl\-lang\.org/home/release\.txt](http://www\.tcl\-lang\.org/home/release\.txt)

       1) [http://www\.tcl\-lang\.org/software/tcllib/\*\.tml](http://www\.tcl\-lang\.org/software/tcllib/\*\.tml)

       1) [http://wiki\.tcl\-lang\.org/page/Tcllib](http://wiki\.tcl\-lang\.org/page/Tcllib)

     The first location maps to the file "embedded/index\.md" in the repository
     itself, as such it can edited as part of the release process\. This is where
     reference to the new fossil event is added, as the new current release\.

     The next two locations are in the fossil tcllib wiki and require admin or
     wiki write permissions for
     [http://core\.tcl\-lang\.org/tcllib](http://core\.tcl\-lang\.org/tcllib)\.

     The last two locations require ssh access to
     [http://www\.tcl\-lang\.org](http://www\.tcl\-lang\.org) and permission to
     edit files in the web area\.

  1. \*\*\*TODO\*\*\* mailing lists and other places to send notes to\.
