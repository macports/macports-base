dnl Process this file with autoconf to produce a configure script.
AC_INIT(src/pextlib1.0/Pextlib.c)
AC_PREFIX_DEFAULT(/opt/local)

# Checks for programs.
AC_PROG_CC
AC_PROG_INSTALL

# Check for standard header files.
AC_HEADER_STDC

# Check for Tcl public headers
dnl XXX hardwire CYGPATH (CYGPATH must be set for SC_PUBLIC_TCL_HEADERS)
CYGPATH=echo
SC_PUBLIC_TCL_HEADERS

# Load tclConfig.sh
SC_PATH_TCLCONFIG
SC_LOAD_TCLCONFIG

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

AC_SUBST(CFLAGS_DEBUG)
AC_SUBST(CFLAGS_OPTIMIZE)
AC_SUBST(STLIB_LD)
AC_SUBST(SHLIB_LD)
AC_SUBST(SHLIB_CFLAGS)
AC_SUBST(SHLIB_LDFLAGS)
AC_SUBST(SHLIB_SUFFIX)
AC_SUBST(TCL_STUB_LIB_SPEC)

dnl man page settings (compressed, links, etc)
dnl
dnl SC_CONFIG_MANPAGES

# Output
AC_OUTPUT(Makefile Mk/dports.autoconf.mk)
