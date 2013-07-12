dnl Process this file with autoconf to produce a configure script.
dnl $Id$
AC_PREREQ(2.63)
AC_DEFUN([MACPORTS_VERSION_MACRO], [esyscmd(<config/macports_version tr -d '\n')])
AC_INIT([MacPorts],MACPORTS_VERSION_MACRO,[macports-dev@lists.macosforge.org],[macports])
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

AC_PATH_PROG(SW_VERS, sw_vers)
AC_PATH_PROG(DEFAULTS, defaults)
AC_PATH_PROG(XCODE_SELECT, xcode-select)

if test "x$SW_VERS" != "x"; then
  AC_MSG_CHECKING(Mac OS X version)
  MACOSX_VERSION=`$SW_VERS -productVersion`
  AC_MSG_RESULT([$MACOSX_VERSION])
fi

case "$MACOSX_VERSION" in
  10.0*|10.1*|10.2*|10.3*)
    AC_MSG_ERROR([This version of Mac OS X is not supported
                  Please upgrade at http://store.apple.com/])
    ;;
  10.4.[[0-9]]|10.4.10|10.5.[[0-7]]|10.6.[[0-7]]|10.7.[[0-4]]|10.8.[[0-3]])
    AC_MSG_WARN([This version of Mac OS X is out of date])
    AC_MSG_WARN([Please run Software Update to update it])
    ;;
  10.4*|10.5*|10.6*|10.7*|10.8*)
    dnl Supported version
    ;;
  *)
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
    AC_MSG_WARN([Please upgrade at http://connect.apple.com/])
    ;;
  2.[[2-3]]*|3.[[0]]*)
    AC_MSG_WARN([This version of Xcode Tools is out of date])
    AC_MSG_WARN([Please consider upgrading as some ports fail compiling])
    ;;
  2.*|3.*|4.*)
    dnl Supported version
    ;;
  *)
    ;;
esac

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_PROG_OBJC

AC_PATH_PROGS(BSDMAKE, [bsdmake pmake], [])
AC_PATH_PROG(BZIP2, [bzip2], [])
AC_PATH_PROG(BZR, [bzr], [])
AC_PATH_PROG(CHOWN, [chown], [], [$PATH:/usr/sbin])
AC_PATH_PROG(CP, [cp], [])
AC_PATH_PROG(CPIO, [cpio], [])
AC_PATH_PROG(CVS, [cvs], [])
AC_PATH_PROG(DIFF, [diff], [])
AC_PATH_PROG(DSCL, [dscl], [])
AC_PATH_PROG(DSEDITGROUP, [dseditgroup], [])
AC_PATH_PROG(FILE, [file], [])
AC_PATH_PROG(FIND, [find], [])
AC_PATH_PROG(GIT, [git], [])
AC_PATH_PROGS(GNUMAKE, [gnumake gmake], [], [$PATH:/usr/local/bin])
AC_PATH_PROGS(GNUPATCH, [gnupatch gpatch], [], [$PATH:/usr/local/bin])
AC_PATH_PROGS(GNUTAR, [gnutar gtar], [], [$PATH:/usr/local/bin])
AC_PATH_PROG(GZIP, [gzip], [])
AC_PATH_PROG(HDIUTIL, [hdiutil], [])
AC_PATH_PROG(HG, [hg], [])
AC_PATH_PROG(LAUNCHCTL, [launchctl], [])
AC_PATH_PROG(LIPO, [lipo], [])
AC_PATH_PROG(LSBOM, [lsbom], [])
AC_PATH_PROG(LZMA, [lzma], [])
AC_PATH_PROG(MAKE, [make])
AC_PATH_PROG(MDFIND, [mdfind], [])
AC_PATH_PROG(MDLS, [mdls], [])
AC_PATH_PROG(MKBOM, [mkbom], [])
AC_PATH_PROG(MTREE, [mtree], [], [$PATH:/usr/sbin])
AC_PATH_PROG(OPEN, [open], [])
AC_PATH_PROG(OPENSSL, [openssl], [])
AC_PATH_PROG(PATCH, [patch], [])
AC_PATH_PROG(PAX, [pax], [])
AC_PATH_PROG(RMDIR, [rmdir], [])
AC_PATH_PROG(RSYNC, [rsync], [])
AC_PATH_PROG(SANDBOX_EXEC, [sandbox-exec], [], [/usr/bin])
AC_PATH_PROG(SED, [sed])
AC_PATH_PROG(SVN, [svn], [])
AC_PATH_PROG(SWIG, [swig], [], [$PATH:/usr/local/bin])
AC_PATH_PROG(TAR, [tar])
AC_PATH_PROG(UNZIP, [unzip])
AC_PATH_PROG(XAR, [xar], [])
AC_PATH_PROG(XCODEBUILD, [xcodebuild], [])
AC_PATH_PROG(XCRUN, [xcrun], [])
AC_PATH_PROG(XZ, [xz], [])
AC_PATH_PROG(ZIP, [zip])

