dnl Process this file with autoconf to produce a configure script.
AC_PREREQ(2.52)
AC_INIT([OpenDarwin DarwinPorts], [1.0], [darwinports@opendarwin.org], [darwinports])
AC_CONFIG_SRCDIR([src/pextlib1.0/Pextlib.c])
AC_CONFIG_HEADERS([src/config.h])
AC_CANONICAL_SYSTEM

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET

OD_PROG_MTREE

AC_SUBST(REPLACEMENT_PROGS)

# Check for md5 implementation
OD_LIB_MD5

# Check for paths
AC_PREFIX_DEFAULT(/opt/local)
OD_PATH_DPORTSDIR([/usr/dports])
OD_PATH_PORTCONFIGDIR([/etc/ports], [$prefix])

# Check for install ownership
OD_CHECK_INSTALLUSER
OD_CHECK_INSTALLGROUP

# Check for standard header files.
AC_HEADER_STDC
AC_HEADER_DIRENT
AC_HEADER_SYS_WAIT
AC_HEADER_STAT
AC_CHECK_HEADERS([limits.h paths.h sys/file.h crt_externs.h fcntl.h sys/fcntl.h])

INCLUDES="-I.. -I. $INCLUDES"

# Checks for library functions.
AC_FUNC_CLOSEDIR_VOID
AC_FUNC_FORK
AC_FUNC_STRERROR_R
AC_CHECK_FUNCS([bzero memset dup2 regcomp strdup strerror strtol fgetln lockf flock])

# Check for Tcl public headers
dnl XXX hardwire CYGPATH (CYGPATH must be set for SC_PUBLIC_TCL_HEADERS)
CYGPATH=echo
SC_PUBLIC_TCL_HEADERS

# Load tclConfig.sh
SC_PATH_TCLCONFIG
SC_LOAD_TCLCONFIG

# Check for tclsh binary
AC_PATH_PROG([TCLSH], [tclsh tclsh$TCL_VERSION])

# Check for Tcl package path
OD_TCL_PACKAGE_DIR

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

AC_CONFIG_FILES([Makefile Mk/dports.autoconf.mk doc/prefix.mtree
		doc/ports.conf src/darwinports1.0/darwinports_autoconf.tcl
		src/programs/Makefile])

AC_OUTPUT
