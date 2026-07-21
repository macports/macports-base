[![Linux CI](https://github.com/flightaware/tclx/actions/workflows/linux-ci.yml/badge.svg)](https://github.com/flightaware/tclx/actions/workflows/linux-ci.yml)
[![Mac CI](https://github.com/flightaware/tclx/actions/workflows/mac-ci.yml/badge.svg)](https://github.com/flightaware/tclx/actions/workflows/mac-ci.yml)

# Extended Tcl (TclX)

## Introduction

Extended Tcl (TclX), is an extension to Tcl, the Tool Command Language invented by Dr. John Ousterhout.  Tcl is a powerful, yet simple embeddable programming language.  Extended Tcl is oriented towards system programming tasks and large application development.  TclX provides additional interfaces to the operating system, and adds many new programming constructs, text manipulation tools, and debugging tools.

TclX is upwardly compatible with Tcl.  You take the Extended Tcl package, add it to Tcl, and from that you get Extended Tcl.  Tcl can be obtained at

    http://www.tcl.tk/ or http://tcl.sourceforge.net/

Extended Tcl runs on most Unix-like systems and Windows.

While this TclX distribution is tested with Tcl 8.6 and Tk 8.4, it should work with Tcl 8.3+.  Please check the Extended Tcl homepage at

    http://tclx.sourceforge.net/

for the latest release and information.

Extended Tcl was designed and implemented by Karl Lehenbauer and Mark Diekhans, with help in the earliest stages from Peter da Silva.  TclX 8.4 work was done by Jeff Hobbs at ActiveState.

TclX 8.4 differs from its predecessors in that it is based more on the idea of TclX as an extension to Tcl, and not an alternate environment.  There is no TkX and no stand-alone shells are built.

As with Tcl, all of Extended Tcl is freely redistributable, including for commercial use and resale (BSD-style license).

## Building and installing TclX

1. Uncompress and unpack the distribution

   ON UNIX/MAC:
	gzip -cd tclx<version>.tar.gz | tar xf -

   ON WINDOWS:
	use something like WinZip to unpack the archive.

   This will create a subdirectory tclx<version> with all the files in it.

2. Configure

ON UNIX/MAC:
	cd tclx<version>
	./configure

TclX is TEA-based and uses information left in tclConfig.sh when you built tcl.  This file will be found in $exec_prefix/lib/.  You might set the --prefix and --exec-prefix options of configure if you don't want the default (/usr/local).  If building on multiple unix platforms, the following is recommended to isolate build conflicts:

	mkdir <builddir>/<platform>
	cd !$
	/path/to/tclx<version>/configure

   ON WINDOWS:

TclX supports building in the cygwin/msys environment on Windows based on TEA (http://www.tcl.tk/doc/tea/).  Inside this environment, you build the same as on Unix.

Otherwise, hack makefile.vc until it works and compile.  It was not updated for TclX 8.4.  It has problems executing wish from a path with a space in it, but the DLL builds just fine.

3. Make and Install

   ON UNIX/MAC or WINDOWS with cygwin/msys:
	make
	make test (OPTIONAL)
	make install

   ON WINDOWS (makefile.vc):
	nmake -f makefile.vc
	nmake -f makefile.vc test (OPTIONAL)
	nmake -f makefile.vc install

   TclX is built to comply to the latest tcl package conventions.

## changes in TclX 8.4

* Restructure of the sources and build system

* Removal of TkX extension

## Features added by Extended Tcl

Here is a summary of the features added by Extended Tcl.  For more details on the commands and functionality provided by Extended Tcl, see the manual page man/TclX.man.

* Keyed lists, a type of list that provides functionality similar to C structures.

* A command tracing facility for debugging and a performance profiler.

* Unix access commands provide access to many Unix system calls, including process management.

* File control and status commands provide added facilities for accessing and manipulating open files.

* File scanning facility that provides awk-like functionality.

* Extended list manipulation commands.

* Extended string and character manipulation commands.

* X/PG based internationalization commands.

* Advanced Tcl code library facility that is oriented towards building large applications.  It is compatible with standard Tcl auto-loading.

* Additional general programming commands.

* Restricted use in a safe interpreter.

* Support for binary data in most commands.

## Manual pages

Man pages in nroff/troff format are provided for all of Tcl and the extensions in the doc directory.  Start with the TclX.n manual.

## Extended Tcl version naming

Extended Tcl version numbering has been changed to track the Tcl/Tk version numbering roughly.

## Linking applications and extension with TclX

There are three basic approaches to linking TclX into applications or with other extensions:

* Dynamically load the C code using either 'package require' or the 'load' command.

* Linking TclX into an application based on the standard Tcl or Tk shells (tclsh or wish) or based on your own startup.

See the TclX_Init.3 manual page for more details.  The pkg_mkIndex does not generate a pkgIndex.tcl file that works with TclX.  See TclX_Init.3 for instructions on how to setup a pkgIndex.tcl file for use with the package require command.  There is no need to dynamically load libtkx, its only there to support wishx and applications that want wishx's signal handling.

TclX will build and install a pkgIndex.tcl that will be automatically found by Tcl if TclX is installed in the same location.

## Support for Extended Tcl

We are committed to providing continuing support for Extended Tcl.  Please send questions, bug reports, and bug fixes to:

	http://tclx.sourceforge.net/

Use news:comp.lang.tcl for discussion about TclX development.

## Where to get it

Extended Tcl can be downloaded from the SF TclX release files area:

	http://tclx.sourceforge.net/

Refer to the above site for bug database and other support forums.

## Thanks

A big thanks to all of the Extended Tcl users from all over the world who have helped us debug problems and given us valuable suggestions.  A special thanks to John Ousterhout, his students at Berkeley, and (more recently) his teams at Sun Microsystems and Scriptics, for Tcl, Tk and all the support they have given us.

Thanks to Michael E. Shorter, Christopher M. Sedore,  Philip Chow, and Kirk Benson for their initial work on porting TclX to MS Windows.

Thanks to Jan Nijtmans of Plus Patch fame for helping to get shared library support working for several system.
