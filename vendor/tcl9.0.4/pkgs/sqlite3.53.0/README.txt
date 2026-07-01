This is the SQLite extension for Tcl using the Tcl Extension
Architecture (TEA). 

----------------------- A BETTER WAY ---------------------------

A better way to build the TCL extension for SQLite is to use the
canonical source code tarball.  For Unix:

    ./configure --with-tclsh=$(TCLSH)
    make tclextension-install

For Windows:

    nmake /f Makefile.msc tclextension-install TCLSH_CMD=$(TCLSH)

In both of the above, replace $(TCLSH) with the full pathname of
of the tclsh that you want the SQLite extension to work with.  See
step-by-step instructions at the links below for more information:

    https://sqlite.org/src/doc/trunk/doc/compile-for-unix.md
    https://sqlite.org/src/doc/trunk/doc/compile-for-windows.md

The whole point of the amalgamation-autoconf tarball (in which this
README.txt file is embedded) is to provide a means of compiling
SQLite that does not require first installing TCL and/or "tclsh".
The canonical Makefile in the SQLite source tree provides more
capabilities (such as the the ability to run test cases to ensure
that the build worked) and is better maintained.  The only
downside of the canonical Makfile is that it requires a TCL
installation.  But if you are wanting to build the TCL extension for
SQLite, then presumably you already have a TCL installation.  So why
not just use the more-capable and better-maintained canoncal Makefile?

This TEA builder is derived from code found at

    http://core.tcl-lang.org/tclconfig
    http://core.tcl-lang.org/sampleextension

The SQLite developers do not understand how it works.  It seems to
work for us.  It might also work for you.  But we cannot promise that.

If you want to use this TEA builder and it works for you, that's fine.
But if you have trouble, the first thing you should do is go back
to using the canonical Makefile in the SQLite source tree.

------------------------------------------------------------------


UNIX BUILD
==========

Building under most UNIX systems is easy, just run the configure script
and then run make. For more information about the build process, see
the tcl/unix/README file in the Tcl src dist. The following minimal
example will install the extension in the /opt/tcl directory.

	$ cd sqlite-*-tea
	$ ./configure --prefix=/opt/tcl
	$ make
	$ make install

WINDOWS BUILD
=============

The recommended method to build extensions under windows is to use the
Msys + Mingw build process. This provides a Unix-style build while
generating native Windows binaries. Using the Msys + Mingw build tools
means that you can use the same configure script as per the Unix build
to create a Makefile. See the tcl/win/README file for the URL of
the Msys + Mingw download.

If you have VC++ then you may wish to use the files in the win
subdirectory and build the extension using just VC++. These files have
been designed to be as generic as possible but will require some
additional maintenance by the project developer to synchronise with
the TEA configure.in and Makefile.in files. Instructions for using the
VC++ makefile are written in the first part of the Makefile.vc
file.

TCL SPECIFIC CHANGES
====================

The version of SQLite provided by Tcl contains a number of additional
enhancements and bug-fixes, in the process of being provided back to
the SQLite developers.

  * Enable SQLite Tcl binding to handle files from a Tcl VFS.
  * Maximum path length enhanced from 260 to 4096 bytes for win32/cygwin
  * Maximum path length enhanced from 512 to 4096 bytes for other platforms
  * Maximum default page length enhanced from 8192 to 32768
  * Maximum Number Of Attached Databases enhanced from 10 to 62
  * VFS filename truncation issues
    <https://www.sqlite.org/src/info/c060923a54>
  * Wrong filename handling in sqlite3_load_extension() for Cygwin
    <http://sqlite.1065341.n5.nabble.com/Wrong-filename-handling-in-sqlite3-load-extension-for-Cygwin-td74049.html>
  * pragma database_list returns win32 paths on Cygwin
    <http://sqlite.1065341.n5.nabble.com/pragma-database-list-returns-win32-paths-on-Cygwin-td74163.html>
  * update to Unicode 16 for FTS3/4/5 tokenizer
  * Extend memory interfaces from using "int" to "size_t".
