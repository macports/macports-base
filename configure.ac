dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.63)
AC_DEFUN([MACPORTS_VERSION_MACRO], [esyscmd(<config/macports_version tr -d '\n')])
AC_INIT([MacPorts],MACPORTS_VERSION_MACRO,[macports-dev@lists.macports.org],[macports])
AC_CONFIG_SRCDIR([src/pextlib1.0/Pextlib.c])
AC_CONFIG_HEADERS([src/config.h])

AC_CANONICAL_TARGET

# Read in the MacPorts version from the base/config/macports_version file
AC_MSG_CHECKING(MacPorts version)
MACPORTS_VERSION=MACPORTS_VERSION_MACRO
AC_MSG_RESULT([$MACPORTS_VERSION])
AC_SUBST(MACPORTS_VERSION)

# Check user PATH for MP paths, and remove as necessary.
MP_PATH_SCAN
MP_FLAGS_SCAN

AC_PATH_PROG(SW_VERS, sw_vers)
AC_PATH_PROG(DEFAULTS, defaults)
AC_PATH_PROG(XCODE_SELECT, xcode-select)

if test "x$SW_VERS" != "x"; then
  AC_MSG_CHECKING(macOS version)
  MACOSX_VERSION=`$SW_VERS -productVersion`
  AC_MSG_RESULT([$MACOSX_VERSION])
fi

case "$MACOSX_VERSION" in
  10.0|10.0.*|10.1|10.1.*|10.2|10.2.*|10.3|10.3.*)
    AC_MSG_ERROR([This version of Mac OS X is not supported
                  Please upgrade at http://store.apple.com/])
    ;;
  10.4|10.4.[[1-9]]|10.4.10|10.5|10.5.[[1-7]]|10.6|10.6.[[1-7]]|10.7|10.7.[[1-4]])
    AC_MSG_WARN([This version of Mac OS X is out of date])
    AC_MSG_WARN([Please run Software Update to update it])
    ;;
  10.8|10.8.[[1-4]]|10.9|10.9.[[1-4]]|10.10|10.10.[[1-4]]|10.11|10.11.[[1-5]])
    AC_MSG_WARN([This version of OS X is out of date])
    AC_MSG_WARN([Please use the Mac App Store to update it])
    ;;
  10.12|10.12.[[1-5]]|10.13|10.13.[[1-5]])
    AC_MSG_WARN([This version of macOS is out of date])
    AC_MSG_WARN([Please use the Mac App Store to update it])
    ;;
  10.14|10.14.[[1-5]]|10.15|10.15.[[1-6]]|11.[[0-2]]|11.[[0-2]].*)
    AC_MSG_WARN([This version of macOS is out of date])
    AC_MSG_WARN([Please run Software Update to update it])
    ;;
  *)
    dnl Not known to be an outdated version
    ;;
esac

# locate currently selected Xcode path
AC_MSG_CHECKING(Xcode location)
if test "x$XCODE_SELECT" != "x"; then
  DEVELOPER_DIR=`$XCODE_SELECT -print-path`
fi
if test -z "$DEVELOPER_DIR" -o ! -d "$DEVELOPER_DIR" ; then
    if test -d /Applications/Xcode.app/Contents/Developer ; then
        DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    else
        DEVELOPER_DIR=/Developer
    fi
fi
AC_MSG_RESULT([$DEVELOPER_DIR])
AC_SUBST(DEVELOPER_DIR)

case "$DEVELOPER_DIR" in
  *Xcode.app/Contents/Developer)
    XCODEPLIST_BASE=`dirname $DEVELOPER_DIR`/version
    ;;
  *)
    XCODEPLIST_BASE=$DEVELOPER_DIR/Applications/Xcode.app/Contents/version
    ;;
esac
XCODEPLIST=${XCODEPLIST_BASE}.plist
if test -r "$XCODEPLIST"; then
  AC_MSG_CHECKING(Xcode version)
  if test "x$DEFAULTS" != "x"; then
    XCODE_VERSION=`$DEFAULTS read $XCODEPLIST_BASE CFBundleShortVersionString`
  else
    XCODE_VERSION=`tr -d '\r\n' < $XCODEPLIST | sed -e 's/.*<key>CFBundleShortVersionString<\/key>.<string>\([[0-9.]]*\)<\/string>.*/\1/'`
  fi
  AC_MSG_RESULT([$XCODE_VERSION])
fi

