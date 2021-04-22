
[//000000001]: # (tcllib\_install\_guide \- )
[//000000002]: # (Generated from file 'tcllib\_installer\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (tcllib\_install\_guide\(n\) 1 tcllib "")

<hr> [ <a href="../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../toc.md">Table Of Contents</a> &#124; <a
href="../../../index.md">Keyword Index</a> &#124; <a
href="../../../toc0.md">Categories</a> &#124; <a
href="../../../toc1.md">Modules</a> &#124; <a
href="../../../toc2.md">Applications</a> ] <hr>

# NAME

tcllib\_install\_guide \- Tcllib \- The Installer's Guide

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Requisites](#section2)

      - [Tcl](#subsection1)

      - [Critcl](#subsection2)

  - [Build & Installation Instructions](#section3)

      - [Installing on Unix](#subsection3)

      - [Installing on Windows](#subsection4)

      - [Critcl & Accelerators](#subsection5)

      - [Tooling](#subsection6)

# <a name='description'></a>DESCRIPTION

Welcome to Tcllib, the Tcl Standard Library\. Note that Tcllib is not a package
itself\. It is a collection of \(semi\-independent\)
*[Tcl](\.\./\.\./\.\./index\.md\#tcl)* packages that provide utility functions
useful to a large collection of Tcl programmers\.

The audience of this document is anyone wishing to build and install the
packages found in Tcllib, for either themselves, or others\.

For developers intending to work on the packages themselves we additionally
provide

  1. *[Tcllib \- The Developer's Guide](tcllib\_devguide\.md)*\.

Please read *[Tcllib \- How To Get The Sources](tcllib\_sources\.md)* first,
if that was not done already\. Here we assume that the sources are already
available in a directory of your choice\.

# <a name='section2'></a>Requisites

Before Tcllib can be build and used a number of requisites must be installed\.
These are:

  1. The scripting language Tcl\. For details see [Tcl](#subsection1)\.

  1. Optionally, the __critcl__ package \(C embedding\) for
     __[Tcl](\.\./\.\./\.\./index\.md\#tcl)__\. For details see __CriTcl__\.

This list assumes that the machine where Tcllib is to be installed is
essentially clean\. Of course, if parts of the dependencies listed below are
already installed the associated steps can be skipped\. It is still recommended
to read their sections though, to validate that the dependencies they talk about
are indeed installed\.

## <a name='subsection1'></a>Tcl

As we are installing a number of Tcl packages and applications it should be
pretty much obvious that a working installation of Tcl itself is needed, and I
will not belabor the point\.

Out of the many possibilities use whatever you are comfortable with, as long as
it provides at the very least Tcl 8\.2, or higher\. This may be a Tcl installation
provided by your operating system distribution, from a distribution\-independent
vendor, or built by yourself\.

*Note* that the packages in Tcllib have begun to require 8\.4, 8\.5, and even
8\.6\. Older versions of Tcl will not be able to use such packages\. Trying to use
them will result in *package not found* errors, as their package index files
will not register them in versions of the core unable to use them\.

Myself, I used \(and still use\) [ActiveState's](http://www\.activestate\.com)
ActiveTcl 8\.5 distribution during development, as I am most familiar with it\.

*\(Disclosure: I, Andreas Kupries, worked for ActiveState until 2016,
maintaining ActiveTcl and TclDevKit for them\)\.*\. I am currently working for
SUSE Software Canada ULC, although not in Tcl\-related areas\.

This distribution can be found at
[http://www\.activestate\.com/activetcl](http://www\.activestate\.com/activetcl)\.
Retrieve the archive of ActiveTcl 8\.5 \(or higher\) for your platform and install
it as directed by ActiveState\.

For those wishing to build and install Tcl on their own, the relevant sources
can be found at

  - Tcl

    [http://core\.tcl\-lang\.org/tcl/](http://core\.tcl\-lang\.org/tcl/)

together with the necessary instructions on how to build it\.

If there are problems with building, installing, or using Tcl, please file a
ticket against *[Tcl](\.\./\.\./\.\./index\.md\#tcl)*, or the vendor of your
distribution, and *not* *[Tcllib](\.\./\.\./\.\./index\.md\#tcllib)*\.

## <a name='subsection2'></a>Critcl

The __critcl__ tool is an *optional* dependency\.

It is only required when trying to build the C\-based *accelerators* for a
number of packages, as explained in [Critcl & Accelerators](#subsection5)

Tcllib's build system looks for it in the , using the name __critcl__\. This
is for Unix\. On Windows on the other hand the search is more complex\. First we
look for a proper application __critcl\.exe__\. When that is not found we look
for a combination of interpreter \(__tclkitsh\.exe__, __tclsh\.exe__\) and
starkit \(__critcl\.kit__, __critcl__\) instead\. *Note* that the choice
of starkit can be overriden via the environment variable \.

Tcllib requires Critcl version 2 or higher\.

The github repository providing releases of version 2 and higher, and the
associated sources, can be found at
[https://andreas\-kupries\.github\.io/critcl](https://andreas\-kupries\.github\.io/critcl)\.

Any branch of the repository can be used \(if not using the prebuild starkit or
starpack\), although the use of the stable branch *master* is recommended\.

At the above url is also an explanation on how to build and install Critcl,
including a list of its dependencies\.

Its instructions will not be repeated here\. If there are problems with these
directions please file a ticket against the *Critcl* project, and not Tcllib\.

# <a name='section3'></a>Build & Installation Instructions

As Tcllib is mainly a bundle of packages written in pure Tcl building it is the
same as installing it\. The exceptions to this have their own subsection,
[Critcl & Accelerators](#subsection5), later on\.

Before that however comes the standard case, differentiated by the platforms
with material differences in the instruction, i\.e\. *Unix*\-like, versus
*Windows*\.

Regarding the latter it should also be noted that it is possible set up an
*Unix*\-like environment using projects like *MSYS*, *Cygwin*, and others\.
In that case the user has the choice of which instructions to follow\.

Regardless of environment or platform, a suitable
*[Tcl](\.\./\.\./\.\./index\.md\#tcl)* has to be installed, and its __tclsh__
should be placed on the \(*Unix*\) or associated with "\.tcl" files
\(*Windows*\)\.

## <a name='subsection3'></a>Installing on Unix

For *Unix*\-like environments Tcllib comes with the standard set of files to
make

    ./configure
    make install

a suitable way of installing it\. This is a standard non\-interactive install
automatically figuring out where to place everything, i\.e\. packages,
applications, and the manpages\.

To get a graphical installer invoke

    ./installer.tcl

instead\.

## <a name='subsection4'></a>Installing on Windows

In a Windows environment we have the __installer\.tcl__ script to perform
installation\.

If the desired __tclsh__ is associated "\.tcl" files then double\-clicking /
opening the __installer\.tcl__ is enough to invoke it in graphical mode\. This
assumes that *[Tk](\.\./\.\./\.\./index\.md\#tk)* is installed and available as
well\.

Without *[Tk](\.\./\.\./\.\./index\.md\#tk)* the only way to invoke the installer
are to open a DOS window, i\.e\. __cmd\.exe__, and then to invoke

    ./installer.tcl

inside it\.

## <a name='subsection5'></a>Critcl & Accelerators

While the majority of Tcllib consists of packages written in pure Tcl a number
of packages also have *accelerators* associated with them\. These are
__critcl__\-based C packages whose use will boost the performance of the
packages using them\. These accelerators are optional, and they are not built by
default\. If they are built according to the instructions below then they will
also be installed as well\.

To build the accelerators the normally optional dependency on __critcl__
becomes required\.

To build and install Tcllib with the accelerators in a Unix\-like environment
invoke:

    ./configure
    make critcl  # Builds the shared library and package holding
                 # the accelerators, tcllibc
    make install # Installs all packages, including the new tcllibc.

The underlying tool is "sak\.tcl" in the toplevel directory of Tcllib and the
command __make critcl__ is just a wrapper around

    ./sak.tcl critcl

Therefore in a Windows environment instead invoke

    ./sak.tcl critcl
    ./installer.tcl

from within a DOS window, i\.e\. __cmd\.exe__\.

## <a name='subsection6'></a>Tooling

The core of Tcllib's build system is the script "installer\.tcl" found in the
toplevel directory of a checkout or release\.

The

    configure ; make install

setup available to developers on Unix\-like systems is just a wrapper around it\.
To go beyond the standard embodied in the wrapper it is necessary to directly
invoke this script\.

On Windows system using it directly is the only way to invoke it\.

For basic help invoke it as

    ./installer.tcl -help

This will print a short list of all the available options to the standard output
channel\.

The commands associated with the various *install* targets in the
*Makefile\.in* for Unix can be used as additional examples on how to use this
tool as well\.

The installer can operate in GUI and CLI modes\. By default it chooses the mode
automatically, based on if the Tcl package
__[Tk](\.\./\.\./\.\./index\.md\#tk)__ can be used or not\. The option
__\-no\-gui__ can be used to force CLI mode\.

Note that it is possible to specify options on the command line even if the
installer ultimatively selects GUI mode\. In that case the hardwired defaults and
the options determine the data presented to the user for editing\.

The installer will select a number of defaults for the locations of packages,
examples, and documentation, and also the format of the documentation\. The user
can overide these defaults in the GUI, or by specifying additional options\. The
defaults depend on the platform detected \(Unix/Windows\) and on the __tclsh__
executable used to run the installer\.

*Options*

  - __\-help__

    Show the list of options explained here on the standard output channel and
    exit\.

  - __\+excluded__

    Include deprecated packages in the installation\.

  - __\-no\-gui__

    Force command line operation of the installer

  - __\-no\-wait__

    In CLI mode the installer will by default ask the user to confirm that the
    chosen configuration \(destination paths, things to install\) is correct
    before performing any action\. Using this option causes the installer to skip
    this query and immediately jump to installation\.

  - __\-app\-path__ *path*

  - __\-example\-path__ *path*

  - __\-html\-path__ *path*

  - __\-nroff\-path__ *path*

  - __\-pkg\-path__ *path*

    Declare the destination paths for the applications, examples, html
    documentation, nroff manpages, and packages\. The defaults are derived from
    the location of the __tclsh__ used to run the installer\.

  - __\-dry\-run__

  - __\-simulate__

    Run the installer without modifying the destination directories\.

  - __\-apps__

  - __\-no\-apps__

  - __\-examples__

  - __\-no\-examples__

  - __\-pkgs__

  - __\-no\-pkgs__

  - __\-html__

  - __\-no\-html__

  - __\-nroff__

  - __\-no\-nroff__

    \(De\)activate the installation of applications, examples, packages, html
    documentation, and nroff manpages\.

    Applications, examples, and packages are installed by default\.

    On Windows the html documentation is installed by default\.

    On Unix the nroff manpages are installed by default\.