AC_CHECK_PROG(HAVE_LAUNCHD, [launchd], [yes], [])

# Define some precious variables allowing user to override PATH for some programs
AC_ARG_VAR(BSDMAKE, [path to bsdmake/pmake command])
AC_ARG_VAR(BZIP2, [path to bzip2 command])
AC_ARG_VAR(CVS, [path to cvs command])
AC_ARG_VAR(GNUMAKE, [path to gnumake command])
AC_ARG_VAR(GNUTAR, [path to gnutar command])
AC_ARG_VAR(LZMA, [path to lzma command])
AC_ARG_VAR(MAKE, [path to make command])
AC_ARG_VAR(MTREE, [path to mtree command])
AC_ARG_VAR(OPEN, [path to open command])
AC_ARG_VAR(OPENSSL, [path to openssl command])
AC_ARG_VAR(RSYNC, [path to rsync command])
AC_ARG_VAR(SED, [path to sed command])
AC_ARG_VAR(SVN, [path to svn command])
AC_ARG_VAR(SWIG, [path to swig command])
AC_ARG_VAR(TAR, [path to tar command])
AC_ARG_VAR(XAR, [path to xar command])
AC_ARG_VAR(XZ, [path to xz command])

if test "x$MTREE" = "x"; then
    AC_MSG_ERROR([mtree not found])
fi

MP_SED_EXTENDED_REGEXP
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
MP_COMPILER_ATTRIBUTE_LF_PRIVATE

# Foundation checks
ACX_PTHREAD
MP_OBJC_RUNTIME
MP_OBJC_FOUNDATION

MP_PROG_DAEMONDO

AC_SUBST(EXTRA_PROGS)

# set default ports-directory
PORTS_DIR_DEFAULT=`pwd | sed -e "s/base/ports/"`

# Check for paths
AC_PREFIX_DEFAULT(/opt/local)
AC_ARG_WITH(
		unsupported-prefix,
		AS_HELP_STRING([--with-unsupported-prefix],
		[Acknowledge that you accept the consequences of using an unsupported prefix.]),
		[with_unsupported_prefix=$withval],
		[with_unsupported_prefix=no])
if test x$prefix = x/usr/local -o x$prefix = x/usr && test x$with_unsupported_prefix != xyes; then
    AC_MSG_ERROR([Installing MacPorts into $prefix is not supported. If \
you understand this and wish to do so anyway, pass --with-unsupported-prefix \
to configure.])
fi
MP_PATH_PORTSDIR([$PORTS_DIR_DEFAULT])
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

# Check for universal options
MP_UNIVERSAL_OPTIONS

# Check for standard header files.
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_HEADER_SYS_WAIT
AC_CHECK_HEADERS([limits.h paths.h sys/file.h crt_externs.h fcntl.h sys/fcntl.h sys/cdefs.h err.h sys/socket.h \
	sys/sysctl.h readline/readline.h readline/history.h pwd.h sys/paths.h utime.h])

INCLUDES="-I.. -I. $INCLUDES"

# Checks for library functions.
AC_CHECK_FUNCS([bzero memset fgetln lockf flock setmode strcasecmp strncasecmp strlcpy strlcat copyfile clearenv sysctlbyname])
MP_CHECK_READLINK_IS_P1003_1A

# Check for md5 implementation
AC_CHECK_HEADER([CommonCrypto/CommonDigest.h], [AC_DEFINE([HAVE_COMMONCRYPTO_COMMONDIGEST_H], [1], [Define if CommonCrypto is available.])], [MP_LIB_MD5])