case "$XCODE_VERSION" in
  1.*|2.[[0-1]]*)
    AC_MSG_WARN([This version of Xcode Tools is not supported])
    AC_MSG_WARN([Please upgrade at https://developer.apple.com/downloads/])
    ;;
  2.[[2-3]]*|3.[[0]]*)
    AC_MSG_WARN([This version of Xcode Tools is out of date])
    AC_MSG_WARN([Please consider upgrading as some ports fail compiling])
    ;;
  *)
    dnl Not a known problematic version
    ;;
esac

# Checks for programs.
AC_PROG_CC([clang cc gcc])
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET

# Check for user-supplied paths before searching

dnl Beware of conflicts between the variables you set and any tools executed in
dnl the configure context. Some tools interpret an environment variable with
dnl their own name as default flags and will fail if it is set to a path. For
dnl example, these include BZIP2 and GZIP, which is the reason why they are
dnl named with a _BIN suffix here.
MP_TOOL_PATH(BSDMAKE, [bsdmake/pmake])
MP_TOOL_PATH(BZIP2_BIN, [bzip2])
MP_TOOL_PATH(CVS, [cvs])
MP_TOOL_PATH(GNUMAKE, [gnumake])
MP_TOOL_PATH(GNUTAR, [gnutar])
MP_TOOL_PATH(LZMA, [lzma])
MP_TOOL_PATH(MAKE, [make])
MP_TOOL_PATH(MTREE, [mtree])
MP_TOOL_PATH(OPEN, [open])
MP_TOOL_PATH(OPENSSL, [openssl])
MP_TOOL_PATH(RSYNC, [rsync])
MP_TOOL_PATH(SED, [sed])
MP_TOOL_PATH(SWIG, [swig])
MP_TOOL_PATH(TAR, [tar])
MP_TOOL_PATH(XAR, [xar])
MP_TOOL_PATH(XZ, [xz])

# Search for tool paths. Any set above (via --with-pkg=PATH) will be retained
AC_PATH_PROGS(BSDMAKE, [bsdmake pmake], [])
AC_PATH_PROG(BZIP2_BIN, [bzip2], [])
AC_PATH_PROG(BZR, [bzr], [])
AC_PATH_PROG(CHOWN, [chown], [], [$PATH:/usr/sbin])
AC_PATH_PROG(CP, [cp], [])
AC_PATH_PROG(CPIO, [cpio], [])
AC_PATH_PROG(CVS, [cvs], [])
AC_PATH_PROG(DIFF, [diff], [])
AC_PATH_PROG(DSCL, [dscl], [])
AC_PATH_PROG(DSEDITGROUP, [dseditgroup], [], [$PATH:/usr/sbin])
AC_PATH_PROG(FILE, [file], [])
AC_PATH_PROG(FIND, [find], [])
AC_PATH_PROG(GIT, [git], [])
AC_PATH_PROGS(GNUMAKE, [gnumake gmake], [])
AC_PATH_PROGS(GNUPATCH, [gnupatch gpatch], [])
AC_PATH_PROGS(GNUTAR, [gnutar gtar], [])
AC_PATH_PROG(GZIP_BIN, [gzip], [])
AC_PATH_PROG(HDIUTIL, [hdiutil], [])
AC_PATH_PROG(HG, [hg], [])
AC_PATH_PROG(LAUNCHCTL, [launchctl], [])
AC_PATH_PROG(LIPO, [lipo], [])
AC_PATH_PROG(LSBOM, [lsbom], [])
AC_PATH_PROG(LZMA, [lzma], [])
AC_PATH_PROG(MAKE, [make])
AC_PATH_PROG(MAN, [man])
AC_PATH_PROG(MDFIND, [mdfind], [])
AC_PATH_PROG(MDLS, [mdls], [])
AC_PATH_PROG(MKBOM, [mkbom], [])
AC_PATH_PROGS(MTREE, [mtree fmtree], [], [$PATH:/usr/sbin])
AC_PATH_PROG(OPEN, [open], [])
AC_PATH_PROG(OPENSSL, [openssl], [])
AC_PATH_PROG(PATCH, [patch], [])
AC_PATH_PROG(PAX, [pax], [])
AC_PATH_PROG(RMDIR, [rmdir], [])
AC_PATH_PROG(RSYNC, [rsync], [])
AC_PATH_PROG(SANDBOX_EXEC, [sandbox-exec], [], [/usr/bin])
AC_PATH_PROG(SED, [sed])
AC_PATH_PROG(SWIG, [swig], [])
AC_PATH_PROG(TAR, [tar])
AC_PATH_PROG(UNZIP, [unzip])
AC_PATH_PROG(XAR, [xar], [])
AC_PATH_PROG(XCODEBUILD, [xcodebuild], [])
AC_PATH_PROG(XCRUN, [xcrun], [])
AC_PATH_PROG(XZ, [xz], [])
AC_PATH_PROG(ZIP, [zip])

