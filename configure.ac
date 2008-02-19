dnl Process this file with autoconf to produce a configure script.
dnl $Id$
AC_PREREQ(2.52)
AC_DEFUN([MACPORTS_VERSION_MACRO], [esyscmd(cat config/macports_version | tr -d '\n')])
AC_INIT([MacPorts], [MACPORTS_VERSION_MACRO], [macports-dev@lists.macosforge.org], [macports])
AC_CONFIG_SRCDIR([src/pextlib1.0/Pextlib.c])
AC_CONFIG_HEADERS([src/config.h])
AC_CANONICAL_SYSTEM

# Read in the MacPorts version from the base/config/macports_vesion file
AC_MSG_CHECKING(MacPorts version)
MACPORTS_VERSION=MACPORTS_VERSION_MACRO
AC_MSG_RESULT([$MACPORTS_VERSION])
AC_SUBST(MACPORTS_VERSION)
# Read the old, floating point format version, which we still use internally, and export it for the $macports::autoconf::macports_version variable
MP_VERSION=$(cat config/mp_version | tr -d '\n')
AC_SUBST(MP_VERSION)

# Check user PATH for MP paths, and remove as necessary.
MP_PATH_SCAN

AC_CHECK_PROGS(SW_VERS, sw_vers)
if test "x$SW_VERS" != "x"; then
  AC_MSG_CHECKING(Mac OS X version)
  MACOSX_VERSION=`$SW_VERS -productVersion | cut -f 1-3 -d.`
  AC_MSG_RESULT([$MACOSX_VERSION])
fi

case "$MACOSX_VERSION" in
  10.0*|10.1*|10.2*)
    AC_WARN(This version of Mac OS X is not supported)
    AC_WARN(Please upgrade at http://store.apple.com/)
    ;;
  10.1.[[0-4]]|10.2.[[0-7]]|10.3.[[0-8]]|10.4.[[0-8]])
    AC_WARN(This version of Mac OS X is out of date)
    AC_WARN(Please run Software Update to update it)
    ;;
  10.3*|10.4*|10.5*)
    dnl Supported version
    ;;
  *)
    ;;
esac

XCODEPLIST=/Developer/Applications/Xcode.app/Contents/version.plist
if test -r "$XCODEPLIST"; then
  AC_MSG_CHECKING(Xcode version)
  XCODE_VERSION=`tr -d '\r\n' < $XCODEPLIST | sed -e 's/.*<key>CFBundleShortVersionString<\/key>.<string>\([[0-9.]]*\)<\/string>.*/\1/'`
  AC_MSG_RESULT([$XCODE_VERSION])
fi

case "$XCODE_VERSION" in
  1.[[0-1]]*|2.[[0-1]]*)
    AC_WARN(This version of Xcode Tools is not supported)
    AC_WARN(Please upgrade at http://connect.apple.com/)
    ;;
  1.[[2-4]]*|2.[[2-3]]*)
    AC_WARN(This version of Xcode Tools is out of date)
    AC_WARN(Please consider upgrading as some ports fail compiling)
    ;;
  1.5*|2.4*|3.*)
    dnl Supported version
    ;;
  *)
    ;;
esac

# Checks for programs.
AC_PROG_CC
AC_PROG_OBJC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_LN_S
AC_PATH_PROG(MTREE, [mtree], [], [$PATH:/usr/sbin])
AC_PATH_PROG(CVS, [cvs], [])
AC_PATH_PROG(SVN, [svn], [])
AC_PATH_PROG(RSYNC, [rsync], [])
AC_PATH_PROG(SED, [sed])
AC_PATH_PROG(TAR, [tar])
AC_PATH_PROG(MAKE, [make])
AC_CHECK_PROG(HAVE_LAUNCHD, [launchd], [yes], [])
AC_PATH_PROG(LAUNCHCTL, [launchctl], [])
AC_PATH_PROG(XCODEBUILD, [xcodebuild], [])
AC_PATH_PROGS(GNUTAR, [gnutar gtar], [], [$PATH:/usr/local/bin])
AC_PATH_PROGS(GNUMAKE, [gnumake gmake], [], [$PATH:/usr/local/bin])
AC_PATH_PROG(BZIP2, [bzip2], [])
AC_PATH_PROG(XAR, [xar], [])
AC_PATH_PROG(OPEN, [open], [])

# Define some precious variables allowing user to override PATH for some programs
AC_ARG_VAR(MTREE, [path to mtree command])
AC_ARG_VAR(CVS, [path to cvs command])
AC_ARG_VAR(SVN, [path to svn command])
AC_ARG_VAR(RSYNC, [path to rsync command])
AC_ARG_VAR(SED, [path to sed command])
AC_ARG_VAR(TAR, [path to tar command])
AC_ARG_VAR(MAKE, [path to make command])
AC_ARG_VAR(GNUTAR, [path to gnutar command])
AC_ARG_VAR(GNUMAKE, [path to gnumake command])
AC_ARG_VAR(BZIP2, [path to bzip2 command])
AC_ARG_VAR(XAR, [path to xar command])
AC_ARG_VAR(OPEN, [path to open command])

