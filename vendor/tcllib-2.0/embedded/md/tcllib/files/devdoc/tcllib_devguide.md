
[//000000001]: # (tcllib\_devguide \- )
[//000000002]: # (Generated from file 'tcllib\_devguide\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (tcllib\_devguide\(n\) 1 tcllib "")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

tcllib\_devguide \- Tcllib \- The Developer's Guide

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commitments](#section2)

      - [Contributor](#subsection1)

      - [Maintainer](#subsection2)

  - [Branching and Workflow](#section3)

      - [Package Dependencies](#subsection3)

      - [Trunk](#subsection4)

      - [Branches](#subsection5)

      - [Working with Branches](#subsection6)

      - [Version numbers](#subsection7)

  - [Structural Overview](#section4)

      - [Main Directories](#subsection8)

      - [More Directories](#subsection9)

      - [Top Files](#subsection10)

      - [File Types](#subsection11)

  - [Testsuite Tooling](#section5)

      - [Invoke the testsuites of a specific module](#subsection12)

      - [Invoke the testsuites of all modules](#subsection13)

      - [Detailed Test Logs](#subsection14)

      - [Shell Selection](#subsection15)

      - [Help](#subsection16)

  - [Documentation Tooling](#section6)

      - [Generate documentation for a specific module](#subsection17)

      - [Generate documentation for all modules](#subsection18)

      - [Available output formats, help](#subsection19)

      - [Validation without output](#subsection20)

  - [Notes On Writing A Testsuite](#section7)

  - [Installation Tooling](#section8)

# <a name='synopsis'></a>SYNOPSIS

[__[Module](\.\./\.\./\.\./index\.md\#module)__ *name* *code\-action* *doc\-action* *example\-action*](#1)  
[__[Application](\.\./\.\./\.\./index\.md\#application)__ *name*](#2)  
[__Exclude__ *name*](#3)  

# <a name='description'></a>DESCRIPTION

Welcome to Tcllib, the Tcl Standard Library\. Note that Tcllib is not a package
itself\. It is a collection of \(semi\-independent\)
*[Tcl](\.\./\.\./\.\./index\.md\#tcl)* packages that provide utility functions
useful to a large collection of Tcl programmers\.

This document is a guide for developers working on Tcllib, i\.e\. maintainers
fixing bugs, extending the collection's functionality, etc\.

Please read

  1. *[Tcllib \- How To Get The Sources](tcllib\_sources\.md)* and

  1. *[Tcllib \- The Installer's Guide](tcllib\_installer\.md)*

first, if that was not done already\.

Here we assume that the sources are already available in a directory of your
choice, and that you not only know how to build and install them, but also have
all the necessary requisites to actually do so\. The guide to the sources in
particular also explains which source code management system is used, where to
find it, how to set it up, etc\.

# <a name='section2'></a>Commitments

## <a name='subsection1'></a>Contributor

As a contributor to Tcllib you are committing yourself to:

  1. keep the guidelines written down in *[Tcl Community \- Kind
     Communication](tcl\_community\_communication\.md)* in your mind\. The main
     point to take away from there is *to be kind to each other*\.

  1. Your contributions getting distributed under a BSD/MIT license\. For the
     details see *[Tcllib \- License](tcllib\_license\.md)*

Contributions are made by entering tickets into our tracker, providing patches,
bundles or branches of code for inclusion, or posting to the Tcllib related
mailing lists\.

## <a name='subsection2'></a>Maintainer

When contributing one or more packages for full inclusion into Tcllib you are
committing yourself to

  1. Keep the guidelines written down in *[Tcl Community \- Kind
     Communication](tcl\_community\_communication\.md)* \(as any contributor\) in
     your mind\. The main point to take away from there is *to be kind to each
     other*\.

  1. Your packages getting distributed under a BSD/MIT license\. For the details
     see *[Tcllib \- License](tcllib\_license\.md)*

  1. Maintenance of the new packages for a period of two years under the
     following rules, and responsibilities:

       1) A maintainer may step down after the mandatory period as they see fit\.

       1) A maintainer may step down before the end of the mandatory period,
          under the condition that a replacement maintainer is immediately
          available and has agreed to serve the remainder of the period, plus
          their own mandatory period \(see below\)\.

       1) When stepping down without a replacement maintainer taking over the
          relevant packages have to be flagged as __unmaintained__\.

       1) When a replacement mantainer is brought in for a package it is \(kept\)
          marked as __maintained__ \(again\)\.

          A replacement maintainer is bound by the same rules as the original
          maintainer, except that the mandatory period of maintenance is
          shortened to one year\.

       1) For any __unmaintained__ package a contributor interested in
          becoming its maintainer can become so by flagging them as
          __maintained__ with their name and contact information, committing
          themselves to the rules of a replacement maintainer \(see previous
          point\)\.

       1) For any already __maintained__ package a contributor interested in
          becoming a co\-maintainer can become so with the agreement of the
          existing maintainer\(s\), committing themselves to the rules of a
          replacement maintainer \(see two points previous\)\.

     The responsibilities as a maintainer include:

       1) Watching Tcllib's ticket tracker for bugs, bug fixes, and feature
          requests related to the new packages\.

       1) Reviewing the aforementioned tickets, rejecting or applying them

       1) Coordination and discussion with ticket submitter during the
          development and/or application of bug fixes\.

  1. Follow the [Branching and Workflow](#section3) of this guide\.

# <a name='section3'></a>Branching and Workflow

## <a name='subsection3'></a>Package Dependencies

Regarding packages and dependencies between them Tcllib occupies a middle
position between two extremes:

  1. On one side a strongly interdependent set of packages, usually by a single
     author, for a single project\. Looking at my \(Andreas Kupries\) own work
     examples of such are [Marpa](https://core\.tcl\.tk/akupries/marpa/index),
     [CRIMP](https://core\.tcl\.tk/akupries/crimp/index),
     [Kinetcl](https://core\.tcl\.tk/akupries/kinetcl/index), etc\.

     For every change the author of the project handles all the modifications
     cascading from any incompatibilities it introduced to the system\.

  1. On the other side, the world of semi\-independent projects by many different
     authors where authors know what packages their own creations depend on, yet
     usually do not know who else depends on them\.

     The best thing an author making an \(incompatible\) change to their project
     can do is to for one announce such changes in some way, and for two use
     versioning to distinguish the code before and after the change\.

     The world is then responsible for adapting, be it by updating their own
     projects to the new version, or by sticking to the old\.

As mentioned already, Tcllib lives in the middle of that\.

While we as maintainers cannot be aware of all users of Tcllib's packages, and
thus have to rely on the mechanisms touched on in point 2 above for that, the
dependencies between the packages contained in Tcllib are a different matter\.

As we are collectively responsible for the usability of Tcllib in toto to the
outside world, it behooves us to be individually mindful even of Tcllib packages
we are not directly maintaining, when they depend on packages under our
maintainership\. This may be as simple as coordinating with the maintainers of
the affected packages\. It may also require us to choose how to adapt affected
packages which do not have maintainers, i\.e\. modify them to use our changed
package properly, or modify them to properly depend on the unchanged version of
our package\.

Note that the above is not only a chore but an opportunity as well\. Additional
insight can be had by forcing ourselves to look at our package and the planned
change\(s\) from an outside perspective, to consider the ramifications of our
actions on others in general, and on dependent packages in particular\.

## <a name='subsection4'></a>Trunk

The management and use of branches is an important part of working with a
*Distributed Version Control System* \(*DVCS*\) like
[fossil](https://www\.fossil\-scm\.org/)\.

For Tcllib the main branch of the collection is *trunk*\. In
*[git](\.\./\.\./\.\./index\.md\#git)* this branch would be called *master*, and
this is exactly the case in the [github
mirror](https://github\.com/tcltk/tcllib/) of Tcllib\.

To properly support debugging *each commit* on this branch *has to pass the
entire testsuite* of the collection\. Using bisection to determine when an issue
appeared is an example of an action made easier by this constraint\.

This is part of our collective responsibility for the usability of Tcllib in
toto to the outside world\. As *[fossil](\.\./\.\./\.\./index\.md\#fossil)* has no
mechanism to enforce this condition this is handled on the honor system for
developers and maintainers\.

To make the task easier Tcllib comes with a tool \("sak\.tcl"\) providing a number
of commands in support\. These commands are explained in the following sections
of this guide\.

While it is possible and allowed to commit directly to trunk remember the above
constraint regarding the testsuite, and the coming notes about other possible
issues with a commit\.

## <a name='subsection5'></a>Branches

Given the constraints placed on the *trunk* branch of the repository it is
\(strongly\) recommended to perform any development going beyond trivial changes
on a non\-trunk branch\.

Outside of the trunk developers are allowed to commit intermediate broken states
of their work\. Only at the end of a development cycle, when the relevant branch
is considered ready for merging, will it be necessary to perform full the set of
validations ensuring that the merge to come will create a good commit on trunk\.

Note that while a review from a second developer is not a required condition for
merging a branch it is recommended to seek out such an independent opinion as a
means of cross\-checking the work\.

It also recommended to give any new branch a name which aids in determining
additional details about it\. Examples of good things to stick into a branch name
would be

  - Developer \(nick\)name

  - Ticket hash/reference

  - One or two keywords applicable to the work

  - \.\.\.

Further, while most development branches are likely quite short\-lived, no
prohibitions exist against making longer\-lived branches\. Creators should however
be mindful that the longer such a branch exists without merges the more
divergent they will tend to be, with an associated increase in the effort which
will have to be spent on either merging from and merging to trunk\.

## <a name='subsection6'></a>Working with Branches

In the hope of engendering good work practices now a few example operations
which will come up with branches, and their associated fossil command
\(sequences\)\.

  - *Awareness*

    When developing we have to keep ourselves aware of the context of our work\.
    On what branch are we ? What files have we changed ? What new files are not
    yet known to the repository ? What has happened remotely since we used our
    checkout ? The answers to these questions become especially important when
    using a long\-lived checkout and coming back to it after some time away\.

    Commands to answer questions like the above are:

      * __fossil pull__

        Get all changes done on the remote since the last pull or sync from it\.
        This has to be done first, before any of the commands below\.

        Even if the commit in our checkout refers to the branch we want right
        now control operations committed to the remote may have changed that
        from underneath us\.

      * __fossil info &#124; grep tags__

      * __fossil branch list &#124; grep '\\\*'__

        Two different ways of determining the branch our checkout is on\.

      * __fossil timeline__

        What have we \(and others\) done recently ?

        *Attention*, this information is very likely outdated, the more the
        longer we did not use this checkout\. Run __fossil pull__ first to
        get latest information from the remote repository of the project\.

      * __fossil timeline current__

        Place the commit our checkout is based on at the top of the timeline\.

      * __fossil changes__

        Lists the files we have changed compared to the commit the checkout is
        based on\.

      * __fossil extra__

        Lists the files we have in the checkout the repository does not know
        about\. This may be leftover chaff from our work, or something we have
        forgotten to __fossil add__ to the repository yet\.

  - *Clean checkouts*

    Be aware of where you are \(see first definition\)\.

    For pretty much all the operation recipes below a clean checkout is at least
    desired, often required\. To check that a checkout is clean invoke

        fossil changes
        fossil extra

    How to clean up when uncommitted changes of all sorts are found is
    context\-specific and outside of the scope of this guide\.

  - *Starting a new branch*

    Be aware of where you are \(see first definition\)\.

    Ensure that you have clean checkout \(see second definition\)\. It is
    *required*\.

    In most situations you want to be on branch *trunk*, and you want to be on
    the latest commit for it\. To get there use

        fossil pull
        fossil update trunk

    If some other branch is desired as the starting point for the coming work
    replace *trunk* in the commands above with the name of that branch\.

    With the base line established we now have two ways of creating the new
    branch, with differing \(dis\)advantages\. The simpler way is to

        fossil branch new NAME_OF_NEW_BRANCH

    and start developing\. The advantage here is that you cannot forget to create
    the branch\. The disadvantages are that we have a branch commit unchanged
    from where we branched from, and that we have to use high\-handed techniques
    like hiding or shunning to get rid of the commit should we decide to abandon
    the work before the first actual commit on the branch\.

    The other way of creating the branch is to start developing, and then on the
    first commit use the option __\-\-branch__ to tell
    __[fossil](\.\./\.\./\.\./index\.md\#fossil)__ that we are starting a branch
    now\. I\.e\. run

        fossil commit --branch NAME_OF_NEW_BRANCH ...

    where *\.\.\.* are any other options used to supply the commit message, files
    to commit, etc\.

    The \(dis\)advantages are now reversed\.

    We have no superflous commit, only what is actually developed\. The work is
    hidden until we commit to make our first commit\.

    We may forget to use __\-\-branch NAME\_OF\_NEW\_BRANCH__ and then have to
    correct that oversight via the fossil web interface \(I am currently unaware
    of ways of doing such from the command line, although some magic
    incantantion of __fossil tag create__ may work\)\.

    It helps to keep awareness, like checking before any commit that we are on
    the desired branch\.

  - *Merging a branch into trunk*

    Be aware of where you are \(see first definition\)\.

    Ensure that you have clean checkout \(see second definition\)\. In the
    full\-blown sequence \(zig\-zag\) it is *required*, due to the merging from
    trunk\. In the shorter sequence it is only desired\. That said, keeping the
    checkout clean before any major operations is a good habit to have, in my
    opinion\.

    The full\-blown sequencing with checks all the way is to

      1. Validate the checkout, i\.e\. last commit on your branch\. Run the full
         test suite and other validations, fix all the issues which have cropped
         up\.

      1. Merge the latest state of the *trunk* \(see next definition\)\.

      1. Validate the checkout again\. The incoming trunk changes may have broken
         something now\. Do any required fixes\.

      1. Now merge to the trunk using

             fossil update trunk
             fossil merge --integrate YOUR_BRANCH

      1. At this point the checkout should be in the same state as at the end of
         point \(3\) above, because we resolved any issues with the trunk already\.
         Thus a simple

             fossil commit ...

         should be sufficient now to commit the merge back and close the branch
         \(due to the __\-\-integrate__ we used on the merge\)\.

         The more paranoid may validate the checkout a third time before
         commiting\.

    I call this a *zig\-zag merge* because of how the arrows look in the
    timeline, from trunk to feature branch for the first merge, and then back
    for the final merge\.

    A less paranoid can do what I call a *simple merge*, which moves step \(2\)
    after step \(4\) and skips step \(3\) entirely\. The resulting shorter sequence
    is

      1. Validate

      1. Merge to trunk

      1. Validate again

      1. Commit to trunk

    The last step after either zig\-zag or plain merge is to

        fossil sync

    This saves our work to the remote side, and further gives us any other work
    done while we were doing our merge\. It especially allows us to check if we
    raced somebody else, resulting in a split trunk\.

    When that happens we should coordinate with the other developer on who fixes
    the split, to ensure that we do not race each other again\.

  - *Merging from trunk*

    Be aware of where you are \(see first definition\)\.

    Ensure that you have clean checkout \(see second definition\)\. It is
    *required*\.

    In most situations you want to import the latest commit of branch *trunk*
    \(or other origin\)\. To get it use

        fossil pull

    With that done we can now import this commit into our current branch with

        fossil merge trunk

    Even if __[fossil](\.\./\.\./\.\./index\.md\#fossil)__ does not report any
    conflicts it is a good idea to check that the operation has not broken the
    new and/or changed functionality we are working on\.

    With the establishment of a good merge we then save the state with

        fossil commit ...

    before continuing development\.

## <a name='subsection7'></a>Version numbers

In Tcllib all changes to a package have to come with an increment of its version
number\. What part is incremented \(patchlevel, minor, major version\) depends on
the kind of change made\. With multiple changes in a commit the highest "wins"\.

When working in a development branch the version change can be deferred until it
is time to merge, and then has to cover all the changes in the branch\.

Below a list of the kinds of changes and their associated version increments:

  - *D \- documentation*

    No increment

  - *T \- testsuite*

    No increment

  - *B \- bugfix*

    Patchlevel

  - *I \- implementation tweak*

    Patchlevel

  - *P \- performance tweak*

    Patchlevel

  - *E \- backward\-compatible extension*

    Minor

  - *API \- incompatible change*

    Major

Note that a commit containing a version increment has to mention the new version
number in its commit message, as well as the kind of change which caused it\.

Note further that the version number of a package currently exists in three
places\. An increment has to update all of them:

  1. The package implementation\.

  1. The package index \("pkgIndex\.tcl"\)

  1. The package documentation\.

The "sak\.tcl" command __validate version__ helps finding discrepancies
between the first two\. All the other __validate__ methods are also of
interest to any developer\. Invoke it with

    sak.tcl help validate

to see their documentation\.

# <a name='section4'></a>Structural Overview

## <a name='subsection8'></a>Main Directories

The main directories in the Tcllib toplevel directory and of interest to a
developer are:

  - "modules"

    Each child directory represents one or more packages\. In the case of the
    latter the packages are usually related in some way\. Examples are "base64",
    "math", and "struct", with loose \(base64\) to strong \(math\) relations between
    the packages in the directory\.

  - "apps"

    This directory contains all the installable applications, with their
    documentation\. Note that this directory is currently *not* split into
    sub\-directories\.

  - "examples"

    Each child directory "foo" contains one or more example application for the
    packages in "modules/foo"\. These examples are generally not polished enough
    to be considered for installation\.

## <a name='subsection9'></a>More Directories

  - "config"

    This directory contains files supporting the Unix build system, i\.e\.
    "configure" and "Makefile\.in"\.

  - "devdoc"

    This directories contains the doctools sources for the global documentation,
    like this document and its sibling guides\.

  - "embedded"

    This directory contains the entire documentation formatted for
    *[HTML](\.\./\.\./\.\./index\.md\#html)* and styled to properly mix into the
    web site generated by fossil for the repository\.

    This is the documentation accessible from the Tcllib home directory,
    represented in the repository as "embedded/index\.md"\.

  - "idoc"

    This directory contains the entire documentation formatted for
    *[nroff](\.\./\.\./\.\./index\.md\#nroff)* and
    *[HTML](\.\./\.\./\.\./index\.md\#html)*, the latter without any styling\. This
    is the documentation which will be installed\.

  - "support"

    This directory contains the sources of internal packages and utilities used
    in the implementation of the "installer\.tcl" and "sak\.tcl" scripts/tools\.

## <a name='subsection10'></a>Top Files

  - "aclocal\.m4"

  - "configure"

  - "configure\.in"

  - "Makefile\.in"

    These four files comprise the Unix build system layered on top of the
    "installer\.tcl" script\.

  - "installer\.tcl"

    The Tcl\-based installation script/tool\.

  - "project\.shed"

    Configuration file for *Sean Wood*'s
    __[PracTcl](\.\./modules/practcl/practcl\.md)__ buildsystem\.

  - "sak\.tcl"

    This is the main tool for developers and release managers, the *Swiss Army
    Knife* of management operations on the collection\.

  - "ChangeLog"

    The log of changes to the global support, when the sources were held in
    *[CVS](\.\./\.\./\.\./index\.md\#cvs)*\. Not relevant any longer with the
    switch to the *[fossil](\.\./\.\./\.\./index\.md\#fossil)* SCM\.

  - "license\.terms"

    The license in plain ASCII\. See also *[Tcllib \-
    License](tcllib\_license\.md)* for the nicely formatted form\. The text is
    identical\.

  - "README\.md"

  - "\.github/CONTRIBUTING\.md"

  - "\.github/ISSUE\_TEMPLATE\.md"

  - "\.github/PULL\_REQUEST\_TEMPLATE\.md"

    These markdown\-formatted documents are used and shown by the github mirror
    of these sources, pointing people back to the official location and issue
    trackers\.

  - "DESCRIPTION\.txt"

  - "STATUS"

  - "tcllib\.spec"

  - "tcllib\.tap"

  - "tcllib\.yml"

    ????

## <a name='subsection11'></a>File Types

The most common file types, by file extension, are:

  - "\.tcl"

    Tcl code for a package, application, or example\.

  - "\.man"

    Doctools\-formatted documentation, usually for a package\.

  - "\.test"

    Test suite for a package, or part of\. Based on __tcltest__\.

  - "\.bench"

    Performance benchmarks for a package, or part of\. Based on "modules/bench"\.

  - "\.pcx"

    Syntax rules for *TclDevKit*'s __tclchecker__\. Using these rules
    allows the checker to validate the use of commands of a Tcllib package
    __foo__ without having to scan the "\.tcl" files implementing it\.

# <a name='section5'></a>Testsuite Tooling

Testsuites in Tcllib are based on Tcl's standard test package __tcltest__,
plus utilities found in the directory "modules/devtools"

Tcllib developers invoke the suites through the __test run__ method of the
"sak\.tcl" tool, with other methods of __[test](\.\./\.\./\.\./index\.md\#test)__
providing management operations, for example setting a list of standard Tcl
shells to use\.

## <a name='subsection12'></a>Invoke the testsuites of a specific module

Invoke either

    ./sak.tcl test run foo

or

    ./sak.tcl test run modules/foo

to invoke the testsuites found in a specific module "foo"\.

## <a name='subsection13'></a>Invoke the testsuites of all modules

Invoke the tool without a module name, i\.e\.

    ./sak.tcl test run

to invoke the testsuites of all modules\.

## <a name='subsection14'></a>Detailed Test Logs

In all the previous examples the test runner will write a combination of
progress display and testsuite log to the standard output, showing for each
module only the tests that passed or failed and how many of each in a summary at
the end\.

To get a detailed log, it is necessary to invoke the test runner with additional
options\.

For one:

    ./sak.tcl test run --log LOG foo

While this shows the same short log on the terminal as before, it also writes a
detailed log to the file "LOG\.log", and excerpts to other files \("LOG\.summary",
"LOG\.failures", etc\.\)\.

For two:

    ./sak.tcl test run -v foo

This writes the detailed log to the standard output, instead of the short log\.

Regardless of form, the detailed log contains a list of all test cases executed,
which failed, and how they failed \(expected versus actual results\)\.

## <a name='subsection15'></a>Shell Selection

By default the test runner will use all the Tcl shells specified via __test
add__ to invoke the specified testsuites, if any\. If no such are specified it
will fall back to the Tcl shell used to run the tool itself\.

Use option __\-\-shell__ to explicitly specify the Tcl shell to use, like

    ./sak.tcl test run --shell /path/to/tclsh ...

## <a name='subsection16'></a>Help

Invoke the tool as

    ./sak.tcl help test

to see the detailed help for all methods of
__[test](\.\./\.\./\.\./index\.md\#test)__, and the associated options\.

# <a name='section6'></a>Documentation Tooling

The standard format used for documentation of packages and other things in
Tcllib is *[doctools](\.\./\.\./\.\./index\.md\#doctools)*\. Its supporting
packages are a part of Tcllib, see the directories "modules/doctools" and
"modules/dtplite"\. The latter is an application package, with the actual
application "apps/dtplite" a light wrapper around it\.

Tcllib developers gain access to these through the __doc__ method of the
"sak\.tcl" tool, another \(internal\) wrapper around the "modules/dtplite"
application package\.

## <a name='subsection17'></a>Generate documentation for a specific module

Invoke either

    ./sak.tcl doc html foo

or

    ./sak.tcl doc html modules/foo

to generate HTML for the documentation found in the module "foo"\. Instead of
__html__ any other supported format can be used here, of course\.

The generated formatted documentation will be placed into a directory "doc" in
the current working directory\.

## <a name='subsection18'></a>Generate documentation for all modules

Invoke the tool without a module name, i\.e\.

    ./sak.tcl doc html

to generate HTML for the documentation found in all modules\. Instead of
__html__ any other supported format can be used here, of course\.

The generated formatted documentation will be placed into a directory "doc" in
the current working directory\.

## <a name='subsection19'></a>Available output formats, help

Invoke the tool as

    ./sak.tcl help doc

to see the entire set of supported output formats which can be generated\.

## <a name='subsection20'></a>Validation without output

Note the special format __validate__\.

Using this value as the name of the format to generate forces the tool to simply
check that the documentation is syntactically correct, without generating actual
output\.

Invoke it as either

    ./sak.tcl doc validate (modules/)foo

or

    ./sak.tcl doc validate

to either check the packages of a specific module or check all of them\.

# <a name='section7'></a>Notes On Writing A Testsuite

While previous sections talked about running the testsuites for a module and the
packages therein, this has no meaning if the module in question has no
testsuites at all\.

This section gives a very basic overview on possible methodologies for writing
tests and testsuites\.

First there are "drudgery" tests\. Written to check absolutely basic assumptions
which should never fail\.

For example for a command FOO taking two arguments, three tests calling it with
zero, one, and three arguments\. The basic checks that the command fails if it
has not enough arguments, or too many\.

After that come the tests checking things based on our knowledge of the command,
about its properties and assumptions\. Some examples based on the graph
operations added during Google's Summer of Code 2009 are:

  - The BellmanFord command in struct::graph::ops takes a *startnode* as
    argument, and this node should be a node of the graph\. This equals one test
    case checking the behavior when the specified node is not a node of the
    graph\.

    This often gives rise to code in the implementation which explicitly checks
    the assumption and throws an understandable error, instead of letting the
    algorithm fail later in some weird non\-deterministic way\.

    It is not always possible to do such checks\. The graph argument for example
    is just a command in itself, and while we expect it to exhibit a certain
    interface, i\.e\. a set of sub\-commands aka methods, we cannot check that it
    has them, except by actually trying to use them\. That is done by the
    algorithm anyway, so an explicit check is just overhead we can get by
    without\.

  - IIRC one of the distinguishing characteristic of either BellmanFord and/or
    Johnson is that they are able to handle negative weights\. Whereas Dijkstra
    requires positive weights\.

    This induces \(at least\) three testcases \.\.\. Graph with all positive weights,
    all negative, and a mix of positive and negative weights\. Thinking further
    does the algorithm handle the weight __0__ as well ? Another test case,
    or several, if we mix zero with positive and negative weights\.

  - The two algorithms we are currently thinking about are about distances
    between nodes, and distance can be 'Inf'inity, i\.e\. nodes may not be
    connected\. This means that good test cases are

      1. Strongly connected graph

      1. Connected graph

      1. Disconnected graph\.

    At the extremes of strongly connected and disconnected we have the fully
    connected graphs and graphs without edges, only nodes, i\.e\. completely
    disconnected\.

  - IIRC both of the algorithms take weighted arcs, and fill in a default if
    arcs are left unweighted in the input graph\.

    This also induces three test cases:

      1. Graph will all arcs with explicit weights\.

      1. Graph without weights at all\.

      1. Graph with mixture of weighted and unweighted graphs\.

What was described above via examples is called *black\-box* testing\. Test
cases are designed and written based on the developer's knowledge of the
properties of the algorithm and its inputs, without referencing a particular
implementation\.

Going further, a complement to *black\-box* testing is *white\-box*\. For this
we know the implementation of the algorithm, we look at it and design our tests
cases so that they force the code through all possible paths in the
implementation\. Wherever a decision is made we have a test case forcing a
specific direction of the decision, for all possible combinations and
directions\. It is easy to get a combinatorial explosion in the number of needed
test\-cases\.

In practice I often hope that the black\-box tests I have made are enough to
cover all the paths, obviating the need for white\-box tests\.

The above should be enough to make it clear that writing tests for an algorithm
takes at least as much time as coding the algorithm, and often more time\. Much
more time\. See for example also
[http://sqlite\.org/testing\.html](http://sqlite\.org/testing\.html), a writeup
on how the Sqlite database engine is tested\. Another article of interest might
be
[https://www\.researchgate\.net/publication/298896236](https://www\.researchgate\.net/publication/298896236)\.
While geared to a particular numerical algorithm it still shows that even a
simple\-looking algorithm can lead to an incredible number of test cases\.

An interesting connection is to documentation\. In one direction, the properties
checked with black\-box testing are exactly the properties which should be
documented in the algorithm's man page\. And conversely, the documentation of the
properties of an algorithm makes a good reference to base the black\-box tests
on\.

In practice test cases and documentation often get written together,
cross\-influencing each other\. And the actual writing of test cases is a mix of
black and white box, possibly influencing the implementation while writing the
tests\. Like writing a test for a condition like *startnode not in input graph*
serving as reminder to put a check for this condition into the code\.

# <a name='section8'></a>Installation Tooling

A last thing to consider when adding a new package to the collection is
installation\.

How to *use* the "installer\.tcl" script is documented in *[Tcllib \- The
Installer's Guide](tcllib\_installer\.md)*\.

Here we document how to extend said installer so that it may install new
package\(s\) and/or application\(s\)\.

In most cases only a single file has to be modified, the
"support/installation/modules\.tcl" holding one command per module and
application to install\.

The relevant commands are:

  - <a name='1'></a>__[Module](\.\./\.\./\.\./index\.md\#module)__ *name* *code\-action* *doc\-action* *example\-action*

    Install the packages of module *name*, found in "modules/*name*"\.

    The *code\-action* is responsible for installing the packages and their
    index\. The system currently provides

      * __\_tcl__

        Copy all "\.tcl" files found in "modules/*name*" into the installation\.

      * __\_tcr__

        As __\_tcl__, copy the "\.tcl" files found in the subdirectories of
        "modules/*name*" as well\.

      * __\_tci__

        As __\_tcl__, and copy the "tclIndex\.tcl" file as well\.

      * __\_msg__

        As __\_tcl__, and copy the subdirectory "msgs" as well\.

      * __\_doc__

        As __\_tcl__, and copy the subdirectory "mpformats" as well\.

      * __\_tex__

        As __\_tcl__, and copy "\.tex" files as well\.

    The *doc\-action* is responsible for installing the package documentation\.
    The system currently provides

      * __\_null__

        No documentation available, do nothing\.

      * __\_man__

        Process the "\.man" files found in "modules/*name*" and install the
        results \(nroff and/or HTML\) in the proper location, as given to the
        installer\.

        This is actually a fallback, normally the installer uses the pre\-made
        formatted documentation found under "idoc"\.

    The *example\-action* is responsible for installing the examples\. The
    system currently provides

      * __\_null__

        No examples available, do nothing\.

      * __\_exa__

        Copy the the directory "examples/*name*" recursively to the install
        location for examples\.

  - <a name='2'></a>__[Application](\.\./\.\./\.\./index\.md\#application)__ *name*

    Install the application with *name*, found in "apps"\.

  - <a name='3'></a>__Exclude__ *name*

    This command signals to the installer which of the listed modules to *not*
    install\. I\.e\. they name the deprecated modules of Tcllib\.

If, and only if the above actions are not suitable for the new module then a
second file has to be modified, "support/installation/actions\.tcl"\.

This file contains the implementations of the available actions, and is the
place where any custom action needed to handle the special circumstances of
module has to be added\.
