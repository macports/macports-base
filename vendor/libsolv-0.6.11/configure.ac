AC_INIT([libsolv],[0.6.11],[macports-dev@lists.macosforge.org])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([foreign -Wall -Werror])
AM_PROG_AR
LT_INIT
AC_PROG_CC
AC_PROG_EGREP
AC_PROG_AWK

# Set swig Macros
AX_PKG_SWIG
AM_CONDITIONAL([HAVE_SWIG], [test "$SWIG" != ""])

# Set Tcl Macros
SC_PATH_TCLCONFIG
SC_LOAD_TCLCONFIG
AC_SUBST([TCL_SHLIB_SUFFIX])
AC_SUBST([TCL_EXEC_PREFIX])
AC_SUBST([TCL_MAJOR_VERSION])
AC_SUBST([TCL_VERSION])

# Check function exists or not
AC_CHECK_FUNCS([qsort_r __qsort_r strchrnul fopencookie funopen])


# Configure Libsolv version.
LIBSOLV_MAJOR=$(echo "${PACKAGE_VERSION}" | cut -d . -f 1)
LIBSOLV_MINOR=$(echo "${PACKAGE_VERSION}" | cut -d . -f 2)
LIBSOLV_PATCH=$(echo "${PACKAGE_VERSION}" | cut -d . -f 3)

VERSION=$PACKAGE_VERSION

AC_SUBST([VERSION])
AC_SUBST([LIBSOLV_MAJOR])
AC_SUBST([LIBSOLV_MINOR])
AC_SUBST([LIBSOLV_PATCH])

AC_CONFIG_FILES(Makefile src/Makefile ext/Makefile bindings/Makefile bindings/tcl/Makefile src/solvversion.h)
AC_OUTPUT