MP_SED_EXTENDED_REGEXP
MP_TAR_NO_SAME_OWNER

# Quiche eaters options.
if test x$GCC = xyes; then
	CFLAGS_QUICHEEATERS='-W -Wall -pedantic'
fi
AC_SUBST(CFLAGS_QUICHEEATERS)
MP_WERROR

MP_COMPILER_ATTRIBUTE_UNUSED
MP_COMPILER_ATTRIBUTE_LF_PRIVATE

# Foundation checks
ACX_PTHREAD
MP_OBJC_RUNTIME
MP_OBJC_FOUNDATION

MP_PROG_DAEMONDO
#MP_PROG_XAR

AC_SUBST(REPLACEMENT_PROGS)
AC_SUBST(EXTRA_PROGS)

# set default ports-directory
PORTS_DIR_DEFAULT=`pwd | sed -e "s/base/ports/"`

# Check for paths
AC_PREFIX_DEFAULT(/opt/local)
MP_PATH_PORTSDIR([$PORTS_DIR_DEFAULT])
MP_PATH_MPCONFIGDIR

# Check for install ownership
MP_CHECK_INSTALLUSER
MP_CHECK_INSTALLGROUP
MP_DIRECTORY_MODE

# Check for default directories
MP_PATH_APPLICATIONS
MP_PATH_FRAMEWORKS

# Check for standard header files.
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_HEADER_SYS_WAIT
AC_HEADER_STAT
AC_CHECK_HEADERS([limits.h paths.h sys/file.h crt_externs.h fcntl.h sys/fcntl.h sys/cdefs.h err.h libgen.h sys/socket.h \
	readline/readline.h readline/history.h pwd.h sys/paths.h utime.h])

INCLUDES="-I.. -I. $INCLUDES"

# Checks for library functions.
AC_FUNC_CLOSEDIR_VOID
AC_FUNC_FORK
AC_FUNC_STRERROR_R
AC_CHECK_FUNCS([bzero memset dup2 regcomp strdup strerror strtol fgetln lockf flock setmode strcasecmp strncasecmp strlcpy copyfile])
MP_CHECK_READLINK_IS_P1003_1A

AC_ARG_WITH(x11-prefix, [AC_HELP_STRING([--with-x11-prefix=PREFIX], [use PREFIX as the X11 base dir (default autodetect)])], [ x11prefix="$withval" ] )
case "$x11prefix" in
  "")
    # default to traditional value
    x11prefix=/usr/X11R6
    ;;
  *)
    x_includes=$x11prefix/include
    x_libraries=$x11prefix/lib
    ;;
esac

# Check for md5 implementation
MP_LIB_MD5
# Check for X11 and paraphernalia
MP_CHECK_X11

AC_MSG_CHECKING(for X11 prefix)
X_INCLUDES_PREFIX=`echo "$x_includes" | sed "s,/include,,"`
X_LIBRARIES_PREFIX=`echo "$x_libraries" | sed "s,/lib,,"`
if test "x$have_x" = "xyes" -a "x$X_INCLUDES_PREFIX" = "x$X_LIBRARIES_PREFIX" -a "x$X_LIBRARIES_PREFIX" != x; then
    x11prefix=$X_LIBRARIES_PREFIX
fi
AC_MSG_RESULT([$x11prefix])
AC_SUBST(x11prefix)

