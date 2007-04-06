dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.52)
AC_INIT([MacPorts], [1.5], [macports-dev@lists.macosforge.org], [macports])
AC_CONFIG_SRCDIR([src/pextlib1.0/Pextlib.c])
AC_CONFIG_HEADERS([src/config.h])
AC_CANONICAL_SYSTEM

# Check user PATH for DP paths, and remove as necessary.
OD_PATH_SCAN

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_LN_S
AC_PATH_PROG(CVS, [cvs], [])
AC_PATH_PROG(RSYNC, [rsync], [])
AC_CHECK_PROG(HAVE_LAUNCHD, [launchd], [yes], [])
AC_PATH_PROG(LAUNCHCTL, [launchctl], [])
AC_PATH_PROG(XCODEBUILD, [xcodebuild], [])
AC_PATH_PROG(BZIP2, [bzip2], [])

# Define some precious variables allowing user to override PATH for some programs
AC_ARG_VAR(CVS, [path to cvs command])
AC_ARG_VAR(RSYNC, [path to rsync command])
AC_ARG_VAR(TAR, [path to tar command])
AC_ARG_VAR(GNUTAR, [path to gnutar command])
AC_ARG_VAR(BZIP2, [path to bzip2 command])

OD_TAR_NO_SAME_OWNER

# Quiche eaters options.
if test x$GCC = xyes; then
	CFLAGS_QUICHEEATERS='-W -Wall -pedantic'
fi
AC_SUBST(CFLAGS_QUICHEEATERS)

OD_COMPILER_ATTRIBUTE_UNUSED

OD_PROG_MTREE
OD_PROG_XAR
AC_ARG_ENABLE(launchd-support,
	AC_HELP_STRING([--disable-launchd-support], [disable support for launchd startupitems]),
	[], [enable_launchd_support=yes])
AC_SUBST(ENABLE_LAUNCHD_SUPPORT, [$enable_launchd_support])
AS_IF([test x"${enable_launchd_support}" == "xyes"], [OD_PROG_DAEMONDO])

AC_SUBST(REPLACEMENT_PROGS)
AC_SUBST(EXTRA_PROGS)

# set default dports-directory
DPORTS_DIR_DEFAULT=`pwd | sed -e "s/base/dports/"`

# Check for paths
AC_PREFIX_DEFAULT(/opt/local)
OD_PATH_DPORTSDIR([$DPORTS_DIR_DEFAULT])
OD_PATH_PORTCONFIGDIR
OD_PATH_SQLITE3

# Check for install ownership
OD_CHECK_INSTALLUSER
OD_CHECK_INSTALLGROUP
OD_DIRECTORY_MODE

# Check for standard header files.
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_HEADER_SYS_WAIT
AC_HEADER_STAT
AC_CHECK_HEADERS([limits.h paths.h sys/file.h crt_externs.h fcntl.h sys/fcntl.h sys/cdefs.h err.h libgen.h sys/socket.h \
	readline/readline.h readline/history.h pwd.h sys/paths.h])

INCLUDES="-I.. -I. $INCLUDES"

# Checks for library functions.
AC_FUNC_CLOSEDIR_VOID
AC_FUNC_FORK
AC_FUNC_STRERROR_R
AC_CHECK_FUNCS([bzero memset dup2 regcomp strdup strerror strtol fgetln lockf flock setmode strcasecmp strncasecmp strlcpy copyfile])
DP_CHECK_READLINK_IS_P1003_1A

# Check for md5 implementation
OD_LIB_MD5
# Check for X11 and paraphernalia
OD_CHECK_X11

# Check for readline
AC_CHECK_LIB([readline], [readline])
AC_CHECK_DECLS([rl_username_completion_function,rl_filename_completion_function,rl_completion_matches,username_completion_function,filename_completion_function,completion_matches], [], [],
[
#include <stdio.h>
#if HAVE_READLINE_READLINE_H
# include <readline/readline.h>
#endif
])

# Load tclConfig.sh
SC_PATH_TCLCONFIG
SC_LOAD_TCLCONFIG

# Check for Tcl public headers
dnl XXX	 hardwire CYGPATH (CYGPATH must be set for SC_PUBLIC_TCL_HEADERS)
CYGPATH=echo
SC_PUBLIC_TCL_HEADERS

# Check for tclsh binary
OD_PROG_TCLSH

# Check for Tcl package path
OD_TCL_PACKAGE_DIR

# Check if thread is enabled.
OD_TCL_THREAD_SUPPORT

## libcurl
OD_LIBCURL_FLAGS

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
		[  --with-included-tclthread install included Thread package.],
		[with_included_tclthread=$withval],
		[with_included_tclthread="unspecified"])

# Check if thread package is already installed.
if test "x$with_included_tclthread" = "xunspecified" ; then
	OD_TCL_PACKAGE(
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

AC_SUBST(OUR_INCLUDED_PACKAGES)

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
AC_SUBST(TCL_DEFS)
AC_SUBST(STLIB_LD)
AC_SUBST(SHLIB_LD)
AC_SUBST(SHLIB_CFLAGS)
AC_SUBST(SHLIB_LDFLAGS)
AC_SUBST(SHLIB_SUFFIX)
AC_SUBST(TCL_STUB_LIB_SPEC)
AC_SUBST(TCL_CC)

#misc variables that need to be expanded for substitution into tcl

oldprefix=$prefix
if test "x$prefix" = "xNONE" ; then
   prefix=$ac_default_prefix
fi

eval "prefix_expanded=$prefix"
AC_SUBST(prefix_expanded)
# do this twice, since there is a nested variable of
# ${prefix} inside of ${sysconfdir}
eval "PORTCONFIGDIR_EXPANDED=$PORTCONFIGDIR"
eval "PORTCONFIGDIR_EXPANDED=$PORTCONFIGDIR_EXPANDED"
AC_SUBST(PORTCONFIGDIR_EXPANDED)
eval "localstatedir_expanded=$localstatedir"
AC_SUBST(localstatedir_expanded)

prefix=$oldprefix

dnl man page settings (compressed, links, etc)
dnl
dnl SC_CONFIG_MANPAGES

# Output

AC_CONFIG_FILES([
	Makefile
	Mk/dports.autoconf.mk
	doc/prefix.mtree
	doc/macosx.mtree
	doc/ports.conf
	src/Makefile
	src/darwinports1.0/darwinports_autoconf.tcl
	src/port1.0/port_autoconf.tcl
	src/registry1.0/registry_autoconf.tcl
	src/programs/Makefile
	src/darwinports1.0/darwinports_fastload.tcl
])

AC_OUTPUT
