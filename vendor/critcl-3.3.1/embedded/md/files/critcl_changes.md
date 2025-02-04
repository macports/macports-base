
[//000000001]: # (critcl\_changes \- C Runtime In Tcl \(CriTcl\))
[//000000002]: # (Generated from file 'critcl\_changes\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; Jean\-Claude Wippler)
[//000000004]: # (Copyright &copy; Steve Landers)
[//000000005]: # (Copyright &copy; 2011\-2024 Andreas Kupries)
[//000000006]: # (critcl\_changes\(n\) 3\.3\.1 doc "C Runtime In Tcl \(CriTcl\)")

<hr> [ <a href="../toc.md">Table Of Contents</a> &#124; <a
href="../index.md">Keyword Index</a> ] <hr>

# NAME

critcl\_changes \- CriTcl Releases & Changes

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Description](#section1)

  - [Changes for version 3\.3\.1](#section2)

  - [Changes for version 3\.3](#section3)

  - [Changes for version 3\.2](#section4)

  - [Changes for version 3\.1\.18\.1](#section5)

  - [Changes for version 3\.1\.18](#section6)

  - [Changes for version 3\.1\.17](#section7)

  - [Changes for version 3\.1\.16](#section8)

  - [Changes for version 3\.1\.15](#section9)

  - [Changes for version 3\.1\.14](#section10)

  - [Changes for version 3\.1\.13](#section11)

  - [Changes for version 3\.1\.12](#section12)

  - [Changes for version 3\.1\.11](#section13)

  - [Changes for version 3\.1\.10](#section14)

  - [Changes for version 3\.1\.9](#section15)

  - [Changes for version 3\.1\.8](#section16)

  - [Changes for version 3\.1\.7](#section17)

  - [Changes for version 3\.1\.6](#section18)

  - [Changes for version 3\.1\.5](#section19)

  - [Changes for version 3\.1\.4](#section20)

  - [Changes for version 3\.1\.3](#section21)

  - [Changes for version 3\.1\.2](#section22)

  - [Changes for version 3\.1\.1](#section23)

  - [Changes for version 3\.1](#section24)

  - [Changes for version 3\.0\.7](#section25)

  - [Changes for version 3\.0\.6](#section26)

  - [Changes for version 3\.0\.5](#section27)

  - [Changes for version 3\.0\.4](#section28)

  - [Changes for version 3\.0\.3](#section29)

  - [Changes for version 3\.0\.2](#section30)

  - [Changes for version 3\.0\.1](#section31)

  - [Changes for version 3](#section32)

  - [Changes for version 2\.1](#section33)

  - [Authors](#section34)

  - [Bugs, Ideas, Feedback](#section35)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='description'></a>DESCRIPTION

Be welcome to the *C Runtime In Tcl* \(short: *[CriTcl](critcl\.md)*\), a
system for embedding and using C code from within
[Tcl](http://core\.tcl\-lang\.org/tcl) scripts\.

Adding C code to
[Tcl](http://core\.tcl\-lang\.org/tcl)/[Tk](http://core\.tcl\-lang\.org/tk)
has never been easier\.

Improve performance by rewriting the performance bottlenecks in C\.

Import the functionality of shared libraries into Tcl scripts\. See the changes
done in each release of *[CriTcl](critcl\.md)*, from the latest at the top
to the beginning of the project\.

The latest changes are found at the top\.

# <a name='section2'></a>Changes for version 3\.3\.1

  1. Oops\. Added refresh of tcl 8\.6, 8\.7 headers which was left behind behind\.

  1. Oops\. Fixed mismatch of package directories computed by install vs
     uninstall\.

# <a name='section3'></a>Changes for version 3\.3

  1. As announced with 3\.2:

       1) Removed support for Tcl 8\.4 and 8\.5\.

       1) Removed support for the argument types __int\*__, __float\*__,
          __double\*__, __bytearray__, __rawchar__, and
          __rawchar\*__\.

  1. Modified packages to accept operation under Tcl 9\. Bumped package versions
     appropriately\. Bumped copyrights\.

     The *[How To Adapt Critcl Packages for Tcl 9](critcl\_tcl9\.md)*
     contains the details relevant to writers of
     *[CriTcl](critcl\.md)*\-based packages\.

  1. Set different minimum Tcl requirements for the 8\.x and 9\.x series\.

     If no minimum is declared the minimum depends on the Tcl version used to
     run the critcl package or application\.

     When running under Tcl 9 the default minimum is version __9__\. For
     anything else the new default minimum is __8\.6__\.

     *Reminder*: Support for Tcl 8\.4 and 8\.5 was removed\.

  1. Made "~"\-handling portable across the 8\.x and 9 boundary \(via __HOME__
     environment variable\)\.

  1. Bumped embedded __tclconfig__ to version 2\.67\. Patch supplied by Paul
     Obermeier\.

  1. *Bug Fix*
     [\#127](https://github\.com/andreas\-kupries/critcl/issues/127)

  1. *Bug Fix*
     [\#128](https://github\.com/andreas\-kupries/critcl/issues/128)

  1. *Bug Fix*
     [\#129](https://github\.com/andreas\-kupries/critcl/issues/129) Fixed
     various typos in the documentation\.

  1. Reworked internals of __[critcl::cutil](critcl\_cutil\.md)__'s tracer
     to support operation in a multi\-threaded environment\. This new mode is also
     default\. The old single\-threaded mode can be \(re\)activated by defining
     __CRITCL\_TRACE\_NOTHREADS__\.

     Package bumped to version 0\.4\.

  1. Reworked the installer to add __tclX__ markers to the installation
     directories of the C\-based support packages
     \(__[critcl::callback](critcl\_callback\.md)__, __critcl::md5c__\),
     where __X__ is the major version number of the __tclsh__ which ran
     critcl\.

  1. In other words, one of __tcl8__ or __tcl9__\.

  1. Broke lingering dependencies on the Tcllib packages __cmdline__ and
     __fileutil__\.

     There are no circularities between Critcl and Tcllib any longer,
     simplifying installation\.

# <a name='section4'></a>Changes for version 3\.2

  1. *BREAKING* *[CriTcl](critcl\.md)* now requires Tcl 8\.6 to be run\.

     It also generates Tcl 8\.6 extensions by default\.

     It is still possible to generates extensions for Tcl 8\.4 and 8\.5, properly
     setting it via __critcl::tcl__\.

     *ATTENTION* It is planned to completely remove 8\.4 and 8\.5 support with
     *[CriTcl](critcl\.md)* 3\.3\. No date has been set for that release yet\.

     All utility packages have their versions and requirements bumped
     accordingly as well\.

  1. *BREAKING* *Bug Fix* Issue
     [\#115](https://github\.com/andreas\-kupries/critcl/issues/115)\.

     Distributions using __build\.tcl__ for installation of critcl in their
     packaging scripts have to be updated to the changed command signature of
     __build\.tcl__ install, etc\. See the details below\.

     Redone the argument handling for __install__, __uninstall__, and
     __targets__\. The destination argument is gone\. All commands now take
     options similar to what is known from GNU __configure__, i\.e\.

       - __\-\-prefix__ path

       - __\-\-exec\-prefix__ path

       - __\-\-bin\-dir__ path

       - __\-\-lib\-dir__ path

       - __\-\-include\-dir__ path

     They now also respect the environment variable __DESTDIR__, and the
     associated option __\-\-dest\-dir__\.

     The __\-\-prefix__ defaults to the topdir from the bin directory holding
     the __tclsh__ running __build\.tcl__\. As Tcl command:

         file dirname [file dirname [info nameofexecutable]]

     Added a command __dirs__ doing the same argument handling, for
     debugging\.

  1. Removed the irrelevant packages __autoscroll__, __cmdline__,
     __dict84__, __lassign84__, __lmap84__, __snit__,
     __snitbutton__, and __wikit__\.

  1. *Documentation Redo* Issue
     [\#116](https://github\.com/andreas\-kupries/critcl/issues/116)\. Reworked
     the documentation to use the system of 4 quadrants\. Reworked the
     introduction \(How To Use Critcl\) to be strongly based on a series of
     examples\.

  1. *Bug Fix* Issue
     [\#125](https://github\.com/andreas\-kupries/critcl/issues/125)\. Added
     missing method __create__ in object creation example of installer
     documentation\.

  1. *Feature*\. Extended __cproc__ argument type processing\. Now able to
     auto\-create restricted scalar types\. I\.e\. types derived from *int*, etc\.
     and limited in the range of allowed values\.

     Further able to auto\-create restricted list types, i\.e\. types derived from
     *list* and either limited in length, or in the type of the elements, or
     both\.

  1. *Bug Fix / Enhancement* Issue
     [\#118](https://github\.com/andreas\-kupries/critcl/issues/118)\. Modified
     __critcl::cproc__ to accept C syntax for arguments, i\.e\. Trailing comma
     on argument names, leading comma on type names, and lone comma characters\.

  1. *Performance Fix* for *[compile & run](\.\./index\.md\#compile\_run)*
     mode\. Issue
     [\#112](https://github\.com/andreas\-kupries/critcl/issues/112)\.

     Moved the command activating more precise code location tracking out of
     package __[critcl](critcl\.md)__ into package __critcl::app__\.

     Because generating packages ahead of time can bear the performance penalty
     invoked by this *global* setting\.

     Arbitrary libraries and applications using critcl dynamically \(*[compile
     & run](\.\./index\.md\#compile\_run)*\) on the other hand likely cannot, and
     should not\.

  1. *Fix* Issue
     [\#109](https://github\.com/andreas\-kupries/critcl/issues/109)\. Ignore
     __clang__ suffices when computing the target identifier from a
     configuration identifier\.

  1. *Feature*\. Bumped package __[critcl::cutil](critcl\_cutil\.md)__ to
     version 0\.2\.1\. Simplified the implementation of macro __ASSERT__ by
     taking the underlying __Tcl\_Panic__'s printf ability into account and
     added a new macro __ASSERT\_VA__ exporting the same ability to the user\.

# <a name='section5'></a>Changes for version 3\.1\.18\.1

  1. *Attention*: While the overall version \(of the bundle\) moves to 3\.1\.18\.1
     the versions of packages __[critcl](critcl\.md)__ and
     __critcl::app__ are *unchanged*\.

  1. *Bugfix* Generally removed a number of 8\.5\-isms which slipped into
     3\.1\.18, breaking ability to use it with Tcl 8\.4\.

  1. *Bugfix* Corrected broken *build\.tcl uninstall*\.

  1. *Bugfix* Package __[critcl::class](critcl\_class\.md)__ bumped to
     version 1\.1\.1\. Fixed partial template substitution breaking compilation of
     the generated code\.

# <a name='section6'></a>Changes for version 3\.1\.18

  1. Feature \(Developer support\)\. Merged pull request \#96 from
     sebres/main\-direct\-invoke\. Enables direct invokation of the "main\.tcl" file
     for starkits from within a dev checkout, i\.e\. outside of a starkit, or
     starpack\.

  1. Feature\. Added channel types to the set of builtin argument and result
     types\. The argument types are for simple channel access, access requiring
     unshared channels, and taking the channel fully into the C level, away from
     Tcl\. The result type comes in variants for newly created channels, known
     channels, and to return taken channels back to Tcl\. The first will register
     the returned value in the interpreter, the second assumes that it already
     is\.

  1. Bugfix\. Issue \#96\. Reworked the documentation around the argument type
     __Tcl\_Interp\*__ to make its special status more visible, explain uses,
     and call it out from result types where its use will be necessary or at
     least useful\.

  1. Feature\. Package __[critcl::class](critcl\_class\.md)__ bumped to
     version 1\.1\. Extended with the ability to create a C API for classes, and
     the ability to disable the generation of the Tcl API\.

  1. Bugfix\. Merged pull request \#99 from pooryorick/master\. Fixes to the target
     directory calculations done by the install code\.

  1. Merged pull request \#94 from andreas\-kupries/documentation\. A larger
     documentation cleanup\. The main work was done by pooryorick, followed by
     tweaks done by myself\.

  1. Extended the test suite with lots of cases based on the examples for the
     various generator packages\. IOW the new test cases replicate/encapsulate
     the examples and demonstrate that the packages used by the examples
     generate working code\.

  1. Bugfix\. Issue \#95\. Changed the field __critcl\_bytes\.s__ to __unsigned
     char\*__ to match Tcl's type\. Further constified the field to make clear
     that read\-only usage is the common case for it\.

  1. Bugfix/Feature\. Package __[critcl::cutil](critcl\_cutil\.md)__ bumped
     to version 0\.2\. Fixed missing inclusion of header "string\.h" in
     "critcl\_alloc\.h", needed for __memcpy__ in macro __STREP__\. Added
     macros __ALLOC\_PLUS__ and __STRDUP__\. Moved documentation of
     __STREP\.\.\.__ macros into proper place \(alloc section, not assert\)\.

  1. Merged pull request \#83 from apnadkarni/vc\-fixes\. Removed deprecated \-Gs
     for MSVC builds, and other Windows fixups\.

  1. Feature\. Package __[critcl::iassoc](critcl\_iassoc\.md)__ bumped to
     version 1\.1\. Refactored internals to generate an include header for use by
     \.c files\. This now matches what other generator packages do\. The template
     file is inlined and removed\.

  1. Merged pull request \#82 from gahr/home\-symlink Modified tests to handle
     possibility of $HOME a symlink\.

  1. Merged pull request \#81 from gahr/test\-not\-installed Modified test support
     to find uninstalled critcl packages when running tests\. Handles all but
     critcl::md5\.

  1. Merged pull request \#85 from snoe925/issue\-84 to fix Issue \#84 breaking
     installation on OSX\.

  1. Merged pull request \#87 from apnadkarni/tea\-fixes to fix Issue \#86, broken
     \-tea option, generating an incomplete package\.

  1. Feature\. New package __[critcl::callback](critcl\_callback\.md)__
     providing C\-level functions and data structures to manage callbacks from C
     to Tcl\.

  1. Feature\. Package __[critcl::literals](critcl\_literals\.md)__ bumped
     to version 1\.3\. Added mode __\+list__ enabling the conversion of
     multiple literals into a list of their strings\.

  1. Feature\. Package __[critcl::enum](critcl\_enum\.md)__ bumped to
     version 1\.1\. Added basic mode handling, supporting __tcl__ \(default\)
     and __\+list__ \(extension enabling the conversion of multiple enum
     values into a list of their strings\)\.

  1. Feature\. Package __[critcl::emap](critcl\_emap\.md)__ bumped to
     version 1\.2\. Extended existing mode handling with __\+list__ extension
     enabling the conversion of multiple emap values into a list of their
     strings\.

  1. Feature\. Extended the set of available types by applying a few range
     restrictions to the scalar types \(*int*, *long*, *wideint*,
     *double*, *float*\)\.

     Example: *int > 0* is now a viable type name\.

     This is actually more limited than the description might let you believe\.

     See the package reference for the details\.

# <a name='section7'></a>Changes for version 3\.1\.17

  1. Extension: Allow duplicate arg\- and result\-type definitions if they are
     fully identical\.

  1. Bugfix\. The application mishandled the possibility of identical\-named
     __critcl::tsource__s\. Possible because __critcl::tsource__s can be
     in subdirectories, a structure which is *not* retained in the assembled
     package, causing such files to overwrite each other and at least one lost\.
     Fixed by adding a serial number to the file names in the assembled package\.

  1. Bugfix in the static scanner which made it loose requirement information\.
     Further added code to generally cleanup results at the end \(removal of
     duplicates, mainly\)\.

  1. Bugfix: Fixed issue \#76\. Support installation directories which are not in
     the __auto\_path__\. Without the patch the installed
     __[critcl](critcl\.md)__ will not find its own packages and fail\.
     Thank you to [Simon Bachmann](https://github\.com/lupylucke) for the
     report and patch, and then his patience with me to getting to actually
     apply it\.

  1. Bugfix: Fixed issue \#75\. Extended __critcl::include__ to now take
     multiple paths\.

  1. Added new compatibility package __lmap84__\.

  1. Fixed typos in various documentation files\.

  1. Fixed bug introduced by commit 86f415dd30 \(3\.1\.16 release\)\. The separation
     of __critcl::ccode__ into user and work layers means that location
     retrieval has to go one more level up to find the user location\.

  1. New supporting package __[critcl::cutil](critcl\_cutil\.md)__\.
     Provides common C level facilities useful to packages \(assertions, tracing,
     memory allocation shorthands\)\.

  1. Modified package __[critcl](critcl\.md)__ to make use of the new
     tracing facilities to provide tracing of arguments and results for
     __critcl::ccommand__ and __critcl::cproc__ invokations\.

  1. Modified packages __[critcl](critcl\.md)__ and
     __[critcl::class](critcl\_class\.md)__ to provide better function
     names for \(class\) method tracing\. Bumped package
     __[critcl::class](critcl\_class\.md)__ to version 1\.0\.7\.

  1. Extended the support package
     __[critcl::literals](critcl\_literals\.md)__ with limited
     configurability\. It is now able to generate code for C\-level access to the
     pool without Tcl types \(Mode __c__\)\. The previously existing
     functionality is accesssible under mode __tcl__, which also is the
     default\. Both modes can be used together\.

  1. Extended the support package __[critcl::emap](critcl\_emap\.md)__
     with limited configurability\. It is now able to generate code for C\-level
     access to the mapping without Tcl types \(Mode __c__\)\. The previously
     existing functionality is accessible under mode __tcl__, which also is
     the default\. Both modes can be used together\.

# <a name='section8'></a>Changes for version 3\.1\.16

  1. New feature\. Extended __critcl::cproc__'s argument handling to allow
     arbitrary mixing of required and optional arguments\.

  1. New feature\. *Potential Incompatibility*\.

     Extended __critcl::cproc__'s argument handling to treat an argument
     __args__ as variadic if it is the last argument of the procedure\.

  1. New feature\. Added two introspection commands, __critcl::has\-argtype__
     and __critcl::has\-resulttype__\. These enable a user to test if a
     specific \(named\) type conversion is implemented or not\.

  1. Added new result type __Tcl\_Obj\*0__, with alias __object0__\. The
     difference to __Tcl\_Obj\*__ is in the reference counting\.

  1. Extended the command __critcl::argtypesupport__ with new optional
     argument through which to explicitly specify the identifier for guarding
     against multiple definitions\.

  1. Bugfix: Fixed problem with the implementation of issue \#54 \(See 3\.1\.14\)\.
     Always create the secondary log file\. Otherwise end\-of\-log handling may
     break, unconditionally assuming its existence\.

  1. Bugfix: Fixed problem with the internal change to the hook
     __HandleDeclAfterBuild__\. Corrected the forgotten
     __critcl::cconst__\.

  1. Debugging aid: Added comment holding the name of the result type when
     emitting result conversions\.

  1. Bugfix: Fixed issue \#60\. Unbundled the package directories containing
     multiple packages\. All directories under "lib/" now contain exactly one
     package\.

  1. Bugfix: Fixed issue \#62, a few __dict exists__ commands operating on a
     fixed string instead of a variable\.

  1. Bugfix: Fixed issue \#56\. Release builders are reminded to run the tests\.

  1. Bugfix: Fixed issue \#55\. For FreeBSD critcl's platform package now
     identifies the Kernel ABI version\. Initialization of the cache directory
     now also uses __platform::identify__ for the default path, instead of
     __platform::generic__\.

  1. Bugfix: Fixed issue \#58\. Simplified the setup and use of md5\. CriTcl now
     makes use of its own package for md5, using itself to built it\. There is no
     chicken/egg problem with this as the __\-pkg__ mode used for this does
     not use md5\. That is limited to mode *[compile &
     run](\.\./index\.md\#compile\_run)*\.

# <a name='section9'></a>Changes for version 3\.1\.15

  1. Fixed version number bogosity with __3\.1\.14__\.

# <a name='section10'></a>Changes for version 3\.1\.14

  1. Fixed issue \#36\. Added message to target __all__ of the Makefile
     generated for TEA mode\. Additionally tweaked other parts of the output to
     be less noisy\.

  1. Accepted request implied in issue \#54\. Unconditionally save the
     compiler/linker build log into key __log__ of the dictionary returned
     by __cresults__, and save a copy of only the execution output in the
     new key __exl__ \("execution log"\)\.

  1. Fixed issue \#53\. Clarified the documentation of commands
     __critcl::load__ and __critcl::failed__ with regard to their
     results and the throwing of errors \(does not happen\)\.

  1. Fixed issue \#48\. Modified mode "compile & run" to allow new declarations in
     a file, after it was build, instead of erroring out\. The new decls are
     build when needed\. Mode "precompile" is unchanged and will continue to trap
     the situation\.

  1. Fixed issue \#52\. Updated the local Tcl/Tk headers to 8\.4\.20, 8\.5\.13, and
     8\.6\.4\.

  1. Fixed issue \#45\. New feature command __critcl::cconst__\.

  1. __[critcl::util](critcl\_util\.md)__: New command __locate__ to
     find a file across a set of paths, and report an error when not found\. This
     is for use in autoconf\-like header\-searches and similar configuration
     tests\.

  1. Modified 'AbortWhenCalledAfterBuild' to dump the entire stack \(info
     frame\!\)\. This should make it easier to determine the location of the
     troubling declaration\.

# <a name='section11'></a>Changes for version 3\.1\.13

  1. Merged PR \#43\. Fixed bug loading adjunct Tcl sources\.

  1. Fixes in documentation and generated code of package "critcl::enum"\. Bumped
     to version 1\.0\.1\.

  1. Fixes in documentation of package "critcl::bitmap"\.

  1. New package "critcl::emap"\. In essence a variant or cross of
     "critcl::bitmap" with behaviour like "critcl::enum"\.

  1. Merged PR \#49\. Fixed documentation typo\.

  1. Merged PR \#46\. Fixed documentation typo\.

  1. Merged PR \#47\. Fixes to test results to match the accumulated code changes\.
     Also made portable across Tcl versions \(varying error syntax\)\.

  1. New predefined argument\- and result\-type "wideint" mapping to Tcl\_WideInt\.

  1. New predefined argument\-type "bytes" mapping to tuple of byte\-array data
     and length\. Note: The existing "bytearray" type \(and its aliases\) was left
     untouched, to keep backward compatibility\.

  1. Modified the internal interface between the Tcl shim and C function
     underneath "critcl::cproc" with respect to the handling of optional
     arguments\. An optional argument "X" now induces the use of two C arguments,
     "X" and "has\_X"\. The new argument "has\_X" is of boolean \(int\) type\. It is
     set to true when X is set, and set to false when X has the default value\. C
     code which cares about knowing if the argument is default or not is now
     able to check that quickly, without having to code the default value
     inside\. NOTE: This change is visible in the output of the advanced commands
     "argcnames", "argcsignature", "argvardecls", and "argconversion"\.

  1. Fixed issue \#50 and documented the availability of variable "interp" \(type
     Tcl\_Interp\*\) within "critcl::cinit" C code fragments\. Note that while the
     old, undocumented name of the variable, "ip", is still usable, it is
     deprecated\. It will be fully removed in two releases, i\.e\. for release
     3\.1\.15\. The variable name was changed to be consistent with other code
     environments\.

  1. Fixed issue \#51\. Disabled the generation of \#line directives for
     "critcl::config lines 0" coming from template files, or code generated with
     them before the final value of this setting was known\.

  1. Fixed issue with handling of namespaced package names in "critcl::iassoc"\.
     Equivalent to a bug in "critcl::class" fixed for critcl 3\.1\.1,
     critcl::class 1\.0\.1\. Note: "literals", "enum", "emap", and "bitmap" do not
     require a fix as they are all built on top of "iassoc"\.

# <a name='section12'></a>Changes for version 3\.1\.12

  1. Fixed issue 42\. Clear ::errorInfo immediately after startup to prevent
     leakage of irrelevant \(caught\) errors into our script and confusing the
     usage code\.

  1. Fixed issue 40\. Keep the order of libraries, and allow duplicates\. Both are
     things which are occasionally required for proper linking\.

  1. Extended the utility package
     __[critcl::literals](critcl\_literals\.md)__ to declare a cproc
     result\-type for a pool\.

     Further fixed the generated header to handle multiple inclusion\.

     Bumped version to 1\.1\.

  1. Fixed issue with utility package
     __[critcl::bitmap](critcl\_bitmap\.md)__\.

     Fixed the generated header to handle multiple inclusion\.

     Bumped version to 1\.0\.1\.

  1. Created new utility package __[critcl::enum](critcl\_enum\.md)__ for
     the quick and easy setup and use of mappings between C values and Tcl
     strings\. Built on top of
     __[critcl::literals](critcl\_literals\.md)__\.

  1. Added examples demonstrating the use of the utility packages
     __[critcl::literals](critcl\_literals\.md)__,
     __[critcl::bitmap](critcl\_bitmap\.md)__, and
     __[critcl::enum](critcl\_enum\.md)__

# <a name='section13'></a>Changes for version 3\.1\.11

  1. Fixed issue \#37, via pull request \#38, with thanks to Jos DeCoster\.
     Information was stored into the v::delproc and v::clientdata arrays using a
     different key than when retrieving the same information, thus failing the
     latter\.

  1. New convenience command __critcl::include__ for easy inclusion of
     headers and other C files\.

  1. New command __critcl::make__ to generate a local header of other C
     files for use by other parts of a package through inclusion\.

  1. New utility package __[critcl::literals](critcl\_literals\.md)__ for
     quick and easy setup of and access to pools of fixed Tcl\_Obj\* strings\.
     Built on top of __[critcl::iassoc](critcl\_iassoc\.md)__\.

  1. New utility package __[critcl::bitmap](critcl\_bitmap\.md)__ for
     quick and easy setup and use of mappings between C bitsets and Tcl lists
     whose string elements represent that set\. Built on top of
     __[critcl::iassoc](critcl\_iassoc\.md)__\.

# <a name='section14'></a>Changes for version 3\.1\.10

  1. Fixed code version numbering forgotten with 3\.1\.9\.

  1. Fixed issue \#35\. In package mode \(\-pkg\) the object cache directory is
     unique to the process, thus we do not need content\-hashing to generate
     unique file names\. A simple counter is sufficient and much faster\.

     Note that mode "compile & run" is not as blessed and still uses
     content\-hasing with md5 to ensure unique file names in its per\-user object
     cache\.

  1. Fixed issue where the __ccommand__ forgot to use its body as input for
     the UUID generation\. Thus ignoring changes to it in mode compile & run, and
     not rebuilding a library for changed sources\. Bug and fix reported by Peter
     Spjuth\.

# <a name='section15'></a>Changes for version 3\.1\.9

  1. Fixed issue \#27\. Added missing platform definitions for various alternate
     linux and OS X targets\.

  1. Fixed issue \#28\. Added missing \-mXX flags for linking at the
     linux\-\{32,64\}\-\* targets\.

  1. Fixed issue \#29\. Replaced the use of raw "cheaders" information in the
     processing of "cdefines" with the proper include directives derived from
     it\.

  1. Fixed the issue behind rejected pull request \#30 by Andrew Shadura\.
     Dynamically extract the stubs variable declarations from the Tcl header
     files and generate matching variable definitions for use in the package
     code\. The generated code will now be always consistent with the headers,
     even when critcl's own copy of them is replaced by system headers\.

  1. Fixed issue \#31\. Accepted patch by Andrew Shadura, with changes \(comments\),
     for easier integration of critcl with OS package systems, replacing
     critcl's copies of Tcl headers with their own\.

  1. Fixed issue \#32\. Merged pull request by Andrew Shadura\. Various typos in
     documentation and comments\.

  1. Fixed issue \#34\. Handle files starting with a dot better\.

# <a name='section16'></a>Changes for version 3\.1\.8

  1. Fixed issue with package indices generated for Tcl 8\.4\. Join the list of
     commands with semi\-colon, not newline\.

  1. Fixed issue \#26 which brought up use\-cases I had forgotten to consider
     while fixing bug \#21 \(see critcl 3\.1\.6\)\.

# <a name='section17'></a>Changes for version 3\.1\.7

  1. Fixed issue \#24\. Extract and unconditionally display compiler warnings
     found in the build log\. Prevents users from missing warnings which, while
     not causing the build to fail, may still indicate problems\.

  1. New feature\. Output hook\. All non\-messaging user output is now routed
     through the command __critcl::print__, and users are allowed to
     override it when using the critcl application\-as\-package\.

  1. New feature, by Ashok P\. Nadkarni\. Platform configurations can inherit
     values from configurations defined before them\.

# <a name='section18'></a>Changes for version 3\.1\.6

  1. Fixed issue \#21\. While the multi\-definition of the stub\-table pointer
     variables was ok with for all the C linkers seen so far C\+\+ linkers did not
     like this at all\. Reworked the code to ensure that this set of variables is
     generated only once, in the wrapper around all the pieces to assemble\.

  1. Fixed issue \#22, the handling of the command identifier arguments of
     __critcl::ccommand__, __critcl::cproc__, and __critcl::cdata__\.
     We now properly allow any Tcl identifier and generate proper internal C
     identifiers from them\.

     As part of this the signature of command __critcl::name2c__ changed\.
     The command now delivers a list of four values instead of three\. The new
     value was added at the end\.

     Further adapted the implementation of package
     __[critcl::class](critcl\_class\.md)__, a user of
     __critcl::name2c__\. This package is now at version 1\.0\.6 and requires
     critcl 3\.1\.6

     Lastly fixed the mis\-handling of option __\-cname__ in
     __critcl::ccommand__, and __critcl::cproc__\.

  1. Fixed issue \#23\.

# <a name='section19'></a>Changes for version 3\.1\.5

  1. Fixed issue \#19\. Made the regular expression extracting the MSVC version
     number more general to make it work on german language systems\. This may
     have to be revisited in the future, for other Windows locales\.

  1. Fixed issue \#20\. Made option \-tea work on windows, at least in a unix
     emulation environment like msys/mingw\.

# <a name='section20'></a>Changes for version 3\.1\.4

  1. Bugfix in package __[critcl::class](critcl\_class\.md)__\. Generate a
     dummy field in the class structure if the class has no class variables\.
     Without this change the structure would be empty, and a number of compilers
     are not able to handle such a type\.

  1. Fixed a typo which broke the win64 configuration\.

  1. Fixed issue \#16, a typo in the documentation of command
     __[critcl::class](critcl\_class\.md)__\.

# <a name='section21'></a>Changes for version 3\.1\.3

  1. Enhancement\. In detail:

  1. Added new argument type "pstring", for "Pascal String", a counted string,
     i\.e\. a combination of string pointer and string length\.

  1. Added new methods __critcl::argtypesupport__ and
     __::critcl::argsupport__ to define and use additional supporting code
     for an argument type, here used by "pstring" above to define the necessary
     structure\.

  1. Semi\-bugfixes in the packages __[critcl::class](critcl\_class\.md)__
     and __[critcl::iassoc](critcl\_iassoc\.md)__\. Pragmas for the AS meta
     data scanner to ensure that the template files are made part of the
     package\. Versions bumped to 1\.0\.4 and 1\.0\.1 respectively\.

# <a name='section22'></a>Changes for version 3\.1\.2

  1. Enhancement\. In detail:

  1. Extended __critcl::cproc__ to be able to handle optional arguments, in
     a limited way\. This is automatically available to
     __[critcl::class](critcl\_class\.md)__ cproc\-based methods as well\.

  1. Bugfix in __lassign__ emulation for Tcl 8\.4\. Properly set unused
     variables to the empty string\. Bumped version of emulation package
     __lassign84__ to 1\.0\.1\.

# <a name='section23'></a>Changes for version 3\.1\.1

  1. Bugfixes all around\. In detail:

  1. Fixed the generation of wrong\#args errors for __critcl::cproc__ and
     derived code \(__[critcl::class](critcl\_class\.md)__ cproc\-based
     methods\)\. Use NULL if there are no arguments, and take the offset into
     account\.

  1. Fixed the handling of package names by
     __[critcl::class](critcl\_class\.md)__\. Forgot that they may contain
     namespace separators\. Bumped to version 1\.0\.1\.

  1. Extended a __[critcl::class](critcl\_class\.md)__ generated error
     message in instance creation for clarity\. Bumped to version 1\.0\.2\.

# <a name='section24'></a>Changes for version 3\.1

  1. Added a new higher\-level package
     __[critcl::iassoc](critcl\_iassoc\.md)__\.

     This package simplifies the creation of code associating data with an
     interpreter via Tcl's __Tcl\_\(Get&#124;Set\)AssocData\(\)__ APIs\. The user can
     concentrate on his data while all the necessary boilerplate C code to
     support this is generated by the package\.

     This package uses several of the new features which were added to the core
     __[critcl](critcl\.md)__ package, see below\.

  1. Added the higher\-level package
     __[critcl::class](critcl\_class\.md)__\.

     This package simplifies the creation of C level objects with class and
     instance commands\. The user can write a class definition with class\- and
     instance\-variables and \-methods similar to a TclOO class, with all the
     necessary boilerplate C code to support this generated by the package\.

     This package uses several of the new features which were added to the core
     __[critcl](critcl\.md)__ package, see below\.

  1. Extended the API for handling TEApot metadata\. Added the command
     __critcl::meta?__ to query the stored information\. Main use currently
     envisioned is retrieval of the current package's name by utility commands,
     for use in constructed names\. This particular information is always
     available due to the static scan of the package file on execution of the
     first critcl command\.

     The new packages __[critcl::iassoc](critcl\_iassoc\.md)__ and
     __[critcl::class](critcl\_class\.md)__ \(see above\) are users of this
     command\.

  1. Extended the API with a command, __critcl::name2c__, exposing the
     process of converting a Tcl name into base name, namespace, and C
     namespace\. This enables higher\-level code generators to generate the same
     type of C identifiers as __[critcl](critcl\.md)__ itself\.

     The new package __[critcl::class](critcl\_class\.md)__ \(see above\) is
     a user of this command\.

  1. Extended the API with a command, __critcl::source__, executing critcl
     commands found in a separate file in the context of the current file\. This
     enables easier management of larger bodies of code as it allows the user to
     split such up into easier to digest smaller chunks without causing the
     generation of multiple packages\.

  1. Related to the previous item, extended the API with commands to divert
     collection of generated C code into memory\. This makes it easier to use the
     commands for embedded C code in higher\-level code generators\.

     See the section __Advanced: Diversions__ for details of the provided
     commands\.

     The new package __[critcl::class](critcl\_class\.md)__ \(see above\) is
     a user of these facilities\.

  1. Extended the API with commands helping developers with the generation of
     proper C *\#line* directives\. This allows higher\-level code generators to
     generate and insert their own directives, ensuring that compile errors in
     their code are properly attributed\.

     See the section __Advanced: Location management__ for details of the
     provided commands\.

     The new packages __[critcl::iassoc](critcl\_iassoc\.md)__ and
     __[critcl::class](critcl\_class\.md)__ \(see above\) are users of these
     facilities\.

  1. Extended the API with commands giving users the ability to define custom
     argument and result types for __::critcl::cproc__\.

     See the section __CriTcl cproc Type Reference__ for details of the
     provided commands\.

# <a name='section25'></a>Changes for version 3\.0\.7

  1. Fixed the code generated by __critcl::c\+\+command__\. The emitted code
     handed a non\-static string table to __Tcl\_GetIndexFromObj__, in
     violation of the contract, which requires the table to have a fixed
     address\. This was a memory smash waiting to happen\. Thanks to Brian Griffin
     for alrerting us to the general problem\.

# <a name='section26'></a>Changes for version 3\.0\.6

  1. Fixed github issue 10\. The critcl application now delivers a proper exit
     code \(1\) on build failure, instead of always indicating success \(status 0\)\.

  1. Fixed github issue 13\. Handling of bufferoverflowU\.lib for release builds
     was inconsistent with handling for debug builds\. It is now identically
     handled \(conditional\) by both cases\.

  1. Documentation cleanup, mainly in the installation guide, and the README\.md
     shown by github

# <a name='section27'></a>Changes for version 3\.0\.5

  1. Fixed bug in the new code for \#line pragmas triggered when specifying C
     code without leading whitespace\.

  1. Extended the documentation to have manpages for the license, source
     retrieval, installer, and developer's guides\.

# <a name='section28'></a>Changes for version 3\.0\.4

  1. Fixed generation of the package's initname when the incoming code is read
     from stdin and has no proper path\.

  1. Fixed github issue 11\. Now using /LIBPATH instead of \-L on Windows
     \(libinclude configuration setting\)\.

  1. Extended critcl to handle \-l:path format of \-l options\. GNU ld 2\.22\+
     handles this by searching for the path as is\. Good when specifying static
     libraries, as plain \-l looks for shared libraries in preference over
     static\. critcl handles it now, as older GNU ld's do not understand it, nor
     the various vendor\-specific linkers\.

  1. Fixed github issue \#12\. CriTcl now determines the version of MSVC in use
     and uses it to switch between various link debug options\. Simplified the
     handling of bufferoverflowU\.lib also, making use of the same mechanism and
     collapsing the two configurations sections we had back into one\.

  1. Reworked the insertion of \#line pragmas into the generated C code to avoid
     limitations on the line number argument imposed by various compilers, and
     be more accurate\.

  1. Modified argument processing\. Option \-libdir now also implies \-L for its
     argument\.

  1. Extended handling of option \-show \(__critcl::showconfig__\) to list the
     path of the configuration file the data is coming from\. Good for debugging
     configuration processing\.

  1. Extended the build script with targets to regenerate the embedded
     documentation, and diagrams, and to generate a release\.

# <a name='section29'></a>Changes for version 3\.0\.3

  1. Fixed github issues 5 and 8, for the example build\.tcl scripts\. Working
     around a missing variable ::errorInfo\. It should always be present, however
     there seem to be revisions of Tcl around which violate this assumption\.

# <a name='section30'></a>Changes for version 3\.0\.2

  1. Fixed issue in compile\-and\-run mode where commands put into the auto\_index
     are not found by Tcl's \[unknown\] command\.

  1. Fixed an array key mismatch breaking usage of client data and delete
     function for procedure\. Reported by Jos DeCoster, with patch\.

  1. Implemented a command line option __\-L__, an equivalent of option
     __\-I__, just for library search paths\.

  1. Fixed github issues 5 and 8\. Working around a missing variable ::errorInfo\.
     It should always be present, however there seem to be revisions of Tcl
     around which violate this assumption\.

# <a name='section31'></a>Changes for version 3\.0\.1

  1. Bugfixes all around\. In detail:

  1. Fixed recording of Tcl version requirements\. Keep package name and version
     together, unbreaking generated meta data and generated package load
     command\.

  1. Fixed the build scripts: When installing, or wrapping for TEA, generate any
     missing directories

  1. Modified the build scripts to properly exit the application when the window
     of their GUI is closed through the \(X\) button\.

  1. Removed an 8\.5\-ism \(open wb\) which had slipped into the main build script\.

  1. Modified the example build scripts to separate the output for the different
     examples \(and packages\) by adding empty lines\.

  1. stack::c example bugfix: Include API declarations for use in the companion
     files\.

  1. Extended the documentation: Noted the need for a working installation of a
     C compiler\.

  1. Extended the Windows target definitions and code to handle the manifest
     files used by modern MS development environments\. Note that this code
     handles both possibilities, environment using manifests, and \(old\(er\)\)
     environments without\.

  1. Extended the Windows 64bit target definitions and code to auto\-detect the
     need for the helper library "bufferoverflowU\.lib" and reconfigure the
     compile and link commands appropriately\. We assume that the library must be
     linked when present\. This should be no harm if the library is present, yet
     not needed\. Just superfluous\. We search for the library in the paths
     specified by the environment variable LIB\.

# <a name='section32'></a>Changes for version 3

  1. The command __critcl::platform__ was deprecated in version 2\.1,
     superceded by __critcl::targetplatform__, yet kept for compatibility\.
     Now it has been removed\.

  1. The command __critcl::compiled__ was kept with in version 2\.1 with
     semantics in contradiction to its, for compatibility\. This contradiction
     has been removed, changing the visible semantics of the command to be in
     line with its name\.

  1. The change to version 3 became necessary because of the two incompatible
     visible changes above\.

  1. Extended the application package with code handling a new option
     __\-tea__\. Specifying this option invokes a special mode where critcl
     generates a TEA package, i\.e\. wraps the input into a directory hierarchy
     and support files which provide it TEA\-lookalike buildsystem\.

     This new option, and __\-pkg__, exclude each other\. If both are
     specified the last used option takes precedence\.

     The generated package directory hierarchy is mostly self\-contained, but not
     fully\. It requires not only a working installation of Tcl, but also working
     installations of the packages __md5__ and __cmdline__\. Both of
     these are provided by the __Tcllib__ bundle\. Not required, but
     recommended to have installed are any of the packages which can accelerate
     md5's operation, i\.e\. __cryptkit__, __tcllibc__, or __Trf__\.

  1. Extended the critcl package with a new command __critcl::scan__ taking
     the path to a "\.critcl" file, statically scanning it, and returning
     license, version, a list of its companion files, list of imported APIs, and
     list of developer\-specified custom configuration options\. This data is the
     foundation for the TEA wrapping described above\.

     Note that this is a *static* scan\. While the other build modes can \(must\)
     execute the "\.critcl" file and make platform\-specific decisions regarding
     the assembled C code, companion files, etc\. the TEA wrap mode is not in a
     position to make platform\-specific decisions\. It has to wrap everything
     which might conceivably be needed when actually building\. Hence the static
     scan\. This has however its own set of problems, namely the inability to
     figure out any dynamic construction of companion file paths, at least on
     its own\. Thus:

  1. Extended the API used by critcl\-based packages with the command
     __critcl::owns__\. While this command is ignored by the regular build
     modes the static scanner described above takes its arguments as the names
     of companion files which have to be wrapped into the TEA package and could
     not be figured by the scanner otherwise, like because of dynamic paths to
     __critcl::tsources__, __critcl::csources__, getting sourced
     directly, or simply being adjunct datafiles\.

  1. Extended the API used by critcl\-based packages with the command
     __critcl::api__ for the management of stubs tables, be it their use,
     and/or declaration and export\.

     Please see section *Stubs Table Management* of the
     __[critcl](critcl\.md)__ package documentation for details\.

  1. Extended the API used by critcl\-based packages with the command
     __critcl::userconfig__ for the management of developer\-specified custom
     configuration options, be it their use and/or declaration\.

     Please see section *Custom Build Configuration* of the
     __[critcl](critcl\.md)__ package documentation for details\.

  1. Extended the API used by critcl\-based packages with the commands
     __critcl::description__, __critcl::summary__,
     __critcl::subject__, __critcl::meta__, and
     __critcl::buildrequirement__ for the declaration of TEApot meta data
     for/about the package\.

     Please see section *Package Meta Data* of the
     __[critcl](critcl\.md)__ package documentation for details\.

# <a name='section33'></a>Changes for version 2\.1

  1. Fixed bug where __critcl::tsources__ interpreted relative paths as
     relative to the current working directory instead of relative to the
     "\.critcl" file using the command, as all other commands of this type do\.

  1. Fixed internals, preventing information collected for multiple "\.critcl"
     files to leak between them\. Notably, __critcl::tk__ is not a global
     configuration option anymore\.

  1. Fixed the command __critcl::license__ to be a null\-operation in mode
     "compile & run", instead of throwing an error\.

  1. Fixed the critcl application's interference with the "compile & run" result
     cache in __\-pkg__ mode by having it use a wholly separate \(and by
     default transient\) directory for that mode\.

  1. Fixed bug where changes to a "\.critcl" file did not result in a rebuild for
     mode "compile & run"\. All relevant API commands now ensure UUID changes\.

  1. Fixed bug in the backend handling of __critcl::debug__ where the
     companion c\-sources of a "\.critcl" file were not compiled with debug
     options, although the "\.critcl" file was\.

  1. Fixed bug in __critcl::debug__ which prevented recognition of mode
     "all" when it was not the first argument to the command\.

  1. Fixed bug in "preload\.c" preventing its compilation on non\-windows
     platforms\.

  1. Fixed long\-standing bug in the handling of namespace qualifiers in the
     command name argument of __critcl::cproc__ and
     __critcl::ccommand__\. It is now possible to specify a fully qualified
     command name without issues\.

  1. Extended/reworked __critcl::tsources__ to be the canonical way of
     declaring "\.tcl" companion files even for mode "compile & run"\.

  1. Extended/reworked __critcl::tsources__ to allow the use of a "\.critcl"
     file as its own Tcl companion file\.

  1. Extended __critcl::framework__ to internally check for OS X build
     target, and to ignore the declaration if its not\.

  1. Extended __critcl::failed__ to be callable more than once in a
     "\.critcl" file\. The first call forces the build, if it was not done
     already, to get the result\. Further calls return the cached result of the
     first call\.

  1. Extended the handling of environment variable CC in the code determining
     the compiler to use to deal with \(i\.e\. remove\) paths to the compiler,
     compiler file extensions, and compiler options specified after the compiler
     itself, leaving only the bare name of the compiler\.

  1. Extended the code handling the search for preloaded libraries to print the
     paths it searched, making debugging of a search failure easier\.

  1. A new command __critcl::tcl__ can be used to declare the version of Tcl
     minimally needed to build and run the "\.critcl" file and package\. Defaults
     to 8\.4 if not declared\. Extended critcl to have the stubs and headers for
     all of Tcl 8\.4, 8\.5, and 8\.6\.

  1. A new command __critcl::load__ forces the build and load of a "\.critcl"
     file\. This is the official way for overriding critcl's default
     lazy\-build\-&\-load\-on\-demand scheme for mode "compile & run"\.

     *Note* that after using __critcl::load__ / __critcl::failed__ in
     a "\.critcl" file it is not possible to use critcl commands in that file
     anymore\. Doing so will throw an error\.

  1. Extended the generation of '\#line' pragmas to use __info frame__ \(if
     available\) to provide the C compiler with exact line numbers into the
     "\.critcl" file for the reporting of warnings and errors\.

  1. Extended __critcl::check__ with logging to help with debugging
     build\-time checks of the environment, plus an additional optional argument
     to provide labeling\.

  1. Added a new command __critcl::checklink__ which not only tries to check
     the environment via compiling the code, but also its linkability\.

  1. Added a new command __critcl::msg__ for messaging, like command
     __critcl::error__ is for error reporting\. Likewise this is a hook a
     user of the package is allowed to override\. The default implementation,
     used by mode *[compile & run](\.\./index\.md\#compile\_run)* does nothing\.
     The implementation for mode *[generate
     package](\.\./index\.md\#generate\_package)* prints the message to stdout\.

     Envisioned use is for the reporting of results determined by
     __critcl::check__ and __critcl::checklink__ during building, to
     help with debugging when something goes wrong with a check\.

  1. Exposed the argument processing internals of __critcl::proc__ for use
     by advanced users\. The new commands are

       1) __critcl::argnames__

       1) __critcl::argcnames__

       1) __critcl::argcsignature__

       1) __critcl::argvardecls__

       1) __critcl::argconversion__

     Please see section *Advanced Embedded C Code* of the
     __[critcl](critcl\.md)__ package documentation for details\.

  1. Extended the critcl package to intercept __package__ __provide__
     and record the file \-> package name mapping\. Plus other internal changes
     now allow the use of namespaced package names while still using proper path
     names and init function\.

  1. Dropped the unused commands __critcl::optimize__ and
     __critcl::include__\.

  1. Dropped __\-lib__ mode from the critcl application\.

  1. Dropped remnants of support for Tcl 8\.3 and before\.

# <a name='section34'></a>Authors

Jean Claude Wippler, Steve Landers, Andreas Kupries

# <a name='section35'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report them at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)\.
Ideas for enhancements you may have for either package, application, and/or the
documentation are also very welcome and should be reported at
[https://github\.com/andreas\-kupries/critcl/issues](https://github\.com/andreas\-kupries/critcl/issues)
as well\.

# <a name='keywords'></a>KEYWORDS

[C code](\.\./index\.md\#c\_code), [Embedded C
Code](\.\./index\.md\#embedded\_c\_code), [calling C code from
Tcl](\.\./index\.md\#calling\_c\_code\_from\_tcl), [code
generator](\.\./index\.md\#code\_generator), [compile &
run](\.\./index\.md\#compile\_run), [compiler](\.\./index\.md\#compiler),
[dynamic code generation](\.\./index\.md\#dynamic\_code\_generation), [dynamic
compilation](\.\./index\.md\#dynamic\_compilation), [generate
package](\.\./index\.md\#generate\_package), [linker](\.\./index\.md\#linker),
[on demand compilation](\.\./index\.md\#on\_demand\_compilation), [on\-the\-fly
compilation](\.\./index\.md\#on\_the\_fly\_compilation)

# <a name='category'></a>CATEGORY

Glueing/Embedded C code

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; Jean\-Claude Wippler  
Copyright &copy; Steve Landers  
Copyright &copy; 2011\-2024 Andreas Kupries