if test "x$MTREE" = "x"; then
    AC_MSG_ERROR([mtree not found])
fi

MP_TAR_FAST_READ
MP_TAR_NO_SAME_OWNER
MP_PATCH_GNU_VERSION

# Quiche eaters options.
if test x$GCC = xyes; then
	CFLAGS_QUICHEEATERS='-Wextra -Wall'
	CFLAGS_PEDANTIC='-pedantic'
fi
AC_SUBST(CFLAGS_QUICHEEATERS)
AC_SUBST(CFLAGS_PEDANTIC)
MP_WERROR

MP_COMPILER_ATTRIBUTE_UNUSED

MP_PROG_DAEMONDO

AC_SUBST(EXTRA_PROGS)

# Check for paths
AC_PREFIX_DEFAULT(/opt/local)
AC_ARG_WITH(
		unsupported-prefix,
		AS_HELP_STRING([--with-unsupported-prefix],
		[acknowledge that you accept the consequences of using an unsupported prefix]),
		[with_unsupported_prefix=$withval],
		[with_unsupported_prefix=no])
if test x$prefix = x/usr/local -o x$prefix = x/usr && test x$with_unsupported_prefix != xyes; then
    AC_MSG_ERROR([Installing MacPorts into $prefix is not supported. If \
you understand this and wish to do so anyway, pass --with-unsupported-prefix \
to configure.])
fi
MP_PATH_MPCONFIGDIR

# Check whether to install without root privileges
MP_CHECK_NOROOTPRIVILEGES

# Check for install ownership
MP_CHECK_INSTALLUSER
MP_CHECK_INSTALLGROUP
MP_CHECK_RUNUSER
MP_DIRECTORY_MODE
MP_SHARED_DIRECTORY

# Check for default directories
MP_PATH_APPLICATIONS
MP_PATH_FRAMEWORKS
MP_CHECK_STARTUPITEMS

# Check for universal options
MP_UNIVERSAL_OPTIONS

# Check for standard header files.
AC_CHECK_HEADERS([crt_externs.h err.h fcntl.h libkern/OSAtomic.h libproc.h limits.h paths.h pwd.h \
	readline/history.h readline/readline.h stdatomic.h spawn.h sys/cdefs.h sys/event.h \
	sys/fcntl.h sys/file.h sys/paths.h sys/socket.h sys/sysctl.h utime.h])

# Checks for library functions.
AC_CHECK_FUNCS([OSAtomicCompareAndSwap32 OSAtomicCompareAndSwap64 \
	OSAtomicCompareAndSwapPtr __getdirentries64 clearenv copyfile \
	_dyld_shared_cache_contains_path flock fls kqueue posix_spawn setmode \
	sysctlbyname])

# Check for library functions, replacements are in pextlib1.0/compat/
AC_CHECK_FUNCS([getline getdelim strlcat strlcpy])
AC_SUBST(HAVE_GETDELIM, $ac_cv_func_getdelim)
AC_SUBST(HAVE_GETLINE, $ac_cv_func_getline)
AC_SUBST(HAVE_STRLCAT, $ac_cv_func_strlcat)
AC_SUBST(HAVE_STRLCPY, $ac_cv_func_strlcpy)