# Check for readline
AC_ARG_ENABLE(readline, AS_HELP_STRING([--enable-readline],[Enable addition of readline support, if readline present.]),
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
AC_DEFINE([MIN_USABLE_UID], [500], [Lowest non-system-reserved UID.])
AC_DEFINE([MIN_USABLE_GID], [500], [Lowest non-system-reserved GID.])

# Load tclConfig.sh
SC_PATH_TCLCONFIG
SC_LOAD_TCLCONFIG

# Check for Tcl public headers
dnl XXX	 hardwire CYGPATH (CYGPATH must be set for SC_PUBLIC_TCL_HEADERS)
CYGPATH=echo
SC_PUBLIC_TCL_HEADERS

# Check for tclsh binary
MP_PROG_TCLSH

# Check for Tcl package path
MP_TCL_PACKAGE_DIR

# Check if thread is enabled.
MP_TCL_THREAD_SUPPORT

## libcurl
MP_LIBCURL_FLAGS

## sqlite3
MP_SQLITE3_FLAGS

MP_CHECK_SQLITE_VERSION(3003011)
if test "x${mp_sqlite_version_ge_3003011}" = "xno"; then
	AC_DEFINE([sqlite3_prepare_v2], [sqlite3_prepare], [define sqlite3_prepare to sqlite_prepare_v2 if the latter is not available])
fi

# Determine if we need to install some bundled packages
OUR_INCLUDED_PACKAGES=

## Thread package.
AC_ARG_WITH(
		included-tclthread,
		AS_HELP_STRING([--with-included-tclthread],
			[install included Thread package.]),
		[with_included_tclthread=$withval],
		[with_included_tclthread="unspecified"])

# Check if thread package is already installed.
if test "x$with_included_tclthread" = "xunspecified" ; then
	MP_TCL_PACKAGE(
		[Thread],
		[AC_MSG_RESULT([yes]); with_included_tclthread=no],
		[AC_MSG_RESULT([no]); with_included_tclthread=yes])
fi

# If thread package isn't installed, configure and install thread package.
if test "$with_included_tclthread" = "yes"; then
	OUR_INCLUDED_PACKAGES="$OUR_INCLUDED_PACKAGES thread2.6"
	AC_CONFIG_SUBDIRS([src/thread2.6])
	# Extract thread package
	(cd src/; gzip -d < thread2.6.tar.gz | tar xf -)
	# Patch thread package (so thread2.6 is the vanilla distribution directory)
	patch -p0 < src/thread2.6.diff
fi

# Allows building of shared libraries
SC_ENABLE_SHARED

# Pull compiler / linker values from tclConfig.sh
LDFLAGS_DEBUG=${TCL_LDFLAGS_DEBUG}
LDFLAGS_OPTIMIZE=${TCL_LDFLAGS_OPTIMIZE}
SHLIB_LD=${TCL_SHLIB_LD}
STLIB_LD=${TCL_STLIB_LD}
SHLIB_CFLAGS=${TCL_SHLIB_CFLAGS}
SHLIB_SUFFIX=${TCL_SHLIB_SUFFIX}

AC_SUBST(INCLUDES)
AC_SUBST(STLIB_LD)
AC_SUBST(SHLIB_LD)
AC_SUBST(SHLIB_CFLAGS)
AC_SUBST(SHLIB_LDFLAGS)
AC_SUBST(SHLIB_SUFFIX)
AC_SUBST(TCL_DEFS)
AC_SUBST(TCL_STUB_LIB_SPEC)
AC_SUBST(TCL_CC)
AC_SUBST(OUR_INCLUDED_PACKAGES)

# misc variables that need to be expanded for substitution into tcl

oldprefix=$prefix
if test "x$prefix" = "xNONE" ; then
   prefix=$ac_default_prefix
fi

# Check if there's an existing DP/MP install too old to upgrade
MP_CHECK_OLDLAYOUT

eval "prefix_expanded=$prefix"
AC_SUBST(prefix_expanded)
# do this twice, since there is a nested variable of
# ${prefix} inside of ${sysconfdir}
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR"
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR_EXPANDED"
AC_SUBST(MPCONFIGDIR_EXPANDED)
eval "localstatedir_expanded=$localstatedir"
AC_SUBST(localstatedir_expanded)
eval "macports_tcl_dir=${datadir}/macports/Tcl"
eval "macports_tcl_dir=$macports_tcl_dir"
AC_SUBST(macports_tcl_dir)

prefix=$oldprefix

dnl man page settings (compressed, links, etc)
dnl
dnl SC_CONFIG_MANPAGES

# Output
AC_CONFIG_FILES([
	Doxyfile
	Makefile
	Mk/macports.autoconf.mk
	doc/base.mtree
	doc/prefix.mtree
	doc/macosx.mtree
	doc/macports.conf
	doc/pubkeys.conf
	portmgr/freebsd/Makefile
	src/Makefile
	src/machista1.0/Makefile
	src/macports1.0/macports_autoconf.tcl
	src/port1.0/port_autoconf.tcl
	src/registry2.0/registry_autoconf.tcl
	src/programs/Makefile
	src/macports1.0/macports_fastload.tcl
	setupenv.bash
])

AC_CONFIG_FILES([src/pkg_mkindex.sh], [chmod +x src/pkg_mkindex.sh])

AC_OUTPUT
