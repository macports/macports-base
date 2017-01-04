#
# Pull in the standard Tcl autoconf macros.
# If you don't have the "tclconfig" subdirectory, it is a dependent CVS
# module. Either "cvs -d <root> checkout tclconfig" right here, or
# re-checkout the thread module
#
builtin(include,tclconfig/tcl.m4)
builtin(include,naviserver.m4)

#
# Handle the "--with-gdbm" option for linking-in
# the gdbm-based peristent store for shared arrays.
# It tries to locate gdbm files in couple of standard
# system directories and/or common install locations
# in addition to the directory passed by the user.
# In the latter case, expect all gdbm lib files and
# include files located in the same directory.
#

AC_DEFUN(TCLTHREAD_WITH_GDBM, [
    AC_ARG_WITH(gdbm,
	[  --with-gdbm             link with optional GDBM support],\
	with_gdbm=${withval})

    if test x"${with_gdbm}" != x; then

    AC_MSG_CHECKING([for GNU gdbm library])

    AC_CACHE_VAL(ac_cv_c_gdbm,[
    if test x"${with_gdbm}" != x -a "${with_gdbm}" != "yes"; then
        if test -f "${with_gdbm}/gdbm.h" -a x"`ls ${with_gdbm}/libgdbm* 2>/dev/null`" != x; then
            ac_cv_c_gdbm=`(cd ${with_gdbm}; pwd)`
            gincdir=$ac_cv_c_gdbm
            glibdir=$ac_cv_c_gdbm
            AC_MSG_RESULT([found in $glibdir])
        else
            AC_MSG_ERROR([${with_gdbm} directory doesn't contain gdbm library])
        fi
    fi
    ])
    if test x"${gincdir}" = x -o x"${glibdir}" = x; then
        for i in \
                `ls -d ${exec_prefix}/lib 2>/dev/null`\
                `ls -d ${prefix}/lib 2>/dev/null`\
                `ls -d /usr/local/lib 2>/dev/null`\
                `ls -d /usr/lib 2>/dev/null` ; do
            if test x"`ls $i/libgdbm* 2>/dev/null`" != x ; then
                glibdir=`(cd $i; pwd)`
                break
            fi
        done
        for i in \
                `ls -d ${prefix}/include 2>/dev/null`\
                `ls -d /usr/local/include 2>/dev/null`\
                `ls -d /usr/include 2>/dev/null` ; do
            if test -f "$i/gdbm.h" ; then
                gincdir=`(cd $i; pwd)`
                break
            fi
        done
        if test x"$glibdir" = x -o x"$gincdir" = x ; then
            AC_MSG_ERROR([none found])
        else
            AC_MSG_RESULT([found in $glibdir, includes in $gincdir])
            AC_DEFINE(HAVE_GDBM)
            GDBM_CFLAGS="-I\"$gincdir\""
            GDBM_LIBS="-L\"$glibdir\" -lgdbm"
        fi
    fi
    fi
])

# EOF
