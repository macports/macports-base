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

    if test x"${with_gdbm}" != x -a "${with_gdbm}" != no; then

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
		`ls -d /usr/lib 2>/dev/null`\
		`ls -d /usr/lib/x86_64-linux-gnu 2>/dev/null` ; do
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


#
# Handle the "--with-lmdb" option for linking-in
# the LMDB-based peristent store for shared arrays.
# It tries to locate LMDB files in couple of standard
# system directories and/or common install locations
# in addition to the directory passed by the user.
# In the latter case, expect all LMDB lib files and
# include files located in the same directory.
#

AC_DEFUN(TCLTHREAD_WITH_LMDB, [
    AC_ARG_WITH(lmdb,
	[  --with-lmdb             link with optional LMDB support],
	with_lmdb=${withval})

    if test x"${with_lmdb}" != "x" -a "${with_lmdb}" != no; then
	AC_MSG_CHECKING([for LMDB library])
	AC_CACHE_VAL(ac_cv_c_lmdb,[
	if test x"${with_lmdb}" != x -a "${with_lmdb}" != "yes"; then
	    if test -f "${with_lmdb}/lmdb.h" -a x"`ls ${with_lmdb}/liblmdb* 2>/dev/null`" != x; then
		ac_cv_c_lmdb=`(cd ${with_lmdb}; pwd)`
		lincdir=$ac_cv_c_lmdb
		llibdir=$ac_cv_c_lmdb
		AC_MSG_RESULT([found in $llibdir])
	    else
		AC_MSG_ERROR([${with_lmdb} directory doesn't contain lmdb library])
	    fi
	fi
	])
	if test x"${lincdir}" = x -o x"${llibdir}" = x; then
	    for i in \
		    `ls -d ${exec_prefix}/lib 2>/dev/null`\
		    `ls -d ${prefix}/lib 2>/dev/null`\
		    `ls -d /usr/local/lib 2>/dev/null`\
		    `ls -d /usr/lib 2>/dev/null`\
		    `ls -d /usr/lib/x86_64-linux-gnu 2>/dev/null` ; do
		if test x"`ls $i/liblmdb* 2>/dev/null`" != x ; then
		    llibdir=`(cd $i; pwd)`
		    break
		fi
	    done
	    for i in \
		    `ls -d ${prefix}/include 2>/dev/null`\
		    `ls -d /usr/local/include 2>/dev/null`\
		    `ls -d /usr/include 2>/dev/null` ; do
		if test -f "$i/lmdb.h" ; then
		    lincdir=`(cd $i; pwd)`
		    break
		fi
	    done
	    if test x"$llibdir" = x -o x"$lincdir" = x ; then
		AC_MSG_ERROR([none found])
	    else
		AC_MSG_RESULT([found in $llibdir, includes in $lincdir])
		AC_DEFINE(HAVE_LMDB)
		LMDB_CFLAGS="-I\"$lincdir\""
		LMDB_LIBS="-L\"$llibdir\" -llmdb"
	    fi
	fi
    fi
])

# FIND_TCLSH9_NATIVE
# Locates a Tcl 9 tclsh and set TCLSH_NATIVE to its path if found.
# Unsets TCLSH_NATIVE if not found.
AC_DEFUN([FIND_TCLSH9_NATIVE], [
	found="no"
	for f in tclsh9.0 tclsh90 tclsh; do
	    AS_UNSET([TCLSH_NATIVE])
	    AS_UNSET([ac_cv_path_TCLSH_NATIVE])
	    AC_PATH_PROG([TCLSH_NATIVE], [$f], [no])
		if test "$TCLSH_NATIVE" != "no"; then
		    AC_MSG_CHECKING([$TCLSH_NATIVE is Tcl 9])
		    CHECK_TCLSH_VERSION([found], [$TCLSH_NATIVE], [9])
			AC_MSG_RESULT([$found])
			if test "$found" = "yes"; then
			   found=yes
			   break
			fi
		fi
	done
    if test "$found" != "yes"; then
	    AS_UNSET(TCLSH_NATIVE)
	fi
])

# CHECK_TCLSH_VERSION(RESULTVAR, EXECUTABLE, VERSIONREQUIREMENTS)
# RESULTVAR - name of variable to in which to store result.
# EXECUTABLE - tclsh program to check
# VERSIONREQUIREMENTS - version requirements as passed to Tcl [package vsatisfies]
#
# The stored result is "yes" if the EXECUTABLE is a tclsh and meets the
# version requirements and "no" in all other cases.

AC_DEFUN([CHECK_TCLSH_VERSION], [
    $1=`echo "puts [[package vsatisfies \\$tcl_version $3]]" | $2`
	if test "x[$][$1]" = "x1"; then
	    $1=yes
	else
	    $1=no
	fi
])

# EOF
