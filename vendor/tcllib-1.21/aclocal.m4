# tcl.m4 --
#
#	This file provides a set of autoconf macros to help TEA-enable
#	a Tcl extension.
#
# Copyright (c) 1999-2000 Ajuba Solutions.
# All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#------------------------------------------------------------------------
# SC_SIMPLE_EXEEXT
#	Select the executable extension based on the host type.  This
#	is a lightweight replacement for AC_EXEEXT that doesn't require
#	a compiler.
#
# Arguments
#	none
#
# Results
#	Subst's the following values:
#		EXEEXT
#------------------------------------------------------------------------

AC_DEFUN(SC_SIMPLE_EXEEXT, [
    AC_MSG_CHECKING(executable extension based on host type)

    case "`uname -s`" in
	*win32* | *WIN32* | *CYGWIN_NT* |*CYGWIN_98*|*CYGWIN_95*|*MSYS*)
	    EXEEXT=".exe"
	;;
	*)
	    EXEEXT=""
	;;
    esac

    AC_MSG_RESULT(${EXEEXT})
    AC_SUBST(EXEEXT)
])

#------------------------------------------------------------------------
# SC_PROG_TCLSH
#	Locate a tclsh shell in the following directories:
#		${exec_prefix}/bin
#		${prefix}/bin
#		${TCL_BIN_DIR}
#		${TCL_BIN_DIR}/../bin
#		${PATH}
#
# Arguments
#	none
#
# Results
#	Subst's the following values:
#		TCLSH_PROG
#------------------------------------------------------------------------

AC_DEFUN(SC_PROG_TCLSH, [
    AC_MSG_CHECKING([for tclsh])

    AC_CACHE_VAL(ac_cv_path_tclsh, [
	search_path=`echo ${exec_prefix}/bin:${prefix}/bin:${TCL_BIN_DIR}:${TCL_BIN_DIR}/../bin:${PATH} | sed -e 's/:/ /g'`
	for dir in $search_path ; do
	    for j in `ls -r $dir/tclsh[[8-9]]*${EXEEXT} 2> /dev/null` \
		    `ls -r $dir/tclsh*${EXEEXT} 2> /dev/null` ; do
		if test x"$ac_cv_path_tclsh" = x ; then
		    if test -f "$j" ; then
			ac_cv_path_tclsh=$j
			break
		    fi
		fi
	    done
	done
    ])

    if test -f "$ac_cv_path_tclsh" ; then
	TCLSH_PROG=$ac_cv_path_tclsh
	AC_MSG_RESULT($TCLSH_PROG)
    else
	AC_MSG_ERROR(No tclsh found in PATH:  $search_path)
    fi
    AC_SUBST(TCLSH_PROG)
])