AC_CHECK_DECLS([atomic_compare_exchange_strong_explicit], [], [], [[#include <stdatomic.h>]])

# Check for md5 implementation
AC_CHECK_HEADER([CommonCrypto/CommonDigest.h], [AC_DEFINE([HAVE_COMMONCRYPTO_COMMONDIGEST_H], [1], [Define if CommonCrypto is available.])], [MP_LIB_MD5])

# Check for readline
AC_ARG_ENABLE(readline, AS_HELP_STRING([--enable-readline],[enable readline support, if readline present]),
[
	AC_CHECK_LIB([readline], [readline], [
				  READLINE_LIBS=-lreadline
				  AC_DEFINE([HAVE_LIBREADLINE], [1], [Define to 1 if you have the 'readline' library (-lreadline).])
				  ])
	AC_CHECK_DECLS([rl_username_completion_function,rl_filename_completion_function,rl_completion_matches,username_completion_function,filename_completion_function,completion_matches], [], [],
	[
	#include <stdio.h>
	#if HAVE_READLINE_READLINE_H
	# include <readline/readline.h>
	#endif
	])
])
AC_SUBST(READLINE_LIBS)

# Lowest non-system-reserved uid and gid (Apple claims <500)
# The first user on the system is 501 so let's start there too
AC_DEFINE([MIN_USABLE_UID], [501], [Lowest non-system-reserved UID.])
AC_DEFINE([MIN_USABLE_GID], [501], [Lowest non-system-reserved GID.])

# Substitute platform for base compatibility check
MP_PLATFORM

## libcurl
MP_LIBCURL_FLAGS

## sqlite3
MP_SQLITE3_FLAGS

MP_CHECK_SQLITE_VERSION
AC_DEFINE_UNQUOTED([MP_SQLITE_VERSION], [$mp_sqlite_version], [SQLite version found])
if test "$mp_sqlite_version" -lt 3003011; then
	AC_DEFINE([sqlite3_prepare_v2], [sqlite3_prepare], [define sqlite3_prepare to sqlite_prepare_v2 if the latter is not available])
fi

# check whether trace mode is supported on this platform
MP_TRACEMODE_SUPPORT

# misc variables that need to be expanded for substitution into tcl
oldprefix=$prefix
oldexec_prefix=$exec_prefix
if test "x$prefix" = "xNONE" ; then
   prefix=$ac_default_prefix
fi
if test "x$exec_prefix" = "xNONE" ; then
	exec_prefix=$prefix
fi
eval "prefix_expanded=$prefix"
eval "exec_prefix_expanded=$exec_prefix"
AC_SUBST(prefix_expanded)

# Define a path where our trace mode workaround for SIP-protected binaries on
# >= 10.11 puts copies
eval DARWINTRACE_SIP_WORKAROUND_PATH="${prefix}/var/macports/sip-workaround"
AC_SUBST(DARWINTRACE_SIP_WORKAROUND_PATH)
AC_DEFINE_UNQUOTED(
	[DARWINTRACE_SIP_WORKAROUND_PATH],
	["$DARWINTRACE_SIP_WORKAROUND_PATH"],
	[Absolute path to a directory used by darwintrace to copy SIP-protected files before executing])

# do this twice, since there is a nested variable of
# ${prefix} inside of ${sysconfdir}
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR"
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR_EXPANDED"
AC_SUBST(MPCONFIGDIR_EXPANDED)
eval "localstatedir_expanded=$localstatedir"
AC_SUBST(localstatedir_expanded)
# Compute the libexec dir for the vendor packages
eval "macports_libexec_dir=${libexecdir}/macports"
eval "macports_libexec_dir=$macports_libexec_dir"
prefix=$oldprefix
exec_prefix=$oldexec_prefix

## Tcl package
MP_CONFIG_SUBDIR([vendor/tcl/unix], [--prefix=${macports_libexec_dir} --enable-threads])
VENDOR_TCL_SUBDIR=tcl/unix
VENDOR_TCL_INSTALL="install-binaries install-libraries"
AC_SUBST(VENDOR_TCL_SUBDIR)
AC_SUBST(VENDOR_TCL_INSTALL)

# Set up some variables needed by MacPorts' Tcl setup
VENDOR_DESTROOT=vendor/vendor-destroot
AC_SUBST(VENDOR_DESTROOT)

## Tcl Thread package
# Tcl supports Threads internally, but to use threads from Tcl code we need
# this package
MP_CONFIG_SUBDIR([vendor/thread], [--prefix=${macports_libexec_dir}])
VENDOR_TCLTHREAD_SUBDIR=thread
VENDOR_TCLTHREAD_INSTALL="install-binaries install-libraries"
AC_SUBST(VENDOR_TCLTHREAD_SUBDIR)
AC_SUBST(VENDOR_TCLTHREAD_INSTALL)

## TclX package
# TclX is required for signal handling
MP_CONFIG_SUBDIR([vendor/tclx], [--prefix=${macports_libexec_dir}])
VENDOR_TCLX_SUBDIR=tclx
VENDOR_TCLX_INSTALL="install-binaries install-libraries"
AC_SUBST(VENDOR_TCLX_SUBDIR)
AC_SUBST(VENDOR_TCLX_INSTALL)

## Tcllib package
# Note that Tcllib needs a Tcl interpreter during installation; it will *not*
# be the one we configure above, because that one isn't built yet. That's not
# a problem, though -- it's only used during installation.
MP_CONFIG_SUBDIR([vendor/tcllib], [--prefix=${macports_libexec_dir}])
VENDOR_TCLLIB_SUBDIR=tcllib
VENDOR_TCLLIB_INSTALL="install-libraries"
AC_SUBST(VENDOR_TCLLIB_SUBDIR)
AC_SUBST(VENDOR_TCLLIB_INSTALL)

# Load tclConfig.sh from our private install of Tcl
AC_MSG_CHECKING([for Tcl configuration])
TCL_BIN_DIR=`(cd vendor/tcl${tcl_version}/unix; pwd)`
AC_MSG_RESULT([found $TCL_BIN_DIR/tclConfig.sh])
SC_LOAD_TCLCONFIG
SC_ENABLE_SHARED

# Pull compiler/linker values from tclConfig.sh
SHLIB_LD=${TCL_SHLIB_LD}
STLIB_LD=${TCL_STLIB_LD}
SHLIB_CFLAGS=${TCL_SHLIB_CFLAGS}
SHLIB_SUFFIX=${TCL_SHLIB_SUFFIX}
TCLSH=${TCL_EXEC_PREFIX}/bin/tclsh${TCL_VERSION}
INTREE_TCLSH=`(cd vendor; pwd)`/tclsh
# strip possible whitespace at the end of TCL_PACKAGE_PATH
eval "TCL_PACKAGE_PATH=${TCL_PACKAGE_PATH}"

AC_SUBST(SHLIB_LD)
AC_SUBST(STLIB_LD)
AC_SUBST(SHLIB_CFLAGS)
AC_SUBST(SHLIB_SUFFIX)
AC_SUBST(TCL_PREFIX)
AC_SUBST(TCL_VERSION)
AC_SUBST(TCL_PACKAGE_PATH)
AC_SUBST(TCL_STUB_LIB_SPEC)
AC_SUBST(TCL_SRC_DIR)
AC_SUBST(TCL_BIN_DIR)
AC_SUBST(TCLSH)
AC_SUBST(INTREE_TCLSH)

INCLUDES="-I.. -I. $INCLUDES"
AC_SUBST(INCLUDES)

# Check if there's an existing DP/MP install too old to upgrade
MP_CHECK_OLDLAYOUT

# Output
AC_CONFIG_FILES([
	Doxyfile
	Makefile
	Mk/macports.autoconf.mk
	doc/Makefile
	doc/base.mtree
	doc/macosx.mtree
	doc/macports.conf
	doc/prefix.mtree
	doc/pubkeys.conf
	portmgr/dmg/postflight
	setupenv.bash
	src/Makefile
	src/cregistry/Makefile
	src/compat/Makefile
	src/darwintracelib1.0/Makefile
	src/machista1.0/Makefile
	src/macports1.0/Makefile
	src/macports1.0/macports_autoconf.tcl
	src/macports1.0/macports_test_autoconf.tcl
	src/mpcommon1.0/Makefile
	src/package1.0/Makefile
	src/package1.0/package_test_autoconf.tcl
	src/pextlib1.0/Makefile
	src/port/Makefile
	src/port1.0/Makefile
	src/port1.0/port_autoconf.tcl
	src/port1.0/port_test_autoconf.tcl
	src/programs/Makefile
	src/registry2.0/Makefile
	src/registry2.0/registry_autoconf.tcl
	tests/Makefile
	tests/test.tcl
	tests/test/library.tcl
	tests/test/trace/test.tcl
	vendor/Makefile
])

AC_CONFIG_FILES([vendor/tclsh], [chmod +x vendor/tclsh])
AC_CONFIG_FILES([src/cxx_stdlib_overridden.tcl], [chmod +x src/cxx_stdlib_overridden.tcl])
AC_CONFIG_FILES([src/dedup_portfiles.tcl], [chmod +x src/dedup_portfiles.tcl])
AC_CONFIG_FILES([src/images_to_archives.tcl], [chmod +x src/images_to_archives.tcl])
AC_CONFIG_FILES([src/pkg_mkindex.sh], [chmod +x src/pkg_mkindex.sh])
AC_CONFIG_FILES([src/upgrade_sources_conf_default.tcl], [chmod +x src/upgrade_sources_conf_default.tcl])

AC_OUTPUT
