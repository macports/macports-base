
The source code for Tcl is managed by fossil.  Tcl developers coordinate all
changes to the Tcl source code at

> [Tcl Source Code](https://core.tcl-lang.org/tcl/timeline)

Release Tcl 9.0.3 arises from the check-in with tag `core-9-0-3`.

Tcl patch releases have the primary purpose of delivering bug fixes
to the userbase.

# Bug fixes
 - [On Unix, IsTimeNative() always defined but not always used](https://core.tcl-lang.org/tcl/tktview/6b8e39)
 - [Tweak install permissions](https://core.tcl-lang.org/tcl/tktview/31d4fa)
 - [interp creation resets encoding directory search path](https://core.tcl-lang.org/tcl/tktview/87b697)
 - [Pointer arithmetic with NULL in buildInfoObjCmd()](https://core.tcl-lang.org/tcl/tktview/85fc8b)
 - [TclPushVarName(): pointer overflow](https://core.tcl-lang.org/tcl/tktview/77059c)
 - [Add IWYU export pragma annotations](https://core.tcl-lang.org/tcl/tktview/c7dc59)
 - [Windows: Install man pages](https://core.tcl-lang.org/tcl/tktview/3161b7)
 - [Windows: Install pkgconfig](https://core.tcl-lang.org/tcl/tktview/1cf49a)
 - [Non-existent variables are ignored if re is {}](https://core.tcl-lang.org/tcl/tktview/cb03e5)
 - [bug in single-argument 'max' with bignums](https://core.tcl-lang.org/tcl/tktview/8dd280)

# Updated bundled packages, libraries, standards, data
 - Itcl 4.3.5
 - http 2.10.1
 - opt 0.4.10
 - platform 1.1.0
 - sqlite3 3.51.0
 - tcltest 2.5.10
 - Thread 3.0.4
 - TDBC\* 1.1.13
 - dde 1.4.6
 - Unicode 17.0.0

Release Tcl 9.0.2 arises from the check-in with tag `core-9-0-2`.

Tcl patch releases have the primary purpose of delivering bug fixes
to the userbase.

# New commands and options
 - [New command encoding user](https://core.tcl-lang.org/tips/doc/trunk/tip/716.md)
 - [New exec option -encoding](https://core.tcl-lang.org/tips/doc/trunk/tip/716.md)

# Bug fixes
 - [Better error-message than "interpreter uses an incompatible stubs mechanism"](https://core.tcl-lang.org/tcl/tktview/fc3509)
 - [\[$interp eval $lambda\] after \[eval $lambda\] or vice versa fails](https://core.tcl-lang.org/tcl/tktview/67d5f7)
 - [tcl::mathfunc::isunordered inconsistency with some integer values](https://core.tcl-lang.org/tcl/tktview/98006f)
 - [test lseq hangs with -Os](https://core.tcl-lang.org/tcl/tktview/d2a3c5)
 - [exec does not handle app execution aliases on Windows](https://core.tcl-lang.org/tcl/tktview/4f0b57)
 - [auto_execok does not find several built-in cmd commands](https://core.tcl-lang.org/tcl/tktview/4e2c8b)
 - [Panic "Buffer Underflow, BUFFER_PADDING not enough"](https://core.tcl-lang.org/tcl/tktview/73bb42)
 - [MS-VS build system: pckIndex.tcl when building for 9 misses "t" for TCL 8.6 part](https://core.tcl-lang.org/tcl/tktview/a77029)
 - [clock format -locale does not look up locale children if parent locale used first](https://core.tcl-lang.org/tcl/tktview/2c0f49)
 - [Missing libtcl?.?.dll.a in Cygwin](https://core.tcl-lang.org/tcl/tktview/dcedba)
 - [tclEpollNotfy PlatformEventsControl panics if websocket disconnected](https://core.tcl-lang.org/tcl/tktview/010d8f)
 - [Tcl_InitStubs compatibility for 9.1](https://core.tcl-lang.org/tcl/tktview/fd8341)
 - [proc with more than 2**31 variables](https://core.tcl-lang.org/tcl/tktview/92aeb8)
 - [scan "long mantissa" %g](https://core.tcl-lang.org/tcl/tktview/42d14c)
 - ["encoding system": wrong result without manifest](https://core.tcl-lang.org/tcl/tktview/8ffd8c)
 - [lseq crash on out-of-range index](https://core.tcl-lang.org/tcl/tktview/7d3101)
 - [lseq crash on nested indices](https://core.tcl-lang.org/tcl/tktview/452b10)
 - [Build broken (trunk branch) tclCompExpr.c tclOOCall.c](https://core.tcl-lang.org/tcl/tktview/1dcda0)
 - [Memory allocation runaway on truncated iso2022 encoding](https://core.tcl-lang.org/tcl/tktview/7346ad)
 - [Missing include dir for extensions in non-default locations](https://core.tcl-lang.org/tcl/tktview/333512)
 - [tcl::tm::path doesn't handle tilde expand](https://core.tcl-lang.org/tcl/tktview/b87673)
 - [lseq numeric overflow](https://core.tcl-lang.org/tcl/tktview/0ee626)
 - ["return": broken ordering of nested -options](https://core.tcl-lang.org/tcl/tktview/ecf35c)
 - [Euro/Tail-sign missing from cp864 encoding](https://core.tcl-lang.org/tcl/tktview/ecafd8)
 - [use after free on TSD in Winsock](https://core.tcl-lang.org/tcl/tktview/40b181)
 - [use after free on Windows pipe handles](https://core.tcl-lang.org/tcl/tktview/7c2716)
 - [tcl::build-info not documented](https://core.tcl-lang.org/tcl/tktview/ef7042)
 - [Fix 32 bit overflow in interp limit](https://core.tcl-lang.org/tcl/tktview/9dfae3)

# Incompatibilities
 - [The ActiveCodePage element has been removed from the Windows executable manifest for tclsh](https://core.tcl-lang.org/tips/doc/trunk/tip/716.md)

# Updated bundled packages, libraries, standards, data
 - Itcl 4.3.3
 - sqlite3 3.49.1
 - Thread 3.0.2
 - TDBC\* 1.1.11
 - tzdata 2025b

Release Tcl 9.0.1 arises from the check-in with tag `core-9-0-1`.

Tcl patch releases have the primary purpose of delivering bug fixes
to the userbase.  As the first patch release in the Tcl 9.0.\* series,
Tcl 9.0.1 also includes a small number of interface changes that complete
some incomplete features first delivered in Tcl 9.0.0.

# Completed 9.0 Features and Interfaces
 - [TIP 701 - Tcl_FSTildeExpand C API](https://core.tcl-lang.org/tips/doc/trunk/tip/701.md)
 - [TIP 707 - ptrAndSize internal rep in Tcl_Obj](https://core.tcl-lang.org/tips/doc/trunk/tip/707.md)
 - [Size modifiers j, q, z, t not implemented]( https://core.tcl-lang.org/tcl/info/c4f365)

# Bug fixes
 - [regression in tzdata, %z instead of offset TZ-name](https://core.tcl-lang.org/tcl/tktview/2c237b)
 - [Tcl will not start properly if there is an init.tcl file in the current dir](https://core.tcl-lang.org/tcl/tktview/43c94f)
 - [clock scan "24:00", ISO-8601 compatibility](https://core.tcl-lang.org/tcl/tktview/aee9f2)
 - [Temporary folder with file "tcl9registry13.dll" remains after "exit"](https://core.tcl-lang.org/tcl/tktview/6ce3c0)
 - [Wrong result by "lsearch -stride -subindices -inline -all"](https://core.tcl-lang.org/tcl/info/5a1aaa)
 - [TIP 609 - required Tcl_ThreadAlert() skipped with nested event loop](https://core.tcl-lang.org/tcl/info/c7e4c4)
 - [buffer overwrite for non-BMP characters in utf-16](https://core.tcl-lang.org/tcl/tktview/66da4d)
 - [zipfs info on mountpoint of executable returns zero offset in field 4"](https://core.tcl-lang.org/tcl/info/aaa84f)
 - [zlib-8.8, zlib-8.16 fail on Fedora 40, gcc 14.1.1](https://core.tcl-lang.org/tcl/tktview/73d5cb)
 - [install registry and dde in $INSTALL_DIR\lib always](https://core.tcl-lang.org/tcl/tktview/364bd9)
 - [cannot build .chm help file (Windows)](https://core.tcl-lang.org/tcl/tktview/bb110c)

# Incompatibilities
 - No known incompatibilities with the Tcl 9.0.0 public interface.

# Updated bundled packages, libraries, standards, data
 - Itcl 4.3.2
 - sqlite3 3.47.2
 - Thread 3.0.1
 - TDBC\* 1.1.10
 - tcltest 2.5.9
 - tzdata 2024b, corrected

Release Tcl 9.0.0 arises from the check-in with tag `core-9-0-0`.

Highlighted differences between Tcl 9.0 and Tcl 8.6 are summarized below,
with focus on changes important to programmers using the Tcl library and
writing Tcl scripts.

# Major Features

## 64-bit capacity: Data values larger than 2Gb
 - Strings can be any length (that fits in your available memory)
 - Lists and dictionaries can have very large numbers of elements

## Internationalization of text
 - Full Unicode range of codepoints
 - New encodings: `utf-16`/`utf-32`/`ucs-2`(`le`|`be`), `CESU-8`, etc.
 - `encoding` options `-profile`, `-failindex` manage encoding of I/O.
 - `msgcat` supports custom locale search list
 - `source` defaults to `-encoding utf-8`

## Zip filesystems and attached archives.
 - Packaging of the Tcl script library with the Tcl binary library,
   meaning that the `TCL_LIBRARY` environment variable is usually not required.
 - Packaging of an application into a virtual filesystem is now a supported
   core Tcl feature.

## Unix notifiers available using `epoll()` or `kqueue()`
 - This relieves limits on file descriptors imposed by legacy `select()` and fixes a performance bottleneck.

# Incompatibilities

## Notable incompatibilities
 - Unqualified varnames resolved in current namespace, not global.
   Note that in almost all cases where this causes a change, the change is actually the removal of a latent bug.
 - No `--disable-threads` build option.  Always thread-enabled.
 - I/O malencoding default response: raise error (`-profile strict`)
 - Windows platform needs Windows 7 or Windows Server 2008 R2 or later
 - Ended interpretation of `~` as home directory in pathnames.
   (See `file home` and `file tildeexpand` for replacements when you need them.)
 - Removed the `identity` encoding.
   (There were only ever very few valid use cases for this; almost all uses
   were systematically wrong.)
 - Removed the encoding alias `binary` to `iso8859-1`.
 - `$::tcl_precision` no longer controls string generation of doubles.
   (If you need a particular precision, use `format`.)
 - Removed pre-Tcl 8 legacies: `case`, `puts` and `read` variant syntaxes.
 - Removed subcommands [`trace variable`|`vdelete`|`vinfo`]
 - Removed `-eofchar` option for write channels.
 - On Windows 10+ (Version 1903 or higher), system encoding is always utf-8.
 - `%b`/`%d`/`%o`/`%x` format modifiers (without size modifier) for `format`
   and `scan` always truncate to 32-bits on all platforms.
 - `%L` size modifier for `scan` no longer truncates to 64-bit.
 - Removed command `::tcl::unsupported::inject`.
   (See `coroinject` and `coroprobe` for supported commands with significantly
   more comprehensible semantics.)

## Incompatibilities in C public interface
 - Extensions built against Tcl 8.6 and before will not work with Tcl 9.0;
   ABI compatibility was a non-goal for 9.0.  In _most_ cases, rebuilding
   against Tcl 9.0 should work except when a removed API function is used.
 - Many arguments expanded type from `int` to `Tcl_Size`, a signed integer type
   large enough to support 64-bit sized memory objects.
   The constant `TCL_AUTO_LENGTH` is a value of that type that indicates that
   the length should be obtained using an appropriate function (typically `strlen()` for `char *` values).
 - Ended support for `Tcl_ChannelTypeVersion` less than 5
 - Introduced versioning of the `Tcl_ObjType` struct
 - Removed macros `CONST*`: Tcl 9 support means dropping Tcl 8.3 support.
   (Replaced with standard C `const` keyword going forward.)
 - Removed registration of several `Tcl_ObjType`s.
 - Removed API functions:

     `Tcl_Backslash()`,
     `Tcl_*VA()`,
     `Tcl_*MathFunc*()`,
     `Tcl_MakeSafe()`,
     `Tcl_(Save|Restore|Discard|Free)Result()`,
     `Tcl_EvalTokens()`,
     `Tcl_(Get|Set)DefaultEncodingDir()`,
     `Tcl_UniCharN(case)cmp()`,
     `Tcl_UniCharCaseMatch()`

 - Revised many internals; beware reliance on undocumented behaviors.

# New Features

## New commands
 - `array default` — Specify default values for arrays (note that this alters the behaviour of `append`, `incr`, `lappend`).
 - `array for` — Cheap iteration over an array's contents.
 - `chan isbinary` — Test if a channel is configured to work with binary data.
 - `coroinject`, `coroprobe` — Interact with paused coroutines.
 - `clock add weekdays` — Clock arithmetic with week days.
 - `const`, `info const*` — Commands for defining constants (variables that can't be modified).
 - `dict getwithdefault` — Define a fallback value to use when `dict get` would otherwise fail.
 - `file home` — Get the user home directory.
 - `file tempdir` — Create a temporary directory.
 - `file tildeexpand` — Expand a file path containing a `~`.
 - `info commandtype` — Introspection for the kinds of commands.
 - `ledit` — Equivalent to `lreplace` but on a list in a variable.
 - `lpop` — Remove an item from a list in a variable.
 - `lremove` — Remove a sublist from a list in a variable.
 - `lseq` — Generate a list of numbers in a sequence.
 - `package files` — Describe the contents of a package.
 - `string insert` — Insert a string as a substring of another string.
 - `string is dict` — Test whether a string is a dictionary.
 - `tcl::process` — Commands for working with subprocesses.
 - `*::build-info` — Obtain information about the build of Tcl.
 - `readFile`, `writeFile`, `foreachLine` — Simple procedures for basic working with files.
 - `tcl::idna::*` — Commands for working with encoded DNS names.

## New command options
 - `chan configure ... -inputmode ...` — Support for raw terminal input and reading passwords.
 - `clock scan ... -validate ...`
 - `info loaded ... ?prefix?`
 - `lsearch ... -stride ...` — Search a list by groups of items.
 - `regsub ... -command ...` — Generate the replacement for a regular expression by calling a command.
 - `socket ... -nodelay ... -keepalive ...`
 - `vwait` controlled by several new options
 - `expr` string comparators `lt`, `gt`, `le`, `ge`
 - `expr` supports comments inside expressions

## Numbers
 - <code>0<i>NNN</i></code> format is no longer octal interpretation. Use <code>0o<i>NNN</i></code>.
 - <code>0d<i>NNNN</i></code> format to compel decimal interpretation.
 - <code>NN_NNN_NNN</code>, underscores in numbers for optional readability
 - Functions: `isinf()`, `isnan()`, `isnormal()`, `issubnormal()`, `isunordered()`
 - Command: `fpclassify`
 - Function `int()` no longer truncates to word size

## TclOO facilities
 - private variables and methods
 - class variables and methods
 - abstract and singleton classes
 - configurable properties
 - `method -export`, `method -unexport`

# Known bugs
 - [changed behaviour wrt command names, namespaces and resolution](https://core.tcl-lang.org/tcl/tktview/f14b33)
 - [windows dos device paths inconsistencies and missing functionality](https://core.tcl-lang.org/tcl/tktview/d8f121)
 - [load library (dll) from zipfs-library causes a leak in temporary folder](https://core.tcl-lang.org/tcl/tktview/a8e4f7)
 - [lsearch -sorted -inline -subindices incorrect result](https://core.tcl-lang.org/tcl/tktview/bc4ac0)
 - ["No error" when load fails due to a missing secondary DLL](https://core.tcl-lang.org/tcl/tktview/66aa81c90a)