# Check for readline
AC_ARG_ENABLE(readline, AC_HELP_STRING([--enable-readline], [Enable addition of readline support, if readline present.]),
[
	AC_CHECK_LIB([readline], [readline], [
				  READLINE_LIBS=-lreadline
				  AC_DEFINE([HAVE_LIBREADLINE], [1], [Define to 1 if you have the `readline' library (-lreadline).])
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

# Do we have curl_easy_strerror?
AH_TEMPLATE([HAVE_CURL_EASY_STRERROR],
	       [Define to 1 if you have the curl_easy_strerror function.])
AC_CHECK_LIB([curl], [curl_easy_strerror],
	[AC_DEFINE([HAVE_CURL_EASY_STRERROR])],[],
	[$LDFLAGS_LIBCURL])

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

## sqlite3 package.
AC_ARG_WITH(
		included-sqlite3,
		AS_HELP_STRING([--with-included-sqlite3],
			[build using bundled sqlite3 package]),
		[with_included_sqlite3=$withval],
		[with_included_sqlite3="unspecified"])

# Check if sqlite3 package is already installed.
if test "x$with_included_sqlite3" = "xunspecified" ; then
	AC_CHECK_LIB([sqlite3],[sqlite3_open],
		[with_included_sqlite3=no],
		[with_included_sqlite3=yes])
fi

AC_ARG_WITH(
		tcl-sqlite3,
		AS_HELP_STRING([--with-tcl-sqlite3=DIR],
			[directory for Tcl sqlite3 (default /usr/lib/sqlite3)]),
		[mp_sqlite3_dir=$withval],
		[mp_sqlite3_dir=/usr/lib/sqlite3])

# If sqlite3 package isn't installed, configure and install sqlite3 package.
if test "$with_included_sqlite3" = "yes"; then
	OUR_INCLUDED_PACKAGES="$OUR_INCLUDED_PACKAGES sqlite-3.1.3"
	INCLUDES="$INCLUDES -I../sqlite-3.1.3"
	AC_CONFIG_SUBDIRS([src/sqlite-3.1.3])
	# Extract sqlite3 package
	(cd src/; gzip -d < sqlite-3.1.3.tar.gz | tar xf -)
	# patch sqlite3 with desired configure options
	patch -p0 < src/sqlite-3.1.3.diff
	# the new tclinstaller.tcl needs to have substitution occur
	mv src/sqlite-3.1.3/tclinstaller.tcl src/sqlite-3.1.3/tclinstaller.tcl.in
	SQLITE3_LIBS=`pwd`"/src/sqlite-3.1.3/.libs/libsqlite3.a"
	if test "x$prefix" = "xNONE" ; then
		SQLITE3_DIR=$ac_default_prefix/share/macports/Tcl/sqlite3
	else
		SQLITE3_DIR=$prefix/share/macports/Tcl/sqlite3
	fi
else
	SQLITE3_LIBS="-lsqlite3"

	AC_CACHE_CHECK([for Tcl sqlite3 location], [mp_cv_sqlite3_dir],
		[mp_cv_sqlite3_dir=
		test -r "${mp_sqlite3_dir}/pkgIndex.tcl" && mp_cv_sqlite3_dir=$mp_sqlite3_dir
		])

	SQLITE3_DIR=$mp_cv_sqlite3_dir
fi

AC_SUBST(SQLITE3_LIBS)
AC_SUBST(SQLITE3_DIR)

AH_TEMPLATE([TRACE_SDK], [SDK for SDK redirect in tracelib])
AC_ARG_WITH(
	trace-sdk,
	AS_HELP_STRING([--with-trace-sdk=SDK],
		[SDK for redirection in trace lib (for example MacOSX10.4u.sdk)]),
	[test -d /Developer/SDKs/$withval && AC_DEFINE_UNQUOTED([TRACE_SDK], "${withval}")], [])
	
	
# If /etc/paths.d and /etc/manpaths.d then we can install our path configuration
# (this code is currently disabled since this mechanism implies that MacPorts paths are
# added after the system's paths, and so MacPorts commands would not override system functions).
AC_MSG_CHECKING(whether to install MacPorts paths into /etc/paths.d and /etc/manpaths.d)
mpprefix=$prefix
test "x$mpprefix" = "xNONE" && mpprefix=$ac_default_prefix
if false && test -d /etc/paths.d -a -d /etc/manpaths.d -a "$mpprefix" = "$ac_default_prefix"; then
	PATHCONF=pathconf
	AC_MSG_RESULT([yes])
else
	AC_MSG_RESULT([no])
fi


# Allows building of shared libraries
SC_ENABLE_SHARED

# Pull compiler / linker values from tclConfig.sh
CFLAGS_DEBUG=${TCL_CFLAGS_DEBUG}
CFLAGS_OPTIMIZE=${TCL_CFLAGS_OPTIMIZE}
LDFLAGS_DEBUG=${TCL_LDFLAGS_DEBUG}
LDFLAGS_OPTIMIZE=${TCL_LDFLAGS_OPTIMIZE}
SHLIB_LD=${TCL_SHLIB_LD}
STLIB_LD=${TCL_STLIB_LD}
SHLIB_CFLAGS=${TCL_SHLIB_CFLAGS}
SHLIB_SUFFIX=${TCL_SHLIB_SUFFIX}

AC_SUBST(INCLUDES)
AC_SUBST(CFLAGS_DEBUG)
AC_SUBST(CFLAGS_OPTIMIZE)
AC_SUBST(PATHCONF)
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

eval "prefix_expanded=$prefix"
AC_SUBST(prefix_expanded)
# do this twice, since there is a nested variable of
# ${prefix} inside of ${sysconfdir}
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR"
eval "MPCONFIGDIR_EXPANDED=$MPCONFIGDIR_EXPANDED"
AC_SUBST(MPCONFIGDIR_EXPANDED)
eval "localstatedir_expanded=$localstatedir"
AC_SUBST(localstatedir_expanded)

prefix=$oldprefix

dnl man page settings (compressed, links, etc)
dnl
dnl SC_CONFIG_MANPAGES

# Output
AC_CONFIG_FILES([
	Doxyfile
	Makefile
	Mk/macports.autoconf.mk
	doc/prefix.mtree
	doc/macosx.mtree
	doc/macports.conf
	portmgr/freebsd/Makefile
	portmgr/fedora/macports.spec
	src/Makefile
	src/macports1.0/macports_autoconf.tcl
	src/tclobjc1.0/Makefile
	src/pathconf/Makefile
	src/pathconf/paths
	src/pathconf/manpaths
	src/port1.0/port_autoconf.tcl
	src/registry1.0/registry_autoconf.tcl
	src/programs/Makefile
	src/macports1.0/macports_fastload.tcl
])

AC_OUTPUT
